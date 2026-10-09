# RabbitMQ Expert — Stack e Referência Técnica

## Versões

| Versão | Status | Notas |
|--------|--------|-------|
| RabbitMQ 4.x | **Mais recente** | AMQP 1.0 nativo, Native AMQP, Classic queue mirror removido |
| RabbitMQ 3.13 | **LTS recomendado** | Quorum queues estável, Streams produção, depreca classic mirrors |
| RabbitMQ 3.12 | Mantido (fim do suporte em breve) | — |

> **Regra**: ambientes novos usam RabbitMQ 3.13 LTS. Não use classic mirrored queues
> (depreciadas em 3.13 e removidas em 4.x). Use Quorum Queues.

---

## Docker Images

```yaml
# docker-compose.yml — desenvolvimento
services:
  rabbitmq:
    image: rabbitmq:3.13-management    # inclui UI de gerenciamento
    # Alternativa: rabbitmq:4.0-management
    ports:
      - "5672:5672"     # AMQP
      - "15672:15672"   # Management UI
      - "15692:15692"   # Prometheus metrics (precisa de plugin)
    environment:
      RABBITMQ_DEFAULT_USER: admin
      RABBITMQ_DEFAULT_PASS: adminpass
      RABBITMQ_DEFAULT_VHOST: /
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
      - ./rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf:ro
      - ./enabled_plugins:/etc/rabbitmq/enabled_plugins:ro
volumes:
  rabbitmq_data:
```

---

## Clients por Linguagem

| Linguagem | Library | Versão | Install |
|----------|---------|--------|---------|
| **Go** | `amqp091-go` | `v1.10+` | `go get github.com/rabbitmq/amqp091-go` |
| **Python** | `pika` | `1.3.x` | `pip install pika` |
| **Python** | `aio-pika` | `9.x` | `pip install aio-pika` (async) |
| **Java** | Spring AMQP | `3.x` | `spring-boot-starter-amqp` |
| **Java** | amqp-client | `5.x` | `com.rabbitmq:amqp-client:5.21.0` |
| **Node.js** | `amqplib` | `0.10.x` | `npm install amqplib` |
| **Node.js** | `@cloudamqp/amqp-client` | `3.x` | `npm install @cloudamqp/amqp-client` |
| **.NET** | `RabbitMQ.Client` | `7.x` | `dotnet add package RabbitMQ.Client` |
| **Rust** | `lapin` | `2.x` | `cargo add lapin` |

---

## Portas Padrão

| Porta | Protocolo | Uso |
|-------|---------|-----|
| **5672** | TCP | AMQP 0-9-1 (clientes) |
| **5671** | TCP | AMQP 0-9-1 com TLS |
| **15672** | HTTP | Management UI e REST API |
| **15671** | HTTPS | Management UI com TLS |
| **15692** | HTTP | Prometheus metrics |
| **4369** | TCP | EPMD (Erlang Port Mapper — clustering) |
| **25672** | TCP | Inter-node e CLI (clustering) |
| **1883** | TCP | MQTT |
| **61613** | TCP | STOMP |

---

## rabbitmq.conf — Configuração Principal

```ini
# /etc/rabbitmq/rabbitmq.conf

## Rede
listeners.tcp.default = 5672
# listeners.ssl.default = 5671   # habilitar para TLS

## Management
management.tcp.port = 15672
# management.ssl.port = 15671

## Limites de recursos (produção)
vm_memory_high_watermark.relative = 0.6   # 60% da RAM — acima disso: flow control
disk_free_limit.absolute = 2GB            # espaço mínimo em disco

## Logging
log.console = true
log.console.level = info
log.file = false    # em containers: log.console=true, log.file=false

## Default user (alterar em produção!)
default_user = admin
default_pass = CHANGE_ME
default_vhost = /

## Heartbeat (segundos) — detectar conexões mortas
heartbeat = 60

## Número máximo de conexões
# connection_max = 10000

## Channel max por conexão
channel_max = 2047

## Message store write sync (performance vs durabilidade)
# queue_master_locator = min-masters
```

---

## advanced.config — Configurações Erlang

```erlang
%% /etc/rabbitmq/advanced.config
%% Somente quando rabbitmq.conf não cobre a necessidade

[
  {rabbit, [
    %% Tamanho máximo de mensagem (bytes) — padrão 128MB
    {max_message_size, 134217728},

    %% Consumer timeout (ms) — rejeitar consumers que não confirmam
    {consumer_timeout, 1800000},  %% 30 minutos

    %% Habilitar confirmação de canal (performance)
    {channel_tick_interval, 60000}
  ]},
  {rabbitmq_management, [
    {rates_mode, basic}    %% none | basic | detailed
  ]}
].
```

---

## Plugins — Essenciais

```bash
# /etc/rabbitmq/enabled_plugins
[rabbitmq_management,
 rabbitmq_prometheus,
 rabbitmq_shovel,
 rabbitmq_shovel_management,
 rabbitmq_delayed_message_exchange].

# Habilitar via CLI:
rabbitmq-plugins enable rabbitmq_management
rabbitmq-plugins enable rabbitmq_prometheus
rabbitmq-plugins enable rabbitmq_delayed_message_exchange
rabbitmq-plugins enable rabbitmq_shovel
```

| Plugin | Função |
|--------|--------|
| `rabbitmq_management` | UI web + HTTP REST API |
| `rabbitmq_prometheus` | Métricas Prometheus em `/metrics` (porta 15692) |
| `rabbitmq_delayed_message_exchange` | Exchange com delay configurável (scheduled messages) |
| `rabbitmq_shovel` | Mover mensagens entre brokers/vhosts |
| `rabbitmq_federation` | Federar exchanges/queues entre clusters |
| `rabbitmq_stream` | Protocolo RabbitMQ Streams |
| `rabbitmq_mqtt` | Suporte MQTT |
| `rabbitmq_stomp` | Suporte STOMP |

---

## Variáveis de Ambiente

| Variável | Padrão | Descrição |
|---------|--------|-----------|
| `RABBITMQ_DEFAULT_USER` | guest | Usuário padrão (só funciona no vhost /) |
| `RABBITMQ_DEFAULT_PASS` | guest | Senha padrão |
| `RABBITMQ_DEFAULT_VHOST` | / | VHost padrão |
| `RABBITMQ_NODENAME` | rabbit@hostname | Nome do nó Erlang |
| `RABBITMQ_CONFIG_FILE` | /etc/rabbitmq/rabbitmq | Caminho da config |
| `RABBITMQ_LOGS` | - | Arquivo de log (`-` = stdout) |
| `RABBITMQ_ERLANG_COOKIE` | (aleatório) | Cookie Erlang — **igual em todos os nós do cluster** |

---

## Clustering — Quorum Queues

```bash
# Configurar cluster de 3 nós (mínimo recomendado para quorum)

# No nó 2 e 3:
rabbitmqctl stop_app
rabbitmqctl reset
rabbitmqctl join_cluster rabbit@node1
rabbitmqctl start_app

# Verificar cluster
rabbitmqctl cluster_status
```

### Quorum Queue — Parâmetros Chave

| Argumento | Valor | Descrição |
|-----------|-------|-----------|
| `x-queue-type` | `quorum` | Tipo de fila |
| `x-quorum-initial-group-size` | `3` | Réplicas iniciais (padrão = cluster size) |
| `x-max-in-memory-length` | `0` | Limite de msgs em memória (0 = sem limite) |
| `x-dead-letter-exchange` | `"dlx.name"` | Exchange para mensagens mortas |
| `x-dead-letter-routing-key` | `"dead.key"` | Routing key para DLX |
| `x-message-ttl` | `86400000` | TTL em ms (24h) |
| `x-overflow` | `reject-publish` | Comportamento quando fila cheia (quorum: apenas este) |

---

## Management HTTP API — Endpoints Principais

```bash
BASE=http://admin:pass@localhost:15672/api

# Listar vhosts
GET $BASE/vhosts

# Listar queues
GET $BASE/queues
GET $BASE/queues/%2F          # vhost '/'

# Status de uma queue
GET $BASE/queues/%2F/my-queue

# Listar exchanges
GET $BASE/exchanges/%2F

# Bindings
GET $BASE/bindings/%2F

# Criar queue via API
curl -u admin:pass -X PUT http://localhost:15672/api/queues/%2F/my-queue \
  -H "Content-Type: application/json" \
  -d '{"durable":true,"arguments":{"x-queue-type":"quorum"}}'

# Publicar mensagem via API (apenas para testes)
curl -u admin:pass -X POST http://localhost:15672/api/exchanges/%2F/amq.default/publish \
  -H "Content-Type: application/json" \
  -d '{"properties":{},"routing_key":"my-queue","payload":"hello","payload_encoding":"string"}'

# Métricas de overview
GET $BASE/overview

# Connections ativas
GET $BASE/connections
```

---

## Prometheus — Métricas Chave

| Métrica | Alerta Sugerido |
|---------|----------------|
| `rabbitmq_queue_messages` | > threshold por fila |
| `rabbitmq_queue_messages_unacknowledged` | crescendo continuamente |
| `rabbitmq_queue_consumers` | = 0 (fila sem consumers) |
| `rabbitmq_connections` | alta taxa de open/close (connection churn) |
| `rabbitmq_process_resident_memory_bytes` | > 60% vm_memory_high_watermark |
| `rabbitmq_disk_space_available_bytes` | < disk_free_limit |
| `rabbitmq_node_mem_alarm` | = 1 (memory alarm ativo — flow control) |
| `rabbitmq_node_disk_free_alarm` | = 1 (disk alarm — publisher bloqueado) |

### Alert Rule Exemplo (PrometheusRule)

```yaml
- alert: RabbitMQQueueHasNoConsumers
  expr: rabbitmq_queue_consumers == 0 and rabbitmq_queue_messages > 0
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Queue {{ $labels.queue }} has messages but no consumers"

- alert: RabbitMQHighConnectionChurn
  expr: rate(rabbitmq_connections_opened_total[5m]) > 10
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "High connection churn detected — clients must use long-lived connections"

- alert: RabbitMQMemoryAlarm
  expr: rabbitmq_node_mem_alarm == 1
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "RabbitMQ memory alarm active — publishers blocked"
```

---

## CLI — rabbitmqctl Referência

```bash
rabbitmqctl status                        # status do nó
rabbitmqctl cluster_status                # estado do cluster
rabbitmqctl list_queues name messages consumers  # listar queues
rabbitmqctl list_exchanges                # listar exchanges
rabbitmqctl list_bindings                 # listar bindings
rabbitmqctl list_connections              # conexões ativas
rabbitmqctl list_channels                 # channels ativos
rabbitmqctl purge_queue <queue>           # limpar mensagens de uma fila
rabbitmqctl delete_queue <queue>          # deletar fila
rabbitmqctl set_policy <name> <pattern> <definition> --apply-to queues
rabbitmqctl add_user <user> <pass>
rabbitmqctl set_permissions -p / <user> ".*" ".*" ".*"
rabbitmqctl set_user_tags <user> administrator
rabbitmq-diagnostics check_running       # health check rápido
rabbitmq-diagnostics memory_breakdown    # breakdown de uso de memória
```
