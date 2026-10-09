# GCP Expert — Padrões de Código

## 1. Terraform — Cloud Run + Cloud SQL

```hcl
# main.tf
terraform {
  required_version = ">= 1.8"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.30" }
  }
  backend "gcs" {
    bucket = "my-project-terraform-state"
    prefix = "myapp/prod"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Service Account para Cloud Run
resource "google_service_account" "api" {
  account_id   = "sa-api-${var.environment}"
  display_name = "API Service Account"
}

# Grant acesso ao Secret Manager
resource "google_secret_manager_secret_iam_member" "api_db" {
  secret_id = google_secret_manager_secret.database_url.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

# Cloud Run Service
resource "google_cloud_run_v2_service" "api" {
  name     = "api-${var.environment}"
  location = var.region

  template {
    service_account = google_service_account.api.email

    scaling {
      min_instance_count = 1
      max_instance_count = 100
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.repo_name}/api:${var.image_tag}"

      resources {
        limits = { cpu = "1", memory = "512Mi" }
        startup_cpu_boost = true
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_url.secret_id
            version = "latest"
          }
        }
      }

      liveness_probe {
        http_get { path = "/health" }
        initial_delay_seconds = 30
        period_seconds        = 30
      }

      startup_probe {
        http_get { path = "/health" }
        failure_threshold = 10
        period_seconds    = 5
      }
    }
  }

  depends_on = [google_secret_manager_secret_iam_member.api_db]
}

# Allow unauthenticated access (public API)
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
```

---

## 2. Cloud Functions (Gen 2) — HTTP + Pub/Sub

```typescript
// src/functions/http-handler.ts
import { http, type Request, type Response } from '@google-cloud/functions-framework';
import { z } from 'zod';

const createUserSchema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
});

http('createUser', async (req: Request, res: Response) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const parsed = createUserSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  // lógica de negócio
  res.status(201).json({ id: crypto.randomUUID(), ...parsed.data });
});
```

```typescript
// src/functions/pubsub-handler.ts
import { cloudEvent, type CloudEvent } from '@google-cloud/functions-framework';
import type { MessagePublishedData } from '@google/events/cloud/pubsub/v1/MessagePublishedData';

cloudEvent<MessagePublishedData>('processOrder', async (event) => {
  const base64Data = event.data?.message?.data;
  if (!base64Data) return;

  const payload = JSON.parse(Buffer.from(base64Data, 'base64').toString()) as {
    orderId: string;
    amount: number;
  };

  console.log(JSON.stringify({ message: 'Processing order', orderId: payload.orderId }));
  // processar pedido
});
```

---

## 3. Pub/Sub — Producer + Consumer

```typescript
// src/lib/pubsub.ts
import { PubSub } from '@google-cloud/pubsub';

const pubsub = new PubSub({ projectId: process.env['GCP_PROJECT_ID'] });

export async function publish<T>(topicName: string, message: T): Promise<void> {
  const topic = pubsub.topic(topicName);
  const data = Buffer.from(JSON.stringify(message));
  await topic.publishMessage({ data });
}

// Para Cloud Run — receber via HTTP push subscription
import type { Request, Response } from 'express';

export function handlePubSubPush(req: Request, res: Response, handler: (data: unknown) => Promise<void>) {
  const message = req.body?.message;
  if (!message?.data) {
    res.status(400).send('No data in message');
    return;
  }

  const data = JSON.parse(Buffer.from(message.data as string, 'base64').toString());

  handler(data)
    .then(() => res.status(204).send())
    .catch((err) => {
      console.error('Error processing Pub/Sub message:', err);
      res.status(500).send('Internal server error'); // Pub/Sub vai retry
    });
}
```

---

## 4. Structured Logging — Cloud Logging

```typescript
// src/lib/logger.ts — structured JSON logging para Cloud Logging
export const logger = {
  info: (message: string, data?: Record<string, unknown>) =>
    console.log(JSON.stringify({
      severity: 'INFO',
      message,
      ...data,
      timestamp: new Date().toISOString(),
    })),
  warn: (message: string, data?: Record<string, unknown>) =>
    console.warn(JSON.stringify({
      severity: 'WARNING',
      message,
      ...data,
      timestamp: new Date().toISOString(),
    })),
  error: (message: string, error?: Error, data?: Record<string, unknown>) =>
    console.error(JSON.stringify({
      severity: 'ERROR',
      message,
      error: error ? { message: error.message, stack: error.stack } : undefined,
      ...data,
      timestamp: new Date().toISOString(),
    })),
};
```

---

## 5. GitHub Actions — Cloud Run Deploy

```yaml
# .github/workflows/deploy.yml
name: Deploy to Cloud Run

on:
  push:
    branches: [main]

permissions:
  id-token: write   # Workload Identity Federation — sem service account keys
  contents: read

env:
  PROJECT_ID: my-gcp-project
  REGION: us-central1
  SERVICE: api-production
  ARTIFACT_REGISTRY: us-central1-docker.pkg.dev/my-gcp-project/my-repo

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Authenticate to GCP via Workload Identity
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: 'projects/123456789/locations/global/workloadIdentityPools/github/providers/github'
          service_account: 'github-actions@my-gcp-project.iam.gserviceaccount.com'

      - name: Build and push to Artifact Registry
        run: |
          gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev
          docker build -t ${{ env.ARTIFACT_REGISTRY }}/api:${{ github.sha }} .
          docker push ${{ env.ARTIFACT_REGISTRY }}/api:${{ github.sha }}

      - name: Deploy to Cloud Run
        uses: google-github-actions/deploy-cloudrun@v2
        with:
          service: ${{ env.SERVICE }}
          region: ${{ env.REGION }}
          image: ${{ env.ARTIFACT_REGISTRY }}/api:${{ github.sha }}
```

---

## Anti-patterns

### ❌ Service Account JSON keys baixadas e comitadas
**Problema:** Criar chaves JSON de Service Account e salvá-las em repositórios, variáveis de ambiente ou imagens Docker.
**Por quê evitar:** Chaves JSON não expiram automaticamente, são difíceis de rotacionar e qualquer vazamento compromete permanentemente o acesso ao GCP.
**Solução:**
```yaml
# GitHub Actions com Workload Identity Federation — sem chaves
- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: 'projects/PROJECT_NUM/locations/global/workloadIdentityPools/github/providers/github'
    service_account: 'deploy-sa@PROJECT.iam.gserviceaccount.com'
```

### ❌ Cloud Run sem --no-allow-unauthenticated
**Problema:** Deploy no Cloud Run sem especificar política de autenticação — o padrão permite acesso público.
**Por quê evitar:** Serviços internos ficam expostos à internet sem necessidade; qualquer pessoa pode invocar o endpoint.
**Solução:**
```bash
gcloud run deploy minha-api \
  --no-allow-unauthenticated \  # exige token de autenticação
  --service-account=api-sa@PROJECT.iam.gserviceaccount.com
# Para expor publicamente, use Cloud Load Balancer com IAP ou API Gateway
```

### ❌ Cloud Functions sem min-instances para endpoints sensíveis à latência
**Problema:** Usar Cloud Functions gen2 (ou Cloud Run) com `min-instances=0` para APIs síncronas.
**Por quê evitar:** Cold starts de 1-10 segundos ocorrem quando não há instância aquecida — inaceitável para chamadas síncronas de usuários.
**Solução:**
```bash
gcloud run deploy minha-api \
  --min-instances=1 \   # mantém 1 instância sempre aquecida
  --max-instances=100
```

### ❌ Logging com print() em vez de logging estruturado
**Problema:** Usar `print()` ou `console.log()` em aplicações no GCP.
**Por quê evitar:** Cloud Logging não parseia texto livre — severity, trace e labels ficam perdidos; alertas e dashboards não funcionam.
**Solução:**
```python
import google.cloud.logging
import logging

client = google.cloud.logging.Client()
client.setup_logging()  # integra com logging padrão do Python

logging.warning("Erro ao processar", extra={"json_fields": {"user_id": uid, "order_id": oid}})
# Cloud Logging recebe severity=WARNING + campos estruturados
```

### ❌ Cloud SQL com IP público sem Cloud SQL Auth Proxy
**Problema:** Habilitar IP público no Cloud SQL e adicionar IPs ao authorized networks.
**Por quê evitar:** IP público expõe o banco à internet; gerenciar lista de IPs autorizados é frágil e não escala com Cloud Run (IPs dinâmicos).
**Solução:**
```yaml
# Cloud Run com Cloud SQL via socket Unix (sem IP público)
- name: DB_HOST
  value: /cloudsql/PROJECT:REGION:INSTANCE
# Adicione a annotation ao Cloud Run:
# run.googleapis.com/cloudsql-instances: PROJECT:REGION:INSTANCE
```

### ❌ Pub/Sub sem Dead Letter Topic
**Problema:** Criar subscription no Pub/Sub sem configurar dead letter topic e `maxDeliveryAttempts`.
**Por quê evitar:** Mensagens que falham são retentadas indefinidamente por padrão — uma mensagem com payload inválido trava o processamento ou gera custo excessivo de redelivery.
**Solução:**
```hcl
resource "google_pubsub_subscription" "main" {
  name  = "eventos-sub"
  topic = google_pubsub_topic.eventos.name

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq.id
    max_delivery_attempts = 5
  }
}
```

### ❌ Cloud Run sem --service-account (usa SA padrão de compute)
**Problema:** Deploy no Cloud Run sem especificar `--service-account`, usando o service account padrão do Compute Engine.
**Por quê evitar:** O SA padrão tem acesso a todos os recursos do projeto (Editor role) — viola menor privilégio; qualquer exploit no container tem acesso total ao GCP.
**Solução:**
```bash
# Crie SA dedicado com apenas as permissões necessárias
gcloud iam service-accounts create api-sa --display-name="API Service Account"
gcloud projects add-iam-policy-binding PROJECT \
  --member="serviceAccount:api-sa@PROJECT.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

gcloud run deploy minha-api --service-account=api-sa@PROJECT.iam.gserviceaccount.com
```
