---
name: codex-review
description: Adversarial second-opinion review by Codex gpt-5.6-sol at xhigh reasoning, read-only, followed by up to two Claude rebuttal rounds. Say what to review in plain language — this session's work (a plan or code changes), the working branch against an explicit, recorded, or default base, or a named set of files. Manual invocation only.
disable-model-invocation: true
argument-hint: "<what to review, in your own words>"
allowed-tools: mcp__codex__codex, mcp__codex__codex-reply, Agent, AskUserQuestion, Read, Write, Grep, Glob, Bash
---

# Codex adversarial review

Send work to Codex for an independent, adversarial review; reconcile what comes back;
contest what is wrong; surface everything to the user.

## The request

> $ARGUMENTS

One string, as the user typed it — there are no positional arguments. Never reach for
`\$1` or `\$2` here: indexed placeholders are zero-based, so `\$1` is the *second* word and
a skill built on them silently reviews the wrong artifact. `\$ARGUMENTS` is the only safe
form. (The backslashes are escapes; without them this paragraph would itself be rewritten
with fragments of the request, which is the bug it warns about.)

Empty means `session` with the default round count.

## The one rule that matters

Codex must form its own view of the work. **Never send it your interpretation.**
The briefing carries primary sources and navigation only. If Codex inherits your
reasoning, it will confirm your mistakes instead of catching them, and a compromised
review reads exactly like a clean one.

| Send | Never send |
|---|---|
| Primary sources, verbatim — see the target file | Your summary of what the change does |
| The plan *under review*, verbatim, in its own file | An assistant proposal that a "yes" pointed at |
| Base ref / merge base, in-scope paths | Justification for a tradeoff you chose |
| Test and lint commands | Which findings you expect, or pre-emptive defense |
| Hard session facts ("user rejected polling") | Your reading of the user's intent |

Verbatim means verbatim. Quote; do not condense.

This holds for every reviewer, not just Codex. A Claude reviewer launched under
`policy/unfamiliar.md` gets the same briefing and the same rubric, and is told nothing
that Codex is not told.

## 1. Resolve the request

Read the request into exactly three values. Everything downstream depends on these and
on nothing else about the wording.

| Value | Domain | Default |
|---|---|---|
| **target** | `session`, `branch`, `paths` | `session` |
| **scope parameter** | a base ref for `branch`; a path or glob for `paths`; nothing for `session` | none |
| **rounds** | `0`, `1`, or `2` | `1` |

Worked examples:

| Request | target | scope | rounds |
|---|---|---|---|
| *(empty)* | session | — | 1 |
| `branch` | branch | a recorded base, otherwise the default branch | 1 |
| `the working branch versus master with 2 rounds` | branch | `master` | 2 |
| `the plan doc, no rebuttal` | paths | `<the resolved file>` | 0 |

The bare forms are not a separate syntax. `session`, `branch:master`, `paths:src/*.ts`
are simply requests unambiguous enough that reading them takes no inference.

### Rounds is capped at 2

A round is one Claude-disagreement → Codex-response exchange. `0` skips the rebuttal
entirely. **Refuse a request for more than 2** — say so and stop, rather than clamping
silently. Depth is a deliberate bound: past two exchanges the agents argue rather than
converge, and each round is a full reasoning pass.

### Interpretation is fenced

This is the one place the skill infers instead of reads. A misresolved request produces a
completely plausible review of the wrong artifact at the wrong depth, and nothing
downstream can detect it.

- **Announce all three values before spending a review call**, in the skill's own
  vocabulary: `Reviewing the working branch against master — branch:master, 2 rounds`, or
  `Interpreting "the plan doc" as paths:docs/plan-v2.md — plan review, 1 file, 1 round`.
  State it and proceed; do not turn it into a question. This announcement is the only
  thing standing between a misread request and a wasted review, so it is not optional and
  it is not a summary — print the resolved values.
- **Rounds is announced too, always, including when it was defaulted.** It is the value
  most easily lost in a long request, and getting it wrong changes review depth without
  changing anything the user can see.
- **Ask once if it is genuinely ambiguous** — two candidate files, or no way to tell
  whether the branch or the session is meant. Asking is cheap here because nothing has
  been spent yet. A target file may also require a question of its own during scope
  resolution — `branch` does when neither a recorded base nor the default branch can be
  resolved. Any such question comes before any review call.
- **Never let the interpretation reach the briefing.** Deciding *which* paths are in
  scope is scope resolution, and Codex is entitled to that. *Why* you think those paths
  matter is your reading of intent, and it is not. The announcement is for the user; the
  briefing gets the resolved file list and nothing about how you arrived at it.

## 2. Read the target file and resolve scope

Read exactly one file from `targets/`, matching the resolved target:

| Target | Artifact | File |
|---|---|---|
| `session` | the work produced in this conversation | `targets/session.md` |
| `branch` | commits since a recorded base, otherwise the default branch | `targets/branch.md` |
| `paths` | a named set of files, and nothing else | `targets/paths.md` |

The target file governs scope resolution, which primary sources go in the briefing, and
which policy file applies.

**Target files never delegate to each other.** "Same sources as `targets/session.md`" is
unfollowable from inside `paths`, because you may only read one of them — you would either
break that rule or brief from an abbreviation that has since drifted from the original.
Anything two targets share belongs in this file, which is already loaded.

Then read the one policy file your target names, from `policy/`:

| Policy | When | Governs |
|---|---|---|
| `policy/authored.md` | you produced the artifact in this conversation | what you do while Codex works, and which bias you correct for |
| `policy/unfamiliar.md` | you did not | as above, plus the independent Claude reviewer |

`session` always takes the first and `branch` always takes the second; `paths` decides.
Keep these separate from the targets — what is under review and whether you wrote it are
independent questions, and collapsing them is what made a `paths` target awkward to add.

Codex runs read-only, so it must use `git --no-optional-locks` for `status` and `diff` —
plain git may fail trying to take an index lock.

### Dynamic values are data, not command text

Shell snippets and Git notation in this skill describe required operations and semantics;
they are not commands that must be copied literally. Use the available tools and choose a
safe implementation for the environment.

Preserve every request-supplied ref and every discovered filename exactly as opaque data
from resolution through use. Never retype listing or tool output into executable syntax,
and never interpolate dynamic text as shell source. If the available tooling cannot carry
a value without evaluating or changing it, stop rather than silently operating on a
different value.

A user-supplied path pattern is pattern-bearing only while resolving scope. After it has
been resolved, use the resulting entries as exact filenames: do not pass the original
pattern downstream or let metacharacters in a concrete filename become shell globs or Git
pathspec syntax again. Keep values returned by Git as data too. The exact safe transport
mechanism is the executing agent's responsibility.

### The review root

Both reviewers need a working directory. Resolve it once, here, and use the same value for
Codex's `cwd` and for the Claude reviewer's prompt.

| Situation | Review root |
|---|---|
| the artifact is inside a git repository | the repository top level reported by Git |
| it is not | the deepest directory containing every in-scope path |

Not every artifact sits in a repository. The `session` target supports a non-repository
working tree explicitly, and a `paths` review can name files anywhere. An instruction that
just says "repository root" leaves an agent to invent one silently in exactly those cases.

**Write every in-scope path in the briefing as an absolute path**, whichever row applied.
The review root then only has to be a sensible place to run git from; it never becomes
load-bearing for locating the artifact. State it in the briefing's `## Scope`.

## 3. Write the briefing

Write to `<scratchpad>/codex-review-briefing.md`. First line states the review type —
`Code review` or `Plan review` — because the rubric branches on it to decide which
artifact intent is derived from.

Include only:

- **Stated intent**, verbatim, from the sources your target file names. Never your own.
- **Scope** — the review root, base ref, commit range, in-scope paths as absolute paths,
  any files named as context rather than under review, what is explicitly out of scope,
  and whether uncommitted changes count.
- **How to verify** — test command, lint command, how to run the app.
- **Hard constraints** — only checkable facts, stated flatly: "the user rejected the
  polling approach", not "polling was rejected because…".

If you catch yourself explaining, delete the sentence.

### An approval is not intent

Applies whenever any part of the artifact was produced in this conversation — `session`
always, `paths` when the files are yours. Skip it for work you did not produce.

"Yes, build that" adopts an action. It does not adopt your diagnosis, your rationale, or
the tradeoff you accepted. **Do not quote, summarize, or reconstruct the assistant-authored
proposal such an approval points at.** A proposal is built out of precisely what the
never-send column forbids, and importing it hands the reviewer your reasoning under the
name of the user's intent. It also corrupts the divergence check: derived-versus-stated
stops comparing the artifact against what was asked for and starts comparing it against
its own author's justification, which it will tend to match.

Record a decision only where it survives that intact — in practice, a choice you put to
the user through `AskUserQuestion`:

| Include | Form |
|---|---|
| the question | verbatim, as asked |
| the option labels | labels only — no descriptions, no rationale |
| the option picked, or the free-form answer | verbatim |
| `assistant-authored option, explicitly selected by the user` | as a provenance line |

This holds only when the selected label states an outcome or a constraint and stands
alone. **If extracting it needs paraphrase, dropped clauses, or an option description to
make sense, the exception does not apply.** Write this instead:

> The user approved a preceding assistant-authored proposal. No self-contained user-stated
> requirements were recorded for it; the proposal is excluded under the
> reviewer-independence rule.

That is a genuine gap and it belongs in the report's verification limits. Do not close it
by writing the proposal down. You may ask the user to state the outcome and constraints in
their own words before the review starts — their answer is a primary source. If they
don't, the briefing ships incomplete and says so.

A rationale does not become admissible because the user said yes to it.

**Use exactly these `##` headings, in this order:** `## Scope`, `## How to verify`,
`## Hard constraints`, `## Stated intent`. Level two, spelled that way, with stated intent
last. Those four and no others — decision records and any recorded gap are *part of* stated
intent, so they go inside `## Stated intent` as `###` subsections. A fifth `##` section
after it means stated intent is no longer last and the reviewer's isolation no longer has a
boundary it can trust.

This is not formatting preference. A reviewer following the rubric has to read the
artifact before it reads the stated intent, which means it must be able to find where
stated intent begins and stop there. A briefing that writes `# Stated intent` at level one
defeats the reviewer's own isolation and it will read intent first — that has already
happened, and it silently degrades the derived-versus-stated comparison into a
confirmation of whatever the briefing claimed. Nothing downstream can detect it; the
reviewer may not even report it.

## 4. Launch the reviewers

Do what the policy file's **While Codex reviews** section says *before* the Codex call —
the MCP call holds the foreground initially and is only handed back as a background task
after roughly 120 seconds, so anything meant to run concurrently must start first or it
forfeits that overlap.

```
mcp__codex__codex
  prompt:  see below
  model:   "gpt-5.6-sol"
  config:  { "model_reasoning_effort": "xhigh" }
  cwd:     the review root, resolved in step 2
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

## 5. Reconcile — this is not a formality

**Wait for every reviewer you launched.** Under `policy/unfamiliar.md` a Claude reviewer
runs concurrently and may still be working when Codex returns; subagents report back
independently, so nothing about Codex finishing says the other one has. Reconciling early
turns a two-reviewer review into a one-reviewer review, and nothing downstream can tell
that apart from a second reviewer that genuinely found nothing. A reviewer that failed or
stalled is a gap in coverage you report under step 7 — one that simply has not answered
yet is not.

Correct for the bias your policy file names; it differs by policy and the wrong
correction is worse than none.

Check every finding against the actual code — read the cited paths, trace the callers,
run the test if one settles it. Then classify each by provenance and verdict.

| Provenance | Meaning | What it needs |
|---|---|---|
| **Corroborated** | Codex and the Claude reviewer both raised it | Still cite evidence. Agreement is not proof; two agents can share a wrong prior. |
| **Codex only** | | Verify it yourself, then agree / disagree / uncertain. |
| **Claude only** | only under `policy/unfamiliar.md`, where a second reviewer ran | Verify it yourself, then put it to Codex in the rebuttal. |
| **Disputed** | the two reviewers contradict each other | Never resolve this silently. It goes to the rebuttal, and to the user either way. |

Verdicts:

- **Agree** — the finding stands. Say what you'd change.
- **Disagree** — you have concrete counter-evidence: a `file:line`, a passing test, a
  fact about the codebase. "I already considered that" is not counter-evidence. If you
  cannot cite something, it is not a disagreement.
- **Uncertain** — plausible but you cannot settle it. Uncertain goes to the *user*, and
  never gets quietly resolved in your favor.

**Which way an uncertain finding routes depends on who raised it**, and the two rules
read as a contradiction unless you take them in this order:

| Raised by | Uncertain means | Goes to rebuttal? |
|---|---|---|
| Codex | you cannot settle its finding | **No.** Arguing a point you cannot support is the failure mode the verdict exists to prevent. |
| the Claude reviewer | you cannot settle your own side's finding | **Yes.** It is new information for Codex, not an argument with Codex — and Codex is the one agent positioned to settle it. |

Uncertain reaches the user either way. The rebuttal is not a filter in front of the
report; nothing is withheld pending Codex's answer.

## 6. Rebuttal rounds (skip if there is nothing to put to Codex)

**The resolved round count is a ceiling, not a quota.** If there are no disagreements, no
disputed findings, and no Claude-only findings, skip this step — do not spend a turn
manufacturing one, and do not spend a second round because the request said 2.

Each round is one `mcp__codex__codex-reply` call with the saved `threadId`; it inherits
the thread's read-only sandbox. A round is four steps, not one:

- **Send** the open items, each with its evidence — see below.
- **Reconcile the response, by step 5.** Verify against the artifact, assign a verdict,
  and classify anything new. A rebuttal response is reviewer output like any other, so a
  finding Codex raises for the first time in one is a finding: step 7 does not let you
  drop it for arriving after the reconciliation step.
- **Recompute what is open.** Withdrawn, resolved, and newly-agreed items leave the list.
  What joins it follows the same provenance rule as step 5: a new Codex finding only if you
  have counter-evidence and disagree — never merely because you cannot settle it — and a
  Claude-only or disputed finding either way.
- **Stop** when that list is empty or the budget is spent, whichever comes first.

Send, each with its evidence:

- **Disagreements** — ask Codex to withdraw the finding or explain why the
  counter-evidence does not resolve it.
- **Claude-only findings** — ask Codex to confirm, refute, or reseverity them. This is
  the collaboration, and it is usually worth more than the argument.
- **Disputed findings** — put both readings to Codex and ask which survives.

A second round carries **only what the recompute left open**. Re-sending a settled finding to use
up the budget is the arguing the cap exists to prevent, and it invites Codex to relitigate
something it already withdrew.

Do not argue past the round budget. An unresolved disagreement is a legitimate outcome
to report, not a failure to fix.

## 7. Surface to the user

**Every finding any reviewer raised appears in your report, including ones you rejected,
ones Codex withdrew, and ones Codex raised for the first time in a rebuttal response.** You do not have discretion to drop a finding. The user decides
what is real; your verdict is annotation, not a filter.

```markdown
## Codex review — <target, and what it resolved to: the range for a branch, the file list for paths>

**Derived intent:** <Codex's, verbatim>
**Stated intent:** <as briefed, or "none stated" >
<agreement, or the divergence and what it implies>

### Findings

#### 1. [must fix] <title> — *corroborated | Codex only | Claude only | disputed*
> <the finding, verbatim from whoever raised it>

**Claude:** agreed / disagreed / uncertain — <evidence, file:line>
**Codex, round 1:** <verbatim, if a round addressed this finding>
**Codex, round 2:** <verbatim, if a second round did — omit the line if none did>
**Status:** resolved / unresolved / withdrawn

### Unresolved after rebuttal
<still in dispute — flag these for the user's judgment>

### Verification limits
<what the reviewers could not check; any stall or truncation; and stated intent that
could not be recorded under **An approval is not intent** in step 3>

### Review conclusion
<whether the implementation actualizes the intended change; behavior preserved and
changed; verification already present and the important gaps; whether the work is ready
to merge once the findings above are addressed>
```

The conclusion is not optional and not a summary of the findings list. `review-rubric.md`
requires every reviewer to produce one, so a report without this section silently discards
work the reviewers were told to do — and the rule above says nothing gets discarded.
Where the reviewers' conclusions disagree, say so rather than blending them.

Report a stalled or failed reviewer as a gap in coverage. A review that was supposed to
run two reviewers and got one back is a review with one reviewer, and the user should be
told that rather than left to assume corroboration was possible.

Do not act on any finding unless the user asks. This skill reviews; it does not fix.
