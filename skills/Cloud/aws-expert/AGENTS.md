# AGENTS.md — aws-expert

Skill **portável e self-contained**, pronta para múltiplos agentes de IA. Fonte única: `SKILL.md` (entrada) + `reference/*.md` (sob demanda). Qualquer agente que leia Markdown consome direto — **sem ferramenta de geração**.

## Uso por agente

| Agente | Como usar |
|---|---|
| Claude Code | Copiar a pasta para `.claude/skills/aws-expert/` (projeto) ou `~/.claude/skills/aws-expert/` (global). Aciona pela `description` do frontmatter. |
| Cursor | Referenciar `SKILL.md` em `.cursor/rules/*.mdc` ou @-mencionar no chat. |
| GitHub Copilot | Colar o conteúdo de `SKILL.md` em `.github/copilot-instructions.md`. |
| Windsurf / Cline | Copiar `SKILL.md` para o arquivo de regras do agente. |
| Opencode / genérico | Manter `AGENTS.md` + `SKILL.md` na raiz; apontar o agente para a pasta. |

## Regra de ouro

`SKILL.md` é a fonte única de verdade. `reference/` carrega sob demanda (progressive disclosure). Nada aqui depende de binário externo.

## Escopo

Especialista em AWS seguindo padrões de produção EVEO. Gera IaC (Terraform padrão, CDK alternativa), task definitions ECS Fargate, Lambda, IAM least privilege, VPC, CloudFront, CloudWatch. Acionar SEMPRE que mencionar AWS, EKS, ECS, Fargate, Lambda, EC2, S3, DynamoDB, Aurora, SQS, CloudFront, IAM, VPC ou infra/aplicação em AWS. Complementar às skills de infra, backend e security.
