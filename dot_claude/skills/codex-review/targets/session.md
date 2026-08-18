# Target: session

The artifact is the work produced in this conversation — a plan you proposed, or code
you changed, and occasionally both. You wrote it, and you are about to judge criticism of
it.

## Scope

### The artifact is an enumeration, not a range

You witnessed this work. Which files you created or edited, which commits you made, and
whether the tree is dirty are facts you hold first-hand. Write them down; do not ask Git
to reconstruct them.

**Do not resolve a base ref or a merge base here.** A fork point can only be recovered by
inferring one from history — ranking candidate refs by how much each would review — and a
wrong one reviews the wrong commits while looking exactly like a correct review. It is
also unnecessary: nothing about a session review depends on where the branch diverged. A
user who wants a fork-point review can say `branch` in one word, and that target resolves
its base from a recorded fact instead of from topology.

So enumerate:

- **The paths you created or edited**, as absolute paths.
- **The commits you made in this conversation**, by full SHA — you have them because you
  ran them. Where a range is convenient, anchor it on the first commit *you* made, never
  on a fork point Git derived.
- **Whether staged, unstaged, and untracked changes are in scope.** They are, by default.

Deciding *which* paths are in scope is scope resolution and Codex is entitled to it. *Why*
those paths matter is interpretation and stays out of the briefing, under `SKILL.md` §1.

If the working tree is not a git repository, the enumeration is the same one minus the
commits. Say so rather than leaving the absence unexplained.

### Nothing produced means stop

A conversation that only explored, read, or discussed has no artifact. If you created and
edited no files, made no commits, and proposed no plan, **say there is nothing for Codex
to review and stop.** Spend no review call. That is a legitimate outcome, not a failure —
and it is a better one than briefing a reviewer on an empty scope, which returns a clean
review of nothing and is indistinguishable from a clean review of something.

### Code, plan, or both

Determine whether this is a **code review** (changes on disk) or a **plan review** (a
proposed approach, not yet implemented). The rubric branches on it and it takes exactly
one value.

A session can hold both — a plan, and a partial implementation of that plan. That is two
artifacts, so it is two invocations. Say so and ask which one the user wants rather than
merging them, because a merged review reads the plan as documentation for the code and the
code as evidence for the plan, and stops testing either against anything independent.

### Announce the enumeration

`SKILL.md` §1 requires announcing the resolved values before any review call is spent. A
session target has no scope parameter to print, so the enumeration is what gives that
announcement content:

```
Reviewing this session's work — 3 files, 1 commit (a1b2c3d), working tree dirty — session, code review, 1 round
Reviewing this session's work — the plan, not yet implemented — session, plan review, 1 round
```

State it and proceed; do not turn it into a question. This is the user's one chance to say
*you missed the migration* or *don't review the scratch script*, and they are the only
party who can catch either. Announcing the bare target instead is worthless: `session` is
true of every possible scope, so it checks nothing.

## Briefing sources

Stated intent comes from the user. Include, verbatim:

- Every user message that shaped the work, in order.
- The hard constraints the user set, as checkable facts.
- The decisions the user made when you offered them a choice — under the rule below, which
  is narrow and fails closed.

The rule for that third bullet — what an approval does and does not carry — is
`SKILL.md` §3, **An approval is not intent**. It is already in your context; do not read
another target file to find it.

For a plan review, write the plan verbatim to `<scratchpad>/codex-review-plan.md` and
reference that path. It is the artifact, and Codex must derive intent from it before
reading your request — which it cannot do if the two arrive in one document. For a code
review there is no plan file; the code is the artifact.

## Review policy

`policy/authored.md`, always. By definition you produced this session's work, so what you
do while Codex reviews and which bias you correct for are both fixed for this target.
