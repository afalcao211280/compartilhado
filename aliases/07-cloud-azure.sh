#!/usr/bin/env bash

alias azl='az group list --output table'
alias azi='az vm list --output table'
alias azv='az vm list-ip-addresses --output table'
alias azac='az acr list --output table'
alias azrgl='az group list --query "[].{Name:name,Location:location,Status:provisioningState}" --output table'
alias azaks='az aks list --output table'

azssh() {
  local rg="$1"
  local vm="$2"
  az vm run-command invoke \
    --resource-group "$rg" \
    --name "$vm" \
    --command-id RunShellScript \
    --scripts "cat /etc/ssh/ssh_host_rsa_key.pub" 2>/dev/null
  ssh -o StrictHostKeyChecking=no "$vm.$rg.cloudapp.azure.com"
}

azlog() {
  local rg="$1"
  local vm="$2"
  az vm run-command invoke \
    --resource-group "$rg" \
    --name "$vm" \
    --command-id RunShellScript \
    --scripts "journalctl -u ${3:-sshd} -n 50 --no-pager" \
    --output json 2>/dev/null | jq -r '.value[0].message' 2>/dev/null
}