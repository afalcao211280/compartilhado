# ADR-022: CI/CD — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Pipeline de CI/CD é o garante de qualidade e segurança em produção. Sem padronização, cada projeto tem gates diferentes, deploy manual e sem rastreabilidade. A padronização garante shift-left de segurança, quality gates consistentes e deployment automatizado com approval gates.

## Decisão

Adotar pipeline de CI com gates de qualidade (lint → SAST → unit → SCA → container build+scan → integration), CD com staging automático e production com approval, GitOps (ArgoCD/Flux para K8s, Terraform para infra) e segurança integrada (secret scanning, SAST, container scan, SBOM, artifact signing).

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| CI/CD Main | Azure DevOps Pipelines | - | GitHub Actions, GitLab CI | Azure-native para projetos Azure |
| CI/CD Multi-cloud | GitHub Actions | - | GitLab CI, CircleCI | Maior ecossistema, self-hosted runners |
| CI/CD Self-hosted | GitLab CI | 17.x+ | Jenkins, Tekton | Container-native, auto-scaling |
| GitOps K8s | ArgoCD | 2.9+ | Flux v2 | UI madura, sync waves, rollback visual |
| GitOps Infra | Terraform/OpenTofu | 1.7+ | Pulumi, Bicep | Ecossistema maduro, multi-cloud |
| Artifact Signing | Cosign (Sigstore) | 2.x | Notary v2 | Supply chain integrity |
| SBOM | Syft (Anchore) | 1.x+ | sbom-tool, CycloneDX CLI | SPIFFE/SPIRE compatible, SPDX output |
| Secret Scanning | gitleaks + truffleHog | 8.x + 3.x | detect-secrets, GitHub secret scanning | gitleaks: fast; truffleHog: entropy |

## Padrões Obrigatórios

### CI Pipeline (Quality Gates)

```
1. Lint + Type Check (zero warnings)
   ↓
2. SAST (Semgrep/CodeQL) — shift-left security
   ↓
3. Unit Tests + Coverage Gate (>80%)
   ↓
4. SCA (Snyk/Dependabot) — dependência vulnerável = block
   ↓
5. Container Build + Scan (Trivy) — before push to registry
   ↓
6. Integration Tests (testcontainers)
   ↓
7. Build Artifact + Semantic Tag
```

### CD Pipeline

```
CI Success
   ↓
Deploy to Staging (automático)
   ↓
Smoke Tests + DAST (ZAP)
   ↓
Deploy to Production (manual approval ou canary)
   ↓
Health Check + Rollback automático em falha
   ↓
Database Migrations (before app deploy, backwards-compatible)
```

### GitOps

- Git como single source of truth
- ArgoCD/Flux para Kubernetes (never `kubectl apply` manual em produção)
- Terraform/OpenTofu para infraestrutura
- PR-based changes (review obrigatório)
- Branch protection rules
- Signed commits (GPG/Sigstore)

### Multi-cloud Patterns

| Plataforma | Caso de Uso | Quando Usar |
|---|---|---|
| Azure DevOps Pipelines | Projetos Azure-native | Azure App Service, AKS, Azure Functions |
| GitHub Actions | Projetos multi-cloud | Qualquer cloud, open-source |
| GitLab CI | Self-hosted, compliance rígido | On-premise, regulamentação de dados |

### Security in Pipeline

| Gate | Ferramenta | Quando | Ação em Falha |
|---|---|---|---|
| Secret Scanning | gitleaks/truffleHog | Pre-commit + CI | Block pipeline |
| SAST | Semgrep/CodeQL | CI (antes do build) | Block pipeline |
| Container Scan | Trivy | CI (antes do push) | Block pipeline |
| SCA | Snyk/Dependabot | CI (dependências) | Block pipeline por severidade |
| SBOM | Syft | CI (post build) | Generate & store |
| Artifact Signing | Cosign | CI (post build) | Block pipeline |
| IaC Scan | checkov/tfsec | CI (Terraform plans) | Block pipeline |

## Estrutura de Projeto / Configuração

### Azure DevOps Pipeline

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include: [main, develop]

stages:
  - stage: CI
    jobs:
      - job: Quality
        steps:
          - task: Semgrep@1                # SAST
          - task: gitleaks@1               # Secret scanning
      - job: Test
        steps:
          - script: go test ./... -coverprofile=coverage.out
          - task: Snyk@1                   # SCA
      - job: Build
        dependsOn: [Quality, Test]
        steps:
          - script: docker build -t app:$(Build.BuildId) .
          - script: trivy image app:$(Build.BuildId)   # Container scan
          - script: syft app:$(Build.BuildId) -o spdx > sbom.json
          - script: cosign sign app:$(Build.BuildId)

  - stage: Deploy_Staging
    condition: succeeded('CI')
    jobs:
      - deployment: staging
        environment: staging

  - stage: Deploy_Prod
    condition: succeeded('Deploy_Staging')
    jobs:
      - deployment: production
        environment: production
```

### ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: meu-servico
  namespace: argocd
spec:
  source:
    repoURL: https://dev.azure.com/org/proj/_git/charts
    targetRevision: main
    helm:
      valueFiles:
        - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: meu-servico
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Anti-padrões

- Deploy manual em produção (`kubectl apply`) — usar GitOps
- Sem quality gates (deploy sem testes passar)
- Secrets hardcoded no pipeline — usar Variable Groups + Key Vault
- Pular SAST/SCA por pressão de prazo
- Container scan apenas em produção (rodar no CI antes do push)
- Branch principal sem protection rules
- Deploy para produção sem approval manual (exceto canary com rollback)
- Não assinar artifacts (cosign)
- Não gerar SBOM
- Pipeline monolítico (CI e CD no mesmo stage)
- IaC sem scan (checkov/tfsec)

## Consequências

**Positivas:**
- Shift-left: vulnerabilidades detectadas antes do deploy
- GitOps: auditoria, rollback, reprodutibilidade
- Quality gates consistentes em todos os projetos
- Supply chain integrity (cosign + SBOM)
- Deployment automatizado com approval gates

**Negativas:**
- Pipeline mais lento (7 stages)
- Manutenção de múltiplos templates de pipeline
- ArgoCD adiciona complexidade operacional
- Secret scanning pode ter falsos positivos

**Riscos:**
- Pipeline lento pode gerar pressão para pular gates — mitigar com paralelismo e cache
- ArgoCD sync delay em staging — mitigar com manual sync para deploy urgente
- SCA block pode travar pipeline por dependência sem patch — mitigar com accept-risk policy documentada

## Referências

- `skills/DevSecOps/cicd-expert/SKILL.md`
- `exemplos/padronizacao/azure/ci_cd.md`
- ArgoCD: https://argoproj.github.io/argo-cd/
- Syft: https://github.com/anchore/syft
- Cosign: https://github.com/sigstore/cosign
- checkov: https://www.checkov.io/
- ADR-016 (Docker) — container build e scan
- ADR-017 (Kubernetes) — GitOps deploy
- ADR-018 (Terraform) — IaC scan no pipeline
- ADR-020 (Pentest) — security gates no pipeline
- ADR-025 (CI/CD Azure DevOps) — padronização Azure DevOps