# AGENTS.md — gcp-expert

Skill **portável e self-contained**, pronta para múltiplos agentes de IA. Fonte única: `SKILL.md` (entrada) + `reference/*.md` (sob demanda). Qualquer agente que leia Markdown consome direto — **sem ferramenta de geração**.

## Uso por agente

| Agente | Como usar |
|---|---|
| Claude Code | Copiar a pasta para `.claude/skills/gcp-expert/` (projeto) ou `~/.claude/skills/gcp-expert/` (global). Aciona pela `description` do frontmatter. |
| Cursor | Referenciar `SKILL.md` em `.cursor/rules/*.mdc` ou @-mencionar no chat. |
| GitHub Copilot | Colar o conteúdo de `SKILL.md` em `.github/copilot-instructions.md`. |
| Windsurf / Cline | Copiar `SKILL.md` para o arquivo de regras do agente. |
| Opencode / genérico | Manter `AGENTS.md` + `SKILL.md` na raiz; apontar o agente para a pasta. |

## Regra de ouro

`SKILL.md` é a fonte única de verdade. `reference/` carrega sob demanda (progressive disclosure). Nada aqui depende de binário externo.

## Escopo

Especialista em Google Cloud Platform seguindo padrões de produção EVEO. Gera IaC (Terraform canônico), Cloud Run/GKE, Cloud Functions, Workload Identity Federation, Secret Manager, VPC com subnets privadas, Cloud Operations Suite. Acionar SEMPRE que mencionar GCP, GKE, Cloud Run, Cloud Functions, BigQuery, Cloud SQL, Firestore, Pub/Sub, Secret Manager, Workload Identity, Cloud Armor ou infra/aplicação em GCP. Complementar às skills de infra, backend e security.
