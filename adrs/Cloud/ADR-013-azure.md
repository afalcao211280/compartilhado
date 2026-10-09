# ADR-013: Azure — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Projetos Azure na EVEO exigem padronização de IaC, compute, database, security, e monitoramento. A ausência de diretrizes resulta em ARM JSON verbose, resource groups sem tags, secrets hardcoded, e endpoints públicos sem WAF. Azure é a cloud principal para ecossistema Microsoft.

## Decisão

Azure como cloud principal para ecossistema Microsoft. Bicep canônico para IaC (nunca ARM JSON). Managed Identity para auth (nunca shared access keys). Key Vault para secrets. App Configuration para configs. Azure Monitor + Log Analytics para observabilidade. Tags obrigatórios em todos os resources.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| IaC | Bicep | — | ARM JSON, Terraform | Declarativo, type-safe, Azure-native |
| Compute | AKS + App Service | — | Functions, Container Apps | AKS para microserviços, App Service para web |
| Database | Azure SQL, Cosmos DB | — | PostgreSQL Flexible, MySQL Flexible | SQL Server para relational, Cosmos para NoSQL |
| Secrets | Key Vault | — | App Configuration (configs apenas) | HSM, soft-delete, purge protection |
| Auth | Managed Identity (MSI) | — | Service Principals, Shared Access Keys | Sem secrets no código |
| Config | App Configuration | — | env vars soltas, Key Vault (configs) | Feature flags, dynamic reload |
| Observabilidade | Azure Monitor + Log Analytics | — | App Insights standalone, Grafana | Logs e métricas centralizados |
| CDN/Front Door | Azure Front Door | — | Application Gateway, CDN | WAF, global routing, SSL offload |
| Storage | Blob Storage + Data Lake | — | Files, NetApp | Block blobs, hierarchical namespace |
| Messaging | Service Bus | — | Event Grid, Storage Queues | Enterprise messaging, topics |
| Cache | Azure Cache for Redis | — | In-proc cache | Distributed cache, session |
| CI/CD | Azure DevOps / GitHub Actions | — | — | Deploy Bicep + apps |
| Networking | VNet + NSGs + Private Endpoints | — | Public endpoints | Zero-trust, deny-by-default |

## Padrões Obrigatórios

- **Bicep para IaC**. Nunca ARM JSON. Nunca deploy manual.
  ```bicep
  param location string = resourceGroup().location
  param environment string
  
  resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
    name: 'kv-${environment}'
    location: location
    properties: {
      enableSoftDelete: true
      enablePurgeProtection: true
      tenantId: subscription().tenantId
    }
  }
  ```
- **Resource Groups por ambiente**: `rg-app-dev`, `rg-app-staging`, `rg-app-prod`.
- **Managed Identity** sempre. Não service principals com secrets. Não shared access keys.
  ```bicep
  resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = { ... }
  ```
- **Key Vault** para secrets e certs. Soft-delete + purge protection habilitados.
- **App Configuration** para configs (feature flags, non-secret configs). Não env vars soltas.
- **NSGs deny-by-default**. Apenas regras explícitas para acesso.
- **Private Endpoints** para PaaS services. Sem public access em produção.
- **Tags obrigatórias**: `env`, `team`, `cost-center`, `app`.
- **Azure Monitor + Log Analytics** para logs e métricas centralizados.
- **WAF** no App Gateway/Front Door para endpoints públicos.
- **Azure AD** para auth. Não custom auth systems.
- **Encryption**: at rest (platform-managed ou customer-managed keys) + in transit (TLS 1.2+).
- **Azure Policy** para compliance — deny non-compliant resources.

## Estrutura de Projeto — Bicep

```
infra/
├── main.bicep                    # Orquestração principal
├── main.parameters.json          # Parâmetros por ambiente
├── modules/
│   ├── appservice.bicep
│   ├── aks.bicep
│   ├── keyvault.bicep
│   ├── sqlserver.bicep
│   ├── vnet.bicep
│   ├── appconfiguration.bicep
│   └── monitoring.bicep
├── policies/
│   ├── deny-public-endpoints.bicep
│   └── require-tags.bicep
└── scripts/
    ├── deploy.sh
    └── validate.sh
```

## Anti-padrões

| Proibido | Alternativa |
|---|---|
| ARM JSON | Bicep |
| Deploy manual | IaC (Bicep) via pipeline |
| Shared access keys em código | Managed Identity |
| Resource Groups sem tags | Tags obrigatórias: `env`, `team`, `cost-center`, `app` |
| Public endpoints sem WAF | Front Door / App Gateway com WAF |
| Secrets em env vars ou config files | Key Vault |
| Configs hardcoded | App Configuration |
| Service Principals com secrets | Managed Identity |
| `any` type em Bicep | Type annotations explícitas |
| PaaS com public access em produção | Private Endpoints |

## Consequências

**Positivas**:
- Bicep é declarativo, type-safe, e Azure-native — melhor DX que ARM JSON
- Managed Identity elimina secrets no código e rotation manual
- Key Vault com soft-delete previne perda acidental de secrets
- App Configuration permite feature flags e dynamic reload sem redeploy
- Private Endpoints eliminam superfície de ataque pública

**Negativas**:
- Bicep é Azure-only — lock-in para IaC (Terraform seria multi-cloud)
- Private Endpoints adicionam custo e complexidade de DNS
- Managed Identity requer configuração por resource

**Riscos**:
- Lock-in Azure — migração para outra cloud requer rewrite de IaC
- Key Vault throttling com alto volume — usar caching de tokens
- App Configuration vs Key Vault boundary — configs não sensíveis em App Configuration, secrets em Key Vault

## Referências

- `skills/Cloud/azure-expert/SKILL.md`
- Documentação Bicep: https://learn.microsoft.com/azure/azure-resource-manager/bicep/
- Documentação Azure Monitor: https://learn.microsoft.com/azure/azure-monitor/
- Documentação Key Vault: https://learn.microsoft.com/azure/key-vault/