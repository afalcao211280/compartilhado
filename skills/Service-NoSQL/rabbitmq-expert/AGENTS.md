# AGENTS.md — rabbitmq-expert

Skill **portável e self-contained**, pronta para múltiplos agentes de IA. Fonte única: `SKILL.md` (entrada) + `reference/*.md` (sob demanda). Qualquer agente que leia Markdown consome direto — **sem ferramenta de geração**.

## Uso por agente

| Agente | Como usar |
|---|---|
| Claude Code | Copiar a pasta para `.claude/skills/rabbitmq-expert/` (projeto) ou `~/.claude/skills/rabbitmq-expert/` (global). Aciona pela `description` do frontmatter. |
| Cursor | Referenciar `SKILL.md` em `.cursor/rules/*.mdc` ou @-mencionar no chat. |
| GitHub Copilot | Colar o conteúdo de `SKILL.md` em `.github/copilot-instructions.md`. |
| Windsurf / Cline | Copiar `SKILL.md` para o arquivo de regras do agente. |
| Opencode / genérico | Manter `AGENTS.md` + `SKILL.md` na raiz; apontar o agente para a pasta. |

## Regra de ouro

`SKILL.md` é a fonte única de verdade. `reference/` carrega sob demanda (progressive disclosure). Nada aqui depende de binário externo.

## Escopo

Especialista RabbitMQ (broker AMQP 0-9-1) em padrões de produção EVEO. Stack: RabbitMQ 3.13 LTS/4.x, clients Go (amqp091-go)/Python (pika/aio-pika)/Java-Spring/Node (amqplib), quorum queues, Prometheus. Gera producer/consumer completos, topologia exchange/queue/binding, DLX/DLQ, publisher confirms, clustering. Acione SEMPRE que mencionar RabbitMQ, AMQP, exchange, queue, binding, routing key, DLX, prefetch, quorum queue ou RabbitMQ vs Kafka.
