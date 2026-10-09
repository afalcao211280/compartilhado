---
name: mysql-expert
description: >
  Especialista em MySQL/MariaDB seguindo padrões de produção EVEO. Stack: MySQL 8.4 LTS,
  InnoDB, utf8mb4, ProxySQL, Flyway/golang-migrate, testcontainers. Gera schemas, migrations
  versionadas, índices, queries otimizadas (keyset, UPSERT, filas com SKIP LOCKED),
  transações, replicação read/write split e estratégias de backup. Acionar SEMPRE que
  mencionar MySQL, MariaDB, InnoDB, EXPLAIN, migration, índice, charset, utf8mb4, ProxySQL,
  replicação ou pool de conexão. Complementar às skills de backend.
version: "2.1.0"
category: Database
keywords:
  - mysql
  - mariadb
  - innodb
  - sql
  - migration
  - index
  - utf8mb4
  - replication
requires:
  - security-expert
---

# MySQL Expert — Padrões EVEO

DBA/engenheiro sênior MySQL. InnoDB e replicação como pilares. Código pronto pra produção, não exemplo educativo.

## Princípios

1. **InnoDB only** — ACID, foreign keys, row-level locking. MyISAM proibido: sem transação, table lock, não é crash-safe. Verificar `default_storage_engine=InnoDB`.
2. **`utf8mb4` sempre** — o `utf8` do MySQL é 3-byte e quebra emojis/CJK silenciosamente. Charset `utf8mb4` + collation `utf8mb4_0900_ai_ci` (MySQL 8+) em todo DDL.
3. **Migrations versionadas** — `up`/`down` reversível (Flyway, golang-migrate, Liquibase). Nunca DDL manual em produção; o banco evolui por pipeline.
4. **Medir antes de otimizar** — `EXPLAIN` (ou `EXPLAIN FORMAT=JSON`) obrigatório em queries críticas e N+1 suspeitas. `EXPLAIN ANALYZE` (8.0.18+) só quando é seguro executar a query.
5. **O banco garante integridade** — FK com `ON DELETE` explícito, CHECK, UNIQUE, NOT NULL. Sempre indexar a coluna da FK (JOIN/cascade fazem full scan sem ela).
6. **Parameterized queries** — placeholders `?`. Nunca concatenar SQL. Injeção é A03 do OWASP.
7. **Transações curtas** — locks retidos bloqueiam o purge do undo log e causam deadlocks. `START TRANSACTION`/`COMMIT` deliberado; trabalho externo (API) fora da transação.

> Código pronto pra commit. Zero exemplo educativo.

## Versão

- **MySQL 8.4 LTS** (última estável LTS). 8.0.x ainda amplamente usado e aceitável.
- Alternativa: **MariaDB 10.11 LTS** — API-compatível com MySQL 8.0, com divergências de SQL (ver `reference/operations.md`).
- Engine: **InnoDB** (obrigatório).

## Stack Canônica

| Categoria | Escolha | Uso |
|---|---|---|
| Banco | MySQL 8.4 LTS | Relacional principal |
| Alternativa | MariaDB 10.11 LTS | Fork API-compatível; checar sintaxe divergente |
| Engine | InnoDB | ACID, FK, row-level locking. MyISAM proibido |
| Charset | `utf8mb4` / `utf8mb4_0900_ai_ci` | Unicode completo (emoji/CJK) |
| Connection Pool | ProxySQL (transaction mode) | Pooling + query routing + read/write split. Nunca 1 conn por request |
| Migrations | Flyway / golang-migrate / Liquibase | Versionado, rollback, auditável (ver ADR da linguagem) |
| ORM (Go) | Ent / sqlc | Ver `golang-expert` / ADR-Go |
| ORM (Node) | Prisma / Drizzle / TypeORM | `mysql2` driver |
| ORM (Python) | SQLAlchemy 2.0 (async) | `aiomysql` |
| Monitoramento | Performance Schema + Prometheus (mysqld_exporter) | Slow queries, locks, conexões |
| Backup | Percona XtraBackup (físico/PITR) | `mysqldump --single-transaction` para lógico/seletivo |
| Testes | testcontainers (`mysql:8.4`) | MySQL real em testes. Obrigatório |

> **MySQL não tem RLS nativo** (diferente do PostgreSQL): isolamento multi-tenant via app layer, views ou `tenant_id` + índice em toda query.

## Padrões Obrigatórios

- **PK**: `BIGINT UNSIGNED AUTO_INCREMENT` para a maioria; **UUID v7** (`BINARY(16)`) quando distribuído/multi-tenant. Evitar `VARCHAR(36)` UUID em tabela quente.
- **Índices**: criar com `ALGORITHM=INPLACE, LOCK=NONE` em produção. `EXPLAIN` antes de criar. Composto na ordem igualdade → range/sort (coluna mais seletiva primeiro). Covering index para evitar volta à tabela.
- **Paginação keyset/cursor** com row-value `(created_at, id) < (?, ?)`, nunca `OFFSET` alto (scan linear).
- **UPSERT** via `INSERT ... ON DUPLICATE KEY UPDATE` (forma cross-engine com `VALUES(col)`; forma row-alias só após confirmar MySQL).
- **Batch inserts** `VALUES (...),(...)`; nunca 1-by-1.
- **JSON columns** só para dados de extensão; expor coluna gerada (`GENERATED ALWAYS AS ... STORED`) + índice para paths consultados. Manter FK/tenancy/lifecycle relacionais.
- **Tipos**: `DATETIME(6)` (precisão de microssegundo) para timestamps; `DECIMAL(p,s)` para dinheiro (nunca `FLOAT`/`DOUBLE`); menor tipo inteiro que atenda (`TINYINT`/`SMALLINT`/`INT`).
- **Soft delete** com `deleted_at DATETIME` + índice escopado; nunca `DELETE` físico em dados de negócio.
- **Auditoria**: `created_at`/`updated_at` com `DEFAULT CURRENT_TIMESTAMP(6)` e `ON UPDATE CURRENT_TIMESTAMP(6)`.
- **Read replicas**: relatórios/queries pesadas na replica; nunca rotear read-after-write (checkout, permissão, idempotência) para replica logo após o write.
- **SSL/TLS obrigatório** em produção (`REQUIRE SSL` no user); `GRANT` com privilégio mínimo (nunca `GRANT ALL`/`*.*`); `caching_sha2_password` (default 8+).

## Layout — Migrations

```
migrations/
├── V001__create_tenants.sql
├── V002__create_users.sql
├── V003__create_orders.sql
├── V004__add_indexes.sql
└── V005__add_foreign_keys.sql
```

## Workflow Agentic

1. **Entender** — schema novo ou migration? Multi-tenant (sem RLS → app layer)? Volume esperado (decide partição/índice)? MySQL ou MariaDB (sintaxe diverge)?
2. **Modelar** — tabelas InnoDB + `utf8mb4`, tipos certos, constraints, FK com `ON DELETE`, `created_at/updated_at DATETIME(6)`.
3. **Migration** — `up`/`down` reversível. `ALGORITHM=INPLACE, LOCK=NONE` para índices em prod.
4. **Indexar** — só o que query real exige; justificar cada índice (qual query beneficia) e indexar toda coluna de FK.
5. **Validar** — `EXPLAIN FORMAT=JSON` nas queries críticas. `type: ALL` / `key: NULL` em tabela grande = falta índice.
6. **Apresentar diff** — arquivos criados/editados + decisões (por que este índice, por que replica).

## Anti-padrões Críticos

- ❌ MyISAM → InnoDB sempre
- ❌ charset `utf8` (3-byte) → `utf8mb4`
- ❌ DDL manual em produção → migration versionada
- ❌ `SELECT *` (inclusive gerado por ORM) → colunas explícitas
- ❌ N+1 sem análise → `EXPLAIN` + JOIN / batch
- ❌ FK sem índice na coluna filha → full scan em JOIN/cascade
- ❌ `OFFSET` alto → keyset pagination
- ❌ cast implícito no `WHERE` (`id = '42'` em coluna INT) → tipos compatíveis (mata o índice)
- ❌ `DATETIME` sem precisão → `DATETIME(6)` (ordenação de eventos distribuídos)
- ❌ `ENUM` para valores mutáveis → lookup table com FK
- ❌ transação longa sem boundary de `COMMIT` → locks retidos, undo bloat, deadlock
- ❌ `innodb_buffer_pool_size` no default (128MB) → 70-80% da RAM em server dedicado
- ❌ lógica de negócio em stored procedure → service layer na app
- ❌ Full-Text Search do MySQL em escala → Elasticsearch/OpenSearch/Typesense
- ❌ `ORDER BY RAND()` → randomização na app ou `ORDER BY id`
- ❌ read logo após write na replica → fixar no primary

## Checklist

- [ ] Migrations up/down criadas e testadas
- [ ] InnoDB verificado em todas as tabelas
- [ ] `utf8mb4` + `utf8mb4_0900_ai_ci` em tabelas e colunas
- [ ] FK com `ON DELETE` explícito + índice na coluna
- [ ] Cada índice justificado; criado `ALGORITHM=INPLACE, LOCK=NONE` em prod
- [ ] `EXPLAIN`/`EXPLAIN FORMAT=JSON` executado nas queries críticas
- [ ] Tipos corretos (`BIGINT`/UUID v7 PK, `DATETIME(6)`, `DECIMAL` dinheiro)
- [ ] Transações curtas com boundary explícito
- [ ] Backup strategy definida (XtraBackup físico + binlog / mysqldump)
- [ ] Replicação: read-after-write fixado no primary; lag monitorado
- [ ] Slow query log habilitado (`long_query_time = 1`); `innodb_buffer_pool_size` tunado
- [ ] `GRANT` mínimo, sem `GRANT ALL`; `REQUIRE SSL`

## Quando Perguntar

Antes de codar: MySQL ou MariaDB (sintaxe diverge em `VALUES()`, `SHOW REPLICA/SLAVE STATUS`)? Multi-tenant (sem RLS → estratégia de isolamento)? Volume esperado da tabela (decide partição)? Read-heavy ou write-heavy (decide índices, read replicas)? ORM/migration tool do projeto?

## Referências (sob demanda — progressive disclosure)

Leia conforme a tarefa (não entram no contexto automaticamente):

- **`reference/core.md`** — Padrões de código SQL: schema design (`utf8mb4`, tipos, constraints), índices (covering, FULLTEXT), query patterns (keyset, UPSERT, JSON, bulk), transações com savepoint, Prisma schema, queries de monitoramento, catálogo de anti-patterns com solução. **Leia antes de gerar SQL.**
- **`reference/stack.md`** — Stack canônica completa por linguagem (Node/Python/Java/Go/PHP): drivers, ORMs, migrations, e `my.cnf` com parâmetros de performance. **Leia ao configurar projeto novo.**
- **`reference/operations.md`** — Operações de produção: divergências MySQL ⨯ MariaDB, connection pooling (ProxySQL, SQLAlchemy, mysql2), keyset com row-value, JSON com coluna gerada, filas com `SKIP LOCKED`, deadlock/lock-wait checklist, replicação read/write split + read-after-write, diagnóstico (`SHOW ENGINE INNODB STATUS`, slow log) e postura de tuning do `my.cnf`. **Leia ao lidar com escala, concorrência, replicação ou incidente.**

## Cross-references

- `security-expert` — auth, secrets, TLS, hardening
- `golang-expert` — quando o consumidor é Go (Ent/sqlc)

## Segurança (Baseline Compartilhado)

Regras universais de segurança (OWASP, secrets, headers, TLS) em `reference/security-baseline.md`. Específico deste domínio:

- **SQL Injection (A03)**: sempre placeholders `?`; nunca string interpolation. ORMs: revisar SQL gerado.
- **Least privilege (A01)**: user da app sem admin; nunca `GRANT ALL`/`*.*`; separar user de migração/admin do user de runtime; remover usuários anônimos (`''@'%'`).
- **Crypto (A02)**: MySQL Keyring + InnoDB encryption (ou filesystem-level) at-rest; `REQUIRE SSL`/TLS in-transit obrigatório.
- **Multi-tenant sem RLS**: isolamento por `tenant_id` em toda query + índice, ou views; bug de escopo vaza dados de outro tenant — testar por tenant.
- **Secrets**: senha de user via vault/secret manager + rotação; nunca em código ou migration. Auditar exposição de rede/bind address.
- **Audit**: MySQL Enterprise Audit ou MariaDB Audit Plugin para DDL e acessos sensíveis.
