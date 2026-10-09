# Azure Expert — Stack Canônica

## Microsoft Azure — Versão Canônica EVEO

| Categoria | Serviço/Lib | Notas |
|-----------|------------|-------|
| **Compute** | | |
| Containers | Azure Container Apps (ACA) | Padrão EVEO para APIs e serviços. Serverless scaling. KEDA nativo |
| Containers alt | Azure Kubernetes Service (AKS) | Para workloads que precisam de controle de cluster |
| Functions | Azure Functions | v4 (isolated worker model). Trigger HTTP, Queue, Timer, Blob |
| VMs | Azure Virtual Machines | Para workloads que não containerizam. B-series para dev |
| **Storage** | | |
| Blobs | Azure Blob Storage | `Standard_LRS` para dev. `Standard_ZRS` para prod |
| Filas | Azure Queue Storage | Para filas simples. Service Bus para enterprise messaging |
| Tabelas | Azure Table Storage | NoSQL key-value simples. CosmosDB para queries complexas |
| Arquivos | Azure Files | SMB shares. Montagem em VMs e AKS |
| **Banco de Dados** | | |
| PostgreSQL | Azure Database for PostgreSQL Flexible Server | Padrão EVEO. Burstable para dev, Memory Optimized para prod |
| SQL Server | Azure SQL Database | Serverless para workloads intermitentes |
| NoSQL | Azure Cosmos DB | Multi-model. API compatível com MongoDB, PostgreSQL, Cassandra |
| Cache | Azure Cache for Redis | Standard (HA) ou Basic (dev) |
| **Mensageria** | | |
| Queues | Azure Service Bus | Enterprise messaging. Padrão EVEO para eventos assíncronos |
| Events | Azure Event Grid | Eventos de infra (Blob criado, VM iniciada) |
| Streaming | Azure Event Hubs | Kafka-compatible endpoint. Para ingestão de alto volume |
| **Segurança** | | |
| Segredos | Azure Key Vault | Secrets, certificates, keys. Obrigatório para credenciais |
| Identidade | Azure Active Directory / Entra ID | RBAC, Managed Identity (sem credentials no código) |
| API Gateway | Azure API Management (APIM) | Throttling, auth, portal de developer |
| Firewall | Azure Firewall / NSG | Network Security Groups para isolamento de redes |
| **DevOps** | | |
| CI/CD | Azure DevOps Pipelines | Padrão EVEO. Ver ADR-023 a ADR-027 |
| Registry | Azure Container Registry (ACR) | Padrão para imagens Docker |
| GitOps | Azure Arc + Flux | Para multi-cloud/hybrid |
| **Observabilidade** | | |
| Logs + Métricas | Azure Monitor + Log Analytics | Workspace centralizado de logs |
| APM | Application Insights | SDK para Node, .NET, Java, Python. Distributed tracing |
| Alertas | Azure Monitor Alerts | Via Action Groups (email, Teams, webhook) |
| Dashboards | Azure Workbooks | Dashboards customizados com Log Analytics queries |
| **Networking** | | |
| Virtual Network | Azure VNet | Isolamento de rede. Subnets por tier (app, db, mgmt) |
| Load Balancer | Azure Load Balancer / App Gateway | App Gateway: L7 com WAF. LB: L4 |
| DNS | Azure DNS + Private DNS Zones | Resolução privada para recursos internos |
| CDN | Azure Front Door | CDN + WAF + Global routing |

## Azure CLI — Comandos Essenciais

```bash
# Login e seleção de subscription
az login
az account set --subscription "EVEO Production"

# Criar Resource Group
az group create --name rg-myapp-prod --location brazilsouth

# Azure Container Apps — deploy
az containerapp create \
  --name api-myapp \
  --resource-group rg-myapp-prod \
  --environment env-myapp \
  --image myacr.azurecr.io/api:v1.0.0 \
  --target-port 3000 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 10 \
  --env-vars "DATABASE_URL=secretref:database-url" \
  --registry-server myacr.azurecr.io

# Key Vault — criar segredo
az keyvault secret set \
  --vault-name kv-myapp-prod \
  --name "database-url" \
  --value "postgresql://..."
```

## Azure SDK — Node.js/TypeScript

```typescript
// Dependências: @azure/identity @azure/keyvault-secrets
import { DefaultAzureCredential } from '@azure/identity';
import { SecretClient } from '@azure/keyvault-secrets';

// DefaultAzureCredential: Managed Identity em prod, az login em dev — sem código diferente
const credential = new DefaultAzureCredential();
const kvClient = new SecretClient('https://kv-myapp-prod.vault.azure.net', credential);

const secret = await kvClient.getSecret('database-url');
const dbUrl = secret.value!;
```
