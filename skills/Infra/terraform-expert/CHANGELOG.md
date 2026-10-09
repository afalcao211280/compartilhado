# Changelog — terraform-expert

## [2.1.0] - 2026-06-30

### Changed
- Consolidação em `skills-optimizadas` (cruzamento skills/ ⨯ skills-compare/terraform-infrastructure ⨯ ADR-018).
- Path do security baseline corrigido para `reference/security-baseline.md`.
- `keywords` corrigido de `['terraform-expert']` (só o nome) para 7 termos reais de trigger (terraform, opentofu, iac, hcl, terragrunt, tfstate, module).
- `description` reescrita (pushy, ≤600 chars) cobrindo stack completa e gatilhos.
- SKILL.md alinhado ao ADR-018: princípios com o porquê, stack canônica com versões, providers por cloud, estrutura de projeto multi-env, workflow agentic, anti-padrões detalhados, "Quando Perguntar".
- Versões atualizadas para última estável: Terraform 1.9+ / OpenTofu 1.8+ (era 1.8+/1.7+), alinhado ao piso do ADR-018 (1.7+) e ao alvo de consolidação.

### Decisões de divergência ADR-018 (caso a caso)
- **IaC Engine**: Terraform **ou** OpenTofu documentados sem default (fork MPL 2.0 drop-in — escolha por projeto). Migração entre eles exige teste de compatibilidade.
- **State Backend**: multi-cloud sem default único — Azure Blob (padrão EVEO Azure), S3+DynamoDB (AWS), GCS (GCP). Todos com locking + encryption at rest.

### Added
- `reference/core.md` — novas seções condensadas do compare `terraform-infrastructure`: módulo multi-cloud AWS (VPC + ALB, backend S3+DynamoDB, `for_each` no lugar de `count`), variables/outputs AWS, script de deploy com workspaces (alternativa a CI).

### Removed
- `reference/patterns.md` — duplicata byte-a-byte de `reference/core.md`.
- Do compare: seção DO/DON'T e Quick Start (redundantes com anti-padrões e stack EVEO); `variables-and-outputs.md` isolado (conceito já coberto; exemplo AWS absorvido no core.md).

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
