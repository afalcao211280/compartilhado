# CI/CD — Best Practices por Plataforma

Referência densa, EVEO-aligned. Cada concern (estágios, cache, matrix, security
scanning, OIDC/secrets, deploy, rollback) tem snippet real por plataforma:
**GitHub Actions**, **GitLab CI**, **Azure DevOps** e **Jenkins**.

Alinhado ao ADR-022 (7 quality gates, GitOps, security in pipeline). Posição EVEO
das plataformas (sem default artificial no código gerado — confirme o provider
com o time): Azure DevOps é o primário Azure-native; GitHub Actions para
multi-cloud/OSS; GitLab CI para self-hosted/compliance rígido; Jenkins aparece em
cenários legacy/migração. Pipelines end-to-end de Azure e GitHub estão em
`reference/core.md` — aqui o foco é por concern e cobre os gaps de GitLab e Jenkins.

## Índice

1. [Estágios do pipeline](#1-estágios-do-pipeline)
2. [Cache de dependências e camadas](#2-cache-de-dependências-e-camadas)
3. [Matrix builds](#3-matrix-builds)
4. [Security scanning (SAST/SCA/container/IaC/secret)](#4-security-scanning)
5. [OIDC e gestão de secrets](#5-oidc-e-gestão-de-secrets)
6. [Deploy strategies (blue-green/canary/rolling)](#6-deploy-strategies)
7. [Rollback](#7-rollback)
8. [Checklist condensado](#8-checklist-condensado)
9. [Anti-padrões (com solução)](#9-anti-padrões)
10. [Cross-references](#10-cross-references)

---

## 1. Estágios do pipeline

Princípio: **fail fast**. Ordem canônica EVEO (ADR-022): lint → SAST → test+coverage
→ SCA → container build+scan → integration → artifact. Estágios claros, um concern
por job.

**GitHub Actions** — jobs com `needs` formando o DAG:
```yaml
jobs:
  lint:      { runs-on: ubuntu-latest, steps: [ ... ] }
  test:      { needs: lint, runs-on: ubuntu-latest, steps: [ ... ] }
  security:  { needs: lint, runs-on: ubuntu-latest, steps: [ ... ] }
  build:     { needs: [test, security], if: github.event_name == 'push', ... }
```

**GitLab CI** — `stages` globais + `needs:` para paralelismo fora da ordem do stage:
```yaml
stages: [lint, test, security, build, deploy]

test:
  stage: test
  needs: [lint]          # começa assim que lint termina, não espera o stage todo
  script: [npm ci, npm test -- --coverage]
```

**Azure DevOps** — `stages` → `jobs` → `steps`, com `dependsOn` + `condition`:
```yaml
stages:
  - stage: CI
    jobs:
      - job: Lint
      - job: Test
      - job: Build
        dependsOn: [Lint, Test]
        condition: succeeded()
```

**Jenkins (Declarative)** — `stages { stage { ... } }`, `parallel` para concorrência:
```groovy
pipeline {
  agent { label 'linux-docker' }
  stages {
    stage('Lint')  { steps { sh 'npm run lint' } }
    stage('Quality') {
      parallel {
        stage('Test')     { steps { sh 'npm run test:coverage'; junit 'test-results.xml' } }
        stage('Security') { steps { sh 'npm audit --audit-level=high' } }
      }
    }
    stage('Build') { steps { sh 'npm run build'; archiveArtifacts 'dist/**/*' } }
  }
  post { always { cleanWs() } failure { echo 'Pipeline failed' } }
}
```

---

## 2. Cache de dependências e camadas

Cachear deps (`~/.npm`, `~/.m2`, `$GOPATH/pkg`) e camadas Docker. Chave derivada
do lockfile para invalidar só quando muda.

**GitHub Actions** — `cache` embutido no setup ou `actions/cache`:
```yaml
- uses: actions/setup-node@v4
  with: { node-version: '20', cache: npm }   # cache automático via package-lock.json
# ou explícito:
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: ${{ runner.os }}-node-
```

**GitLab CI** — `cache` por chave de ref; artifacts para relatórios:
```yaml
cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths: [node_modules/, .npm/]

test:
  script: [npm ci --cache .npm --prefer-offline, npm test]
  artifacts:
    reports: { junit: junit.xml }
    expire_in: 1 week
```

**Azure DevOps** — task `Cache@2` com key por lockfile:
```yaml
- task: Cache@2
  inputs:
    key: 'npm | "$(Agent.OS)" | package-lock.json'
    restoreKeys: 'npm | "$(Agent.OS)"'
    path: $(Pipeline.Workspace)/.npm
- script: npm ci --cache $(Pipeline.Workspace)/.npm --prefer-offline
```

**Docker layer caching (GitLab, aplicável a qualquer runner com dind)**:
```yaml
build-image:
  image: docker:latest
  services: [docker:dind]
  script:
    - docker pull $CI_REGISTRY_IMAGE:latest || true
    - docker build --cache-from $CI_REGISTRY_IMAGE:latest
        -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA -t $CI_REGISTRY_IMAGE:latest .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
```
Em GitHub Actions, use `docker/build-push-action` com `cache-from`/`cache-to: type=gha`.

---

## 3. Matrix builds

Rodar a mesma suíte contra várias versões/OS/plataformas em paralelo.

**GitHub Actions**:
```yaml
strategy:
  fail-fast: false
  matrix:
    node: ['18', '20', '22']
    os: [ubuntu-latest, windows-latest]
runs-on: ${{ matrix.os }}
steps:
  - uses: actions/setup-node@v4
    with: { node-version: '${{ matrix.node }}' }
```

**GitLab CI** — `parallel: matrix`:
```yaml
test:
  stage: test
  parallel:
    matrix:
      - NODE_VERSION: ['18', '20', '22']
  image: node:${NODE_VERSION}-alpine
  script: [npm ci, npm test]
```

**Azure DevOps** — `strategy: matrix`:
```yaml
strategy:
  matrix:
    node18: { nodeVersion: '18.x' }
    node20: { nodeVersion: '20.x' }
  maxParallel: 2
steps:
  - task: NodeTool@0
    inputs: { versionSpec: $(nodeVersion) }
```

**Jenkins (Declarative)** — bloco `matrix`:
```groovy
stage('Test matrix') {
  matrix {
    axes { axis { name 'NODE'; values '18', '20', '22' } }
    stages {
      stage('Test') { steps { sh "nvm use ${NODE} && npm test" } }
    }
  }
}
```

---

## 4. Security scanning

Shift-left: SAST antes do build, SCA em cada run, container scan **antes** do push,
IaC scan, secret scan. Bloquear em CRITICAL/HIGH. Ferramentas EVEO (ADR-022):
Semgrep/CodeQL (SAST), Snyk/npm audit/Dependabot (SCA), Trivy (container), checkov/tfsec
(IaC), gitleaks/truffleHog (secret), Syft (SBOM), Cosign (signing).

**GitHub Actions**:
```yaml
security:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
      with: { fetch-depth: 0 }        # histórico completo p/ gitleaks
    - run: npm audit --audit-level=high            # SCA
    - uses: gitleaks/gitleaks-action@v2            # secret scan
    - uses: semgrep/semgrep-action@v1              # SAST
      with: { config: p/owasp-top-ten }
    - uses: aquasecurity/trivy-action@master       # container scan
      with: { image-ref: 'myapp:${{ github.sha }}', severity: 'CRITICAL,HIGH', exit-code: '1' }
    - uses: bridgecrewio/checkov-action@v12         # IaC scan
      with: { directory: infra/ }
```

**GitLab CI** — templates nativos (`Security/*.gitlab-ci.yml`):
```yaml
include:
  - template: Security/SAST.gitlab-ci.yml
  - template: Security/Dependency-Scanning.gitlab-ci.yml
  - template: Security/Container-Scanning.gitlab-ci.yml
  - template: Security/Secret-Detection.gitlab-ci.yml

container_scanning:
  variables: { CS_SEVERITY_THRESHOLD: HIGH }
```

**Azure DevOps** — steps inline (Semgrep, Trivy, npm audit):
```yaml
- job: SecurityScan
  steps:
    - script: npm audit --audit-level=high
    - task: Bash@3
      displayName: Semgrep SAST
      inputs:
        targetType: inline
        script: |
          pip install semgrep
          semgrep --config=p/owasp-top-ten --error .
    - task: Bash@3
      displayName: Trivy container scan
      inputs:
        targetType: inline
        script: trivy image --exit-code 1 --severity CRITICAL,HIGH $(acrName).azurecr.io/api:$(Build.BuildId)
```

**Jenkins** — plugins/CLI nos stages:
```groovy
stage('Security') {
  steps {
    sh 'npm audit --audit-level=high'
    sh 'semgrep --config=p/owasp-top-ten --error .'
    sh 'trivy image --exit-code 1 --severity CRITICAL,HIGH ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}'
  }
}
```

**SBOM + signing (portável)** após o build da imagem:
```bash
syft <image> -o spdx-json > sbom.spdx.json      # SBOM
cosign sign --yes <image>@<digest>               # assinatura (Sigstore keyless via OIDC)
cosign attest --yes --predicate sbom.spdx.json --type spdxjson <image>@<digest>
```

---

## 5. OIDC e gestão de secrets

Regra dura: **nunca** segredo em texto plano no YAML. Preferir OIDC (federação de
identidade) para cloud — elimina long-lived keys. Segredos só via secret store/cofre.

**GitHub Actions → Azure (OIDC, sem client secret)**:
```yaml
permissions:
  id-token: write        # necessário p/ emitir o token OIDC
  contents: read
steps:
  - uses: azure/login@v2
    with:
      client-id: ${{ secrets.AZURE_CLIENT_ID }}
      tenant-id: ${{ secrets.AZURE_TENANT_ID }}
      subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```
AWS: `aws-actions/configure-aws-credentials@v4` com `role-to-assume` + `id-token: write`.

**GitLab CI → cloud via OIDC (`id_tokens`)**:
```yaml
deploy:
  id_tokens:
    AZURE_TOKEN: { aud: api://AzureADTokenExchange }
  script:
    - az login --service-principal -u $CLIENT_ID -t $TENANT_ID
        --federated-token $AZURE_TOKEN
```
Segredos sensíveis: **Masked + Protected variables** ou integração HashiCorp Vault
(`secrets:` keyword). Nunca commitar no `.gitlab-ci.yml`.

**Azure DevOps** — Variable Group linkado ao Key Vault + Service Connection (OIDC/workload identity):
```yaml
variables:
  - group: producao-secrets     # linked ao Azure Key Vault
steps:
  - task: AzureCLI@2
    inputs:
      azureSubscription: 'EVEO-ServiceConnection'   # workload identity federation
      scriptType: bash
      scriptLocation: inlineScript
      inlineScript: az acr build --registry $(acrName) --image api:$(Build.BuildId) .
```

**Jenkins** — `credentials()` binding (nunca `echo` do secret):
```groovy
environment {
  REGISTRY_CREDS = credentials('registry-user-pass')  // expõe _USR e _PSW
}
steps {
  sh 'echo $REGISTRY_CREDS_PSW | docker login -u $REGISTRY_CREDS_USR --password-stdin $REGISTRY'
}
```

---

## 6. Deploy strategies

Gate de ambiente + aprovação para prod. Estratégia por risco: rolling (padrão K8s),
blue-green (swap instantâneo), canary (tráfego gradual). GitOps (ArgoCD/Flux) onde
aplicável — ver `kubernetes-expert`.

**Canary — Azure Container Apps (split de tráfego por revisão)**:
```bash
az containerapp revision copy --name ca-api-prod -g rg-prod \
  --image myacr.azurecr.io/api:new --revision-suffix v2
az containerapp ingress traffic set --name ca-api-prod -g rg-prod \
  --revision-weight ca-api-prod--v1=90 ca-api-prod--v2=10   # 10% canary
# se OK após observabilidade: --revision-weight latest=100
```

**Blue-green — Azure Web App deployment slots**:
```bash
az webapp deployment slot create --name app -g rg --slot staging
az webapp deploy --name app -g rg --slot staging --src-path app.zip
az webapp deployment slot swap --name app -g rg --slot staging --target-slot production
```

**Rolling — Kubernetes (via GitLab CI ou qualquer runner)**:
```yaml
deploy-k8s:
  stage: deploy
  image: alpine/k8s:latest
  script:
    - kubectl set image deployment/app app=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA -n production
    - kubectl rollout status deployment/app -n production   # espera o rollout
  environment: { name: production }
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual        # aprovação manual p/ prod
```

**Environment gate + aprovação (GitHub Actions / Azure DevOps)**:
```yaml
# GitHub Actions: required reviewers configurados no Environment
jobs:
  deploy-prod:
    environment: { name: production, url: https://app.exemplo.com.br }
```
```yaml
# Azure DevOps: deployment job aponta p/ Environment com approval check
- deployment: DeployProd
  environment: production   # approval + audit trail configurados no Environment
  strategy: { runOnce: { deploy: { steps: [ ... ] } } }
```

---

## 7. Rollback

Rollback deve ser **definido e testado** antes do primeiro deploy. Health check
pós-deploy dispara reversão automática.

- **Canary/traffic split (ACA)**: reverter peso para a revisão anterior — instantâneo,
  sem redeploy: `az containerapp ingress traffic set ... --revision-weight ca-api-prod--v1=100`.
- **Blue-green (slots)**: novo `swap` inverte staging↔production.
- **Kubernetes rolling**: `kubectl rollout undo deployment/app -n production` (volta ao
  ReplicaSet anterior); GitOps: reverter o commit no repo de manifests (ArgoCD ressincroniza).
- **GitHub Actions**: gate `if: failure()` em step de health check que dispara o rollback.
- **Jenkins**: `post { failure { sh 'kubectl rollout undo deployment/app' } }`.

Health check padrão pós-deploy (portável):
```bash
for i in $(seq 1 10); do
  code=$(curl -s -o /dev/null -w '%{http_code}' https://app.exemplo.com.br/health)
  [ "$code" = "200" ] && exit 0
  sleep 6
done
exit 1   # falhou → pipeline dispara rollback
```

---

## 8. Checklist condensado

**Pipeline**
- Fail fast: lint/test antes de build/deploy. Estágios claros (lint → test → build → scan → deploy).
- Cache de dependências e camadas. Matrix p/ múltiplas versões/plataformas.
- Artefato imutável construído **uma vez**, promovido entre ambientes (dev→stg→prod).

**Segurança (DevSecOps)**
- Segredos em cofre/secret store (nunca plaintext no YAML). OIDC p/ cloud (sem long-lived keys).
- Scanning no pipeline: SAST, SCA, secret scan, container scan, IaC scan.
- Runners com privilégio mínimo. Pin de actions/imagens por SHA/digest. SBOM + signing (Syft/Cosign).

**Deploy**
- Gates de ambiente + aprovação p/ prod. Estratégia: blue-green/canary/rolling.
- Rollback definido e testado. Health check pós-deploy.
- GitOps onde aplicável (ArgoCD/Flux — ver `kubernetes-expert`).

**Qualidade**
- Cobertura mínima como gate (≥80%). Build reproduzível. Versionamento SemVer + changelog.

---

## 9. Anti-padrões

- ❌ **Segredo em plaintext no pipeline** → repository/group secrets, Key Vault, `credentials()`.
- ❌ **Rebuild do artefato por ambiente (drift)** → construir uma vez, promover o mesmo digest.
- ❌ **Action/imagem por tag mutável (`@latest`, `@main`)** → pin por SHA/digest (supply chain).
- ❌ **Deploy sem rollback** → canary/blue-green + `rollout undo` testado.
- ❌ **Runner com credencial ampla** → privilégio mínimo, OIDC de curta duração, sem dind privilegiado desnecessário.
- ❌ **Container scan só em produção** → scan **antes** do push, bloquear CRITICAL/HIGH.
- ❌ **Pular SAST/SCA por prazo** → gate obrigatório; risco aceito só com policy documentada.
- ❌ **Testes paralelos sem isolamento de banco** → cada job sobe seu próprio serviço (service container).
- ❌ **Deploy manual em produção (`kubectl apply`)** → GitOps (ArgoCD/Flux).

---

## 10. Cross-references

- `git-expert` — branch protection, signed commits, PR-based flow.
- `docker-expert` — multi-stage build, container security scanning.
- `kubernetes-expert` — GitOps (ArgoCD/Flux), rolling/canary no cluster, Helm.
- `terraform-expert` — IaC scan (checkov/tfsec), pipeline de infra.
- `security-expert` — SAST/DAST, secrets management, SBOM, signing.
- `reference/core.md` — pipelines end-to-end (Azure DevOps, GitHub Actions).
- `reference/stack.md` — stack canônica EVEO, branching (ADR-023), environment progression.
</content>
</invoke>
