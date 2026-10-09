# AGENTS.md — elasticsearch-expert

Skill **portável e self-contained**, pronta para múltiplos agentes de IA. Fonte única: `SKILL.md` (entrada) + `reference/*.md` (sob demanda). Qualquer agente que leia Markdown consome direto — **sem ferramenta de geração**.

## Uso por agente

| Agente | Como usar |
|---|---|
| Claude Code | Copiar a pasta para `.claude/skills/elasticsearch-expert/` (projeto) ou `~/.claude/skills/elasticsearch-expert/` (global). Aciona pela `description` do frontmatter. |
| Cursor | Referenciar `SKILL.md` em `.cursor/rules/*.mdc` ou @-mencionar no chat. |
| GitHub Copilot | Colar o conteúdo de `SKILL.md` em `.github/copilot-instructions.md`. |
| Windsurf / Cline | Copiar `SKILL.md` para o arquivo de regras do agente. |
| Opencode / genérico | Manter `AGENTS.md` + `SKILL.md` na raiz; apontar o agente para a pasta. |

## Regra de ouro

`SKILL.md` é a fonte única de verdade. `reference/` carrega sob demanda (progressive disclosure). Nada aqui depende de binário externo.

## Escopo

Especialista Elasticsearch em padrões de produção EVEO. Stack: Elasticsearch 8.x+ (security by default), clients @elastic/elasticsearch, elasticsearch-py, Java/Go, Kibana. Gera mappings explícitos, queries full-text, agregações, busca vetorial/híbrida (kNN, semantic_text, RRF), ILM, aliases e sync. Acione SEMPRE que mencionar Elasticsearch, ES, Kibana, full-text search, kNN, embeddings, hybrid/semantic search ou busca.
