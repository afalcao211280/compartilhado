# ADR-015: GCP — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Projetos GCP na EVEO exigem padronização de IaC, compute, database, security, e observabilidade. A ausência de diretrizes resulta em gcloud commands manuais, service account keys em código, VPC default, e custos sem controle. Terraform canônico. Organization policies como guardrails.

## Decisão

GCP como cloud para workloads data-native e Kubernetes-native. Terraform canônico para IaC (nunca gcloud manual). Workload Identity Federation (nunca service account keys). Secret Manager para secrets. Cloud Operations Suite para observabilidade. VPC com subnets privadas (nunca default network).

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| IaC | Terraform | — | Deployment Manager, Pulumi | Multi-cloud, mature, declarative |
| Compute | GKE + Cloud Run | — | Compute Engine, Cloud Functions | GKE para microserviços, Cloud Run para containers serverless |
| Database | Cloud SQL (PostgreSQL/MySQL) + Firestore | — | AlloyDB, Spanner, Bigtable | Cloud SQL para relational, Firestore para NoSQL |
| Secrets | Secret Manager | — | GCS encrypted, Vault | Rotation, IAM-native, audit |
| Auth | Workload Identity Federation | — | Service account keys | Sem keys, short-lived tokens |
| CDN | Cloud CDN + Load Balancer | — | Cloudflare standalone | Global CDN, LB integration |
| Storage | Cloud Storage | — | — | Object storage, lifecycle policies |
| Messaging | Pub/Sub | — | Cloud Tasks, Beams | Event streaming, async messaging |
| Cache | Memorystore (Redis) | — | Cloud CDN cache | Distributed cache |
| CI/CD | Cloud Build + GitHub Actions | — | Jenkins, GitLab CI | GCP-native + GitOps |
| Networking | VPC + Firewall Rules + Private Google Access | — | Default VPC (proibido) | Zero-trust, private access |
| Observabilidade | Cloud Operations Suite (Logging + Monitoring + Trace) | — | Grafana, Datadog | Integrated, IAM-native |
| DNS | Cloud DNS | — | External DNS | Health checks, routing policies |
| Data | BigQuery | — | Snowflake, Redshift | Serverless, SQL-native, real-time |

## Padrões Obrigatórios

- **Terraform para IaC**. Nunca gcloud commands manuais. Nunca ClickOps.
  ```hcl
  resource "google_sql_database_instance" "main" {
    name             = "db-${var.environment}"
    database_version = "POSTGRES_16"
    region           = var.region
    
    settings {
      tier = "db-custom-2-7680"
      
      backup_configuration {
        enabled = true
      }
    }
    
    deletion_protection = var.environment == "prod" ? true : false
  }
  ```
- **VPC com subnets privadas**. Nunca default network. Private Google Access para serviços GCP.
- **Workload Identity Federation**. Nunca service account keys em código.
  ```hcl
  resource "google_service_account" "app" {
    account_id = "app-${var.environment}"
  }
  
  resource "google_service_account_iam_binding" "workload_identity" {
    service_account_id = google_service_account.app.name
    role               = "roles/iam.workloadIdentityUser"
    members            = ["serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_ns}/${var.k8s_sa}]"]
  }
  ```
- **Secret Manager** para secrets. Não env vars em código. Não GCS para secrets.
- **Cloud Operations Suite** (Logging + Monitoring + Trace) — logs e métricas centralizados.
- **Labels obrigatórios**: `env`, `team`, `cost-center`, `app`.
- **Cloud Build** para CI/CD. GitHub Actions como alternativa.
- **Organization policies** como guardrails: `constraints/compute.requireOsLogin`, `constraints/iam.disableServiceAccountKeyCreation`.
- **Encryption**: at rest (Google-managed ou CMEK) + in transit (TLS 1.2+).
- **IAM**: least privilege. Custom roles quando predefined roles são amplos demais.
- **GKE**: Workload Identity, Network Policy, Binary Authorization, Container-Optimized OS.

## Estrutura de Projeto — Terraform

```
infra/
├── main.tf                       # Provider + backend config
├── variables.tf                  # Input variables
├── outputs.tf                    # Output values
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
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
├── backend.tf                    # GCS state backend
├── organization_policies.tf     # Guardrails
└── Makefile
```

## Anti-padrões

| Proibido | Alternativa |
|---|---|
| gcloud commands manuais | Terraform |
| Service account keys em código | Workload Identity Federation |
| Default VPC | VPC custom com subnets privadas |
| Secrets em código ou GCS | Secret Manager |
| Resources sem labels | Labels obrigatórias: `env`, `team`, `cost-center`, `app` |
| IAM roles amplos (roles/owner) | Least privilege + custom roles |
| Cloud SQL com public IP | Private IP + Private Service Connect |
| Logs sem retention policy | Cloud Logging com retention configurado |
| `any` type em Terraform | Type constraints explícitas |
| Cloud Run para workloads longas (>60 min) | GKE ou Compute Engine |

## Consequências

**Positivas**:
- Terraform é multi-cloud — reutilizável para AWS/Azure se necessário
- Workload Identity elimina service account keys e rotation manual
- Secret Manager integra com IAM nativamente — sem solução terceira
- Cloud Operations Suite é IM-native — sem configuração de agents
- Data-native: BigQuery + Pub/Sub + Dataflow para analytics pipeline

**Negativas**:
- Terraform state management requer S3/GCS backend e locking — operacional overhead
- GKE é complexo para teams sem experiência Kubernetes — Cloud Run é alternativa mais simples
- GCP tem menos managed services que AWS para casos específicos

**Riscos**:
- Organization policies restritivas podem bloquear desenvolvedores — balancear segurança e produtividade
- Cloud Run cold starts para workloads pouco frequentes — configurar min instances
- BigQuery costs podem escalar sem[data monitoring] — enforce budget labels equota alerts

## Referências

- `skills/Cloud/gcp-expert/SKILL.md`
- Documentação Terraform GCP Provider: https://registry.terraform.io/providers/hashicorp/google/
- Documentação GKE: https://cloud.google.com/kubernetes-engine/docs/
- Documentação Cloud Run: https://cloud.google.com/run/docs/
- Documentação Workload Identity: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity