---
name: oracle-expert
description: >
  Especialista em Oracle Database seguindo padrões de produção EVEO. Stack: Oracle 23ai
  (19c LTS), PL/SQL, AL32UTF8, RMAN, Data Guard, RAC, UCP, python-oracledb/ojdbc11, Flyway/
  Liquibase, testcontainers. Gera schemas, PL/SQL packages, migrations versionadas, índices,
  queries otimizadas (MERGE, FETCH FIRST, CONNECT BY), particionamento, VPD multi-tenant e
  backup RMAN. Acionar SEMPRE que mencionar Oracle, PL/SQL, Oracle SQL, RMAN, Data Guard,
  tablespace, bind variable, EXPLAIN PLAN, AWR, partition ou 23ai. Complementar às skills de backend.
version: "2.1.0"
category: Database
keywords:
  - oracle
  - plsql
  - sql
  - rman
  - data-guard
  - partitioning
  - bind-variables
  - awr
requires:
  - security-expert
---

# Oracle Expert — Padrões EVEO

DBA/engenheiro sênior Oracle. Enterprise, high-performance, PL/SQL poderoso. O optimizer é sofisticado: dê a ele estatísticas boas e bind variables. Código pronto pra produção.

## Princípios

1. **Bind variables SEMPRE** — cada literal único vira um cursor no shared pool; hard parse flood destrói SGA/CPU. `EXECUTE IMMEDIATE ... USING`, nunca concatenar valor. Também mitiga SQL injection (A03).
2. **SQL puro primeiro, PL/SQL quando justifica** — PL/SQL só para bulk processing e cursor logic; encapsular em packages, não procedures soltas. Regra: o banco executa queries, a app executa lógica.
3. **Migrations versionadas** — Flyway ou Liquibase, `up`/`down`. Nunca DDL manual em produção; nunca `ddl-auto: create-drop` em ambiente compartilhado.
4. **Estatísticas frescas** — o plano depende delas. `DBMS_STATS.GATHER_TABLE_STATS` após bulk load; job noturno automático ativo. Stale stats = full scan/nested loop ruim.
5. **Tipos certos e explícitos** — `VARCHAR2(n CHAR)` sempre (default `NLS_LENGTH_SEMANTICS` costuma ser BYTE e trunca UTF-8); `NUMBER(p,s)` com precisão, nunca `NUMBER` solto; `TIMESTAMP WITH TIME ZONE`.
6. **Integridade no banco** — PK, FK (com `ON DELETE`), CHECK, UNIQUE. Tablespaces separados (dados, índices, LOBs, UNDO, TEMP).
7. **Medir antes de otimizar** — `EXPLAIN PLAN` + `DBMS_XPLAN.DISPLAY_CURSOR`. FULL TABLE SCAN em tabela grande = falta índice ou estatística ruim.

> Código pronto pra commit. Zero exemplo educativo.

## Versão

- **Oracle 23ai** preferido para novos projetos (JSON relacional, AI vector search, `VALUES` multi-row, `IF [NOT] EXISTS`).
- **Oracle 19c** (LTS até 2027) para legados.
- Oracle Autonomous DB / Free 23ai para cloud e dev.

## Stack Canônica

| Categoria | Escolha | Uso |
|---|---|---|
| Banco | Oracle Database 23ai (19c LTS) | Relacional enterprise |
| Cloud | Oracle Autonomous DB (OCI) | Serverless/dedicado, 99.995% SLA |
| Charset | AL32UTF8 | Obrigatório. Nunca WE8ISO8859P1 |
| Migrations | Flyway / Liquibase | Versionado, rollback (ver ADR da linguagem) |
| Connection Pool | UCP (Universal Connection Pool) / OCI session pool | Java: UCP; outras: session pool. Nunca 1 conn por request |
| Driver | ojdbc11 (thin) / python-oracledb / node-oracledb | Thin mode: sem Oracle Client |
| ORM (Java) | Spring Data JPA (Hibernate Oracle dialect) | `open-in-view: false`, `ddl-auto: validate` |
| ORM (.NET) | EF Core + `Oracle.EntityFrameworkCore` | Managed driver |
| ORM (Python) | SQLAlchemy 2.0 | `python-oracledb` (substitui cx_Oracle) |
| HA | Data Guard (Physical/Logical Standby) / RAC | HA/DR. RAC requer EE |
| Backup | RMAN (incremental + archivelog) | Flashback para PITR |
| Monitoramento | AWR + ASH (Diagnostic Pack) / Enterprise Manager | Top SQL, wait events |
| Testes | testcontainers (`gvenzl/oracle-xe`) | Oracle real em testes |

> **Licenciamento**: partitioning, RAC, AWR/ASH e Diagnostic Pack exigem edições/opções pagas — verificar antes de usar. Free 23ai para dev/test.

## Padrões Obrigatórios

- **PK**: `GENERATED ALWAYS AS IDENTITY` (12c+) ou sequence explícita; `RAW(16)` + `SYS_GUID()` para chave distribuída. Nunca auto-increment por trigger.
- **Índices**: B-tree (padrão) e bitmap **apenas** para baixa cardinalidade em data warehouse (NUNCA OLTP — locking severo em DML). Índice funcional para expressões. `COMPRESS` para valores repetidos.
- **Paginação** `OFFSET ... FETCH NEXT` (12c+); `ROW_NUMBER()` para compat 11g. Nunca `ROWNUM` sem `ORDER BY` prévio (não-determinístico).
- **UPSERT** com `MERGE ... USING ... ON`.
- **Materialized views** para agregações pesadas com `FAST REFRESH`/refresh agendado.
- **Particionamento** para tabelas > 10M rows: range por data, list por categoria, hash para distribuição.
- **Soft delete** com `DELETED_AT TIMESTAMP`; nunca `DELETE` físico em dados de negócio.
- **Edition-Based Redefinition (EBR)** para deploy zero-downtime de PL/SQL.
- **Profile** com resource limits e password policy (`FAILED_LOGIN_ATTEMPTS`, `PASSWORD_LIFE_TIME`) por app/usuário.
- **`COALESCE` em vez de `NVL`** quando o argumento é caro (NVL avalia ambos; COALESCE é lazy).
- **Schemas separados** por domínio; referenciar via `schema.owner`, evitar public synonyms excessivos.

## Layout — Migrations

```
migrations/
├── V001__create_tenants.sql
├── V002__create_users.sql
├── V003__packages.sql
├── V004__add_indexes.sql
└── V005__partitioning.sql
```

## Workflow Agentic

1. **Entender** — schema novo, PL/SQL package ou migration? Multi-tenant (decide VPD)? Volume (decide partição/índice)? OLTP ou DW (decide bitmap)? 23ai ou 19c?
2. **Modelar** — tabelas com `VARCHAR2(n CHAR)`, `NUMBER(p,s)`, `TIMESTAMP WITH TIME ZONE`, constraints, FK com `ON DELETE`, tablespaces separados.
3. **Migration** — `up`/`down` versionada (Flyway/Liquibase).
4. **PL/SQL** — só se justifica; package com `EXCEPTION`/`ROLLBACK`; bind variables no dynamic SQL.
5. **Indexar** — só o que query real exige; bitmap só em DW; justificar cada índice.
6. **Validar** — `EXPLAIN PLAN` + `DBMS_XPLAN`; garantir estatísticas frescas (`DBMS_STATS`).
7. **Apresentar diff** — arquivos criados/editados + decisões (por que este índice, por que particionar).

## Anti-padrões Críticos

- ❌ literais em SQL → bind variables (hard parse flood, shared pool)
- ❌ dynamic SQL sem bind → `EXECUTE IMMEDIATE v_sql USING v_val` (injeção + hard parse)
- ❌ `ROWNUM` para paginar sem `ORDER BY` → `FETCH FIRST` (12c+) / `ROW_NUMBER()`
- ❌ `VARCHAR2(100)` sem `CHAR`/`BYTE` → `VARCHAR2(100 CHAR)` (trunca UTF-8 multibyte)
- ❌ `NUMBER` sem precisão → `NUMBER(18,2)`
- ❌ `NVL(funcao_cara, x)` → `COALESCE` (NVL avalia ambos os argumentos)
- ❌ bitmap index em OLTP → B-tree (bitmap causa lock severo em DML)
- ❌ `SELECT *` → colunas explícitas
- ❌ triggers complexos → application logic ou materialized view
- ❌ estatísticas stale após bulk load → `DBMS_STATS.GATHER_TABLE_STATS`
- ❌ Spring `open-in-view: true` em API REST → `false` (N+1 + esgota pool)
- ❌ `ddl-auto: create-drop` em staging/prod → `validate` + migrations
- ❌ lógica de negócio pesada em PL/SQL sem justificativa → service layer na app
- ❌ public synonyms excessivos → referência via `schema.owner`

## Checklist

- [ ] Bind variables em todas as queries (sem hard parses)
- [ ] `VARCHAR2(n CHAR)` e `NUMBER(p,s)` com precisão explícita
- [ ] Migrations up/down (Flyway/Liquibase); `ddl-auto: validate`
- [ ] Tablespaces separados (dados, índices, LOBs)
- [ ] `EXPLAIN PLAN` executado; estatísticas frescas confirmadas
- [ ] Índices justificados; bitmap só em DW
- [ ] Particionamento definido para tabelas grandes
- [ ] VPD configurado e testado por tenant (se multi-tenant)
- [ ] Unified Auditing configurado
- [ ] Backup strategy definida (RMAN + recovery catalog); Flashback para PITR
- [ ] AWR baseline criado (se licenciado)
- [ ] Licenciamento verificado (partitioning/RAC/Diagnostic Pack)

## Quando Perguntar

Antes de codar: 23ai ou 19c (features divergem)? Multi-tenant (decide VPD)? OLTP ou DW (decide bitmap, materialized views)? Volume esperado (decide partição)? Edição/opções licenciadas (partitioning, RAC, Diagnostic Pack)? ORM/migration tool do projeto?

## Referências (sob demanda — progressive disclosure)

Leia conforme a tarefa (não entram no contexto automaticamente):

- **`reference/core.md`** — Padrões de código: schema design (tipos, constraints, índice funcional/bitmap), PL/SQL packages (procedure/function, `SYS_REFCURSOR`, error handling), query patterns (`FETCH FIRST`, `MERGE`, `CONNECT BY`, JSON), `EXPLAIN PLAN`/`DBMS_XPLAN`, AWR/ASH e `DBMS_STATS`, Spring Data JPA config, catálogo de anti-patterns com solução. **Leia antes de gerar SQL/PL/SQL.**
- **`reference/stack.md`** — Stack canônica completa por linguagem (Java/.NET/Python/Node): drivers (thin mode), ORMs, migrations, e parâmetros essenciais do banco (SGA/PGA, `cursor_sharing`, estatísticas automáticas). **Leia ao configurar projeto novo.**

## Cross-references

- `security-expert` — auth, secrets, TLS, hardening
- `java-expert` / `dotnet-expert` — quando o consumidor é Java (Spring/JPA) ou .NET (EF Core)

## Segurança (Baseline Compartilhado)

Regras universais de segurança (OWASP, secrets, headers, TLS) em `reference/security-baseline.md`. Específico deste domínio:

- **SQL Injection (A03)**: bind variables sempre; `DBMS_SQL`/`EXECUTE IMMEDIATE` com `USING`, nunca concatenar.
- **VPD (A01)**: Virtual Private Database (`DBMS_RLS`) para isolamento multi-tenant no nível do banco; bug em policy bloqueia dados legítimos — testar por tenant.
- **Crypto (A02)**: Transparent Data Encryption (TDE) at-rest; `sqlnet.ora` com protocolo `TCPS` (SSL/TLS) in-transit.
- **Least privilege (A01)**: `CREATE ROLE` + `GRANT` mínimo; Profile com resource/password limits; Data Redaction (`DBMS_REDACT`) para mascaramento em queries.
- **Audit (A09)**: Unified Auditing (`CREATE AUDIT POLICY`) para DDL e acessos sensíveis.
- **Secrets**: credenciais via vault/secret manager + rotação; nunca em código ou migration.
