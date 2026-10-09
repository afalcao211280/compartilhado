# ADR-011: SQL Server + Oracle — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Projetos enterprise na EVEO podem exigir SQL Server (ecossistema Microsoft/Azure) ou Oracle (legacy enterprise). A ausência de padronização resulta em T-SQL vs PL/SQL mistos, features não aproveitadas, e configurações subótimas. Este ADR unifica as decisões para ambos os bancos, destacando diferenças e trade-offs.

## Decisão

**SQL Server 2022+ / Azure SQL**: banco relacional para ecossistema Microsoft. T-SQL como linguagem canônica. Azure SQL Managed Instance para cloud-native. Always Encrypted para dados sensíveis.

**Oracle 19c+ / 23ai**: banco relacional para workloads enterprise legados. PL/SQL quando necessário. Partitioning para tabelas grandes. Oracle 23ai para JSON e AI vector search quando disponível.

## Stack Canônica

| Categoria | Escolha (SQL Server) | Versão | Escolha (Oracle) | Versão |
|---|---|---|---|---|
| Banco | SQL Server | 2022+ | Oracle Database | 19c+ (23ai preferido) |
| Cloud | Azure SQL Managed Instance | — | Oracle Cloud Infrastructure (OCI) | — |
| Migrations | Flyway / DbUp | — | Flyway / Liquibase | — |
| Connection Pool | ADO.NET pooling / JDBC pool | — | UCP (Universal Connection Pool) | — |
| Monitoramento | Query Store + DMVs + Prometheus | — | AWR + Enterprise Manager | — |
| Backup | Azure SQL auto-backup / native backup | — | RMAN | — |
| HA | Always On Availability Groups | — | Data Guard / RAC | — |
| Charset | UTF-8 (SQL Server 2019+) | — | AL32UTF8 | — |

## Padrões Obrigatórios — SQL Server

- **T-SQL** como linguagem canônica. Procedimentos armazenados para lógica complexa — nunca business logic solta na app se o banco for o boundary.
- **Azure SQL Managed Instance** preferido sobre SQL Server VM para cloud-native.
- **Always Encrypted** para dados sensíveis (PII, financeiro). Client-side encryption — nunca armazenar chaves no banco.
- **Query Store** habilitado em toda database de produção. `ALTER DATABASE ... SET QUERY_STORE = ON`.
- **DMVs** (`sys.dm_exec_query_stats`, `sys.dm_exec_sessions`) para monitoramento de queries e connections.
- **Migrations versionadas** obrigatórias. Nunca DDL manual em produção.
- **Índices**: `INCLUDE` columns para covering indexes. `WHERE` clause para filtered indexes.
- **Partitioning** para tabelas grandes: partition by date range para dados temporais.
- **JSON support** (SQL Server 2019+): `JSON_VALUE()`, `JSON_QUERY()`, `OPENJSON()`.
- **Temporal tables** (`SYSTEM_VERSIONING`) para auditoria automática de alterações.
- **Soft delete** com `DeletedAt DATETIME2` — nunca DELETE físico em dados de negócio.
- **Schemas** para organização: `dbo`, `app`, `audit`, `staging`.

## Padrões Obrigatórios — Oracle

- **PL/SQL** apenas quando a complexidade justifica (bulk processing, cursor logic). Preferir SQL puro sempre possível.
- **Oracle 23ai preferido** para novos projetos. 19c para legados.
- **AL32UTF8** como charset obrigatório. Never WE8ISO8859P1.
- **Partitioning** para tabelas > 10M rows: range por data, list por categoria.
- **RMAN** para backup. Flashback para recovery point-in-time.
- **AWR** (Automatic Workload Repository) para performance analysis.
- **Migrations versionadas** obrigatórias. Liquibase ou Flyway.
- **Soft delete** com `DELETED_AT TIMESTAMP` — nunca DELETE físico.
- **Sequences** para IDs. Never trigger-based auto-increment.
- **Materialized views** para agregações pesadas com refresh agendado.
- **Edition-based redefinition** (EBR) para deploy zero-downtime de PL/SQL.
- **Profile** para resource limits por usuário/app.

## Anti-padrões

| Proibido | Alternativa |
|---|---|
| MyISAM (SQL Server não tem, mas equivalente: heap tables sem cluster) | Clustered indexes em toda tabela |
| DDL manual em produção | Migrations versionadas |
| `SELECT *` | Colunas explícitas |
| N+1 queries sem análise | Execution plan analysis |
| DELETE físico em dados de negócio | Soft delete |
| 1 connection per request | Connection pooling (ADO.NET / UCP) |
| Business logic no banco sem justificativa | ORM/app layer, stored procedures apenas quando necessário |
| String concatenation para queries | Parameterized queries sempre |
| `NOLOCK` hint (SQL Server) | Read committed snapshot isolation |
| `SELECT * FROM v$version` em loops (Oracle) | Caching de metadata |
| Oracle `VARCHAR2` sem BYTE/CHAR semântico | `VARCHAR2(255 CHAR)` explícito |

## Consequências

**Positivas**:
- SQL Server: integração nativa com Azure, Always Encrypted, Query Store
- Oracle: partitioning maduro, RAC para HA, PL/SQL para processamento pesado
- Temporal tables (SQL Server) e Flashback (Oracle) para auditoria automática
- JSON support em ambos permite dados semi-estruturados sem tabela separada

**Negativas**:
- SQL Server: licensing caro, lock-in Microsoft
- Oracle: licensing complexo, curva de aprendizado PL/SQL
- Diferenças significativas em SQL dialect exigem especialistas por banco

**Riscos**:
- SQL Server Always Encrypted requer planning de key management
- Oracle partitioning requer licensing Enterprise — verificar antes de usar
- Migration entre bancos (SQL Server ↔ Oracle) é complexa — evitar se possível

## Referências

- `skills/Database-Relacional/sqlserver-expert/SKILL.md`
- `skills/Database-Relacional/oracle-expert/SKILL.md`
- Documentação SQL Server 2022: https://learn.microsoft.com/sql/sql-server/
- Documentação Oracle 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/
- Documentação Oracle 23ai: https://docs.oracle.com/en/database/oracle/oracle-database/23/