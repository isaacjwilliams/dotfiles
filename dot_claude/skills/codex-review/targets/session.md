# Target: session

The artifact is the work produced in this conversation — a plan you proposed, or code
you changed. You wrote it, and you are about to judge criticism of it.

## Review units

One. The session's work is a single artifact.

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
- The decisions the user made when you offered them a choice, with the option they
  picked — these are the ones most likely to look like mistakes to a reviewer who
  doesn't know they were chosen deliberately.

For a plan review, write the plan verbatim to `<scratchpad>/codex-review-plan.md` and
reference that path. It is the artifact, and Codex must derive intent from it before
reading your request — which it cannot do if the two arrive in one document. For a code
review there is no plan file; the code is the artifact.

## While Codex reviews

Do no further work on this review; wait for Codex's result.

You already hold the full context of this work, so a second pass by you adds no
independent signal — it would reproduce the same reasoning that produced the artifact,
including whatever is wrong with it. Do not launch a reviewer subagent, and do not spend
the wait re-reading your own diff looking for things to pre-emptively defend.

The call is handed back to you as a background task after roughly 120 seconds. That is
not an invitation to start reviewing; the reason to hold off is independence, not
blocking. Unrelated work the user asks for in the meantime is fine.

## The bias to correct for

You are evaluating criticism of your own work. Assume you are tilted toward dismissal
and correct for it. The failure mode here is a finding you talk yourself out of because
you remember why you did it that way — and remembering why is not counter-evidence.
