# Target: session

The artifact is the work produced in this conversation — a plan you proposed, or code
you changed. You wrote it, and you are about to judge criticism of it.

## Scope

Determine whether this is a **code review** (changes on disk) or a **plan review** (a
proposed approach, not yet implemented). If code, resolve the comparison explicitly:
base ref or merge base, and whether staged, unstaged, and untracked changes are all in
scope. If the working tree is not a git repository, say so and list the in-scope paths
individually.

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
