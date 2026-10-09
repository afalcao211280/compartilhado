#!/usr/bin/env bash

alias k='kubectl'
alias kgp='kubectl get pods'
alias kdp='kubectl describe pod'
alias klfp='kubectl logs -f --prefix'
alias kgs='kubectl get svc'
alias kgd='kubectl get deploy'
alias kgn='kubectl get nodes'
alias kga='kubectl get all'

kns() {
  if [[ -z "$1" ]]; then
    kubectl get namespaces
    return
  fi
  kubectl config set-context --current --namespace="$1"
  echo "Switched to namespace: $1"
}

kctx() {
  if [[ -z "${1:-}" ]]; then
    kubectl config get-contexts
    return
  fi
  kubectl config use-context "$1"
}

kwatch() {
  local ns="${1:-default}"
  watch -n 2 "kubectl get pods -n $ns"
}

alias h='helm'
alias hl='helm list'
alias hi='helm install'
alias hu='helm upgrade'
alias hr='helm rollback'