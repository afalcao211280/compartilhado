# Elasticsearch Expert — Stack Canônica

## Elasticsearch 8.x — Versão Canônica EVEO

| Categoria | Lib/Ferramenta | Versão | Link | Notas |
|-----------|---------------|--------|------|-------|
| **Core** | | | | |
| Search Engine | Elasticsearch | 8.x | https://elastic.co/elasticsearch | 8.x: security by default |
| Stack | ELK Stack | 8.x | https://elastic.co/elastic-stack | Elasticsearch + Logstash + Kibana |
| Cloud | Elastic Cloud | — | https://cloud.elastic.co | Managed. Alternativa: AWS OpenSearch |
| Alternativa | OpenSearch | 2.x | https://opensearch.org | Fork Apache 2.0 do ES 7.10 |
| **Clientes** | | | | |
| Cliente (Node/TS) | @elastic/elasticsearch | 8.x | https://github.com/elastic/elasticsearch-js | TypeScript nativo |
| Cliente (Python) | elasticsearch-py | 8.x | https://elasticsearch-py.readthedocs.io | Async: `AsyncElasticsearch` |
| Cliente (Java) | Elasticsearch Java Client | 8.x | https://elastic.co/guide/en/elasticsearch/client/java-api-client | Substitui RestHighLevelClient |
| Cliente (.NET) | Elastic.Clients.Elasticsearch | 8.x | https://github.com/elastic/elasticsearch-net | Nova API typesafe |
| Cliente (Go) | go-elasticsearch | 8.x | https://github.com/elastic/go-elasticsearch | Oficial |
| **Integrações** | | | | |
| Spring | Spring Data Elasticsearch | 5.x | https://spring.io/projects/spring-data-elasticsearch | `@Document`, `ElasticsearchRepository` |
| NestJS | @nestjs/elasticsearch | 10.x | https://github.com/nestjs/elasticsearch | Wrapper do cliente oficial |
| **Indexação / Sync** | | | | |
| CDC (Postgres) | Logstash JDBC Input | built-in | — | `jdbc_streaming` para sync periódico |
| CDC (Kafka) | Kafka Elasticsearch Connector | — | https://docs.confluent.io | Sink connector |
| CDC moderno | Debezium → Kafka → ES | — | https://debezium.io | Event-driven sync |
| **Monitoramento** | | | | |
| Kibana | Kibana Stack Monitoring | built-in | — | Cluster health, índices, nodes |
| API | `_cluster/health`, `_cat/indices` | built-in | — | REST API nativa |
| **Segurança** | | | | |
| Auth | X-Pack Security (built-in 8.x) | built-in | — | TLS obrigatório por padrão |
| API Keys | Elasticsearch API Keys | built-in | — | Para acesso programático |

## elasticsearch.yml — Configuração Essencial

```yaml
cluster.name: eveo-cluster
node.name: node-1

# Paths
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch

# Network — nunca 0.0.0.0 em produção sem TLS
network.host: 127.0.0.1

# Memory lock — evitar swap
bootstrap.memory_lock: true

# Security (obrigatório no 8.x)
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true

# JVM Heap — em jvm.options: -Xms e -Xmx = 50% da RAM, máximo 26-30GB
# Não configurar aqui, usar jvm.options

# Index settings padrão para novos índices
index:
  number_of_shards: 1       # Para clusters < 5 nodes. Aumentar para datasets > 50GB
  number_of_replicas: 1     # Para HA. 0 em dev single-node
  refresh_interval: "1s"    # Aumentar para "30s" em indexação em bulk
```
