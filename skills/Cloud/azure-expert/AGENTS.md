# AGENTS.md — azure-expert

Skill **portável e self-contained**, pronta para múltiplos agentes de IA. Fonte única: `SKILL.md` (entrada) + `reference/*.md` (sob demanda). Qualquer agente que leia Markdown consome direto — **sem ferramenta de geração**.

## Uso por agente

| Agente | Como usar |
|---|---|
| Claude Code | Copiar a pasta para `.claude/skills/azure-expert/` (projeto) ou `~/.claude/skills/azure-expert/` (global). Aciona pela `description` do frontmatter. |
| Cursor | Referenciar `SKILL.md` em `.cursor/rules/*.mdc` ou @-mencionar no chat. |
| GitHub Copilot | Colar o conteúdo de `SKILL.md` em `.github/copilot-instructions.md`. |
| Windsurf / Cline | Copiar `SKILL.md` para o arquivo de regras do agente. |
| Opencode / genérico | Manter `AGENTS.md` + `SKILL.md` na raiz; apontar o agente para a pasta. |

## Regra de ouro

`SKILL.md` é a fonte única de verdade. `reference/` carrega sob demanda (progressive disclosure). Nada aqui depende de binário externo.

## Escopo

Especialista em Microsoft Azure seguindo padrões de produção EVEO. Gera IaC (Bicep canônico), Azure Container Apps/AKS, Azure Functions, Managed Identity, Key Vault, VNet + NSG + Private Endpoints, Azure Monitor. Acionar SEMPRE que mencionar Azure, AKS, ACA, App Service, Azure SQL, Cosmos DB, Azure Functions, Key Vault, Bicep, Service Bus, Front Door, Managed Identity ou infra/aplicação em Azure. Complementar às skills de infra, backend e security.
