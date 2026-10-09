# MongoDB — Design de Schema (Patterns e Anti-padrões)

Schema ruim é a causa raiz da maioria dos problemas de performance e custo no MongoDB — query e índice não consertam um modelo fundamentalmente errado. Fonte: padrões oficiais MongoDB. Consulte ao desenhar schema novo, migrar de SQL, revisar modelo, ou diante de slow queries / Atlas Schema Suggestions.

**Princípio central**: *dados acessados juntos são armazenados juntos.* Modele em torno das queries (endpoints/páginas), não das entidades. Embed elimina joins, reduz round-trips e habilita update atômico. Referencie só quando precisar.

## Índice
1. Fundamentos
   - 1.1 Embrace the document model (migração SQL)
   - 1.2 Embed vs Reference (matriz de decisão)
   - 1.3 Relacionamentos (1:1, 1:few, 1:many, M:N, árvore)
   - 1.4 Schema validation (`$jsonSchema`)
   - 1.5 Tamanho de documento (limite 16MB)
2. Anti-padrões (Atlas Performance Advisor)
   - 2.1 Coleções desnecessárias
   - 2.2 `$lookup` excessivo
   - 2.3 Índices desnecessários
3. Patterns de modelagem
   - 3.1 Subset / hot-cold
   - 3.2 Extended reference
   - 3.3 Computed
   - 3.4 Approximation
   - 3.5 Bucket
   - 3.6 Attribute
   - 3.7 Polymorphic
   - 3.8 Outlier
   - 3.9 Archive
   - 3.10 Time series collections
   - 3.11 Document versioning vs schema versioning

---

## 1. Fundamentos

### 1.1 Embrace the document model

**Não recrie tabelas SQL 1:1 em coleções MongoDB.** Espelhar fronteiras relacionais (`customers` + `addresses` + `phones` + `preferences` ligados por `customerId`) força 4 queries + join na aplicação por perfil, e updates exigem coordenação cross-collection / transação.

Modelo rico: tudo do cliente em um documento → 1 read, update atômico sem transação.

```javascript
{ _id: "cust123", name: "Alice", email: "alice@ex.com",
  addresses: [{ type: "home", street: "123 Main", city: "Boston" }],
  phones: [{ type: "mobile", number: "555-1234" }],
  preferences: { newsletter: true, theme: "dark" } }
```

Migração SQL: (1) não converta tabelas 1:1; (2) identifique tabelas sempre joinadas; (3) denormalize esses joins em um documento; (4) mantenha separado só o que é acessado separado.

**Não aplicar quando**: dados genuinamente independentes/compartilhados; relacionamento unbounded (user com 10k orders não embeda orders); compliance que exige trilha normalizada.

### 1.2 Embed vs Reference — matriz de decisão

Decida por **padrão de acesso**, não só pela cardinalidade da relação.

| Relação | Cardinalidade | Acesso | Bounded? | Decisão |
|---|---|---|---|---|
| User → Profile | 1:1 | sempre junto | sim | **Embed** |
| User → Addresses | 1:few (1–5) | quase sempre junto | sim | **Embed array** |
| Order → Line items | 1:few (1–50) | sempre junto | sim | **Embed array** |
| Publisher → Books | 1:many (1000+) | frequentemente separado | não | **Reference** |
| Post → Comments | 1:many (unbounded) | adds separados | não | **Reference** |
| Students ↔ Classes | M:N | ambas direções | moderado | **Reference dos dois lados** |
| Product ↔ Category | M:N | qualquer direção | moderado | **Embed ref na direção primária** |

- **Embed quando**: acessado junto; filho não faz sentido sem o pai; updates atômicos; array claramente limitado por regra de negócio.
- **Reference quando**: acessado de forma independente; M:N; filho grande relativo ao pai ou array de crescimento ilimitado; frequências de update diferentes.

Guia **aproximado** — sempre valide com o workload real.

### 1.3 Relacionamentos

**1:1** — embed no pai quando co-acessado (elimina round-trip, garante atomicidade). Agrupe em subdocumentos lógicos (`auth`, `profile`, `settings`). NÃO embed se: acessado independente, requisitos de segurança distintos (auth vs profile), diferença extrema de tamanho, frequências de update muito diferentes.

**1:few** — embed array limitado.
```javascript
db.users.updateOne({ _id, "addresses.type": "home" }, { $set: { "addresses.$.city": "Cambridge" } })
```
Imponha o limite com schema validation (`maxItems`). NÃO embed se: crescimento ilimitado, acesso independente, filho grande.

**1:many** — referencie no filho com índice no campo de referência. Embedar 10k+ filhos faz cada insert reescrever documento grande até estourar 16MB.
```javascript
{ _id: "book001", title: "...", publisherId: "oreilly" }   // index { publisherId: 1 }
db.books.find({ publisherId: "oreilly" })                  // ou $lookup quando precisar dos dois lados
```
Híbrido: embede subset limitado (top 5) no pai para exibição sem `$lookup`; "ver todos" consulta a coleção de filhos. Mantenha contadores denormalizados em sync (`$inc`).

**M:N** — escolha a direção primária de query e denormalize para o padrão mais comum. Embedding bidirecional (summaries dos dois lados) quando ambas direções são frequentes — troca duplicação por leitura rápida. Reference-only quando cardinalidade alta:
```javascript
{ _id: "prod123", categoryIds: ["cat1", "cat2"] }   // categoria sem back-reference array
```
Manter consistência bidirecional → use transação para os dois `$push`.

**Árvore/hierarquia** — escolha por operação primária:

| Pattern | Pais | Filhos | Descendentes | Ancestrais | Custo update |
|---|---|---|---|---|---|
| Parent refs | direto | indexado | recursivo/`$graphLookup` | recursivo | baixo |
| Child refs | query membership | direto | recursivo/`$graphLookup` | recursivo | baixo–médio |
| Array of ancestors | via `parent` | via `parent` | rápido (indexado) | direto (armazenado) | médio |
| Materialized paths | via path/`parent` | prefix query | regex/prefix | do path | médio |

Breadcrumb → array of ancestors. File browser → parent refs. Org chart → materialized paths. Threads de comentário → parent refs.

### 1.4 Schema validation

Última linha de defesa contra dado inválido. Use `$jsonSchema` no `validator` da coleção.

```javascript
db.createCollection("users", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["email", "name"],
    properties: {
      email: { bsonType: "string", pattern: "^[\\w.%+-]+@[\\w.-]+\\.[a-zA-Z]{2,}$" },
      name:  { bsonType: "string", minLength: 1, maxLength: 100 },
      status:{ enum: ["active", "inactive", "pending"] },
      addresses: { bsonType: "array", maxItems: 10 }   // trava array unbounded
    }
  }},
  validationLevel: "strict", validationAction: "error"
})
```

| `validationLevel` | Comportamento | | `validationAction` | Comportamento |
|---|---|---|---|---|
| `strict` (default) | valida todos inserts/updates | | `error` (default) | rejeita inválidos |
| `moderate` | valida só docs que já batem o schema | | `warn` | aceita e loga (só migração) |

Adicionar a coleção existente: comece `moderate`+`warn`, encontre violações (`db.coll.find({ $nor: [validator] })`), depois aperte para `strict`+`error`. NÃO usar em: prototipação rápida, designs schema-per-document intencionais, coleções de log/eventos de alta escrita.

### 1.5 Tamanho de documento

**16MB é limite rígido do BSON** — write falha ao atingir. Alvo prático: **< 1MB** (melhor working-set na cache WiredTiger, reads/writes mais rápidos, oplog menor). 16MB é rede de segurança, não meta de design.

Como documentos incham: (1) arrays unbounded; (2) arrays grandes ainda que limitados (cada `$push` reescreve o doc, índice multikey fan-out por elemento); (3) campos cold junto de hot (MongoDB lê o documento inteiro mesmo com projection — projection economiza rede, não memória, a menos que a query seja coberta por índice); (4) binário grande embedado; (5) aninhamento profundo.

- **Solução 1**: mover dado unbounded/grande para coleção separada com referência + índice composto. Binário grande → GridFS ou object storage externo.
- **Solução 2 (Subset pattern)**: hot fields no doc principal; cold em coleção separada. Ex.: movie (~2KB: título, rating, plot, `reviewStats`, `featuredReviews` top-5) + reviews completos em `reviews` carregados sob clique. Aumenta densidade da cache drasticamente.
- **Manter subset embedado limitado** sem job: `$push` com `$slice` e `$sort`.
```javascript
db.posts.updateOne({ _id }, { $push: { recentComments: { $each: [c], $slice: -20, $sort: { ts: -1 } } }, $inc: { commentCount: 1 } })
```

Hot vs cold: hot = exibido em todo load, usado em filtro/sort, pequeno, limitado, muda raro. Cold = só sob ação do usuário, histórico/arquival, grande, unbounded, muda frequente.

Diagnóstico: `$bsonSize: "$$ROOT"` por documento; `db.serverStatus().wiredTiger.cache`. Atlas sinaliza "Array field may grow without bound" e "Document size exceeds recommended limit".

---

## 2. Anti-padrões (Atlas Performance Advisor)

### 2.1 Coleções desnecessárias

O anti-padrão **não é a contagem** — é usar coleção como substituto de índice (uma coleção por categoria/dia/tenant em vez de indexar uma só). Cada coleção carrega índice `_id` default (365 coleções/ano = 365 índices extras), queries cross-collection exigem `$unionWith`, e validação/índices/TTL precisam ser duplicados.

Correto: uma coleção + índice fazendo o particionamento.
```javascript
db.temperatures.createIndex({ timestamp: 1 })
db.temperatures.find({ timestamp: { $gte: ISODate("2024-05-10"), $lt: ISODate("2024-05-11") } })
db.temperatures.createIndex({ timestamp: 1 }, { expireAfterSeconds: 7776000 })   // TTL 90d
```
Para alto volume time-stamped → bucket pattern ou time series collection. **Separar de fato quando**: dados independentes, relação unbounded, M:N, contextos/lifecycles diferentes, compliance.

### 2.2 `$lookup` excessivo

`$lookup` repetido em hot path indica over-normalização (custo depende de cardinalidade, ordem de stage, suporte de índice, tamanho do resultado — **meça antes de embedar**). Se os mesmos campos relacionados são lidos juntos com frequência, denormalize (embed ou extended reference).

Sync de dado denormalizado: dado raro → `updateMany` ao mudar a fonte. Dado frequente → mantenha `brandId` + cache `brandCache` com `cachedAt`, refresh ao expirar staleness. NÃO denormalizar: dado muda frequente/independente, raramente acessado, M:N de alta cardinalidade, queries analíticas batch.

Diagnóstico: profiler com `"command.pipeline.$lookup": { $exists: true }`; `$indexStats` para checar índice no campo foreign; `explain("executionStats")` → `totalDocsExamined` no stage.

### 2.3 Índices desnecessários

**Todo índice tem custo de escrita** — insert/update/delete atualizam TODOS os índices, e índices consomem RAM na cache competindo com o working set. Atlas sinaliza "Redundant Index" (prefixo de um composto existente) e "Unused Index" (zero uso).

```javascript
db.col.createIndex({ a: 1 })        // DROP — redundante (prefixo)
db.col.createIndex({ a: 1, b: 1 })  // mantém (serve todas as queries de {a:1})
db.col.createIndex({ b: 1 })        // mantém — leading field diferente, NÃO é coberto
```

Remoção segura: **hide → monitor → drop**.
```javascript
db.orders.hideIndex("status_1")     // invisível ao planner, fica em disco
// monitore um ciclo de workload; se degradar: db.orders.unhideIndex("status_1")
db.orders.dropIndexes(["status_1"]) // só quando confiante
```
Diagnóstico: `$indexStats` → `accesses.ops: 0` após período representativo = nunca usado. NÃO remover: índices de operações raras mas críticas (backup/compliance mensal), TTL (servem lifecycle, não query).

---

## 3. Patterns de modelagem

### 3.1 Subset / hot-cold
Ver 1.5. Hot no documento principal; cold em coleção separada. Melhora densidade da cache em hot paths.

### 3.2 Extended reference
Copie campos frequentemente acessados do documento referenciado para o pai (elimina `$lookup` em queries comuns, mantém a fonte normalizada).
```javascript
{ _id: "order123", customer: { _id: "cust456", name: "Jane", email: "jane@ex.com" }, total: 299.99 }
```
Cache: display name/avatar, status/tipo, dado que muda devagar, campos de sort/filtro. NÃO cache: bio/descrição completa, PII sensível, valores real-time (saldo, estoque), binário grande. Sync: atualize a fonte primeiro, depois `updateMany` nas cópias por `_id`; ou cache com `cachedAt` + refresh on read.

### 3.3 Computed
Pré-calcule e armazene valores agregados frequentemente lidos (troca complexidade de escrita por velocidade de leitura).
```javascript
// update on write (baixo volume)
db.movies.updateOne({ _id }, { $inc: { "stats.totalViewers": 400 }, $set: { "stats.computedAt": new Date() } })
// background job (alto volume): aggregate + $merge into a coleção destino
```
`computedAt` para controle de staleness. Considere **on-demand materialized views** (`$merge`/`$out`) quando o resultado tem shape/granularidade diferente da fonte ou precisa ser indexado independente. NÃO usar: cálculo raramente acessado, escrita altíssima, consistência forte exigida.

### 3.4 Approximation
Armazene valores **aproximados** para reduzir carga de escrita quando exatidão real-time não é necessária (contadores de alta frequência: views, trending). Batche incrementos em memória e escreva ao cruzar threshold (ex.: a cada 100 → ~100× menos writes). Trade-off: staleness até `threshold` eventos, incrementos não sincronizados perdidos no restart. **NUNCA** para: valores financeiros, estoque, contagens auditadas.

Diferença do Computed: Computed pré-calcula resultado **exato**; Approximation grava valor **inexato** de propósito para reduzir frequência de escrita.

### 3.5 Bucket
Agrupe série de itens relacionados em arrays limitados num único documento (reduz contagem de documentos, alinha storage ao consumo — ex.: paginação). Para time-series, **prefira time series collections** (bucketing automático + compressão).
```javascript
db.trades.findOneAndUpdate(
  { _id: /^123_/, count: { $lt: 10 } },              // bucket do cliente não cheio
  { $push: { history: trade }, $inc: { count: 1 },
    $setOnInsert: { _id: "123_" + epoch, customerId: 123 } },
  { upsert: true, sort: { _id: -1 } })               // 1 bucket = 1 página
```
NÃO usar: workload time-series (use TS collection), acesso aleatório por item, baixo volume, itens muito heterogêneos em tamanho.

### 3.6 Attribute
Muitos campos opcionais/esparsos → mova para array key-value (evita dezenas de índices parciais; um multikey index cobre tudo).
```javascript
{ _id: 1, name: "Bottle", attributes: [{ k: "color", v: "red" }, { k: "size", v: "M" }] }
db.items.createIndex({ "attributes.k": 1, "attributes.v": 1 })
db.items.find({ attributes: { $elemMatch: { k: "color", v: "red" } } })
```
NÃO usar: schema fixo/estável, validação type-specific por campo, queries single-field, **Atlas Search** (estrutura `{k,v}` não mapeia como campos nomeados — use campos estáticos).

### 3.7 Polymorphic
Tipos diferentes mas relacionados numa só coleção com discriminador `type` (mantém queries/índices compartilhados simples, permite campos específicos por tipo). Adicionar tipo novo não exige migração.
```javascript
db.products.createIndex({ type: 1, price: 1 })                                  // sempre filtra por tipo
db.products.createIndex({ price: 1, type: 1 })                                  // raramente filtra por tipo
db.products.createIndex({ author: 1 }, { partialFilterExpression: { type: "book" } })  // campo de um tipo
db.products.createIndex({ "specs.$**": 1 })                                     // wildcard p/ campos variáveis
```
Validação por tipo: `$jsonSchema` com `oneOf` por discriminador. NÃO usar: padrões de acesso totalmente distintos, requisitos de índice conflitantes, separação estrita exigida (regulatório), tamanhos de doc muito díspares, shard key por tipo.

### 3.8 Outlier
Isole documentos atípicos com arrays gigantes (ex.: bestseller com 50k clientes vs típico de 50) para não degradar queries típicas. Documento normal mantém array embedado + `hasExtras: false`; outlier limita o array no threshold, marca `hasExtras: true`, guarda `customerCount` denormalizado, e transborda o resto para coleção separada em batches. App checa `hasExtras` antes de carregar overflow. Índice multikey no doc principal fica pequeno (só o threshold por doc).

NÃO usar: distribuição uniforme, sempre precisa do dado completo, outliers write-heavy, outliers pequenos (só aumente o threshold).

### 3.9 Archive
Mova dado histórico raramente acessado para storage separado (reduz coleção ativa, índices, working set e custo). `$merge` para a coleção de archive (`whenMatched: "keepExisting"`) + `deleteMany` na ativa, em batches.

Storage (melhor→pior custo/perf): object storage externo (S3 + Atlas Data Federation) → cluster mais barato → coleção no mesmo cluster → **Atlas Online Archive** (tiering automático por regra de data, query transparente via Federated DB, zero código). Dicas: archive deve ser **self-contained** (embede snapshot do relacionado, não referências que podem sumir); guarde idade em um campo indexável único (`date`); trate `retentionPolicy: "permanent"`. Se o dado deve ser **deletado** (não arquivado), use TTL.

### 3.10 Time series collections
Purpose-built para measurements append-only (IoT, métricas, financeiro, logs): bucketing, compressão e índice automáticos → 10–100× menos storage/índice. **MongoDB 8.0**: block processing acelera pipelines analíticos elegíveis (`$match` + `$sort` no timeField + `$group`) em até +200%, automático.
```javascript
db.createCollection("sensor_data", {
  timeseries: { timeField: "ts", metaField: "metadata", granularity: "minutes" },
  expireAfterSeconds: 60*60*24*90 })   // TTL 90d
```
`metaField`: campos co-queridos com tempo, cardinalidade **moderada**, **estáticos** para a série (NÃO use campo único como requestId, nem campo que muda). `granularity`: `seconds` (bucket ~1h) / `minutes` (~24h) / `hours` (~30d), case por taxa de ingestão; ou `bucketMaxSpanSeconds` (6.3+). Insert em batch (`insertMany`, `ordered: false`), agrupando mesmo metaField. NÃO usar: acesso primário não-temporal, updates/deletes frequentes em dado antigo, volume muito baixo, **writes em transação** (não suportado; reads sim).

### 3.11 Document versioning vs schema versioning

| Pattern | Propósito | Armazena |
|---|---|---|
| **Schema versioning** | migração de estrutura de campo | campo `schemaVersion` em cada doc |
| **Document versioning** | reproduzir estado histórico exato (auditoria/compliance) | snapshots completos em coleção `revisions` |

**Schema versioning** evita *schema drift* (docs da mesma coleção com estruturas inconsistentes → código defensivo, queries que falham silenciosamente). Adicione `schemaVersion` a todo doc; código aceita as duas versões durante a transição; deploy do código novo antes da migração de dados; rollback fácil. Migração online: batch em background (com guarda `schemaVersion: { $lt: 2 }` anti-double-migration + throttle), pipeline `updateMany` (4.2+), ou lazy on-read.
- **Bump necessário** (breaking): rename de campo, mudança de tipo, restruturação, remoção de campo lido por código antigo.
- **Sem bump** (compatível): adicionar campo opcional, adicionar índice, relaxar validação.

Detectar drift: `$objectToArray` + `$group` por conjunto de chaves (vários key-sets distintos = drift).

**Document versioning**: coleção `current` (estado atual, reads rápidos) + coleção `revisions` (snapshots por `v`). Use transação para inserir a revisão e atualizar o current atomicamente. Índice `{ entityId: 1, v: -1 }` + TTL para retenção. NÃO usar: updates altíssima frequência (use event sourcing), histórico aproximado basta, crescimento de revisões sem política de retenção.
