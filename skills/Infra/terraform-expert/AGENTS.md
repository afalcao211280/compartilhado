# AGENTS.md — terraform-expert

Skill **portável e self-contained**, pronta para múltiplos agentes de IA. Fonte única: `SKILL.md` (entrada) + `reference/*.md` (sob demanda). Qualquer agente que leia Markdown consome direto — **sem ferramenta de geração**.

## Uso por agente

| Agente | Como usar |
|---|---|
| Claude Code | Copiar a pasta para `.claude/skills/terraform-expert/` (projeto) ou `~/.claude/skills/terraform-expert/` (global). Aciona pela `description` do frontmatter. |
| Cursor | Referenciar `SKILL.md` em `.cursor/rules/*.mdc` ou @-mencionar no chat. |
| GitHub Copilot | Colar o conteúdo de `SKILL.md` em `.github/copilot-instructions.md`. |
| Windsurf / Cline | Copiar `SKILL.md` para o arquivo de regras do agente. |
| Opencode / genérico | Manter `AGENTS.md` + `SKILL.md` na raiz; apontar o agente para a pasta. |

## Regra de ouro

`SKILL.md` é a fonte única de verdade. `reference/` carrega sob demanda (progressive disclosure). Nada aqui depende de binário externo.

## Escopo

Especialista em Terraform/OpenTofu (IaC) seguindo padrões de produção EVEO. Stack: Terraform 1.9+/OpenTofu, Terragrunt, tfenv, remote state com locking (Azure Blob/S3+DynamoDB/GCS), TFLint, checkov + tfsec, terraform-docs. Gera módulos reutilizáveis, environments dev/staging/prod, variable validation, outputs e pipelines plan→apply. Acionar SEMPRE que mencionar Terraform, OpenTofu, IaC, HCL, infrastructure as code, tfstate, módulo, provider, Terragrunt ou provisionamento de infra.
