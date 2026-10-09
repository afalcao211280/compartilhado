# ADR-025: CI/CD Pipelines — Decisões de Stack e Padrões (Azure DevOps)

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Sem padronização de pipelines, cada projeto define stages, quality gates e ambientes de forma diferente. Resultado: deploys sem rastreabilidade, sem approval gates e sem integração com monitoring. A padronização garante CI consistente, CD com approval gates e observabilidade integrada.

> **Nota de reconciliação (2026-07-14):** as seções abaixo descrevem a arquitetura-**alvo** decidida em 2026-05-17. O que está de fato implementado, piloteado (`esteira_a-mas-juridico`) e rodando em produção em 6 repositórios hoje é outro conjunto de escolhas — ver seção **"Estado Real (V1) — `pipeline-templates`"** ao final desta ADR antes de gerar CI/CD para um repositório novo.

## Decisão

Adotar pipelines Azure DevOps com nomenclatura padronizada `[proj]-[type]-[env]`, environments segregados (dev/staging/prod), CI com quality gates obrigatórios (lint → SAST → unit → SCA → build+scan → integration), CD com approval gates (staging automático, produção manual), IaC (Terraform/Bicep) integrado ao pipeline e monitoring integrado.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| CI/CD Platform | Azure DevOps Pipelines | - | GitHub Actions, GitLab CI | Integração nativa Azure, boards, repos |
| IaC | Terraform + Bicep | 1.7+ / 0.28+ | ARM Templates, Pulumi | Terraform: multi-cloud; Bicep: Azure-native simplificado |
| Container Registry | Azure Container Registry | Premium | Docker Hub, GHCR | Geo-replication, scan nativo, integração Azure |
| K8s Deploy | ArgoCD + Helm | 2.9+ / 3.x | Flux, kubectl apply | GitOps, rollback visual, sync waves |
| Monitoring | Azure Monitor + Prometheus + Grafana | - | Datadog, New Relic | Azure-native + Prometheus para K8s |
| Artifacts | Azure Artifacts | - | JFrog, Nexus | Integração nativa com pipelines |

## Padrões Obrigatórios

### 1. Nomenclatura de Pipelines

**Padrão:** `[proj]-[type]-[env]`

| Type | Descrição | Exemplo |
|------|-----------|---------|
| `ci` | Build + Test | `plat-ci-dev` |
| `cd` | Deploy | `plat-cd-staging` |
| `cd-prod` | Deploy Produção | `plat-cd-prod` |
| `iac` | Infraestrutura | `plat-iac-dev` |
| `e2e` | Testes E2E | `plat-e2e-staging` |
| `sec` | Security Scan | `plat-sec-prod` |

### 2. Ambientes de Deploy

| Ambiente | Propósito | Aprovação | Auto-deploy |
|----------|-----------|-----------|-------------|
| DEV | Desenvolvimento e integração | Automático | Sim (após CI sucesso) |
| HMG (Staging) | Homologação e QA | 1 Tech Lead | Sim (após DEV estável) |
| PROD | Produção | Tech Lead + PO | Não (approval manual) |

### 3. Pipeline CI (Build + Test)

```yaml
# azure-pipelines-ci.yml
trigger:
  branches:
    include: [main, develop]
  paths:
    exclude: [docs/, *.md]

pool:
  vmImage: 'ubuntu-latest'

stages:
  - stage: Quality
    jobs:
      - job: Lint_TypeCheck
        steps:
          - script: make lint
          - script: make typecheck

      - job: SAST
        steps:
          - task: Semgrep@1

      - job: Secret_Scan
        steps:
          - task: gitleaks@1

  - stage: Test
    dependsOn: Quality
    jobs:
      - job: Unit
        steps:
          - script: make test-unit
          - task: PublishCodeCoverageResults@1
            inputs:
              codeCoverageTool: 'Cobertura'
              summaryFileLocation: 'coverage.xml'

      - job: SCA
        steps:
          - task: Snyk@1

  - stage: Build
    dependsOn: Test
    jobs:
      - job: Container_Build
        steps:
          - script: docker build -t app:$(Build.BuildId) .
          - script: trivy image app:$(Build.BuildId)

      - job: Integration
        dependsOn: Container_Build
        steps:
          - script: make test-integration

      - job: Publish
        dependsOn: Integration
        steps:
          - task: Docker@2
            inputs:
              command: push
          - script: cosign sign app:$(Build.BuildId)
          - script: syft app:$(Build.BuildId) -o spdx > sbom.json
```

### 4. Pipeline CD (Deploy)

```yaml
# azure-pipelines-cd.yml
trigger: none

stages:
  - stage: Deploy_DEV
    condition: succeeded()
    jobs:
      - deployment: dev
        environment: dev
        strategy:
          runOnce:
            deploy:
              steps:
                - script: make deploy-dev

  - stage: Deploy_HMG
    dependsOn: Deploy_DEV
    condition: succeeded()
    jobs:
      - deployment: staging
        environment: staging
        strategy:
          runOnce:
            deploy:
              steps:
                - script: make deploy-staging
                - script: make smoke-tests

  - stage: Deploy_PROD
    dependsOn: Deploy_HMG
    condition: succeeded()
    jobs:
      - deployment: production
        environment: production
        strategy:
          canary:
            increments: [10, 50, 100]
            deploy:
              steps:
                - script: make deploy-prod
                - script: make health-check
```

### 5. Approval Gates

| Ambiente | Tipo | Aprovadores |
|----------|------|-------------|
| DEV | Automático | - |
| HMG | Manual | 1 Tech Lead |
| PROD | Manual | Tech Lead + PO |

**Quality Gates obrigatórios antes de deploy:**
- Coverage > 80%
- Zero vulnerabilidades Críticas/Altas (SAST/SCA)
- Todos os testes passando
- Smoke tests passando em staging
- SonarQube Quality Gate passing (se habilitado)

### 6. Variable Groups

| Group | Conteúdo | Security |
|-------|----------|----------|
| `env-dev` | Configurações DEV | Non-secret |
| `env-hmg` | Configurações HMG | Non-secret |
| `env-prod` | Configurações PROD | Non-secret |
| `common-secure` | Secrets comuns (API keys, tokens) | Key Vault linked |
| `container-registry` | ACR credentials | Key Vault linked |

**Regra:** Variáveis sensíveis somente via Key Vault linked variable groups.

### 7. IaC no Pipeline

**Terraform:**
```yaml
- stage: IaC_Plan
  steps:
    - script: terraform init
    - script: terraform plan -out=tfplan
    - script: checkov -f tfplan.json    # Security scan

- stage: IaC_Apply
  dependsOn: IaC_Plan
  condition: succeeded()
  steps:
    - script: terraform apply tfplan
```

**Bicep (Azure-native):**
```yaml
- stage: Bicep_Validate
  steps:
    - script: az bicep build --file main.bicep
    - script: az deployment what-if --template-file main.bicep

- stage: Bicep_Deploy
  dependsOn: Bicep_Validate
  steps:
    - script: az deployment create --template-file main.bicep
```

### 8. Monitoramento Integrado

| Tipo | Ferramenta | Configuração |
|------|----------|-------------|
| Application Metrics | Azure Monitor / Prometheus | Alert rules em alerts.yaml |
| Logs | Azure Log Analytics / Loki | Structured logging (JSON) |
| Traces | Application Insights / OTEL | Correlation ID em todos os requests |
| Alerts | Azure Alerts / PagerDuty | Channel: Slack + Email |

**Alertas obrigatórios por serviço:**
- Error rate > 5% (5 min window)
- Latency p99 > 2s (5 min window)
- Health check failing (1 min window)
- Deployment failed
- Container restart > 3 vezes (5 min window)

## Anti-padrões

- Pipeline sem quality gates (deploy sem testes)
- Secrets hardcoded no YAML — usar Variable Groups + Key Vault
- Deploy manual para staging — deve ser automático após CI
- Deploy automático para produção — deve ter approval manual
- Pipeline monolítico (CI e CD no mesmo arquivo)
- Não rodar SAST/SCA por pressão de prazo
- Não gerar SBOM e assinar artifacts
- Ignorar quality gates (coverage, vulnerabilities)
- Não ter IaC — infra criada manualmente
- Ambientes compartilhados sem isolamento

## Consequências

**Positivas:**
- CI consistente com quality gates em todos os projetos
- CD com approval gates garante governança
- IaC integrado — infra é versionada e auditavel
- Monitoring integrado — visibilidade pós-deploy
- Nomenclatura padronizada facilita busca e troubleshooting
- Variable Groups + Key Vault centralizam secrets

**Negativas:**
- Pipeline mais lento (7+ stages)
- Approval manual em PROD pode atrasar deploy urgente
- Manutenção de múltiplos templates de pipeline
- ArgoCD adiciona complexidade operacional

**Riscos:**
- Quality gates muito rígidos podem bloquear deploys de hotfix — mitigar com pipeline de hotfix separado
- Variáveis no Key Vault aumentam latência de pipeline — mitigar com cache
- Deployment canary em PROD requer observabilidade madura — mitigar com rollback automático em health check fail

## Estado Real (V1) — `pipeline-templates`

**Contexto da reconciliação:** as seções acima descrevem a arquitetura-alvo aceita nesta ADR em 2026-05-17. O que está de fato implementado e rodando em produção hoje é o repositório `pipeline-templates` (org `eveo-workspaces`, projeto `ENGSOFT - Engenharia de Software`), piloteado em `esteira_a-mas-juridico` e consumido via `extends`/`resources.repositories` por 6 repositórios ativos. O próprio `ONBOARDING.md` desse repositório classifica GitOps/ArgoCD/Cosign/promote-by-digest como **"Fase 2 (diferida)"** — a visão-alvo acima segue válida como norte, só ainda não foi construída.

| Aspecto | Visão-alvo (Fase 2, seções acima) | Estado real V1 (implementado hoje) |
|---|---|---|
| Deploy | ArgoCD (GitOps, sync automático) | `helm upgrade --install` direto no job de CD (push-based) |
| Ambientes | `dev` / `staging(hmg)` / `prod` | `dev` / `uat` / `prd` |
| Nomenclatura de pipeline | `[proj]-[type]-[env]` | `<repo>-cicd` (uma pipeline por repo; stage dinâmico por env) |
| Registry | Azure Container Registry | Harbor (`10.1.67.145`, um projeto por produto) |
| Container scan | Trivy (implícito) | Trivy, `--severity CRITICAL --exit-code 1`, bloqueia push |
| SAST | Semgrep/CodeQL | SonarQube — implementado como **placeholder ainda desligado** (`SKIP_SONAR`), dispara só em PR→uat |
| SCA | Snyk/Dependabot | Não implementado no v1 |
| Secret scanning | (implícito) | gitleaks, roda em toda PR — implementado |
| Artifact signing / SBOM | Cosign + Syft | Não implementado no v1 (descrito como visão-alvo no `cicd/README.md` do próprio `pipeline-templates`) |
| Secrets | Key Vault linked variable groups | Azure DevOps Variable Groups (`harbor`, `kube-<env>`, `<repo>-<env>`), sem Key Vault |
| Aprovação PROD | Tech Lead + PO | 2 revisores obrigatórios via branch policy em `prd` |
| Rollback | `argocd app rollback` | `helm rollback` (o artefato `rollback/` do template ainda não tem YAML implementado) |
| Versionamento de imagem | Build-once + promote-by-digest | Build por ambiente, tag `${{ env }}-$SHORT` (short SHA) |

**Recomendação:** ao criar CI/CD para um repositório novo, usar o padrão real (`pipeline-templates` + `scaffold-repo.sh`), não a "Stack Canônica"/"Padrões Obrigatórios" descritos acima — tratar essas seções como backlog de evolução (Fase 2). O procedimento e o checklist de nomenclatura consistente vivem no command `/scaffold-pipeline` (`ai-hardness/commands/scaffold-pipeline.md`) e na seção "EVEO — Padrão Real" da skill `cicd-expert` (`ai-hardness/skills/DevSecOps/cicd-expert/SKILL.md`).

## Referências

- `exemplos/padronizacao/azure/ci_cd.md`
- Azure DevOps Pipelines: https://docs.microsoft.com/pt-br/azure/devops/pipelines/
- ADR-017 (Kubernetes) — deploy via ArgoCD
- ADR-018 (Terraform) — IaC no pipeline
- ADR-022 (CI/CD) — CI/CD patterns e security gates
- ADR-023 (Git) — branch triggers e PR validation
- ADR-027 (Testes) — pipeline de testes automatizados
- `pipeline-templates` (`ENGSOFT - Engenharia de Software/pipeline-templates`) — implementação real V1, `ONBOARDING.md`/`GUIA-RAPIDO.md`/`scaffold-repo.sh`
- `ai-hardness/commands/scaffold-pipeline.md` — command de scaffold para repositórios novos
- `ai-hardness/skills/DevSecOps/cicd-expert/SKILL.md` — seção "EVEO — Padrão Real"