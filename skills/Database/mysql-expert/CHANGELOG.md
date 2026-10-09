# Changelog — mysql-expert

## [2.1.0] - 2026-06-30

### Changed
- Consolidação em `skills-optimizadas` (cruzamento skills/ ⨯ skills-compare/mysql-patterns ⨯ ADR-010).
- Versão canônica alinhada à última estável LTS: **MySQL 8.4 LTS** (era 8.0+ no SKILL.md; 8.0.x mantido como aceitável). MariaDB 10.11 LTS como alternativa.
- SKILL.md reescrito no formato Framework 2.0 do precedente (postgres-expert/golang-expert): Princípios, Stack Canônica, Workflow Agentic, Quando Perguntar, Cross-references, seção de Segurança específica do domínio.
- Path do security baseline corrigido para `reference/security-baseline.md`.
- `description` enriquecida e `keywords` expandidas (1 → 8 reais) para trigger matching.
- Collation canônica alinhada ao ADR-010 em `core.md` e `stack.md`: `utf8mb4_unicode_ci` → **`utf8mb4_0900_ai_ci`** (default MySQL 8+).

### Added
- `reference/operations.md` — operações de produção condensadas do compare (alto valor genérico): divergências MySQL ⨯ MariaDB (`VALUES()`, `SHOW REPLICA/SLAVE STATUS`), sinais no `EXPLAIN`, keyset com row-value, JSON com coluna gerada, transações/deadlock/lock-wait checklist, filas com `SKIP LOCKED`, connection pools (ProxySQL/SQLAlchemy/mysql2), replicação read/write split + read-after-write, diagnóstico e postura de tuning do `my.cnf`.
- Alinhamentos do ADR-010 ao SKILL.md: engine InnoDB explícito (`default_storage_engine`), `ALGORITHM=INPLACE, LOCK=NONE` para índices em prod, FK com `ON DELETE` + índice na coluna, nota de ausência de RLS nativo (isolamento multi-tenant via app/views), ProxySQL como pool canônico.

### Removed
- `reference/patterns.md` — duplicata byte-a-byte de `reference/core.md` (`diff` idêntico; sem valor adicional).

### Descartes (skills-compare/mysql-patterns)
- Seções "Output Expectations" e "Related" (metadados de skill de review, não-stack).
- `my.cnf` genérico do compare (mesclado ao `operations.md`/`stack.md` da EVEO, sem duplicar).
- Repetição de exemplos de UPSERT/keyset já cobertos por `core.md` (condensada para as divergências relevantes).

### Decisões de divergência ADR-010
- Nenhuma contradição dura. ADR-010 mais específico na collation (`utf8mb4_0900_ai_ci`) e no pool (ProxySQL) → skill alinhada ao ADR. `stack.md` já citava 8.4 LTS; SKILL.md e banner do `stack.md` alinhados. Nota: ADR-010 lista ORM (Go) = Ent/sqlc — mantido (skill de linguagem decide via ADR-Go).

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
