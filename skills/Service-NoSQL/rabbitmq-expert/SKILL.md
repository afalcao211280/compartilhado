---
name: rabbitmq-expert
description: >
  Especialista RabbitMQ (broker AMQP 0-9-1) em padrões de produção EVEO. Stack: RabbitMQ
  3.13 LTS/4.x, clients Go (amqp091-go)/Python (pika/aio-pika)/Java-Spring/Node (amqplib),
  quorum queues, Prometheus. Gera producer/consumer completos, topologia exchange/queue/binding,
  DLX/DLQ, publisher confirms, clustering. Acione SEMPRE que mencionar RabbitMQ, AMQP, exchange,
  queue, binding, routing key, DLX, prefetch, quorum queue ou RabbitMQ vs Kafka.
version: "2.1.0"
category: Service-NoSQL
keywords:
  - rabbitmq
  - amqp
  - messaging
  - queue
  - pub-sub
  - exchange
  - dead-letter-exchange
  - quorum-queue
  - publisher-confirms
  - prefetch
globs:
  - "**/rabbitmq*.{yml,yaml,conf}"
  - "**/amqp*.{go,py,js,ts,java}"
requires:
  - security-expert
---

# RabbitMQ Expert — Padrões EVEO

Especialista sênior em RabbitMQ. Função **executiva**: gera código de producer/consumer completo,
define topologia AMQP, configura mensageria pronta para produção — não esqueletos.

## Princípios

1. **Uma Connection por processo, um Channel por thread/goroutine** — Connection é TCP caro; abrir Connection por mensagem é o anti-pattern #1 (esgota file descriptors).
2. **Publisher confirms + ack manual = at-least-once end-to-end** — fire-and-forget e autoAck perdem mensagem silenciosamente na falha.
3. **Quorum Queues em produção** — HA via Raft. Classic mirrored queues foram depreciadas no 3.13 e removidas no 4.x.
4. **DLX sempre em filas de produção** — sem Dead Letter Exchange, mensagem rejeitada/expirada/overflow some sem rastro.
5. **`prefetch` (QoS) sempre definido** — prefetch ilimitado sobrecarrega um consumer e deixa os outros ociosos (sem fair dispatch).
6. **`durable: true` + `deliveryMode: 2`** — exchange, fila e mensagem persistentes para sobreviver a restart do broker.
7. **Reconexão automática com backoff** — qualquer falha de rede derruba o consumer sem recovery.

## Arquitetura AMQP 0-9-1

```
Producer
   │
   │  publish(exchange, routing_key, message)
   ▼
Exchange ──── Binding (routing_key) ───► Queue ──► Consumer
   │                                       │
   │  (regras de roteamento)         (ack/nack/reject)
   │
   ├── Direct:   routing_key == binding_key  (1-to-1 ou round-robin)
   ├── Fanout:   broadcast para todas as filas (ignora routing_key)
   ├── Topic:    routing_key com wildcards (* = 1 palavra, # = N palavras)
   └── Headers:  match em headers AMQP (ignora routing_key)

Connection → Channel(s) → [declare exchange / declare queue / bind / publish / consume]
```

> Uma **Connection** é TCP; um **Channel** é uma sessão lógica multiplexada dentro da
> Connection. Use **uma Connection por processo/serviço** e **um Channel por goroutine/thread**.
> Nunca abra uma Connection por mensagem — é o anti-pattern #1 do RabbitMQ.

## Tabela de Decisão — Tipo de Exchange

| Padrão | Exchange Type | Routing Key | Quando Usar |
|--------|--------------|-------------|-------------|
| Ponto-a-ponto, round-robin | `direct` | exata | Work queues, task dispatch |
| Broadcast para todos | `fanout` | ignorado | Notificações, cache invalidation |
| Roteamento por padrão | `topic` | `*.order.#` | Logs multi-nível, eventos por domínio |
| Roteamento por atributos | `headers` | ignorado | Filtros complexos sem convenção de routing key |
| Sem exchange (default) | `""` (default) | nome da fila | Testes rápidos, legado |

## Tabela de Decisão — Tipo de Queue

| Tipo | Quando Usar | HA | Replay | Produção |
|------|-------------|----|----|------|
| **Quorum** | Workloads gerais, HA obrigatória | ✅ Raft | ❌ | ✅ **Padrão recomendado** |
| **Stream** | Alto volume, replay, múltiplos consumidores independentes | ✅ | ✅ | ✅ |
| Classic | Legado, filas temporárias não críticas | ❌ (deprecated espelhamento) | ❌ | ⚠️ |

> **Regra de ouro**: use **Quorum Queues** em produção para qualquer workload que precise de
> durabilidade e HA. Classic queues com mirroring foram depreciadas no RabbitMQ 3.13+.

## Garantias de Entrega

| Configuração | Garantia | Custo |
|-------------|---------|-------|
| Publisher sem confirms | Fire and forget | Sem custo extra |
| **Publisher confirms** | At-least-once (broker confirmou) | ~20% throughput |
| Consumer `ack` manual | At-least-once (processou) | Lógica de retry necessária |
| Consumer `ack` auto | At-most-once (pode perder) | Não use em produção |
| **Confirms + ack manual** | **At-least-once end-to-end** | **Padrão produção** |

## Padrões Obrigatórios de Produção

### Prefetch / QoS — Fair Dispatch

```
# Sem prefetch: broker entrega TODAS as mensagens ao consumer de uma vez
# Com prefetch=1: broker só entrega próxima mensagem após ack da anterior
# Recomendação: 10-50 para consumidores rápidos, 1 para processamento pesado

channel.basicQos(prefetchCount: 10)  # por channel
```

### Dead Letter Exchange (DLX)

Mensagens rejeitadas (nack sem requeue), TTL expirado ou fila cheia → redirecionadas ao DLX.
Sempre configure DLX em filas de produção para não perder mensagens com falha.

```
Fila principal: x-dead-letter-exchange = "dlx.orders"
                x-dead-letter-routing-key = "dead.orders"
DLX Exchange:   type=direct
DLQ:            "dlq.orders" (bound ao DLX com routing key "dead.orders")
```

### Conexão com Reconnect

Nunca abra conexão sem retry e sem connection recovery. Use as bibliotecas com
`automatic_recovery` habilitado (padrão no amqp091-go e amqplib).

## Workflow Agentic — Como Gerar Soluções

### 1. Entender o padrão de mensageria

Antes de gerar código, identificar:
- **Padrão**: Work Queue? Pub/Sub? Topic routing? RPC? Event sourcing?
- **Linguagem(s)**: Go, Python, Java/Spring, Node.js, .NET?
- **Garantia de entrega**: fire-and-forget, at-least-once, ou exactly-once aplicativo?
- **Volume**: mensagens/segundo — impacta prefetch e número de consumers
- **HA**: cluster com quorum queues ou standalone (dev)?
- **DLX**: precisa de dead letter para mensagens com falha?
- **Conteúdo**: JSON, Avro, binário?

### 2. Gerar componentes em ordem

```
1. Topology declaration   → exchanges, queues, bindings (idempotente com durable=true)
2. Producer               → connect, publish com confirms
3. Consumer               → connect, declare mesmos recursos, basicConsume + ack manual
4. Docker Compose         → broker + management UI
5. Prometheus/alertas     → se monitoramento solicitado
```

### 3. Saída esperada por entrega

- **Código completo** por linguagem (sem "completar conforme seu caso")
- **Topology clara**: qual exchange, qual queue, qual routing key
- **Error handling**: reconexão, nack com requeue=false para DLX
- **Configuração Docker** para dev/test local

## Checklist de Produção

- [ ] Quorum Queues declaradas com `x-queue-type: quorum`
- [ ] Exchanges e filas declaradas como `durable: true`
- [ ] Mensagens publicadas como `deliveryMode: 2` (persistent)
- [ ] Publisher confirms habilitado (não fire-and-forget)
- [ ] `prefetchCount` configurado (não 0 / ilimitado)
- [ ] Acks manuais no consumer (não `autoAck: true`)
- [ ] DLX configurado para mensagens com falha
- [ ] TTL definido para filas que não devem acumular indefinidamente
- [ ] Uma Connection por processo, um Channel por goroutine/thread
- [ ] Reconexão automática com backoff exponencial
- [ ] vhosts por ambiente/aplicação (não tudo no `/`)
- [ ] Credenciais via variáveis de ambiente (nunca hardcoded)
- [ ] `rabbitmq_prometheus` plugin ativo + alertas de consumer lag e memory

## Padrões de Resiliência

- **Retry queues com delay incremental**: não requeue na mesma fila indefinidamente (auto-DoS). Encaminhe para filas de espera com TTL crescente (1s → 5s → 30s) via `rabbitmq_delayed_message_exchange`, e ao DLQ após esgotar.
- **Circuit breaker**: quando o downstream falha, pare de consumir para não acumular fila; backoff exponencial na reconexão.
- **Backpressure**: monitore `vm_memory_high_watermark` (flow control) — buffer de channel cheio deve bloquear/pausar o publisher, não estourar memória.

## Referências (sob demanda — progressive disclosure)

Leia conforme a tarefa (não entram no contexto automaticamente):

- **`reference/patterns.md`** — Código canônico por linguagem: Go (amqp091-go), Python (pika/aio-pika), Java/Spring AMQP, Node.js (amqplib); padrões Work Queue, Pub/Sub fanout, Topic routing, RPC, Dead Letter Queue; Docker Compose; quorum queue com DLX; publisher confirms assíncrono; 8 anti-patterns ❌/✅. **Leia SEMPRE ao gerar código ou configuração.**
- **`reference/stack.md`** — Versões RabbitMQ, Docker images, clients por linguagem, `rabbitmq.conf`/`advanced.config`, env vars, portas, clustering e quorum queues, plugins, management HTTP API, métricas Prometheus e alertas. **Leia ao configurar broker, clustering ou monitoramento.**

## Cross-references

- `security-expert` — TLS, auth (LDAP/OAuth2), secrets, vhost isolation.
- `kafka-expert` — event streaming de alto volume, replay por offset, múltiplos consumer groups (ver tabela Kafka vs RabbitMQ).
- Skills de backend (golang/java/python/node) — camada de aplicação do producer/consumer.

## Segurança (Baseline Compartilhado)

Regras universais em `reference/security-baseline.md`. Ameaças específicas do domínio RabbitMQ:

- **TLS obrigatório**: AMQP sobre TLS (porta 5671) e Management sobre HTTPS (15671) em produção. Nunca `guest/guest` fora de dev local.
- **Autenticação**: usuário/credencial por aplicação/serviço; LDAP ou OAuth2 para enterprise. Rotação regular.
- **Autorização por vhost**: isolar tenants/ambientes em vhosts (não tudo no `/`); permissões mínimas (configure/write/read) por padrão.
- **Credenciais** via env/secret manager, nunca hardcoded na DSN nem em logs.
- **Limites de recurso**: `vm_memory_high_watermark` e `disk_free_limit` configurados — evita OOM e protege o broker (flow control).