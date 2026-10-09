# MySQL Expert — Padrões de Código

## 1. Schema Design — Convenções MySQL 8.0

```sql
-- Sempre utf8mb4 + utf8mb4_0900_ai_ci
-- UUID como CHAR(36) ou BINARY(16) (mais eficiente)
-- AUTO_INCREMENT para chaves internas; UUID para chaves expostas

CREATE TABLE users (
    id          CHAR(36) PRIMARY KEY DEFAULT (UUID()),  -- MySQL 8.0+
    email       VARCHAR(255) NOT NULL,
    name        VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role        ENUM('admin', 'editor', 'viewer') NOT NULL DEFAULT 'viewer',
    active      TINYINT(1) NOT NULL DEFAULT 1,
    created_at  DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at  DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                  ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT users_email_unique UNIQUE (email),
    INDEX idx_users_active_created (active, created_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Tabela de relacionamento
CREATE TABLE user_roles (
    user_id CHAR(36) NOT NULL,
    role_id INT UNSIGNED NOT NULL,
    assigned_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id)
        REFERENCES roles (id) ON DELETE RESTRICT
) ENGINE=InnoDB;
```

---

## 2. Índices — Estratégia MySQL

```sql
-- Índice cobridor (covering index) — evita volta à tabela
-- Para query: SELECT name, email FROM users WHERE active=1 ORDER BY created_at DESC
CREATE INDEX idx_users_cover ON users (active, created_at DESC, name, email);

-- EXPLAIN para verificar uso de índice
EXPLAIN FORMAT=JSON
SELECT name, email FROM users
WHERE active = 1
ORDER BY created_at DESC
LIMIT 20;

-- Índice FULLTEXT para busca textual
ALTER TABLE products ADD FULLTEXT INDEX idx_products_search (name, description);

-- Busca FULLTEXT
SELECT *, MATCH(name, description) AGAINST ('laptop wireless' IN BOOLEAN MODE) AS score
FROM products
WHERE MATCH(name, description) AGAINST ('laptop wireless' IN BOOLEAN MODE)
ORDER BY score DESC
LIMIT 10;

-- Ver índices de uma tabela
SHOW INDEX FROM users;

-- Forçar uso de índice específico (diagnóstico, não produção)
SELECT * FROM users USE INDEX (idx_users_active_created)
WHERE active = 1 LIMIT 10;
```

---

## 3. Query Patterns

```sql
-- Paginação com cursor (evitar OFFSET em tabelas grandes)
SELECT id, name, email, created_at
FROM users
WHERE active = 1
  AND (created_at < ? OR (created_at = ? AND id < ?))
ORDER BY created_at DESC, id DESC
LIMIT 20;

-- INSERT ... ON DUPLICATE KEY UPDATE (UPSERT)
INSERT INTO user_settings (user_id, `key`, value)
VALUES (?, ?, ?)
ON DUPLICATE KEY UPDATE
    value = VALUES(value),
    updated_at = CURRENT_TIMESTAMP(6);

-- Bulk insert eficiente
INSERT INTO events (id, type, payload, created_at)
VALUES
    (UUID(), 'click', '{"page": "/home"}', NOW()),
    (UUID(), 'view', '{"page": "/products"}', NOW()),
    (UUID(), 'click', '{"page": "/cart"}', NOW());

-- JSON column queries (MySQL 8.0+)
SELECT id, payload->>'$.user_id' AS user_id,
       JSON_EXTRACT(payload, '$.amount') AS amount
FROM transactions
WHERE JSON_EXTRACT(payload, '$.status') = 'completed'
  AND created_at >= NOW() - INTERVAL 7 DAY;
```

---

## 4. Transações

```sql
-- Transação explícita com savepoint
START TRANSACTION;

INSERT INTO orders (id, user_id, total) VALUES (UUID(), ?, ?);
SAVEPOINT after_order;

INSERT INTO order_items (order_id, product_id, quantity, price)
VALUES (LAST_INSERT_ID(), ?, ?, ?);

-- Se falhar, rollback para savepoint
-- ROLLBACK TO SAVEPOINT after_order;

COMMIT;

-- Nível de isolamento
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- REPEATABLE READ: padrão MySQL, seguro para maioria dos casos
-- READ COMMITTED: evita phantom reads do Hibernate/JPA com FlushMode=AUTO
```

---

## 5. Prisma Schema (MySQL)

```prisma
// prisma/schema.prisma
datasource db {
  provider = "mysql"
  url      = env("DATABASE_URL")
}

model User {
  id           String    @id @default(uuid()) @db.Char(36)
  email        String    @unique @db.VarChar(255)
  name         String    @db.VarChar(100)
  passwordHash String    @map("password_hash") @db.VarChar(255)
  role         UserRole  @default(VIEWER)
  active       Boolean   @default(true)
  createdAt    DateTime  @default(now()) @map("created_at") @db.DateTime(6)
  updatedAt    DateTime  @updatedAt @map("updated_at") @db.DateTime(6)

  @@index([active, createdAt(sort: Desc)])
  @@map("users")
}

enum UserRole {
  ADMIN
  EDITOR
  VIEWER
}
```

---

## 6. Queries de Monitoramento

```sql
-- Queries lentas recentes
SELECT * FROM mysql.slow_log
ORDER BY start_time DESC
LIMIT 20;

-- Processos ativos
SHOW FULL PROCESSLIST;

-- Status InnoDB
SHOW ENGINE INNODB STATUS;

-- Verificar deadlocks no INNODB STATUS:
-- TRANSACTION X WAITING FOR LOCK, TRANSACTION Y HOLDS LOCK

-- Variáveis de performance
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_%';
SHOW GLOBAL STATUS LIKE 'Threads_%';
SHOW GLOBAL STATUS LIKE 'Questions';

-- Tabelas sem índices usados (performance_schema)
SELECT object_schema, object_name, index_name,
       count_read, count_write
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE index_name IS NOT NULL
  AND count_read = 0
  AND count_write = 0
  AND object_schema NOT IN ('mysql', 'performance_schema', 'information_schema')
ORDER BY object_schema, object_name;
```

---

## Anti-patterns

### ❌ Usar charset utf8 em vez de utf8mb4
**Problema:** O desenvolvedor cria tabelas ou banco com `CHARSET=utf8` sem perceber que o `utf8` do MySQL é limitado a 3 bytes.
**Por quê evitar:** O charset `utf8` do MySQL não implementa UTF-8 completo — emojis e muitos caracteres CJK requerem 4 bytes e causam erros de inserção ou truncamento silencioso. O padrão correto é `utf8mb4`.
**Solução:**
```sql
-- Errado
CREATE TABLE messages (
    content TEXT
) CHARSET=utf8;

-- Correto
CREATE TABLE messages (
    content TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Converter tabela existente
ALTER TABLE messages
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- Definir padrão no servidor (my.cnf)
-- [mysqld]
-- character-set-server = utf8mb4
-- collation-server = utf8mb4_0900_ai_ci
```

---

### ❌ Usar MyISAM em vez de InnoDB
**Problema:** O desenvolvedor cria tabelas sem especificar engine ou usa `ENGINE=MyISAM` explicitamente.
**Por quê evitar:** MyISAM não suporta transações, usa lock a nível de tabela (em vez de row-level locking do InnoDB), não tem suporte a foreign keys e não é crash-safe — dados podem ser corrompidos em caso de falha de energia.
**Solução:**
```sql
-- Errado
CREATE TABLE logs (id INT, message TEXT) ENGINE=MyISAM;

-- Correto: InnoDB sempre
CREATE TABLE logs (
    id      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    message TEXT NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Verificar e converter tabelas MyISAM existentes
SELECT table_name, engine
FROM information_schema.tables
WHERE table_schema = DATABASE() AND engine = 'MyISAM';

ALTER TABLE logs ENGINE=InnoDB;
```

---

### ❌ DATETIME sem precisão fracionária para microsserviços
**Problema:** O desenvolvedor usa `DATETIME` ou `TIMESTAMP` sem especificar precisão de sub-segundos.
**Por quê evitar:** `DATETIME` sem precisão armazena apenas até segundos inteiros, perdendo informação de milissegundos/microssegundos necessária para ordenação correta de eventos em sistemas distribuídos e para correlação com logs de aplicação.
**Solução:**
```sql
-- Errado
CREATE TABLE events (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Correto: DATETIME(6) para precisão de microssegundos
CREATE TABLE events (
    id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                 ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;
```

---

### ❌ JOIN sem índice na coluna de junção
**Problema:** O desenvolvedor cria foreign keys ou faz JOINs sem criar índice na coluna da tabela filha.
**Por quê evitar:** MySQL precisa fazer full table scan na tabela filha para cada linha da tabela pai no JOIN; em tabelas grandes isso multiplica o custo e pode levar a queries de segundos ou minutos.
**Solução:**
```sql
-- Errado: FK sem índice correspondente
ALTER TABLE orders ADD CONSTRAINT fk_orders_user
    FOREIGN KEY (user_id) REFERENCES users (id);
-- user_id não tem índice → full scan em orders para cada user

-- Correto: índice explícito na coluna de FK
CREATE INDEX idx_orders_user_id ON orders (user_id);

-- Verificar FKs sem índice
SELECT kcu.table_name, kcu.column_name
FROM information_schema.key_column_usage kcu
LEFT JOIN information_schema.statistics s
    ON s.table_schema = kcu.table_schema
    AND s.table_name = kcu.table_name
    AND s.column_name = kcu.column_name
WHERE kcu.referenced_table_name IS NOT NULL
  AND s.index_name IS NULL
  AND kcu.table_schema = DATABASE();
```

---

### ❌ Conversão implícita de tipos em WHERE
**Problema:** O desenvolvedor compara uma coluna com um literal de tipo diferente (ex: coluna INT comparada com string `'123'`).
**Por quê evitar:** MySQL converte implicitamente os valores para compatibilidade, mas essa conversão impede o uso do índice na coluna, transformando Index Scan em Full Table Scan.
**Solução:**
```sql
-- Errado: coluna id é INT, comparado com string
SELECT * FROM users WHERE id = '42';

-- Errado: coluna created_at é DATETIME, mas comparado com string sem cast
SELECT * FROM orders WHERE created_at = '2024-01-15';

-- Correto: tipos compatíveis
SELECT * FROM users WHERE id = 42;
SELECT * FROM orders WHERE created_at >= '2024-01-15 00:00:00'
                       AND created_at <  '2024-01-16 00:00:00';
```

---

### ❌ SELECT * em queries ORM
**Problema:** O desenvolvedor deixa o ORM (Sequelize, TypeORM, Prisma) gerar `SELECT *` sem configurar seleção explícita de colunas.
**Por quê evitar:** Trafega colunas desnecessárias (incluindo blobs, textos longos), impede covering indexes, aumenta uso de memória e latência, e quebra quando colunas são adicionadas ou removidas.
**Solução:**
```typescript
// Errado (TypeORM)
const users = await userRepository.find({ where: { active: true } });

// Correto: selecionar apenas colunas necessárias
const users = await userRepository.find({
    select: ['id', 'email', 'name', 'role'],
    where: { active: true },
});

// Correto (Prisma)
const users = await prisma.user.findMany({
    where: { active: true },
    select: { id: true, email: true, name: true, role: true },
});
```

---

### ❌ Usar MySQL Full-Text Search em escala
**Problema:** O desenvolvedor usa `FULLTEXT` index do MySQL para search em produção com alta carga ou datasets grandes.
**Por quê evitar:** O Full-Text Search do MySQL/InnoDB é limitado em recursos (sem fuzzy, sem stemming avançado, sem relevance tuning), não escala horizontalmente e degrada performance do banco principal ao misturar carga de search com carga OLTP.
**Solução:**
```
Para busca textual em produção com escala:
- Elasticsearch ou OpenSearch: relevance scoring, facets, autocomplete, fuzzy
- Typesense: alternativa mais simples, self-hosted, excelente para autocomplete
- Meilisearch: fácil de operar, boa para datasets até ~10M documentos

Manter MySQL para dados transacionais; sincronizar para search engine
via CDC (Change Data Capture) ou event queue.
```

---

### ❌ Transações longas sem boundary explícito de COMMIT
**Problema:** O desenvolvedor executa múltiplos DML statements sem definir explicitamente os limites da transação quando `autocommit=0`.
**Por quê evitar:** Transações abertas retêm locks de linha, impedem purge do undo log (aumentando tamanho do tablespace), e podem causar deadlocks ou timeouts para outras sessions concorrentes.
**Solução:**
```sql
-- Errado: sem boundary explícito, tudo numa transação implícita gigante
SET autocommit = 0;
UPDATE orders SET status = 'processing' WHERE status = 'pending';
-- ... 5 minutos de processamento ...
UPDATE inventory SET qty = qty - 1 WHERE product_id = ?;

-- Correto: transações curtas e explícitas
START TRANSACTION;
UPDATE orders SET status = 'processing' WHERE id = ? AND status = 'pending';
COMMIT;

START TRANSACTION;
UPDATE inventory SET qty = qty - 1 WHERE product_id = ? AND qty > 0;
COMMIT;
```

---

### ❌ innodb_buffer_pool_size no valor padrão
**Problema:** O desenvolvedor sobe MySQL em produção sem ajustar `innodb_buffer_pool_size`, que tem default de 128MB.
**Por quê evitar:** O buffer pool é o cache principal do InnoDB para dados e índices; com 128MB em um servidor com 16GB+ de RAM, praticamente toda query vira I/O de disco, tornando o banco ordens de magnitude mais lento que o necessário.
**Solução:**
```ini
# my.cnf — ajustar para 70-80% da RAM disponível (exceto se compartilhar servidor)
# Servidor com 16GB RAM: usar ~12GB
[mysqld]
innodb_buffer_pool_size = 12G
innodb_buffer_pool_instances = 8   # 1 instância por GB, máximo 64

# Verificar hit rate atual (deve ser > 99%)
# SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read%';
# hit_rate = 1 - (Innodb_buffer_pool_reads / Innodb_buffer_pool_read_requests)
```

---

### ❌ Lógica de negócio em stored procedures
**Problema:** O desenvolvedor implementa regras de negócio complexas dentro de stored procedures no banco de dados.
**Por quê evitar:** Stored procedures são difíceis de versionar, testar unitariamente, depurar e fazer deploy de forma independente; acoplam lógica ao banco, dificultam migrations e tornam o sistema mais difícil de escalar horizontalmente (não se pode escalar a lógica sem escalar o banco).
**Solução:**
```
Regra geral: banco de dados executa queries, aplicação executa lógica.

Usar stored procedures apenas para:
- Operações atômicas que precisam minimizar round-trips (ex: bulk operations)
- Casos onde a latência de rede entre app e DB é o gargalo real

Alternativas para lógica de negócio:
- Service layer na aplicação (Go, Node.js, Java)
- Transações explícitas na aplicação com múltiplos statements
- Event-driven com queues para operações assíncronas (RabbitMQ, Kafka)
```
