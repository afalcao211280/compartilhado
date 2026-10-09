# ADR-010: MySQL — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Projetos backend na EVEO que utilizam MySQL como banco relacional exigem padronização de engine, charset, connection pooling, e operações. A ausência de diretrizes resulta em uso inadvertido de MyISAM, charset inconsistente (emojis quebrados), e configurações de pool inadequadas para produção.

## Decisão

Adotar MySQL 8.0+ como banco relacional. InnoDB exclusivamente — MyISAM proibido. Charset `utf8mb4` com collation `utf8mb4_0900_ai_ci`. ProxySQL para connection pooling em produção. Migrations versionadas obrigatórias. EXPLAIN em queries críticas.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| Banco | MySQL | 8.0+ | PostgreSQL, MariaDB | Ecossistema, replica, JSON support |
| Engine | InnoDB | — | MyISAM (proibido) | ACID, foreign keys, row-level locking |
| Charset | utf8mb4_0900_ai_ci | — | utf8 (3-byte, quebra emojis) | Suporte completo a Unicode/emoji |
| Connection Pool | ProxySQL | — | HAProxy, built-in pool | Query routing, read/write split, caching |
| Migrations | Flyway / golang-migrate | — | Liquibase, raw SQL | Versionado, rollback |
| ORM (Go) | Ent / sqlc | — | GORM | Ver ADR-Go |
| ORM (Node) | Prisma / TypeORM | — | Knex, Sequelize | Ver ADR-Node |
| Monitoramento | Performance Schema + Prometheus | — | — | Slow queries, locks, connections |
| Backup | mysqlbackup / XtraBackup | — | mysqldump | Hot backup, point-in-time recovery |
| Replica | Async/Semi-sync replication | — | Group Replication | Escalabilidade de leitura, HA |

## Padrões Obrigatórios

- **InnoDB only**. Verificar `default_storage_engine=InnoDB`. MyISAM proibido em produção.
- **`utf8mb4` charset + `utf8mb4_0900_ai_ci` collation** obrigatório. Nunca `utf8` (3-byte).
  ```sql
  CREATE DATABASE app_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
  ```
- **ProxySQL** para connection pooling e read/write split em produção. Nunca 1 connection per request.
- **Migrations versionadas obrigatórias**. Nunca DDL manual em produção.
- **EXPLAIN** em queries críticas e N+1 suspeitas. `EXPLAIN FORMAT=JSON` para análise detalhada.
- **Foreign Keys** com ON DELETE behavior explícito (CASCADE, SET NULL, RESTRICT).
- **Índices**: criar com `ALGORITHM=INPLACE LOCK=NONE` em produção. EXPLAIN antes de criar.
- **JSON columns** para dados semi-estruturados — MySQL 8 suporta `JSON` type com `JSON_TABLE()`.
- **Window functions** (MySQL 8+) para queries analíticas — evitar subqueries correlacionadas.
- **CTEs** (`WITH` clause) para queries complexas — melhor legibilidade que subqueries aninhadas.
- **Soft delete** com `deleted_at DATETIME` — nunca DELETE físico em dados de negócio.
- **Auto-increment PKs** para tabelas simples. UUID v7 para distribuído/multi-tenant.
- **Binary logging** habilitado para replica e point-in-time recovery.

## Estrutura de Projeto — Migrations

```
migrations/
├── V001__create_tenants.sql
├── V002__create_users.sql
├── V003__create_orders.sql
├── V004__add_indexes.sql
└── V005__add_foreign_keys.sql
```

## Anti-padrões

| Proibido | Alternativa |
|---|---|
| MyISAM engine | InnoDB |
| `utf8` charset (3-byte) | `utf8mb4` |
| DDL manual em produção | Migrations versionadas |
| `SELECT *` | Colunas explícitas |
| N+1 queries sem EXPLAIN | EXPLAIN FORMAT=JSON + JOIN |
| DELETE físico em dados de negócio | Soft delete com `deleted_at` |
| 1 connection per request | ProxySQL connection pooling |
| FK sem ON DELETE behavior | CASCADE / SET NULL / RESTRICT explícito |
| Índices sem EXPLAIN | EXPLAIN antes de criar |
| Subqueries correlacionadas | CTEs e window functions |
| `ORDER BY RAND()` | Application-level randomization ou `ORDER BY id` + offset |

## Consequências

**Positivas**:
- InnoDB garante ACID, foreign keys, e row-level locking
- `utf8mb4` suporta Unicode completo (emojis, caracteres asiáticos)
- ProxySQL permite read/write split, query routing, e caching
- MySQL 8+ CTEs e window functions reduzem complexidade de queries

**Negativas**:
- InnoDB usa mais disco e memória que MyISAM (trade-off aceitável pela consistência)
- ProxySQL adiciona uma camada operacional (monitoramento, configuração)
- MySQL replication lag pode impactar leituras recentes — usar semi-sync para dados críticos

**Riscos**:
- Charset `utf8` (3-byte) ainda é default em algumas ferramentas — exigir `utf8mb4` em todo DDL
- ProxySQL query rules mal configuradas podem rotear writes para replicas — usar hostgroups separados
- Falta de RLS nativo (diferente de PostgreSQL) — isolamento de tenant via app layer ou views

## Referências

- `skills/Database-Relacional/mysql-expert/SKILL.md`
- Documentação MySQL 8.0: https://dev.mysql.com/doc/refman/8.0/
- ProxySQL: https://proxysql.com/
- MySQL InnoDB: https://dev.mysql.com/doc/refman/8.0/en/innodb-introduction.html