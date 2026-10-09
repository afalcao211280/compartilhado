---
name: solr-expert
description: >
  Especialista em Apache Solr seguindo padrões de produção. Use SEMPRE que
  houver menção a Solr, search engine Java, Lucene, SolrCloud, ou quando o
  contexto for busca com Solr. Stack: Solr 9+, SolrCloud, ZooKeeper, Lucene.
  Complementar às skills de backend.
version: "2.1.1"
category: Service-NoSQL
keywords:
  - solr
  - lucene
  - solrcloud
  - search
  - zookeeper
  - indexing
requires: ['security-expert']
---

# Solr Expert

## Princípio Central

Solr — search engine enterprise, Lucene-based. Como Elasticsearch, não é banco transacional. Use para busca, faceting, analytics sobre texto.

## Versão

- Solr 9+
- SolrCloud para production (nunca standalone)
- ZooKeeper 3.8+ (ou Solr embarcado ZK para dev)

## Padrões Obrigatórios

- **Explicit schema**: definir field types e fields — não depender de dynamic fields descontrolados
- Managed schema: use schema API, não edite `managed-schema` manualmente
- SolrCloud para production: collection > core, distributed
- Collections com replication factor ≥ 2: HA com N+1 replicas
- Config sets versionados: gerencie em Git, deploy via ZK CLI
- ZooKeeper ensemble: 3+ nodes para quórum
- Commit strategy explícito: `softCommit` para near-real-time, `hardCommit` para durability
- Document routing: `router.field` ou compositeId para colocalidade

## Performance

- Schema field types corretos: `string` para exact match, `text_general` para full-text
- `stored=false` para fields não retrieval: economiza disk e I/O
- `docValues=true` para faceting, sorting, grouping: columnar, heap-efficient
- Filter queries (`fq`) para cache: separar filters de queries de scoring
- Result caching: `queryResultCache`, `documentCache` — ajuste sizes por workload
- Shard requests em paralelo: `shards.qt` e `shards.info`
- JVM tuning: `-Xmx` 50-70% da RAM, G1GC para heaps >32GB
- `autoSoftCommit`: 1-10s para NRT, `autoCommit`: 15-60s para durability

## Security

- Authentication plugin: Basic ou Bearer (JWT)
- SSL/TLS: `SOLR_SSL_*` env vars, obrigatório em production
- Rule-based authorization: `security.json` com permissions por collection
- Audit logging: Solr audit plugin ou external (Logstash)
- Encryption at rest: filesystem-level (LUKS) ou Solr transparent encryption
- ZooKeeper ACL: `digest` auth para ZK nodes
- API key management:Solr API keys ou JWT tokens com rotação

## Patterns

- **Collection-per-tenant** para isolamento forte; **alias-per-tenant** para isolation suave
- **Nested documents** para dados related 1:few:(child doc dentro do parent)
- **Join queries**: limitadas, use apenas quando necessário — não escala bem
- **Faceting** para navigation: `facet.field`, `facet.range`, `facet.pivot`
- **Spellcheck + Suggest** para UX: `spellcheck.collate`, `suggest.build`
- **Near-real-time**: `autoSoftCommit=1s` + RealTimeGet para baja latência

## Anti-padrões

- **No** wildcard queries em campos grandes: `*:*` ou prefix wildcard `field:*` — full scan
- **No** deep pagination: usar `cursorMark` em vez de `start=100000`
- **No** `stored=true` para fields não retrieval: desperdício de disk
- **No** replica única em production: replication factor ≥ 2
- **No** commits dentro de loops: usar `autoCommit` ou commit batch
- **No** schema dinâmico sem versionamento: `dynamicField` é escape, não regra

## Checklist

Para cada collection/config, verifique:

- [ ] Schema explícito com field types corretos
- [ ] SolrCloud configurado (ZK ensemble 3+, replication factor ≥ 2)
- [ ] Config sets versionados em Git
- [ ] Backups configurados (incremental + full)
- [ ] Monitoring: Solr metrics + Prometheus/Grafana
- [ ] JVM tuning: heap size e GC configurados
- [ ] Security plugin habilitado (auth + authz + TLS)

## Boas Práticas (referência)

- `reference/best-practices.md` — checklist Solr 9+ (schema, query fq/edismax, commit, SolrCloud). Leia ao gerar/revisar código.

## Seguranca (Baseline Compartilhado)
- `reference/security-baseline.md` — Regras universais de seguranca (OWASP, secrets, headers, TLS)

