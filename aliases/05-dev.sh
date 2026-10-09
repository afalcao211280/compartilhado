#!/usr/bin/env bash

alias gor='go run'
alias gob='go build'
alias got='go test ./...'
alias gobv='go build -v ./...'

alias py='python3'
alias pipi='pip3 install'
alias pipu='pip3 install --upgrade'
alias pyr='python3 -m pytest -v'

venv() {
  local name="${1:-.venv}"
  if [[ ! -d "$name" ]]; then
    python3 -m venv "$name"
  fi
  source "$name/bin/activate"
  echo "Activated: $name"
}

alias ni='npm install'
alias nr='npm run'
alias ns='npm start'
alias nl='npm run lint'
alias nb='npm run build'

repolint() {
  echo "=== ESLint ==="
  npx eslint . 2>/dev/null || echo "eslint not configured"
  echo ""
  echo "=== Prettier Check ==="
  npx prettier --check . 2>/dev/null || echo "prettier not configured"
}