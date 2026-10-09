# Changelog — azure-expert

## [2.1.0] - 2026-06-30

### Changed
- Consolidação em `skills-optimizadas` (cruzamento skills/ ⨯ ADR-013-azure; sem compare direto).
- SKILL.md reescrito e densificado no formato Framework 2.0 (princípios com porquê, stack canônica resumida, estrutura de projeto Bicep, workflow agentic, anti-padrões em tabela, checklist, quando perguntar).
- Path do security baseline corrigido para `reference/security-baseline.md`.
- keywords expandidas de 1 (`azure-expert`, auto-referente/inútil) para 7 termos reais (`azure`, `bicep`, `aks`, `managed-identity`, `key-vault`, `container-apps`, `azure-functions`).
- AGENTS.md alinhado ao formato do corpus e apontando para `skills-optimizadas`.
- Alinhamento ao ADR-013 (ADR mais rico): incorporados stack canônica completa, estrutura de projeto Bicep, Resource Groups por ambiente, Private Endpoints, App Configuration, Azure Policy, PIM e anti-padrões com alternativas.

### Removed
- `reference/patterns.md` — duplicata byte-a-byte de `reference/core.md`. Consolidado em `core.md` (ajustados ponteiros do SKILL.md).

### Decisões de divergência ADR-013 (caso a caso)
- **Bicep como IaC canônico** — o SKILL.md original e o ADR-013 convergem em Bicep (nunca ARM JSON). Alinhado. Terraform (`azurerm`) permanece como alternativa "perguntar ao time" apenas para multi-cloud, conforme consequência de lock-in documentada no ADR.
- **Divergência interna resolvida**: os `reference/` herdados usavam Terraform rotulado como "Padrão EVEO", em conflito com SKILL.md + ADR-013 (Bicep). Corrigido o rótulo do exemplo em `reference/core.md` para "alternativa multi-cloud" sem reescrever os snippets (código Terraform `azurerm` preservado como referência multi-cloud válida). SKILL.md e stack canônica passam a declarar Bicep canônico.

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
