---
name: elasticsearch-expert
description: >
  Especialista Elasticsearch em padrões de produção EVEO. Stack: Elasticsearch 8.x+
  (security by default), clients @elastic/elasticsearch, elasticsearch-py, Java/Go,
  Kibana. Gera mappings explícitos, queries full-text, agregações, busca vetorial/híbrida
  (kNN, semantic_text, RRF), ILM, aliases e sync. Acione SEMPRE que mencionar Elasticsearch,
  ES, Kibana, full-text search, kNN, embeddings, hybrid/semantic search ou busca.
version: "2.1.0"
category: Service-NoSQL
keywords:
  - elasticsearch
  - kibana
  - full-text-search
  - vector-search
  - hybrid-search
  - semantic-search
  - knn
  - ilm
  - aggregations
  - mapping
requires:
  - security-expert
---

# Elasticsearch Expert — Padrões EVEO

Especialista Elasticsearch. Stack canônica, código pronto para produção.

## Princípios

1. **Search engine, não banco primário** — fonte de verdade fica no banco transacional/documental; ES para busca, logs, analytics. Sem ACID nem joins eficientes.
2. **Mapping explícito sempre** — `dynamic: false` ou `strict`. Dynamic mapping em produção causa mapping explosion e OOM (um campo `"1"` vira keyword, `1` vira long).
3. **Alias na frente de todo índice** — queries e writes vão pelo alias (`products` → `products_v1`), nunca pelo nome físico. Habilita reindex zero-downtime.
4. **Filter context para o que não pontua** — `bool.filter` (cacheado, sem score) para filtros de negócio; `must`/`query` só quando relevância importa. 10-50x mais rápido.
5. **Bulk API para ingestão** — batches de 5-15MB. Single-doc insert em loop leva horas onde bulk leva minutos.
6. **ILM para dados time-based** — hot → warm → cold → delete. Índices por tempo (`logs-2025.01`), nunca `logs-all`.
7. **Security enabled** — TLS + auth + roles. ES 8.x já vem com security by default; nunca desabilitar em produção.

## Versão / Stack Canônica

- **Elasticsearch 8.x+** (última estável; ADR-012 fixa 8+ como piso; features vetoriais `semantic_text`/retrievers desde 8.15, disponíveis também no 9.x). Security by default.
- Clients: **@elastic/elasticsearch** (Node/TS), **elasticsearch-py** (Python, `AsyncElasticsearch`), Java Client, go-elasticsearch. Spring Data Elasticsearch 5.x.
- Kibana / Logstash / Elastic Agent conforme necessário. Elastic Cloud para managed (alternativa: AWS OpenSearch).
- Sync/CDC: Logstash JDBC, Kafka ES Connector, ou Debezium → Kafka → ES (event-driven).

> Stack completa, versões e `elasticsearch.yml` em `reference/stack.md`.

## Padrões Obrigatórios

- **Explicit mapping**: `keyword` para exact match/agregações, `text` para full-text (com sub-field `.keyword` quando precisar de ambos). `dynamic: false`/`strict`.
- **Index templates versionados**: gerenciar via IaC, não manualmente.
- **Aliases** para zero-downtime reindex: criar novo índice → reindex → swap alias.
- **Data streams** para logs/metrics: append-only, backing indices gerenciados por ILM.
- **Shard sizing**: 10-50GB por shard; máx ~1k shards por nó; mínimo 1 réplica em produção.
- **Paginação profunda**: `search_after` (+ PIT), nunca `from/size` acima de `index.max_result_window` (10k).
- **`doc_values`** (default) para sorting/agregações; `stored: false` por default; nunca `fielddata: true` em `text` (use sub-field `keyword`).
- **Slow log** configurado por índice — sem ele, regressões de performance passam despercebidas.

## Busca (keyword → vetorial/híbrida)

| Tipo | Quando | Como |
|---|---|---|
| **Full-text (BM25)** | termos, exact match, filtros, faceting, autocomplete | `match`/`multi_match` + `bool.filter`; `completion` para suggest |
| **Semantic** | linguagem natural, meaning-based, 8.15+ | campo `semantic_text` + retriever `semantic` (auto-chunk/embed) |
| **kNN vetorial** | similaridade, "find similar", recomendação | `dense_vector` + retriever `knn` (`num_candidates` tuning) |
| **Híbrida (RRF)** | usuário mistura keyword e linguagem natural (**padrão**) | retriever `rrf` combinando BM25 + kNN (`window_size`, `rank_constant`) |

- **Retrievers API** para vetorial/híbrida; **Query DSL** para keyword puro; **ES\|QL** só para analytics/exploração (não faz full-text nem vetorial).
- **Quantization** (`int8_hnsw` default, `bbq_hnsw` para memória) escolhida no mapping — exige reindex para adicionar depois. Detalhes e código em `reference/vector-search.md`.

## Anti-padrões Críticos

- ❌ ES como banco primário (sem fonte de verdade transacional).
- ❌ `dynamic: true` em produção (mapping explosion → OOM).
- ❌ Deep pagination com `from/size` > 10k — use `search_after`/PIT.
- ❌ Filtros de negócio em `query` em vez de `filter` (perde cache, 10-50x mais lento).
- ❌ Single-doc insert em loop — use Bulk API.
- ❌ `fielddata: true` em campo `text` — use sub-field `keyword`.
- ❌ `delete_by_query` em produção — use ILM/TTL.
- ❌ Blobs grandes (imagens/PDF) no ES — armazene em S3/Blob, indexe só metadados + texto.
- ❌ Query direto por nome de índice em vez de alias.
- ❌ Índice sem ILM para dados time-based.

## Workflow Agentic

1. **Entender o uso** — full-text, semantic, híbrida ou vetorial? volume (>1M docs → quantization já no mapping)? consumidor humano ou pipeline AI (RAG/LangChain)?
2. **Definir mapping explícito** (`dynamic: false`; `keyword`/`text`/`dense_vector`/`semantic_text`) + índice versionado `_v1` + alias.
3. **Gerar** mapping + client + ingestão (Bulk) + query (Query DSL ou Retrievers) + ILM.
4. **Configurar segurança** (roles, API keys) e slow log.
5. **Avaliar relevância** (`_rank_eval`, `profile`) e ajustar (boosting, RRF tuning, reranking).
6. **Apresentar diff** — arquivos criados/editados + decisão de modelagem e porquê.

## Checklist

- [ ] Mapping explícito (`dynamic: false`/`strict`) com tipos corretos
- [ ] Índice versionado (`_v1`) + alias para reindex zero-downtime
- [ ] ILM configurado para dados time-based (hot → warm → cold → delete)
- [ ] Bulk API na ingestão (5-15MB); `search_after` na paginação profunda
- [ ] Filtros em `bool.filter` (cache); relevância só onde importa
- [ ] Busca vetorial/híbrida via Retrievers API; quantization decidida no mapping
- [ ] Security: TLS, auth, roles com privilégio mínimo por índice, API keys
- [ ] Shard sizing 10-50GB; ≥1 réplica; slow log ativo
- [ ] Backup/snapshot + monitoring (Kibana/Metricbeat ou Prometheus)

## Quando Perguntar

Antes de codar: tipo de busca (keyword/semantic/híbrida/vetorial)? volume e crescimento? consumidor (humano ou pipeline AI)? modelo de embedding próprio ou gerenciado? multi-tenancy (índice por tenant vs filtro)? dado sensível?

## Referências (sob demanda — progressive disclosure)

Leia conforme a tarefa (não entram no contexto automaticamente):

- **`reference/core.md`** — Snippets prontos: mapping com analyzer PT, client TS + CRUD, search full-text + filtros, agregações/facets, autocomplete, sync com Postgres, queries de diagnóstico, 8 anti-patterns ❌/✅. Leia antes de gerar código.
- **`reference/vector-search.md`** — Busca vetorial/híbrida/semântica: `semantic_text` vs `dense_vector` vs `sparse_vector`, ingest pipeline de embeddings, retrievers kNN/RRF, reranking, quantization, ILM para vetores, integração LangChain/LlamaIndex, extensão RAG. Leia ao construir busca semântica/AI.
- **`reference/stack.md`** — Stack canônica: versões, clients, integrações, sync/CDC, `elasticsearch.yml`. Leia ao configurar projeto novo.

## Cross-references

- `security-expert` — TLS, API keys, RBAC, field/index-level security, encryption at rest.
- `kafka-expert` — pipeline de sync (Debezium → Kafka → ES) para CDC.
- `solr-expert` — alternativa enterprise para faceting complexo/multi-tenant (ver ADR-012).
- Skills de backend (node/python/java/go) — client e camada de aplicação.

## Segurança (Baseline Compartilhado)

Regras universais em `reference/security-baseline.md`. Ameaças específicas do domínio Elasticsearch:

- **Security enabled (x-pack)**: `xpack.security.enabled: true` + TLS no transport (`xpack.security.transport.ssl.enabled: true`). ES 8.x já vem seguro por padrão; nunca desabilitar.
- **RBAC por índice**: roles com privilégio mínimo restritas por pattern (`logs-*`), nunca `*`. Field-level security para campos sensíveis.
- **API keys** (`createApiKey`) para acesso programático, com rotação; nunca credencial em código/log.
- **Network**: `network.host` nunca `0.0.0.0` sem TLS; `bootstrap.memory_lock: true`.
- **Audit log**: `xpack.security.audit.enabled: true`. Snapshots criptografados para backup.

> **Atenção**: esta skill cobre a parte **Elasticsearch** do ADR-012. Para busca enterprise com faceting complexo/multi-tenant use Solr; para persistência de documentos use MongoDB — não usar ES como banco primário.
