# Azure Expert — Padrões de Código

## 1. Terraform — Infraestrutura Azure (alternativa multi-cloud)

> **Nota EVEO**: o IaC canônico para Azure é **Bicep** (ver SKILL.md e ADR-013). Os exemplos Terraform (`azurerm`) abaixo permanecem válidos como alternativa **apenas quando o projeto exigir multi-cloud** — não são o padrão.

```hcl
# main.tf — Resource Group + Container App
terraform {
  required_version = ">= 1.8"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformeveo"
    container_name       = "tfstate"
    key                  = "myapp/prod.tfstate"
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.app_name}-${var.environment}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${var.app_name}-${var.environment}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

resource "azurerm_container_app" "api" {
  name                         = "ca-api-${var.environment}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    identity             = azurerm_user_assigned_identity.main.id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }

  ingress {
    target_port      = 3000
    external_enabled = true
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = 1
    max_replicas = 10

    container {
      name   = "api"
      image  = "${azurerm_container_registry.main.login_server}/api:${var.image_tag}"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }
      env {
        name  = "NODE_ENV"
        value = "production"
      }

      liveness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 3000
      }
    }

    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = "100"
    }
  }

  secret {
    name                = "database-url"
    key_vault_secret_id = azurerm_key_vault_secret.database_url.versionless_id
    identity            = azurerm_user_assigned_identity.main.id
  }
}
```

---

## 2. Azure Functions — Isolated Worker (Node.js)

```typescript
// src/functions/processQueue.ts
import { app, type ServiceBusQueueTrigger } from '@azure/functions';

interface OrderMessage {
  orderId: string;
  userId: string;
  amount: number;
}

app.serviceBusQueue('processOrder', {
  queueName: 'orders',
  connection: 'SERVICE_BUS_CONNECTION',
  handler: async (message: unknown, context) => {
    const order = message as OrderMessage;
    context.log(`Processing order: ${order.orderId}`);

    try {
      // processar pedido
      context.log(`Order ${order.orderId} processed successfully`);
    } catch (err) {
      context.error(`Failed to process order ${order.orderId}:`, err);
      throw err; // dead-letter após max retries
    }
  },
});

// HTTP trigger
app.http('healthCheck', {
  methods: ['GET'],
  authLevel: 'anonymous',
  route: 'health',
  handler: async (_req, context) => {
    context.log('Health check requested');
    return { status: 200, jsonBody: { status: 'healthy', timestamp: new Date().toISOString() } };
  },
});
```

---

## 3. Application Insights — Telemetria

```typescript
// src/lib/telemetry.ts — inicializar ANTES de imports de app
import { setup, start, defaultClient } from 'applicationinsights';

export function initTelemetry(): void {
  if (!process.env['APPLICATIONINSIGHTS_CONNECTION_STRING']) return;

  setup(process.env['APPLICATIONINSIGHTS_CONNECTION_STRING'])
    .setAutoCollectRequests(true)
    .setAutoCollectPerformance(true)
    .setAutoCollectExceptions(true)
    .setAutoCollectDependencies(true)
    .setUseDiskRetryCaching(true)
    .start();
}

export function trackEvent(name: string, properties?: Record<string, string>): void {
  defaultClient?.trackEvent({ name, properties });
}

export function trackException(error: Error, properties?: Record<string, string>): void {
  defaultClient?.trackException({ exception: error, properties });
}
```

---

## 4. Managed Identity — Acesso a Recursos

```typescript
// src/lib/azure-storage.ts — usar Managed Identity, nunca connection strings
import { BlobServiceClient } from '@azure/storage-blob';
import { DefaultAzureCredential } from '@azure/identity';

const credential = new DefaultAzureCredential();
// Em ACA/AKS: usa Managed Identity automaticamente
// Em local dev: usa `az login` ou AZURE_CLIENT_ID/TENANT_ID/CLIENT_SECRET

export const blobClient = new BlobServiceClient(
  `https://${process.env['STORAGE_ACCOUNT_NAME']}.blob.core.windows.net`,
  credential,
);

export async function uploadBlob(
  containerName: string,
  blobName: string,
  content: Buffer,
): Promise<string> {
  const containerClient = blobClient.getContainerClient(containerName);
  await containerClient.createIfNotExists();
  const blockBlobClient = containerClient.getBlockBlobClient(blobName);
  await blockBlobClient.uploadData(content);
  return blockBlobClient.url;
}
```

---

## 5. Service Bus — Producer + Consumer (NestJS)

```typescript
// src/azure/service-bus.service.ts
import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { ServiceBusClient, type ServiceBusSender, type ServiceBusReceiver } from '@azure/service-bus';
import { DefaultAzureCredential } from '@azure/identity';

@Injectable()
export class ServiceBusService implements OnModuleDestroy {
  private readonly client: ServiceBusClient;
  private readonly senders = new Map<string, ServiceBusSender>();

  constructor() {
    // Sem connection string — Managed Identity
    this.client = new ServiceBusClient(
      `${process.env['SERVICE_BUS_NAMESPACE']}.servicebus.windows.net`,
      new DefaultAzureCredential(),
    );
  }

  async send(queueName: string, message: unknown): Promise<void> {
    let sender = this.senders.get(queueName);
    if (!sender) {
      sender = this.client.createSender(queueName);
      this.senders.set(queueName, sender);
    }
    await sender.sendMessages({ body: message, contentType: 'application/json' });
  }

  createReceiver(queueName: string): ServiceBusReceiver {
    return this.client.createReceiver(queueName);
  }

  async onModuleDestroy(): Promise<void> {
    for (const sender of this.senders.values()) await sender.close();
    await this.client.close();
  }
}
```

---

## 6. Azure DevOps Pipeline — Container Apps Deploy

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include: [main]

pool:
  vmImage: ubuntu-latest

variables:
  imageTag: $(Build.BuildId)
  acrName: myacr
  containerAppName: ca-api-prod
  resourceGroup: rg-myapp-prod

stages:
  - stage: Build
    jobs:
      - job: BuildAndPush
        steps:
          - task: AzureCLI@2
            displayName: Build and push image
            inputs:
              azureSubscription: 'EVEO-ServiceConnection'
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                az acr build \
                  --registry $(acrName) \
                  --image api:$(imageTag) \
                  --file Dockerfile .

  - stage: Deploy
    dependsOn: Build
    condition: succeeded()
    jobs:
      - deployment: DeployToACA
        environment: production
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  displayName: Update Container App revision
                  inputs:
                    azureSubscription: 'EVEO-ServiceConnection'
                    scriptType: bash
                    scriptLocation: inlineScript
                    inlineScript: |
                      az containerapp update \
                        --name $(containerAppName) \
                        --resource-group $(resourceGroup) \
                        --image $(acrName).azurecr.io/api:$(imageTag)
```

---

## Anti-patterns

### ❌ Secrets hardcoded em appsettings.json ou variáveis de ambiente
**Problema:** Armazenar connection strings, API keys e senhas diretamente em `appsettings.json` ou na config do App Service.
**Por quê evitar:** Qualquer pessoa com acesso ao repositório ou ao portal Azure vê o segredo — rotação é manual e propensa a erros.
**Solução:**
```csharp
// Use Key Vault + Managed Identity — sem segredo no código
builder.Configuration.AddAzureKeyVault(
    new Uri($"https://{kvName}.vault.azure.net/"),
    new DefaultAzureCredential()); // lê da Managed Identity em prod, az login em dev
```

### ❌ Service Principal com Client Secret em vez de Managed Identity
**Problema:** Criar Service Principal com `clientSecret` para que aplicações Azure acessem outros recursos.
**Por quê evitar:** Segredos de SP expiram, precisam de rotação manual e são frequentemente vazados em logs, variáveis de ambiente e pipelines.
**Solução:**
```bash
# Habilitar System-assigned Managed Identity no resource
az containerapp identity assign --name minha-api --resource-group rg-prod --system-assigned
# Atribuir RBAC ao identity (não ao Service Principal)
az role assignment create --role "Storage Blob Data Reader" --assignee <principal-id> --scope /subscriptions/.../storageAccounts/...
```

### ❌ DefaultAzureCredential sem AZURE_CLIENT_ID para Managed Identity user-assigned
**Problema:** Usar `DefaultAzureCredential()` sem especificar `AZURE_CLIENT_ID` quando há múltiplas Managed Identities user-assigned no recurso.
**Por quê evitar:** `DefaultAzureCredential` não sabe qual identity usar — falha com erro confuso de "Multiple managed identities found".
**Solução:**
```python
from azure.identity import DefaultAzureCredential, ManagedIdentityCredential

# Em prod com user-assigned MI, especifique o client_id
credential = ManagedIdentityCredential(client_id=os.environ["AZURE_CLIENT_ID"])
```

### ❌ Containers ACA/AKS sem resource limits
**Problema:** Não definir `cpu` e `memory` nos containers do Azure Container Apps ou AKS.
**Por quê evitar:** Um container pode consumir todos os recursos do nó (noisy neighbor), causando OOMKill em outros pods ou escalando desnecessariamente.
**Solução:**
```yaml
# AKS Deployment
resources:
  requests:
    cpu: "250m"
    memory: "256Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

### ❌ Service Bus sem processamento idempotente
**Problema:** Processar mensagens do Service Bus assumindo entrega exatamente uma vez.
**Por quê evitar:** Service Bus garante *at-least-once* — mensagens podem ser reenviadas após falha. Sem idempotência, operações como débito/crédito são duplicadas.
**Solução:**
```csharp
// Use MessageId como chave de idempotência
var alreadyProcessed = await _cache.ExistsAsync($"sb:processed:{message.MessageId}");
if (alreadyProcessed) { await args.CompleteMessageAsync(message); return; }
// processa...
await _cache.SetAsync($"sb:processed:{message.MessageId}", true, TimeSpan.FromDays(1));
```

### ❌ Azure Functions em Consumption plan para workloads latency-sensitive
**Problema:** Usar Consumption plan para Functions que respondem a chamadas síncronas de usuários.
**Por quê evitar:** Cold starts de 1-5 segundos em Consumption plan são inaceitáveis para APIs — use Premium plan (pre-warmed instances) ou ACA.
**Solução:**
```hcl
resource "azurerm_service_plan" "func" {
  sku_name = "EP1"  # Elastic Premium — sem cold start
  # ou migre para Azure Container Apps (mais flexível)
}
```

### ❌ ACR sem Content Trust ou imagens sem tag imutável
**Problema:** Usar tag `latest` para imagens em produção ou não habilitar quarentena no ACR.
**Por quê evitar:** Tag `latest` não é imutável — um redeploy pode puxar imagem diferente da que foi testada; sem content trust, imagens adulteradas podem ser executadas.
**Solução:**
```bash
# Use digest SHA256 imutável em prod
IMAGE="myacr.azurecr.io/api@sha256:abc123..."
# ou tag com git SHA
IMAGE="myacr.azurecr.io/api:$(git rev-parse --short HEAD)"
```
