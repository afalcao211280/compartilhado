# AWS Expert — Stack Canônica

## Amazon Web Services — Versão Canônica EVEO

| Categoria | Serviço | Notas |
|-----------|---------|-------|
| **Compute** | | |
| Containers | ECS Fargate | Padrão EVEO AWS para containers. Serverless, sem gerenciar EC2 |
| Containers alt | EKS (Kubernetes) | Para controle de cluster e workloads complexos |
| Functions | AWS Lambda | Node.js 20.x, Python 3.12, Java 21 runtimes. ARM64 (Graviton) preferido |
| VMs | EC2 | Para workloads que não containerizam. t3/t4g para dev, c6g/m6g para prod |
| **Storage** | | |
| Object storage | S3 | Padrão para arquivos. Lifecycle policies para controle de custo |
| Bloco | EBS | Para EC2. gp3 padrão (mais barato que gp2) |
| Arquivo | EFS | NFS gerenciado. Para ECS multi-AZ com estado |
| **Banco de Dados** | | |
| PostgreSQL | Aurora PostgreSQL | Padrão EVEO. Serverless v2 para workloads variáveis |
| MySQL | Aurora MySQL | Alternativa quando MySQL específico é necessário |
| NoSQL | DynamoDB | On-demand billing. Single-table design para alta escala |
| Cache | ElastiCache for Redis | cluster mode para HA |
| Search | OpenSearch Service | Fork do Elasticsearch. Padrão para busca AWS |
| **Mensageria** | | |
| Queues | SQS | Standard (alta throughput) ou FIFO (ordem garantida) |
| Pub/Sub | SNS | Fan-out para múltiplos subscribers (SQS, Lambda, email) |
| Streaming | Kinesis Data Streams | Para ingestão de alto volume (logs, IoT) |
| Events | EventBridge | Event bus gerenciado. Integra 200+ serviços AWS |
| **Segurança** | | |
| Segredos | AWS Secrets Manager | Rotação automática. Padrão para credenciais |
| Parâmetros | AWS SSM Parameter Store | SecureString para configs não-críticas |
| Identidade | IAM + Roles | Roles para EC2/ECS/Lambda. NUNCA access keys em código |
| WAF | AWS WAF | Proteção contra OWASP Top 10. Associar ao CloudFront/ALB |
| **Networking** | | |
| LB | ALB (Application Load Balancer) | L7, path/host routing. Padrão para HTTP/HTTPS |
| CDN | CloudFront | CDN + WAF. Origin: S3, ALB, API Gateway |
| DNS | Route 53 | DNS + health checks. Failover routing |
| VPC | VPC + Subnets | Multi-AZ: 2 public + 2 private subnets mínimo |
| **Observabilidade** | | |
| Logs | CloudWatch Logs | Estruturados JSON. Log Insights para queries |
| Métricas | CloudWatch Metrics | Custom metrics via SDK. Dashboards + Alarms |
| Tracing | AWS X-Ray | Distributed tracing. OpenTelemetry compatível |
| **IaC** | | |
| IaC | Terraform + AWS provider | Padrão EVEO. Ver terraform-expert skill |
| Alternativa | AWS CDK | TypeScript/Python. Abstração sobre CloudFormation |

## AWS SDK — Node.js/TypeScript (v3)

```typescript
// Sempre usar AWS SDK v3 (modular, tree-shakeable)
// npm install @aws-sdk/client-s3 @aws-sdk/client-secrets-manager

import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

// IAM Roles são resolvidos automaticamente via instance profile / task role / Lambda execution role
const s3 = new S3Client({ region: process.env['AWS_REGION'] });
const secretsManager = new SecretsManagerClient({ region: process.env['AWS_REGION'] });

export async function getSecret(secretName: string): Promise<string> {
  const response = await secretsManager.send(
    new GetSecretValueCommand({ SecretId: secretName }),
  );
  return response.SecretString ?? '';
}
```

## IAM Policy — Least Privilege (exemplo ECS task role)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:123456789:secret:myapp/*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::my-app-bucket/*"
    }
  ]
}
```
