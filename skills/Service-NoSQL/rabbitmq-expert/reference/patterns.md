# RabbitMQ — Padrões Canônicos de Produção

## Índice

1. [Go — amqp091-go: Producer + Consumer completo](#1-go--amqp091-go)
2. [Python — pika: Producer + Consumer](#2-python--pika)
3. [Java/Spring AMQP](#3-javaspring-amqp)
4. [Node.js — amqplib](#4-nodejs--amqplib)
5. [Topology: Work Queue com DLX e Quorum Queue](#5-topology-work-queue-com-dlx)
6. [Padrão Pub/Sub — Fanout Exchange](#6-pubsub--fanout-exchange)
7. [Padrão Topic Routing](#7-topic-routing)
8. [Publisher Confirms Assíncrono (Go)](#8-publisher-confirms-assíncrono)
9. [RPC Pattern](#9-rpc-pattern)
10. [Docker Compose — Broker Completo](#10-docker-compose)
11. [Anti-patterns](#11-anti-patterns)

---

## 1. Go — amqp091-go

### Producer (com publisher confirms)

```go
package messaging

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

type Publisher struct {
	conn    *amqp.Connection
	channel *amqp.Channel
	done    chan struct{}
}

// NewPublisher cria publisher com publisher confirms habilitado.
// dsn: "amqp://user:pass@host:5672/vhost"
func NewPublisher(dsn string) (*Publisher, error) {
	conn, err := amqp.Dial(dsn)
	if err != nil {
		return nil, fmt.Errorf("dial: %w", err)
	}

	ch, err := conn.Channel()
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("channel: %w", err)
	}

	// Habilitar publisher confirms no channel
	if err := ch.Confirm(false); err != nil {
		ch.Close()
		conn.Close()
		return nil, fmt.Errorf("confirm mode: %w", err)
	}

	return &Publisher{conn: conn, channel: ch, done: make(chan struct{})}, nil
}

// DeclareTopology declara exchange, queue e binding (idempotente).
func (p *Publisher) DeclareTopology(exchange, queue string) error {
	// Exchange durável
	if err := p.channel.ExchangeDeclare(
		exchange, "direct", true, false, false, false, nil,
	); err != nil {
		return fmt.Errorf("exchange declare: %w", err)
	}

	// Quorum Queue com DLX
	args := amqp.Table{
		amqp.QueueTypeArg:             amqp.QueueTypeQuorum,
		"x-dead-letter-exchange":       "dlx." + exchange,
		"x-dead-letter-routing-key":    "dead." + queue,
		"x-message-ttl":                int64(86400000), // 24h em ms
	}
	if _, err := p.channel.QueueDeclare(
		queue, true, false, false, false, args,
	); err != nil {
		return fmt.Errorf("queue declare: %w", err)
	}

	// Binding
	return p.channel.QueueBind(queue, queue, exchange, false, nil)
}

// Publish publica mensagem e aguarda confirm do broker (at-least-once).
func (p *Publisher) Publish(ctx context.Context, exchange, routingKey string, payload any) error {
	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal: %w", err)
	}

	confirms := p.channel.NotifyPublish(make(chan amqp.Confirmation, 1))

	err = p.channel.PublishWithContext(ctx,
		exchange,
		routingKey,
		false, // mandatory
		false, // immediate
		amqp.Publishing{
			ContentType:  "application/json",
			DeliveryMode: amqp.Persistent, // mensagem persistente (survives broker restart)
			Timestamp:    time.Now(),
			Body:         body,
		},
	)
	if err != nil {
		return fmt.Errorf("publish: %w", err)
	}

	// Aguardar confirm do broker
	select {
	case confirm := <-confirms:
		if !confirm.Ack {
			return fmt.Errorf("broker nack — mensagem rejeitada")
		}
		return nil
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(5 * time.Second):
		return fmt.Errorf("timeout aguardando publisher confirm")
	}
}

func (p *Publisher) Close() {
	p.channel.Close()
	p.conn.Close()
}
```

### Consumer (com reconexão e ack manual)

```go
package messaging

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

type HandlerFunc func(ctx context.Context, body []byte) error

type Consumer struct {
	dsn      string
	queue    string
	prefetch int
	handler  HandlerFunc
}

func NewConsumer(dsn, queue string, prefetch int, handler HandlerFunc) *Consumer {
	return &Consumer{dsn: dsn, queue: queue, prefetch: prefetch, handler: handler}
}

// Start inicia o consumer com reconexão automática com backoff exponencial.
func (c *Consumer) Start(ctx context.Context) {
	backoff := time.Second
	for {
		if err := c.run(ctx); err != nil {
			if ctx.Err() != nil {
				return // ctx cancelado — encerrar
			}
			slog.Error("consumer error — reconnecting", "err", err, "backoff", backoff)
			select {
			case <-time.After(backoff):
				backoff = min(backoff*2, 30*time.Second)
			case <-ctx.Done():
				return
			}
		}
	}
}

func (c *Consumer) run(ctx context.Context) error {
	conn, err := amqp.Dial(c.dsn)
	if err != nil {
		return fmt.Errorf("dial: %w", err)
	}
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil {
		return fmt.Errorf("channel: %w", err)
	}
	defer ch.Close()

	// Prefetch: broker só entrega N mensagens antes de receber ack
	if err := ch.Qos(c.prefetch, 0, false); err != nil {
		return fmt.Errorf("qos: %w", err)
	}

	msgs, err := ch.Consume(c.queue, "", false, false, false, false, nil)
	if err != nil {
		return fmt.Errorf("consume: %w", err)
	}

	connClose := conn.NotifyClose(make(chan *amqp.Error, 1))
	slog.Info("consumer started", "queue", c.queue, "prefetch", c.prefetch)

	for {
		select {
		case <-ctx.Done():
			return nil
		case err := <-connClose:
			return fmt.Errorf("connection closed: %w", err)
		case msg, ok := <-msgs:
			if !ok {
				return fmt.Errorf("channel closed")
			}
			c.processMessage(ctx, msg)
		}
	}
}

func (c *Consumer) processMessage(ctx context.Context, msg amqp.Delivery) {
	err := c.handler(ctx, msg.Body)
	if err != nil {
		slog.Error("handler error — nack sem requeue (vai para DLX)",
			"err", err, "queue", c.queue)
		// nack com requeue=false → mensagem vai para DLX
		_ = msg.Nack(false, false)
		return
	}
	// Processamento OK → ack
	_ = msg.Ack(false)
}

func min(a, b time.Duration) time.Duration {
	if a < b {
		return a
	}
	return b
}
```

---

## 2. Python — pika

### Producer assíncrono (aio-pika)

```python
import asyncio
import json
from datetime import datetime
from typing import Any

import aio_pika
from aio_pika import ExchangeType, Message, DeliveryMode


async def create_publisher(dsn: str) -> aio_pika.Connection:
    """Conecta ao RabbitMQ e declara topology."""
    conn = await aio_pika.connect_robust(
        dsn,
        # reconnect_interval: tempo entre tentativas de reconexão (padrão 5s)
    )
    return conn


async def publish(conn: aio_pika.Connection, exchange_name: str, routing_key: str, payload: Any):
    async with conn.channel() as channel:
        # Habilitar confirms
        await channel.set_qos(prefetch_count=10)

        exchange = await channel.declare_exchange(
            exchange_name,
            ExchangeType.DIRECT,
            durable=True,
        )

        message = Message(
            body=json.dumps(payload).encode(),
            content_type="application/json",
            delivery_mode=DeliveryMode.PERSISTENT,  # mensagem persistente
            timestamp=datetime.utcnow(),
        )

        # publish com confirmation (raises se broker recusar)
        await exchange.publish(message, routing_key=routing_key)


# Consumer assíncrono
async def start_consumer(dsn: str, queue_name: str):
    conn = await aio_pika.connect_robust(dsn)
    channel = await conn.channel()
    await channel.set_qos(prefetch_count=10)

    queue = await channel.declare_queue(
        queue_name,
        durable=True,
        arguments={"x-queue-type": "quorum"},
    )

    async with queue.iterator() as q_iter:
        async for message in q_iter:
            async with message.process(requeue=False):  # nack=requeue=False on exception → DLX
                payload = json.loads(message.body)
                await handle_message(payload)


async def handle_message(payload: dict):
    print(f"Processando: {payload}")
    # lógica de negócio aqui
```

---

## 3. Java/Spring AMQP

### Configuração (Spring Boot)

```java
// RabbitMQConfig.java
import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.config.SimpleRabbitListenerContainerFactory;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    public static final String EXCHANGE     = "orders.exchange";
    public static final String QUEUE        = "orders.queue";
    public static final String ROUTING_KEY  = "orders.created";
    public static final String DLX          = "orders.dlx";
    public static final String DLQ          = "orders.dlq";

    // Dead Letter Exchange e Queue
    @Bean
    DirectExchange dlx() {
        return new DirectExchange(DLX, true, false);
    }

    @Bean
    Queue dlq() {
        return QueueBuilder.durable(DLQ).build();
    }

    @Bean
    Binding dlqBinding() {
        return BindingBuilder.bind(dlq()).to(dlx()).with("dead." + ROUTING_KEY);
    }

    // Topology principal
    @Bean
    DirectExchange exchange() {
        return new DirectExchange(EXCHANGE, true, false);
    }

    @Bean
    Queue ordersQueue() {
        return QueueBuilder.durable(QUEUE)
            .quorum()                                       // Quorum Queue
            .withArgument("x-dead-letter-exchange", DLX)
            .withArgument("x-dead-letter-routing-key", "dead." + ROUTING_KEY)
            .withArgument("x-message-ttl", 86400000L)       // 24h
            .build();
    }

    @Bean
    Binding binding() {
        return BindingBuilder.bind(ordersQueue()).to(exchange()).with(ROUTING_KEY);
    }

    // JSON converter
    @Bean
    Jackson2JsonMessageConverter jsonConverter() {
        return new Jackson2JsonMessageConverter();
    }

    // RabbitTemplate com publisher confirms
    @Bean
    RabbitTemplate rabbitTemplate(ConnectionFactory cf) {
        var template = new RabbitTemplate(cf);
        template.setMessageConverter(jsonConverter());
        template.setConfirmCallback((correlationData, ack, cause) -> {
            if (!ack) {
                log.error("Publisher NACK: {}", cause);
            }
        });
        return template;
    }

    // Listener factory com prefetch e ack manual
    @Bean
    SimpleRabbitListenerContainerFactory rabbitListenerContainerFactory(ConnectionFactory cf) {
        var factory = new SimpleRabbitListenerContainerFactory();
        factory.setConnectionFactory(cf);
        factory.setMessageConverter(jsonConverter());
        factory.setPrefetchCount(10);           // fair dispatch
        factory.setAcknowledgeMode(AcknowledgeMode.MANUAL);
        factory.setDefaultRequeueRejected(false); // nack → DLX (não requeue)
        return factory;
    }
}
```

### Producer e Consumer Spring

```java
// OrderPublisher.java
@Service
public class OrderPublisher {
    private final RabbitTemplate rabbitTemplate;

    public void publishOrderCreated(OrderCreatedEvent event) {
        rabbitTemplate.convertAndSend(
            RabbitMQConfig.EXCHANGE,
            RabbitMQConfig.ROUTING_KEY,
            event
        );
    }
}

// OrderConsumer.java
@Component
public class OrderConsumer {

    @RabbitListener(queues = RabbitMQConfig.QUEUE)
    public void handleOrder(OrderCreatedEvent event, Channel channel, Message message)
        throws IOException {

        long deliveryTag = message.getMessageProperties().getDeliveryTag();
        try {
            processOrder(event);
            channel.basicAck(deliveryTag, false);  // ack manual
        } catch (Exception e) {
            log.error("Falha ao processar ordem {}: {}", event.orderId(), e.getMessage());
            channel.basicNack(deliveryTag, false, false);  // nack → DLX
        }
    }

    private void processOrder(OrderCreatedEvent event) {
        // lógica de negócio
    }
}
```

---

## 4. Node.js — amqplib

```typescript
import amqplib, { Channel, Connection, Message } from 'amqplib';

// ── Producer ──────────────────────────────────────────────────────────────────
async function createPublisher(dsn: string) {
  const conn: Connection = await amqplib.connect(dsn);
  const channel: Channel = await conn.createConfirmChannel(); // publisher confirms

  // Declarar topology (idempotente)
  await channel.assertExchange('events', 'topic', { durable: true });
  await channel.assertQueue('events.orders', {
    durable: true,
    arguments: {
      'x-queue-type': 'quorum',
      'x-dead-letter-exchange': 'dlx.events',
      'x-message-ttl': 86400000,
    },
  });
  await channel.bindQueue('events.orders', 'events', 'orders.*');

  return {
    publish: async (routingKey: string, payload: object): Promise<void> => {
      const body = Buffer.from(JSON.stringify(payload));
      return new Promise((resolve, reject) => {
        const sent = channel.publish('events', routingKey, body, {
          persistent: true,               // mensagem persistente
          contentType: 'application/json',
        }, (err) => {
          if (err) reject(err);
          else resolve();
        });
        if (!sent) {
          reject(new Error('Channel write buffer full — aplicar backpressure'));
        }
      });
    },
    close: async () => { await channel.close(); await conn.close(); },
  };
}

// ── Consumer ──────────────────────────────────────────────────────────────────
async function startConsumer(dsn: string, queue: string, handler: (msg: object) => Promise<void>) {
  const conn = await amqplib.connect(dsn);
  const channel = await conn.createChannel();

  await channel.prefetch(10); // fair dispatch

  conn.on('error', (err) => console.error('Connection error:', err));
  conn.on('close', () => { console.log('Connection closed — reconnect...'); /* lógica de reconnect */ });

  await channel.consume(queue, async (msg: Message | null) => {
    if (!msg) return;
    try {
      const payload = JSON.parse(msg.content.toString());
      await handler(payload);
      channel.ack(msg);                   // ack manual
    } catch (err) {
      console.error('Handler error:', err);
      channel.nack(msg, false, false);    // nack → DLX (não requeue)
    }
  }, { noAck: false }); // noAck: false = ack manual
}
```

---

## 5. Topology: Work Queue com DLX

Configuração completa de uma topology de produção: exchange principal, quorum queue com DLX, DLX exchange e DLQ.

```
┌─────────────────────────────────────────────────────────────────────┐
│  TOPOLOGY: orders                                                    │
│                                                                     │
│  Exchange: orders.direct (direct, durable)                          │
│      │                                                              │
│      │ routing_key="orders.created"                                 │
│      ▼                                                              │
│  Queue: orders.created (quorum, durable)                           │
│      │  x-dead-letter-exchange: dlx.orders                         │
│      │  x-dead-letter-routing-key: dead.orders                     │
│      │  x-message-ttl: 86400000 (24h)                              │
│      │                                                              │
│      │  [nack / TTL expirado / fila cheia]                         │
│      ▼                                                              │
│  Exchange: dlx.orders (direct, durable)                             │
│      │ routing_key="dead.orders"                                    │
│      ▼                                                              │
│  Queue: dlq.orders (classic/quorum, durable)                       │
│      └── Consumer de monitoramento/reprocessamento                  │
└─────────────────────────────────────────────────────────────────────┘
```

```go
// Declaração completa da topology acima em Go
func DeclareOrdersTopology(ch *amqp.Channel) error {
    // 1. DLX exchange
    if err := ch.ExchangeDeclare("dlx.orders", "direct", true, false, false, false, nil); err != nil {
        return err
    }
    // 2. Dead letter queue
    if _, err := ch.QueueDeclare("dlq.orders", true, false, false, false,
        amqp.Table{"x-queue-type": "quorum"},
    ); err != nil {
        return err
    }
    if err := ch.QueueBind("dlq.orders", "dead.orders", "dlx.orders", false, nil); err != nil {
        return err
    }

    // 3. Exchange principal
    if err := ch.ExchangeDeclare("orders.direct", "direct", true, false, false, false, nil); err != nil {
        return err
    }
    // 4. Quorum queue principal com DLX
    args := amqp.Table{
        amqp.QueueTypeArg:          amqp.QueueTypeQuorum,
        "x-dead-letter-exchange":    "dlx.orders",
        "x-dead-letter-routing-key": "dead.orders",
        "x-message-ttl":             int64(86400000),
    }
    if _, err := ch.QueueDeclare("orders.created", true, false, false, false, args); err != nil {
        return err
    }
    // 5. Binding
    return ch.QueueBind("orders.created", "orders.created", "orders.direct", false, nil)
}
```

---

## 6. Pub/Sub — Fanout Exchange

```go
// Producer: publica para fanout — todos os consumers recebem
func publishEvent(ch *amqp.Channel, exchange string, body []byte) error {
    return ch.Publish(exchange, "", false, false, amqp.Publishing{
        ContentType:  "application/json",
        DeliveryMode: amqp.Persistent,
        Body:         body,
    })
}

// Consumer: declara fila exclusiva e efêmera (sobrevive apenas enquanto connectado)
func subscribeToFanout(ch *amqp.Channel, exchange string) (<-chan amqp.Delivery, error) {
    if err := ch.ExchangeDeclare(exchange, "fanout", true, false, false, false, nil); err != nil {
        return nil, err
    }
    // Fila exclusiva e auto-delete: cada instância do consumer tem a sua
    q, err := ch.QueueDeclare("", false, false, true, false, nil)
    if err != nil {
        return nil, err
    }
    if err := ch.QueueBind(q.Name, "", exchange, false, nil); err != nil {
        return nil, err
    }
    return ch.Consume(q.Name, "", true, true, false, false, nil) // autoAck em fanout efêmero
}
```

---

## 7. Topic Routing

```
Exchange type: topic
Routing key:   <domain>.<entity>.<action>
Exemplos:
  "orders.payment.approved"
  "orders.fulfillment.shipped"
  "inventory.product.updated"

Bindings:
  "orders.#"           → fila orders-service (todas as mensagens de orders)
  "*.payment.*"        → fila payment-service (qualquer entidade de pagamento)
  "inventory.product.*"→ fila product-service
  "#"                  → fila audit-log (tudo)
```

```go
// Binding com topic wildcards
ch.QueueBind("orders-service", "orders.#", "events", false, nil)
ch.QueueBind("payment-service", "*.payment.*", "events", false, nil)
ch.QueueBind("audit-log", "#", "events", false, nil)
```

---

## 8. Publisher Confirms Assíncrono

```go
// PublishBatch: alta performance com confirms assíncronos
func PublishBatch(ch *amqp.Channel, exchange string, messages [][]byte) error {
    if err := ch.Confirm(false); err != nil {
        return err
    }

    confirms := ch.NotifyPublish(make(chan amqp.Confirmation, len(messages)))
    unconfirmed := make(map[uint64][]byte)
    var seqNo uint64 = 1

    for _, body := range messages {
        unconfirmed[seqNo] = body
        seqNo++
        if err := ch.Publish("", exchange, false, false, amqp.Publishing{
            DeliveryMode: amqp.Persistent,
            Body:         body,
        }); err != nil {
            return err
        }
    }

    // Aguardar todos os confirms
    confirmed := 0
    for confirmed < len(messages) {
        confirm := <-confirms
        if confirm.Multiple {
            // Todas as mensagens até confirm.DeliveryTag foram confirmadas
            for tag := range unconfirmed {
                if tag <= confirm.DeliveryTag {
                    delete(unconfirmed, tag)
                    confirmed++
                }
            }
        } else {
            delete(unconfirmed, confirm.DeliveryTag)
            confirmed++
        }
        if !confirm.Ack {
            return fmt.Errorf("broker nack para mensagem %d", confirm.DeliveryTag)
        }
    }
    return nil
}
```

---

## 9. RPC Pattern

```go
// RPC via RabbitMQ: producer aguarda resposta em reply-to queue exclusiva
func CallRPC(ch *amqp.Channel, exchange, routingKey string, request []byte) ([]byte, error) {
    // Criar fila de resposta exclusiva e efêmera
    replyQueue, _ := ch.QueueDeclare("", false, false, true, false, nil)
    replies, _ := ch.Consume(replyQueue.Name, "", true, true, false, false, nil)

    correlationID := uuid.New().String()

    ch.Publish(exchange, routingKey, false, false, amqp.Publishing{
        ContentType:   "application/json",
        CorrelationId: correlationID,
        ReplyTo:       replyQueue.Name,  // onde o servidor deve responder
        Body:          request,
    })

    timeout := time.After(10 * time.Second)
    for {
        select {
        case reply := <-replies:
            if reply.CorrelationId == correlationID {
                return reply.Body, nil
            }
        case <-timeout:
            return nil, fmt.Errorf("RPC timeout")
        }
    }
}

// Servidor RPC: processa e responde na reply-to queue
func handleRPC(ch *amqp.Channel, msg amqp.Delivery) {
    result := processRequest(msg.Body)
    ch.Publish("", msg.ReplyTo, false, false, amqp.Publishing{
        ContentType:   "application/json",
        CorrelationId: msg.CorrelationId,
        Body:          result,
    })
    msg.Ack(false)
}
```

---

## 10. Docker Compose

```yaml
# docker-compose.yml — RabbitMQ completo para desenvolvimento
version: "3.9"

services:
  rabbitmq:
    image: rabbitmq:3.13-management
    container_name: rabbitmq
    ports:
      - "5672:5672"    # AMQP
      - "15672:15672"  # Management UI — http://localhost:15672
      - "15692:15692"  # Prometheus metrics
    environment:
      RABBITMQ_DEFAULT_USER: admin
      RABBITMQ_DEFAULT_PASS: adminpass
      RABBITMQ_DEFAULT_VHOST: /
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
      - ./config/rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf:ro
      - ./config/enabled_plugins:/etc/rabbitmq/enabled_plugins:ro
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "check_running"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  rabbitmq_data:

# config/enabled_plugins:
# [rabbitmq_management,rabbitmq_prometheus,rabbitmq_delayed_message_exchange].

# config/rabbitmq.conf:
# vm_memory_high_watermark.relative = 0.6
# disk_free_limit.absolute = 1GB
# log.console = true
# log.console.level = info
```

---

## 11. Anti-patterns

### ❌ 1 — Uma Connection por mensagem (anti-pattern #1)

```go
// ❌ NUNCA — abre e fecha TCP por mensagem (lento + esgota file descriptors)
for _, msg := range messages {
    conn, _ := amqp.Dial(dsn)        // nova conexão TCP por mensagem!
    ch, _ := conn.Channel()
    ch.Publish(...)
    conn.Close()
}

// ✅ SEMPRE — uma Connection e Channel reutilizados (ou pool de channels)
conn, _ := amqp.Dial(dsn)
ch, _ := conn.Channel()
ch.Confirm(false)
for _, msg := range messages {
    ch.Publish(...)
}
```

---

### ❌ 2 — autoAck em work queues

```go
// ❌ NUNCA — autoAck: se o consumer cair após receber mas antes de processar,
// a mensagem é perdida silenciosamente
msgs, _ := ch.Consume(queue, "", true, false, false, false, nil) // autoAck=true

// ✅ SEMPRE — ack manual após processamento confirmado
msgs, _ := ch.Consume(queue, "", false, false, false, false, nil) // autoAck=false
for msg := range msgs {
    if err := process(msg.Body); err != nil {
        msg.Nack(false, false) // nack → DLX
    } else {
        msg.Ack(false)
    }
}
```

---

### ❌ 3 — Sem prefetch (prefetch ilimitado)

```go
// ❌ NUNCA — sem QoS: broker entrega todas as mensagens ao consumer de uma vez
// Resultado: consumer fica sobrecarregado, outros consumers ficam ociosos
ch.Consume(queue, ...)  // sem ch.Qos() antes

// ✅ SEMPRE — definir prefetch para fair dispatch
ch.Qos(10, 0, false)   // 10 mensagens por vez (ajustar conforme workload)
ch.Consume(queue, ...)
```

---

### ❌ 4 — Classic queue sem DLX

```go
// ❌ NUNCA — mensagem rejeitada/expirada é descartada silenciosamente
ch.QueueDeclare("orders", true, false, false, false, nil) // sem DLX

// ✅ SEMPRE — DLX para capturar mensagens com falha
args := amqp.Table{
    amqp.QueueTypeArg:          amqp.QueueTypeQuorum,
    "x-dead-letter-exchange":    "dlx.orders",
    "x-dead-letter-routing-key": "dead.orders",
}
ch.QueueDeclare("orders", true, false, false, false, args)
```

---

### ❌ 5 — Credenciais hardcoded

```go
// ❌ NUNCA
conn, _ := amqp.Dial("amqp://admin:adminpass@rabbitmq:5672/")

// ✅ SEMPRE — variáveis de ambiente
dsn := fmt.Sprintf("amqp://%s:%s@%s:%s/%s",
    os.Getenv("RABBITMQ_USER"),
    os.Getenv("RABBITMQ_PASS"),
    os.Getenv("RABBITMQ_HOST"),
    os.Getenv("RABBITMQ_PORT"),
    url.PathEscape(os.Getenv("RABBITMQ_VHOST")),
)
```

---

### ❌ 6 — Classic mirrored queues (depreciadas)

```go
// ❌ NUNCA em RabbitMQ 3.13+ — HA policy com classic mirrors foi removida em 4.x
// rabbitmqctl set_policy ha-all ".*" '{"ha-mode":"all"}' --apply-to queues

// ✅ SEMPRE — Quorum Queues para HA (Raft-based, muito mais robusto)
args := amqp.Table{amqp.QueueTypeArg: amqp.QueueTypeQuorum}
ch.QueueDeclare("my-queue", true, false, false, false, args)
```

---

### ❌ 7 — Sem reconexão automática

```go
// ❌ NUNCA — conexão sem recovery: qualquer falha de rede derruba o consumer
conn, _ := amqp.Dial(dsn)
// se conn cair → panic ou loop de erros sem recovery

// ✅ SEMPRE — loop de reconexão com backoff exponencial (vide padrão Consumer em seção 1)
// Ou usar amqp.DialConfig com automatic recovery via NotifyClose
```

---

### ❌ 8 — Publicar sem confirmar tipo de fila

```go
// ❌ RISCO — publisher assume que a fila é durável, mas não a declara
ch.Publish(exchange, "my-queue", false, false, msg)
// Se a fila não existe ou não é durável → mensagem perdida

// ✅ SEMPRE — idempotent declare antes de publicar ou ao inicializar
ch.QueueDeclare("my-queue", true, false, false, false,
    amqp.Table{amqp.QueueTypeArg: amqp.QueueTypeQuorum})
```
