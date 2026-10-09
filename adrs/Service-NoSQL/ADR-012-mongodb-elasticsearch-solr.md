# ADR-012: MongoDB + Elasticsearch + Solr — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Projetos na EVEO frequentemente necessitam de banco de documentos (MongoDB), busca full-text (Elasticsearch) e/ou busca enterprise (Solr). A ausência de padronização resulta em schema design inconsistente, índices ausentes, e configuração de pooling/replica subótima. Este ADR define as decisões para cada tecnologia e quando usar cada uma.

## Decisão

**MongoDB 7+**: banco de documentos para dados semi-estruturados e APIs JSON-native. Schema validation obrigatória em produção. Atlas para managed. Mongoose (Node) ou mongo-driver (Go).

**Elasticsearch 8+**: search engine para busca full-text, logs, e analytics. Security enabled by default. ILM para lifecycle. Data streams para append-only.

**Solr 9+**: search engine enterprise para busca facetada, relevância tuning, e multi-tenant. SolrCloud obrigatório em produção. Schema explícito com field types definidos.

Cada tecnologia tem seu domínio: MongoDB para persistência de documentos, Elasticsearch para search/logging/analytics, Solr para enterprise search com faceting complexo. Não usar MongoDB como search engine nem Elasticsearch como primary database.

## Stack Canônica

| Categoria | MongoDB | Elasticsearch | Solr |
|---|---|---|---|
| Versão | 7+ | 8+ | 9+ |
| driver (Node) | Mongoose | @elastic/elasticsearch | solr-client |
| driver (Go) | mongo-driver | olivere/elastic | go-solr |
| Cloud | Atlas | Elastic Cloud | Managed SolrCloud |
| Migrations | mongouse / atlas-cli | Index templates versionados | Config sets versionados |
| Monitoramento | Atlas Insights + Prometheus | Kibana + Metricbeat | Solr metrics + Prometheus |
| Backup | Atlas snapshots / mongodump | Snapshot API / EBS snapshots | Collections API backup |
| Connection Pool | maxPoolSize configurado | Connection pool HTTP | Connection pool HTTP |

## Padrões Obrigatórios — MongoDB

- **Schema validation**: `db.createCollection()` com `validator` — nunca schemaless em produção.
  ```javascript
  db.createCollection("users", {
    validator: {
      $jsonSchema: {
        bsonType: "object",
        required: ["email", "tenantId"],
        properties: {
          email: { bsonType: "string", pattern: "^.+@.+$" },
          tenantId: { bsonType: "objectId" }
        }
      }
    }
  })
  ```
- **Embed vs Reference**:
  - Embed para 1:few (até ~100 subdocuments): user → addresses
  - Reference para 1:many/many:many: user → orders → `$lookup` ou app-level join
- **Connection pooling**: reutilize connections, configure `maxPoolSize`.
- **Read preference**: `primary`, `primaryPreferred`, `secondaryPreferred`, `nearest` — explícito por query.
- **Write concern**: `{ w: "majority" }` para durability, `{ w: 1 }` para performance (logs).
- **Transactions** apenas quando necessário. Prefer embed/reference estratégica.
- **TTL indexes** para dados temporários: sessions, logs, tokens.
- **Índices**: `explain()` obrigatório antes de criar. Compound indexes respeitando ESR rule (Equality, Sort, Range).
- **Bucket pattern** para time-series: `{ roomId, measurements: [{ts, temp, humidity}] }`.
- **Atlas** preferido para managed. Self-hosted apenas com justificativa.

## Padrões Obrigatórios — Elasticsearch

- **Explicit mapping**: definir tipos antes de indexar — `dynamic: false` ou `strict`.
- **Index templates** versionados: gerenciar via IaC, não manualmente.
- **Time-based naming** para logs/metrics: `logs-2025.01`, não `logs-all`.
- **ILM policies** para lifecycle: hot → warm → cold → delete.
- **Aliases** para zero-downtime reindex: `GET alias/_search`, não `GET index-name`.
- **Bulk API** para inserts: batch de 5-15MB. Nunca single-doc inserts em produção.
- **Replica shards**: mínimo 1 réplica em production.
- **Shard sizing**: 10-50GB por shard. Não criar indices com shards > 50GB.
- **Nested** para relacionamentos 1:few: `nested` type com `nested` queries.
- **Data streams** para logs/metrics: append-only, backing indices gerenciados.
- **Security enabled**: TLS, auth, role-based access. Nunca rodar sem security em produção.

## Padrões Obrigatórios — Solr

- **SolrCloud** obrigatório em produção. ZK ensemble 3+. Replication factor ≥ 2.
- **Schema explícito**: definir field types antes de indexar. `managed-schema` versionado.
- **Config sets** versionados em Git. Não configurar via Admin UI em produção.
- **Collection-per-tenant** para isolamento forte. **Alias-per-tenant** para isolamento suave.
- **Faceting** para navigation: `facet.field`, `facet.range`, `facet.pivot`.
- **Spellcheck + Suggest** para UX: `spellcheck.collate`, `suggest.build`.
- **Near-real-time**: `autoSoftCommit=1s` + RealTimeGet para baixa latência.
- **Bulk indexing**: DIH (DataImportHandler) ou API com commit Within. Nunca single-doc adds em produção.
- **JVM tuning**: heap size e GC configurados. Não usar defaults.
- **Security plugin** habilitado: auth + authz + TLS. Nunca rodar aberto.
- **Monitoring**: Solr metrics + Prometheus/Grafana.
- **Backup**: incremental + full. Configurar schedule.

## Anti-padrões

| MongoDB | Alternativa |
|---|---|
| Schemaless em produção | Schema validation com `$jsonSchema` |
| Unbounded arrays (embed sem limite) | Reference para >100 subdocuments |
| `explain()` ausente | `explain()` obrigatório antes de criar índice |
| Transactions para tudo | Embed/reference estratégica |
| Write concern `{ w: 1 }` para dados críticos | `{ w: "majority" }` para durability |

| Elasticsearch | Alternativa |
|---|---|
| `dynamic: true` em produção | `dynamic: false` ou `strict` |
| Single-doc inserts | Bulk API (5-15MB batches) |
| Indices sem ILM | ILM policy: hot → warm → cold → delete |
| Search direto por index name | Alias para zero-downtime reindex |
| Security desabilitado | TLS + auth + role-based |

| Solr | Alternativa |
|---|---|
| Standalone mode em produção | SolrCloud com ZK ensemble 3+ |
| Schema auto-detect | Schema explícito com field types |
| Admin UI para config | Config sets versionados em Git |
| Single-doc adds | Bulk indexing com commitWithin |
| Sem security plugin | Auth + Authz + TLS |

## Consequências

**Positivas**:
- Cada tecnologia no seu domínio: MongoDB para documentos, ES para search/logs, Solr para enterprise search
- Schema validation em MongoDB elimina dados inconsistentes
- ILM no Elasticsearch automatiza lifecycle de dados
- SolrCloud + ZK garante HA e distribuição

**Negativas**:
- Operar 3 tecnologias de dados exige expertise diversificada
- Sync entre MongoDB e ES/Solr requer pipeline (Change Streams + Kafka/Logstash)
- Custos operacionais: MongoDB Atlas + Elastic Cloud ou self-hosted com overhead

**Riscos**:
- Usar MongoDB como search engine (sem ES/Solr) — sem relevância scoring, faceting limitado
- Usar ES como primary database — sem ACID, sem joins eficientes, não é banco transacional
- Change Streams para sync MongoDB → ES pode ter lag — definir SLA aceitável
- SolrCloud requiere ZK expertise — planejar operacionalmente

## Referências

- `skills/Database-NoSQL/mongodb-expert/SKILL.md`
- `skills/Database-NoSQL/elasticsearch-expert/SKILL.md`
- `skills/Database-NoSQL/solr-expert/SKILL.md`
- Documentação MongoDB 7: https://www.mongodb.com/docs/v7.0/
- Documentação Elasticsearch 8: https://www.elastic.co/guide/en/elasticsearch/reference/current/
- Documentação Solr 9: https://solr.apache.org/guide/solr/latest/