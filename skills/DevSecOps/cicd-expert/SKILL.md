---
name: cicd-expert
description: >
  Especialista em CI/CD e DevSecOps seguindo padrões de produção. Use SEMPRE
  que houver menção a CI/CD, pipeline, GitHub Actions, GitLab CI, Azure
  DevOps, Jenkins, deploy, ou quando o contexto envolver automação de
  build/deploy. Complementar às skills de infra e testing.
version: "2.4.0"
category: DevSecOps
keywords:
  - cicd
  - pipeline
  - github-actions
  - gitlab-ci
  - jenkins
  - deploy
  - devsecops
requires: ['security-expert']
---

# CI/CD Expert

## Princípio Central

- CI/CD como código. Shift-left security. Deploy automatizado.
- Se não está no pipeline, não está em produção.

## CI Pipeline

1. Lint + type check (zero warnings)
2. SAST (Semgrep/CodeQL)
3. Unit tests + coverage gate (>80%)
4. SCA (Snyk/Dependabot)
5. Container build + scan (Trivy)
6. Integration tests
7. Build artifact + tag (semântico)

## CD Pipeline

1. Deploy to staging (automatic after CI)
2. Smoke tests
3. Deploy to production (manual approval ou canary)
4. Blue-green or canary strategy
5. Rollback automático em health check fail
6. Database migrations (before app deploy, backwards-compatible)

## GitOps

- Git como single source of truth
- ArgoCD/Flux para Kubernetes
- Terraform/OpenTofu para infra
- PR-based changes (review obrigatório)
- Branch protection rules
- Signed commits (GPG/Sigstore)

## Multi-Cloud Patterns

- GitHub Actions (Azure/AWS/GCP)
- GitLab CI (self-hosted/cloud)
- Azure DevOps (Azure-native)
- Jenkins (legacy/custom)
- Platform-agnostic quando possível (multi-cloud)

## EVEO — Padrão Real (Azure DevOps + `pipeline-templates`)

Quando o repositório é EVEO e roda em Azure DevOps, **este é o padrão real** (não o genérico das seções acima). Fonte: `pipeline-templates` (org `eveo-workspaces`, projeto `ENGSOFT - Engenharia de Software`), piloto validado em `esteira_a-mas-juridico`, em produção em 6 repos (leitura de 2026-07-14 — reconfira `ONBOARDING.md`/`GUIA-RAPIDO.md` daquele repo antes de scaffolds críticos, o v1 ainda evolui). Para o procedimento passo a passo de scaffold, use o command `/scaffold-pipeline` (`ai-hardness/commands/scaffold-pipeline.md`).

**Consumo via `extends`, nunca cópia do YAML:**
```yaml
resources:
  repositories:
    - repository: templates
      type: git
      name: 'ENGSOFT - Engenharia de Software/pipeline-templates'
      ref: refs/heads/main
extends:
  template: pr/pr-pipeline.yml@templates      # ou cicd/cd-pipeline.yml@templates
```

**Stages/jobs (nomes literais, reaproveitar):** `stage: ci` (PR gate) com `job: build_lint_test` (Go: build · golangci-lint · gitleaks · `go test -race -coverprofile=coverage.out`) ou `job: lint_test_secrets` (Python: ruff · gitleaks · pytest); `stage: cd_${{ parameters.env }}` com `job: build_scan_push` (Harbor login · build · Trivy `--severity CRITICAL --exit-code 1` · push) e `job: deploy` (ConfigMap/Secret · `helm upgrade --install ... --set image.tag=${{ env }}-$SHORT` · smoke `kubectl rollout status`). Pool sempre `pool-build`.

**SonarQube / Quality Gate (obrigatório quando habilitado no template):** coverage ≥80%; zero secrets no Git (gitleaks + `secrets:S6694`); Go: `go:S138`/`S107`/`S3776` tratados no código e no `.golangci.yml` (ver `golang-expert`). Publicar coverage Go com `sonar.go.coverage.reportPaths=coverage.out`. Detalhes e `sonar-project.properties` em `reference/core.md` §3. Gate/agente de governança AIOps (se existir) vive em `pipeline-templates` — não documentado neste repo.

**8 stacks suportadas — `scaffold-repo.sh` sempre gera o `extends` do template Go por padrão; troque manualmente para o template certo depois de rodar o script** (mesmo procedimento já valia para Python, agora generalizado):

| Stack | Template (`pr/<arquivo>@templates`) | Status |
|---|---|---|
| Go | `pr-pipeline.yml` | Piloteado em produção (`esteira_a-mas-juridico`) |
| Python | `pr-pipeline-python.yml` | Piloteado em produção |
| Java (Maven ou Gradle) | `pr-pipeline-java.yml` | Draft — gerado do ADR-002, ainda não piloteado |
| NestJS | `pr-pipeline-nestjs.yml` | Draft — gerado do ADR-004, ainda não piloteado |
| React / Next.js (mesma toolchain, 1 template só) | `pr-pipeline-react-next.yml` | Draft — gerado do ADR-005, ainda não piloteado |
| Vue.js | `pr-pipeline-vue.yml` | Draft — gerado do ADR-006, ainda não piloteado |
| Angular | `pr-pipeline-angular.yml` | Draft — gerado do ADR-007, ainda não piloteado |

Templates "Draft" seguem a toolchain exata que o ADR da stack já fixa (ex.: Angular usa Jest via builder esbuild, nunca Karma/Jasmine — proibido pelo ADR-007; as 4 stacks TypeScript de frontend/NestJS levam `type-coverage > 95%`, ADR-008), mas **nunca rodaram num repo real** — tratar o 1º uso como validação, igual o próprio `cd-pipeline.yml` v1 já se declara "rascunho a validar". Qualquer stack fora dessas 8 (ex.: Rust, PHP) não tem template — não inventar um, apontar para o time de plataforma.

**`scaffold-repo.sh`** (dentro de `pipeline-templates/`) gera, num diretório novo: `azure-pipelines.yml` (com o `extends` condicional por `Build.Reason`/`Build.SourceBranch`), `charts/<svc>/` (dependendo do chart `common` via OCI, `podSecurityContext`/`securityContext` hardened por padrão), `config/{dev,uat,prd}.env` e `values-{dev,uat,prd}.yaml`. Flags principais: `--repo --namespace --image-project --services 'nome:tipo:dockerfile' --secret-keys --vg-prefix --registry --api-host` (`tipo` = `http`|`worker`, decide réplicas/porta/ingress/PDB). **Não cria variable group nem registra a pipeline** — isso fica para o time (ver checklist `az` abaixo).

**Variable groups esperados:** `harbor` (`HARBOR_USER`/`HARBOR_PASS`), `kube-<env>` (`KUBECONFIG_B64`), `<repo>-<env>` (secrets de runtime da app). Autorizar com `--authorize true` ou "Permit" manual no 1º run — "não encontrado" quase sempre é autorização, não senha errada.

**Fluxo real (v1):** `feature → PR dev (gate) → merge = deploy direto (helm upgrade, sem ArgoCD)` → promoção `dev → uat → prd` por PR (2 revisores obrigatórios em `prd`). Tag de imagem = `${{ env }}-$SHORT` (short SHA), **não** semver/digest-promotion — isso (build-once + promote-by-digest + ArgoCD + Cosign) é a visão-alvo de Fase 2, ainda **não implementada** (ver `ADR-025`, seção "Estado Real (V1)" vs. "Visão-alvo"). Rollback real hoje é `helm rollback`, não `argocd app rollback`.

**Checklist de nomenclatura (evita as inconsistências já vistas em produção):**
- `namespace`, `imageProject`, `configMapName`/`secretName` e `secretVarGroup` derivam **todos do mesmo slug** do repo — nunca um usa hífen e outro underscore, nunca um usa o nome do domínio e outro um apelido interno.
- Declare `configMapName`/`secretName`/`smokeDeployment` **sempre explicitamente**, mesmo quando coincidem com o default do template — não deixe implícito.
- `kubeVarGroup` isolado por ambiente (`kube-dev`/`kube-uat`/`kube-prd`) salvo exceção documentada e deliberada.
- Se algum serviço depende de um secret condicional (ex.: Redis só em uat/prd), garanta que o `extends` de cada ambiente realmente usa o conjunto de `secretKeys` que o comentário do arquivo descreve — comentário e código já divergiram em produção nesse ponto exato.

**Gotchas operacionais (top 5, ver `ONBOARDING.md` de `pipeline-templates` para a lista completa):** `pr:` trigger não funciona em Azure Repos (gate é via branch policy `build-validation`, não via `pr:` do YAML); branch nova não dispara CI na 1ª vez (`az pipelines run --branch <b>` manual); `type: object` com default em **flow** `[a,b]` chega vazio via `extends` — use default em **bloco**; `${{ each }}` não funciona dentro de string `script:`; projeto Harbor precisa existir **antes** do 1º push (senão `401`).

**Pré-requisitos de execução (o QUE precisa existir antes do 1º run — o command `/scaffold-pipeline` valida ativamente cada um, ver seu Etapa 4):**
- **Harbor**: projeto criado para o `imageProject` **antes** do 1º push (senão `401`), com "Automatically scan images on push: ON" (habilita Trivy); robot credentials válidas na variable group `harbor`.
- **Azure DevOps**: variable groups `harbor`/`kube-<env>`/`<repo>-<env>` existem e autorizadas (`--authorize true` ou "Permit" manual); `secretKeys` declarados no `azure-pipelines.yml` batem 1:1 com as chaves reais da variable group; branch policies (`build-validation` em dev/uat/prd, 2 revisores em prd) configuradas; pool `pool-build` com agente online e capacidade livre.
- **Kubernetes (por ambiente/cluster)**: namespace do repo existe; RoleBinding `cicd-deployer`+`harbor-pull` presente nesse namespace (sintoma se faltar: `cannot get resource "configmaps" in the namespace "<ns>"` — fix: `bootstrap-cluster.sh --repo-ns-only --env <env> --namespace <ns>`); `KUBECONFIG_B64` decodifica e aponta pro cluster/server certo.
- **Aplicação**: endpoints `/healthz`/`/readyz` implementados (usados pelo smoke test pós-deploy); Dockerfile presente no path declarado em `services`; chart `common` (OCI) acessível a partir do registry configurado.

## Security in Pipeline

- Secret scanning (gitleaks) — bloqueia senha/token em YAML K8s (`secret.yaml` com `data`/`stringData` = `secrets:S6694`)
- SAST before build (Semgrep/CodeQL; SonarQube quando o template habilitar)
- Container scan before push
- Dependency audit (SCA)
- SBOM generation (syft/spdx)
- Sign artifacts (cosign)
- IaC scan (checkov/tfsec)

## Anti-padrões

- No manual deploy
- No secrets em pipeline YAML
- No skip tests
- No deploy sem rollback strategy
- No monolithic pipeline (split by concern)
- No `latest` tag em produção

## Referências Cruzadas

- `docker-expert` — container build, multi-stage, security scanning
- `kubernetes-expert` — GitOps, ArgoCD, Helm deployment
- `security-expert` — SAST/DAST, secrets management, signing
- `testing-expert` — test pipeline integration, coverage gates

## Quando Pedir Ajuda

- Container build/dockerização → carregar `docker-expert`
- Deploy em Kubernetes → carregar `kubernetes-expert`
- Configuração de security scanning → carregar `security-expert`
- Estratégia de testes no pipeline → carregar `testing-expert`
- Multi-cloud pipeline → alinhar provider com o usuário (carregar skill cloud específica)

## Checklist

- [ ] CI gates (lint, test+coverage ≥80%, SAST/Sonar, SCA, gitleaks)
- [ ] CD strategy (blue-green/canary)
- [ ] Rollback plan definido
- [ ] Security scans integrados
- [ ] Artifact signing (cosign)
- [ ] Notification channels (Slack/Teams)
- [ ] Metrics dashboard

## Boas Práticas (referência)

- `reference/best-practices.md` — padrões por concern (estágios, cache, matrix, security scanning SAST/SCA/container/IaC, OIDC/secrets, deploy strategies, rollback) com snippet real por plataforma (GitHub Actions, GitLab CI, Azure DevOps, Jenkins) + checklist e anti-padrões. Leia ao gerar/revisar pipeline.

## Seguranca (Baseline Compartilhado)
- `reference/security-baseline.md` — Regras universais de seguranca (OWASP, secrets, headers, TLS)

