# AGENTS.md — kubernetes-expert

Skill **portável e self-contained**, pronta para múltiplos agentes de IA. Fonte única: `SKILL.md` (entrada) + `reference/*.md` (sob demanda). Qualquer agente que leia Markdown consome direto — **sem ferramenta de geração**.

## Uso por agente

| Agente | Como usar |
|---|---|
| Claude Code | Copiar a pasta para `.claude/skills/kubernetes-expert/` (projeto) ou `~/.claude/skills/kubernetes-expert/` (global). Aciona pela `description` do frontmatter. |
| Cursor | Referenciar `SKILL.md` em `.cursor/rules/*.mdc` ou @-mencionar no chat. |
| GitHub Copilot | Colar o conteúdo de `SKILL.md` em `.github/copilot-instructions.md`. |
| Windsurf / Cline | Copiar `SKILL.md` para o arquivo de regras do agente. |
| Opencode / genérico | Manter `AGENTS.md` + `SKILL.md` na raiz; apontar o agente para a pasta. |

## Regra de ouro

`SKILL.md` é a fonte única de verdade. `reference/` carrega sob demanda (progressive disclosure). Nada aqui depende de binário externo.

## Escopo

Especialista em Kubernetes e Helm seguindo padrões de produção EVEO. Stack: K8s 1.31+, Helm 3, Kustomize, ArgoCD/Flux (GitOps), External Secrets, Kyverno/OPA, Prometheus. Gera manifests e Helm charts production-grade — Deployment, Service, Ingress, HPA, PDB, NetworkPolicy, RBAC, values por ambiente. Acionar SEMPRE que mencionar Kubernetes, K8s, kubectl, pod, deployment, service, ingress, Helm, chart, values.yaml, HPA, ArgoCD, GitOps ou orquestração de containers.
