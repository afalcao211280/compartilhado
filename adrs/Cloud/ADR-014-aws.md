# ADR-014: AWS — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Projetos AWS na EVEO exigem padronização de IaC, compute, database, security, e observabilidade. A ausência de diretrizes resulta em ClickOps, secrets em código, security groups abertos, e custos sem controle. Well-Architected Framework como guia.

## Decisão

AWS como cloud para workloads que exigem ecossistema Amazon. IaC obrigatório — CDK ou Terraform (perguntar preferência do time, nunca ClickOps). Well-Architected Framework como guia. IAM roles com least privilege. Secrets Manager para secrets. CloudWatch + X-Ray para observabilidade.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| IaC | CDK ou Terraform | — | CloudFormation, Pulumi | CDK para TypeScript devs, Terraform para multi-cloud |
| Compute | EKS + Lambda | — | ECS, Fargate, EC2 | EKS para microserviços, Lambda para event-driven |
| Database | RDS (PostgreSQL/MySQL) + DynamoDB | — | Aurora, DocumentDB | RDS para relational, DynamoDB para key-value |
| Secrets | Secrets Manager | — | SSM Parameter Store, Vault | Rotation automática, audit trail |
| Auth | IAM Roles | — | Access keys, Cognito (user-facing) | Least privilege, temp credentials |
| CDN | CloudFront | — | ALB standalone | Global CDN, WAF integration |
| Storage | S3 | — | EFS, EBS | Object storage, lifecycle policies |
| Messaging | SQS + SNS + EventBridge | — | Kinesis, MQ | SQS para queues, SNS para pub/sub, EB para events |
| Cache | ElastiCache (Redis) | — | DynamoDB DAX, CloudFront | Distributed cache, session store |
| CI/CD | CodePipeline ou GitHub Actions | — | Jenkins, GitLab CI | AWS-native ou GitOps |
| Networking | VPC + Security Groups + NACLs | — | Public subnets only | Zero-trust, deny-by-default |
| Observabilidade | CloudWatch + X-Ray | — | Grafana, Datadog | Logs, métricas, traces integrados |
| DNS | Route 53 | — | External DNS | Health checks, routing policies |

## Padrões Obrigatórios

- **IaC obrigatório**. CDK ou Terraform — nunca deploy manual (ClickOps).
  - CDK preferido para times TypeScript/Python
  - Terraform preferido para times multi-cloud ou com expertise existente
- **Well-Architected Framework**: revisar os 5 pilares periodicamente.
- **IAM Roles com least privilege**. Nunca access keys hardcoded. STS para temp credentials.
  ```typescript
  // CDK: least privilege
  const role = new iam.Role(this, 'AppRole', {
    assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
    managedPolicies: [iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole')],
  });
  role.addToPolicy(new iam.PolicyStatement({
    actions: ['s3:GetObject'],
    resources: [bucket.arnForObjects('*')],
  }));
  ```
- **Secrets Manager** para secrets com rotation automática. SSM Parameter Store para configs não sensíveis.
- **VPC**: subnets privadas para workloads. Public subnets apenas para ALB/NAT Gateway.
- **Security Groups**: deny-by-default. Apenas regras explícitas.
- **Encryption**: at rest (KMS) + in transit (TLS 1.2+). Nunca dados não criptografados.
- **Tags obrigatórias**: `env`, `team`, `cost-center`, `app`.
- **Cost alerts**: AWS Budgets com notificação para anomalias.
- **CloudWatch + X-Ray** para logs, métricas, e traces.
- **Backup**: RDS automated backups, S3 versioning + cross-region replication.

## Estrutura de Projeto — CDK

```
infra/
├── bin/
│   └── app.ts                    # CDK app entry
├── lib/
│   ├── app-stack.ts              # Main stack
│   ├── constructs/
│   │   ├── lambda-api.ts
│   │   ├── eks-cluster.ts
│   │   ├── rds-database.ts
│   │   ├── vpc-network.ts
│   │   └── monitoring.ts
│   └── utils/
│       ├── tags.ts
│       └── naming.ts
├── cdk.json
├── tsconfig.json
└── package.json
```

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
│   ├── eks/
│   ├── rds/
│   ├── lambda/
│   ├── secrets/
│   └── monitoring/
├── environments/
│   ├── dev.tfvars
│   ├── staging.tfvars
│   └── prod.tfvars
├── backend.tf                    # S3 + DynamoDB state backend
└── Makefile
```

## Anti-padrões

| Proibido | Alternativa |
|---|---|
| ClickOps (deploy manual) | IaC (CDK ou Terraform) |
| Access keys hardcoded | IAM Roles + STS |
| Secrets em código ou SSM PlainText | Secrets Manager com rotation |
| VPC default | VPC custom com subnets privadas |
| Security Groups 0.0.0.0/0 | Least privilege SGs |
| S3 buckets public | Private buckets com CloudFront |
| Resources sem tags | Tags obrigatórias |
| RDS public access | Private subnets + VPC endpoints |
| CloudWatch logs sem retention | Log groups com retention policy |
| `any` type em CDK | Type annotations explícitas |
| Lambda monolítica (>15 min) | ECS/Fargate ou Step Functions |

## Consequências

**Positivas**:
- CDK oferece type-safe IaC com TypeScript — melhor DX que CloudFormation YAML
- Terraform é multi-cloud — reutilizável para Azure/GCP se necessário
- IAM Roles eliminam secrets e rotation manual
- Secrets Manager com rotation automática garante compliance
- Well-Architected Framework prevê revisões de segurança, performance, e custo

**Negativas**:
- CDK lock-in AWS — Terraform seria mais portátil
- VPC + Private Endpoints adicionam complexidade e custo
- Learning curve para CDK constructs e Terraform modules

**Riscos**:
- Escolha IaC (CDK vs Terraform) afeta portabilidade e hiring — **perguntar ao time**
- EKS é complexo para times sem experiência Kubernetes — considerar ECS/Fargate
- Cost sprawl fácil sem tags e budgets — enforce via AWS Organizations SCP

## Referências

- `skills/Cloud/aws-expert/SKILL.md`
- Documentação AWS CDK: https://docs.aws.amazon.com/cdk/
- Documentação Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/
- AWS Well-Architected Framework: https://aws.amazon.com/architecture/well-architected/