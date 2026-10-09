# ADR-018: Terraform/OpenTofu — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Infraestrutura como código é fundamental para reprodutibilidade, auditoria e governança. Sem padronização, drift de configuração, state corrompido e módulos não versionados comprometem a operação multi-cloud da EVEO.

## Decisão

Adotar Terraform 1.7+ (ou OpenTofu como fork compatível) com remote state com locking, módulos versionados, Terragrunt para DRY em multi-environment, e scanning de segurança (checkov/tfsec) no CI.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| IaC Engine | Terraform / OpenTofu | 1.7+ / 1.8+ | Pulumi, CDKTF | OpenTofu: fork open-source; Terraform: ecossistema maduro |
| DRY Tool | Terragrunt | 0.55+ | tfvars + symlinks | DRY para multi-env, remote state, dependency management |
| Version Manager | tfenv / tenv | 3.x / 1.x | asdf | Especializado em Terraform, lock de versão por projeto |
| State Backend | Azure Blob Storage | - | S3, GCS, Consul | Integração nativa Azure, locking nativo |
| Security Scanner | checkov + tfsec | 3.x + 1.x | KICS, Terrascan | checkov: CIS benchmarks; tfsec: regras customizáveis |
| Documentation | terraform-docs | 0.17+ | tfdocsdot | Gera README automaticamente a partir de módulos |
| Policy as Code | OPA / Sentinel | 0.58+ / Enterprise | checkov policies | OPA: open-source; Sentinel: Terraform Enterprise |

## Padrões Obrigatórios

### Remote State

- Remote state obrigatório (nunca local em produção)
- Backend: Azure Blob Storage com locking habilitado
- State encryption at rest
- State file por ambiente separado (`env:dev`, `env:staging`, `env:prod`)
- `.gitignore` para `.tfvars` sensíveis e `.terraform/`

### Módulos

- Módulos versionados com tags semver (nunca `main` branch como source)
- Registry local ou Terraform Registry para compartilhamento
- `variable validation` em todas as variáveis de entrada
- Outputs documentados e tipados
- README gerado com `terraform-docs` (hook pre-commit)

### Multi-Environment

- Estrutura de diretórios por ambiente:

```
infra/
├── modules/                   # Módulos reutilizáveis
│   ├── networking/
│   ├── aks/
│   ├── sql/
│   └── app-service/
├── envs/
│   ├── dev/
│   │   ├── terragrunt.hcl
│   │   └── main.tf
│   ├── staging/
│   │   ├── terragrunt.hcl
│   │   └── main.tf
│   └── prod/
│       ├── terragrunt.hcl
│       └── main.tf
└── _common/
    ├── provider.hcl            # Provider config compartilhado
    └── backend.hcl             # Backend config compartilhado
```

### Segurança

- Nenhum secret em state (usar Vault ou cloud-native key vault)
- `.tfvars` sensível em `.gitignore`
- `checkov` + `tfsec` no CI como quality gate
- CIS benchmarks compliance
- Least privilege para Terraform IAM/ServiceAccount
- `prevent_destroy` para recursos críticos (databases, storage accounts)

## Estrutura de Projeto / Configuração

### Template de Módulo

```
modules/meu-recurso/
├── main.tf                    # Recurso principal
├── variables.tf               # Variáveis de entrada com validation
├── outputs.tf                 # Outputs documentados
├── versions.tf                # Provider version constraints
├── locals.tf                  # Valores computados
├── data.tf                    # Data sources
├── README.md                  # Gerado por terraform-docs
├── .terraform-docs.yml        # Config do terraform-docs
└── examples/
    └── basic/
        └── main.tf            # Exemplo de uso
```

### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.88.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
      - id: terraform_tflint
      - id: checkov
```

## Anti-padrões

- State local em produção
- Módulos com source em branch (sem versionamento)
- Hardcoded values em recursos (usar variables)
- Secret em state ou variável (usar Key Vault)
- Executar `terraform apply` manualmente em produção (usar CI/CD)
- Não usar `prevent_destroy` em recursos críticos
- Deixar `.terraform/` e `.tfvars` no Git
- Ignorar drift de configuração
- Módulos monolíticos (um módulo para tudo)
- Não versionar provider constraints

## Con sequências

**Positivas:**
- Infra reprodutível e versionada (GitOps para infra)
- Auditabilidade: toda mudança é review via PR
- DRY com Terragrunt em multi-environment
- Security scanning automatizado (shift-left)
- Documentação automática com terraform-docs

**Negativas:**
- Curva de aprendizado HCL + Terragrunt
- State locking pode causar bloqueios em pipelines concorrentes
- Refactoring de state é complexo (state mv)
- OpenTofu é fork recente — compatibilidade futura incerta

**Riscos:**
- Drift manual fora do Terraform — mitigar com policies e auditoria
- State file grande — usar partial plan/apply com `-target`
- Migração Terraform → OpenTofu requer teste de compatibilidade

## Referências

- `skills/Infra/terraform-expert/SKILL.md`
- Terraform Best Practices: https://www.terraform-best-practices.com/
- Terragrunt: https://terragrunt.gruntwork.io/
- checkov: https://www.checkov.io/
- tfsec: https://aquasecurity.github.io/tfsec/
- ADR-016 (Docker) — container registry provisioned via Terraform
- ADR-017 (Kubernetes) — AKS cluster provisioned via Terraform
- ADR-022 (CI/CD) — terraform plan/apply no pipeline
- ADR-025 (CI/CD Pipelines) — IaC no pipeline Azure DevOps