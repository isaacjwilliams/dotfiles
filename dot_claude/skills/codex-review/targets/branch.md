# Target: branch

The artifact is the commits between the resolved fork point and the working branch, plus
any uncommitted changes. You did not necessarily write it. In a stack like
`master -> A -> B`, an explicitly named or recorded base of `A` reviews only what `B`
added; with no recorded base, the default branch is used and the review intentionally
includes both `A` and `B`.

## Scope

### The base comes from a recorded fact or the defined default, not topology

In `master -> A -> B`, reviewing `B` against `A` and against `master` are both
legitimate — the first is "what this branch added", the second is "what the stack adds".
Nothing in the topology distinguishes them, because the difference is in what the user
wants reviewed.

**So do not infer a base from history.** Use a base the user or the repository has
actually recorded; when there is none, use the default branch and say that you did. A base
picked by cleverness reviews the wrong commits and says nothing about having done so — this
skill previously shipped a ranking heuristic for exactly this decision and it was wrong
four separate times.

### 1. Use a recorded base if one exists

In precedence order. Each of these is a stated fact, not a guess.

**The request named one.** "versus master", "against origin/main", `branch:master`.
Preserve the exact text as argument data and ask Git to verify that it resolves to a
commit. Stop with the unknown ref named if it does not; do not rewrite the request into a
different ref.

**A pull request records one.**

Read the PR's `baseRefName` and `baseRefOid` through the available GitHub tooling. Use
`baseRefOid`. It names the base commit unambiguously; `baseRefName` does not, because a
local branch of that name can predate the fork, and in a fork workflow `origin/<name>` may
be the contributor's fork rather than the PR's base repository. Ask Git whether that
commit is present locally. If it is absent, **stop and say to fetch it** — do not
substitute a same-named ref.

**An upstream records one, if it is not this branch's own remote copy.** `origin/feat` is
not a base for `feat`. Compare *whole branch paths*: strip only the remote name, never
everything up to the last slash. `origin/feature/foo` reduced to `foo` does not match
`feature/foo`, and accepting it as a parent makes the review cover only the unpushed
commits — or, once the branch is pushed, nothing at all.

### 2. Otherwise, the default branch

Ask Git for the ref named by `refs/remotes/origin/HEAD`; when present and resolvable, that
is the remote's own default — `origin/main`, usually. If it is absent or dangling, take
the first of `origin/main`, `origin/master`, `main`, `master` that resolves to a commit.
An absent symbolic ref or unresolved candidate is an expected negative probe, not a Git
command failure. An operational error while performing the probe is still a failure.

Then ask Git whether it shares history with `HEAD`. A report that no merge base exists is
an expected negative answer, not an operational failure.

If nothing resolves, or what resolves shares no history with `HEAD`, **ask the user to name
a base** and stop until they answer. Do not go looking through the repository's refs for
one: ranking candidates by how much they would review is the heuristic that was wrong four
times, and it is no better for being presented as a menu.

**A stacked branch with nothing recorded is reviewed against the default branch**, so the
range includes the parent's commits too. That is intended. In `master -> A -> B` with no
pull request and no upstream, nothing in the topology marks `A` as the base — only the
user's intent does, and stating it is one phrase: *review this branch versus A*, which step
1 above takes as a recorded base. The announcement below names the base and how it was chosen,
which is what makes a wrong one correctable in one line rather than invisible.

### 3. Resolve the fork point once, and then use only that

Ask Git for the merge base of the resolved base and `HEAD`. That SHA is the base of the
review. **Every operation that reads committed history uses `<sha>..HEAD` and nothing
else** — the announcement, the briefing, the reviewer prompt, every commit-range diff and
log.

Never write `<base>..HEAD` with the ref name. Two-dot diff compares two endpoint *trees*,
so the moment the base branch gains a commit after your fork, that commit shows up in the
diff as a deletion the branch never made. `<base>...HEAD` is equivalent to the SHA form
and is safe, but prefer the SHA: it removes the decision from every call site instead of
requiring four of them to remember it.

(Revision listing and diff interpret two-dot ranges differently: revision listing walks
commits, while diff compares endpoint trees. That asymmetry is why the fork-point SHA is
resolved once here rather than trusted to each caller.)

#### The range covers commits. It does not cover the working tree.

A committed-tree diff for `<sha>..HEAD` compares two *committed* trees. Staged, unstaged,
and untracked changes appear in none of it, and they are in scope by default. Read them
separately, and always — not only when you have reason to think something is there:

Read all four surfaces separately with read-only Git operations: the committed tree diff
for `<sha>..HEAD`, the staged diff, the unstaged diff, and status including untracked
paths. Do this even when there is no prior indication that the working tree is dirty.

In the no-commits-and-dirty case below, the fork point *is* `HEAD`. The range is empty and
the working tree is the entire artifact. A rule reading "the range and nothing else" would
review nothing there, produce no error, and look exactly like a clean review.

### Refusals

Stop and say why. Do not continue with an unrecorded non-default base inferred from
topology.

- **Detached HEAD** — there is no working branch artifact. Ask the user to select a
  branch or choose another target; naming a base does not create a working branch.
- **An unknown ref**, or a base sharing no history with `HEAD` — except where that base is
  the default branch, which step 2 turns into a question rather than a refusal.
- **An operational Git failure.** Expected negative results during default-base
  resolution are not operational failures: `origin/HEAD` may be absent, a fallback
  candidate may not resolve, and a candidate may have no common ancestor with `HEAD`.
  Handle those results as step 2 specifies. If an operation such as reading the commit
  count or status actually errors, the repository may be corrupt or unreadable; reporting
  zero commits on a clean tree would silently cancel the review while looking exactly like
  a branch with nothing on it.

### Announce before calling Codex

State the base, the fork point, how the base was determined, and the commit count:

```
Reviewing 7 commits on feat since master (fork point a1b2c3d, from the pull request base)
Reviewing 9 commits on B since main (fork point e4f5a6b, the default branch), working tree dirty
Reviewing 2 commits on B since A (fork point c7d8e9f, the base you named)
```

A wrong base silently reviews the wrong code, and the user is the only one who can catch
it. Say how the base was chosen, always — `the default branch` is the line that lets
someone standing on a stacked branch answer "no, versus A" before a review call is spent.
State it and proceed; do not turn it into a question.

- **No commits and a clean tree means stop.** There is nothing to review; spend no review
  call.
- **No commits and a dirty tree is legitimate** — uncommitted work sitting on the base.

Uncommitted tracked and untracked changes are in scope by default. Say so explicitly in
the briefing so Codex does not review the commits alone.

## Briefing sources

Do not use conversation context as stated intent for a branch target. Its stated intent
comes from repository and hosting records — the author's own claims about the change:

- The PR body and title, verbatim, through the available GitHub tooling if a PR exists.
- The commit messages in `<sha>..HEAD`, verbatim — full hashes and bodies included, with
  an unambiguous delimiter between commits. Do not use an abbreviated log format that
  drops commit bodies.
- The linked issue, verbatim, if the PR references one.

If none of these exist, say so plainly in the briefing: *there is no stated intent for
this branch.* Do not manufacture one, and do not substitute your own reading of the
diff — that is exactly the interpretation the briefing rule forbids, and it would make
the derived-vs-stated comparison circular.

The base is scope, not intent. Which base the user picked belongs in the briefing's
`## Scope`; *why* they picked it does not belong anywhere in the briefing.

## Review policy

`policy/unfamiliar.md`, always. A branch target is defined by repository state rather
than session authorship, even if you happened to create some current changes in this
conversation. Do not rely on potentially incomplete authorship context.

**Reviewer scope line:** `` `<sha>..HEAD`, plus uncommitted tracked and untracked changes ``,
with the fork-point SHA written out literally. The policy tells the reviewer to use the
scope exactly as given rather than constructing its own; that instruction only works if
what you hand it is already anchored.
