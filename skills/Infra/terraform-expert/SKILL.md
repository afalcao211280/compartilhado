---
name: terraform-expert
description: >
  Especialista em Terraform/OpenTofu (IaC) seguindo padrões de produção EVEO.
  Stack: Terraform 1.9+/OpenTofu, Terragrunt, tfenv, remote state com locking
  (Azure Blob/S3+DynamoDB/GCS), TFLint, checkov + tfsec, terraform-docs. Gera
  módulos reutilizáveis, environments dev/staging/prod, variable validation,
  outputs e pipelines plan→apply. Acionar SEMPRE que mencionar Terraform,
  OpenTofu, IaC, HCL, infrastructure as code, tfstate, módulo, provider,
  Terragrunt ou provisionamento de infra.
version: "2.1.0"
category: Infra
keywords:
  - terraform
  - opentofu
  - iac
  - hcl
  - terragrunt
  - tfstate
  - module
requires:
  - security-expert
---

# Terraform Expert — Padrões EVEO

Especialista Terraform/OpenTofu. IaC que entra em produção: state gerenciado, módulos reutilizáveis, plan revisado. Zero exemplo educativo.

## Princípios

1. **If it's not in Terraform, it doesn't exist** — mudança manual na cloud é drift; toda infra nasce e muda por código versionado + PR.
2. **Remote state com locking** — nunca state local em produção. Sem locking, dois `apply` simultâneos corrompem o state; sem backend remoto, trabalho em equipe é impossível.
3. **State por ambiente separado** — dev/staging/prod com state isolado. Blast radius de uma mudança fica contido a um ambiente.
4. **Módulos com responsabilidade única** — um módulo por concern (networking, database, app), versionado por semver. Módulo monolítico faz `plan` demorar e um erro derruba todo o apply.
5. **Plan antes de apply, sempre** — `plan -out=tfplan` → revisar add/change/**DESTROY** → `apply tfplan`. `apply` cego recria banco de produção por mudança de atributo imutável.
6. **`for_each` sobre `count` em coleções** — `count` indexa por número: remover item do meio destrói e recria todos os seguintes. `for_each` com map isola cada recurso.
7. **Sem secrets no state/código** — state guarda valores em texto claro. Secrets via Key Vault/Vault + `sensitive = true`; recursos stateful com `prevent_destroy`.

> Módulos e environments prontos para commit e PR.

## Stack Canônica

| Categoria | Ferramenta | Versão | Notas |
|---|---|---|---|
| IaC Engine | Terraform **ou** OpenTofu | 1.9+ / 1.8+ | OpenTofu: fork MPL 2.0, drop-in. Decisão por projeto (sem default) |
| DRY multi-env | Terragrunt | 0.55+ | DRY de backend/provider, dependency management |
| Version Manager | tfenv / tenv | 3.x / 1.x | Lock de versão por projeto |
| State Backend | Azure Blob **/** S3+DynamoDB **/** GCS | — | Por cloud. Azure é padrão EVEO. Locking + encryption at rest |
| Formatter | `terraform fmt` | built-in | Sempre no CI (`-check -recursive`) |
| Linter | TFLint | 0.51+ | Regras por provider |
| Security | checkov + tfsec | 3.x + 1.x | Quality gate no CI. CIS benchmarks |
| Docs | terraform-docs | 0.17+ | README automático (hook pre-commit) |
| Testing | `terraform test` / Terratest | built-in 1.6+ / 0.46+ | HCL-native ou Go |
| Policy as Code | OPA / Sentinel | 0.58+ / Enterprise | Guardrails de compliance |
| Automação PR | Atlantis | 0.27+ | Plan no PR, apply no merge |

> **Remote state com locking, módulos versionados, `plan`→`apply` e checkov+tfsec são fixos.** Terraform vs OpenTofu é decisão por projeto. Backend varia por cloud.
> **PERGUNTAR ao usuário**: cloud (Azure/AWS/GCP)? Terraform ou OpenTofu? usa Terragrunt? quantos ambientes? Atlantis ou pipeline próprio?

## Providers Principais

| Cloud | Provider | Constraint sugerido |
|---|---|---|
| Azure (padrão EVEO) | `hashicorp/azurerm` | `~> 3.100` |
| AWS | `hashicorp/aws` | `~> 5.50` |
| GCP | `hashicorp/google` | `~> 5.30` |
| Kubernetes | `hashicorp/kubernetes` | `~> 2.30` |
| Helm | `hashicorp/helm` | `~> 2.13` |

## Estrutura de Projeto (multi-environment)

```
infra/
├── modules/                    # Módulos reutilizáveis (1 concern cada)
│   ├── networking/
│   ├── container-app/
│   ├── postgres/
│   └── keyvault/
├── environments/
│   ├── dev/     { main.tf (só chamadas de módulo), variables.tf, outputs.tf, terraform.tfvars }
│   ├── staging/
│   └── prod/
└── _common/
    ├── provider.hcl            # provider compartilhado (Terragrunt)
    └── backend.hcl             # backend compartilhado (Terragrunt)
```

Módulo: `main.tf` · `variables.tf` (com validation) · `outputs.tf` (com description) · `versions.tf` · `locals.tf` · `data.tf` · `README.md` (terraform-docs) · `examples/basic/`.

## Workflow Agentic

1. **Entender escopo** — qual cloud? recurso novo ou existente? quantos ambientes? já existe módulo reutilizável?
2. **Decidir estrutura** — módulo reutilizável (recomendado) vs recurso direto no environment. Terragrunt se multi-env com DRY.
3. **Gerar de dentro pra fora**:
   - `modules/<x>/`: `versions.tf` (constraints) → `variables.tf` (type + validation) → `main.tf` → `outputs.tf` (com description) → `examples/basic/`.
   - `environments/<env>/main.tf`: chamadas de módulo + `locals` (tags padrão + naming) + `backend` remoto.
   - `prevent_destroy` em recursos stateful (DB, storage).
   - Pipeline: `fmt -check` → `validate` → TFLint → checkov/tfsec → `plan` (comenta no PR) → `apply` no merge.
4. **Validar** — `terraform fmt -check -recursive`; `terraform validate`; `tflint`; conferir remote state, validation, `sensitive`, `for_each` (não `count`), `prevent_destroy`.
5. **Apresentar diff** — "criei/editei: A, B, C; decisão: módulo pq reuso multi-env".

## Anti-padrões Críticos

- ❌ State local em produção (sem locking → corrupção em apply concorrente; perda se o disco falhar).
- ❌ Secrets em `.tf` ou variável (o state guarda em texto claro — usar Key Vault + `sensitive = true`).
- ❌ `terraform apply` sem revisar o `plan` (recursos podem ser replaced/destroyed sem aviso — DB apagado).
- ❌ `count` para coleções (remover item do meio recria todos os seguintes — usar `for_each` com map).
- ❌ Provider sem constraint / sem upper bound (major com breaking change em `init` — usar `~> x.y` + commitar `.terraform.lock.hcl`).
- ❌ Módulo com `source` em branch (`main`) — não reproduzível; usar tag semver.
- ❌ Recurso stateful sem `lifecycle { prevent_destroy = true }` (refactor de módulo apaga dados de produção).
- ❌ Módulo monolítico root (VNet+DB+AKS+DNS num state só) — `plan` lento, blast radius = toda a infra.
- ❌ Hardcoded values em recursos (usar `variables`); IDs hard-coded (usar `data` sources).
- ❌ `apply` manual em produção (usar CI/CD com plan revisado); ignorar drift.
- ❌ `.terraform/` e `.tfvars` sensíveis no Git (adicionar ao `.gitignore`).

## Checklist

- [ ] Remote state com locking + encryption at rest
- [ ] State separado por ambiente (dev/staging/prod)
- [ ] Módulos versionados por semver (nunca branch como source)
- [ ] `variable` com type + validation
- [ ] `output` com description
- [ ] Provider constraint (`~> x.y`) + `.terraform.lock.hcl` commitado
- [ ] `for_each` (não `count`) para coleções
- [ ] `sensitive = true` em variáveis secretas; secrets via Key Vault
- [ ] `prevent_destroy` em recursos stateful (DB, storage)
- [ ] `.gitignore`: `.terraform/`, `*.tfvars` sensíveis
- [ ] `checkov` + `tfsec` + TFLint no CI (quality gate)
- [ ] README via `terraform-docs`
- [ ] Pipeline: `plan` no PR → revisão → `apply` no merge

## Quando Perguntar

Antes de gerar: cloud (Azure/AWS/GCP)? Terraform ou OpenTofu (fork MPL)? usa Terragrunt para DRY? quantos ambientes? automação via Atlantis ou pipeline próprio (GitHub Actions/Azure Pipelines)? Vault ou key vault nativo da cloud para secrets?

## Referências (sob demanda — progressive disclosure)

Leia conforme a tarefa (não entram no contexto automaticamente):

- **`reference/core.md`** — HCL pronto: módulo reutilizável (variables/outputs), chamada no environment, locals + tags padrão + naming, remote state + `data` sources, `terraform test`, pipeline GitHub Actions (OIDC, plan no PR), comandos operacionais (import, state rm, force-unlock, taint), anti-patterns detalhados com solução. Leia antes de gerar qualquer HCL.
- **`reference/stack.md`** — Stack canônica: versões, providers e constraints por cloud, state backends, ferramentas de qualidade/teste, estrutura de diretórios EVEO, template de `required_providers`.

## Cross-references

- `azure-expert` — provider azurerm, Bicep vs Terraform, multi-subscription
- `aws-expert` — provider aws, multi-account
- `gcp-expert` — provider google, org policies
- `kubernetes-expert` — provisionar cluster (AKS/EKS/GKE) via Terraform
- `security-expert` — IaC scanning, secrets management, least-privilege IAM

## Segurança (Baseline Compartilhado)

Regras universais em `reference/security-baseline.md`. Aqui só ameaças específicas do domínio:

- **Sem secrets no state** — state é sensível (texto claro); usar Key Vault/Vault + `sensitive = true`.
- **State encryption at rest** + backend com locking; acesso ao state restrito.
- **checkov + tfsec no CI** como quality gate (CIS benchmarks; shift-left).
- **Least privilege** para a identidade que roda o Terraform (Service Principal/IAM Role mínimo).
- **`prevent_destroy`** em recursos com dados (databases, storage accounts).

> **Atenção**: o padrão EVEO é **remote state com locking + módulos versionados + `plan` revisado + checkov/tfsec**. `terraform apply` manual em produção é proibido — usar CI/CD. Terraform (BSL) e OpenTofu (MPL 2.0, fork) são intercambiáveis; migração entre eles exige teste de compatibilidade.
