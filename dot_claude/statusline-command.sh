#!/bin/bash
# Claude Code status line: model name + context usage progress bar + token counts

input=$(cat)

# .worktree is only present for sessions entered via the worktree feature;
# .workspace.git_worktree covers a cwd that is a linked git worktree.
worktree=$(echo "$input" | jq -r '.worktree.name // .workspace.git_worktree // empty')
worktree_display=""
[ -n "$worktree" ] && worktree_display=$(printf "\033[2m[%s]\033[0m " "$worktree")

model=$(echo "$input" | jq -r '.model.display_name')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# current_usage is an object of token buckets (input, output, cache creation,
# cache read); occupancy is their sum. Tolerate a plain number as well.
tokens=$(echo "$input" | jq -r '
  .context_window.current_usage
  | if type == "object" then ([.[] | numbers] | add)
    elif type == "number" then .
    else empty end
  // empty')

if [ -z "$used" ]; then
  printf "%s\033[2m%s\033[0m\n" "$worktree_display" "$model"
  exit 0
fi

used_int=$(printf '%.0f' "$used")
[ "$used_int" -gt 100 ] && used_int=100
[ "$used_int" -lt 0 ] && used_int=0

bar_width=10
filled=$(( used_int * bar_width / 100 ))
empty=$(( bar_width - filled ))

bar=""
for ((i = 0; i < filled; i++)); do bar="${bar}#"; done
for ((i = 0; i < empty; i++)); do bar="${bar}-"; done

if [ "$used_int" -ge 80 ]; then
  color="\033[31m"   # red
elif [ "$used_int" -ge 50 ]; then
  color="\033[33m"   # yellow
else
  color="\033[32m"   # green
fi

# 91400 -> 91k, 1000000 -> 1m, 1240000 -> 1.2m
abbreviate() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000) { v = n / 1000000; u = "m" }
    else if (n >= 1000) { v = n / 1000; u = "k" }
    else { printf "%d", n; exit }
    s = sprintf("%.1f", v)
    sub(/\.0$/, "", s)
    printf "%s%s", s, u
  }'
}

counts=""
if [ -n "$tokens" ] && [ -n "$total" ]; then
  counts=$(printf " (%s/%s)" "$(abbreviate "$tokens")" "$(abbreviate "$total")")
fi

printf "%s\033[2m%s\033[0m  ${color}[%s]\033[0m \033[2m%s%%%s\033[0m\n" \
  "$worktree_display" "$model" "$bar" "$used_int" "$counts"
