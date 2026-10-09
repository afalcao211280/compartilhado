# DevSecOps Aliases

## Quick Start

```bash
source aliases/load.sh
```

## Auto-Load

Add to your shell config (`~/.bashrc` or `~/.zshrc`):

```bash
if [ -f "$HOME/.engsoft-aliases/load.sh" ]; then
  source "$HOME/.engsoft-aliases/load.sh"
fi
```

Copy the folder to `~/.engsoft-aliases` first (or point the `source` line at this repo's `aliases/load.sh` directly).

## Customization

Edit individual alias files to match your preferences. Each file is independent and can be modified without affecting others.

## File Naming Convention

Files are prefixed with `00`-`09` to control load order. Lower numbers load first. This ensures dependencies between alias files are respected.

Add custom aliases by creating new files following the pattern: `NN-category.sh`

## Files

| File | Description |
|------|-------------|
| `00-general.sh` | Navigation, find, grep, and utility aliases |
| `01-git.sh` | Git shortcuts and branch management functions |
| `02-docker.sh` | Docker and compose aliases |
| `03-k8s.sh` | Kubernetes and Helm shortcuts |
| `04-security.sh` | Security scanning tools (trivy, gitleaks, grype, tfsec) |
| `05-dev.sh` | Go, Python, Node.js development shortcuts |
| `06-cloud-aws.sh` | AWS CLI shortcuts and SSM/EC2 helpers |
| `07-cloud-azure.sh` | Azure CLI shortcuts and VM/ACR helpers |
| `08-cloud-gcp.sh` | GCloud CLI shortcuts and compute helpers |
| `09-ai.sh` | AI tools: opencode, aider, ollama |