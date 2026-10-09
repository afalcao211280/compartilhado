# SQL Server — Best Practices e Operações de Produção

Referência para performance, concorrência, particionamento, backup/HA e novidades do
SQL Server 2025. Genérico (não-EVEO-específico); os padrões corporativos EVEO ficam no
`SKILL.md`. Para padrões de código T-SQL do dia a dia (schema, procs, EF Core, DMVs),
ver `core.md`.

## Índice

1. [Índices e Execution Plans](#1-índices-e-execution-plans)
2. [SARGability e Tuning de Queries](#2-sargability-e-tuning-de-queries)
3. [Isolamento, RCSI e Concorrência](#3-isolamento-rcsi-e-concorrência)
4. [Deadlocks e Retry](#4-deadlocks-e-retry)
5. [Particionamento](#5-particionamento)
6. [Query Store e Plan Forcing](#6-query-store-e-plan-forcing)
7. [Recovery Models, Backup e Restore/PITR](#7-recovery-models-backup-e-restorepitr)
8. [Always On, HA e DR](#8-always-on-ha-e-dr)
9. [TempDB e Configuração de Instância](#9-tempdb-e-configuração-de-instância)
10. [Manutenção de Índices e Estatísticas](#10-manutenção-de-índices-e-estatísticas)
11. [Novidades SQL Server 2025](#11-novidades-sql-server-2025)
12. [Troubleshooting — Wait Stats e Sintomas](#12-troubleshooting--wait-stats-e-sintomas)
13. [Anti-padrões](#13-anti-padrões)
14. [Cross-references](#14-cross-references)

---

## 1. Índices e Execution Plans

| Padrão de query | Índice | Por quê |
|---|---|---|
| `WHERE id = x`, range, `ORDER BY`, prefix `LIKE 'x%'` | **Clustered / Nonclustered rowstore** | Seek por igualdade, range, ordenação. Toda tabela deve ter clustered |
| Query quente que só lê poucas colunas | **Covering (`INCLUDE`)** | Evita key/RID lookup — todas as colunas do SELECT no índice |
| Subconjunto recorrente (`Active = 1`, `DeletedAt IS NULL`) | **Filtered index** (`WHERE`) | Menor, escrita mais barata, estatística mais precisa |
| Coluna derivada usada em filtro/join | **Índice sobre computed column `PERSISTED`** | Torna a expressão SARGable e indexável |
| Analytics / agregação em tabela grande | **Clustered Columnstore (CCI)** | Compressão 10x, batch mode, ideal para DW/fato |
| OLTP + analytics na mesma tabela | **Nonclustered Columnstore (NCCI)** | HTAP — analytics sem cópia para DW |
| Busca textual | **Full-Text / Semantic** | `CONTAINS`, `FREETEXT` |

- **Chave clusterizada**: estreita, crescente, imutável, única. `BIGINT IDENTITY` ou
  `NEWSEQUENTIALID()` — nunca `NEWID()` (fragmentação por page split; ver `core.md`).
- **Ordem de colunas do índice composto**: igualdade primeiro, depois range/ordenação
  (regra equivalente ao ESR). Casar com o padrão real da query, não com a intuição.
- **Key lookup** no plano = falta coluna no índice → adicionar via `INCLUDE`.
- **Não sobre-indexar**: cada índice tem custo em `INSERT`/`UPDATE`/`DELETE` e storage.
  Auditar índices duplicados/nunca usados (`sys.dm_db_index_usage_stats`).

### Lendo o execution plan

```sql
SET STATISTICS IO, TIME ON;     -- logical reads + CPU/elapsed por statement
SET STATISTICS PROFILE ON;      -- plano real com contagem de linhas por operador
-- No SSMS: "Include Actual Execution Plan" (Ctrl+M)
```

Sinais de alerta no plano real (comparar **Estimated vs Actual Rows**):
- **Scan** (Clustered/Table) em tabela grande → falta índice ou predicado não-SARGable.
- **Key Lookup / RID Lookup** com muitas execuções → covering index com `INCLUDE`.
- **Estimated ≠ Actual** por ordem de magnitude → estatísticas velhas (`UPDATE STATISTICS`)
  ou parameter sniffing.
- **Warning de Spill** (Sort/Hash para tempdb) → memory grant insuficiente; revisar
  estimativa de cardinalidade ou reduzir volume intermediário.
- **Implicit Conversion** (warning) → tipo do parâmetro difere da coluna (ex.: `NVARCHAR`
  vs `VARCHAR`) → invalida seek, força scan.
- **Lock/Latch/CXPACKET** altos → contenção; ver seções 3 e 12.

Índices ausentes e não usados (complementar aos DMVs de `core.md`):

```sql
-- Índices nunca usados após o último restart (candidatos a DROP)
SELECT OBJECT_NAME(i.object_id) AS tabela, i.name AS indice,
       s.user_seeks, s.user_scans, s.user_lookups, s.user_updates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats s
       ON s.object_id = i.object_id AND s.index_id = i.index_id
      AND s.database_id = DB_ID()
WHERE i.type_desc = 'NONCLUSTERED' AND i.is_primary_key = 0
  AND COALESCE(s.user_seeks, 0) + COALESCE(s.user_scans, 0)
    + COALESCE(s.user_lookups, 0) = 0
ORDER BY s.user_updates DESC;
```

---

## 2. SARGability e Tuning de Queries

**SARGable** = o otimizador consegue usar seek de índice. Regra: **não aplicar função,
cast ou cálculo na coluna do `WHERE`/`JOIN`**.

```sql
-- ❌ Não-SARGable: função na coluna → scan
WHERE YEAR(CreatedAt) = 2026
WHERE CONVERT(date, CreatedAt) = '2026-07-01'
WHERE LEFT(Email, 5) = 'admin'
WHERE Amount * 1.1 > @Limite

-- ✅ SARGable: transformação no literal, coluna intacta → seek
WHERE CreatedAt >= '2026-01-01' AND CreatedAt < '2027-01-01'
WHERE CreatedAt >= '2026-07-01' AND CreatedAt < '2026-07-02'
WHERE Email LIKE 'admin%'
WHERE Amount > @Limite / 1.1
```

- **Implicit conversion**: parâmetro `NVARCHAR` contra coluna `VARCHAR` (ou vice-versa)
  quebra a SARGability. Tipar o parâmetro igual à coluna. Preferir `VARCHAR` quando não
  há necessidade de Unicode (`NVARCHAR` ocupa 2x).
- **`OR` que impede seek**: reescrever com `UNION ALL` de dois seeks quando cada ramo é
  seletivo.

### Parameter sniffing

O plano é compilado e cacheado para o primeiro conjunto de valores. Se a distribuição for
enviesada, um plano ótimo para "poucas linhas" degrada quando reusado para "muitas linhas".

```sql
-- Recompila a cada execução (custo de compile; para procs raras/muito variáveis)
... OPTION (RECOMPILE);

-- Fixa o plano para um valor representativo
... OPTION (OPTIMIZE FOR (@status = 'active'));
... OPTION (OPTIMIZE FOR UNKNOWN);   -- usa densidade média, ignora o valor sniffado
```

- **SQL Server 2025** resolve a maioria dos casos com **OPPO** (Optional Parameter Plan
  Optimization / Parameter Sensitive Plan Optimization) — múltiplos planos por proc,
  escolhidos pelo valor em runtime. Ver seção 11.
- Antes de hints, medir com Query Store (seção 6): hint fixo mascara regressão futura.

---

## 3. Isolamento, RCSI e Concorrência

| Nível | Comportamento | Uso |
|---|---|---|
| Read Uncommitted (`NOLOCK`) | Dirty reads: linhas não commitadas, duplicadas ou perdidas em page split | Evitar; usar RCSI |
| Read Committed (default, locking) | Shared locks nas leituras → leitor bloqueia escritor | Padrão herdado; trocar por RCSI |
| **Read Committed Snapshot (RCSI)** | Lê a última versão commitada via row-versioning; leitor **não** bloqueia escritor | **Recomendado para OLTP** |
| Snapshot (`SET TRANSACTION ISOLATION LEVEL SNAPSHOT`) | Snapshot consistente por transação | Relatórios longos consistentes |
| Repeatable Read | Mantém shared locks até o fim | Consistência intra-transação |
| Serializable | Range locks; sem phantom | Transações críticas |

```sql
-- Habilitar RCSI (online, sem downtime). Requer versionamento em tempdb.
ALTER DATABASE MyDB SET READ_COMMITTED_SNAPSHOT ON;
-- Snapshot isolation opcional (isolamento por transação, além do RCSI de statement)
ALTER DATABASE MyDB SET ALLOW_SNAPSHOT_ISOLATION ON;

SELECT name, is_read_committed_snapshot_on, snapshot_isolation_state_desc
FROM sys.databases WHERE name = 'MyDB';
```

- **RCSI é a alternativa correta ao `NOLOCK`**: elimina o bloqueio leitor↔escritor sem
  dirty reads. Custo: versões em `tempdb` (dimensionar tempdb — seção 9) e 14 bytes por
  linha versionada.
- **`NOLOCK`** só quando leitura aproximada é aceitável (dashboards não-transacionais) e
  a decisão está documentada. **Nunca** em dados financeiros/contábeis.
- **Transações curtas**: abrir tarde, commitar cedo. Nunca abrir transação e esperar por
  I/O de app/rede dentro dela (lock hold longo → bloqueio em cascata).
- **`SET XACT_ABORT ON`** em toda proc com transação: garante rollback em erro de runtime
  (ver `core.md`, anti-pattern de transação).
- **Lock escalation**: > ~5000 locks em um objeto escalam para lock de tabela. Mitigar com
  lotes menores ou `ALTER TABLE ... SET (LOCK_ESCALATION = AUTO)` em tabelas particionadas.

---

## 4. Deadlocks e Retry

Deadlock = duas sessões esperando lock uma da outra; o SQL Server elege uma vítima
(`Error 1205`) e faz rollback. **Não é bug do engine — é ordem de acesso.**

- **Prevenção**: acessar objetos sempre na **mesma ordem** entre transações; manter
  transações curtas; índices adequados (menos linhas travadas); RCSI reduz o footprint.
- **Diagnóstico**: capturar o deadlock graph via Extended Events (sessão `system_health`
  já captura por padrão):

```sql
SELECT CAST(xet.target_data AS XML) AS deadlock_xml
FROM sys.dm_xe_session_targets xet
JOIN sys.dm_xe_sessions xe ON xe.address = xet.event_session_address
WHERE xe.name = 'system_health' AND xet.target_name = 'ring_buffer';
```

- **Retry na aplicação** é obrigatório: `1205` (deadlock) e `1222` (lock timeout) são
  transitórios. Retry com backoff, idempotência garantida, limite de tentativas.

```csharp
// EF Core: retry resiliente para transitórios (inclui deadlock/timeout)
options.UseSqlServer(cs, o => o.EnableRetryOnFailure(
    maxRetryCount: 5,
    maxRetryDelay: TimeSpan.FromSeconds(10),
    errorNumbersToAdd: null));
```

---

## 5. Particionamento

Para tabelas grandes (dezenas de milhões+). Objetivo real: **manutenção e lifecycle**
(sliding window, switch, rebuild por partição), não ganho mágico de leitura — o ganho de
query vem de **partition elimination** quando a query filtra pela partition key.

```sql
-- 1) Função de partição (range por mês). RIGHT: o limite pertence à partição da direita.
CREATE PARTITION FUNCTION pf_Events_Monthly (DATETIME2)
AS RANGE RIGHT FOR VALUES
  ('2026-06-01', '2026-07-01', '2026-08-01');

-- 2) Esquema mapeando partições a filegroups (ou todas em [PRIMARY])
CREATE PARTITION SCHEME ps_Events_Monthly
AS PARTITION pf_Events_Monthly ALL TO ([PRIMARY]);

-- 3) Tabela particionada; a partition key deve integrar a PK/clustered
CREATE TABLE dbo.Events (
    Id        BIGINT IDENTITY NOT NULL,
    CreatedAt DATETIME2 NOT NULL,
    Payload   NVARCHAR(MAX) NULL,
    CONSTRAINT PK_Events PRIMARY KEY CLUSTERED (CreatedAt, Id)
) ON ps_Events_Monthly (CreatedAt);
```

- **Partition elimination**: validar no plano que só as partições relevantes são lidas
  (propriedade `Actual Partition Count`). Query sem filtro pela partition key varre todas.
- **Sliding window** (retenção): `SPLIT` cria a próxima partição, `SWITCH` move dados
  antigos para uma tabela de staging (metadados, instantâneo), `MERGE` remove o limite.

```sql
-- Novo mês
ALTER PARTITION SCHEME ps_Events_Monthly NEXT USED [PRIMARY];
ALTER PARTITION FUNCTION pf_Events_Monthly() SPLIT RANGE ('2026-09-01');

-- Arquivar/expurgar o mês mais antigo (quase instantâneo — só metadados)
ALTER TABLE dbo.Events SWITCH PARTITION 1 TO dbo.Events_Archive PARTITION 1;
ALTER PARTITION FUNCTION pf_Events_Monthly() MERGE RANGE ('2026-06-01');
```

- `SWITCH` exige tabela de staging com **schema e índices idênticos** e no mesmo filegroup.
- Muito mais barato que `DELETE` em massa (sem log de linha a linha, sem bloat).
- Combinar com **Clustered Columnstore** por partição para arquivamento comprimido.

---

## 6. Query Store e Plan Forcing

Query Store é o "flight recorder" de planos e runtime stats. **Habilitar em toda base de
produção** (é a principal ferramenta nativa contra regressão de plano).

```sql
ALTER DATABASE MyDB SET QUERY_STORE = ON (
    OPERATION_MODE = READ_WRITE,
    QUERY_CAPTURE_MODE = AUTO,                          -- ignora queries triviais
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    MAX_STORAGE_SIZE_MB = 1024,
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    INTERVAL_LENGTH_MINUTES = 60);
```

- **Regressão de plano** (query ficou lenta após upgrade/estatística): identificar no
  Query Store o plano bom anterior e **forçar**:

```sql
-- Queries que regrediram (múltiplos planos, um mais lento)
SELECT q.query_id, p.plan_id, rs.avg_duration/1000.0 AS avg_ms, rs.count_executions
FROM sys.query_store_query q
JOIN sys.query_store_plan p ON p.query_id = q.query_id
JOIN sys.query_store_runtime_stats rs ON rs.plan_id = p.plan_id
ORDER BY rs.avg_duration DESC;

EXEC sp_query_store_force_plan @query_id = 42, @plan_id = 17;   -- força
EXEC sp_query_store_unforce_plan @query_id = 42, @plan_id = 17; -- libera
```

- **Automatic Plan Correction**: deixa o engine reverter regressões sozinho.

```sql
ALTER DATABASE MyDB SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = ON);
```

---

## 7. Recovery Models, Backup e Restore/PITR

| Recovery model | Log | PITR | Uso |
|---|---|---|---|
| **FULL** | Retido até log backup | Sim (até o segundo) | **Produção OLTP** |
| Bulk-logged | Minimamente logado em bulk | Parcial | Janelas de carga em massa |
| Simple | Truncado em checkpoint | Não | Dev, DW recarregável |

Estratégia base em produção: **FULL + DIFF + LOG**. Regra 3-2-1 (3 cópias, 2 mídias,
1 offsite). **Backup não testado não é backup** — ensaiar restore periodicamente.

```sql
ALTER DATABASE MyDB SET RECOVERY FULL;

-- FULL semanal, com verificação e compressão
BACKUP DATABASE MyDB TO DISK = 'MyDB_full.bak'
  WITH COMPRESSION, CHECKSUM, INIT, STATS = 10;

-- DIFF diário (mudanças desde o último FULL)
BACKUP DATABASE MyDB TO DISK = 'MyDB_diff.bak'
  WITH DIFFERENTIAL, COMPRESSION, CHECKSUM;

-- LOG a cada 5-15 min (habilita PITR e controla o crescimento do log)
BACKUP LOG MyDB TO DISK = 'MyDB_log.trn' WITH COMPRESSION, CHECKSUM;

-- Backup direto para Azure Blob (SQL Server on-prem/VM)
BACKUP DATABASE MyDB TO URL = 'https://acct.blob.core.windows.net/bak/MyDB.bak'
  WITH CREDENTIAL = 'https://acct.blob.core.windows.net/bak', COMPRESSION, CHECKSUM;
```

**Restore com PITR** (cadeia FULL → DIFF → LOGs, com `NORECOVERY` até o último):

```sql
RESTORE DATABASE MyDB FROM DISK = 'MyDB_full.bak' WITH NORECOVERY, REPLACE;
RESTORE DATABASE MyDB FROM DISK = 'MyDB_diff.bak' WITH NORECOVERY;
RESTORE LOG MyDB FROM DISK = 'MyDB_log.trn'
  WITH STOPAT = '2026-07-01 14:30:00', RECOVERY;   -- ponto exato no tempo
```

- `WITH CHECKSUM` + `RESTORE VERIFYONLY` para detectar corrupção; rodar `DBCC CHECKDB`
  regularmente.
- **Azure SQL Database / MI**: backup automático (PITR 1-35 dias) + LTR configurável;
  restore self-service. Não gerenciar `.bak` manualmente.

---

## 8. Always On, HA e DR

**Always On Availability Groups (AG)** — HA + read scaling + DR (Enterprise).

- **Réplica síncrona** (mesmo site): zero perda de dados, commit espera o secundário
  endurecer o log → latência maior. Suporta **automatic failover**.
- **Réplica assíncrona** (DR remoto): rápida, perda possível (RPO > 0), failover manual.
- **Readable secondary**: descarrega leituras/relatórios/backup do primário.
  `ApplicationIntent=ReadOnly` na connection string + read-only routing no listener.
- **Listener**: nome/VIP único para a app; abstrai qual réplica é o primário atual.

```sql
-- Estado das réplicas e lag de sincronização
SELECT ar.replica_server_name, rs.role_desc, rs.synchronization_health_desc,
       drs.synchronization_state_desc, drs.log_send_queue_size,
       drs.redo_queue_size
FROM sys.dm_hadr_availability_replica_states rs
JOIN sys.availability_replicas ar ON ar.replica_id = rs.replica_id
JOIN sys.dm_hadr_database_replica_states drs ON drs.replica_id = rs.replica_id;
```

- Monitorar `log_send_queue_size` (backlog no primário) e `redo_queue_size` (atraso de
  aplicação no secundário) — ambos altos = risco de RPO/RTO estourado.
- **Azure SQL**: Active Geo-Replication / Auto-failover groups substituem o AG gerenciado.
- **Basic AG** (Standard Edition): 1 primário + 1 secundário, 1 database, sem leitura no
  secundário — DR mínimo.

---

## 9. TempDB e Configuração de Instância

`tempdb` é recurso global compartilhado (versionamento do RCSI, sorts/hash spills, tabelas
temporárias). Mal dimensionado → contenção de alocação (`PAGELATCH` em GAM/SGAM/PFS).

- **Múltiplos data files**: 1 por vCPU até 8, iguais em tamanho e autogrowth. Reduz
  contenção de páginas de alocação.
- Pré-dimensionar (evitar autogrowth em runtime); autogrowth em MB fixo, não em %.
- SSD/NVMe dedicado para tempdb; em Azure VM, usar o disco temporário local (`D:`).
- **MAXDOP** e **Cost Threshold for Parallelism**: default (`MAXDOP 0`, custo 5) costuma
  ser ruim em OLTP — ajustar `MAXDOP` ao nº de cores do NUMA node e elevar o custo (≈ 50)
  para evitar paralelismo em queries baratas (sintoma `CXPACKET`/`CXCONSUMER`).
- **Max Server Memory**: sempre limitar (deixar RAM para o SO/outros serviços).
- **Instant File Initialization** (privilégio "Perform Volume Maintenance Tasks") acelera
  grow/restore de data files.

---

## 10. Manutenção de Índices e Estatísticas

- **Fragmentação** (ver query em `core.md`): 5-30% → `REORGANIZE` (online, incremental);
  > 30% → `REBUILD` (`WITH (ONLINE = ON)` em Enterprise/Azure). Em tabela particionada,
  rebuild por partição.
- **Estatísticas**: manter `AUTO_UPDATE_STATISTICS` (e `..._ASYNC ON` para não bloquear a
  compilação). Em tabelas grandes, o gatilho automático pode ser raro → `UPDATE STATISTICS
  ... WITH FULLSCAN` agendado nas tabelas quentes.
- **Não usar `sp_updatestats` cegamente**; ele pode fazer sample pequeno em tabelas grandes.
- Preferir soluções mantidas (Ola Hallengren `IndexOptimize`) a scripts caseiros; em Azure
  SQL, usar Automatic Tuning + jobs Elastic.
- **Fill factor**: baixar (ex. 80-90) só em índices com muito page split; padrão 100 para
  índices crescentes.

---

## 11. Novidades SQL Server 2025

> RC em out/2025, GA prevista para nov/2025. Validar disponibilidade da feature na build
> antes de assumir em produção. Detalhamento completo: `skills-compare/sql-server-2025`.

### Vector database nativo (IA / RAG)

Tipo `VECTOR` (até 3.996 dimensões, half-precision) + índice **DiskANN** (ANN em disco)
para busca semântica em escala. Combina similaridade vetorial com filtros SQL (busca
híbrida) sem store vetorial externo.

```sql
CREATE TABLE Documents (
    Id INT PRIMARY KEY IDENTITY,
    Title NVARCHAR(200),
    ContentVector VECTOR(1536)          -- ex.: OpenAI ada-002
);

DECLARE @q VECTOR(1536) = CAST('[0.15, 0.25, ...]' AS VECTOR(1536));
SELECT TOP 10 Id, Title,
       VECTOR_DISTANCE('cosine', ContentVector, @q) AS Similarity
FROM Documents
WHERE Title LIKE '%Azure%'              -- filtro híbrido (keyword + vetor)
ORDER BY Similarity;

CREATE INDEX IX_Documents_Vector ON Documents(ContentVector)
USING VECTOR_INDEX WITH (DISTANCE_METRIC = 'cosine', VECTOR_SIZE = 1536);
```

### Optimized Locking

Reduz drasticamente memória de lock e bloqueio via **TID locking** (um lock por Transaction
ID em vez de N locks de linha) + **LAQ** (Lock After Qualification — avalia o predicado na
última versão commitada e só trava se qualificar). **Requer RCSI habilitado.** Menos lock
escalation, mais concorrência.

### OPPO — Optional/Parameter-Sensitive Plan Optimization

Múltiplos planos por statement, selecionados pelo valor do parâmetro em runtime; ataca o
parameter sniffing sem hints manuais.

```sql
ALTER DATABASE MyDB SET PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = ON;
```

### Outras novidades relevantes

- **Tipo `JSON` nativo** + funções (`JSON_ARRAYAGG`, `JSON_OBJECTAGG`): melhor performance
  e validação que `NVARCHAR(MAX)` com `ISJSON`.
- **Regex em T-SQL**: `REGEXP_LIKE`, `REGEXP_REPLACE`, `REGEXP_SUBSTR` (validação/extração).
- **REST a partir do T-SQL**: `sp_invoke_external_rest_endpoint` (enriquecer dados via API).
- **AI model integration**: `CREATE EXTERNAL MODEL` (ONNX/Azure OpenAI/Ollama), `PREDICT`,
  integração com LangChain/Semantic Kernel/EF Core; GraphQL via Data API Builder (DAB).
- **Microsoft Fabric mirroring** (zero-ETL): replicação near-real-time para OneLake via
  change feed (substitui CDC), requer Azure Arc — analytics sem carga no primário.
- **Microsoft Entra managed identities**: `CREATE LOGIN ... FROM EXTERNAL PROVIDER` —
  elimina credencial em connection string.
- **Sensitivity classification**: `ADD SENSITIVITY CLASSIFICATION` para rotular PII e
  novas permissões (`ALTER ANY INFORMATION PROTECTION`).
- **Tooling**: SqlPackage 170.2.70, ScriptDom 170.0.64, Microsoft.Build.Sql 2.0 (GA);
  target platform `SqlServer2025` em DACPAC/CI-CD.

---

## 12. Troubleshooting — Wait Stats e Sintomas

Wait stats são o ponto de partida: mostram **por que** as sessões esperam.

```sql
-- Top waits desde o último restart (ignora waits benignos de idle)
SELECT TOP 15 wait_type,
       wait_time_ms / 1000.0 AS wait_s,
       signal_wait_time_ms / 1000.0 AS signal_s,  -- espera por CPU (pressão de scheduler)
       waiting_tasks_count
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN ('CLR_SEMAPHORE','SLEEP_TASK','LAZYWRITER_SLEEP',
    'BROKER_TASK_STOP','XE_TIMER_EVENT','WAITFOR','SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
    'REQUEST_FOR_DEADLOCK_SEARCH','HADR_FILESTREAM_IOMGR_IOCOMPLETION')
ORDER BY wait_time_ms DESC;
```

| Wait / Sintoma | Causa provável |
|---|---|
| `PAGEIOLATCH_*` | I/O de disco lento / falta de memória (buffer pool pequeno) |
| `PAGELATCH_*` (tempdb) | Contenção de alocação em tempdb → mais data files (seção 9) |
| `LCK_M_*` | Bloqueio por lock → transações longas; considerar RCSI |
| `CXPACKET` / `CXCONSUMER` | Paralelismo excessivo → ajustar MAXDOP / Cost Threshold |
| `RESOURCE_SEMAPHORE` | Memory grants insuficientes → queries com spill, revisar planos |
| `WRITELOG` | Log lento → disco de log, autogrowth ruim, batch de commit |
| `SOS_SCHEDULER_YIELD` + `signal_s` alto | Pressão de CPU (queries caras / falta de índice) |
| Query lenta pontual | Estatística velha, parameter sniffing, key lookup, non-SARGable |
| Connection exhaustion | Falta de pooling, leak na app, `max pool size` baixo |

- Sessões e bloqueios ao vivo: `sys.dm_exec_requests` + `sys.dm_exec_sql_text`
  (`blocking_session_id`) — ver query pronta em `core.md`.
- Buffer cache hit ratio e Page Life Expectancy (`sys.dm_os_performance_counters`) baixos =
  pressão de memória.

---

## 13. Anti-padrões

- ❌ Cursor / loop `WHILE` onde set-based (`UPDATE`/`MERGE`/CTE) resolve — RBAR, 10-100x mais lento.
- ❌ Função/cast na coluna filtrada (não-SARGable) → scan em vez de seek.
- ❌ SQL concatenado (injection + plano novo a cada chamada) → sempre `sp_executesql` parametrizado.
- ❌ `NOLOCK` como "acelerador" universal → dirty reads; usar RCSI.
- ❌ `NEWID()` como chave clusterizada → fragmentação por page split; usar `NEWSEQUENTIALID()`/`IDENTITY`.
- ❌ Transação longa segurando lock enquanto espera I/O de app/rede.
- ❌ Recovery model FULL sem log backup → log cresce sem parar.
- ❌ Backup nunca testado; sem `DBCC CHECKDB` agendado.
- ❌ `SELECT *` em views/procs (quebra com mudança de schema; impede covering index).
- ❌ tempdb com um único data file em servidor multi-core.

---

## 14. Cross-references

- `core.md` — padrões de código T-SQL (schema, índices, procs, EF Core, DMVs, anti-patterns).
- `stack.md` — versões canônicas, drivers, ORMs, ferramentas de migration/HA.
- `oracle-expert`, `clean-architecture`, `security-expert`.
- `skills-compare/sql-server-2025` — catálogo completo de features do SQL Server 2025.
