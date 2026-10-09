# AGENTS.md — criar-story-devops

Skill **portável e self-contained**, pronta para múltiplos agentes de IA. Fonte única: `SKILL.md` (entrada) + `reference/*.md` (sob demanda). Qualquer agente que leia Markdown consome direto — **sem ferramenta de geração**.

## Uso por agente

| Agente | Como usar |
|---|---|
| Claude Code | Copiar a pasta para `.claude/skills/criar-story-devops/` (projeto) ou `~/.claude/skills/criar-story-devops/` (global). Aciona pela `description` do frontmatter. |
| Cursor | Referenciar `SKILL.md` em `.cursor/rules/*.mdc` ou @-mencionar no chat. |
| GitHub Copilot | Colar o conteúdo de `SKILL.md` em `.github/copilot-instructions.md`. |
| Windsurf / Cline | Copiar `SKILL.md` para o arquivo de regras do agente. |
| Opencode / genérico | Manter `AGENTS.md` + `SKILL.md` na raiz; apontar o agente para a pasta. |

## Regra de ouro

`SKILL.md` é a fonte única de verdade. `reference/` carrega sob demanda (progressive disclosure). Nada aqui depende de binário externo.

## Escopo

Cria e amadurece work items User Story no Azure DevOps (org eveo-workspaces, projeto ENGSOFT) no padrão EVEO. Busca o padrão na wiki ENGSOFT em tempo de execução (fonte da verdade — nunca de memória), monta Description + Acceptance Criteria (Gherkin) + Refinamento Técnico e roda o fluxo de estados via MCP azure-devops. Acionar SEMPRE que pedirem: "cria uma story", "criar story no devops", "abre uma US", "monta a story", "refina essa story", "transforma isso em story".
