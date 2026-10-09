# Apache Solr 9+ — Best Practices, Tuning e Decisões

Deep-dive de decisões e tuning para Solr 9+ / SolrCloud, EVEO-aligned (ADR-012).

> Este arquivo cobre **decisões de design e tuning** (schema, relevância, faceting,
> commit, cluster, cache, segurança). Os **snippets de código prontos** (Schema API,
> SolrJ, pysolr, diagnóstico) estão em `core.md`; **versões/JVM/config base** em `stack.md`.

## Índice

- [1. Schema — Field Types e Analyzers](#1-schema--field-types-e-analyzers)
- [2. Query DSL — edismax, fq e Boosting](#2-query-dsl--edismax-fq-e-boosting)
- [3. Faceting — facet.* e json.facet](#3-faceting--facet-e-jsonfacet)
- [4. Commit Strategy](#4-commit-strategy)
- [5. SolrCloud + ZooKeeper](#5-solrcloud--zookeeper)
- [6. Tuning de Cache](#6-tuning-de-cache)
- [7. Segurança](#7-seguranca)
- [8. Anti-padrões](#8-anti-padroes)

---

## 1. Schema — Field Types e Analyzers

### Escolha de field type

| Necessidade | Field type | Notas |
|-------------|-----------|-------|
| Match exato, facet, sort, filtro | `string` | Token único, sem análise. `docValues=true` p/ facet/sort |
| Busca full-text | `text_general` / `text_pt` | Tokenizado + analisado. **Não** usar para facet/sort direto |
| Numéricos | `pint`/`plong`/`pfloat`/`pdouble` | "Point" types (Solr 9). Range eficiente |
| Data | `pdate` | ISO-8601, range `[NOW-30DAYS TO NOW]` |
| Booleano | `boolean` | |
| Ambos (busca + facet) no mesmo dado | `text_*` + `copyField` → `string` | Ex.: `name` (text) + `name_exact` (string) |

Regras:
- `indexed=true` apenas se busca/filtra; `stored=true` apenas se precisa **retornar** o valor;
  `docValues=true` para facet/sort/grouping/funções (colunar, heap-efficient).
- `uninvertible=false` (default no 9) evita fielddata acidental em campos `text`.
- `copyField` para servir múltiplos usos (full-text + exact match + `_text_` catch-all).
- `multiValued` explícito quando o campo é lista.

### Analyzers (index vs query)

Um `TextField` define `indexAnalyzer` e `queryAnalyzer` (podem divergir — ex.: sinônimos só
na query). Cadeia típica PT-BR:

```
tokenizer:  StandardTokenizerFactory
filters:    LowerCaseFilterFactory
            ASCIIFoldingFilterFactory            # remove acentos p/ recall
            StopFilterFactory (stopwords_pt.txt)
            BrazilianStemFilterFactory           # stemming PT
            SynonymGraphFilterFactory            # PREFERIR na query, não no index
```

Decisões de analyzer:
- **Sinônimos**: aplicar no `queryAnalyzer` (`SynonymGraphFilterFactory`) evita reindex ao
  mudar a lista; se aplicar no index, toda alteração exige reindexação total.
- **Stemming vs exact**: campo `text_pt` (stem) recupera "notebooks" ao buscar "notebook";
  para match exato/ordenação mantenha um `copyField` `string`.
- **Managed resources**: use `managed-schema` + Schema API; `stopwords`/`synonyms` gerenciados
  via Managed Resources API propagam por ZooKeeper (sem editar arquivo no nó).
- **Debug**: `analysis/field?analysis.fieldname=...&analysis.fieldvalue=...` mostra a cadeia
  token a token (ver `core.md` §5). Divergência index/query aqui explica "não encontra".

---

## 2. Query DSL — edismax, fq e Boosting

### edismax como parser padrão

`defType=edismax` é o parser para busca de usuário: tolera sintaxe "suja" (sem erros de
parse), busca multi-campo e permite boosting rico.

| Param | Função | Exemplo |
|-------|--------|---------|
| `qf` | Campos consultados + boost por campo | `qf=name^3 description^1 tags^2` |
| `pf` | Phrase boost — termos próximos pontuam mais | `pf=name^5` |
| `pf2`/`pf3` | Phrase boost em bigramas/trigramas | `pf2=name^3` |
| `ps` | Phrase slop (distância tolerada) | `ps=2` |
| `mm` | Minimum should match | `mm=75%` ou `mm=2<-1 5<80%` |
| `tie` | Tiebreaker entre campos (0=max, 1=soma) | `tie=0.1` |
| `bq` | Boost query (aditivo ao score) | `bq=active:true^2` |
| `bf` | Boost function (aditivo) | `bf=recip(ms(NOW,created_at),3.16e-11,1,1)` |
| `boost` | Boost multiplicativo (recomendado p/ recência/popularidade) | `boost=recip(...)` |
| `qs` | Query slop em campos | `qs=1` |

### `q` vs `fq`

- `q` = **relevância** (afeta score). Só o que precisa pontuar.
- `fq` = **filtros** de negócio (não afetam score, **cacheados** no `filterCache`).
  5-20x mais rápido que filtrar no `q`. Um `fq` por dimensão para maximizar reuso de cache.

```
q=laptop&defType=edismax&qf=name^3 description&pf=name^5&mm=75%
fq=active:true
fq=category:"Eletrônicos"
fq=price:[50 TO 500]
```

### Deep paging

Nunca `start` grande — cada shard busca e descarta N docs (custo multiplica por shard).
Use `cursorMark=*` + `sort` determinístico (inclua `id`), iterando `nextCursorMark`.
Para exportação em massa: `/export` handler com `docValues`.

---

## 3. Faceting — facet.* e json.facet

### API clássica (`facet.*`) — simples

```
facet=true
facet.field=category&facet.field=tags
facet.mincount=1               # omite buckets vazios (obrigatório — evita ruído)
facet.limit=20
facet.range=price&facet.range.start=0&facet.range.end=1000&facet.range.gap=100
facet.pivot=category,brand     # facets hierárquicas
```

### JSON Facet API (`json.facet`) — preferir para casos ricos

Mais expressiva e performática: métricas agregadas, sub-facets aninhadas, filtros de domínio.

```json
{
  "categories": {
    "type": "terms", "field": "category", "limit": 20, "mincount": 1,
    "facet": {
      "avg_price": "avg(price)",
      "in_stock": { "type": "query", "q": "active:true" },
      "brands": { "type": "terms", "field": "brand", "limit": 5 }
    }
  },
  "price_ranges": {
    "type": "range", "field": "price", "start": 0, "end": 1000, "gap": 100
  }
}
```

Boas práticas de facet:
- `mincount:1` sempre (default retorna buckets com 0 docs → resposta volumosa).
- Limitar cardinalidade (`limit`) — facet em campo de altíssima cardinalidade é caro.
- Campos de facet devem ter `docValues=true`.
- Cardinalidade única (distinct count): `unique(field)` ou `hll(field)` (HyperLogLog, aproximado).
- `refine:true` em SolrCloud multi-shard para contagens exatas em top-N.

---

## 4. Commit Strategy

Dois tipos de commit — separar visibilidade de durabilidade:

| | soft commit | hard commit |
|-|-------------|-------------|
| Objetivo | **Visibilidade** (NRT) | **Durabilidade** (fsync + novo segmento) |
| `openSearcher` | true (novo searcher) | **false** (recomendado no autoCommit) |
| Custo | baixo | alto (I/O) |
| Config alvo | `autoSoftCommit.maxTime` 1-10s | `autoCommit.maxTime` 15-60s |

```xml
<autoSoftCommit>
  <maxTime>1000</maxTime>          <!-- visibilidade NRT ~1s -->
</autoSoftCommit>
<autoCommit>
  <maxTime>15000</maxTime>         <!-- durabilidade ~15s -->
  <maxDocs>1000</maxDocs>
  <openSearcher>false</openSearcher>  <!-- hard commit NÃO abre searcher; softCommit cuida da visibilidade -->
</autoCommit>
```

Regras:
- **Nunca commit por documento** em produção (thrash de searcher, GC pressure). Use
  `autoCommit`/`autoSoftCommit` ou `commitWithin` no request de update.
- Bulk: `commitWithin=<ms>` no add em vez de `commit=true` por lote.
- `RealTimeGet` (`/get?id=...`) lê docs não commitados (por `id`) sem esperar o soft commit.
- `openSearcher=false` no hard commit evita abrir searcher redundante quando o soft já abre.
- `optimize`/forceMerge só em janela de manutenção — reescreve todo o índice.
- `ramBufferSizeMB` (default 100) e `TieredMergePolicy` controlam segment flush/merge.

---

## 5. SolrCloud + ZooKeeper

**SolrCloud obrigatório em produção** (nunca standalone — ADR-012).

### ZooKeeper ensemble
- Ensemble **ímpar** de 3 ou 5 nós (quórum = maioria; 3 tolera 1 falha, 5 tolera 2).
- Chroot dedicado: `ZK_HOST="zk1:2181,zk2:2181,zk3:2181/solr"`.
- Config sets versionados em Git, publicados via `bin/solr zk upconfig` — **nunca** Admin UI em produção.
- ZK guarda estado do cluster (`clusterstate`), configs e leader election; não é armazenamento de dados.

### Sharding
- Nº de shards = função do **volume/throughput de indexação** e paralelismo de query. Fixado na
  criação; crescer depois exige `SPLITSHARD` (compositeId permite split; implicit não).
- Dimensione por doc count/tamanho do índice por shard, não por RAM total.

### Replicação e tipos de réplica (Solr 9)

| Tipo | Indexa localmente | Serve query | Uso |
|------|-------------------|-------------|-----|
| **NRT** (default) | sim | sim | NRT real, writes moderados. Qualquer réplica pode virar leader |
| **TLOG** | via transaction log (replica do leader) | sim | Alta indexação; réplicas não re-indexam, replicam segmentos |
| **PULL** | não | sim | Escala de leitura pura; nunca vira leader |

- `replicationFactor ≥ 2` (HA N+1). Combos comuns: NRT+NRT (NRT verdadeiro) ou TLOG+PULL (write-heavy).
- Distribuir réplicas por rack/AZ (autoscaling/replica placement policies).

### Document routing
- **compositeId** (default): hash do `id` → shard. Prefixo `tenant!id` co-loca todos os docs
  de um tenant no mesmo shard (`_route_=tenant!` na query evita fan-out). Suporta SPLITSHARD.
- **implicit**: você controla o shard via campo `_route_`/`router.field` — sem rebalanceamento automático.
- Co-locar dados relacionados melhora join e reduz latência multi-shard.

### Multi-tenancy (ADR-012)
- **Collection-per-tenant**: isolamento forte (schema/config/segurança por tenant); custo de gestão.
- **Alias-per-tenant** ou routing por prefixo: isolamento suave, menos overhead.

---

## 6. Tuning de Cache

Solr 9 usa `CaffeineCache` por padrão. Ajuste por workload e **monitore hit ratio** no
Admin UI / `admin/mbeans?cat=CACHE`.

| Cache | O que guarda | Sizing | Autowarm |
|-------|--------------|--------|----------|
| `filterCache` | resultado de cada `fq` (bitset) | grande se muitos `fq` reutilizados | `autowarmCount` alto — filtros repetem |
| `queryResultCache` | ordenação de resultados por (q, sort, fq) | médio | moderado |
| `documentCache` | campos `stored` de docs | ~ (rows × maxConcurrent) | 0 (não warmável) |
| `fieldValueCache` | fielddata p/ facet em multiValued | conforme facet | — |

```xml
<filterCache class="solr.CaffeineCache" size="512" initialSize="512" autowarmCount="128"/>
<queryResultCache class="solr.CaffeineCache" size="512" initialSize="512" autowarmCount="32"/>
<documentCache class="solr.CaffeineCache" size="512" initialSize="512" autowarmCount="0"/>
```

Diretrizes:
- **filterCache** é o de maior ROI (filtros de negócio repetem) — daí a regra `fq` > filtro no `q`.
- `autowarmCount` alto reduz cold cache após commit, mas **cada soft commit re-aquece** — não
  combine autowarm agressivo com soft commit sub-segundo (custo de warming a cada 1s).
- `maxWarmingSearchers=2` e `useColdSearcher` conforme latência aceitável no primeiro request.
- `docValues=true` reduz dependência de fielddata/heap para facet/sort.
- JVM: heap 50-70% da RAM (máx ~26-31GB p/ compressed oops), `G1GC`. Deixe RAM p/ page cache do OS
  (Lucene depende do file system cache). Ver `stack.md`.

---

## 7. Segurança

**Nunca rodar Solr aberto** (ADR-012). `security.json` no ZooKeeper: autenticação + autorização.

```json
{
  "authentication": {
    "class": "solr.BasicAuthPlugin",
    "blockUnknown": true,
    "credentials": { "admin": "<hash-sha256+salt>" }
  },
  "authorization": {
    "class": "solr.RuleBasedAuthorizationPlugin",
    "permissions": [
      { "name": "read",         "collection": "products", "role": "app-read" },
      { "name": "update",       "collection": "products", "role": "app-write" },
      { "name": "security-edit", "role": "admin" }
    ],
    "user-role": { "admin": ["admin", "app-read", "app-write"], "svc-search": ["app-read"] }
  }
}
```

Camadas obrigatórias:
- **AuthN**: `BasicAuthPlugin` (blockUnknown) ou `JWTAuthPlugin` (Bearer/OIDC) para SSO corporativo.
- **AuthZ**: `RuleBasedAuthorizationPlugin` — role por collection, `security-edit` restrito, privilégio mínimo.
- **TLS**: `SOLR_SSL_*` (keystore/truststore) — obrigatório em produção, inclusive Solr↔ZK.
- **ZK ACL**: `digest` auth nos znodes para que só o Solr leia/escreva o `security.json` e configs.
- **Rede**: não expor `8983` publicamente; Solr atrás de gateway/VPC, sem acesso direto do cliente.
- **Audit**: audit logging plugin (ou export p/ Logstash). **Encryption at rest**: LUKS/FS-level.
- **Credenciais**: fora do código; rotação de API keys/JWT.

---

## 8. Anti-padrões

- ❌ Solr exposto sem auth/TLS.
- ❌ Standalone em produção (usar SolrCloud + ZK ensemble 3+).
- ❌ Editar `managed-schema`/`schema.xml` no nó — usar Schema API (propaga via ZK).
- ❌ Config via Admin UI em produção — config sets versionados em Git.
- ❌ Commit por documento (thrash de searcher) — `autoCommit`/`autoSoftCommit`/`commitWithin`.
- ❌ Deep paging com `start` grande — usar `cursorMark`.
- ❌ Filtro no `q` em vez de `fq` (perde `filterCache`, 5-20x mais lento).
- ❌ Campo `string` para busca textual (sem tokenização/stemming) — usar `text_*`.
- ❌ `stored=true`/`fl=*` em tudo (banda e I/O) — retornar só o necessário.
- ❌ `facet.mincount` ausente (buckets vazios, ruído).
- ❌ Réplica única (usar `replicationFactor ≥ 2`).
- ❌ Autowarm agressivo com soft commit sub-segundo (re-warming constante).

## Cross-references

- `elasticsearch-expert` — alternativa de search engine (ADR-012); Solr para faceting complexo/multi-tenant.
- `mongodb-expert` — fonte de verdade documental (Solr não é banco primário).
- Skills de backend (java/python/node/go) — clients e camada de aplicação.
