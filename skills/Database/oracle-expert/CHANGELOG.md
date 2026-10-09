# Changelog — oracle-expert

## [2.1.0] - 2026-06-30

### Changed
- Consolidação em `skills-optimizadas` (cruzamento skills/ ⨯ ADR-011-sqlserver-oracle, seção Oracle). Sem compare direto em `skills-compare/` → otimização + correção.
- Versão canônica alinhada à última estável: **Oracle 23ai** preferido para novos projetos; **19c** (LTS até 2027) para legados.
- SKILL.md reescrito no formato Framework 2.0 do precedente (postgres-expert/golang-expert): Princípios, Stack Canônica, Workflow Agentic, Quando Perguntar, Cross-references, seção de Segurança específica do domínio.
- Path do security baseline corrigido para `reference/security-baseline.md`.
- `description` enriquecida e `keywords` expandidas (1 → 8 reais) para trigger matching.

### Added
- Alinhamentos do ADR-011 (Oracle) ao SKILL.md: AL32UTF8 como charset obrigatório, PL/SQL apenas quando justifica (SQL puro primeiro), sequences/IDENTITY (nunca auto-increment por trigger), materialized views com refresh agendado, Edition-Based Redefinition (EBR) para deploy zero-downtime, Profile com resource/password limits, nota de licenciamento (partitioning/RAC/Diagnostic Pack exigem edições pagas).
- Anti-padrão `COALESCE` vs `NVL` promovido ao SKILL.md; nota de bitmap index restrito a DW.

### Removed
- `reference/patterns.md` — duplicata byte-a-byte de `reference/core.md` (`diff` idêntico; sem valor adicional).

### Decisões de divergência ADR-011
- Nenhuma contradição dura. O SKILL.md original já citava 19c/23ai, VPD, RMAN, Data Guard e UCP — alinhado ao ADR. ADR mais rico em pontos operacionais (EBR, materialized views, Profile, sequences vs trigger) → skill alinhada ao ADR. Sem compare para mesclar; conteúdo genérico permaneceu em `core.md`/`stack.md`.

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
