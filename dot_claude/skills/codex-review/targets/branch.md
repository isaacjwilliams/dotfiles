# Target: branch

The artifact is the commits the working branch has added since it forked from its base,
plus any uncommitted changes. You did not necessarily write it. In a stack like
`master -> A -> B`, running on `B` reviews what `B` added on top of `A`.

## Review units

One. The branch is a single artifact.

(A future `stack` target splits this into one unit per PR plus a synthesis pass. Keep
the pipeline's handling of units generic; do not collapse it because there is one here.)

## Scope

Run the resolver rather than reasoning about merge bases yourself:

```bash
~/.claude/skills/codex-review/resolve-base.sh [explicit-base]
```

Pass the explicit base only if the user gave one as `branch:<base>`. On success it
prints `base`, `base_sha`, `range`, `method`, `commits`, `dirty`, and sometimes
`alternatives`. On failure it exits non-zero with a reason — that is a deliberate
refusal to guess, not a malfunction. Report it and stop; do not fall back to a base you
picked yourself.

**Use `range` verbatim wherever a commit range is needed.** It is `<base_sha>..HEAD`,
anchored at the merge base. Never write `<base>..HEAD` with the ref name: that compares
branch tips, so every commit the base branch gained after the fork shows up in the diff
as a deletion the branch never made. If you need three-dot form for a tool that wants
ref names, `base...HEAD` is the equivalent — but prefer `range`.

Then:

- **Announce the resolution to the user before calling Codex** — the range, how it was
  found, and the commit count: `Reviewing 7 commits on feat since master (fork point
  a1b2c3d, via nearest fork point among branch refs), working tree dirty`. A wrong base
  silently reviews the wrong code, and the user is the only one who can catch it. Do not
  turn this into a question; state it and proceed.
- **`commits=0` and `dirty=no` means stop.** There is nothing to review. Say so and
  spend no review call.
- `commits=0` and `dirty=yes` is a legitimate review of uncommitted work on the base.
- **`alternatives` present means the base was inferred from topology and may be wrong.**
  Include it in the announcement — `other candidates: old-topic(2)` — and say the user
  can rerun with `branch:<base>`. The ranking cannot tell a parent branch from a
  pre-rebase backup of the branch under review; the two have identical shapes. When
  `method` names a pull request base or a tracking branch, the base came from recorded
  metadata rather than inference and no alternatives are printed.

Uncommitted tracked and untracked changes are in scope by default. Say so explicitly in
the briefing so Codex does not review the commits alone.

## Briefing sources

You have no session context for this work, so there is no verbatim user request to
quote. Stated intent comes from the author's own claims about the change:

- The PR body and title, verbatim, via `gh pr view --json title,body` if a PR exists.
- The commit messages in `range`, verbatim.
- The linked issue, verbatim, if the PR references one.

If none of these exist, say so plainly in the briefing: *there is no stated intent for
this branch.* Do not manufacture one, and do not substitute your own reading of the
diff — that is exactly the interpretation the briefing rule forbids, and it would make
the derived-vs-stated comparison circular.

## While Codex reviews

Launch an independent Claude review that runs concurrently, then make the Codex call.
Launch first: the MCP call holds the foreground initially and is handed back to you as a
background task only after roughly 120 seconds, so anything started afterwards loses
that much overlap for no reason.

```
Agent  subagent_type: general-purpose
       description:   "Independent branch review"
       prompt:        see below
```

> Review `<range>` in `<repo root>` adversarially — that range is anchored at the merge
> base, so use it exactly as given rather than constructing your own. Follow the rubric
> at `~/.claude/skills/codex-review/review-rubric.md` exactly, including its
> `Derived intent vs. stated intent` section — derive intent from the code and tests
> before you read the stated intent in `<scratchpad>/codex-review-briefing.md`.
> Uncommitted tracked and untracked changes are in scope. Use `git --no-optional-locks`
> for status and diff. Do not modify anything; this is a review.
> Return your findings in the rubric's format. Your report is the deliverable — it goes
> to a reconciliation step, not to a human, so return findings rather than prose.

Same rubric and same briefing as Codex, deliberately: the two reviews are only
comparable if they were asked the same question.

The two reviewers are isolated, so neither can anchor on the other and independence
holds regardless of which returns first. Do not relay anything between them while both
are running.

## The bias to correct for

Not dismissal — you have no stake in this code. Two other failure modes replace it:

- **Rubber-stamping.** You lack the context the author had. A finding you cannot
  evaluate is `uncertain` and goes to the user; it is not an implicit pass.
- **Treating your own review as the yardstick.** You now hold a competing set of
  findings. That makes it tempting to score Codex against yourself. Both reviews are
  evidence; neither is the answer key. Agreement between them is corroboration, not
  proof — two agents can share a wrong prior about an unfamiliar codebase.
