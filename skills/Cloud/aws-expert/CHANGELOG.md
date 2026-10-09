# Changelog — aws-expert

## [2.1.0] - 2026-06-30

### Changed
- Consolidação em `skills-optimizadas` (cruzamento skills/ ⨯ skills-compare/ ⨯ ADR-014).
- SKILL.md reescrito e densificado no formato Framework 2.0 (princípios com porquê, stack canônica resumida, estrutura de projeto, workflow agentic, anti-padrões em tabela, checklist, quando perguntar).
- Path do security baseline corrigido para `reference/security-baseline.md`.
- keywords expandidas para 7 termos reais (`aws`, `terraform`, `ecs-fargate`, `lambda`, `iam`, `cloudfront`, `vpc`).
- AGENTS.md alinhado ao formato do corpus e apontando para `skills-optimizadas`.
- Alinhamento ao ADR-014: incorporado CDK como alternativa de IaC, estrutura de projeto Terraform, e anti-padrões com alternativas (ADR mais rico).

### Added
- `reference/cloudfront.md` — CloudFront/CDN com Terraform (origem: skills-compare/aws-cloudfront-cdn), preenchendo lacuna real (a skill citava CloudFront na stack sem nenhum padrão de código). Modernizado de OAI (legado) para Origin Access Control (OAC), `forwarded_values` → cache/origin request policies, response headers de segurança, WAF e alarms.

### Removed
- `reference/core.md` — duplicata byte-a-byte de `reference/patterns.md`. Consolidado em `patterns.md`.

### Decisões de divergência ADR-014 (caso a caso)
- **ECS Fargate como compute padrão** mantido (skill vence — mais específica que o ADR, que lista EKS+Lambda como primários). EKS reservado para workloads Kubernetes.
- **Terraform como IaC padrão** mantido (skill vence). CDK permanece como alternativa "perguntar ao time", conforme ADR.

### Descartes do compare (aws-cloudfront-cdn)
- `references/cloudfront-distribution-with-aws-cli.md` — CLI imperativo, contraria o princípio IaC; coberto pela versão Terraform.
- `scripts/validate-config.sh` e `templates/config-starter.yaml` — boilerplate genérico só com TODOs vazios, sem substância.

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
