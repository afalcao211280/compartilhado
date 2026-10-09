#!/usr/bin/env bash

alias trs='trivy image'
alias trf='trivy fs'
alias trc='trivy config'

alias gls='gitleaks detect --source . -v'
alias glp='gitleaks protect --staged -v'

alias gys='grype'

alias tfs='tfsec .'

sec_scan() {
  local target="${1:-.}"
  echo "=== Trivy FS Scan ==="
  trivy fs --severity HIGH,CRITICAL "$target" 2>/dev/null || echo "trivy not available"
  echo ""
  echo "=== Gitleaks Scan ==="
  gitleaks detect --source "$target" --no-git -v 2>/dev/null || echo "gitleaks not available"
  echo ""
  echo "=== Trivy Config Scan ==="
  trivy config "$target" 2>/dev/null || echo "trivy config not available"
}

check_secrets() {
  echo "=== Scanning git history for secrets ==="
  gitleaks detect --source . -v --log-opts="--all" 2>/dev/null || echo "gitleaks not available"
}