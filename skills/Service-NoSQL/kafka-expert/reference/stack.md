# Kafka Expert — Stack e Referência Técnica

## Versões

| Versão | Status | Notas |
|--------|--------|-------|
| Kafka **4.0** | **Mais recente** | KRaft obrigatório (ZooKeeper removido), Java 17 mínimo |
| Kafka **3.9** | **LTS recomendado** | KRaft estável, ZooKeeper ainda suportado |
| Kafka 3.7 | Mantido | — |
| Confluent Platform 7.9 | LTS (enterprise) | Kafka 3.9 + Schema Registry + Control Center |

> **Regra**: novos clusters usam **KRaft mode** (sem ZooKeeper). ZooKeeper foi removido em 4.0.
> Confluent Platform é o wrapper enterprise com Schema Registry, ksqlDB e Control Center.

---

## Docker Images

```yaml
# docker-compose.yml — Kafka KRaft single-node (dev)
version: "3.9"
services:
  kafka:
    image: apache/kafka:3.9.0          # oficial Apache, KRaft nativo
    # Alternativa: confluentinc/cp-kafka:7.9.0
    container_name: kafka
    ports:
      - "9092:9092"    # clientes externos
      - "9093:9093"    # controller KRaft (interno)
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "false"    # nunca em produção
    volumes:
      - kafka_data:/var/lib/kafka/data
    healthcheck:
      test: ["CMD", "kafka-topics.sh", "--list", "--bootstrap-server", "localhost:9092"]
      interval: 10s
      timeout: 5s
      retries: 5

  schema-registry:
    image: confluentinc/cp-schema-registry:7.9.0
    depends_on: [kafka]
    ports:
      - "8081:8081"
    environment:
      SCHEMA_REGISTRY_HOST_NAME: schema-registry
      SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: kafka:9092
      SCHEMA_REGISTRY_LISTENERS: http://0.0.0.0:8081

volumes:
  kafka_data:
```

---

## Clients por Linguagem

| Linguagem | Library | Versão | Install |
|----------|---------|--------|---------|
| **Go** | `kafka-go` (segmentio) | `v0.4.x` | `go get github.com/segmentio/kafka-go` |
| **Go** | `confluent-kafka-go` | `v2.x` | `go get github.com/confluentinc/confluent-kafka-go/v2` (requer librdkafka) |
| **Python** | `confluent-kafka` | `2.x` | `pip install confluent-kafka` |
| **Python** | `kafka-python` | `2.x` | `pip install kafka-python` (pure Python, mais lento) |
| **Java** | Spring Kafka | `3.x` | `spring-kafka` + `spring-boot-starter` |
| **Java** | kafka-clients | `4.0.x` | `org.apache.kafka:kafka-clients:4.0.0` |
| **Node.js** | `kafkajs` | `2.x` | `npm install kafkajs` |
| **.NET** | `Confluent.Kafka` | `2.x` | `dotnet add package Confluent.Kafka` |
| **Rust** | `rdkafka` | `0.37.x` | `cargo add rdkafka` |

---

## Portas Padrão

| Porta | Uso |
|-------|-----|
| **9092** | Clientes (PLAINTEXT) |
| **9093** | KRaft Controller (inter-cluster) |
| **9094** | Clientes com SSL/TLS |
| **9095** | Clientes com SASL_SSL |
| **8081** | Confluent Schema Registry |
| **8082** | Confluent REST Proxy |
| **8083** | Kafka Connect REST API |
| **9021** | Confluent Control Center |

---

## Propriedades do Producer — Referência Completa

| Propriedade | Padrão | Recomendado Produção | Descrição |
|------------|--------|---------------------|-----------|
| `bootstrap.servers` | — | `broker1:9092,broker2:9092,broker3:9092` | Lista de brokers |
| `acks` | `all` (desde 3.0) | `all` | 0=fire-forget, 1=leader, all=ISR |
| `enable.idempotence` | `true` (desde 3.0) | `true` | Sem duplicatas em retry |
| `retries` | `2147483647` | `2147483647` | Retry infinito (com idempotência) |
| `max.in.flight.requests.per.connection` | `5` | `5` (com idempotência) | Requests paralelos |
| `linger.ms` | `5` | `5-100` | Acumular mensagens em batch |
| `batch.size` | `16384` | `65536` (64KB) | Tamanho máximo do batch |
| `buffer.memory` | `33554432` | `67108864` (64MB) | Buffer total do producer |
| `compression.type` | `none` | `snappy` | Compressão: none/gzip/snappy/lz4/zstd |
| `request.timeout.ms` | `30000` | `30000` | Timeout por request ao broker |
| `delivery.timeout.ms` | `120000` | `120000` | Timeout total por mensagem |
| `transactional.id` | — | `<service>-<instance>` | Habilita transações (exactly-once) |
| `key.serializer` | — | `StringSerializer` / `KafkaAvroSerializer` | Serializer da key |
| `value.serializer` | — | `StringSerializer` / `KafkaAvroSerializer` | Serializer do value |

---

## Propriedades do Consumer — Referência Completa

| Propriedade | Padrão | Recomendado Produção | Descrição |
|------------|--------|---------------------|-----------|
| `bootstrap.servers` | — | `broker1:9092,...` | Lista de brokers |
| `group.id` | — | `<service>-group` | **Obrigatório** — nome do consumer group |
| `enable.auto.commit` | `true` | **`false`** | Commit manual → at-least-once |
| `auto.offset.reset` | `latest` | `earliest` ou `latest` (declarar!) | Offset inicial para grupo novo |
| `max.poll.records` | `500` | `500` | Máximo de records por poll |
| `max.poll.interval.ms` | `300000` | `300000` | Tempo máximo de processamento por poll |
| `session.timeout.ms` | `45000` | `45000` | Timeout para detecção de consumer morto |
| `heartbeat.interval.ms` | `3000` | `15000` | Frequência de heartbeat |
| `fetch.min.bytes` | `1` | `1` | Bytes mínimos por fetch (tradeoff latência/throughput) |
| `fetch.max.wait.ms` | `500` | `500` | Espera máxima por fetch.min.bytes |
| `isolation.level` | `read_uncommitted` | `read_committed` | Com transações no producer |
| `partition.assignment.strategy` | `RangeAssignor` | `CooperativeStickyAssignor` | Evita stop-the-world rebalance |
| `key.deserializer` | — | `StringDeserializer` / `KafkaAvroDeserializer` | Deserializer |
| `value.deserializer` | — | `StringDeserializer` / `KafkaAvroDeserializer` | Deserializer |

---

## Configurações do Topic — Referência

| Configuração | Padrão Broker | Recomendado | Descrição |
|-------------|--------------|-------------|-----------|
| `replication.factor` | 1 | **3** | Número de réplicas |
| `min.insync.replicas` | 1 | **2** | Réplicas mínimas para aceitar escrita |
| `retention.ms` | `604800000` (7d) | Conforme negócio | Tempo de retenção |
| `retention.bytes` | -1 (sem limite) | Conforme disco | Tamanho máximo por partição |
| `cleanup.policy` | `delete` | `delete` ou `compact` | Política de retenção |
| `compression.type` | `producer` | `snappy` | Compressão |
| `segment.ms` | `604800000` | — | Frequência de roll do segment |
| `segment.bytes` | `1073741824` (1GB) | — | Tamanho máximo do segment |
| `max.message.bytes` | `1048588` (~1MB) | `1048576` | Tamanho máximo de mensagem |
| `delete.retention.ms` | `86400000` (24h) | — | Tempo de retenção de tombstones (compact) |

---

## Configuração de Broker (server.properties) — Produção

```properties
# /etc/kafka/server.properties — broker produção KRaft

## KRaft
node.id=1
process.roles=broker,controller
controller.quorum.voters=1@broker1:9093,2@broker2:9093,3@broker3:9093

## Listeners
listeners=PLAINTEXT://:9092,CONTROLLER://:9093,SSL://:9094
advertised.listeners=PLAINTEXT://broker1.example.com:9092,SSL://broker1.example.com:9094
listener.security.protocol.map=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT,SSL:SSL
inter.broker.listener.name=PLAINTEXT
controller.listener.names=CONTROLLER

## Replicação
default.replication.factor=3
min.insync.replicas=2
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2

## Retenção padrão
log.retention.hours=168          # 7 dias
log.retention.check.interval.ms=300000
log.segment.bytes=1073741824     # 1GB

## Performance
num.network.threads=8
num.io.threads=16
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
num.partitions=6                 # default por topic (ajustar por cluster)

## Limites
message.max.bytes=1048576
auto.create.topics.enable=false  # NUNCA em produção

## Logs
log.dirs=/var/kafka/data
```

---

## KRaft — Setup de Cluster (sem ZooKeeper)

```bash
# Gerar cluster UUID único (uma vez por cluster)
KAFKA_CLUSTER_ID=$(kafka-storage.sh random-uuid)

# Formatar storage em cada broker
kafka-storage.sh format \
  --config /etc/kafka/server.properties \
  --cluster-id $KAFKA_CLUSTER_ID

# Iniciar broker
kafka-server-start.sh /etc/kafka/server.properties
```

---

## SSL/SASL — Segurança

```properties
# server.properties — SSL
ssl.keystore.location=/var/ssl/kafka.server.keystore.jks
ssl.keystore.password=keystorepass
ssl.key.password=keypass
ssl.truststore.location=/var/ssl/kafka.server.truststore.jks
ssl.truststore.password=truststorepass
ssl.client.auth=required          # mTLS: required | requested | none

# SASL SCRAM-SHA-512 (mais seguro que PLAIN)
sasl.enabled.mechanisms=SCRAM-SHA-512
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512

# Client (producer/consumer)
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="app-user" password="app-password";
ssl.truststore.location=/var/ssl/client.truststore.jks
ssl.truststore.password=truststorepass
```

---

## CLI — Referência Completa

```bash
# Topics
kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --topic my-topic --partitions 6 --replication-factor 3 \
  --config retention.ms=604800000 --config min.insync.replicas=2

kafka-topics.sh --bootstrap-server localhost:9092 --list
kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic my-topic
kafka-topics.sh --bootstrap-server localhost:9092 \
  --alter --topic my-topic --partitions 12           # só aumentar, nunca diminuir

# Configurar topic
kafka-configs.sh --bootstrap-server localhost:9092 \
  --entity-type topics --entity-name my-topic \
  --alter --add-config retention.ms=86400000

# Producer (teste)
kafka-console-producer.sh --bootstrap-server localhost:9092 \
  --topic my-topic --property "key.separator=:" --property "parse.key=true"

# Consumer (teste)
kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic my-topic --from-beginning --group test-group \
  --property "print.key=true" --property "print.timestamp=true"

# Consumer Groups
kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group my-consumer-group
# LAG: coluna LAG = offset atual - committed offset

# Reset offset (cuidado em produção!)
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --group my-consumer-group --topic my-topic \
  --reset-offsets --to-earliest --execute

# Verificar lag de todos os grupos
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --all-groups | grep -v "^$" | sort -k6 -n -r | head -20

# Log compaction trigger manual
kafka-log-dirs.sh --bootstrap-server localhost:9092 --describe --topic-list my-topic
```

---

## Schema Registry — API e Uso

```bash
# Listar schemas
GET http://schema-registry:8081/subjects

# Registrar schema Avro
POST http://schema-registry:8081/subjects/orders.created-value/versions
Content-Type: application/vnd.schemaregistry.v1+json
{
  "schema": "{\"type\":\"record\",\"name\":\"OrderCreated\",\"fields\":[{\"name\":\"orderId\",\"type\":\"string\"},{\"name\":\"amount\",\"type\":\"double\"}]}"
}

# Verificar compatibilidade
POST http://schema-registry:8081/compatibility/subjects/orders.created-value/versions/latest
Content-Type: application/vnd.schemaregistry.v1+json
{ "schema": "... novo schema ..." }

# Configurar compatibilidade (BACKWARD = consumers antigos leem schemas novos)
PUT http://schema-registry:8081/config/orders.created-value
{ "compatibility": "BACKWARD" }
# Níveis: BACKWARD | FORWARD | FULL | NONE
```

---

## Métricas JMX e Alertas

### Métricas Chave do Broker

| MBean | Métrica | Alerta |
|-------|---------|--------|
| `kafka.server:type=BrokerTopicMetrics,name=MessagesInPerSec` | Taxa de ingestão | Spike anormal |
| `kafka.server:type=ReplicaManager,name=UnderReplicatedPartitions` | Partições sub-replicadas | > 0 por > 1min |
| `kafka.server:type=ReplicaManager,name=LeaderCount` | Líderes por broker | Desbalanceado |
| `kafka.controller:type=KafkaController,name=ActiveControllerCount` | Controladores ativos | ≠ 1 |
| `kafka.network:type=RequestMetrics,name=TotalTimeMs` | Latência de request | P99 > threshold |

### Consumer Lag (crítico)

```bash
# Prometheus JMX Exporter + alert rule
# kafka_consumer_group_lag{topic="orders.created",group="payments-service"}

- alert: KafkaConsumerLagCritical
  expr: kafka_consumer_group_lag > 10000
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Consumer group {{ $labels.group }} lag {{ $value }} no topic {{ $labels.topic }}"

- alert: KafkaUnderReplicatedPartitions
  expr: kafka_server_replica_manager_under_replicated_partitions > 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "{{ $value }} partições sub-replicadas em {{ $labels.instance }}"

- alert: KafkaNoActiveController
  expr: kafka_controller_kafka_controller_active_controller_count != 1
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Kafka sem controlador ativo"
```

### Prometheus JMX Exporter

```yaml
# jmx-exporter.yml — configuração mínima para Kafka
startDelaySeconds: 0
ssl: false
lowercaseOutputName: true
lowercaseOutputLabelNames: true
whitelistObjectNames:
  - "kafka.server:*"
  - "kafka.controller:*"
  - "kafka.network:*"
  - "kafka.log:*"
  - "kafka.consumer:*"
  - "kafka.producer:*"
```
