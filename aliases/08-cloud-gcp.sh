#!/usr/bin/env bash

alias gcpl='gcloud compute instances list'
alias gcpi='gcloud compute instances describe'
alias gcpv='gcloud compute instances list --format="table(name,status,networkInterfaces[0].networkIP)"'
alias gcpcl='gcloud container clusters list'
alias gcpgkl='gcloud container clusters list --format="table(name,location,status)"'
alias gcpsshl='gcloud compute ssh-l'

gcpssh() {
  local instance="$1"
  local zone="${2:-$(gcloud config get-value compute/zone 2>/dev/null)}"
  gcloud compute ssh "$instance" --zone="$zone" --tunnel-through-iap
}

gcplog() {
  local instance="$1"
  local zone="${2:-$(gcloud config get-value compute/zone 2>/dev/null)}"
  gcloud compute ssh "$instance" --zone="$zone" --command="journalctl -u ${3:-sshd} -n 50 --no-pager" --tunnel-through-iap
}