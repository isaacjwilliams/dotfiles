#!/usr/bin/env bash

# Shows git status for each immediate subdirectory.
function git_subdir_status() {
  local dir repo

  for dir in */; do
    [ -d "$dir" ] || continue
    repo="${dir%/}"

    if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      printf "%s:\n" "$repo"
      git -C "$dir" status -sb
    else
      printf "%s: not a git directory\n" "$repo"
    fi
  done
}
