# Changelog — kubernetes-expert

## [2.2.0] - 2026-07-16

### Changed
- `SKILL.md` — princípio e anti-padrão: nunca versionar `Secret`/`secret.yaml` com valores (Sonar `secrets:S6694` BLOCKER).
- `reference/patterns.md` — nota no ExternalSecret + anti-padrão dedicado a Secret plaintext no Git.

## [2.1.0] - 2026-06-30

### Changed
- Consolidação em `skills-optimizadas` (cruzamento skills/ ⨯ skills-compare/ ⨯ ADR-017).
- Path do security baseline corrigido para `reference/security-baseline.md`.
- `keywords` corrigido de `['kubernetes-expert']` para 7 termos reais de trigger (kubernetes, k8s, helm, kubectl, argocd, gitops, manifest).
- `description` reescrita (pushy, ≤600 chars) cobrindo Helm e gatilhos.
- SKILL.md alinhado ao ADR-017: estrutura de projeto Helm + ArgoCD, padrões obrigatórios, workflow agentic, anti-padrões detalhados, "Quando Perguntar".
- Versões atualizadas para última estável: Kubernetes 1.31+; GitOps via ArgoCD 2.9+ ou Flux 2.x (era K8s 1.28/1.29).

### Decisões de divergência ADR-017 (caso a caso)
- **GitOps**: decisão de gate — ArgoCD **ou** Flux v2 documentados **sem default** (escolha por projeto). Ambos são GitOps; `kubectl apply` manual em produção continua proibido.

### Added
- `reference/helm.md` — chart scaffolding completo (origem: compare `helm-chart-scaffolding`): estrutura, Chart.yaml, `_helpers.tpl`, deployment template endurecido, values base + por ambiente, `values.schema.json`, dependencies, hooks, testes, `.helmignore`, validação.
- Seção **RBAC (ServiceAccount + Role + RoleBinding)** em `reference/patterns.md` (origem: compare `kubernetes-deployment`).

### Removed
- `reference/core.md` — duplicata byte-a-byte de `reference/patterns.md`.

## [2.0.0] - 2026-05-28
### Changed
- SKILL.md padronizado no formato Framework 2.0 (caveman style)
- Adicionado versionamento semantico
- Adicionado keywords para trigger matching
- Seguranca referenciada via _shared/security/baseline.md
- Referencias reorganizadas

## [1.0.0] - 2024-01-10
### Added
- Versao inicial
