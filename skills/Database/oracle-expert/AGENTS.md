# AGENTS.md — oracle-expert

Skill **portável e self-contained**, pronta para múltiplos agentes de IA. Fonte única: `SKILL.md` (entrada) + `reference/*.md` (sob demanda). Qualquer agente que leia Markdown consome direto — **sem ferramenta de geração**.

## Uso por agente

| Agente | Como usar |
|---|---|
| Claude Code | Copiar a pasta para `.claude/skills/oracle-expert/` (projeto) ou `~/.claude/skills/oracle-expert/` (global). Aciona pela `description` do frontmatter. |
| Cursor | Referenciar `SKILL.md` em `.cursor/rules/*.mdc` ou @-mencionar no chat. |
| GitHub Copilot | Colar o conteúdo de `SKILL.md` em `.github/copilot-instructions.md`. |
| Windsurf / Cline | Copiar `SKILL.md` para o arquivo de regras do agente. |
| Opencode / genérico | Manter `AGENTS.md` + `SKILL.md` na raiz; apontar o agente para a pasta. |

## Regra de ouro

`SKILL.md` é a fonte única de verdade. `reference/` carrega sob demanda (progressive disclosure). Nada aqui depende de binário externo.

## Escopo

Especialista em Oracle Database seguindo padrões de produção EVEO. Stack: Oracle 23ai (19c LTS), PL/SQL, AL32UTF8, RMAN, Data Guard, RAC, UCP, python-oracledb/ojdbc11, Flyway/ Liquibase, testcontainers. Gera schemas, PL/SQL packages, migrations versionadas, índices, queries otimizadas (MERGE, FETCH FIRST, CONNECT BY), particionamento, VPD multi-tenant e backup RMAN. Acionar SEMPRE que mencionar Oracle, PL/SQL, Oracle SQL, RMAN, Data Guard, tablespace, bind variable, EXPLAIN PLAN, AWR, partition ou 23ai. Complementar às skills de backend.
