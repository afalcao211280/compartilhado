# Changelog — gcp-expert

## [2.1.0] - 2026-06-30

### Changed
- Consolidação em `skills-optimizadas` (cruzamento skills/ ⨯ ADR-015-gcp; sem compare direto).
- SKILL.md reescrito e densificado no formato Framework 2.0 (princípios com porquê, stack canônica resumida, estrutura de projeto Terraform, workflow agentic, anti-padrões em tabela, checklist, quando perguntar).
- Path do security baseline corrigido para `reference/security-baseline.md`.
- keywords expandidas de 1 (`gcp-expert`, auto-referente/inútil) para 7 termos reais (`gcp`, `terraform`, `cloud-run`, `gke`, `workload-identity`, `secret-manager`, `bigquery`).
- AGENTS.md alinhado ao formato do corpus e apontando para `skills-optimizadas`.
- Alinhamento ao ADR-015 (ADR mais rico): incorporados stack canônica completa, estrutura de projeto Terraform, Organization Policies como guardrails, VPC Service Controls, Private Service Connect, Binary Authorization e anti-padrões com alternativas.

### Removed
- `reference/patterns.md` — duplicata byte-a-byte de `reference/core.md`. Consolidado em `core.md` (ajustados ponteiros do SKILL.md).

### Decisões de divergência ADR-015 (caso a caso)
- **Cloud Run como compute padrão** mantido (skill vence — mais específica que o ADR, que lista GKE+Cloud Run como pares). GKE reservado para workloads Kubernetes.
- **Terraform como IaC canônico** — SKILL.md e ADR-015 convergem. Sem divergência dura. Pulumi permanece como alternativa "perguntar ao time".

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
