# Policy: unfamiliar work

You did not produce the artifact under review. A target file points here when that is
true; `policy/authored.md` covers the case where you wrote it yourself.

Because you have no authorship context, a second independent review is worth running —
it is genuine signal rather than an echo of the reasoning that produced the artifact.

## While Codex reviews

Launch an independent Claude review that runs concurrently, then make the Codex call.
Launch first: the MCP call holds the foreground initially and is handed back to you as a
background task only after roughly 120 seconds, so anything started afterwards loses
that much overlap for no reason.

```
Agent  subagent_type: general-purpose
       description:   "Independent review"
       prompt:        see below
```

Substitute `<scope>` with the **reviewer scope line** your target file specifies, and
`<review root>` with the review root resolved in `SKILL.md` step 2.

> Review `<scope>` in `<review root>` adversarially. Use the scope exactly as given; do not
> widen it or reconstruct it for yourself. Follow the rubric at
> `~/.claude/skills/codex-review/review-rubric.md` exactly, including its
> `Derived intent vs. stated intent` section — derive intent from the artifact before you
> read the stated intent in `<scratchpad>/codex-review-briefing.md`.
> Use `git --no-optional-locks` for status and diff. Do not modify anything; this is a
> review.
> Return your findings in the rubric's format. Your report is the deliverable — it goes
> to a reconciliation step, not to a human, so return findings rather than prose.

Same rubric and same briefing as Codex, deliberately: the two reviews are only
comparable if they were asked the same question.

The two reviewers are isolated, so neither can anchor on the other and independence
holds regardless of which returns first. Do not relay anything between them while both
are running, and do not begin `SKILL.md` step 5 until both have returned.

## The bias to correct for

Not dismissal — you have no stake in this code. Two other failure modes replace it:

- **Rubber-stamping.** You lack the context the author had. A finding you cannot
  evaluate is `uncertain` and goes to the user; it is not an implicit pass.
- **Treating your own review as the yardstick.** You now hold a competing set of
  findings. That makes it tempting to score Codex against yourself. Both reviews are
  evidence; neither is the answer key. Agreement between them is corroboration, not
  proof — two agents can share a wrong prior about an unfamiliar codebase.
