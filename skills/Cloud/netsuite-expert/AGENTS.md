# AGENTS.md — netsuite-expert

Skill **portável e self-contained**, pronta para múltiplos agentes de IA. Fonte única: `SKILL.md` (entrada) + `reference/*.md` (sob demanda). Qualquer agente que leia Markdown consome direto — **sem ferramenta de geração**.

## Uso por agente

| Agente | Como usar |
|---|---|
| Claude Code | Copiar a pasta para `.claude/skills/netsuite-expert/` (projeto) ou `~/.claude/skills/netsuite-expert/` (global). Aciona pela `description` do frontmatter. |
| Cursor | Referenciar `SKILL.md` em `.cursor/rules/*.mdc` ou @-mencionar no chat. |
| GitHub Copilot | Colar o conteúdo de `SKILL.md` em `.github/copilot-instructions.md`. |
| Windsurf / Cline | Copiar `SKILL.md` para o arquivo de regras do agente. |
| Opencode / genérico | Manter `AGENTS.md` + `SKILL.md` na raiz; apontar o agente para a pasta. |

## Regra de ouro

`SKILL.md` é a fonte única de verdade. `reference/` carrega sob demanda (progressive disclosure). Nada aqui depende de binário externo.

## Escopo

Especialista sênior em Oracle NetSuite (ERP cloud, SuiteCloud). Gera SuiteScript 2.1 pronto para deploy (User Event, RESTlet, Map/Reduce, Scheduled, Suitelet, Client Script), planeja integração (SuiteTalk REST vs RESTlet vs SuiteQL), escreve SuiteQL, gera objetos SDF (XML) e configura OAuth 2.0 / TBA. Acionar SEMPRE que mencionar NetSuite, SuiteScript, SuiteFlow, SuiteTalk, RESTlet, Suitelet, SDF, SuiteQL, Map/Reduce NetSuite, N/record, N/search, N/query, @NScriptType, custscript/custbody/customrecord, TBA/OAuth NetSuite ou integração ERP.
