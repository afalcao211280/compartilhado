# CI/CD Expert — Stack Canônica

## CI/CD — Versão Canônica EVEO

| Categoria | Ferramenta | Versão | Link | Notas |
|-----------|-----------|--------|------|-------|
| **CI/CD Primário (EVEO)** | | | | |
| Pipelines | Azure DevOps Pipelines | — | https://azure.microsoft.com/devops | Padrão EVEO. Ver ADR-023 a ADR-027 |
| Repos | Azure Repos (Git) | — | — | Integrado ao Pipelines |
| Artifacts | Azure Artifacts | — | — | Package registry (npm, Maven, NuGet, pip) |
| Board | Azure Boards | — | — | Work items, Sprints |
| **CI/CD Alternativo** | | | | |
| GitHub Actions | GitHub Actions | — | https://github.com/features/actions | Para projetos OSS ou GitHub-hosted |
| GitLab CI | GitLab CI/CD | — | https://docs.gitlab.com/ci | Auto-DevOps templates |
| **Container Registry** | | | | |
| Registry | Azure Container Registry (ACR) | — | https://azure.microsoft.com/container-registry | Padrão EVEO Azure |
| Registry alt | GitHub Container Registry | — | `ghcr.io` | Para OSS/GitHub |
| Registry alt | AWS ECR | — | — | Para projetos AWS |
| **Deploy Strategies** | | | | |
| Blue/Green | Azure Deployment Slots / ECS | — | — | Zero-downtime via traffic swap |
| Canary | Azure Container Apps revisions | — | — | Percentual de tráfego gradual |
| Rolling | Kubernetes rolling update | built-in | — | `maxSurge` + `maxUnavailable` |
| Feature Flags | Azure App Config / LaunchDarkly | — | — | Desacoplar deploy de release |
| **Quality Gates** | | | | |
| SAST | Semgrep / ESLint security | — | — | Bloquear PRs com issues críticos |
| SCA | npm audit / Snyk | — | — | Bloquear em vulnerabilidades HIGH/CRITICAL |
| Coverage | Cobertura ≥ 80% | — | — | Falhar build se < threshold |
| Linting | ESLint / Ruff / golangci-lint | — | — | Zero warnings em CI |
| **Notifications** | | | | |
| Teams | Microsoft Teams Webhook | — | — | Pipeline failures → canal de alerta |
| Slack | Slack Incoming Webhook | — | — | Para equipes usando Slack |
| Email | Azure DevOps notifications | built-in | — | Por subscription/notificação |

## Branching Strategy (ADR-023)

```
main (production-ready)
  ↑
release/vX.Y.Z (estabilização)
  ↑
develop (integração)
  ↑
feature/TICKET-123-descricao (desenvolvimento)
hotfix/TICKET-456-descricao (produção → main + develop)
```

## Environment Progression

```
feature branch → dev environment (auto-deploy on push)
develop branch → staging environment (auto-deploy on push to develop)
release branch → staging environment (manual QA approval)
main branch    → production (manual approval + audit trail)
```
