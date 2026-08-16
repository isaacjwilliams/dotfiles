# Code Review

Code review is read-only unless the user explicitly asks to address findings.

## Review Scope

Resolve the requested comparison exactly. For a branch review, inspect staged, unstaged, and untracked changes against
the stated base branch or merge base. Read the relevant production code, tests, documentation, and callers rather than
reviewing the diff in isolation.

Review for:

- Data flow and persistence correctness.
- Logic errors, regressions, race conditions, and stale-state behavior.
- Authorization and ownership boundaries.
- Rails and object-oriented design.
- Public and internal interfaces that are broader than current callers require.
- Speculative compatibility, defensive code, and legacy runtime paths.
- Test gaps, incorrect test layers, production-path mismatches, and vacuous assertions.
- Performance and query-shape regressions.
- Dead code and incomplete migrations from previous approaches.
- Naming, responsibility, locality, and cognitive load.
- Plan, documentation, and stated-requirement conformance.

## Findings

Prioritize actionable findings using:

- `must fix`: correctness, data loss, security, authorization, production failure, or material regression.
- `should fix`: substantial maintainability, testing, performance, or design issue that belongs in the current work.
- `fix later`: valid improvement outside the current completion contract.
- `nitpick`: low-impact clarity or consistency issue.

For each finding:

- Name the concrete failure or maintenance cost.
- Cite the relevant code path and affected caller or user flow.
- Explain the causal chain rather than only describing suspicious code.
- Distinguish a proven defect from a question or preference.
- Recommend the smallest coherent correction without implementing it.

Do not inflate the review with findings that lack a demonstrated caller, behavioral consequence, or maintenance cost.

## Review Conclusion

Summarize:

- The intended change.
- Whether the implementation actualizes that intent.
- Preserved and changed behavior.
- Verification already present and important gaps.
- Whether the work is ready to merge after the listed findings.

When no findings remain, say so directly and identify any residual verification limits.

## Persisted class names

When a change renames a class, check whether its name is stored in an STI `type` column or a polymorphic association's
type column. Require a data migration for stored values so existing rows continue resolving. This includes framework
features such as Action Text and Active Storage, where a missed polymorphic type update can make attached content appear
to vanish without deleting it.

## Derived intent vs. stated intent

Derive intent first, from the artifact under review, and commit it to writing as `Derived intent` in the conclusion
before you read any stated intent. Which artifact that is depends on the review type, named at the top of the briefing:

- **Code review** — derive from the code and tests alone. The briefing's stated intent is off-limits until you have
  written your own. Where the change is a range of commits, commit messages and any pull request description are
  *stated* intent, not derivation material — they are the author's claim about the change, exactly like the briefing's.
  Read what the code does before you read what it was said to do.
- **Plan review** — there is no implementation to derive from; the plan *is* the artifact. Derive intent from the plan
  document alone, read as a proposal on its own terms, before you read the user's request in the briefing. The plan is
  supplied as its own file, separate from the briefing, precisely so this ordering is possible.

Only then read the stated intent in the briefing. Record it as `Stated intent` and compare:

- If they agree, say so in one line.
- If they diverge, that divergence is itself a finding, severity assigned on its consequences. Divergence means either
  the artifact fails to communicate its own purpose, or the wrong thing was built or proposed. Say which and why.

The briefing carries primary sources only — the author's own words, whether those are the user's messages or a pull
request description and commit messages; an approved plan; scope pointers. It deliberately contains no summary or
justification from the agent whose work you are reviewing. If it states that no intent was recorded for this change,
that is a fact about the change, not a gap for you to fill by inference. Treat any framing you infer as unverified, and
never let the briefing substitute for reading the code.
