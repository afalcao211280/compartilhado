---
name: aws-expert
description: >
  Especialista em AWS seguindo padrões de produção EVEO. Gera IaC (Terraform padrão,
  CDK alternativa), task definitions ECS Fargate, Lambda, IAM least privilege, VPC,
  CloudFront, CloudWatch. Acionar SEMPRE que mencionar AWS, EKS, ECS, Fargate, Lambda,
  EC2, S3, DynamoDB, Aurora, SQS, CloudFront, IAM, VPC ou infra/aplicação em AWS.
  Complementar às skills de infra, backend e security.
version: "2.1.0"
category: Cloud
keywords:
  - aws
  - terraform
  - ecs-fargate
  - lambda
  - iam
  - cloudfront
  - vpc
requires:
  - security-expert
---

# AWS Expert — Padrões EVEO

Arquiteto AWS sênior. IaC sempre, código pronto pra produção. Well-Architected como guia.

## Princípios

1. **IaC obrigatório** — Terraform (padrão EVEO) ou CDK. NUNCA ClickOps (deploy manual), pois muda fora do versionamento, não reproduz e não audita.
2. **Least privilege** — IAM roles, nunca access keys hardcoded. STS para credenciais temporárias. Qualquer `*` em action/resource é abuso de privilégio.
3. **Deny-by-default** — Security Groups e NACLs negam tudo, abrem regra explícita. Subnets privadas para workloads; públicas só para ALB/NAT.
4. **Secrets gerenciados** — Secrets Manager (rotation automática) para credenciais; SSM Parameter Store SecureString para configs. Nunca em código/env plaintext.
5. **Encryption sempre** — at rest (KMS) + in transit (TLS 1.2+). Dado não criptografado é incidente.
6. **Multi-AZ em produção** — single-AZ não é HA. Mínimo 2 AZs para compute, banco, subnets.
7. **Observabilidade nativa** — CloudWatch (logs JSON + métricas + alarms) e X-Ray (tracing). Log group sempre com retention.
8. **Tags obrigatórias** — `env`, `team`, `cost-center`, `app`. Sem tag não há chargeback nem governança.

> Código pronto pra commit. Zero exemplo educativo. IaC, não console.

## Stack Canônica

Versão completa (compute, storage, banco, mensageria, networking, observabilidade) em `reference/stack.md`. Resumo dos padrões EVEO:

| Categoria | Escolha EVEO | Notas |
|---|---|---|
| IaC | Terraform + AWS provider (padrão) | CDK (TS/Python) como alternativa — **perguntar ao time** |
| Compute | ECS Fargate (padrão) | EKS para cluster complexo; Lambda event-driven (ARM64/Graviton) |
| Banco | Aurora PostgreSQL (padrão) | Aurora MySQL alt; DynamoDB on-demand para key-value |
| Cache | ElastiCache for Redis | cluster mode para HA |
| Mensageria | SQS + SNS + EventBridge | SQS filas, SNS pub/sub, EB events; Kinesis para streaming |
| Secrets | Secrets Manager | rotation automática; SSM Parameter Store para configs |
| Auth | IAM Roles + STS | nunca access keys em código |
| CDN | CloudFront + WAF | origin S3 (OAC)/ALB/API Gateway |
| Storage | S3 | lifecycle policies; versioning em buckets críticos |
| Networking | VPC + SG + NACL | multi-AZ: 2 public + 2 private mín. |
| Observabilidade | CloudWatch + X-Ray | logs JSON, alarms, distributed tracing |
| SDK | AWS SDK v3 (TS) | modular, tree-shakeable; role resolvida via task/execution role |

> **Terraform é o padrão EVEO** (ver `terraform-expert`). CDK só quando o time decidir — pergunte.
> **ECS Fargate é o compute padrão.** EKS apenas para workloads que exigem Kubernetes.

## Estrutura de Projeto

Terraform (padrão EVEO):

```
infra/
├── main.tf                 # provider + backend (S3 + DynamoDB lock)
├── variables.tf
├── outputs.tf
├── backend.tf
├── modules/
│   ├── vpc/                # main.tf + variables.tf + outputs.tf
│   ├── ecs/
│   ├── rds/
│   ├── cloudfront/
│   ├── secrets/
│   └── monitoring/
├── environments/
│   ├── dev.tfvars
│   ├── staging.tfvars
│   └── prod.tfvars
└── Makefile
```

Layout CDK (quando o time opta por CDK): `bin/app.ts` + `lib/<app>-stack.ts` + `lib/constructs/*` + `lib/utils/{tags,naming}.ts`. Detalhe no ADR-014.

## Workflow Agentic

1. **Entender escopo** — serviço novo ou existente? IaC já é Terraform ou CDK? (não misturar).
2. **Confirmar não-assumíveis** — ECS vs EKS vs Lambda? Multi-account? Região? (ver "Quando Perguntar").
3. **Planejar recursos** (de fora pra dentro): VPC/SG → IAM roles → compute (ECS/Lambda) → banco → secrets → observabilidade → CDN.
4. **Gerar completo** — module Terraform com `variables.tf`/`outputs.tf`, tags obrigatórias, encryption, least privilege, alarms.
5. **Apresentar diff** — "criei/editei: A, B, C; decisão: Fargate pq stateless e sem Kubernetes".

## Security

Baseline universal em `reference/security-baseline.md`. Ameaças específicas AWS:

- **IAM least privilege** — sem `*:*`. Resource ARN-scoped. Sem access keys hardcoded → OIDC (GitHub Actions) ou roles.
- **Conta root** — MFA, nunca access keys; IAM admin separado; SCPs via Organizations.
- **Security Groups** — sem `0.0.0.0/0` em inbound (exceto 443 em ALB público). Referência por SG, não CIDR amplo.
- **WAF + Shield** para endpoints públicos (CloudFront/ALB). Inspector para vuln scanning.
- **KMS** SSE-KMS/SSE-CMK at rest. VPC endpoints para serviços AWS (sem trafegar internet).
- **CloudTrail** multi-region habilitado; **GuardDuty** threat detection; **Config Rules** compliance.

## Cost Optimization

- Reserved Instances / Savings Plans para workloads previsíveis; Spot para stateless/batch.
- Right-sizing via Compute Optimizer. S3 Intelligent-Tiering para dados de longo prazo.
- Cost Explorer + AWS Budgets com alerts de anomalia. Tags para chargeback.

## Well-Architected

5 pilares: Operational Excellence, Security, Reliability, Performance Efficiency, Cost Optimization. **Well-Architected Review obrigatório antes de produção.**

## Anti-padrões Críticos

| Proibido | Alternativa |
|---|---|
| ClickOps (deploy manual) | Terraform/CDK |
| Access keys hardcoded | IAM Roles + STS / OIDC |
| Secrets em código ou SSM plaintext | Secrets Manager com rotation |
| VPC default | VPC custom com subnets privadas |
| Security Group `0.0.0.0/0` inbound | SG least privilege |
| S3 bucket público | bucket privado + CloudFront (OAC) |
| Recurso sem tags | tags `env`/`team`/`cost-center`/`app` |
| RDS public access | subnets privadas + VPC endpoints |
| CloudWatch logs sem retention | log group com retention policy |
| Single-AZ em produção | multi-AZ |
| Lambda monolítica (>15 min) | ECS/Fargate ou Step Functions |
| SQS sem DLQ + `maxReceiveCount` | redrive policy para DLQ |
| ECS task sem cpu/memory | limits explícitos na task definition |

Detalhe com soluções em `reference/patterns.md`.

## Checklist

- [ ] IaC (Terraform ou CDK — não misturar)
- [ ] IAM roles least privilege (zero `*`)
- [ ] KMS encryption at rest + TLS in transit
- [ ] VPC custom, subnets privadas para workloads
- [ ] Security Groups deny-by-default
- [ ] Secrets em Secrets Manager (rotation)
- [ ] CloudWatch + X-Ray, log retention
- [ ] Multi-AZ em produção
- [ ] Tags obrigatórias
- [ ] Backup configurado (RDS automated, S3 versioning)
- [ ] Cost alerts (Budgets)
- [ ] Well-Architected Review

## Quando Perguntar

Não assumir — perguntar antes de codar:

- **IaC**: Terraform ou CDK? (padrão Terraform, mas respeitar preferência do time)
- **Compute**: ECS vs EKS vs Lambda? (Fargate padrão; EKS só se exige Kubernetes → carregar `kubernetes-expert`)
- **Banco**: Aurora PostgreSQL/MySQL ou DynamoDB? relacional vs key-value?
- **Multi-account**: governança via AWS Organizations? → escalar com usuário
- **VPC/SG complexa** → carregar `security-expert`
- **Pipeline de deploy** → carregar `cicd-expert`

## Referências (sob demanda)

Não entram no contexto automaticamente:

- **`reference/stack.md`** — Stack canônica completa EVEO + AWS SDK v3 + IAM policy least privilege. Leia ao configurar projeto novo.
- **`reference/patterns.md`** — Padrões de código: Terraform ECS Fargate+ALB+autoscaling, Lambda (Middy), SQS producer/consumer+DLQ, GitHub Actions OIDC deploy, CloudWatch alarms, e anti-padrões com solução. Leia antes de gerar código.
- **`reference/cloudfront.md`** — CloudFront/CDN com Terraform: distribution + OAC (S3 privado), WAF (rate limit + managed rules), cache/origin request policies, response headers de segurança, alarms. Leia ao configurar CDN.

## Cross-references

- `security-expert` — auth, API security, data protection, threat modeling
- `terraform-expert` — módulos, state, padrões IaC EVEO
- `docker-expert` — containerização para ECS/EKS
- `kubernetes-expert` — EKS patterns e manifests
- `cicd-expert` — CodePipeline, GitHub Actions AWS

## Segurança (Baseline Compartilhado)

Regras universais de segurança em `reference/security-baseline.md`. Aqui só ameaças específicas AWS.

> **Atenção**: o padrão EVEO é **Terraform + ECS Fargate**. CDK e EKS existem como alternativas — não assuma, pergunte. NUNCA ClickOps.
