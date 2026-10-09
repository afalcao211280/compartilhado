# Changelog — cicd-expert

## [2.4.0] - 2026-07-16

### Added
- `SKILL.md` — nota SonarQube/Quality Gate no padrão EVEO: coverage ≥80%, gitleaks/`secrets:S6694`, IDs Go (`S138`/`S107`/`S3776`), publish `sonar.go.coverage.reportPaths`; ponteiro curto de que o gate AIOps (se houver) é step externo em `pipeline-templates`.
- `reference/core.md` §3 — thresholds Sonar com IDs recorrentes + snippet Go (`coverage.out` → Sonar).

### Changed
- Job Go do padrão real: `go test -race` passa a mencionar `-coverprofile=coverage.out`.

## [2.3.0] - 2026-07-14

### Added
- `SKILL.md` — tabela das 8 stacks suportadas pelo padrão real (Go/Python piloteados; Java/NestJS/React-Next.js/Vue/Angular como draft, gerados a partir dos ADRs 002/004/005/006/007/008). Templates novos escritos em `~/projetos/pipeline-templates/pr/` (repo separado, fora de `ai-hardness`). Change OpenSpec: `scaffold-pipeline-multi-stack`.

## [2.2.1] - 2026-07-14

### Added
- `SKILL.md` — subseção "Pré-requisitos de execução" dentro de "EVEO — Padrão Real": lista declarativa (Harbor, Azure DevOps, Kubernetes por ambiente, aplicação) do que precisa existir para a pipeline rodar, validado ativamente pelo command `/scaffold-pipeline` (Etapa 4). Change OpenSpec: `scaffold-pipeline-readiness-check`.

## [2.2.0] - 2026-07-14

### Added
- `SKILL.md` — seção "EVEO — Padrão Real (Azure DevOps + `pipeline-templates`)", inline (não em `reference/`, por convenção de conteúdo específico-empresa): bloco `resources.repositories`/`extends`, nomes de stage/job reais, `scaffold-repo.sh` (flags + geração), gate Go/Python (Node/Java não suportados hoje), variable groups, fluxo `dev/uat/prd` v1 vs. Fase 2, checklist de nomenclatura consistente e gotchas operacionais. Referencia o novo command `/scaffold-pipeline`.
- Relacionado à reconciliação de `ADR-025` (seção "Estado Real (V1)") e ao novo command `ai-hardness/commands/scaffold-pipeline.md`. Change OpenSpec: `scaffold-cicd-pipeline`.

## [2.1.2] - 2026-07-01

### Changed
- `reference/best-practices.md` — enriquecimento profundo: de checklist raso para referência por concern (estágios, cache, matrix, security scanning SAST/SCA/container/IaC/secret, OIDC/secrets, deploy strategies, rollback) com snippet real por plataforma (GitHub Actions, GitLab CI, Azure DevOps, Jenkins), alinhado ao ADR-022. Preenche os gaps de GitLab CI e Jenkins.
- `reference/core.md` — ponteiro corrigido: `reference/platforms.md` (inexistente) → `reference/best-practices.md`.
- `SKILL.md` — descrição do ponteiro para `best-practices.md` atualizada.

## [2.1.1] - 2026-07-01

### Added
- `reference/best-practices.md` — enriquecimento (checklist condensado, EVEO-aligned).

## [2.1.0] - 2026-06-30

### Changed
- Consolidação em skills-optimizadas (skills/ ⨯ skills-compare/ ⨯ ADR): baseline `../../`, keywords/description ajustadas, dedup core/patterns quando idêntico.


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
