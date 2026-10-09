# AWS Expert — Padrões de Código

## 1. Terraform — ECS Fargate + ALB

```hcl
# modules/ecs-service/main.tf
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.app_name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "api"
    image     = "${var.ecr_repository_url}:${var.image_tag}"
    essential = true

    portMappings = [{ containerPort = 3000, protocol = "tcp" }]

    environment = [
      { name = "NODE_ENV", value = "production" },
      { name = "PORT", value = "3000" },
    ]

    secrets = [
      { name = "DATABASE_URL", valueFrom = aws_secretsmanager_secret.database_url.arn },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.app_name}-api"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])
}

resource "aws_ecs_service" "api" {
  name            = "${var.app_name}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 3000
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}

# Auto-scaling
resource "aws_appautoscaling_target" "api" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_cpu" {
  name               = "cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
```

---

## 2. Lambda — Node.js com Middy

```typescript
// src/handlers/createUser.ts
import middy from '@middy/core';
import httpJsonBodyParser from '@middy/http-json-body-parser';
import httpErrorHandler from '@middy/http-error-handler';
import validator from '@middy/validator';
import { transpileSchema } from '@middy/validator/transpile';
import type { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

const schema = {
  type: 'object',
  properties: {
    body: {
      type: 'object',
      properties: {
        name: { type: 'string', minLength: 2 },
        email: { type: 'string', format: 'email' },
      },
      required: ['name', 'email'],
    },
  },
};

const baseHandler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  const body = event.body as unknown as { name: string; email: string };

  // lógica de negócio
  const user = { id: crypto.randomUUID(), ...body };

  return {
    statusCode: 201,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(user),
  };
};

export const handler = middy(baseHandler)
  .use(httpJsonBodyParser())
  .use(validator({ eventSchema: transpileSchema(schema) }))
  .use(httpErrorHandler());
```

---

## 3. SQS — Producer + Consumer

```typescript
// src/lib/sqs.ts
import { SQSClient, SendMessageCommand, type Message } from '@aws-sdk/client-sqs';

const sqs = new SQSClient({ region: process.env['AWS_REGION'] });

export async function enqueue<T>(queueUrl: string, message: T): Promise<void> {
  await sqs.send(
    new SendMessageCommand({
      QueueUrl: queueUrl,
      MessageBody: JSON.stringify(message),
      MessageGroupId: 'default', // FIFO queues only
    }),
  );
}

// Lambda handler para SQS trigger
import type { SQSHandler, SQSRecord } from 'aws-lambda';

interface OrderMessage { orderId: string; amount: number }

export const processOrderHandler: SQSHandler = async (event) => {
  const failedItems: { itemIdentifier: string }[] = [];

  for (const record of event.Records) {
    try {
      const message = JSON.parse(record.body) as OrderMessage;
      await processOrder(message);
    } catch (err) {
      console.error(`Failed to process record ${record.messageId}:`, err);
      // Retornar para dead-letter sem falhar o batch inteiro
      failedItems.push({ itemIdentifier: record.messageId });
    }
  }

  return { batchItemFailures: failedItems };
};

async function processOrder(msg: OrderMessage): Promise<void> {
  console.log(`Processing order ${msg.orderId}`);
}
```

---

## 4. GitHub Actions — ECS Deploy

```yaml
# .github/workflows/deploy.yml
name: Deploy to ECS

on:
  push:
    branches: [main]

permissions:
  id-token: write  # OIDC para assumir IAM role sem access keys
  contents: read

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: myapp-api
  ECS_CLUSTER: myapp-production
  ECS_SERVICE: myapp-api

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions-deploy
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, push to ECR
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

      - name: Deploy to ECS
        uses: aws-actions/amazon-ecs-deploy-task-definition@v2
        with:
          task-definition: ecs-task-def.json
          service: ${{ env.ECS_SERVICE }}
          cluster: ${{ env.ECS_CLUSTER }}
          wait-for-service-stability: true
```

---

## 5. CloudWatch — Alertas Essenciais

```hcl
# Alarme: erro 5xx no ALB
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.app_name}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB returning 5xx errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# Alarme: Lambda com erros
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5

  dimensions = { FunctionName = var.function_name }
  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

---

## Anti-patterns

### ❌ Credenciais AWS hardcoded no código
**Problema:** Desenvolvedores configuram `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY` diretamente no código ou em arquivos `.env` comitados.
**Por quê evitar:** Credenciais vazam via git history, logs, imagens Docker — rotação é manual e o comprometimento compromete toda a conta.
**Solução:**
```hcl
# Para ECS/EC2: IAM Role anexada à task definition
resource "aws_iam_role" "ecs_task" {
  assume_role_policy = jsonencode({
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
# Para GitHub Actions: OIDC — sem chaves estáticas
```

### ❌ Wildcard em políticas IAM
**Problema:** Usar `Resource: "*"` ou `Action: "*"` em políticas IAM por conveniência.
**Por quê evitar:** Viola princípio do menor privilégio — qualquer comprometimento da role dá acesso irrestrito à conta.
**Solução:**
```json
{
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:PutObject"],
  "Resource": "arn:aws:s3:::meu-bucket-prod/*"
}
```

### ❌ SQS sem Dead Letter Queue
**Problema:** Criar filas SQS sem configurar DLQ e `maxReceiveCount`.
**Por quê evitar:** Mensagens que falham ficam tentando indefinidamente, consumindo recursos e mascarando bugs; eventualmente são descartadas silenciosamente.
**Solução:**
```hcl
resource "aws_sqs_queue" "main" {
  name                      = "eventos"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })
}
```

### ❌ Lambda síncrona para trabalho de background
**Problema:** Invocar Lambda de forma síncrona (`RequestResponse`) para tarefas longas chamadas de APIs.
**Por quê evitar:** Bloqueia o chamador até o timeout (máx 15min), aumenta custo e latência — use invocação assíncrona ou SQS.
**Solução:**
```typescript
// Invocação assíncrona: não espera resposta
await lambda.send(new InvokeCommand({
  FunctionName: 'processar-relatorio',
  InvocationType: 'Event', // assíncrono
  Payload: JSON.stringify({ userId }),
}));
```

### ❌ S3 sem versionamento em buckets críticos
**Problema:** Deixar versionamento desabilitado em buckets com dados de produção ou backups.
**Por quê evitar:** Deleção acidental ou sobrescrita é irreversível; sem versionamento não há como recuperar.
**Solução:**
```hcl
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.dados.id
  versioning_configuration { status = "Enabled" }
}
```

### ❌ Lambda em VPC sem NAT Gateway para acesso externo
**Problema:** Colocar Lambda em VPC privada e esperar que ela acesse internet (APIs externas, S3 endpoint público).
**Por quê evitar:** Lambda em VPC privada sem NAT Gateway não tem rota para internet — timeouts silenciosos difíceis de diagnosticar.
**Solução:**
```hcl
# Use VPC Endpoint para S3/DynamoDB (sem NAT)
# ou provisione NAT Gateway na subnet pública
# ou mantenha Lambda fora de VPC se não precisar acessar recursos privados
```

### ❌ Usar conta root para acesso programático
**Problema:** Criar access keys para o usuário root da conta AWS.
**Por quê evitar:** Root tem acesso irrestrito e inalienável — comprometimento = perda total da conta; não pode ser restringido por SCPs.
**Solução:**
```
1. Habilitar MFA na conta root
2. Criar IAM user admin separado para operações diárias
3. Usar AWS Organizations com SCPs para limitar o que roots de member accounts podem fazer
4. Nunca criar access keys para root
```

### ❌ ECS task sem CPU/Memory limits
**Problema:** Não definir `cpu` e `memory` na task definition do ECS Fargate.
**Por quê evitar:** AWS rejeita a task definition (Fargate exige) — mas no EC2 launch type a task pode consumir todos os recursos do host, causando instabilidade no cluster.
**Solução:**
```hcl
resource "aws_ecs_task_definition" "api" {
  cpu    = 512   # 0.5 vCPU
  memory = 1024  # 1 GB
  # container_definitions deve ter limits menores ou iguais
}
```
