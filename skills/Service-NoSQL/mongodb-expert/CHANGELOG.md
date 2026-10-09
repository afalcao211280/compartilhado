# Changelog — mongodb-expert

## [2.1.0] - 2026-06-30

### Changed
- Consolidação em `skills-optimizadas` (cruzamento skills/ ⨯ skills-compare/mongodb-schema-design ⨯ ADR-012).
- Path do security baseline corrigido para `reference/security-baseline.md`.
- Versão canônica elevada de MongoDB 7+ para **8+** (última estável); imagem testcontainers `mongo:8.0`. ADR-012 mantém 7+ como piso (divergência só de versão, sem contradição de padrões).
- `keywords` corrigidas de `['mongodb-expert']` para 7 termos reais (mongodb, mongoose, aggregation, schema-design, nosql, document-model, atlas).
- SKILL.md reescrito no padrão otimizado: princípios com porquê, tabela de decisão embed vs reference, seção de patterns, anti-padrões expandidos.

### Added
- `reference/schema-design.md` — design de schema condensado dos padrões oficiais MongoDB (origem: skills-compare/mongodb-schema-design, 17 arquivos): fundamentos (document model, embed vs reference, relacionamentos 1:1/1:few/1:many/M:N/árvore, validation, tamanho 16MB), anti-padrões (coleções/`$lookup`/índices desnecessários), patterns (subset, extended reference, computed, approximation, bucket, attribute, polymorphic, outlier, archive, time series, document/schema versioning).

### Removed
- `reference/patterns.md` — duplicata byte-a-byte de `reference/core.md` (redundância eliminada).

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
