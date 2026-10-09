# MySQL Expert — Stack Canônica

## MySQL 8.4 LTS / MariaDB 10.11 LTS — Versão Canônica EVEO

| Categoria | Lib/Ferramenta | Versão | Link | Notas |
|-----------|---------------|--------|------|-------|
| **Core** | | | | |
| Banco | MySQL | 8.4 LTS | https://mysql.com | LTS atual. 8.0.x ainda amplamente usado |
| Alternativa | MariaDB | 10.11 LTS | https://mariadb.org | Fork ativo. API-compatível com MySQL 8.0 |
| **ORM / Query Builder** | | | | |
| ORM (Node/TS) | Prisma | 5.x | https://www.prisma.io | `provider = "mysql"` |
| ORM (Node/TS) | Drizzle | 0.30+ | https://orm.drizzle.team | `mysql2` driver |
| ORM (Node/TS) | TypeORM | 0.3.x | https://typeorm.io | `mysql2` driver |
| ORM (Python) | SQLAlchemy | 2.0+ | https://sqlalchemy.org | `aiomysql` para async |
| ORM (Java) | Spring Data JPA | 3.3+ | https://spring.io | Hibernate dialect |
| ORM (PHP) | Eloquent (Laravel) | 11.x | https://laravel.com | `mysql` driver nativo |
| **Driver / Pool** | | | | |
| Driver (Node) | mysql2 | 3.x | https://github.com/sidorares/node-mysql2 | Preparated statements, promise API |
| Driver (Python) | aiomysql | 0.2+ | https://github.com/aio-libs/aiomysql | Async. Junto com SQLAlchemy |
| Driver (Python) | PyMySQL | 1.1+ | https://pymysql.readthedocs.io | Sync |
| Pool | ProxySQL | 2.x | https://proxysql.com | Connection pooling + query routing |
| **Migrations** | | | | |
| Node | Prisma Migrate | built-in | — | |
| Java | Flyway | 10.x | https://flywaydb.org | |
| Python | Alembic | 1.13+ | https://alembic.sqlalchemy.org | |
| Genérico | Liquibase | 4.x | https://liquibase.org | XML/YAML/SQL changesets |
| **Testes** | | | | |
| Containers | testcontainers (mysql) | multi-lang | https://testcontainers.com | `mysql:8.0` image |
| **Backup** | | | | |
| Lógico | mysqldump | built-in | — | `--single-transaction` para InnoDB |
| Físico | Percona XtraBackup | 8.0 | https://percona.com | Hot backup InnoDB. Incremental |
| **Monitoramento** | | | | |
| Performance Schema | performance_schema | built-in | — | Sempre habilitado em 8.0+ |
| Slow query | slow_query_log | config | — | `long_query_time = 1` |
| Dashboard | Percona Monitoring | 2.x | https://percona.com/software/pmm | PMM stack |

## my.cnf — Configuração Essencial de Performance

```ini
[mysqld]
# Mecanismo de armazenamento
default_storage_engine = InnoDB

# InnoDB buffer pool — regra: 70-80% da RAM dedicada ao MySQL
innodb_buffer_pool_size = 1G
innodb_buffer_pool_instances = 8  # 1 por GB de buffer pool

# Redo log — maior = melhor I/O, mais tempo de recovery
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 1  # Durabilidade máxima. 2 = melhor perf, menos durabilidade

# Conexões
max_connections = 200
thread_cache_size = 32

# Query cache foi removido no 8.0 — não configurar

# Slow query log
slow_query_log = ON
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1
log_queries_not_using_indexes = ON

# Charset obrigatório
character_set_server = utf8mb4
collation_server = utf8mb4_0900_ai_ci
```
