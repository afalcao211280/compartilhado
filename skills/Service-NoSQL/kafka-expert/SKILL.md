---
name: kafka-expert
description: >
  Especialista Apache Kafka em padrões de produção EVEO. Stack: Kafka 4.0/3.9 (KRaft),
  clients Go/Python/Java-Spring/Node, Schema Registry, Kafka Streams, Connect. Gera
  producer/consumer completos, config de topics, DLT, exactly-once, Docker Compose e
  alertas de lag. Acione SEMPRE que mencionar Kafka, event streaming, topic, partition,
  producer/consumer, consumer group, offset, KRaft ou Kafka vs RabbitMQ.
version: "2.1.0"
category: Service-NoSQL
keywords:
  - kafka
  - event-streaming
  - messaging
  - pub-sub
  - topics
  - partitions
  - consumer-group
  - schema-registry
  - kafka-streams
  - exactly-once
globs:
  - "**/kafka*.{yml,yaml,properties,conf}"
  - "**/producer*.{go,py,java,ts}"
  - "**/consumer*.{go,py,java,ts}"
requires:
  - security-expert
---

# Kafka Expert — Padrões EVEO

Especialista sênior em Apache Kafka. Função **executiva**: gera código completo de
producer/consumer, configura cluster, topics e pipelines — não esqueletos comentados.

## Princípios

1. **`acks=all` + idempotência é o piso** — sem isso o cluster perde mensagens na falha de um broker. Idempotência elimina duplicatas em retry sem custo.
2. **Nunca auto-commit em consumer de negócio** — `enable.auto.commit=true` pode commitar antes do processamento terminar → mensagem perdida. Commit manual após o lote.
3. **`replication.factor=3` + `min.insync.replicas=2`** — sobrevive à falha de 1 broker. Menos que isso não é produção.
4. **`auto.offset.reset` explícito** — nunca confiar no padrão (`latest`); decidir `earliest` vs `latest` por caso.
5. **Dead Letter Topic sempre** — consumer de negócio sem DLT bloqueia ou descarta silenciosamente mensagens com falha.
6. **Partições ≥ consumers do grupo** — paralelismo é limitado pelo nº de partições; partições só aumentam, nunca diminuem. Planejar capacidade.

## Arquitetura Core

```
Producers ──► Topic (N partições) ──► Consumers (em Consumer Groups)
                    │
                    │  Cada partição:
                    │  ┌─────────────────────────────────┐
                    │  │ offset: 0  1  2  3  4  5  6 ... │
                    │  │ msgs:  [A][B][C][D][E][F][G] ... │  (imutável, append-only)
                    │  └─────────────────────────────────┘
                    │
                    ├── Replication: 1 Leader + N-1 Followers (ISR)
                    │   min.insync.replicas: mínimo de réplicas para aceitar escrita
                    │
                    └── Retention: por tempo (retention.ms) ou tamanho (retention.bytes)
                        Compaction: mantém apenas o último valor por key

Consumer Group:
  - Cada partição é atribuída a UM consumer do grupo (paralelismo ≤ N partições)
  - Grupos independentes: cada grupo lê todas as mensagens (event replay)
  - Offsets commitados em __consumer_offsets (interno)
```

## Tabela de Decisão — Garantias de Entrega

| Config Producer | Config Consumer | Garantia | Uso |
|----------------|-----------------|---------|-----|
| `acks=0` | auto-commit | At-most-once | Métricas não críticas |
| `acks=1` | auto-commit | At-most-once* | Logs, analytics |
| **`acks=all`** | **commit manual** | **At-least-once** | **Padrão produção** |
| `acks=all` + `enable.idempotence=true` + commit manual | At-least-once sem duplicatas | Padrão produção robusto |
| Transações (`transactional.id`) | `isolation.level=read_committed` | **Exactly-once** | Pagamentos, contabilidade |

## Tabela de Decisão — Configuração de Topic

| Cenário | `cleanup.policy` | `retention.ms` | `replication.factor` | `min.insync.replicas` |
|---------|-----------------|-----------------|----------------------|----------------------|
| Event log (time-based) | `delete` | `604800000` (7d) | 3 | 2 |
| Event sourcing / CDC | `compact` | `-1` (sem fim) | 3 | 2 |
| Compaction + delete | `compact,delete` | `86400000` (1d) | 3 | 2 |
| Alto volume, baixa criticidade | `delete` | `3600000` (1h) | 2 | 1 |
| Dev / teste | `delete` | `3600000` | 1 | 1 |

> **Regra de ouro**: `replication.factor=3` e `min.insync.replicas=2` em produção.
> Com `acks=all` + `min.insync.replicas=2`, o cluster suporta a falha de 1 broker
> sem perda de dados.

## Tabela de Decisão — Quando Usar Kafka vs RabbitMQ

| Critério | Kafka | RabbitMQ |
|---------|-------|---------|
| Volume de mensagens | Milhões/segundo | Dezenas de milhares/segundo |
| Replay de eventos | ✅ (por offset) | ❌ (mensagem consumida = removida) |
| Múltiplos consumer groups independentes | ✅ | ❌ (precisa de múltiplas filas) |
| Roteamento complexo por atributo | ❌ limitado | ✅ (exchanges, binding keys) |
| Latência ultra-baixa (<1ms) | ⚠️ (ms range) | ✅ (sub-ms possível) |
| Streams processing built-in | ✅ (Kafka Streams) | ❌ |
| Simplicidade de operação | ⚠️ (cluster complexo) | ✅ (mais simples) |
| CDC / Event sourcing | ✅ | ❌ |

## Padrões Obrigatórios de Produção

### Producer — Configuração Segura

```properties
# Obrigatório para durabilidade
acks=all
enable.idempotence=true
# Retry automático sem duplicatas (com idempotência habilitada)
retries=2147483647
max.in.flight.requests.per.connection=5   # máximo 5 com idempotência

# Performance (ajustar conforme latência tolerada)
linger.ms=5           # aguardar até 5ms para acumular batch
batch.size=65536      # 64KB por batch
compression.type=snappy  # snappy (velocidade) ou zstd (melhor ratio)
buffer.memory=33554432   # 32MB buffer local antes de bloquear
```

### Consumer — Configuração Segura

```properties
# Controle de offset: NUNCA auto-commit em processamento de negócio
enable.auto.commit=false
auto.offset.reset=earliest   # ou latest — decidir explicitamente, não confiar no padrão

# Proteção contra rebalance por lentidão
max.poll.records=500         # processar em lotes
max.poll.interval.ms=300000  # 5min — aumentar se processamento for lento
session.timeout.ms=45000     # 45s (deve ser < max.poll.interval.ms)
heartbeat.interval.ms=15000  # 1/3 do session.timeout

# Exactly-once: filtrar registros de transações abortadas
isolation.level=read_committed  # use com producers transacionais
```

### Topic — Criação Segura

```bash
kafka-topics.sh --create \
  --topic orders.created \
  --partitions 12 \             # múltiplos do número de consumers esperado
  --replication-factor 3 \      # sempre 3 em produção
  --config retention.ms=604800000 \
  --config min.insync.replicas=2 \
  --config compression.type=snappy \
  --bootstrap-server broker:9092
```

## Workflow Agentic — Como Gerar Soluções

### 1. Entender o cenário

Antes de gerar código:
- **Padrão**: event log? CDC? Kafka Streams (stateful processing)? Connect?
- **Volume**: msgs/segundo → impacta partições, batch.size, linger.ms
- **Garantia**: at-least-once (padrão) ou exactly-once (pagamentos, contabilidade)?
- **Consumer groups**: quantos consumidores diferentes leem o mesmo topic?
- **Retenção**: quanto tempo manter os eventos? Compaction (state) ou delete (log)?
- **Linguagem**: Go, Python, Java/Spring, Node.js?
- **Cluster**: Docker (dev)? KRaft (produção self-managed)? MSK? Confluent Cloud?
- **Schema**: JSON simples ou Avro/Protobuf com Schema Registry?

### 2. Gerar componentes em ordem

```
1. Topic declaration   → kafka-topics.sh ou AdminClient
2. Producer            → configuração + serialização + error handling
3. Consumer            → grupo, offset management, commit manual
4. Dead Letter Topic   → para mensagens com falha de processamento
5. Docker Compose      → broker KRaft single-node (dev)
6. Kafka Streams DSL   → se processamento stateful solicitado
7. Monitoramento       → consumer lag alert
```

### 3. Saída esperada

- **Código completo** sem TODO nem "implemente aqui"
- **Configuração explícita**: todo `acks`, `enable.auto.commit`, `auto.offset.reset` declarado
- **Dead Letter Topic**: sempre para consumers de negócio
- **Docker Compose** funcional para dev

## Checklist de Produção

- [ ] `acks=all` + `enable.idempotence=true` no producer
- [ ] `enable.auto.commit=false` no consumer com commit manual
- [ ] `auto.offset.reset` declarado explicitamente (`earliest` ou `latest`)
- [ ] `replication.factor=3` e `min.insync.replicas=2` nos topics
- [ ] Dead Letter Topic para mensagens não processáveis
- [ ] Consumer processa em lotes e commita após lote completo (não por mensagem)
- [ ] `max.poll.interval.ms` > tempo máximo de processamento por lote
- [ ] Partições ≥ número de consumers no grupo (paralelismo garantido)
- [ ] Alertas de consumer lag configurados (lag > threshold por N minutos)
- [ ] Credenciais via variáveis de ambiente (não no código)
- [ ] `compression.type=snappy` ou `zstd` nos topics de alto volume
- [ ] Schema Registry para Avro/Protobuf (evolução de schema compatível)

## Padrões Arquiteturais (event-driven)

- **Event Sourcing**: estado como sequência imutável de eventos; `cleanup.policy=compact` + KTable para reconstruir estado sem replay O(N).
- **CQRS**: separar modelo de escrita (comando) do de leitura; Kafka como event store; projeções read-optimized via Connect → banco.
- **Saga**: transações distribuídas entre serviços; cada passo publica evento; compensação em falha; `correlation_id` para rastrear a instância.
- **CDC (Change Data Capture)**: Debezium captura mudanças do banco como eventos; base de sync MongoDB/Postgres → Kafka → Elasticsearch/Solr.

## Referências (sob demanda — progressive disclosure)

Leia conforme a tarefa (não entram no contexto automaticamente):

- **`reference/patterns.md`** — Código canônico: Go (kafka-go/segmentio), Python (confluent-kafka), Java/Spring Kafka, Node.js (kafkajs); Kafka Streams DSL (KTable, windowing); Kafka Connect source/sink; Schema Registry Avro; producer transacional (exactly-once); consumer com commit manual e Dead Letter Topic; Docker Compose KRaft; 8 anti-patterns ❌/✅. **Leia SEMPRE ao gerar código ou configuração.**
- **`reference/stack.md`** — Versões Kafka/Confluent, Docker images, clients por linguagem, propriedades completas de producer/consumer/broker/topic, KRaft, SSL/SASL, CLI (kafka-topics, kafka-consumer-groups), Schema Registry API, métricas JMX e alertas de lag. **Leia ao configurar cluster, segurança ou verificar propriedades.**

## Cross-references

- `security-expert` — SSL/SASL, ACLs, secrets, rotação de credenciais.
- `rabbitmq-expert` — mensageria com roteamento complexo/baixa latência (ver tabela Kafka vs RabbitMQ).
- Skills de backend (golang/java/python/node) — camada de aplicação do producer/consumer.

## Segurança (Baseline Compartilhado)

Regras universais em `reference/security-baseline.md`. Ameaças específicas do domínio Kafka:

- **SSL/TLS in-transit**: `security.protocol=SASL_SSL`; nunca PLAINTEXT em produção. mTLS (`ssl.client.auth=required`) entre brokers.
- **Autenticação SASL/SCRAM-SHA-512** (mais seguro que PLAIN) ou OAUTHBEARER. Rotação regular de credenciais.
- **Autorização por ACLs**: privilégio mínimo por principal; separar read/write por topic. Deny-by-default.
- **`auto.create.topics.enable=false`**: topics auto-criados herdam defaults inseguros (RF=1, sem `min.insync.replicas`).
- **Credenciais** via env/secret manager, nunca em `server.properties` versionado nem em logs.