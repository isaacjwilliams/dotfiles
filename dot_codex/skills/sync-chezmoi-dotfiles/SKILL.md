---
name: sync-chezmoi-dotfiles
description: Review, import, and commit live changes to files already managed by chezmoi while preserving templates, secrets, and unrelated repository work. Use when a user asks which tracked dotfiles changed, wants changed home configuration added back to a chezmoi source repository, or wants those updates committed with a matching message.
---

# Sync Chezmoi Dotfiles

Safely reconcile changed managed files from chezmoi's target directory into its source repository. Limit mutations to the user's requested scope.

## Inspect

1. Resolve the source repository with `chezmoi source-path` and inspect its Git status before changing anything.
2. Run `chezmoi status` and `chezmoi diff --no-pager` to identify changed managed targets and understand their content changes.
3. Treat `chezmoi diff` as a diff from the current live target to chezmoi's managed desired state. When importing live changes, the resulting source-repository diff will generally have the opposite orientation.
4. Confirm each candidate is already managed with `chezmoi source-path <target>`. Do not add unrelated or newly discovered home-directory files unless the user explicitly requests them.
5. Report sensitive-looking content without echoing secret values. Never import credentials, tokens, session data, or machine-local state merely because a path appears in a status listing.

If the user asks only for a check, stop after reporting the read-only findings.

## Import

1. Map every selected target to its source path before importing.
2. Preserve pre-existing source-repository changes. If a selected source path already has uncommitted changes, do not overwrite it; explain the overlap and ask how to reconcile it.
3. Inspect templated source paths before acting. Do not replace a `.tmpl` file with a rendered target. Reconcile the live change into the template and verify its rendered output instead.
4. Import exact files, not broad directories, with `chezmoi add --secrets error <target>...`. This keeps the privacy boundary explicit and prevents neighboring files from being swept in.
5. Re-run `chezmoi status` and `chezmoi diff --no-pager`. Investigate any selected path that remains divergent.
6. Review `git diff --check`, the full source diff, and the source paths changed by the import. Ensure no unrelated files entered the change set.

Use format or syntax checks appropriate to the affected files. Account for formats such as JSONC that intentionally fail strict JSON parsing.

## Commit

Commit only when the user asks for a commit.

1. Summarize the behavior represented by the source diff, not just the filenames.
2. Choose a concise imperative commit subject matching the main changes. Split unrelated logical groups when the user requests separate commits or when doing so is necessary to preserve an existing separation.
3. Stage exact source paths with `git add -- <paths>`, then inspect `git diff --cached --check`, `git diff --cached`, and `git status --short`.
4. Commit the staged paths without amending or rewriting existing commits unless explicitly requested.
5. Verify the new commit, repository status, and final `chezmoi status`. Do not push unless explicitly requested.

In the handoff, list the imported target files, commit hash and subject, validations performed, and any unrelated work left untouched.
