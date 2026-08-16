#!/usr/bin/env bash
#
# Fixtures for resolve-base.sh.
#
# Every case here except the first exists because an earlier version of the
# resolver passed a clean linear `master -> A -> B` fixture and was wrong on
# everything else. A base-resolution bug is silent — it produces a plausible
# range over the wrong code — so the fixtures have to include the shapes that
# break it, not the shape it was designed for.
#
# Usage: test-resolve-base.sh [workdir]    (default: mktemp -d)

set -uo pipefail

RESOLVE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/resolve-base.sh
WORK=${1:-$(mktemp -d)}
pass=0; fail=0

g() { command git --no-optional-locks "$@"; }

field() { printf '%s\n' "$1" | sed -n "s/^$2=//p"; }

ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; }
is()   { [ "$2" = "$3" ] && ok "$1" || bad "$1" "$3" "$2"; }

newrepo() { # newrepo <name>
  rm -rf "${WORK:?}/$1"; mkdir -p "$WORK/$1"; cd "$WORK/$1" || exit 1
  g init -q -b master .
  g config user.email t@t; g config user.name t
}

commit() { echo "$2" > "$1"; g add -A; g commit -qm "$3"; }

echo "workdir: $WORK"

# --- 1. linear stack: master -> A -> B, reviewed on B ------------------------
echo "linear stack"
newrepo linear
commit f m1 m1
g checkout -qb A; commit a a1 a1; commit a a2 a2
g checkout -qb B; commit b b1 b1; commit b b2 b2
out=$($RESOLVE 2>&1)
is "picks A, not master" "$(field "$out" base)" "A"
is "counts B's own commits" "$(field "$out" commits)" "2"
is "base_sha is A's tip" "$(field "$out" base_sha)" "$(g rev-parse A)"

# --- 2. base advances after the fork, stale merged topic present -------------
# The case that broke the ancestor-based resolver: once master moves, it is no
# longer an ancestor of HEAD, and a long-merged topic branch wins by default.
echo "advancing base with a stale merged topic branch"
newrepo advancing
commit shared base m1
g checkout -qb old-topic; commit topic t topic
g checkout -q master; g merge -q --no-ff old-topic -m "merge old-topic"
g checkout -qb feat; commit feat f f1
g checkout -q master; echo "master-only" >> shared; g commit -qam m2
g checkout -q feat
out=$($RESOLVE 2>&1)
is "picks master, not the stale topic branch" "$(field "$out" base)" "master"
is "counts only the branch's commit" "$(field "$out" commits)" "1"
is "base_sha is the fork point, not master's tip" \
   "$(field "$out" base_sha)" "$(g merge-base master HEAD)"

# The point of emitting base_sha: the range must not contain the base's own work.
range=$(field "$out" range)
is "diff over range excludes the base-only change" \
   "$(g diff --name-only "$range" | sort | tr '\n' ' ')" "feat "
is "two-dot diff on the ref name would have included it (why base_sha exists)" \
   "$(g diff --name-only master..HEAD | sort | tr '\n' ' ')" "feat shared "
is "reports the runner-up so a wrong heuristic pick is visible" \
   "$(field "$out" alternatives)" "old-topic(2)"

# --- 2b. two candidates forking at different points, same distance ----------
# Topologically a real tie. Guessing would review the wrong code.
echo "ambiguous fork points"
newrepo ambiguous
commit f m1 m1
g checkout -qb P; commit p p1 p1
g checkout -q master; g checkout -qb Q; commit q q1 q1
g checkout -qb feat; g merge -q --no-ff P -m "merge P"
out=$($RESOLVE 2>&1); rc=$?
is "refuses to guess between equidistant forks" "$rc" "1"
is "names both candidates" "$(printf '%s' "$out" | grep -c 'ambiguous base')" "1"

# --- 3. sitting on the default branch, clean, no remote ---------------------
echo "on the default branch, no remote"
newrepo ondefault
commit shared base m1
g checkout -qb old-topic; commit topic t topic
g checkout -q master; g merge -q --no-ff old-topic -m "merge old-topic"
out=$($RESOLVE 2>&1)
is "does not reach for the stale topic branch" "$(field "$out" base)" "master"
is "reports nothing to review" "$(field "$out" commits)" "0"
is "clean tree" "$(field "$out" dirty)" "no"

echo "untracked" > scratch.txt
out=$($RESOLVE 2>&1)
is "dirty tree on the default branch is still reviewable" "$(field "$out" dirty)" "yes"
rm scratch.txt

# --- 4. default branch with a remote and unpushed commits -------------------
echo "on the default branch with unpushed commits"
newrepo remoted
commit f m1 m1
rm -rf "${WORK:?}/remoted.git"   # newrepo only clears the worktree, not the bare remote
g init -q --bare "$WORK/remoted.git"
g remote add origin "$WORK/remoted.git"
g push -q origin master
commit f m2 m2
commit f m3 m3
out=$($RESOLVE 2>&1)
is "compares against the remote" "$(field "$out" base)" "origin/master"
is "counts the unpushed commits" "$(field "$out" commits)" "2"

# --- 5. a branch built on top of ours is a child, not a base ----------------
echo "descendant branch"
newrepo descendant
commit f m1 m1
g checkout -qb feat; commit f f1 f1
g checkout -qb child; commit f c1 c1
g checkout -q feat
out=$($RESOLVE 2>&1)
is "ignores the descendant, picks master" "$(field "$out" base)" "master"
is "counts feat's commit" "$(field "$out" commits)" "1"

# --- 6. explicit override ---------------------------------------------------
echo "explicit override"
cd "$WORK/linear" || exit 1
out=$($RESOLVE master 2>&1)
is "honours the explicit base" "$(field "$out" base)" "master"
is "explicit method" "$(field "$out" method)" "explicit"
is "counts A and B together" "$(field "$out" commits)" "4"
out=$($RESOLVE no-such-ref 2>&1); rc=$?
is "rejects an unknown ref" "$rc" "1"

# --- 7. refusals ------------------------------------------------------------
echo "refusals"
cd "$WORK/linear" || exit 1
g checkout -q --detach HEAD
out=$($RESOLVE 2>&1); rc=$?
is "detached HEAD fails" "$rc" "1"
is "detached HEAD explains itself" "$(printf '%s' "$out" | grep -c 'explicit base')" "1"
g checkout -q B

mkdir -p "$WORK/notgit"; cd "$WORK/notgit" || exit 1
out=$($RESOLVE 2>&1); rc=$?
is "non-repository fails" "$rc" "1"

cd /
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
