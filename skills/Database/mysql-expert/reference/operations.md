# MySQL Expert — Operações de Produção

Referência para escala, concorrência, replicação e incidentes. Genérico (não-EVEO-específico), condensado do padrão `mysql-patterns`. Para padrões de código SQL do dia a dia, ver `core.md`.

## Índice

1. [Divergências MySQL ⨯ MariaDB](#1-divergências-mysql--mariadb)
2. [Índices — Sinais no EXPLAIN](#2-índices--sinais-no-explain)
3. [Keyset Pagination (row-value)](#3-keyset-pagination-row-value)
4. [JSON com Coluna Gerada](#4-json-com-coluna-gerada)
5. [Transações, Deadlock e Filas](#5-transações-deadlock-e-filas)
6. [Connection Pools](#6-connection-pools)
7. [Replicação e Read-After-Write](#7-replicação-e-read-after-write)
8. [Diagnóstico](#8-diagnóstico)
9. [Configuração (`my.cnf`)](#9-configuração-mycnf)

---

## 1. Divergências MySQL ⨯ MariaDB

Confirmar engine e versão antes de aplicar feature específica:

```sql
SELECT VERSION();
SHOW VARIABLES LIKE 'version_comment';
```

- **UPSERT**: no MySQL, `VALUES(col)` em `ON DUPLICATE KEY UPDATE` está **deprecado** — usar row-alias (`... AS new ... = new.col`). No MariaDB, `VALUES(col)` é a forma suportada. Para frota mista, use `VALUES(col)`.
- **Replicação**: `SHOW REPLICA STATUS` (terminologia nova) vs `SHOW SLAVE STATUS` (legada, ainda comum). Checar versão antes de padronizar.
- **`SKIP LOCKED`**: adequado apenas para workloads de fila; pula linhas travadas e retorna visão inconsistente — não usar em leitura de contabilidade/integridade.

## 2. Índices — Sinais no EXPLAIN

```sql
EXPLAIN
SELECT id, total FROM orders
WHERE account_id = 123 AND status = 'pending'
ORDER BY created_at DESC LIMIT 50;
```

| Campo | Sinal de risco |
|---|---|
| `type` | `ALL` em tabela grande (full scan) |
| `key` | `NULL` quando há predicado seletivo |
| `rows` | Estimativa muito alta em caminho interativo |
| `Extra` | `Using temporary`, `Using filesort`, `Using where` amplo |

Ordem do índice composto: igualdade primeiro, depois range/sort. Cada índice extra aumenta custo de write, tempo de migration, tamanho de backup e pressão no buffer pool — não indexar às cegas. `EXPLAIN ANALYZE` só quando seguro executar (roda a query, caro em dados de produção).

## 3. Keyset Pagination (row-value)

```sql
SELECT id, name, created_at
FROM products
WHERE (created_at, id) < (?, ?)
ORDER BY created_at DESC, id DESC
LIMIT 50;

CREATE INDEX idx_products_created_id ON products (created_at, id);
```

Nunca `OFFSET` profundo em tabela grande: o servidor varre e descarta linhas antes de retornar a página.

## 4. JSON com Coluna Gerada

JSON para dados de extensão, não para campos com filtro/constraint relacional pesado. Para paths consultados com frequência, expor coluna gerada e indexá-la:

```sql
CREATE TABLE events (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    payload JSON NOT NULL,
    event_type VARCHAR(64)
        GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(payload, '$.type'))) STORED,
    KEY idx_events_type (event_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

Manter FK, ownership, tenancy e lifecycle relacionais.

## 5. Transações, Deadlock e Filas

Transações curtas, travar linhas em ordem determinística:

```sql
START TRANSACTION;
SELECT id, balance FROM accounts WHERE id IN (?, ?) ORDER BY id FOR UPDATE;
UPDATE accounts SET balance = balance - ? WHERE id = ?;
UPDATE accounts SET balance = balance + ? WHERE id = ?;
COMMIT;
```

Checklist deadlock / lock-wait:

- Travar linhas em ordem determinística em todos os caminhos de código.
- Chamadas externas (API) **antes** de abrir a transação, nunca dentro.
- Indexar predicados de `UPDATE`/`DELETE`/leitura com lock.
- Em deadlock: rollback + retry da transação inteira com budget limitado.
- Capturar `SHOW ENGINE INNODB STATUS\G` logo após o deadlock (é sobrescrito por eventos posteriores).

Fila (worker claim) — `SKIP LOCKED` só quando pular linha travada é aceitável:

```sql
START TRANSACTION;
SELECT id FROM jobs WHERE status = 'pending'
ORDER BY created_at LIMIT 1 FOR UPDATE SKIP LOCKED;
UPDATE jobs SET status = 'processing', started_at = CURRENT_TIMESTAMP WHERE id = ?;
COMMIT;
```

## 6. Connection Pools

ProxySQL em produção (pooling + read/write split + query routing). No pool da aplicação, manter recycle abaixo do `wait_timeout` do servidor.

SQLAlchemy:

```python
engine = create_engine(
    "mysql+aiomysql://app:secret@db.internal/app",
    pool_size=10, max_overflow=5, pool_timeout=30,
    pool_recycle=240,           # abaixo do wait_timeout do servidor
    pool_pre_ping=True,         # recupera de failover/queda de rede
    connect_args={"connect_timeout": 5},
)
```

Node.js `mysql2`:

```javascript
const pool = mysql.createPool({
  host: process.env.DB_HOST, user: process.env.DB_USER,
  password: process.env.DB_PASSWORD, database: process.env.DB_NAME,
  waitForConnections: true, connectionLimit: 10, queueLimit: 0,
  enableKeepAlive: true, keepAliveInitialDelay: 30000,
});
const [rows] = await pool.execute(
  'SELECT id, total FROM orders WHERE account_id = ? LIMIT 50', [accountId]);
```

## 7. Replicação e Read-After-Write

Read replicas atrasam. **Não** rotear para replica logo após um write: read-your-own-write, checkout, checagem de permissão, leitura por idempotency-key — fixar no primary.

```sql
SHOW REPLICA STATUS\G;   -- terminologia nova
SHOW SLAVE STATUS\G;     -- legada, ainda comum em frotas existentes
```

Monitorar saúde do SQL thread, do IO thread e o lag — não apenas se a conexão TCP está viva.

## 8. Diagnóstico

```sql
SHOW FULL PROCESSLIST;
SHOW ENGINE INNODB STATUS\G;   -- deadlocks: TRANSACTION WAITING FOR / HOLDS LOCK
SHOW VARIABLES LIKE 'slow_query_log';
SHOW VARIABLES LIKE 'long_query_time';

-- buffer pool hit rate (deve ser > 99%)
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read%';
-- hit = 1 - (Innodb_buffer_pool_reads / Innodb_buffer_pool_read_requests)
```

Habilitar slow log em ambiente controlado:

```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;
SET GLOBAL log_queries_not_using_indexes = 'ON';
```

## 9. Configuração (`my.cnf`)

Ponto de partida para host dedicado — tratar como prompt de revisão, não preset universal. Dimensionar memória, conexões, retenção de log e durabilidade a partir de workload, hardware, política de backup e RPO/RTO.

```ini
[mysqld]
default_storage_engine = InnoDB
innodb_buffer_pool_size = 4G          # 70-80% da RAM em server dedicado
innodb_buffer_pool_instances = 8      # ~1 por GB
innodb_flush_log_at_trx_commit = 1    # durabilidade máxima (2 = mais perf, menos durável)
sync_binlog = 1

max_connections = 300
thread_cache_size = 50

wait_timeout = 300
interactive_timeout = 300
innodb_lock_wait_timeout = 10

slow_query_log = ON
long_query_time = 1
log_queries_not_using_indexes = ON

log_bin = mysql-bin
binlog_format = ROW                    # RBR para consistência
binlog_expire_logs_seconds = 604800

character_set_server = utf8mb4
collation_server = utf8mb4_0900_ai_ci
# Query cache foi removido no 8.0 — não configurar
```
