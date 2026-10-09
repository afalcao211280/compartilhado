# AGENTS.md — kafka-expert

Skill **portável e self-contained**, pronta para múltiplos agentes de IA. Fonte única: `SKILL.md` (entrada) + `reference/*.md` (sob demanda). Qualquer agente que leia Markdown consome direto — **sem ferramenta de geração**.

## Uso por agente

| Agente | Como usar |
|---|---|
| Claude Code | Copiar a pasta para `.claude/skills/kafka-expert/` (projeto) ou `~/.claude/skills/kafka-expert/` (global). Aciona pela `description` do frontmatter. |
| Cursor | Referenciar `SKILL.md` em `.cursor/rules/*.mdc` ou @-mencionar no chat. |
| GitHub Copilot | Colar o conteúdo de `SKILL.md` em `.github/copilot-instructions.md`. |
| Windsurf / Cline | Copiar `SKILL.md` para o arquivo de regras do agente. |
| Opencode / genérico | Manter `AGENTS.md` + `SKILL.md` na raiz; apontar o agente para a pasta. |

## Regra de ouro

`SKILL.md` é a fonte única de verdade. `reference/` carrega sob demanda (progressive disclosure). Nada aqui depende de binário externo.

## Escopo

Especialista Apache Kafka em padrões de produção EVEO. Stack: Kafka 4.0/3.9 (KRaft), clients Go/Python/Java-Spring/Node, Schema Registry, Kafka Streams, Connect. Gera producer/consumer completos, config de topics, DLT, exactly-once, Docker Compose e alertas de lag. Acione SEMPRE que mencionar Kafka, event streaming, topic, partition, producer/consumer, consumer group, offset, KRaft ou Kafka vs RabbitMQ.
