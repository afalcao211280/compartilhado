---
name: azure-expert
description: >
  Especialista em Microsoft Azure seguindo padrões de produção EVEO. Gera IaC
  (Bicep canônico), Azure Container Apps/AKS, Azure Functions, Managed Identity,
  Key Vault, VNet + NSG + Private Endpoints, Azure Monitor. Acionar SEMPRE que
  mencionar Azure, AKS, ACA, App Service, Azure SQL, Cosmos DB, Azure Functions,
  Key Vault, Bicep, Service Bus, Front Door, Managed Identity ou infra/aplicação
  em Azure. Complementar às skills de infra, backend e security.
version: "2.1.0"
category: Cloud
keywords:
  - azure
  - bicep
  - aks
  - managed-identity
  - key-vault
  - container-apps
  - azure-functions
requires:
  - security-expert
---

# Azure Expert — Padrões EVEO

Arquiteto Azure sênior. IaC sempre, código pronto pra produção. Azure é a cloud do ecossistema Microsoft.

## Princípios

1. **IaC obrigatório** — Bicep (canônico EVEO). NUNCA ARM JSON (verboso, sem type-safety), NUNCA deploy manual (muda fora do versionamento, não reproduz, não audita).
2. **Managed Identity sempre** — MSI/Managed Identity para auth entre recursos. NUNCA service principals com secret nem shared access keys (expiram, vazam em logs, rotação manual).
3. **Deny-by-default** — NSGs negam tudo, abrem regra explícita. Private Endpoints para PaaS; sem public access em produção.
4. **Secrets gerenciados** — Key Vault (soft-delete + purge protection) para credenciais e certs. App Configuration para configs não sensíveis (feature flags, reload dinâmico). Nunca em código/env/appsettings plaintext.
5. **Encryption sempre** — at rest (platform-managed ou CMK) + in transit (TLS 1.2+). Dado não criptografado é incidente.
6. **Observabilidade nativa** — Azure Monitor + Log Analytics (logs e métricas centralizados) + Application Insights (distributed tracing).
7. **Resource Groups por ambiente** — `rg-app-dev`, `rg-app-staging`, `rg-app-prod`. Isolamento e governança.
8. **Tags obrigatórias** — `env`, `team`, `cost-center`, `app`. Sem tag não há chargeback nem governança.

> Código pronto pra commit. Zero exemplo educativo. IaC, não portal.

## Stack Canônica

Versão completa (compute, storage, banco, mensageria, networking, observabilidade) em `reference/stack.md`. Resumo dos padrões EVEO:

| Categoria | Escolha EVEO | Notas |
|---|---|---|
| IaC | Bicep (canônico) | ARM JSON proibido; Terraform (`azurerm`) só p/ multi-cloud — **perguntar ao time** |
| Compute | Azure Container Apps (padrão) | AKS p/ cluster complexo; Functions v4 isolated worker event-driven |
| Banco | Azure SQL / PostgreSQL Flexible | Cosmos DB multi-model p/ NoSQL |
| Cache | Azure Cache for Redis | Standard (HA) em prod |
| Mensageria | Service Bus | enterprise messaging + topics; Event Grid p/ eventos de infra; Event Hubs p/ streaming |
| Secrets | Key Vault | soft-delete + purge protection; App Configuration só p/ configs |
| Auth | Managed Identity (MSI) | nunca service principals com secret |
| CDN | Azure Front Door + WAF | global routing, SSL offload |
| Storage | Blob Storage + Data Lake | lifecycle tiers Hot/Cool/Archive |
| Networking | VNet + NSG + Private Endpoints | zero-trust, deny-by-default |
| Observabilidade | Azure Monitor + Log Analytics + App Insights | logs JSON, alerts, tracing |
| Registry | Azure Container Registry (ACR) | imagens com digest imutável, não `latest` |
| CI/CD | Azure DevOps / GitHub Actions | deploy Bicep + apps |

> **Bicep é o padrão EVEO** para IaC Azure. Terraform (`azurerm`) só quando o projeto exigir multi-cloud — pergunte.
> **Azure Container Apps é o compute padrão.** AKS apenas para workloads que exigem controle de cluster Kubernetes.

## Estrutura de Projeto

Bicep (padrão EVEO):

```
infra/
├── main.bicep                    # orquestração principal
├── main.parameters.json          # parâmetros por ambiente
├── modules/
│   ├── containerapp.bicep        # ou appservice.bicep / aks.bicep
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

## Workflow Agentic

1. **Entender escopo** — serviço novo ou existente? IaC já é Bicep? (não misturar com Terraform).
2. **Confirmar não-assumíveis** — ACA vs AKS vs App Service? Multi-subscription? Região? (ver "Quando Perguntar").
3. **Planejar recursos** (de fora pra dentro): VNet/NSG → Managed Identity → compute (ACA/Functions) → banco → Key Vault → observabilidade → Front Door.
4. **Gerar completo** — módulo Bicep com params por ambiente, tags obrigatórias, encryption, Managed Identity, alerts.
5. **Apresentar diff** — "criei/editei: A, B, C; decisão: ACA pq serverless scaling e sem Kubernetes".

## Security

Baseline universal em `reference/security-baseline.md`. Ameaças específicas Azure:

- **Managed Identity** sempre; sem service principals com secret. `DefaultAzureCredential` em prod resolve via MSI, em dev via `az login`. Com múltiplas user-assigned MI, especifique `AZURE_CLIENT_ID`.
- **Key Vault** com soft-delete + purge protection; RBAC no vault, não access policies amplas.
- **NSGs** deny-by-default; sem `0.0.0.0/0` inbound (exceto 443 em App Gateway/Front Door público). Referência por ASG/subnet, não CIDR amplo.
- **WAF** no App Gateway/Front Door para endpoints públicos. **Microsoft Defender for Cloud** habilitado.
- **Private Endpoints** para PaaS (Key Vault, SQL, Storage) — sem trafegar internet pública.
- **Azure AD (Entra ID)** para auth; sem custom auth. **PIM** para roles elevados. **Azure Policy** para compliance (deny non-compliant).

## Cost Optimization

- Reserved Instances (1/3 anos) para workloads estáveis; Spot VMs para batch/stateless.
- Right-sizing via Azure Advisor. Auto-shutdown para VMs de dev/test.
- Blob access tiers (Hot/Cool/Archive). Budgets com alerts de anomalia. Tags para chargeback.

## Anti-padrões Críticos

| Proibido | Alternativa |
|---|---|
| ARM JSON | Bicep |
| Deploy manual (portal) | Bicep via pipeline |
| Shared access keys / connection strings em código | Managed Identity |
| Service Principals com secret | Managed Identity |
| Secrets em env/appsettings/config files | Key Vault |
| Configs hardcoded | App Configuration |
| Resource Groups sem tags | tags `env`/`team`/`cost-center`/`app` |
| Public endpoints sem WAF | Front Door / App Gateway com WAF |
| PaaS com public access em produção | Private Endpoints |
| Container ACA/AKS sem cpu/memory | limits explícitos |
| Service Bus sem idempotência | dedup via MessageId (entrega at-least-once) |
| Functions em Consumption p/ APIs síncronas | Premium (EP1) ou ACA (evita cold start) |
| Imagem ACR com tag `latest` em prod | digest SHA256 imutável ou tag git SHA |
| `any` type em Bicep | type annotations explícitas |

Detalhe com soluções em `reference/core.md`.

## Checklist

- [ ] IaC em Bicep (não ARM JSON, não misturar com Terraform)
- [ ] Managed Identity configurado (zero secrets de SP)
- [ ] Key Vault com soft-delete + purge protection
- [ ] NSGs deny-by-default; Private Endpoints em PaaS
- [ ] Encryption at rest (CMK/platform) + TLS 1.2+
- [ ] Azure Monitor + Log Analytics + App Insights
- [ ] Resource Groups por ambiente
- [ ] Tags obrigatórias
- [ ] WAF em endpoints públicos
- [ ] Backup configurado
- [ ] Cost alerts (Budgets)

## Quando Perguntar

Não assumir — perguntar antes de codar:

- **IaC**: Bicep ou Terraform? (padrão Bicep; Terraform só se multi-cloud)
- **Compute**: ACA vs AKS vs App Service? (ACA padrão; AKS só se exige Kubernetes → carregar `kubernetes-expert`)
- **Banco**: Azure SQL / PostgreSQL Flexible ou Cosmos DB? relacional vs NoSQL?
- **Multi-subscription**: governança via Landing Zone? → escalar com usuário
- **WAF/NSG complexa** → carregar `security-expert`
- **Pipeline de deploy** → carregar `cicd-expert`
- **Hybrid/on-premises** → consultar Azure Arc

## Referências (sob demanda)

Não entram no contexto automaticamente:

- **`reference/core.md`** — Padrões de código prontos p/ produção: Terraform Container App, Azure Functions isolated worker, Application Insights, Managed Identity (Blob/Storage), Service Bus producer/consumer (NestJS), Azure DevOps pipeline ACA, e anti-patterns com solução. Leia antes de gerar código.
- **`reference/stack.md`** — Stack canônica completa EVEO + Azure CLI essencial + Azure SDK (Node/TS) com Managed Identity. Leia ao configurar projeto novo.

## Cross-references

- `security-expert` — auth, API security, data protection, threat modeling
- `terraform-expert` — módulos, state, IaC multi-cloud (alternativa ao Bicep)
- `docker-expert` — containerização para ACA/AKS
- `kubernetes-expert` — AKS patterns e manifests
- `cicd-expert` — Azure DevOps pipelines, GitOps

## Segurança (Baseline Compartilhado)

Regras universais de segurança em `reference/security-baseline.md`. Aqui só ameaças específicas Azure.

> **Atenção**: o padrão EVEO é **Bicep + Azure Container Apps**. Terraform e AKS existem como alternativas — não assuma, pergunte. NUNCA ARM JSON, NUNCA deploy manual, NUNCA shared access keys.
