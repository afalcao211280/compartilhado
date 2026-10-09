# Changelog — kafka-expert

## [2.1.0] - 2026-06-30

### Changed
- Consolidação em `skills-optimizadas` (cruzamento skills/ ⨯ skills-compare/kafka-development; sem ADR dedicado).
- **`description` reduzida** de keyword-stuffing (>1000 chars, reprovava no schema maxLength 600) para versão enxuta e pushy; keywords movidas para o array `keywords[]`.
- `keywords` ampliadas de 7 para 10 termos reais (adicionados consumer-group, schema-registry, kafka-streams, exactly-once; removido `distributed` genérico).
- Path do security baseline corrigido para `reference/security-baseline.md`.
- SKILL.md reescrito no padrão otimizado: seção **Princípios** com o porquê, seção de **Segurança** com ameaças específicas do domínio (SSL/SASL, ACLs, `auto.create.topics`), **Cross-references**.
- Ponteiros de referência atualizados para `reference/patterns.md` e `reference/stack.md`.

### Added
- Seção **Padrões Arquiteturais (event-driven)** no SKILL.md — Event Sourcing, CQRS, Saga, CDC (origem: skills-compare/kafka-development, condensado).

### Removed
- `reference/core.md` — stub redundante (duplicava as tabelas de decisão já presentes no SKILL.md e continha seções vazias "Padrões Obrigatórios"/"Workflow Agentic" sem conteúdo). O conteúdo real permanece em `reference/patterns.md`, referenciado pelo SKILL.md.

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
