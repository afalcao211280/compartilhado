---
name: sqlserver-expert
description: >
  Especialista em SQL Server seguindo padrões de produção. Use SEMPRE que
  houver menção a SQL Server, MSSQL, T-SQL, Azure SQL, ou quando o contexto
  for um banco SQL Server. Stack: SQL Server 2022+, Azure SQL, T-SQL, SSMS.
  Complementar às skills de backend.
version: "2.1.2"
category: Database
keywords:
  - sqlserver
  - mssql
  - t-sql
  - azure-sql
  - database
  - ssms
requires: ['security-expert']
---

# SQL Server Expert

## Princípio Central

SQL Server/Azure SQL — enterprise-ready, integrado ao ecossistema Microsoft. T-SQL é poderoso; use com intenção.

## Versão

- SQL Server 2022+ (SQL Server 2025 quando GA — vector/DiskANN, Optimized Locking, OPPO, JSON nativo; ver `reference/best-practices.md` §11)
- Azure SQL Database / Managed Instance (padrão EVEO Azure; MI preferido sobre VM para cloud-native)

## Padrões Obrigatórios

- Schema separation: `dbo` para objetos comuns, schemas específicos por domínio (`app.`, `audit.`, `config.`)
- Stored procedures para lógica de banco (quando necessário — não como padrão, prefira application logic)
- Parameterized queries sempre: sp_executesql com parâmetros, nunca concatenação
- Índices clusterizados por padrão: toda tabela tem um clustered index
- IDENTITY ou SEQUENCE para PKs
- Temporal tables para audit automático
- Connection pooling: ADO.NET/ODBC connection pooling habilitado
- Explicit transactions: `BEGIN TRAN`/`COMMIT` — nunca implícito para multi-operações

## Performance

- Execution plans: `SET STATISTICS IO ON`, `SET STATISTICS TIME ON`, `SET STATISTICS PROFILE ON`
- Índices com `INCLUDE` columns: covering indexes para evitar key lookups
- Columnstore indexes para workloads analytics
- Partitioning para tabelas grandes: range partitioning por data
- Query Store habilitado: `ALTER DATABASE ... SET QUERY_STORE = ON`
- Statistics update automático: `AUTO_UPDATE_STATISTICS_ASYNC = ON`
- `NOLOCK` apenas quando leitura suja é aceitável — documente a decisão
- Batch operations: `BULK INSERT`, Table-Valued Parameters, nunca 1-by-1

## Security

- Role-based access: database roles com privilégios mínimos
- Row-Level Security (RLS): `CREATE SECURITY POLICY` para multi-tenant
- Always Encrypted para dados sensíveis (SSN, CPF, cartão): client-side encryption
- Encryption at rest: TDE (Transparent Data Encryption)
- SSL/TLS para connections: `Encrypt=yes` em connection string
- SQL Server Audit: server-level e database-level audit specs
- Dynamic Data Masking (DDM): mascaramento sem alterar dados
- `sp_executesql` com parâmetros: **nunca concatenar SQL**

## Patterns

- **BIGINT IDENTITY** para PKs: simples, eficiente, sequencial
- **Temporal tables**: `SYSTEM_VERSIONING = ON` para audit automático
- **Computed columns**: `AS ... PERSISTED` para colunas derivadas indexáveis
- **Filtered indexes**: `WHERE` clause no índice para subsets
- **Optimistic concurrency**: coluna `rowversion` — `WHERE rowversion = :expected`
- **Cross-database queries**: linked servers com cuidado — prefira APIs entre serviços

## Anti-padrões

- **No** `SELECT *` — sempre especifique colunas
- **No** cursors quando set-based funciona: `WHILE` loops e cursors são code smell
- **No** `NOLOCK` sem entender implications: dirty reads, missing/duplicate rows
- **No** `sp_` prefix: reservado para system stored procedures — usar outro prefixo
- **No** `NVARCHAR` quando `VARCHAR` basta: nvarchar é 2x o tamanho
- **No** ad-hoc distributed queries: prefira ETL ou APIs

## Checklist

Para cada feature/migration, verifique:

- [ ] Migrations criadas e testadas (up/down)
- [ ] Índices com INCLUDE columns quando apropriado
- [ ] Query Store habilitado e baseline criado
- [ ] RLS configurado se multi-tenant
- [ ] Backup strategy definida (full + diff + log backups)
- [ ] SQL Server Audit configurado
- [ ] Statistics update automático confirmado

## Boas Práticas (referência)

- `reference/core.md` — padrões de código T-SQL (schema, índices, query patterns, procs, EF Core, DMVs, anti-patterns).
- `reference/best-practices.md` — operações de produção: índices/execution plans, SARGability, isolamento/RCSI, deadlocks/retry, particionamento (sliding window), Query Store/plan forcing, backup/PITR, Always On, tempdb/tuning, wait stats e novidades SQL Server 2025. Leia ao tunar, operar ou revisar performance.
- `reference/stack.md` — versões canônicas, drivers, ORMs, migrations, HA/monitoramento.

## Seguranca (Baseline Compartilhado)
- `reference/security-baseline.md` — Regras universais de seguranca (OWASP, secrets, headers, TLS)

