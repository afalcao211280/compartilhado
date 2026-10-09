# ADR-009: PostgreSQL — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Projetos backend na EVEO que utilizam PostgreSQL como banco relacional principal exigem padronização de migrations, connection pooling, particionamento, e segurança (RLS para multi-tenant). A ausência de diretrizes resulta em schemas não versionados, queries sem análise de plano, e configurações de pool subótimas.

## Decisão

Adotar PostgreSQL 16+ como banco relacional principal. Migrations versionadas obrigatórias (golang-migrate, flyway, ou Prisma migrate). EXPLAIN ANALYZE em queries críticas. Row-Level Security (RLS) para multi-tenant. PgBouncer para connection pooling em produção. Partitioning para tabelas grandes.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| Banco | PostgreSQL | 16+ | MySQL, SQL Server | Extensões, RLS, JSONB, particionamento |
| Migrations | golang-migrate / flyway / Prisma migrate | — | Liquibase, raw SQL | Versionado, rollback, auditável |
| Connection Pool | PgBouncer | — | Built-in (pgbouncer) | Transaction pooling, production grade |
| ORM (Go) | Ent / sqlc | — | GORM, pgx bare | Ver ADR-Go para decisão |
| ORM (Node) | Prisma / Drizzle | — | TypeORM, Knex | Ver ADR-Node para decisão |
| Monitoramento | pg_stat_statements + Prometheus | — | — | Query performance, slow queries |
| Backup | pg_basebackup + WAL archiving | — | pg_dump | Point-in-time recovery |
| Extensões | uuid-ossp, pgcrypto, pg_trgm, btree_gist | — | — | UUID gen, crypto, trigram search |

## Padrões Obrigatórios

- **Migrations versionadas obrigatórias**. Nunca DDL manual em produção. Cada migration com `up` e `down`.
- **EXPLAIN ANALYZE** em queries críticas e N+1 suspeitas. Medir antes de otimizar.
- **Row-Level Security (RLS)** para multi-tenant:
  ```sql
  ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
  CREATE POLICY tenant_isolation ON orders USING (tenant_id = current_setting('app.tenant_id')::uuid);
  ```
- **Connection pooling**: PgBouncer em modo transaction pooling em produção. Nunca 1 connection per request.
- **Particionamento** para tabelas > 10M rows: range partitioning por data, list partitioning por tenant.
- **Índices**: criar com CONCURRENTLY em produção. EXPLAIN antes de criar.
- **JSONB** para dados semi-estruturados — nunca JSON text columns.
- **UUID v7** para primary keys (timestamp-ordered, sortable).
- **Soft delete** com `deleted_at TIMESTAMP` — nunca DELETE físico em dados de negócio.
- **Constraints obrigatórias**: NOT NULL, CHECK, UNIQUE, FK com ON DELETE behavior explícito.
- **Schema versioning**: tabela `_migrations` com hash e timestamp de apply.
- **Prepared statements** para queries frequentes (reduz parse time).
- **Vacuum**: autovacuum tuning para tabelas com alto write volume.

## Estrutura de Projeto — Migrations

```
migrations/
├── 001_create_tenants.up.sql
├── 001_create_tenants.down.sql
├── 002_create_users.up.sql
├── 002_create_users.down.sql
├── 003_rls_policies.up.sql
├── 003_rls_policies.down.sql
├── 004_create_orders_partitioned.up.sql
└── 004_create_orders_partitioned.down.sql
```

## Anti-padrões

| Proibido | Alternativa |
|---|---|
| DDL manual em produção | Migrations versionadas |
| `SELECT *` | Colunas explícitas |
| N+1 queries sem análise | EXPLAIN ANALYZE + JOIN/eager loading |
| `text` column para JSON | `JSONB` column |
| UUID v4 para PK (random) | UUID v7 (timestamp-ordered) |
| DELETE físico em dados de negócio | Soft delete com `deleted_at` |
| 1 connection per request | PgBouncer transaction pooling |
| FK sem ON DELETE behavior | ON DELETE CASCADE / SET NULL / RESTRICT explícito |
| Índices sem EXPLAIN | EXPLAIN ANALYZE antes de criar |
| Tabelas grandes sem particionamento | Range/list partitioning |
| Queries sem prepared statements | Prepared statements para queries frequentes |
| `any` em types (ORM) | Branded types para IDs |

## Consequências

**Positivas**:
- RLS garante isolamento de tenant no nível do banco — impossível vazar dados mesmo com bug na app
- PgBouncer resolve o problema de connection exhaustion em produção
- UUID v7 permite indexação eficiente (sortable, timestamp-ordered)
- Partitioning mantém performance em tabelas com centenas de milhões de rows

**Negativas**:
- RLS adiciona complexidade nas queries (SET app.tenant_id por request)
- PgBouncer em transaction mode limita prepared statements e advisory locks
- Migrations requerem disciplina e pipeline automatizado

**Riscos**:
- PgBouncer em transaction mode vs session mode — decisões de pooling impactam funcionalidades (LISTEN/NOTIFY, prepared statements)
- Partitioning mal configurado pode ser pior que tabela simples — medir antes de particionar
- RLS policies bugs podem bloquear dados legítimos — testar com cada tenant

## Referências

- `skills/Database-Relacional/postgres-expert/SKILL.md`
- Documentação PostgreSQL 16: https://www.postgresql.org/docs/16/
- PgBouncer: https://www.pgbouncer.org
- UUID v7: RFC 9562