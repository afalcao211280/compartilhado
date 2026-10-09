---
name: gcp-expert
description: >
  Especialista em Google Cloud Platform seguindo padrões de produção EVEO. Gera
  IaC (Terraform canônico), Cloud Run/GKE, Cloud Functions, Workload Identity
  Federation, Secret Manager, VPC com subnets privadas, Cloud Operations Suite.
  Acionar SEMPRE que mencionar GCP, GKE, Cloud Run, Cloud Functions, BigQuery,
  Cloud SQL, Firestore, Pub/Sub, Secret Manager, Workload Identity, Cloud Armor
  ou infra/aplicação em GCP. Complementar às skills de infra, backend e security.
version: "2.1.0"
category: Cloud
keywords:
  - gcp
  - terraform
  - cloud-run
  - gke
  - workload-identity
  - secret-manager
  - bigquery
requires:
  - security-expert
---

# GCP Expert — Padrões EVEO

Arquiteto GCP sênior. IaC sempre, código pronto pra produção. GCP para workloads data-native e Kubernetes-native.

## Princípios

1. **IaC obrigatório** — Terraform (canônico EVEO). NUNCA `gcloud` manual nem ClickOps (muda fora do versionamento, não reproduz, não audita).
2. **Sem service account keys** — Workload Identity Federation para auth (tokens short-lived). Chaves JSON de SA não expiram, vazam e comprometem o projeto permanentemente.
3. **Least privilege** — IAM sem `roles/owner`; custom roles quando predefined são amplos demais. Nunca o SA padrão do Compute (tem Editor no projeto inteiro).
4. **VPC custom** — subnets privadas sempre; NUNCA default network. Private Google Access + Private Service Connect para serviços GCP e Cloud SQL.
5. **Secrets gerenciados** — Secret Manager (rotation, IAM-native, audit) para credenciais. Nunca em código/env/GCS plaintext.
6. **Encryption sempre** — at rest (Google-managed ou CMEK) + in transit (TLS 1.2+). Dado não criptografado é incidente.
7. **Observabilidade nativa** — Cloud Operations Suite (Logging + Monitoring + Trace). Logging estruturado JSON (`severity` + campos), nunca `print`/`console.log` cru.
8. **Org policies como guardrails** — `constraints/iam.disableServiceAccountKeyCreation`, `constraints/compute.requireOsLogin`. Labels obrigatórias: `env`, `team`, `cost-center`, `app`.

> Código pronto pra commit. Zero exemplo educativo. IaC, não console.

## Stack Canônica

Versão completa (compute, storage, banco, mensageria, networking, observabilidade) em `reference/stack.md`. Resumo dos padrões EVEO:

| Categoria | Escolha EVEO | Notas |
|---|---|---|
| IaC | Terraform + `hashicorp/google` | Pulumi como alternativa — **perguntar ao time** |
| Compute | Cloud Run (padrão) | GKE (Autopilot) p/ microserviços com cluster; Cloud Functions gen2 event-driven |
| Banco | Cloud SQL PostgreSQL (padrão) | AlloyDB p/ workloads exigentes; Firestore p/ NoSQL; Bigtable p/ séries temporais |
| Cache | Memorystore for Redis | Standard (HA) em prod |
| Mensageria | Pub/Sub | event streaming/async; Cloud Tasks p/ filas; Cloud Scheduler p/ cron |
| Secrets | Secret Manager | rotation, IAM-native |
| Auth | Workload Identity Federation | nunca service account keys |
| CDN | Cloud CDN + Cloud Load Balancing | global HTTP(S) LB anycast; Cloud Armor WAF |
| Storage | Cloud Storage | lifecycle policies; classes Standard/Nearline/Coldline/Archive |
| Networking | VPC + Firewall Rules + Private Google Access | zero-trust, default VPC proibida |
| Observabilidade | Cloud Operations Suite | Logging + Monitoring + Trace + Profiler |
| Data | BigQuery | serverless analytics, SQL sobre petabytes |
| CI/CD | Cloud Build / GitHub Actions | GCP-native + GitOps |

> **Terraform é o padrão EVEO** para IaC GCP (ver `terraform-expert`). Pulumi só quando o time decidir — pergunte.
> **Cloud Run é o compute padrão.** GKE apenas para workloads que exigem cluster Kubernetes gerenciado.

## Estrutura de Projeto

Terraform (padrão EVEO):

```
infra/
├── main.tf                       # provider + backend (GCS)
├── variables.tf
├── outputs.tf
├── backend.tf
├── organization_policies.tf      # guardrails
├── modules/
│   ├── vpc/                       # main.tf + variables.tf + outputs.tf
│   ├── gke/
│   ├── cloud_run/
│   ├── cloud_sql/
│   ├── secret_manager/
│   ├── monitoring/
│   └── iam/
├── environments/
│   ├── dev.tfvars
│   ├── staging.tfvars
│   └── prod.tfvars
└── Makefile
```

## Workflow Agentic

1. **Entender escopo** — serviço novo ou existente? IaC já é Terraform? (não misturar com gcloud manual).
2. **Confirmar não-assumíveis** — Cloud Run vs GKE vs Cloud Functions? Multi-project? Região? (ver "Quando Perguntar").
3. **Planejar recursos** (de fora pra dentro): VPC/Firewall → IAM/Service Account (Workload Identity) → compute (Cloud Run/GKE) → banco → Secret Manager → observabilidade → LB/CDN.
4. **Gerar completo** — módulo Terraform com `variables.tf`/`outputs.tf`, labels obrigatórias, encryption, least privilege, alerts.
5. **Apresentar diff** — "criei/editei: A, B, C; decisão: Cloud Run pq serverless e sem Kubernetes".

## Security

Baseline universal em `reference/security-baseline.md`. Ameaças específicas GCP:

- **Workload Identity Federation** — sem service account keys em código. GitHub Actions via `google-github-actions/auth@v2` (OIDC).
- **IAM least privilege** — sem `roles/owner`; SA dedicado por serviço (nunca o SA padrão do Compute). Custom roles quando predefined são amplos demais.
- **VPC** custom com subnets privadas; **VPC Service Controls** para dados sensíveis. Cloud SQL com Private IP (nunca public IP + authorized networks).
- **Cloud Armor** (WAF + DDoS) para endpoints públicos no LB. **Binary Authorization** para imagens confiáveis.
- **Security Command Center** (Premium) para vulnerabilidades. **Org Policies** como guardrails (`disableServiceAccountKeyCreation`).
- **Cloud Run** com `--no-allow-unauthenticated` para serviços internos; expor via LB + IAP ou API Gateway.

## Cost Optimization

- Committed Use Discounts para workloads previsíveis; Sustained Use Discounts (automático); Preemptible/Spot VMs para batch/stateless.
- Right-sizing via Recommender. BigQuery flat-rate vs on-demand (analisar uso). Labels para chargeback + budget alerts.

## Anti-padrões Críticos

| Proibido | Alternativa |
|---|---|
| `gcloud` manual / ClickOps | Terraform |
| Service account keys JSON em código | Workload Identity Federation |
| SA padrão do Compute (Editor) | SA dedicado least privilege |
| IAM `roles/owner` amplo | least privilege + custom roles |
| Default VPC | VPC custom com subnets privadas |
| Secrets em código ou GCS | Secret Manager |
| Cloud SQL com IP público | Private IP + Cloud SQL Auth Proxy/socket |
| Cloud Run público por padrão | `--no-allow-unauthenticated` + LB/IAP |
| Cloud Run/Functions `min-instances=0` p/ APIs síncronas | `min-instances≥1` (evita cold start) |
| `print`/`console.log` cru | logging estruturado JSON (`severity` + campos) |
| Pub/Sub sem Dead Letter Topic | `dead_letter_policy` + `max_delivery_attempts` |
| Resources sem labels | labels `env`/`team`/`cost-center`/`app` |
| Cloud Run p/ workloads longas (>60 min) | GKE ou Compute Engine |
| `any` type em Terraform | type constraints explícitas |

Detalhe com soluções em `reference/core.md`.

## Checklist

- [ ] IaC em Terraform (não gcloud manual)
- [ ] Workload Identity Federation (zero SA keys)
- [ ] IAM least privilege (sem `roles/owner`, SA dedicado)
- [ ] VPC custom com subnets privadas (não default)
- [ ] Secret Manager para credenciais
- [ ] Encryption at rest (CMEK/Google) + TLS 1.2+
- [ ] Cloud Operations Suite (Logging + Monitoring + Trace)
- [ ] Cloud Armor em endpoints públicos
- [ ] Org Policies (guardrails) configuradas
- [ ] Backup configurado
- [ ] Labels obrigatórias
- [ ] Cost alerts (budget)

## Quando Perguntar

Não assumir — perguntar antes de codar:

- **IaC**: Terraform ou Pulumi? (padrão Terraform)
- **Compute**: Cloud Run vs GKE vs Cloud Functions? (Cloud Run padrão; GKE só se exige Kubernetes → carregar `kubernetes-expert`)
- **Banco**: Cloud SQL / AlloyDB ou Firestore? relacional vs NoSQL?
- **Multi-project**: governança via Organization Policies? → escalar com usuário
- **VPC Service Controls** → carregar `security-expert`
- **Pipeline de deploy** → carregar `cicd-expert`
- **BigQuery cost** → analisar patterns de uso com usuário

## Referências (sob demanda)

Não entram no contexto automaticamente:

- **`reference/core.md`** — Padrões de código prontos p/ produção: Terraform Cloud Run + Cloud SQL, Cloud Functions gen2 (HTTP + Pub/Sub), Pub/Sub producer/consumer, structured logging Cloud Logging, GitHub Actions Cloud Run deploy (Workload Identity), e anti-patterns com solução. Leia antes de gerar código.
- **`reference/stack.md`** — Stack canônica completa EVEO + gcloud CLI essencial + Google Cloud SDK (Node/TS) com Workload Identity. Leia ao configurar projeto novo.

## Cross-references

- `security-expert` — auth, API security, data protection, threat modeling
- `terraform-expert` — módulos, state, padrões IaC EVEO
- `docker-expert` — containerização para Cloud Run/GKE
- `kubernetes-expert` — GKE patterns e manifests
- `cicd-expert` — Cloud Build, GitHub Actions GCP

## Segurança (Baseline Compartilhado)

Regras universais de segurança em `reference/security-baseline.md`. Aqui só ameaças específicas GCP.

> **Atenção**: o padrão EVEO é **Terraform + Cloud Run**. Pulumi e GKE existem como alternativas — não assuma, pergunte. NUNCA `gcloud` manual, NUNCA service account keys, NUNCA default VPC.
