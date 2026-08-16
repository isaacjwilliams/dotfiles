#!/usr/bin/env bash
#
# Resolve the base of the working branch for `codex-review branch`.
#
# Two things this has to get right. A naive implementation gets both wrong, and
# both failures are silent — they produce a plausible range over the wrong code.
#
#   1. The base is a *fork point*, not a branch tip. `git diff base..HEAD`
#      compares two endpoint trees, so the moment the base branch gains a commit
#      after your fork, that commit appears in the diff as a deletion the branch
#      never made. Everything downstream must diff from `base_sha` below, which
#      is the merge base, and never from the ref name.
#
#   2. "Nearest branch tip that is an ancestor of HEAD" is the wrong way to pick
#      a base. Requiring the candidate to be an ancestor disqualifies the correct
#      base as soon as it advances, handing the answer to whatever stale merged
#      topic branch is still lying around. Candidates are ranked here by how far
#      their merge base sits from HEAD, which is defined for every branch whether
#      or not it is an ancestor.
#
# In a stack like master -> A -> B, running on B resolves A.
#
# Prints to stdout, on success:
#   base=<ref>           human-readable name of the base
#   base_sha=<sha>       the merge base — diff and log from THIS, not from base
#   range=<sha>..HEAD    ready-made range for git diff / git log
#   method=<how it was resolved>
#   commits=<count in range>
#   dirty=<yes|no>       uncommitted tracked or untracked changes present
#   alternatives=<...>   heuristic path only: runner-up bases, `ref(distance)`.
#                        Present means the pick was inferred from topology and
#                        could be wrong; show these so the user can catch it.
#
# commits=0 with dirty=no means there is nothing to review; the caller is
# expected to stop rather than spend a review call on an empty range. commits=0
# with dirty=yes is legitimate — uncommitted work sitting directly on the base.
#
# On failure, prints a reason to stderr and exits non-zero. Failure is always
# preferred to a guess: a wrong base reviews the wrong code and nothing
# downstream can detect it.
#
# Usage: resolve-base.sh [explicit-base]

set -uo pipefail

# --no-optional-locks throughout: the reviewing session may be read-only, and
# plain git can fail trying to take an index lock.
g() { command git --no-optional-locks "$@"; }

die() { echo "$*" >&2; exit 1; }

# emit <ref> <method> [base_sha] [alternatives]
# Without an explicit base_sha, the merge base against HEAD is computed.
emit() {
  local ref=$1 method=$2 sha=${3:-} alts=${4:-} n dirty
  if [ -z "$sha" ]; then
    sha=$(g merge-base "$ref" HEAD 2>/dev/null) || sha=""
    [ -n "$sha" ] || die "no common history between $ref and HEAD; pass an explicit base as branch:<base>"
  fi
  n=$(g rev-list --count "$sha..HEAD" 2>/dev/null) || n=0
  if [ -n "$(g status --porcelain 2>/dev/null)" ]; then dirty=yes; else dirty=no; fi
  printf 'base=%s\nbase_sha=%s\nrange=%s..HEAD\nmethod=%s\ncommits=%s\ndirty=%s\n' \
    "$ref" "$sha" "$sha" "$method" "$n" "$dirty"
  [ -n "$alts" ] && printf 'alternatives=%s\n' "$alts"
  exit 0
}

default_branch() {
  local d
  d=$(g symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  [ -n "$d" ] && { echo "${d##*/}"; return; }
  if command -v gh >/dev/null 2>&1; then
    d=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null)
    [ -n "$d" ] && { echo "$d"; return; }
  fi
  for c in main master; do
    g rev-parse --verify --quiet "refs/heads/$c" >/dev/null && { echo "$c"; return; }
  done
  echo ""
}

g rev-parse --git-dir >/dev/null 2>&1 || die "not a git repository"

current=$(g rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -n "$current" ] && [ "$current" != "HEAD" ] ||
  die "detached HEAD; pass an explicit base as branch:<base>"

head_sha=$(g rev-parse HEAD 2>/dev/null) || die "HEAD does not resolve; is this an empty repository?"

# 1. Explicit override always wins.
if [ -n "${1:-}" ]; then
  g rev-parse --verify --quiet "$1^{commit}" >/dev/null || die "unknown ref: $1"
  emit "$1" "explicit"
fi

# 2. The PR's own base, resolved to the exact commit. baseRefName alone is not
#    enough: a local branch of that name can predate the fork, and in a fork
#    workflow `origin/<name>` may be the contributor's fork rather than the
#    PR's base repository. baseRefOid names the commit unambiguously.
if command -v gh >/dev/null 2>&1; then
  pr=$(gh pr view --json baseRefName,baseRefOid -q '"\(.baseRefName)\t\(.baseRefOid)"' 2>/dev/null)
  if [ -n "$pr" ]; then
    pr_name=${pr%%$'\t'*}
    pr_oid=${pr##*$'\t'}
    if [ -n "$pr_oid" ] && [ "$pr_oid" != "$pr_name" ]; then
      if g cat-file -e "$pr_oid^{commit}" 2>/dev/null; then
        mb=$(g merge-base "$pr_oid" HEAD 2>/dev/null) || mb=""
        [ -n "$mb" ] || die "PR base commit $pr_oid shares no history with HEAD; pass an explicit base as branch:<base>"
        emit "$pr_name" "pull request base ($pr_oid)" "$mb"
      fi
      die "PR base commit $pr_oid is not present locally.
Fetch it (git fetch origin $pr_name) and re-run, or pass an explicit base as branch:<base>.
Refusing to substitute a local ref named $pr_name, which may be stale or may belong to a fork."
    fi
  fi
fi

# 3. Tracking branch, but only when it is something other than this same branch
#    pushed to a remote — origin/B is not a base for B.
upstream=$(g rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)
if [ -n "$upstream" ] && [ "${upstream##*/}" != "$current" ]; then
  emit "$upstream" "tracking branch"
fi

def=$(default_branch)

# 4. Sitting on the default branch. There is no parent branch to compare
#    against, so the review is whatever has not reached the remote yet, plus the
#    working tree. Without this case the ranking below has no legitimate
#    candidate and would reach for a stale merged topic branch.
if [ -n "$def" ] && [ "$current" = "$def" ]; then
  if g rev-parse --verify --quiet "refs/remotes/origin/$def" >/dev/null; then
    emit "origin/$def" "default branch, against its remote"
  fi
  emit "$current" "on the default branch with no remote — working tree only" "$head_sha"
fi

# 5. Rank every branch ref by how far its merge base sits from HEAD. The nearest
#    fork point wins. A stale merged branch forked long ago and therefore ranks
#    far away, which is exactly the discrimination the old ancestor test lacked.
#
#    This ranking cannot distinguish a parent branch from a sibling: a
#    pre-rebase backup of the branch under review has the same topology as the
#    branch it forked from, and will outrank the real parent because it is
#    nearer. No metric fixes that — the shapes are identical. It is why PR and
#    tracking metadata are consulted first, and why the runners-up are reported
#    as `alternatives` rather than discarded. The caller is expected to show
#    them so a wrong pick is visible instead of silent.
cands=$(
  g for-each-ref --format='%(refname:short)' refs/heads refs/remotes |
  while IFS= read -r ref; do
    [ "${ref##*/}" = "$current" ] && continue   # this branch, local or pushed
    [ "$ref" = "origin/HEAD" ] && continue      # an alias, not a branch
    mb=$(g merge-base "$ref" HEAD 2>/dev/null) || continue
    [ -n "$mb" ] || continue                    # unrelated history
    [ "$mb" = "$head_sha" ] && continue         # a descendant of HEAD is a child, not a base
    n=$(g rev-list --count "$mb..HEAD" 2>/dev/null) || continue
    printf '%s\t%s\t%s\n' "$n" "$mb" "$ref"
  done | sort -n -k1,1
)

if [ -n "$cands" ]; then
  best=$(printf '%s\n' "$cands" | head -1)
  best_n=${best%%$'\t'*}
  best_rest=${best#*$'\t'}
  best_sha=${best_rest%%$'\t'*}
  best_ref=${best_rest#*$'\t'}

  # A different fork point at the same distance is a genuine tie. Guessing here
  # would review the wrong code, so refuse and make the caller decide.
  amb=$(printf '%s\n' "$cands" |
        awk -F'\t' -v n="$best_n" -v s="$best_sha" '$1==n && $2!=s {print $3; exit}')
  [ -n "$amb" ] && die "ambiguous base: $best_ref and $amb fork from HEAD at different points but the same distance.
Pass an explicit base as branch:<base>."

  # Runners-up at a different fork point. Same-fork-point refs are aliases of
  # the winner, not alternatives, so they are dropped.
  alts=$(printf '%s\n' "$cands" |
         awk -F'\t' -v s="$best_sha" '$2!=s {printf "%s(%s) ", $3, $1}' |
         awk '{$1=$1};1' | cut -c1-160)

  emit "$best_ref" "nearest fork point among branch refs" "$best_sha" "$alts"
fi

# 6. Default branch, as a last resort. Remote first: a local copy can be stale.
if [ -n "$def" ]; then
  for cand in "origin/$def" "$def"; do
    g rev-parse --verify --quiet "$cand^{commit}" >/dev/null && emit "$cand" "default branch"
  done
fi

die "could not resolve a base; pass one explicitly as branch:<base>"
