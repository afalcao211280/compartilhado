#!/usr/bin/env bash

alias oc='opencode'
alias oca='opencode --agent'
alias och='opencode --help'

alias ai='aider'
alias aif='aider --file'
alias aim='aider --model'

alias ol='ollama list'
alias olr='ollama run'
alias oll='ollama pull'
alias olp='ollama ps'

aichat() {
  local model="${1:-}"
  local prompt="${*:2}"
  if command -v opencode &>/dev/null; then
    opencode --prompt "$prompt" 2>/dev/null
  elif command -v ollama &>/dev/null; then
    ollama run "${model:-llama3}" "$prompt" 2>/dev/null
  else
    echo "No AI tool found. Install opencode or ollama."
  fi
}

codereview() {
  local target="${1:-.}"
  if command -v aider &>/dev/null; then
    aider --file "$(git diff --name-only HEAD~1 2>/dev/null || find "$target" -name '*.py' -o -name '*.js' -o -name '*.go' -o -name '*.ts' 2>/dev/null | head -10)" --message "Review this code for security vulnerabilities, performance issues, and best practices violations. Provide actionable feedback." 2>/dev/null
  elif command -v opencode &>/dev/null; then
    opencode --prompt "Review the code in $target for security vulnerabilities, performance issues, and best practices" 2>/dev/null
  else
    echo "No AI tool available. Install opencode or aider."
  fi
}