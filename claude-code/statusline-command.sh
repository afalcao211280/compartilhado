#!/usr/bin/env bash
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "?"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Git branch
branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Progress bar for context window
bar=""
if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  filled=$(( used_int / 5 ))
  empty=$(( 20 - filled ))
  bar_fill=$(printf '%0.s#' $(seq 1 $filled) 2>/dev/null || python3 -c "print('#' * $filled)" 2>/dev/null)
  bar_empty=$(printf '%0.s-' $(seq 1 $empty) 2>/dev/null || python3 -c "print('-' * $empty)" 2>/dev/null)
  bar="[${bar_fill}${bar_empty}] ${used_int}%"
fi

# Build output
parts=""

# Model
printf '\033[0;36m\033[2m%s\033[0m' "$model"

# Separator
printf '\033[2m | \033[0m'

# Working directory (shorten home)
short_cwd="${cwd/#$HOME/~}"
printf '\033[0;33m\033[2m%s\033[0m' "$short_cwd"

# Git branch
if [ -n "$branch" ]; then
  printf '\033[2m | \033[0m'
  printf '\033[0;35m\033[2m %s\033[0m' "$branch"
fi

# Context bar
if [ -n "$bar" ]; then
  printf '\033[2m | \033[0m'
  if [ "$used_int" -ge 80 ]; then
    printf '\033[0;31m\033[2m%s\033[0m' "$bar"
  elif [ "$used_int" -ge 50 ]; then
    printf '\033[0;33m\033[2m%s\033[0m' "$bar"
  else
    printf '\033[0;32m\033[2m%s\033[0m' "$bar"
  fi
fi

printf '\n'
