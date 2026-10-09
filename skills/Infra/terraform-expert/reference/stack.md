# Terraform Expert — Stack Canônica

## Terraform 1.9+ / OpenTofu 1.8+ — Versão Canônica EVEO

| Categoria | Ferramenta | Versão | Link | Notas |
|-----------|-----------|--------|------|-------|
| **Core** | | | | |
| IaC | Terraform | 1.9+ | https://terraform.io | HashiCorp BSL license (1.6+). Padrão EVEO |
| IaC alt | OpenTofu | 1.8+ | https://opentofu.org | Fork open-source. Drop-in substituto. MPL 2.0 |
| **Providers Principais** | | | | |
| Azure | hashicorp/azurerm | ~> 3.100 | https://registry.terraform.io/providers/hashicorp/azurerm | Padrão EVEO Azure |
| AWS | hashicorp/aws | ~> 5.50 | https://registry.terraform.io/providers/hashicorp/aws | |
| GCP | hashicorp/google | ~> 5.30 | https://registry.terraform.io/providers/hashicorp/google | |
| Kubernetes | hashicorp/kubernetes | ~> 2.30 | https://registry.terraform.io/providers/hashicorp/kubernetes | |
| Helm | hashicorp/helm | ~> 2.13 | https://registry.terraform.io/providers/hashicorp/helm | |
| **State Backend** | | | | |
| Azure | azurerm (Blob Storage) | — | — | Padrão EVEO Azure |
| AWS | S3 + DynamoDB lock | — | — | Padrão EVEO AWS |
| GCP | GCS | — | — | Padrão EVEO GCP |
| SaaS | Terraform Cloud / HCP Terraform | — | https://app.terraform.io | VCS-driven workflows |
| **Módulos** | | | | |
| Registry | Terraform Registry | — | https://registry.terraform.io/modules | Módulos públicos versionados |
| Estrutura | Local modules + Git modules | — | — | `source = "../modules/ecs"` ou `git::` |
| **Qualidade** | | | | |
| Formatter | `terraform fmt` | built-in | — | Sempre no CI |
| Linter | TFLint | 0.51+ | https://github.com/terraform-linters/tflint | Regras por provider |
| Security | tfsec / Trivy | — | https://github.com/aquasecurity/tfsec | Misconfigurations de segurança |
| Checkov | Checkov | 3.x | https://www.checkov.io | Políticas de compliance |
| Testing | Terratest | 0.46+ | https://github.com/gruntwork-io/terratest | Testes de infraestrutura em Go |
| Testing alt | `terraform test` | built-in 1.6+ | — | HCL-native test framework |
| **Fluxo de Trabalho** | | | | |
| Plan/Apply | `terraform plan -out=tfplan` → `terraform apply tfplan` | — | — | Nunca apply sem plan |
| Automação | Atlantis | 0.27+ | https://www.runatlantis.io | PR-based workflow |
| CI | GitHub Actions / Azure Pipelines | — | — | Plan no PR, Apply no merge |

## Estrutura de Diretórios — Padrão EVEO

```
infra/
├── environments/
│   ├── dev/
│   │   ├── main.tf          # Apenas chamadas de módulos
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   └── prod/
└── modules/
    ├── container-app/       # Módulo reutilizável
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── postgres/
    └── networking/
```

## Versão de Provider — sempre fixar

```hcl
terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"  # permite patch updates, bloqueia minor/major
    }
  }
}
```
