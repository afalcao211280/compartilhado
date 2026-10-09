# Oracle Expert — Padrões de Código

## 1. Schema Design — Convenções Oracle

```sql
-- Oracle usa SEQUENCES para auto-increment (pré-12c)
-- Oracle 12c+: IDENTITY columns disponíveis
-- Oracle 23ai: UUID() function nativa

CREATE TABLE users (
    id          RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    email       VARCHAR2(255 CHAR) NOT NULL,
    name        VARCHAR2(100 CHAR) NOT NULL,
    password_hash VARCHAR2(255 CHAR) NOT NULL,
    role        VARCHAR2(20 CHAR) DEFAULT 'viewer' NOT NULL
                  CONSTRAINT ck_users_role CHECK (role IN ('admin', 'editor', 'viewer')),
    active      NUMBER(1) DEFAULT 1 NOT NULL
                  CONSTRAINT ck_users_active CHECK (active IN (0, 1)),
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT uq_users_email UNIQUE (email)
);

-- Índice funcional (equivalente ao partial/expression index do PostgreSQL)
CREATE INDEX ix_users_active_created ON users (created_at DESC)
    COMPRESS 1;  -- comprimir valores do índice quando repetidos

-- Índice bitmap — apenas para colunas de baixa cardinalidade em data warehouse
-- NUNCA usar em OLTP (causa locking severo em DML)
-- CREATE BITMAP INDEX bix_users_role ON users (role);  -- DW apenas

-- Trigger para updated_at
CREATE OR REPLACE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END;
/
```

---

## 2. PL/SQL — Procedimentos e Functions

```sql
-- Package — agrupar procedures e functions relacionadas
CREATE OR REPLACE PACKAGE user_pkg AS
    PROCEDURE create_user(
        p_email    IN  VARCHAR2,
        p_name     IN  VARCHAR2,
        p_password IN  VARCHAR2,
        p_new_id   OUT RAW
    );

    FUNCTION get_user(p_id IN RAW) RETURN SYS_REFCURSOR;
END user_pkg;
/

CREATE OR REPLACE PACKAGE BODY user_pkg AS

    PROCEDURE create_user(
        p_email    IN  VARCHAR2,
        p_name     IN  VARCHAR2,
        p_password IN  VARCHAR2,
        p_new_id   OUT RAW
    ) AS
        v_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM users
        WHERE LOWER(email) = LOWER(p_email);

        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Email already exists: ' || p_email);
        END IF;

        p_new_id := SYS_GUID();

        INSERT INTO users (id, email, name, password_hash)
        VALUES (p_new_id, LOWER(p_email), TRIM(p_name), p_password);

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END create_user;

    FUNCTION get_user(p_id IN RAW) RETURN SYS_REFCURSOR AS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT id, email, name, role, active, created_at
            FROM users
            WHERE id = p_id;
        RETURN v_cursor;
    END get_user;

END user_pkg;
/
```

---

## 3. Query Patterns Oracle (SQL)

```sql
-- Paginação com OFFSET/FETCH (Oracle 12c+)
SELECT id, name, email, created_at
FROM users
WHERE active = 1
ORDER BY created_at DESC, id DESC
OFFSET 0 ROWS FETCH NEXT 20 ROWS ONLY;

-- ROW_NUMBER() para compatibilidade 11g
SELECT * FROM (
    SELECT id, name, email, created_at,
           ROW_NUMBER() OVER (ORDER BY created_at DESC) AS rn
    FROM users
    WHERE active = 1
) WHERE rn BETWEEN 1 AND 20;

-- UPSERT com MERGE
MERGE INTO user_settings tgt
USING (SELECT :user_id AS user_id, :key AS key_col, :value AS value FROM DUAL) src
ON (tgt.user_id = src.user_id AND tgt.key_col = src.key_col)
WHEN MATCHED THEN
    UPDATE SET tgt.value = src.value, tgt.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN
    INSERT (user_id, key_col, value)
    VALUES (src.user_id, src.key_col, src.value);

-- Hierarquia com CONNECT BY
SELECT LPAD(' ', LEVEL * 2) || name AS name, id, parent_id, LEVEL
FROM categories
START WITH parent_id IS NULL
CONNECT BY PRIOR id = parent_id
ORDER SIBLINGS BY name;

-- JSON (Oracle 21c+)
SELECT jt.user_id, jt.amount
FROM transactions,
     JSON_TABLE(payload, '$'
         COLUMNS (
             user_id  VARCHAR2(36) PATH '$.userId',
             amount   NUMBER        PATH '$.amount'
         )
     ) jt
WHERE JSON_EXISTS(payload, '$.status?(@ == "completed")');
```

---

## 4. Explain Plan — Análise de Performance

```sql
-- Gerar explain plan
EXPLAIN PLAN FOR
SELECT u.name, COUNT(o.id) AS order_count
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE u.active = 1
GROUP BY u.id, u.name
ORDER BY order_count DESC;

-- Ver resultado formatado
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Autotrace (SQL*Plus / SQL Developer)
SET AUTOTRACE ON EXPLAIN STATISTICS

-- Hints para forçar plano (diagnóstico, não produção permanente)
SELECT /*+ INDEX(u IX_USERS_ACTIVE_CREATED) USE_NL(o) */ u.name, o.id
FROM users u, orders o
WHERE u.id = o.user_id AND u.active = 1;

-- Sinais de problema no plano:
-- FULL TABLE SCAN em tabela grande → falta índice ou estatísticas ruins
-- CARTESIAN JOIN → missing join condition
-- HASH JOIN com grande estimated rows → atualizar estatísticas DBMS_STATS
```

---

## 5. AWR / ASH — Diagnóstico de Performance

```sql
-- Top SQL por elapsed time (requer licença Diagnostic Pack)
SELECT sql_id, elapsed_time_delta/1000000 AS elapsed_s,
       executions_delta AS execs,
       elapsed_time_delta / NULLIF(executions_delta, 0) / 1000000 AS avg_s,
       sql_text
FROM dba_hist_sqlstat s
JOIN dba_hist_sqltext t USING (sql_id)
WHERE snap_id = (SELECT MAX(snap_id) FROM dba_hist_snapshot)
ORDER BY elapsed_time_delta DESC
FETCH FIRST 20 ROWS ONLY;

-- Sessions ativas agora por wait event
SELECT event, COUNT(*) AS sessions,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM v$session
WHERE status = 'ACTIVE' AND type != 'BACKGROUND'
GROUP BY event
ORDER BY sessions DESC;

-- Atualizar estatísticas manualmente (DBA)
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname   => 'MYSCHEMA',
        tabname   => 'USERS',
        estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
        method_opt => 'FOR ALL COLUMNS SIZE AUTO',
        cascade    => TRUE -- inclui índices
    );
END;
/
```

---

## 6. Spring Data JPA — Oracle Config

```java
// application.yml
spring:
  datasource:
    url: jdbc:oracle:thin:@//host:1521/servicename
    driver-class-name: oracle.jdbc.OracleDriver
    hikari:
      maximum-pool-size: 20
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000
  jpa:
    database-platform: org.hibernate.dialect.OracleDialect
    hibernate:
      ddl-auto: validate  # NUNCA create-drop em prod
    properties:
      hibernate:
        jdbc:
          batch_size: 50
          order_inserts: true
          order_updates: true
        format_sql: false
        show_sql: false
```

```java
// Entity — convenções Oracle
@Entity
@Table(name = "USERS", schema = "MYSCHEMA")
public class User {
    @Id
    @Column(name = "ID", columnDefinition = "RAW(16)")
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "EMAIL", nullable = false, length = 255)
    private String email;

    @Column(name = "CREATED_AT", nullable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = OffsetDateTime.now(ZoneOffset.UTC);
    }
}
```

---

## Anti-patterns

### ❌ ROWNUM para paginação sem ORDER BY
**Problema:** Usar `WHERE ROWNUM <= 10` para paginar sem garantir ordenação prévia.
**Por quê evitar:** ROWNUM é atribuído antes do ORDER BY — os "primeiros 10 rows" são não-determinísticos; resultados mudam entre queries.
**Solução:**
```sql
-- Oracle 12c+: use FETCH FIRST (limpo e correto)
SELECT id, nome, preco
FROM produtos
ORDER BY created_at DESC, id DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;

-- Oracle 11g: subquery com ROWNUM após ORDER BY
SELECT * FROM (
  SELECT p.*, ROWNUM rn FROM (
    SELECT id, nome FROM produtos ORDER BY created_at DESC
  ) p WHERE ROWNUM <= 20
) WHERE rn > 10;
```

### ❌ VARCHAR2 sem semântica CHAR explícita
**Problema:** Definir `VARCHAR2(100)` sem especificar `CHAR` ou `BYTE`.
**Por quê evitar:** O padrão depende do `NLS_LENGTH_SEMANTICS` do banco (geralmente BYTE) — com UTF-8, um caractere pode ter 1-4 bytes; `VARCHAR2(10)` aceita apenas 2-3 caracteres UTF-8 multibyte.
**Solução:**
```sql
-- Sempre especifique CHAR para dados textuais
nome    VARCHAR2(100 CHAR),
codigo  VARCHAR2(20 BYTE)  -- apenas para dados ASCII-safe (códigos, UUIDs)
```

### ❌ Literals em SQL em vez de bind variables
**Problema:** Gerar SQL com valores literais: `WHERE id = 123` ou `WHERE nome = 'Ana'`.
**Por quê evitar:** Cada literal único cria um novo cursor no shared pool — hard parse flood consome CPU e memória do SGA; bind variables permitem soft parse com reuso do execution plan.
**Solução:**
```java
// JDBC com bind variables — sempre
PreparedStatement ps = conn.prepareStatement(
    "SELECT * FROM usuarios WHERE id = ? AND status = ?"
);
ps.setLong(1, userId);
ps.setString(2, "ativo");
```

### ❌ NVL() em ambos os argumentos sempre avaliados
**Problema:** Usar `NVL(expressao_cara, 'default')` onde a expressão é custosa.
**Por quê evitar:** NVL avalia os dois argumentos antes de escolher — mesmo quando o primeiro não é NULL; COALESCE avalia lazily (para no primeiro não-NULL).
**Solução:**
```sql
-- NVL: avalia funcao_cara mesmo quando coluna IS NOT NULL
SELECT NVL(funcao_cara(id), 'fallback') FROM tabela;

-- COALESCE: avalia funcao_cara SOMENTE quando coluna IS NULL
SELECT COALESCE(coluna, funcao_cara(id), 'fallback') FROM tabela;
```

### ❌ Spring Boot com OSIV habilitado (Open Session in View)
**Problema:** Deixar `spring.jpa.open-in-view=true` (padrão) em APIs REST com Oracle.
**Por quê evitar:** A sessão JPA (e a conexão do pool) fica aberta durante toda a renderização HTTP — lazy loading silencioso em controllers causa N+1 e esgota o pool de conexões sob carga.
**Solução:**
```yaml
# application.yml
spring:
  jpa:
    open-in-view: false  # OBRIGATÓRIO em APIs REST
# Carregue todos os dados necessários na camada de service com fetch joins
```

### ❌ Hibernate ddl-auto: create-drop em staging/produção
**Problema:** Usar `spring.jpa.hibernate.ddl-auto: create-drop` em ambientes compartilhados.
**Por quê evitar:** `create-drop` destrói e recria todo o schema ao iniciar/parar a aplicação — perda irreversível de todos os dados do banco.
**Solução:**
```yaml
spring:
  jpa:
    hibernate:
      ddl-auto: validate  # verifica schema mas não altera
# Use Flyway ou Liquibase para migrations versionadas
```

### ❌ Estatísticas stale sem DBMS_STATS
**Problema:** Não executar coleta de estatísticas após bulk loads ou mudanças significativas de dados.
**Por quê evitar:** O optimizer escolhe planos de execução baseado em estatísticas — dados stale levam a full table scans desnecessários ou nested loops ineficientes em tabelas grandes.
**Solução:**
```sql
-- Após bulk insert/update significativo
EXEC DBMS_STATS.GATHER_TABLE_STATS('SCHEMA', 'TABELA', CASCADE => TRUE);
-- Em produção: job noturno de estatísticas automáticas (habilitado por padrão no Oracle 10g+)
-- Verificar: SELECT * FROM DBA_AUTO_TASK_CLIENT WHERE client_name = 'auto optimizer stats collection';
```
