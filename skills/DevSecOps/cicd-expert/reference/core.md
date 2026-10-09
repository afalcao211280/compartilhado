# CI/CD Expert — Padrões de Código

Snippets prontos por plataforma e concern. Alinhados ao ADR-022 (quality gates, GitOps, security in pipeline). Ler ao gerar YAML de pipeline.

## Índice

1. [Azure Pipelines — Pipeline Completo (Node.js)](#1-azure-pipelines--pipeline-completo-nodejs)
2. [GitHub Actions — Pipeline Universal](#2-github-actions--pipeline-universal)
3. [Quality Gates — Thresholds](#3-quality-gates--thresholds)
4. [Deploy Canary — Azure Container Apps](#4-deploy-canary--azure-container-apps)
5. [Notificações — Teams Webhook](#5-notificações--teams-webhook)
6. [Anti-patterns (com solução)](#anti-patterns)

> Snippets de GitLab CI (self-hosted) e Jenkins, e padrões por concern (cache, matrix, security scanning, OIDC, deploy, rollback) em todas as plataformas: ver `reference/best-practices.md`.

## 1. Azure Pipelines — Pipeline Completo (Node.js)

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main
      - develop
      - release/*
  paths:
    exclude:
      - '*.md'
      - docs/**

pr:
  branches:
    include: ['*']
  paths:
    exclude:
      - '*.md'

variables:
  nodeVersion: '20.x'
  acrName: 'myacreveo'
  imageRepository: 'api'

stages:
  # ─── CI ───────────────────────────────────────────────
  - stage: CI
    displayName: 'Build & Test'
    jobs:
      - job: Lint
        displayName: 'Lint & Type Check'
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: NodeTool@0
            inputs: { versionSpec: $(nodeVersion) }
          - script: npm ci
          - script: npm run lint
          - script: npm run typecheck

      - job: Test
        displayName: 'Test & Coverage'
        pool:
          vmImage: ubuntu-latest
        services:
          postgres:
            image: postgres:16-alpine
            env:
              POSTGRES_USER: test
              POSTGRES_PASSWORD: test
              POSTGRES_DB: test_db
            ports: ['5432:5432']
        steps:
          - task: NodeTool@0
            inputs: { versionSpec: $(nodeVersion) }
          - script: npm ci
          - script: npm test -- --coverage --coverageThreshold='{"global":{"lines":80}}'
            env:
              DATABASE_URL: 'postgresql://test:test@localhost:5432/test_db'
          - task: PublishTestResults@2
            inputs:
              testResultsFormat: JUnit
              testResultsFiles: '**/junit.xml'
          - task: PublishCodeCoverageResults@2
            inputs:
              codeCoverageTool: Cobertura
              summaryFileLocation: coverage/cobertura-coverage.xml

      - job: SecurityScan
        displayName: 'SAST & SCA'
        pool:
          vmImage: ubuntu-latest
        steps:
          - script: npm ci
          - script: npm audit --audit-level=high
          - task: Bash@3
            displayName: Semgrep SAST
            inputs:
              targetType: inline
              script: |
                pip install semgrep
                semgrep --config=p/owasp-top-ten --error .

      - job: Build
        displayName: 'Build & Push Image'
        dependsOn: [Lint, Test, SecurityScan]
        condition: succeeded()
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: AzureCLI@2
            displayName: 'Build and push to ACR'
            inputs:
              azureSubscription: 'EVEO-ServiceConnection'
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                IMAGE_TAG=$(Build.BuildId)
                az acr build \
                  --registry $(acrName) \
                  --image $(imageRepository):${IMAGE_TAG} \
                  --image $(imageRepository):latest \
                  --file Dockerfile .

                # Trivy scan on pushed image
                trivy image \
                  --exit-code 1 \
                  --severity CRITICAL \
                  $(acrName).azurecr.io/$(imageRepository):${IMAGE_TAG}

  # ─── Deploy Dev ───────────────────────────────────────
  - stage: DeployDev
    displayName: 'Deploy → Dev'
    dependsOn: CI
    condition: and(succeeded(), eq(variables['Build.SourceBranchName'], 'develop'))
    jobs:
      - deployment: DeployDev
        environment: development
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  displayName: 'Update Container App (dev)'
                  inputs:
                    azureSubscription: 'EVEO-ServiceConnection'
                    scriptType: bash
                    scriptLocation: inlineScript
                    inlineScript: |
                      az containerapp update \
                        --name ca-api-dev \
                        --resource-group rg-myapp-dev \
                        --image $(acrName).azurecr.io/$(imageRepository):$(Build.BuildId)

  # ─── Deploy Production ────────────────────────────────
  - stage: DeployProd
    displayName: 'Deploy → Production'
    dependsOn: CI
    condition: and(succeeded(), eq(variables['Build.SourceBranchName'], 'main'))
    jobs:
      - deployment: DeployProd
        environment: production  # Requer aprovação manual configurada no Environment
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  displayName: 'Update Container App (prod)'
                  inputs:
                    azureSubscription: 'EVEO-ServiceConnection'
                    scriptType: bash
                    scriptLocation: inlineScript
                    inlineScript: |
                      az containerapp update \
                        --name ca-api-prod \
                        --resource-group rg-myapp-prod \
                        --image $(acrName).azurecr.io/$(imageRepository):$(Build.BuildId)
```

---

## 2. GitHub Actions — Pipeline Universal

```yaml
# .github/workflows/ci.yml
name: CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true  # Cancela runs antigas do mesmo branch

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: npm
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck

  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env: { POSTGRES_USER: test, POSTGRES_PASSWORD: test, POSTGRES_DB: test_db }
        ports: ['5432:5432']
        options: --health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: npm }
      - run: npm ci
      - run: npm test -- --coverage
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/test_db
      - uses: codecov/codecov-action@v4
        with:
          fail_ci_if_error: true

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - run: npm ci
      - run: npm audit --audit-level=high
      - uses: gitleaks/gitleaks-action@v2
      - uses: semgrep/semgrep-action@v1
        with: { config: p/owasp-top-ten }

  build-push:
    needs: [lint, test, security]
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - run: |
          az acr build \
            --registry myacreveo \
            --image api:${{ github.sha }} \
            --file Dockerfile .
```

---

## 3. Quality Gates — Thresholds

Limiares EVEO (Sonar Quality Gate + CI). IDs abaixo bloqueiam/recorrem em gate real — prevenir no código e no lint local.

| Threshold | Valor | Notas / IDs |
|---|---|---|
| Coverage (linhas) | ≥ 80% | Sem relatório → 0% e falha. Go: ver abaixo |
| Branch coverage | ≥ 70% | Preferível como sinal (ADR-021) |
| Secrets no Git | 0 | gitleaks; Sonar `secrets:S6694` (ex.: `secret.yaml` com senha) |
| Função >30 linhas | 0 novo | `go:S138` — espelhar com `funlen` |
| >3 parâmetros | 0 novo | `go:S107` — Options/Params; revive `argument-limit: 3` |
| Cognitive complexity >15 | 0 novo | `go:S3776` — espelhar com `gocognit` |
| TODO sem issue | evitar | `go:S1135` (info; tratar no review) |
| Bugs / Vulns | 0 blocker/critical | Quality Gate |
| Duplications | < 3% | — |
| Security Hotspots | 100% reviewed | — |

```properties
# sonar-project.properties
sonar.projectKey=eveo_myapp
sonar.qualitygate.wait=true

# Go — publicar coverage (senão o gate vê 0%)
sonar.go.coverage.reportPaths=coverage.out
# Node/TS (exemplo): sonar.javascript.lcov.reportPaths=coverage/lcov.info
```

```bash
# CI Go — gerar o arquivo que o Sonar consome
go test ./... -race -coverprofile=coverage.out -covermode=atomic
```

```json
// package.json — scripts de CI (Node/TS)
{
  "scripts": {
    "lint": "eslint . --max-warnings 0",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:coverage": "vitest run --coverage",
    "test:coverage:check": "vitest run --coverage --coverage.thresholds.lines=80 --coverage.thresholds.branches=80"
  }
}
```

> Gate/agente de governança AIOps (quando existir no fluxo ADO) é step externo em `pipeline-templates` — não inventar detalhes aqui. Ver também `golang-expert`, `testing-expert`, `kubernetes-expert` (secrets).

---

## 4. Deploy Canary — Azure Container Apps

```bash
# Criar nova revisão (sem tráfego)
az containerapp revision copy \
  --name ca-api-prod \
  --resource-group rg-myapp-prod \
  --image myacr.azurecr.io/api:new-version \
  --revision-suffix v2

# Enviar 10% do tráfego para nova revisão
az containerapp ingress traffic set \
  --name ca-api-prod \
  --resource-group rg-myapp-prod \
  --revision-weight \
    ca-api-prod--v1=90 \
    ca-api-prod--v2=10

# Monitorar erros por 30min (Application Insights / Azure Monitor)
# Se OK → 100% para nova revisão
az containerapp ingress traffic set \
  --name ca-api-prod \
  --resource-group rg-myapp-prod \
  --revision-weight \
    latest=100

# Se problemas → rollback imediato
az containerapp ingress traffic set \
  --name ca-api-prod \
  --resource-group rg-myapp-prod \
  --revision-weight \
    ca-api-prod--v1=100
```

---

## 5. Notificações — Teams Webhook

```yaml
# task de notificação no Azure Pipelines (após job de deploy)
- task: Bash@3
  displayName: 'Notify Teams'
  condition: always()
  inputs:
    targetType: inline
    script: |
      STATUS="${{ job.status }}"
      COLOR=$([ "$STATUS" == "Succeeded" ] && echo "00FF00" || echo "FF0000")
      EMOJI=$([ "$STATUS" == "Succeeded" ] && echo "✅" || echo "❌")

      curl -s -X POST "$(TEAMS_WEBHOOK_URL)" \
        -H "Content-Type: application/json" \
        -d "{
          \"@type\": \"MessageCard\",
          \"themeColor\": \"$COLOR\",
          \"title\": \"$EMOJI Deploy $(Build.Repository.Name) → $(ENVIRONMENT)\",
          \"text\": \"Branch: $(Build.SourceBranchName) | Build: $(Build.BuildId) | Status: $STATUS\",
          \"potentialAction\": [{
            \"@type\": \"OpenUri\",
            \"name\": \"Ver Pipeline\",
            \"targets\": [{ \"os\": \"default\", \"uri\": \"$(Build.BuildUri)\" }]
          }]
        }"
```

---

## Anti-patterns

### ❌ Secrets hardcoded em arquivos de pipeline
**Problema:** Escrever senhas, tokens ou chaves diretamente no YAML do pipeline (`password: minha_senha`).
**Por quê evitar:** Qualquer pessoa com acesso ao repositório vê o segredo; o histórico do git preserva secrets mesmo após remoção.
**Solução:**
```yaml
# Azure DevOps: use variáveis de grupo de variáveis (Key Vault linked)
variables:
  - group: producao-secrets  # linked ao Azure Key Vault

# GitHub Actions: use repository secrets
- run: docker login -u ${{ secrets.REGISTRY_USER }} -p ${{ secrets.REGISTRY_PASS }}
```

### ❌ Actions sem versão pinada (supply chain risk)
**Problema:** Usar `uses: actions/checkout@main` ou `uses: third-party/action@latest` em GitHub Actions.
**Por quê evitar:** A tag `main`/`latest` pode mudar a qualquer momento — um repositório de action comprometido pode injetar código malicioso em todos os pipelines que o usam.
**Solução:**
```yaml
# Pinar pelo SHA imutável do commit
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
- uses: docker/build-push-action@ca052bb54ab0790a636c9b5f226502c73d547a25  # v5.4.0
```

### ❌ Deploy direto em produção sem environment protection
**Problema:** Configurar pipeline para fazer deploy em produção automaticamente sem aprovação manual.
**Por quê evitar:** Qualquer merge na branch main dispara deploy em prod — um bug crítico vai ao ar antes que alguém possa revisar.
**Solução:**
```yaml
# GitHub Actions: environment com required reviewers
jobs:
  deploy-prod:
    environment:
      name: production  # requer aprovação configurada no GitHub
      url: https://app.exemplo.com.br
```

### ❌ Testes paralelos sem isolamento de banco
**Problema:** Executar jobs de teste em paralelo compartilhando o mesmo banco de dados.
**Por quê evitar:** Testes concorrentes modificam dados uns dos outros — resultados não-determinísticos, flaky tests que passam às vezes.
**Solução:**
```yaml
# Azure DevOps: cada job sobe seu próprio serviço de banco
jobs:
  - job: Test
    services:
      postgres:
        image: postgres:16-alpine
        env: { POSTGRES_DB: testdb, POSTGRES_PASSWORD: test }
    # Banco isolado por job — sem compartilhamento entre workers paralelos
```

### ❌ Sem cache de dependências no pipeline
**Problema:** Não cachear `node_modules`, `~/.m2`, `$GOPATH/pkg` entre runs do pipeline.
**Por quê evitar:** `npm install` / `mvn dependency:resolve` / `go mod download` em cada run adiciona 1-5 minutos desnecessários — 50 runs/dia = 50-250 minutos desperdiçados.
**Solução:**
```yaml
# GitHub Actions
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: ${{ runner.os }}-node-
```

### ❌ Sem rollback plan — zero downtime não configurado
**Problema:** Deploy em produção substituindo diretamente a versão anterior sem estratégia de rollback.
**Por quê evitar:** Se a nova versão tem bug crítico, reverter exige um novo deploy (lento) — sem blue/green ou canary, há janela de downtime.
**Solução:**
```bash
# ACA: canary com split de tráfego — rollback instantâneo
az containerapp ingress traffic set \
  --name minha-api --resource-group rg-prod \
  --revision-weight nova-revision=10 antiga-revision=90
# Se OK: 100% nova. Se bug: 100% antiga sem redeploy
```

### ❌ concurrency sem cancel-in-progress em PRs
**Problema:** Não configurar `concurrency` em GitHub Actions para builds de PR.
**Por quê evitar:** Múltiplos pushes na mesma PR enfileiram múltiplos runs — o runner fica ocupado com runs obsoletos enquanto o run mais recente espera na fila.
**Solução:**
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true  # cancela runs anteriores do mesmo PR
```
