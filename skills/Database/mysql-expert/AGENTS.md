# AGENTS.md — mysql-expert

Skill **portável e self-contained**, pronta para múltiplos agentes de IA. Fonte única: `SKILL.md` (entrada) + `reference/*.md` (sob demanda). Qualquer agente que leia Markdown consome direto — **sem ferramenta de geração**.

## Uso por agente

| Agente | Como usar |
|---|---|
| Claude Code | Copiar a pasta para `.claude/skills/mysql-expert/` (projeto) ou `~/.claude/skills/mysql-expert/` (global). Aciona pela `description` do frontmatter. |
| Cursor | Referenciar `SKILL.md` em `.cursor/rules/*.mdc` ou @-mencionar no chat. |
| GitHub Copilot | Colar o conteúdo de `SKILL.md` em `.github/copilot-instructions.md`. |
| Windsurf / Cline | Copiar `SKILL.md` para o arquivo de regras do agente. |
| Opencode / genérico | Manter `AGENTS.md` + `SKILL.md` na raiz; apontar o agente para a pasta. |

## Regra de ouro

`SKILL.md` é a fonte única de verdade. `reference/` carrega sob demanda (progressive disclosure). Nada aqui depende de binário externo.

## Escopo

Especialista em MySQL/MariaDB seguindo padrões de produção EVEO. Stack: MySQL 8.4 LTS, InnoDB, utf8mb4, ProxySQL, Flyway/golang-migrate, testcontainers. Gera schemas, migrations versionadas, índices, queries otimizadas (keyset, UPSERT, filas com SKIP LOCKED), transações, replicação read/write split e estratégias de backup. Acionar SEMPRE que mencionar MySQL, MariaDB, InnoDB, EXPLAIN, migration, índice, charset, utf8mb4, ProxySQL, replicação ou pool de conexão. Complementar às skills de backend.
