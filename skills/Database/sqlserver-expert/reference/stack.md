# SQL Server Expert — Stack Canônica

## SQL Server 2019+ / Azure SQL — Versão Canônica EVEO

| Categoria | Lib/Ferramenta | Versão | Link | Notas |
|-----------|---------------|--------|------|-------|
| **Core** | | | | |
| Banco | SQL Server | 2019 / 2022 | https://microsoft.com/sql-server | 2022 em produção nova |
| Cloud | Azure SQL Database | — | https://azure.microsoft.com/sql-database | Managed PaaS. Padrão EVEO Azure |
| Cloud Serverless | Azure SQL Serverless | — | — | Para workloads intermitentes |
| **ORM / Query Builder** | | | | |
| ORM (Node/TS) | Prisma | 5.x | https://www.prisma.io | `provider = "sqlserver"` |
| ORM (Node/TS) | TypeORM | 0.3.x | https://typeorm.io | `mssql` driver |
| ORM (.NET) | Entity Framework Core | 8.x | https://learn.microsoft.com/ef | `Microsoft.EntityFrameworkCore.SqlServer` |
| Query Builder (.NET) | Dapper | 2.x | https://github.com/DapperLib/Dapper | Micro-ORM para queries complexas |
| ORM (Java) | Spring Data JPA | 3.3+ | https://spring.io | MSSQL Hibernate dialect |
| ORM (Python) | SQLAlchemy | 2.0+ | https://sqlalchemy.org | `pyodbc` / `aioodbc` |
| **Driver** | | | | |
| Driver (Node) | mssql / tedious | 10.x / 18.x | https://github.com/brianc/node-mssql | mssql usa tedious internamente |
| Driver (.NET) | Microsoft.Data.SqlClient | 5.x | https://learn.microsoft.com | |
| Driver (Python) | pyodbc + ODBC Driver 18 | — | https://learn.microsoft.com/sql/connect/odbc | |
| Driver (Java) | mssql-jdbc | 12.x | https://github.com/microsoft/mssql-jdbc | |
| **Migrations** | | | | |
| .NET | EF Core Migrations | built-in | — | `dotnet ef migrations add` |
| .NET | DbUp | 4.x | https://dbup.readthedocs.io | SQL scripts versionados |
| Multi-lang | Flyway | 10.x | https://flywaydb.org | SQL Server suportado |
| Node | Prisma Migrate | built-in | — | |
| **Testes** | | | | |
| Containers | testcontainers (mssql) | multi-lang | https://testcontainers.com | `mcr.microsoft.com/mssql/server:2022-latest` |
| **Backup / HA** | | | | |
| Backup | SQL Server Backup | built-in | — | Full + Differential + Log |
| HA | Always On AG | built-in (Enterprise) | — | Replicação síncrona |
| Azure HA | Azure SQL geo-replication | built-in | — | Active Geo-Replication |
| **Monitoramento** | | | | |
| DMVs | Dynamic Management Views | built-in | — | `sys.dm_exec_*`, `sys.dm_os_*` |
| Slow queries | Query Store | built-in (2016+) | — | Sempre habilitar em produção |
| Azure | Azure SQL Insights | — | Azure Monitor | |

## Configurações Essenciais

```sql
-- Habilitar Query Store (SQL Server 2016+)
ALTER DATABASE [MeuBanco]
SET QUERY_STORE = ON (
    OPERATION_MODE = READ_WRITE,
    QUERY_CAPTURE_MODE = AUTO,
    MAX_STORAGE_SIZE_MB = 1024,
    INTERVAL_LENGTH_MINUTES = 60
);

-- Compatibilidade level — usar o mais recente compatível com a versão
ALTER DATABASE [MeuBanco] SET COMPATIBILITY_LEVEL = 150; -- 2019

-- Enable Read Committed Snapshot Isolation (RCSI) — evita locks em reads
ALTER DATABASE [MeuBanco] SET READ_COMMITTED_SNAPSHOT ON;
-- Nota: requer que não haja conexões abertas. Fazer em janela de manutenção.
```
