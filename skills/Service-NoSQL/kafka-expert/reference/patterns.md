# Kafka — Padrões Canônicos de Produção

## Índice

1. [Go — kafka-go: Producer + Consumer completo](#1-go--kafka-go)
2. [Python — confluent-kafka](#2-python--confluent-kafka)
3. [Java/Spring Kafka](#3-javaspring-kafka)
4. [Node.js — KafkaJS](#4-nodejs--kafkajs)
5. [Producer Transacional — Exactly-Once](#5-producer-transacional--exactly-once)
6. [Consumer com Dead Letter Topic](#6-consumer-com-dead-letter-topic)
7. [Kafka Streams DSL](#7-kafka-streams-dsl)
8. [Kafka Connect — Source e Sink](#8-kafka-connect)
9. [Schema Registry + Avro (Java)](#9-schema-registry--avro)
10. [Docker Compose — Cluster KRaft Completo](#10-docker-compose--kraft)
11. [Anti-patterns](#11-anti-patterns)

---

## 1. Go — kafka-go

### Producer (at-least-once com idempotência)

```go
package kafka

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/segmentio/kafka-go"
)

type Producer struct {
	writer *kafka.Writer
}

// NewProducer cria producer com configuração segura para produção.
func NewProducer(brokers []string) *Producer {
	w := &kafka.Writer{
		Addr:         kafka.TCP(brokers...),
		Balancer:     &kafka.Hash{},        // roteamento por key (determinístico)
		RequiredAcks: kafka.RequireAll,      // acks=all
		MaxAttempts:  10,
		BatchSize:    100,
		BatchTimeout: 5 * time.Millisecond, // linger.ms equivalente
		Compression:  kafka.Snappy,
		// Idempotência: habilitada automaticamente com RequireAll + MaxAttempts > 1
		ErrorLogger: kafka.LoggerFunc(func(msg string, args ...interface{}) {
			fmt.Printf("[KAFKA-PRODUCER ERROR] "+msg+"\n", args...)
		}),
	}
	return &Producer{writer: w}
}

// Publish publica um evento. A key determina a partição (mensagens com mesma key
// vão para a mesma partição, preservando ordenação).
func (p *Producer) Publish(ctx context.Context, topic string, key string, payload any) error {
	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal payload: %w", err)
	}

	msg := kafka.Message{
		Topic: topic,
		Key:   []byte(key),
		Value: body,
		Headers: []kafka.Header{
			{Key: "content-type", Value: []byte("application/json")},
			{Key: "produced-at", Value: []byte(time.Now().UTC().Format(time.RFC3339))},
		},
	}

	if err := p.writer.WriteMessages(ctx, msg); err != nil {
		return fmt.Errorf("write message to %s: %w", topic, err)
	}
	return nil
}

// PublishBatch publica múltiplas mensagens atomicamente no mesmo topic.
func (p *Producer) PublishBatch(ctx context.Context, topic string, events []any, keyFn func(any) string) error {
	msgs := make([]kafka.Message, len(events))
	for i, e := range events {
		body, _ := json.Marshal(e)
		msgs[i] = kafka.Message{Topic: topic, Key: []byte(keyFn(e)), Value: body}
	}
	return p.writer.WriteMessages(ctx, msgs...)
}

func (p *Producer) Close() error { return p.writer.Close() }
```

### Consumer (commit manual, reconexão, Dead Letter)

```go
package kafka

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"time"

	"github.com/segmentio/kafka-go"
)

type MessageHandler func(ctx context.Context, key, value []byte) error

type Consumer struct {
	reader      *kafka.Reader
	dlqWriter   *kafka.Writer // Dead Letter Topic writer
	handler     MessageHandler
	maxAttempts int
}

// NewConsumer cria consumer com commit manual e Dead Letter Topic.
func NewConsumer(brokers []string, topic, groupID, dlqTopic string, handler MessageHandler) *Consumer {
	reader := kafka.NewReader(kafka.ReaderConfig{
		Brokers:        brokers,
		Topic:          topic,
		GroupID:        groupID,
		MinBytes:       1,
		MaxBytes:       10e6,    // 10MB
		MaxWait:        500 * time.Millisecond,
		CommitInterval: 0,       // commit manual (CommitInterval=0 desabilita auto-commit)
		StartOffset:    kafka.FirstOffset, // equivale a auto.offset.reset=earliest
		// Rebalance strategy: CooperativeSticky (menos disruptivo)
		GroupBalancers: []kafka.GroupBalancer{
			kafka.CooperativeStickyGroupBalancer{},
		},
	})

	var dlqWriter *kafka.Writer
	if dlqTopic != "" {
		dlqWriter = &kafka.Writer{
			Addr:         kafka.TCP(brokers...),
			Topic:        dlqTopic,
			RequiredAcks: kafka.RequireAll,
		}
	}

	return &Consumer{reader: reader, dlqWriter: dlqWriter, handler: handler, maxAttempts: 3}
}

// Start inicia o loop de consumo com retry e Dead Letter Topic.
func (c *Consumer) Start(ctx context.Context) error {
	for {
		msg, err := c.reader.FetchMessage(ctx)
		if err != nil {
			if errors.Is(err, context.Canceled) || errors.Is(err, io.EOF) {
				return nil
			}
			return fmt.Errorf("fetch: %w", err)
		}

		if err := c.processWithRetry(ctx, msg); err != nil {
			// Falha após todos os retries → enviar para DLQ
			slog.Error("message processing failed — sending to DLQ",
				"topic", msg.Topic, "partition", msg.Partition,
				"offset", msg.Offset, "err", err)
			c.sendToDLQ(ctx, msg, err)
		}

		// Commit apenas após processamento (at-least-once)
		if err := c.reader.CommitMessages(ctx, msg); err != nil {
			slog.Error("commit failed", "err", err)
		}
	}
}

func (c *Consumer) processWithRetry(ctx context.Context, msg kafka.Message) error {
	var lastErr error
	for attempt := 1; attempt <= c.maxAttempts; attempt++ {
		if err := c.handler(ctx, msg.Key, msg.Value); err != nil {
			lastErr = err
			slog.Warn("handler error — retrying",
				"attempt", attempt, "max", c.maxAttempts, "err", err)
			time.Sleep(time.Duration(attempt) * 500 * time.Millisecond) // backoff
			continue
		}
		return nil
	}
	return lastErr
}

func (c *Consumer) sendToDLQ(ctx context.Context, original kafka.Message, procErr error) {
	if c.dlqWriter == nil {
		return
	}
	dlqMsg := kafka.Message{
		Key:   original.Key,
		Value: original.Value,
		Headers: append(original.Headers,
			kafka.Header{Key: "dlq-original-topic", Value: []byte(original.Topic)},
			kafka.Header{Key: "dlq-error", Value: []byte(procErr.Error())},
			kafka.Header{Key: "dlq-timestamp", Value: []byte(time.Now().UTC().Format(time.RFC3339))},
		),
	}
	if err := c.dlqWriter.WriteMessages(ctx, dlqMsg); err != nil {
		slog.Error("failed to write to DLQ", "err", err)
	}
}

func (c *Consumer) Close() {
	c.reader.Close()
	if c.dlqWriter != nil {
		c.dlqWriter.Close()
	}
}
```

---

## 2. Python — confluent-kafka

```python
import json
import logging
from typing import Callable, Any
from confluent_kafka import Producer, Consumer, KafkaException, KafkaError, Message

logger = logging.getLogger(__name__)

# ── Producer ──────────────────────────────────────────────────────────────────
class KafkaProducer:
    def __init__(self, brokers: str):
        self._producer = Producer({
            "bootstrap.servers": brokers,
            "acks": "all",
            "enable.idempotence": True,
            "retries": 2147483647,
            "max.in.flight.requests.per.connection": 5,
            "linger.ms": 5,
            "batch.size": 65536,
            "compression.type": "snappy",
            "delivery.timeout.ms": 120000,
        })

    def publish(self, topic: str, key: str, payload: Any) -> None:
        """Publica mensagem com delivery callback."""
        def on_delivery(err, msg):
            if err:
                logger.error(f"Delivery failed: {err} | topic={msg.topic()}")
            else:
                logger.debug(f"Delivered: {msg.topic()}[{msg.partition()}]@{msg.offset()}")

        self._producer.produce(
            topic=topic,
            key=key.encode("utf-8"),
            value=json.dumps(payload).encode("utf-8"),
            on_delivery=on_delivery,
        )
        # flush a cada N mensagens para controlar buffering
        self._producer.poll(0)  # processar callbacks pendentes sem bloquear

    def flush(self, timeout: float = 30.0) -> None:
        remaining = self._producer.flush(timeout)
        if remaining > 0:
            logger.warning(f"{remaining} messages still in queue after flush")

    def __enter__(self): return self
    def __exit__(self, *_): self.flush()


# ── Consumer ──────────────────────────────────────────────────────────────────
class KafkaConsumer:
    def __init__(self, brokers: str, group_id: str, topics: list[str]):
        self._consumer = Consumer({
            "bootstrap.servers": brokers,
            "group.id": group_id,
            "enable.auto.commit": False,          # commit manual
            "auto.offset.reset": "earliest",
            "max.poll.interval.ms": 300000,
            "session.timeout.ms": 45000,
            "heartbeat.interval.ms": 15000,
            "partition.assignment.strategy": "cooperative-sticky",
            "isolation.level": "read_committed",
        })
        self._consumer.subscribe(topics)
        self._running = False

    def start(self, handler: Callable[[str, bytes], None]) -> None:
        self._running = True
        try:
            while self._running:
                msg: Message = self._consumer.poll(timeout=1.0)
                if msg is None:
                    continue
                if msg.error():
                    if msg.error().code() == KafkaError._PARTITION_EOF:
                        continue
                    raise KafkaException(msg.error())

                try:
                    handler(msg.key().decode("utf-8") if msg.key() else "", msg.value())
                    # Commit após processamento (at-least-once)
                    self._consumer.commit(message=msg, asynchronous=False)
                except Exception as e:
                    logger.error(f"Handler error: {e} — message NOT committed")
                    # Não commita → será reprocessado após rebalance/restart
        finally:
            self._consumer.close()

    def stop(self): self._running = False
```

---

## 3. Java/Spring Kafka

### Configuração Spring Boot

```java
// KafkaConfig.java
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.common.serialization.StringSerializer;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory;
import org.springframework.kafka.core.*;
import org.springframework.kafka.listener.*;
import org.springframework.util.backoff.FixedBackOff;

@Configuration
@EnableKafka
public class KafkaConfig {

    @Value("${spring.kafka.bootstrap-servers}")
    private String bootstrapServers;

    // ── Producer ──────────────────────────────────────────────────────────────
    @Bean
    ProducerFactory<String, String> producerFactory() {
        return new DefaultKafkaProducerFactory<>(Map.of(
            ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers,
            ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class,
            ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class,
            ProducerConfig.ACKS_CONFIG, "all",
            ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true,
            ProducerConfig.RETRIES_CONFIG, Integer.MAX_VALUE,
            ProducerConfig.LINGER_MS_CONFIG, 5,
            ProducerConfig.BATCH_SIZE_CONFIG, 65536,
            ProducerConfig.COMPRESSION_TYPE_CONFIG, "snappy"
        ));
    }

    @Bean
    KafkaTemplate<String, String> kafkaTemplate() {
        return new KafkaTemplate<>(producerFactory());
    }

    // ── Consumer ──────────────────────────────────────────────────────────────
    @Bean
    ConsumerFactory<String, String> consumerFactory() {
        return new DefaultKafkaConsumerFactory<>(Map.of(
            ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers,
            ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class,
            ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class,
            ConsumerConfig.GROUP_ID_CONFIG, "orders-service-group",
            ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false,
            ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest",
            ConsumerConfig.MAX_POLL_RECORDS_CONFIG, 500,
            ConsumerConfig.PARTITION_ASSIGNMENT_STRATEGY_CONFIG,
                "org.apache.kafka.clients.consumer.CooperativeStickyAssignor"
        ));
    }

    @Bean
    ConcurrentKafkaListenerContainerFactory<String, String> kafkaListenerContainerFactory() {
        var factory = new ConcurrentKafkaListenerContainerFactory<String, String>();
        factory.setConsumerFactory(consumerFactory());
        factory.setConcurrency(3);  // número de threads (≤ partições do topic)
        factory.getContainerProperties().setAckMode(ContainerProperties.AckMode.MANUAL_IMMEDIATE);

        // Retry: 3 tentativas com 1s de intervalo
        factory.setCommonErrorHandler(new DefaultErrorHandler(
            // Dead Letter Publishing após esgotar retries
            new DeadLetterPublishingRecoverer(kafkaTemplate(),
                (record, ex) -> new TopicPartition(record.topic() + ".dlq", record.partition())),
            new FixedBackOff(1000L, 3)
        ));
        return factory;
    }
}
```

### Producer e Consumer Spring

```java
// OrderEventPublisher.java
@Service
public class OrderEventPublisher {
    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ObjectMapper objectMapper;

    public CompletableFuture<SendResult<String, String>> publishOrderCreated(OrderCreatedEvent event) {
        try {
            String payload = objectMapper.writeValueAsString(event);
            return kafkaTemplate.send("orders.created", event.orderId(), payload)
                .whenComplete((result, ex) -> {
                    if (ex != null) {
                        log.error("Failed to publish order {}: {}", event.orderId(), ex.getMessage());
                    } else {
                        log.debug("Published order {} to partition {} offset {}",
                            event.orderId(),
                            result.getRecordMetadata().partition(),
                            result.getRecordMetadata().offset());
                    }
                });
        } catch (JsonProcessingException e) {
            return CompletableFuture.failedFuture(e);
        }
    }
}

// OrderEventConsumer.java
@Component
public class OrderEventConsumer {

    @KafkaListener(
        topics = "orders.created",
        groupId = "payments-service-group",
        containerFactory = "kafkaListenerContainerFactory"
    )
    public void handleOrderCreated(
        @Payload String payload,
        @Header(KafkaHeaders.RECEIVED_KEY) String key,
        @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
        @Header(KafkaHeaders.OFFSET) long offset,
        Acknowledgment ack
    ) {
        try {
            OrderCreatedEvent event = objectMapper.readValue(payload, OrderCreatedEvent.class);
            processOrder(event);
            ack.acknowledge();  // commit manual após processamento
            log.info("Processed order {} from partition {} offset {}", event.orderId(), partition, offset);
        } catch (Exception e) {
            log.error("Failed to process order key={}: {}", key, e.getMessage());
            // DefaultErrorHandler fará retry → DLQ após esgotar
            throw new RuntimeException("Processing failed", e);
        }
    }
}
```

---

## 4. Node.js — KafkaJS

```typescript
import { Kafka, Producer, Consumer, EachMessagePayload } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'my-service',
  brokers: (process.env.KAFKA_BROKERS ?? 'localhost:9092').split(','),
  ssl: process.env.KAFKA_SSL === 'true',
  retry: {
    initialRetryTime: 300,
    retries: 10,
    multiplier: 2,
    maxRetryTime: 30_000,
  },
});

// ── Producer ──────────────────────────────────────────────────────────────────
const producer: Producer = kafka.producer({
  idempotent: true,              // enable.idempotence=true
  transactionTimeout: 60_000,
  maxInFlightRequests: 5,        // obrigatório com idempotência
});

await producer.connect();

async function publishEvent(topic: string, key: string, payload: object): Promise<void> {
  const result = await producer.send({
    topic,
    messages: [{
      key,
      value: JSON.stringify(payload),
      headers: {
        'content-type': 'application/json',
        'produced-at': new Date().toISOString(),
      },
    }],
    acks: -1,   // acks=all
  });
  console.log(`Published to ${topic}[${result[0].partition}]@${result[0].baseOffset}`);
}

// ── Consumer ──────────────────────────────────────────────────────────────────
const consumer: Consumer = kafka.consumer({
  groupId: 'orders-service-group',
  sessionTimeout: 45_000,
  heartbeatInterval: 15_000,
  maxBytesPerPartition: 1_048_576,  // 1MB
  maxWaitTimeInMs: 500,
});

await consumer.connect();
await consumer.subscribe({ topics: ['orders.created'], fromBeginning: true });

await consumer.run({
  autoCommit: false,    // commit manual
  partitionsConsumedConcurrently: 3,
  eachMessage: async ({ topic, partition, message, heartbeat, pause }: EachMessagePayload) => {
    const key = message.key?.toString();
    const value = message.value?.toString();

    try {
      await processOrder(JSON.parse(value!));
      // Commit após processamento bem-sucedido
      await consumer.commitOffsets([{
        topic, partition,
        offset: (BigInt(message.offset) + 1n).toString(),
      }]);
    } catch (err) {
      console.error(`Processing failed for key=${key}: ${err}`);
      // Pausar partição para evitar loop de erro
      const resume = pause();
      setTimeout(resume, 5_000); // aguardar 5s e retomar
      throw err;
    }
  },
});
```

---

## 5. Producer Transacional — Exactly-Once

```java
// Java — Producer transacional (exactly-once end-to-end com consumer)
Properties props = new Properties();
props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker:9092");
props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
props.put(ProducerConfig.TRANSACTIONAL_ID_CONFIG, "payments-service-1");  // único por instância
props.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);

Producer<String, String> producer = new KafkaProducer<>(props);
producer.initTransactions();  // chamar uma vez ao inicializar

try {
    producer.beginTransaction();

    // Múltiplos topics na mesma transação — atômico
    producer.send(new ProducerRecord<>("payments.processed", orderId, paymentJson));
    producer.send(new ProducerRecord<>("orders.updated", orderId, orderJson));

    // Commitar offsets do consumer na transação (consume-transform-produce atômico)
    Map<TopicPartition, OffsetAndMetadata> offsets = getConsumedOffsets();
    producer.sendOffsetsToTransaction(offsets, new ConsumerGroupMetadata("payments-group"));

    producer.commitTransaction();
} catch (ProducerFencedException e) {
    // Fatal: outra instância assumiu o transactional.id → fechar e não reiniciar
    producer.close();
    throw e;
} catch (KafkaException e) {
    producer.abortTransaction();  // desfazer
    // retry na próxima iteração
}
```

---

## 6. Consumer com Dead Letter Topic

```
Topology do fluxo com DLT:

orders.created ──► consumer-group ──► processamento
                        │
                        │  [falha após N retries]
                        ▼
                 orders.created.dlt  ──► DLT consumer (monitoramento / reprocessamento manual)
```

```go
// Criação do DLT topic (kafka-topics.sh)
kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --topic orders.created.dlt \
  --partitions 6 --replication-factor 3 \
  --config retention.ms=2592000000  # 30 dias para análise

// Consumer Go com DLT (vide NewConsumer em seção 1 — dlqTopic="orders.created.dlt")
consumer := kafka.NewConsumer(
    []string{"broker:9092"},
    "orders.created",
    "payments-service-group",
    "orders.created.dlt",  // DLT topic
    func(ctx context.Context, key, value []byte) error {
        return processOrder(ctx, key, value)
    },
)
consumer.Start(context.Background())
```

---

## 7. Kafka Streams DSL

```java
// Exemplo: contar pedidos por cliente em janela de 1 hora
import org.apache.kafka.streams.*;
import org.apache.kafka.streams.kstream.*;
import java.time.Duration;

Properties props = new Properties();
props.put(StreamsConfig.APPLICATION_ID_CONFIG, "order-analytics");
props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, "broker:9092");
props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass());
props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, Serdes.String().getClass());
// Exactly-once processing
props.put(StreamsConfig.PROCESSING_GUARANTEE_CONFIG, StreamsConfig.EXACTLY_ONCE_V2);
// Resiliência: réplicas de standby para failover rápido
props.put(StreamsConfig.NUM_STANDBY_REPLICAS_CONFIG, 1);

StreamsBuilder builder = new StreamsBuilder();

// KStream: stream de eventos imutáveis
KStream<String, String> orders = builder.stream("orders.created");

// KTable: estado atual (último valor por key) — changelog compactado
KTable<String, Long> orderCountPerCustomer = orders
    .selectKey((key, value) -> extractCustomerId(value))  // re-keying
    .groupByKey()
    .windowedBy(TimeWindows.ofSizeWithNoGrace(Duration.ofHours(1)))
    .count(Named.as("order-count-per-customer-hourly"))
    .toStream()
    .map((windowedKey, count) -> KeyValue.pair(windowedKey.key(), count));

// Sink: escrever resultado
orderCountPerCustomer
    .filter((customerId, count) -> count > 10)  // filtrar clientes com > 10 pedidos/hora
    .to("customers.high-volume", Produced.with(Serdes.String(), Serdes.Long()));

// Stream join: enriquecer orders com dados de customer
KTable<String, String> customers = builder.table("customers");
orders
    .selectKey((k, v) -> extractCustomerId(v))
    .join(customers, (order, customer) -> enrichOrder(order, customer))
    .to("orders.enriched");

KafkaStreams streams = new KafkaStreams(builder.build(), props);
streams.setUncaughtExceptionHandler((exception) -> StreamThreadExceptionResponse.REPLACE_THREAD);
streams.start();
Runtime.getRuntime().addShutdownHook(new Thread(streams::close));
```

---

## 8. Kafka Connect

### Source Connector — PostgreSQL CDC (Debezium)

```json
// POST http://connect:8083/connectors
{
  "name": "postgres-cdc-orders",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "tasks.max": "1",
    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "debezium",
    "database.password": "${file:/run/secrets/db-password:password}",
    "database.dbname": "orders_db",
    "database.server.name": "orders-db",
    "topic.prefix": "cdc",
    "table.include.list": "public.orders,public.order_items",
    "plugin.name": "pgoutput",
    "slot.name": "debezium_slot",
    "publication.name": "debezium_pub",
    "snapshot.mode": "initial",
    "decimal.handling.mode": "double",
    "transforms": "unwrap",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.drop.tombstones": "false",
    "errors.tolerance": "all",
    "errors.log.enable": "true",
    "errors.deadletterqueue.topic.name": "cdc.dlq"
  }
}
```

### Sink Connector — Elasticsearch

```json
{
  "name": "elasticsearch-sink-orders",
  "config": {
    "connector.class": "io.confluent.connect.elasticsearch.ElasticsearchSinkConnector",
    "tasks.max": "2",
    "topics": "orders.enriched",
    "connection.url": "http://elasticsearch:9200",
    "type.name": "_doc",
    "key.ignore": "false",
    "schema.ignore": "true",
    "behavior.on.malformed.documents": "warn",
    "errors.tolerance": "all",
    "errors.deadletterqueue.topic.name": "elasticsearch.dlq",
    "errors.retry.timeout": "600000",
    "errors.retry.delay.max.ms": "30000"
  }
}
```

```bash
# Verificar status dos connectors
GET http://connect:8083/connectors
GET http://connect:8083/connectors/postgres-cdc-orders/status
# Reiniciar conector travado
POST http://connect:8083/connectors/postgres-cdc-orders/restart
```

---

## 9. Schema Registry + Avro

```java
// Avro schema: src/main/avro/OrderCreated.avsc
{
  "type": "record",
  "name": "OrderCreated",
  "namespace": "com.eveo.orders",
  "fields": [
    {"name": "orderId", "type": "string"},
    {"name": "customerId", "type": "string"},
    {"name": "amount", "type": "double"},
    {"name": "currency", "type": {"type": "enum", "name": "Currency", "symbols": ["BRL", "USD"]}},
    {"name": "createdAt", "type": {"type": "long", "logicalType": "timestamp-millis"}}
  ]
}

// Producer com Avro + Schema Registry
Properties props = new Properties();
props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class);
props.put("schema.registry.url", "http://schema-registry:8081");
props.put("auto.register.schemas", true);   // registrar automaticamente em dev
// Em produção: auto.register.schemas=false (registrar via CI/CD)

Producer<String, OrderCreated> producer = new KafkaProducer<>(props);
producer.send(new ProducerRecord<>("orders.created", order.getOrderId(), order));

// Consumer com Avro + Schema Registry
props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, KafkaAvroDeserializer.class);
props.put("schema.registry.url", "http://schema-registry:8081");
props.put("specific.avro.reader", true);  // usar classe gerada (type-safe)

Consumer<String, OrderCreated> consumer = new KafkaConsumer<>(props);
```

---

## 10. Docker Compose — KRaft Completo

```yaml
# docker-compose.yml — Kafka KRaft + Schema Registry + Connect (dev)
version: "3.9"

services:
  kafka:
    image: apache/kafka:3.9.0
    container_name: kafka
    ports:
      - "9092:9092"
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
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "false"
      KAFKA_LOG_RETENTION_HOURS: 168
      KAFKA_DEFAULT_REPLICATION_FACTOR: 1    # 1 para dev, 3 para produção
      KAFKA_NUM_PARTITIONS: 3
    volumes:
      - kafka_data:/var/lib/kafka/data
    healthcheck:
      test: ["CMD-SHELL", "kafka-topics.sh --list --bootstrap-server localhost:9092"]
      interval: 10s
      timeout: 10s
      retries: 10

  schema-registry:
    image: confluentinc/cp-schema-registry:7.9.0
    container_name: schema-registry
    depends_on:
      kafka:
        condition: service_healthy
    ports:
      - "8081:8081"
    environment:
      SCHEMA_REGISTRY_HOST_NAME: schema-registry
      SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: kafka:9092
      SCHEMA_REGISTRY_LISTENERS: http://0.0.0.0:8081
      SCHEMA_REGISTRY_SCHEMA_COMPATIBILITY_LEVEL: BACKWARD

  kafka-connect:
    image: confluentinc/cp-kafka-connect:7.9.0
    container_name: kafka-connect
    depends_on:
      kafka:
        condition: service_healthy
    ports:
      - "8083:8083"
    environment:
      CONNECT_BOOTSTRAP_SERVERS: kafka:9092
      CONNECT_REST_PORT: 8083
      CONNECT_GROUP_ID: kafka-connect-group
      CONNECT_CONFIG_STORAGE_TOPIC: connect-configs
      CONNECT_OFFSET_STORAGE_TOPIC: connect-offsets
      CONNECT_STATUS_STORAGE_TOPIC: connect-status
      CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR: 1
      CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR: 1
      CONNECT_STATUS_STORAGE_REPLICATION_FACTOR: 1
      CONNECT_KEY_CONVERTER: org.apache.kafka.connect.storage.StringConverter
      CONNECT_VALUE_CONVERTER: io.confluent.connect.avro.AvroConverter
      CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL: http://schema-registry:8081
      CONNECT_PLUGIN_PATH: /usr/share/java,/usr/share/confluent-hub-components

  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    container_name: kafka-ui
    depends_on: [kafka, schema-registry]
    ports:
      - "8080:8080"
    environment:
      KAFKA_CLUSTERS_0_NAME: local
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:9092
      KAFKA_CLUSTERS_0_SCHEMAREGISTRY: http://schema-registry:8081
      KAFKA_CLUSTERS_0_KAFKACONNECT_0_NAME: local-connect
      KAFKA_CLUSTERS_0_KAFKACONNECT_0_ADDRESS: http://kafka-connect:8083

volumes:
  kafka_data:
```

---

## 11. Anti-patterns

### ❌ 1 — enable.auto.commit=true em consumer de negócio

```java
// ❌ NUNCA — auto-commit pode commitar offsets antes do processamento terminar
// Se o consumer cair entre o commit e o fim do processamento → mensagem perdida
props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, true);  // padrão PERIGOSO

// ✅ SEMPRE — commit manual após processamento confirmado
props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false);
consumer.commitSync();  // após processar o lote
```

---

### ❌ 2 — acks=1 ou acks=0 para dados críticos

```properties
# ❌ NUNCA — acks=1: mensagem pode ser perdida se o leader falhar antes de replicar
acks=1

# ✅ SEMPRE — acks=all + min.insync.replicas=2 em produção
acks=all
# (topic) min.insync.replicas=2
```

---

### ❌ 3 — Uma partição para todos os consumers (gargalo)

```bash
# ❌ NUNCA — 1 partição com 5 consumers: apenas 1 consumer ativo, 4 ociosos
kafka-topics.sh --create --topic my-topic --partitions 1 ...

# ✅ SEMPRE — partições ≥ número de consumers planejado
# Regra: criar com múltiplos do número de consumers, arredondado para cima
# 3 consumers → 6 partições; 8 consumers → 12 partições
kafka-topics.sh --create --topic my-topic --partitions 12 ...
```

---

### ❌ 4 — auto.create.topics.enable=true em produção

```properties
# ❌ NUNCA — topics criados automaticamente herdam defaults do broker
# Resultado: replication.factor=1, retention=7d, sem min.insync.replicas correto
auto.create.topics.enable=true

# ✅ SEMPRE — criar topics explicitamente com configuração certa
auto.create.topics.enable=false
# Criar via CI/CD ou Terraform com todas as configurações definidas
```

---

### ❌ 5 — Commitar offsets por mensagem individual (lento)

```java
// ❌ NUNCA — commit síncrono por mensagem: destrói throughput
for (ConsumerRecord<String, String> record : records) {
    process(record);
    consumer.commitSync();  // round-trip ao broker por mensagem!
}

// ✅ SEMPRE — commitar por lote (após processar todos os records do poll)
for (ConsumerRecord<String, String> record : records) {
    process(record);
}
consumer.commitSync();  // um commit por lote
```

---

### ❌ 6 — Diminuir número de partições

```bash
# ❌ NUNCA — não é possível diminuir partições sem recriar o topic
# (Kafka não suporta reparticionamento para baixo)
kafka-topics.sh --alter --topic my-topic --partitions 3  # de 12 para 3 → ERRO

# ✅ PLANEJAR CAPACIDADE: criar com partições suficientes desde o início
# Regra: max(consumers, throughput_target/partition_throughput)
# Exemplo: target 100MB/s ÷ 10MB/s por partição = 10 partições
```

---

### ❌ 7 — Sem Dead Letter Topic para consumers de negócio

```java
// ❌ NUNCA — sem DLT: mensagem com falha pode bloquear o consumer indefinidamente
// ou ser descartada silenciosamente dependendo da configuração
while (true) {
    ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
    for (ConsumerRecord<String, String> record : records) {
        process(record);  // se lançar exceção → loop infinito ou perda
    }
    consumer.commitSync();
}

// ✅ SEMPRE — retry + DLT (vide seção 6 e configuração DefaultErrorHandler do Spring)
```

---

### ❌ 8 — Usar Kafka como banco de dados de query (topic não compactado)

```
# ❌ EVITAR — ler todo o histórico do topic para reconstruir estado atual
# Custo: O(N) onde N = todos os eventos históricos

# ✅ PADRÃO — usar cleanup.policy=compact para state topics
# O compaction mantém apenas o ÚLTIMO valor por key → reconstrução eficiente
# E combinar com KTable (Kafka Streams) ou materializar em banco externo (Connect → PostgreSQL)
kafka-topics.sh --create --topic customers \
  --config cleanup.policy=compact \
  --config min.cleanable.dirty.ratio=0.1 \
  --config segment.ms=3600000
```
