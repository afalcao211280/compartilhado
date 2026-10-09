# GCP Expert — Stack Canônica

## Google Cloud Platform — Versão Canônica EVEO

| Categoria | Serviço | Notas |
|-----------|---------|-------|
| **Compute** | | |
| Containers | Cloud Run | Padrão EVEO GCP. Serverless containers. Auto-scaling para zero |
| Containers alt | GKE (Google Kubernetes Engine) | Para clusters gerenciados com Autopilot mode |
| Functions | Cloud Functions (gen 2) | Baseado em Cloud Run. Node.js 20, Python 3.12, Go 1.22, Java 21 |
| VMs | Compute Engine | E2 para dev, C2/N2 para prod |
| **Storage** | | |
| Object | Cloud Storage | Padrão para arquivos. Classes: Standard, Nearline, Coldline, Archive |
| Bloco | Persistent Disk | Para GCE. pd-balanced (padrão), pd-ssd (prod) |
| **Banco de Dados** | | |
| PostgreSQL | Cloud SQL for PostgreSQL | Padrão EVEO GCP. High Availability com failover automático |
| MySQL | Cloud SQL for MySQL | Quando MySQL específico |
| PostgreSQL/MySQL | AlloyDB | PostgreSQL-compatible, 4x mais rápido. Para workloads exigentes |
| NoSQL | Firestore | Serverless document DB. Ideal para mobile/web apps |
| NoSQL alt | Cloud Bigtable | Para petabytes de dados de séries temporais |
| Cache | Memorystore for Redis | Redis gerenciado. Standard (HA) ou Basic |
| Data Warehouse | BigQuery | Serverless analytics. SQL sobre petabytes |
| **Mensageria** | | |
| Pub/Sub | Cloud Pub/Sub | Mensageria assíncrona. Padrão GCP |
| Tasks | Cloud Tasks | Filas de tarefas gerenciadas (equivalente ao SQS) |
| Scheduler | Cloud Scheduler | Cron jobs gerenciados |
| **Segurança** | | |
| Segredos | Secret Manager | Padrão para credenciais. Rotação automática |
| Identidade | Cloud IAM + Workload Identity | Service Accounts. NUNCA service account keys em código |
| API Gateway | Cloud Endpoints / API Gateway | Throttling, auth, monitoramento |
| Armor | Cloud Armor | WAF + DDoS protection para LB |
| **Networking** | | |
| LB | Cloud Load Balancing | Global HTTP(S) LB com anycast |
| CDN | Cloud CDN | Integrado ao Global LB |
| DNS | Cloud DNS | DNS gerenciado |
| **Observabilidade** | | |
| Logs | Cloud Logging | Structured logging. Log Explorer + Log-based metrics |
| Métricas | Cloud Monitoring | Metrics + Alerting policies + Dashboards |
| Tracing | Cloud Trace | Distributed tracing. OpenTelemetry compatível |
| Profiling | Cloud Profiler | CPU/heap profiling em produção |
| **IaC** | | |
| IaC | Terraform + Google provider | Padrão EVEO. `hashicorp/google` |
| Alternativa | Pulumi | TypeScript/Python/Go |

## gcloud CLI — Comandos Essenciais

```bash
# Setup
gcloud auth login
gcloud config set project my-project-id
gcloud config set run/region us-central1

# Cloud Run — deploy
gcloud run deploy api \
  --image gcr.io/my-project/api:v1.0.0 \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "NODE_ENV=production" \
  --set-secrets "DATABASE_URL=database-url:latest" \
  --min-instances 1 \
  --max-instances 100 \
  --memory 512Mi \
  --cpu 1

# Secret Manager
gcloud secrets create database-url --data-file=- <<< "postgresql://..."
gcloud secrets add-iam-policy-binding database-url \
  --member="serviceAccount:api-sa@my-project.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

## Google Cloud SDK — Node.js/TypeScript

```typescript
// Workload Identity Federation — sem service account keys
// Em Cloud Run/GKE: credenciais automáticas via metadata server
import { SecretManagerServiceClient } from '@google-cloud/secret-manager';

const secretClient = new SecretManagerServiceClient();

export async function getSecret(secretName: string, projectId: string): Promise<string> {
  const [version] = await secretClient.accessSecretVersion({
    name: `projects/${projectId}/secrets/${secretName}/versions/latest`,
  });
  return version.payload?.data?.toString() ?? '';
}
```
