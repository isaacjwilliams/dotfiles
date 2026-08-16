---
name: codex-review
description: Adversarial second-opinion review by Codex gpt-5.6-sol at xhigh reasoning, read-only, followed by a Claude rebuttal round. Reviews either this session's work (a plan or code changes) or the working branch against its nearest base. Manual invocation only.
disable-model-invocation: true
argument-hint: "[session|branch|branch:<base>] [rounds]"
allowed-tools: mcp__codex__codex, mcp__codex__codex-reply, Agent, Read, Write, Grep, Glob, Bash
---

# Codex adversarial review

Send work to Codex for an independent, adversarial review; reconcile what comes back;
contest what is wrong; surface everything to the user.

## Arguments

| Arg | Values | Default |
|---|---|---|
| `$1` target | `session`, `branch`, `branch:<base>` | `session` |
| `$2` rounds | integer, `0` = no rebuttal | `1` |

A round is one Claude-disagreement → Codex-response exchange. A bare integer in `$1` is
a round count, not a target — `/codex-review 1` means `session` with one round.

## The one rule that matters

Codex must form its own view of the work. **Never send it your interpretation.**
The briefing carries primary sources and navigation only. If Codex inherits your
reasoning, it will confirm your mistakes instead of catching them, and a compromised
review reads exactly like a clean one.

| Send | Never send |
|---|---|
| Primary sources, verbatim — see the target file | Your summary of what the change does |
| The approved plan, verbatim, in its own file | Why you believe the approach is correct |
| Base ref / merge base, in-scope paths | Justification for a tradeoff you chose |
| Test and lint commands | Which findings you expect, or pre-emptive defense |
| Hard session facts ("user rejected polling") | Your reading of the user's intent |

Verbatim means verbatim. Quote; do not condense.

This holds for every reviewer, not just Codex. A Claude reviewer launched under the
`branch` target gets the same briefing and the same rubric, and is told nothing that
Codex is not told.

## 1. Resolve the target and scope

Read exactly one file from `targets/`, matching `$1`:

| Target | Artifact | File |
|---|---|---|
| `session` | the work produced in this conversation | `targets/session.md` |
| `branch` | commits on the working branch since its nearest base | `targets/branch.md` |

The target file governs scope resolution, which primary sources go in the briefing, what
you do while Codex works, and which bias you are correcting for. It also yields the
**review units** — one for both current targets. The pipeline below runs per unit; keep
it that way even at one, so a future multi-unit target (a PR stack) is a new target file
rather than a rewrite of this one.

Codex runs read-only, so it must use `git --no-optional-locks` for `status` and `diff` —
plain git may fail trying to take an index lock.

## 2. Write the briefing

Write to `<scratchpad>/codex-review-briefing.md`. First line states the review type —
`Code review` or `Plan review` — because the rubric branches on it to decide which
artifact intent is derived from.

Include only:

- **Stated intent**, verbatim, from the sources your target file names. Never your own.
- **Scope** — base ref, commit range, in-scope paths, what is explicitly out of scope,
  and whether uncommitted changes count.
- **How to verify** — test command, lint command, how to run the app.
- **Hard constraints** — only checkable facts, stated flatly: "the user rejected the
  polling approach", not "polling was rejected because…".

If you catch yourself explaining, delete the sentence.

## 3. Launch the reviewers

Do what the target file's **While Codex reviews** section says *before* the Codex call —
the MCP call holds the foreground initially and is only handed back as a background task
after roughly 120 seconds, so anything meant to run concurrently must start first or it
forfeits that overlap.

```
mcp__codex__codex
  prompt:  see below
  model:   "gpt-5.6-sol"
  config:  { "model_reasoning_effort": "xhigh" }
  cwd:     repository root
```

`sandbox` and `approval-policy` are forced to read-only by the MCP proxy and cannot be
overridden from here. The proxy's timeout is staleness-only — 3 minutes of silence,
extended to 15 while a reasoning block or shell command is open — with no wall-clock
ceiling. Claude Code separately imposes a hard 60-minute per-server cap that no amount of
activity extends; that is a platform limit, not part of this design. If the tool returns
a cancellation error, **report the stall to the user**; never invent what the review
would have said.

Prompt (for a plan review, point the first line at the plan file as well):

> Adversarially review the work described in `<scratchpad>/codex-review-briefing.md`.
> Follow the rubric at `~/.claude/skills/codex-review/review-rubric.md` exactly,
> including its `Derived intent vs. stated intent` section — derive intent from the
> artifact named for this review type before you read the stated intent in the briefing.
> Use `git --no-optional-locks` for git status and diff; the sandbox is read-only.
> You are reviewing work produced by another AI agent. Be direct and specific. Do not
> soften findings, and do not manufacture findings to appear thorough.

Save the returned `threadId`.

## 4. Reconcile — this is not a formality

Correct for the bias your target file names; it differs by target and the wrong
correction is worse than none.

Check every finding against the actual code — read the cited paths, trace the callers,
run the test if one settles it. Then classify each by provenance and verdict.

| Provenance | Meaning | What it needs |
|---|---|---|
| **Corroborated** | Codex and the Claude reviewer both raised it | Still cite evidence. Agreement is not proof; two agents can share a wrong prior. |
| **Codex only** | | Verify it yourself, then agree / disagree / uncertain. |
| **Claude only** | only under `branch`, where a second reviewer ran | Verify it yourself, then put it to Codex in the rebuttal. |
| **Disputed** | the two reviewers contradict each other | Never resolve this silently. It goes to the rebuttal, and to the user either way. |

Verdicts:

- **Agree** — the finding stands. Say what you'd change.
- **Disagree** — you have concrete counter-evidence: a `file:line`, a passing test, a
  fact about the codebase. "I already considered that" is not counter-evidence. If you
  cannot cite something, it is not a disagreement.
- **Uncertain** — plausible but you cannot settle it. Uncertain goes to the *user*,
  never into the rebuttal, and never gets quietly resolved in your favor.

## 5. Rebuttal round (skip if there is nothing to put to Codex)

If there are no disagreements, no disputed findings, and no Claude-only findings, skip
this step — do not spend a turn manufacturing one. Otherwise call
`mcp__codex__codex-reply` with the saved `threadId`, once per round in `$2`. It inherits
the thread's read-only sandbox.

Send, each with its evidence:

- **Disagreements** — ask Codex to withdraw the finding or explain why the
  counter-evidence does not resolve it.
- **Claude-only findings** — ask Codex to confirm, refute, or reseverity them. This is
  the collaboration, and it is usually worth more than the argument.
- **Disputed findings** — put both readings to Codex and ask which survives.

Do not argue past the round budget. An unresolved disagreement is a legitimate outcome
to report, not a failure to fix.

## 6. Surface to the user

**Every finding any reviewer raised appears in your report, including ones you rejected
and ones Codex withdrew.** You do not have discretion to drop a finding. The user decides
what is real; your verdict is annotation, not a filter.

```markdown
## Codex review — <target, and the resolved range for a branch review>

**Derived intent:** <Codex's, verbatim>
**Stated intent:** <as briefed, or "none stated" >
<agreement, or the divergence and what it implies>

### Findings

#### 1. [must fix] <title> — *corroborated | Codex only | Claude only | disputed*
> <the finding, verbatim from whoever raised it>

**Claude:** agreed / disagreed / uncertain — <evidence, file:line>
**Codex's response:** <verbatim, if a rebuttal round ran>
**Status:** resolved / unresolved / withdrawn

### Unresolved after rebuttal
<still in dispute — flag these for the user's judgment>

### Verification limits
<what the reviewers could not check, and any stall or truncation>
```

Report a stalled or failed reviewer as a gap in coverage. A branch review where the
Claude reviewer returned nothing is a review with one reviewer, and the user should be
told that rather than left to assume corroboration was possible.

Do not act on any finding unless the user asks. This skill reviews; it does not fix.
