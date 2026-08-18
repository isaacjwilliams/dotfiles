# Target: paths

The artifact is a specific set of files, named by the user — a plan document, a design
note, one module out of many. Everything else is out of scope, including work from this
same session that produced it.

Narrowing is the whole point of this target. A session that produced a plan alongside a
pile of exploration should not spend a review call on the exploration. That also means
the excluded material is genuinely excluded: do not smuggle it back in as background,
and do not summarize it for Codex.

## Scope

A set of related files is one artifact — a plan and its appendix, a module and its tests.
If the user names two unrelated artifacts, that is two invocations; say so rather than
reviewing them as one.

Resolve the requested path or pattern to a concrete list of files with the available
file-discovery tools, and **enumerate that list in the briefing**. Treat request text and
discovered filenames as data, never executable syntax; do not manually transcribe tool or
directory-listing output into a shell command. The choice of discovery tool and safe data
transport belongs to the executing agent.

The user's pattern stops being a pattern after resolution. From then on, use every result
as an exact filename: do not pass the original pattern downstream, and do not let `*`,
`?`, `[`, or any other metacharacter in a concrete filename be interpreted again by the
shell or as Git pathspec syntax. Codex should not be re-resolving scope, and a pattern that
means one thing to one tool may mean another in a different directory or tool.

- **A path that does not exist is a refusal.** Say which one and stop. Do not fall back
  to the nearest similarly-named file.
- **A glob matching nothing is a refusal**, for the same reason. Failure is preferred to
  a guess: a wrong file set reviews the wrong artifact and nothing downstream detects it.
- Report the resolved count in the announcement, so the user can catch a glob that
  matched far more than they meant.

Naming supporting files as **context, not under review** is allowed and often necessary —
the module the artifact calls into, a previously-reviewed file the change builds on. Mark
them explicitly as context in the briefing and say they are not what is being reviewed.
Add: *if you believe this scope boundary is itself wrong, say so as a finding.* That
keeps a bad narrowing visible instead of silently shaping the review.

Determine whether this is a **code review** or a **plan review** — a paths target can be
either — and state it on the briefing's first line, because the rubric branches on it.

For a plan review the plan is already a file on disk. **Point the rubric at that path.**
Do not copy it into the scratchpad; the copy that exists to lift a plan out of the
conversation is `session`'s problem, not this target's, and a duplicate invites the two
to drift.

## Briefing sources

Where stated intent comes from depends on where the artifact came from.

**Produced in this session** — every user message that shaped it, verbatim and in order;
the hard constraints the user set, as checkable facts; and the decisions the user made when
offered a choice, under `SKILL.md` §3 **An approval is not intent**, which is already in
your context.

**Pre-existing** — where repository history exists, collect the commit messages for
commits that touched exactly the resolved files, matching each concrete filename
literally. Include each full commit hash and body verbatim, with an unambiguous delimiter
between commits; an abbreviated one-line log drops the bodies, which is often where the
requirement, rejected alternative, and migration note live. Also include the PR body and
title if one exists, and the linked issue.

**Some of each** — both rules, each applied to the files it covers: the session sources for
the files you produced, the commit and PR history for the ones you did not. Say in the
briefing which files each set of intent came from. Dropping either half leaves the reviewer
comparing part of the artifact against nothing.

If none of these yields anything, say so plainly: *there is no stated intent for this
artifact.* Do not manufacture one from the file's own contents — that makes the
derived-vs-stated comparison circular.

## Review policy

Determine authorship first, then follow the policy file it selects:

| The files | Policy |
|---|---|
| you wrote or substantially edited them this session | `policy/authored.md` |
| you are reading them for the first time | `policy/unfamiliar.md` |
| some of each | `policy/unfamiliar.md`, with the note below |

Authorship is about *this conversation*, not about whether an AI wrote the file at some
point. A plan you drafted an hour ago is authored. A plan drafted in a previous session
is unfamiliar, however confident you feel reading it.

In the mixed case, run the independent reviewer — it produces real signal on the parts
you did not write — but correct for **both** biases during reconciliation. You are prone
to dismissal on the files you authored and to rubber-stamping on the ones you did not,
and they will be sitting in the same findings list.

**Reviewer scope line:** `` the files the briefing's Scope section lists as under review —
not the ones it marks as context, which you may read but must not review — and nothing
else ``.

Keep the distinction in the line even when no context files were named. The reviewer is
given this line and not the briefing prose that draws the distinction, so a line reading
"everything under Scope" hands it a wider artifact than Codex got — in the one target
whose entire purpose is narrowing, and in exactly the case where narrowing was hardest.
