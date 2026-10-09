# Solr Expert — Stack Canônica

## Apache Solr 9.x — Versão Canônica EVEO

| Categoria | Lib/Ferramenta | Versão | Link | Notas |
|-----------|---------------|--------|------|-------|
| **Core** | | | | |
| Search Platform | Apache Solr | 9.x | https://solr.apache.org | Java-based. Mature, enterprise-grade |
| Distribuição | SolrCloud | built-in | — | Modo distribuído com ZooKeeper |
| ZooKeeper | Apache ZooKeeper | 3.8+ | https://zookeeper.apache.org | Coordenação do SolrCloud |
| **Clientes** | | | | |
| Cliente (Java) | SolrJ | 9.x | https://solr.apache.org/guide/solr/latest/deployment-guide/solrj.html | Official Java client |
| Cliente (Node/TS) | solr-client | 1.x | https://github.com/lbdremy/solr-node-client | Alternativa: `solr-node` |
| Cliente (Python) | pysolr | 3.10+ | https://github.com/django-haystack/pysolr | |
| Cliente (Python) alt | SolrClient | 0.2+ | https://github.com/moonlitesolutions/SolrClient | Async via Tornado |
| Framework (Python) | Django Haystack | 3.x | https://django-haystack.readthedocs.io | ORM-like para Solr/Elasticsearch |
| **Spring** | | | | |
| Spring Data Solr | Spring Data Solr | (deprecated) | — | Use SolrJ diretamente em Spring Boot 3.x |
| **Indexação** | | | | |
| DataImportHandler | DIH (deprecated no 9.x) | — | — | Substituir por Solr Cell ou custom |
| Tika | Apache Tika (via Solr Cell) | 2.x | https://tika.apache.org | Extração de texto de PDFs, docs |
| Kafka | Kafka Solr Connector | — | — | Via Solr REST API ou SolrJ |
| **Monitoramento** | | | | |
| Admin UI | Solr Admin | built-in | `/solr/#/` | Análise de queries, schema, logs |
| Metrics | Prometheus Exporter | built-in 9.x | — | `solr/admin/metrics?wt=json` |
| JMX | JMX via Solr | built-in | — | Para integração com Grafana/Prometheus |
| **Schema** | | | | |
| Schema Mode | Managed Schema | padrão | — | Alterações via Schema API, não editar XML manualmente |
| Alternativa | schema.xml | legacy | — | Edição manual. Não recomendado para novos projetos |
| **Segurança** | | | | |
| Auth | Basic Auth + Rule-Based Auth | built-in | — | Configurar `security.json` no ZooKeeper |
| TLS | HTTPS/TLS | built-in | — | Obrigatório em produção |

## solr.in.sh / solr.in.cmd — JVM Essencial

```bash
# Heap size — regra: 50% da RAM, máximo 26-30GB
SOLR_HEAP="2g"

# GC tuning — G1GC padrão no Java 17+
GC_TUNE="-XX:+UseG1GC -XX:+PerfDisableSharedMem -XX:+ParallelRefProcEnabled \
  -XX:MaxGCPauseMillis=250 -XX:+UseLargePages"

# Enable JMX para monitoramento
ENABLE_REMOTE_JMX_OPTS="false"  # true em ambiente monitorado

# ZooKeeper (SolrCloud)
ZK_HOST="zk1:2181,zk2:2181,zk3:2181/solr"
```

## solrconfig.xml — Configurações de Cache

```xml
<!-- Cache configs no solrconfig.xml -->
<filterCache size="512" initialSize="512" autowarmCount="128"/>
<queryResultCache size="512" initialSize="512" autowarmCount="32"/>
<documentCache size="512" initialSize="512" autowarmCount="0"/>

<!-- Query result window size — pré-carregar docs adjacentes -->
<queryResultWindowSize>20</queryResultWindowSize>
<queryResultMaxDocsCached>200</queryResultMaxDocsCached>

<!-- Soft commit para near-realtime search -->
<autoSoftCommit>
  <maxTime>1000</maxTime>
</autoSoftCommit>

<!-- Hard commit -->
<autoCommit>
  <maxTime>15000</maxTime>
  <maxDocs>1000</maxDocs>
  <openSearcher>false</openSearcher>
</autoCommit>
```
