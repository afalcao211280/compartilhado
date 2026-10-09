#!/usr/bin/env zsh

alias gs='git status'
alias gl='git log --oneline -15'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'
alias grb='git rebase'
alias gcm='git commit -m'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias glast='git log -1 --pretty=format:"%h - %s (%cr)" && echo'
alias gsta='git stash push'
alias gstp='git stash pop'
alias gdno='git diff --name-only'
unalias glog 2>/dev/null
function glog() { git log --graph --pretty="%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset" --abbrev-commit -20 }

unalias gcb 2>/dev/null
function gcb() {
  git checkout -b "$1" "${2:-HEAD}"
}

function gdel() {
  local branch="$1"
  git branch -d "$branch" && git push origin --delete "$branch" 2>/dev/null
}

function gsync() {
  local remote="${1:-origin}"
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  git fetch "$remote"
  git rebase "$remote/$branch"
}