# How I like code to be shaped

These are my preferences from reviewing a lot of agent-written code. They apply in every project. A project's
own AGENTS.md or CLAUDE.md wins where they conflict. When a plan or a diff goes against one of these, say so and
let me decide; don't quietly work around it.

## Structure

- **One unit, one audience, one job.** A route, controller, class or view that serves two audiences (public
  visitors and the people who manage the thing, say) gets split, so neither has to branch on who is looking.
  Role checks scattered through a view mean the structure is wrong, not that the view needs tidying.
- **Branches and plumbing are design smells.** A third branch in a view, a chain of `select`/`group_by`/
  `index_by`, or a subclass blanking out methods it inherited all tell me the model isn't expressive enough or
  the hierarchy is wrong. Fix the model or the hierarchy; don't add another branch.
- **Pass a model, not loose values.** When a new value has to be threaded through many signatures, there should
  be an object that carries it from where it's computed to where it's used. Usually one already exists and is
  being unpacked too early.
- **One concept, not two near-twins.** Don't keep two shapes of the same idea, one for memory and one for a
  payload, say. Give the one concept a way to serialize and rehydrate itself.
- **Respect what an abstraction is for.** If a wrapper exists to run a mutation and handle its side effects,
  side effects go in the wrapper's handling, not into the mutation block.
- **Abstractions earn their place today.** No one-method collaborators or intermediate classes, no keying or
  configuration for cases nobody has yet ("not worth it"). Equally, don't leave a too-small module standing on
  its own; fold it into its one caller.
- **Use what the codebase, framework and libraries already give you** before writing your own: an existing
  helper or pattern, type casting, validation contexts, resourceful routes, the authorization path the app
  already uses, the design system's helpers, the gem's own validation. If you hand-roll one, say why the
  built-in one didn't fit. Follow the local patterns of the code you touch.

## Complexity is a signal

- **Obvious over clever.** Code should make sense to a competent teammate who hasn't read the surrounding
  files. If a line only makes sense with context from three files away, restructure it, or leave a comment
  that says why.
- If a comment, a PR description or an explanation needs to be long, or full of "or", "but" and "except", the
  interactions are too complex. Simplify them so each component's rule can be stated without caveats, rather
  than explaining the complexity better.
- When a comment is hard to follow, check whether the code is the real problem before polishing the comment.

## Finish the job

- Leave the code you touch easier to work with. If it fights you, do a small preparatory refactor first, in
  its own commit before the feature commit.
- Don't cut a refactor short of its potential. Question constraints whose reasons are historical ("is it still
  necessary, or just pre-established?") and remove the ones that are.
- Compatibility code, legacy paths and fallbacks need a stated reason and an end date. If nothing current needs
  them, remove them in the same change. I'd rather accept a short, known deploy window (and be told what it
  costs) than carry a two-release migration.
- A closely related defect or edge case found on the way gets fixed in the same PR when it's cheap. Tell me the
  cost and I'll decide; don't just list it as a follow-up.
- Don't bend a design to an invented constraint, like "no extra query" or "under 100 lines". Measure the real
  cost and report it.

## Names

- Name things for what they mean in the domain and for what's passed in (`pinned_wave_id`, not
  `selected_wave_id`, when the caller passes the pinned wave). Name the outcome, not the mechanism. Keep names
  consistent with neighbouring code.
- A name that's become false is a bug: `guest_user_sign_up` that handles every sign-up, "legacy" on the only
  path there is.

## Comments and prose

- Comments must read plainly on first pass: short sentences, ordinary words, no dense jargon. A comment that
  makes the code harder to follow should be rewritten or deleted.
- Every factual claim in docs, release notes or a PR description is checked against the code or the data
  first. "What does the data show?" is the question I'll ask.
- Use domain words precisely. A prerequisite that is one way in "qualifies for" the next stage; it doesn't
  "require" it.

## UI copy and behaviour

- Wording is natural and short. Round numbers to what a person needs (95%, not 95.2%). Summarize ("27 waves
  with 19 contestants will also be deleted") rather than listing everything. Confirmation dialogs ask a
  question and use plain verbs on their buttons ("Cancel", "Delete"). Bold the facts that matter.
- The most-used action sits on the outer edge of a control group.
- Where a pattern should apply everywhere (dialogs as sheets on mobile, say), extract it once so each use only
  declares it, instead of handling each instance.
- API docs state formats (dates, for example) so nobody has to guess and read an error to learn them.

## Tests

- Organize and write tests the way the project already does, not by feature or by PR.
- A test's name says what it checks.

## Commits

- Commits are small and logical, with messages in the project's style. Squash "WIP" and "fix" commits locally
  before pushing.
- No drive-by changes to unrelated code or formatting, or to files that belong to other work.

## Working with me

- When you're unsure of a design, offer the options with a recommendation. For an interface other code will
  depend on, propose it before writing it. For names and smaller shapes, show me code: I won't know how a name
  feels until I see it in place.
- Push back when you can support it. My understanding of the domain or the code is sometimes wrong, and I
  would rather hear it.
