# Terraform Expert — Padrões de Código

## 1. Estrutura de Módulo Reutilizável

```hcl
# modules/container-app/variables.tf
variable "app_name" {
  type        = string
  description = "Name of the application"
}

variable "environment" {
  type        = string
  description = "Environment (dev, staging, prod)"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "image_tag" {
  type        = string
  description = "Docker image tag to deploy"
}

variable "min_replicas" {
  type    = number
  default = 1
}

variable "max_replicas" {
  type    = number
  default = 10
}

variable "secrets" {
  type = map(object({
    key_vault_secret_id = string
    identity_id         = string
  }))
  default     = {}
  description = "Map of environment variable name to Key Vault secret reference"
}

# modules/container-app/outputs.tf
output "url" {
  value       = azurerm_container_app.main.latest_revision_fqdn
  description = "Container App URL"
}

output "principal_id" {
  value       = azurerm_user_assigned_identity.main.principal_id
  description = "Managed Identity principal ID for role assignments"
}
```

---

## 2. Módulo Chamado no Environment

```hcl
# environments/prod/main.tf
module "api" {
  source = "../../modules/container-app"

  app_name    = "myapp-api"
  environment = "prod"
  image_tag   = var.image_tag

  min_replicas = 2
  max_replicas = 20

  secrets = {
    "DATABASE_URL" = {
      key_vault_secret_id = module.keyvault.database_url_secret_id
      identity_id         = module.identity.id
    }
  }
}

module "keyvault" {
  source = "../../modules/keyvault"

  name        = "kv-myapp-prod"
  environment = "prod"
}

# Outputs para uso em outros sistemas
output "api_url" {
  value = module.api.url
}
```

---

## 3. Locals e Tags Padrão

```hcl
# locals.tf — em cada environment
locals {
  common_tags = {
    Environment  = var.environment
    Application  = var.app_name
    ManagedBy    = "terraform"
    Repository   = "github.com/eveo/myapp"
    CostCenter   = var.cost_center
    Owner        = var.team_email
  }

  # Naming convention: resource-type-app-environment
  naming = {
    resource_group  = "rg-${var.app_name}-${var.environment}"
    container_app   = "ca-${var.app_name}-${var.environment}"
    keyvault        = "kv-${var.app_name}-${substr(var.environment, 0, 4)}"
    acr             = "acr${replace(var.app_name, "-", "")}${var.environment}"
  }
}

# Aplicar tags em todos os recursos
resource "azurerm_resource_group" "main" {
  name     = local.naming.resource_group
  location = var.location
  tags     = local.common_tags
}
```

---

## 4. Remote State + Data Sources

```hcl
# Ler outputs de outro state (ex: networking de outro workspace)
data "terraform_remote_state" "networking" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformeveo"
    container_name       = "tfstate"
    key                  = "networking/prod.tfstate"
  }
}

# Usar outputs do outro state
resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${var.app_name}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  infrastructure_subnet_id   = data.terraform_remote_state.networking.outputs.subnet_id
  log_analytics_workspace_id = data.terraform_remote_state.networking.outputs.log_analytics_id
}

# Data source para resource já existente
data "azurerm_container_registry" "shared" {
  name                = "acrsharedeveo"
  resource_group_name = "rg-shared"
}
```

---

## 5. `terraform test` (built-in 1.6+)

```hcl
# modules/container-app/tests/basic.tftest.hcl
variables {
  app_name    = "test-app"
  environment = "dev"
  image_tag   = "latest"
}

run "valid_environment" {
  command = plan

  assert {
    condition     = azurerm_container_app.main.name == "ca-test-app-dev"
    error_message = "Container app name format is incorrect"
  }
}

run "reject_invalid_environment" {
  command = plan

  variables {
    environment = "invalid"
  }

  expect_failures = [var.environment]
}
```

---

## 6. Pipeline CI/CD — GitHub Actions

```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  pull_request:
    paths: ['infra/**']
  push:
    branches: [main]
    paths: ['infra/**']

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  terraform:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: infra/environments/prod

    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.8.5"

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Terraform Init
        run: terraform init

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: TFLint
        uses: terraform-linters/setup-tflint@v4
        continue-on-error: false

      - name: Terraform Plan
        id: plan
        run: terraform plan -out=tfplan -var="image_tag=${{ github.sha }}"

      - name: Comment PR with plan
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const output = `#### Terraform Plan 📖\`${{ steps.plan.outcome }}\`
            <details><summary>Show Plan</summary>
            \`\`\`hcl\n${{ steps.plan.outputs.stdout }}\n\`\`\`
            </details>`;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply tfplan
```

---

## 7. Comandos Operacionais

```bash
# Inicializar com upgrade de providers
terraform init -upgrade

# Planejar para um recurso específico
terraform plan -target=module.api.azurerm_container_app.main

# Importar recurso existente para o state
terraform import azurerm_resource_group.main /subscriptions/xxx/resourceGroups/rg-myapp-prod

# Remover do state sem destruir (recurso gerenciado manualmente)
terraform state rm azurerm_resource_group.main

# Ver dependências
terraform graph | dot -Tsvg > graph.svg

# Taint (forçar recriação)
terraform taint module.api.azurerm_container_app.main

# Unlock state preso
terraform force-unlock LOCK_ID
```

---

## Anti-patterns

### ❌ State local em vez de remote backend
**Problema:** Deixar `terraform.tfstate` localmente sem configurar backend remoto.
**Por quê evitar:** Sem backend remoto não há state locking — dois `terraform apply` simultâneos corrompem o state; o state fica perdido se o disco falhar; trabalho em equipe é impossível.
**Solução:**
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformeveo"
    container_name       = "tfstate"
    key                  = "producao/api.tfstate"
  }
}
```

### ❌ Secrets hardcoded em arquivos .tf
**Problema:** Colocar passwords, API keys ou connection strings diretamente em variáveis ou resource attributes no código Terraform.
**Por quê evitar:** Qualquer pessoa com acesso ao repositório vê o segredo; o state file também armazena o valor em texto claro (state é sensível).
**Solução:**
```hcl
# Use variável marcada como sensitive + passe via env ou vault
variable "db_password" {
  type      = string
  sensitive = true  # não aparece em planos/logs
}
# Passe via: TF_VAR_db_password=secret terraform apply
# Ou use: data "azurerm_key_vault_secret" "db_password" { ... }
```

### ❌ Provider versions sem constraint
**Problema:** Não especificar `version` ou usar `version = ">= 3.0"` sem upper bound.
**Por quê evitar:** Um `terraform init` em uma nova máquina pode baixar uma versão major diferente com breaking changes — builds não são reprodutíveis.
**Solução:**
```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"  # aceita 3.100.x mas não 4.x
    }
  }
}
# Commite o .terraform.lock.hcl para garantir versões exatas
```

### ❌ terraform apply sem revisar o plan
**Problema:** Executar `terraform apply` diretamente sem fazer `terraform plan` e revisar as mudanças.
**Por quê evitar:** Recursos podem ser destroyed e recriados (replace) sem aviso visual — banco de dados, load balancer, VMs deletadas por mudança de atributo imutável.
**Solução:**
```bash
# Sempre: plan → revisar → apply com plan file salvo
terraform plan -out=tfplan
# Revisar CUIDADOSAMENTE: quantos add/change/DESTROY?
terraform apply tfplan
```

### ❌ count em vez de for_each para coleções
**Problema:** Usar `count = length(var.environments)` para criar recursos de uma lista ou mapa.
**Por quê evitar:** `count` indexa por número — se você remove o item do meio da lista, o Terraform destrói e recria todos os recursos com índice maior (incluindo banco de dados de produção).
**Solução:**
```hcl
# NUNCA: count com lista
resource "azurerm_resource_group" "envs" {
  count = length(var.environments)
  name  = var.environments[count.index]
}

# SEMPRE: for_each com map — deletar um item não afeta outros
resource "azurerm_resource_group" "envs" {
  for_each = toset(var.environments)
  name     = each.value
}
```

### ❌ Módulo monolítico root sem separação
**Problema:** Colocar todos os recursos (VNet, banco, AKS, ACA, DNS) em um único módulo root.
**Por quê evitar:** `terraform plan` demora minutos e locks todo o state — um erro numa resource derruba todo o apply; a "blast radius" de uma mudança inclui toda a infra.
**Solução:**
```
environments/
  prod/
    networking/  → terraform apply independente
    database/    → terraform apply independente
    app/         → terraform apply independente (usa remote_state para pegar outputs)
```

### ❌ Recursos stateful sem lifecycle prevent_destroy
**Problema:** Não proteger bancos de dados, buckets e outros recursos com dados contra destruição acidental.
**Por quê evitar:** Uma mudança de atributo imutável, um refactor de module ou um `terraform destroy` apaga permanentemente dados de produção.
**Solução:**
```hcl
resource "azurerm_postgresql_flexible_server" "main" {
  # ...
  lifecycle {
    prevent_destroy = true  # terraform plan falha se tentar destruir
  }
}
```

---

## 8. Multi-cloud — Módulo AWS (VPC + ALB)

Padrão AWS: backend S3 + DynamoDB lock, `default_tags` no provider, VPC com subnets pública/privada e NAT.

```hcl
# versions.tf
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.50" }
  }
  backend "s3" {
    bucket         = "terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true            # encryption at rest
    dynamodb_table = "terraform-locks"  # state locking
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = var.project_name
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${var.project_name}-vpc" }
}

# for_each com toset — remover uma AZ não recria as outras (evita count)
resource "aws_subnet" "public" {
  for_each                = toset(var.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public-${each.key}" }
}

resource "aws_lb" "main" {
  name                       = "${var.project_name}-alb"
  load_balancer_type         = "application"
  subnets                    = [for s in aws_subnet.public : s.id]
  enable_deletion_protection = var.environment == "production"  # protege prod
}
```

```hcl
# variables.tf — validation + tipos explícitos
variable "environment" {
  type        = string
  description = "Ambiente (dev, staging, production)"
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment deve ser dev, staging ou production."
  }
}

variable "public_subnets" {
  type        = list(string)
  description = "CIDRs das subnets públicas"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# outputs.tf — sempre com description
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}
output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "DNS do ALB"
}
```

---

## 9. Script de Deploy (alternativa a CI, com workspaces)

Quando não há Atlantis/Actions, um wrapper reproduz `fmt`→`validate`→`plan`/`apply` por ambiente. Em produção prefira o pipeline (§6).

```bash
#!/bin/bash
# deploy.sh <ambiente> <plan|apply|destroy>
set -euo pipefail
ENVIRONMENT="${1:-dev}"
ACTION="${2:-plan}"
cd terraform

terraform init -upgrade
terraform fmt -recursive -check .
terraform validate
terraform workspace select -or-create "$ENVIRONMENT"

case "$ACTION" in
  plan)
    terraform plan -var-file="environments/$ENVIRONMENT.tfvars" -out="tfplan-$ENVIRONMENT" ;;
  apply)
    terraform apply "tfplan-$ENVIRONMENT" ;;   # aplica o plan revisado (não -auto-approve cego)
  destroy)
    read -p "Destruir $ENVIRONMENT? (yes/no): " c
    [ "$c" = "yes" ] && terraform destroy -var-file="environments/$ENVIRONMENT.tfvars" ;;
  *) echo "Ação inválida: $ACTION"; exit 1 ;;
esac
```

> `workspace` isola state por ambiente num mesmo backend. Para isolamento forte (state/backend separados por ambiente), prefira a estrutura de diretórios `environments/<env>/` (ver `stack.md`).
