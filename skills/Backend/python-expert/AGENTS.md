# AGENTS.md — python-expert

Skill **portável e self-contained**, pronta para múltiplos agentes de IA. Fonte única: `SKILL.md` (entrada) + `reference/*.md` (sob demanda). Qualquer agente que leia Markdown consome direto — **sem ferramenta de geração**.

## Uso por agente

| Agente | Como usar |
|---|---|
| Claude Code | Copiar a pasta para `.claude/skills/python-expert/` (projeto) ou `~/.claude/skills/python-expert/` (global). Aciona pela `description` do frontmatter. |
| Cursor | Referenciar `SKILL.md` em `.cursor/rules/*.mdc` ou @-mencionar no chat. |
| GitHub Copilot | Colar o conteúdo de `SKILL.md` em `.github/copilot-instructions.md`. |
| Windsurf / Cline | Copiar `SKILL.md` para o arquivo de regras do agente. |
| Opencode / genérico | Manter `AGENTS.md` + `SKILL.md` na raiz; apontar o agente para a pasta. |

## Regra de ouro

`SKILL.md` é a fonte única de verdade. `reference/` carrega sob demanda (progressive disclosure). Nada aqui depende de binário externo.

## Escopo

Engenheiro sênior Python, padrões de produção EVEO. Use SEMPRE que houver Python, .py, requirements.txt, pyproject.toml, Django, FastAPI, Flask ou projeto Python. AGENTIC: gera features completas (routes, schemas, services, repositories, tests, migrations) e scaffold, Clean Architecture. Stack: Python 3.13, FastAPI, Django, SQLAlchemy 2, Pydantic v2, pytest, Celery+Redis, PostgreSQL (asyncpg/psycopg3), Docker. Acionar em "API Python", "microsserviço", "scaffold", "worker Celery", "cria migration", "novo endpoint".
