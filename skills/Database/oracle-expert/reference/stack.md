# Oracle Expert — Stack Canônica

## Oracle Database 19c / 21c / 23ai — Versão Canônica EVEO

| Categoria | Lib/Ferramenta | Versão | Link | Notas |
|-----------|---------------|--------|------|-------|
| **Core** | | | | |
| Banco | Oracle Database | 19c (LTS) / 23ai | https://oracle.com/database | 19c: LTS até 2027. 23ai: Free Edition disponível |
| Cloud | Oracle Autonomous DB | — | https://oracle.com/autonomous-database | Serverless ou dedicado |
| **ORM / Query Builder** | | | | |
| ORM (Java) | Spring Data JPA | 3.3+ | https://spring.io | Hibernate Oracle dialect |
| ORM (.NET) | EF Core + Oracle Provider | 8.x | https://oracle.com/dotnet | `Oracle.EntityFrameworkCore` |
| ORM (Python) | SQLAlchemy | 2.0+ | https://sqlalchemy.org | `cx_Oracle` / `python-oracledb` |
| ORM (Node/TS) | TypeORM | 0.3.x | https://typeorm.io | `oracledb` driver |
| **Driver** | | | | |
| Driver (Java) | ojdbc11 (thin) | 23.x | https://oracle.com/jdbc | JDBC Thin — sem Oracle Client necessário |
| Driver (Python) | python-oracledb | 2.x | https://oracle.github.io/python-oracledb | Substitui cx_Oracle. Thin mode: sem Client |
| Driver (Node) | node-oracledb | 6.x | https://oracle.github.io/node-oracledb | Thin mode: sem Oracle Client |
| Driver (.NET) | Oracle.ManagedDataAccess.Core | 23.x | https://nuget.org | Managed driver, sem Oracle Client |
| **Migrations** | | | | |
| Java | Flyway | 10.x | https://flywaydb.org | Suporte Oracle na versão Teams/Enterprise |
| Java | Liquibase | 4.x | https://liquibase.org | Suporte Oracle na versão Open Source |
| DBA | Liquibase Pro | 4.x | — | Para Oracle especificamente em ambientes enterprise |
| **Testes** | | | | |
| Containers | testcontainers (oracle) | multi-lang | https://testcontainers.com | `gvenzl/oracle-xe:21-slim` |
| Oracle Free | Oracle Free 23ai | — | https://oracle.com/database/free | Para dev/test local |
| **Backup / HA** | | | | |
| Backup | RMAN | built-in | — | Recovery Manager. Incremental + archivelog |
| HA | Oracle Data Guard | built-in (EE) | — | Physical/Logical Standby |
| Cloud HA | Autonomous DB | built-in | — | 99.995% SLA. Auto-backup |
| **Monitoramento** | | | | |
| AWR | Automatic Workload Repository | built-in (EE) | — | Relatórios de performance por período |
| ASH | Active Session History | built-in (EE) | — | Wait events, SQL sampling |
| Cloud | Oracle Cloud Monitoring | — | — | Para Autonomous DB |

## Parâmetros e Configurações Essenciais

```sql
-- Ver parâmetros atuais
SELECT name, value, description
FROM v$parameter
WHERE name IN (
    'memory_target', 'sga_target', 'pga_aggregate_target',
    'db_cache_size', 'open_cursors', 'cursor_sharing',
    'optimizer_mode', 'parallel_max_servers'
)
ORDER BY name;

-- Ajustar PGA para workloads analíticos (DBA)
ALTER SYSTEM SET pga_aggregate_target = 1G SCOPE=BOTH;

-- Cursor sharing — cuidado: FORCE pode ocultar queries lentas
-- Padrão EXACT é o correto para apps com bind variables
ALTER SYSTEM SET cursor_sharing = EXACT SCOPE=BOTH;

-- Estatísticas automáticas — verificar se job está ativo
SELECT client_name, status FROM dba_autotask_client
WHERE client_name LIKE '%stats%';
```
