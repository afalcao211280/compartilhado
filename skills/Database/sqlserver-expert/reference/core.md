# SQL Server Expert — Padrões de Código

## 1. Schema Design — Convenções T-SQL

```sql
-- Usar schemas para organizar objetos (não apenas dbo)
CREATE SCHEMA app;
CREATE SCHEMA audit;
GO

-- Tabela com boas práticas
CREATE TABLE app.Users (
    Id          UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(), -- Ordenável (melhor que NEWID())
    Email       NVARCHAR(255)    NOT NULL,
    Name        NVARCHAR(100)    NOT NULL,
    PasswordHash NVARCHAR(255)   NOT NULL,
    Role        NVARCHAR(20)     NOT NULL DEFAULT 'viewer'
                  CONSTRAINT CK_Users_Role CHECK (Role IN ('admin', 'editor', 'viewer')),
    Active      BIT              NOT NULL DEFAULT 1,
    CreatedAt   DATETIMEOFFSET(7) NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    UpdatedAt   DATETIMEOFFSET(7) NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_Users PRIMARY KEY (Id),
    CONSTRAINT UQ_Users_Email UNIQUE (Email)
);
GO

-- Índice filtrado (equivalente ao partial index do PostgreSQL)
CREATE INDEX IX_Users_Active_CreatedAt
ON app.Users (CreatedAt DESC)
INCLUDE (Email, Name)
WHERE Active = 1;
GO

-- Trigger para UpdatedAt
CREATE TRIGGER app.tr_Users_UpdatedAt
ON app.Users AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE app.Users
    SET UpdatedAt = SYSDATETIMEOFFSET()
    FROM app.Users u
    INNER JOIN inserted i ON u.Id = i.Id;
END;
GO
```

---

## 2. Índices — Estratégia SQL Server

```sql
-- Índice cobridor com INCLUDE
-- Para: SELECT Name, Email FROM Users WHERE Active=1 ORDER BY CreatedAt DESC
CREATE INDEX IX_Users_Cover
ON app.Users (Active, CreatedAt DESC)
INCLUDE (Name, Email);

-- Columnstore Index para queries analíticas (data warehouse)
CREATE CLUSTERED COLUMNSTORE INDEX CCI_Sales
ON dbo.SalesFacts;

-- Índice de texto completo
CREATE FULLTEXT CATALOG ft_catalog AS DEFAULT;
CREATE FULLTEXT INDEX ON dbo.Products (Name LANGUAGE 1046, Description LANGUAGE 1046)
    KEY INDEX PK_Products ON ft_catalog;

-- Verificar fragmentação
SELECT i.name, s.avg_fragmentation_in_percent, s.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') s
JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
WHERE s.avg_fragmentation_in_percent > 10
ORDER BY s.avg_fragmentation_in_percent DESC;

-- Reconstruir índices fragmentados
-- < 30% fragmentação → REORGANIZE (online, sem lock)
-- > 30% fragmentação → REBUILD (offline por padrão)
ALTER INDEX IX_Users_Cover ON app.Users REORGANIZE;
ALTER INDEX IX_Users_Cover ON app.Users REBUILD WITH (ONLINE = ON); -- Enterprise/Azure SQL
```

---

## 3. Query Patterns T-SQL

```sql
-- Paginação com OFFSET/FETCH (SQL Server 2012+)
SELECT Id, Name, Email, CreatedAt
FROM app.Users
WHERE Active = 1
ORDER BY CreatedAt DESC, Id DESC
OFFSET 0 ROWS FETCH NEXT 20 ROWS ONLY;

-- CTE + ROW_NUMBER para paginação legada compatível
WITH PagedUsers AS (
    SELECT Id, Name, Email, CreatedAt,
           ROW_NUMBER() OVER (ORDER BY CreatedAt DESC) AS RowNum
    FROM app.Users
    WHERE Active = 1
)
SELECT * FROM PagedUsers WHERE RowNum BETWEEN 1 AND 20;

-- MERGE (UPSERT)
MERGE app.UserSettings AS target
USING (VALUES (@UserId, @Key, @Value)) AS source (UserId, [Key], Value)
ON target.UserId = source.UserId AND target.[Key] = source.[Key]
WHEN MATCHED THEN
    UPDATE SET target.Value = source.Value, target.UpdatedAt = SYSDATETIMEOFFSET()
WHEN NOT MATCHED THEN
    INSERT (UserId, [Key], Value)
    VALUES (source.UserId, source.[Key], source.Value);

-- JSON (SQL Server 2016+)
SELECT Id,
       JSON_VALUE(Payload, '$.userId') AS UserId,
       JSON_VALUE(Payload, '$.amount') AS Amount
FROM dbo.Transactions
WHERE JSON_VALUE(Payload, '$.status') = 'completed'
  AND ISJSON(Payload) = 1;
```

---

## 4. Stored Procedures com Error Handling

```sql
CREATE OR ALTER PROCEDURE app.CreateUser
    @Email    NVARCHAR(255),
    @Name     NVARCHAR(100),
    @Password NVARCHAR(255),
    @NewId    UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Checar duplicata
    IF EXISTS (SELECT 1 FROM app.Users WHERE Email = @Email)
    BEGIN
        RAISERROR('Email already exists: %s', 16, 1, @Email);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @NewId = NEWSEQUENTIALID();

        INSERT INTO app.Users (Id, Email, Name, PasswordHash)
        VALUES (@NewId, @Email, @Name, @Password); -- senha deve ser hasheada na app

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        RAISERROR(@ErrorMsg, @ErrorSeverity, 1);
    END CATCH;
END;
GO
```

---

## 5. EF Core — Model e Migration (.NET)

```csharp
// Domain/User.cs
public class User
{
    public Guid Id { get; private set; }
    public string Email { get; private set; } = default!;
    public string Name { get; private set; } = default!;
    public string Role { get; private set; } = "viewer";
    public bool Active { get; private set; } = true;
    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset UpdatedAt { get; private set; }

    private User() { }

    public static User Create(string email, string name) =>
        new() { Id = Guid.NewGuid(), Email = email, Name = name, CreatedAt = DateTimeOffset.UtcNow, UpdatedAt = DateTimeOffset.UtcNow };
}

// Infrastructure/Configurations/UserConfiguration.cs
public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("Users", "app");
        builder.HasKey(u => u.Id);
        builder.Property(u => u.Email).HasMaxLength(255).IsRequired();
        builder.Property(u => u.Name).HasMaxLength(100).IsRequired();
        builder.HasIndex(u => u.Email).IsUnique();
        builder.Property(u => u.CreatedAt).HasColumnType("datetimeoffset(7)");
        builder.Property(u => u.UpdatedAt).HasColumnType("datetimeoffset(7)");
    }
}
```

---

## 6. DMVs — Monitoramento

```sql
-- Top queries por CPU
SELECT TOP 20
    qs.total_worker_time / qs.execution_count AS avg_cpu_us,
    qs.execution_count,
    qs.total_elapsed_time / qs.execution_count AS avg_elapsed_us,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(qt.text)
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)+1) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY avg_cpu_us DESC;

-- Conexões ativas
SELECT session_id, status, command, wait_type, wait_time,
       blocking_session_id, DB_NAME(database_id) AS db_name,
       text
FROM sys.dm_exec_requests er
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle)
WHERE session_id > 50; -- excluir processos internos

-- Missing indexes
SELECT mig.equality_columns, mig.inequality_columns,
       mig.included_columns, mid.statement AS table_name,
       migs.unique_compiles, migs.user_seeks,
       migs.avg_total_user_cost * migs.avg_user_impact AS impact_score
FROM sys.dm_db_missing_index_groups mig
JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
ORDER BY impact_score DESC;
```

---

## Anti-patterns

### ❌ RCSI desabilitado — READ_COMMITTED com locks compartilhados
**Problema:** O banco é criado sem `READ_COMMITTED_SNAPSHOT`, então leituras `READ COMMITTED` adquirem shared locks e bloqueiam escritas.
**Por quê evitar:** Em workloads OLTP, leitores bloqueiam escritores e vice-versa, causando timeouts e deadlocks desnecessários que desaparecem com RCSI.
**Solução:**
```sql
-- Habilitar RCSI no banco (operação online, sem downtime)
ALTER DATABASE MyDB SET READ_COMMITTED_SNAPSHOT ON;
-- Verificar
SELECT name, is_read_committed_snapshot_on
FROM sys.databases
WHERE name = 'MyDB';
```

---

### ❌ SELECT * em views e stored procedures
**Problema:** O desenvolvedor usa `SELECT *` em vez de listar colunas explicitamente.
**Por quê evitar:** Quando uma coluna é adicionada à tabela base, a view retorna a coluna antiga em cache até ser recriada com `sp_refreshview`; stored procedures que fazem `INSERT INTO ... SELECT *` quebram silenciosamente com erros de tipo ou contagem de colunas.
**Solução:**
```sql
-- Errado
SELECT * FROM app.Users WHERE Active = 1;

-- Correto — listar colunas explicitamente
SELECT Id, Email, Name, Role, CreatedAt
FROM app.Users
WHERE Active = 1;
```

---

### ❌ Transação implícita sem SET XACT_ABORT ON
**Problema:** A stored procedure abre uma transação mas não define `SET XACT_ABORT ON`, confiando apenas no `TRY/CATCH`.
**Por quê evitar:** Sem `XACT_ABORT ON`, certos erros de runtime (ex: violação de constraint) não abortam a transação automaticamente; um `RETURN` prematuro dentro do `TRY` pode deixar a transação aberta e causar commit parcial ou bloqueio de conexão.
**Solução:**
```sql
CREATE OR ALTER PROCEDURE app.TransferFunds
    @FromId UNIQUEIDENTIFIER,
    @ToId   UNIQUEIDENTIFIER,
    @Amount DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;  -- aborta a transação inteira em qualquer erro

    BEGIN TRY
        BEGIN TRANSACTION;
        -- operações...
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
```

---

### ❌ Cursor para processamento linha a linha
**Problema:** O desenvolvedor itera sobre linhas com `CURSOR` em vez de usar operações set-based.
**Por quê evitar:** Cursores em SQL Server têm overhead de alocação de memória e contexto por linha; para tabelas com milhares de registros, a diferença de performance pode ser de 10x–100x em comparação com uma operação `UPDATE` ou `MERGE` equivalente.
**Solução:**
```sql
-- Errado: cursor para atualizar status
DECLARE cur CURSOR FOR SELECT Id FROM app.Orders WHERE ...;
-- ...FETCH/UPDATE por linha

-- Correto: operação set-based
UPDATE app.Orders
SET Status = 'expired', UpdatedAt = SYSDATETIMEOFFSET()
WHERE Status = 'pending'
  AND CreatedAt < DATEADD(DAY, -30, SYSDATETIMEOFFSET());
```

---

### ❌ NOLOCK como solução universal para performance
**Problema:** O desenvolvedor adiciona `WITH (NOLOCK)` em todas as queries de leitura para "evitar bloqueios".
**Por quê evitar:** `NOLOCK` realiza leituras sujas (dados de transações não commitadas) e pode retornar linhas duplicadas ou omitir linhas durante page splits — dados financeiros lidos com `NOLOCK` podem estar incorretos. A solução correta é habilitar RCSI.
**Solução:**
```sql
-- Errado para dados financeiros
SELECT SUM(Amount) FROM app.Transactions WITH (NOLOCK);

-- Correto: habilitar RCSI no banco (veja anti-pattern #1)
-- e usar READ COMMITTED normalmente — sem hints
SELECT SUM(Amount) FROM app.Transactions;
```

---

### ❌ EF Core lazy loading em loops — N+1 queries
**Problema:** O desenvolvedor itera sobre uma lista de entidades e acessa uma propriedade de navegação dentro do loop, disparando uma query por item.
**Por quê evitar:** Com 100 pedidos, o código dispara 101 queries ao banco (1 para a lista + 1 por pedido para carregar os itens); com `Include()` seria uma única query com JOIN.
**Solução:**
```csharp
// Errado: N+1 — 1 query para orders + 1 query por order para Items
var orders = await context.Orders.ToListAsync();
foreach (var order in orders)
{
    Console.WriteLine(order.Items.Count); // lazy load dispara aqui
}

// Correto: eager loading com Include
var orders = await context.Orders
    .Include(o => o.Items)
    .ToListAsync();
```

---

### ❌ EF Core sem AsNoTracking() em queries somente leitura
**Problema:** Queries de leitura são feitas sem `AsNoTracking()`, fazendo o EF Core registrar todas as entidades no change tracker.
**Por quê evitar:** O change tracker consome memória proporcional ao número de entidades retornadas e adiciona overhead de detecção de mudanças em cada `SaveChanges()`; para APIs GET que nunca modificam os dados, esse custo é puro desperdício.
**Solução:**
```csharp
// Errado: entidades rastreadas desnecessariamente
var users = await context.Users
    .Where(u => u.Active)
    .ToListAsync();

// Correto: AsNoTracking para queries somente leitura
var users = await context.Users
    .AsNoTracking()
    .Where(u => u.Active)
    .ToListAsync();

// Alternativa global via DbContext para repositórios read-only
context.ChangeTracker.QueryTrackingBehavior = QueryTrackingBehavior.NoTracking;
```

---

### ❌ NEWID() como chave do índice clusterizado
**Problema:** O desenvolvedor usa `NEWID()` (GUID aleatório) como chave primária clusterizada.
**Por quê evitar:** GUIDs aleatórios causam fragmentação de página extrema — cada INSERT vai para uma página aleatória, fragmentando o índice e degradando performance de leitura; o `FILLFACTOR` cai rapidamente, aumentando I/O.
**Solução:**
```sql
-- Errado: GUID aleatório como PK clusterizado
Id UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY

-- Correto opção 1: NEWSEQUENTIALID() — GUID sequencial (SQL Server)
Id UNIQUEIDENTIFIER DEFAULT NEWSEQUENTIALID() PRIMARY KEY

-- Correto opção 2: IDENTITY INT/BIGINT para tabelas OLTP
Id BIGINT IDENTITY(1,1) PRIMARY KEY

-- Correto opção 3: no EF Core
modelBuilder.Entity<User>()
    .Property(u => u.Id)
    .HasDefaultValueSql("NEWSEQUENTIALID()");
```

---

### ❌ SQL dinâmico por concatenação de strings
**Problema:** O desenvolvedor monta SQL dinâmico concatenando parâmetros de entrada diretamente na string.
**Por quê evitar:** Abertura imediata para SQL injection; além disso, cada chamada gera um plano de execução diferente, poluindo o plan cache do SQL Server.
**Solução:**
```sql
-- Errado: SQL injection e cache miss
DECLARE @sql NVARCHAR(MAX) = 'SELECT * FROM Users WHERE Email = ''' + @Email + '''';
EXEC(@sql);

-- Correto: sp_executesql com parâmetros tipados
DECLARE @sql NVARCHAR(MAX) = N'SELECT Id, Name FROM app.Users WHERE Email = @Email';
EXEC sp_executesql @sql,
    N'@Email NVARCHAR(255)',
    @Email = @Email;
```

---

### ❌ Não monitorar o Query Store
**Problema:** O banco tem Query Store disponível mas o time nunca o consulta para identificar regressões de plano ou queries lentas.
**Por quê evitar:** Sem Query Store ativo, regressões de plano após uma atualização de estatísticas ou upgrade passam despercebidas por horas; o Query Store é a principal ferramenta nativa do SQL Server para detectar e forçar planos estáveis.
**Solução:**
```sql
-- Habilitar Query Store (SQL Server 2016+)
ALTER DATABASE MyDB SET QUERY_STORE = ON (
    OPERATION_MODE = READ_WRITE,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    MAX_STORAGE_SIZE_MB = 1024
);

-- Top 20 queries com maior tempo médio
SELECT TOP 20
    qt.query_sql_text,
    rs.avg_duration / 1000.0 AS avg_ms,
    rs.count_executions
FROM sys.query_store_query_text qt
JOIN sys.query_store_query q ON qt.query_text_id = q.query_text_id
JOIN sys.query_store_plan p  ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
ORDER BY rs.avg_duration DESC;
```
```
