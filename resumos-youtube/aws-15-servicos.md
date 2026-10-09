# Resumo — "15 serviços AWS que você precisa dominar"

Fonte: https://www.youtube.com/watch?v=8chgJEuDzYM (vídeo em pt-BR, ~18 min)
Data do resumo: 30/08/2026

## Tese central

Dos 200+ serviços AWS, 90% das aplicações usam os mesmos 15. O vídeo explica cada um — o que faz, quando usar e como se conectam — e fecha montando uma arquitetura de referência com todos juntos.

## Os 15 serviços

### 1. IAM (Identidade e Acesso)
Quem pode fazer o quê, onde e quando. 4 conceitos:
- **Users** — pessoas
- **Groups** — agrupam users e herdam permissões
- **Roles** — identidades temporárias que serviços assumem
- **Policies** — regras JSON do que pode e não pode

Princípio do **least privilege**: mínimo necessário para cada coisa funcionar. MFA na conta root e nunca usá-la no dia a dia.

### 2. VPC (Rede)
Rede isolada dentro da AWS. Define range de IPs, subnets e controle de entrada/saída.
- **Subnet pública** — rota pro internet gateway
- **Subnet privada** — isolada, só sai via NAT gateway
- **Security Groups** — firewall no nível da instância

Arquitetura típica: load balancer na subnet pública, aplicação e banco na privada, três camadas de defesa.

### 3. EC2 (Computação)
Servidor virtual na nuvem. Famílias comuns:
- **T** — workloads variáveis, dev/teste
- **M** — uso geral em produção
- **C** — computação pesada
- **R** — muita memória

Modelos de preço:
- **On-Demand** — paga por uso, sem compromisso, mais caro
- **Reserved** — 1 a 3 anos, desconto até 70%
- **Spot** — capacidade ociosa, até 90% de desconto, mas pode ser interrompido

**EBS** = discos de bloco: GP3 para quase tudo, IO2 para banco com IOPS garantido.

### 4. Auto Scaling Group + ALB (Escala)
- **ASG** mantém instâncias saudáveis rodando (mín/desejado/máx; escala por CPU ~70%)
- **ALB** (Application Load Balancer) distribui tráfego HTTP, roteia por path/host/headers, faz health checks e remove instância falha do pool

Padrão clássico: ALB na frente, ASG atrás. Tráfego sobe → ASG escala; cai → reduz e economiza.

### 5. S3 (Armazenamento de objetos)
Objetos até 5 TB, durabilidade de 11 noves. Classes:
- **Standard** — dados acessados com frequência
- **Standard-IA** — raramente acessados, disponíveis rápido
- **Glacier** — longo prazo, recuperação em minutos a horas

Lifecycle policies movem objetos entre classes automaticamente (30 dias → IA, 90 dias → Glacier). Versioning protege contra deleção acidental; Block Public Access trava acesso público mesmo com config errada. **Event Notifications** disparam Lambda/SQS — a cola de arquiteturas event-driven.

### 6. RDS (Banco relacional gerenciado)
Postgres, MySQL, MariaDB, Oracle, SQL Server. AWS cuida de patching, backups e failover; você cuida do esquema/queries/índices.
- **AZs** = data centers físicos separados (energia, rede, refrigeração independentes)
- **Multi-AZ** — alta disponibilidade com failover automático
- **Read replicas** — até 5, escalam leitura (escritas só no primário)

### 7. Aurora (banco nativo de nuvem)
Compatível com Postgres/MySQL, storage distribuído em 3 AZs, cresce até 128 TB, até 15 réplicas compartilhando o mesmo storage, failover < 30s. **Aurora Serverless**: paga por uso, escala sozinho, pausa sem tráfego.
Regra: workload pequeno/dev → RDS; performance/escala → Aurora.

### 8. Lambda (Serverless)
Código + triggers (API Gateway para HTTP, S3 para upload, SQS para filas, EventBridge para schedules). Escala para milhares de contêineres paralelos. Pontos importantes:
- **Cold start** — latência da 1ª execução; Provisioned Concurrency mantém contêineres prontos
- Preço por execução e tempo; 1º milhão de requests/mês grátis
- **Timeout máximo de 15 minutos**
- Tráfego constante e previsível → EC2 geralmente mais barato

### 9. DynamoDB (NoSQL)
Escala praticamente ilimitada, latência de milissegundos consistente. Projeta-se pelo **padrão de acesso**, não por modelo normalizado: partition key (distribui/localiza) + sort key (queries por range).
- **Provisioned** vs **on-demand** (on-demand é mais caro por request, menos preocupação)
- **DynamoDB Streams** — captura mudanças em tempo real (Lambda sincroniza/reage/audita)
- Ideal: sessões, leaderboards, IoT, carrinhos. Não ideal: analytics complexos, dados relacionais

### 10. API Gateway
Expõe suas APIs pro mundo. **REST API** (mais features) vs **HTTP API** (mais simples e barato) — comece com HTTP, migre se precisar. Integra com Lambda, proxy para EC2/ECS, ou direto no DynamoDB. Autorização: IAM (service-to-service), Cognito (JWT), Lambda authorizers (lógica customizada). Throttling protege o backend; domínios customizados com certificado SSL via ACM.

### 11. CloudFront (CDN)
400+ pontos no mundo. Edge location mais próximo responde em milissegundos em vez de viajar até a origem. Origins: S3, Load Balancer, API Gateway, qualquer HTTP server. Cache behaviors por path.
- **ACM** — certificado HTTPS gratuito, emite e renova sozinho
- **OAC** (Origin Access Control) — garante que só o CloudFront acessa seu S3
- **WAF** — protege contra SQL injection, XSS e bots

### 12. CloudWatch (Observabilidade)
Hub baseado em três pilares: métricas, logs e alarmes. Métricas automáticas (CPU, latência, erros) + customizadas. Log groups com retention configurável. **X-Ray** dá trace ID com o caminho completo da request (ex.: API Gateway → Lambda → DynamoDB) para identificar gargalos e erros por componente.

### 13. SQS (Fila)
Desacopla sistemas e absorve picos: produtor manda, consumidor processa quando pode; se cai, a mensagem espera.
- **Standard** — throughput ilimitado, at-least-once
- **FIFO** — ordem garantida, exactly-once
- **Dead Letter Queue** — captura mensagens que falharam várias vezes

### 14. SNS (Pub/Sub)
Publica num tópico, todos os inscritos recebem. SQS entrega para um, SNS entrega para todos. Padrão comum: SNS publica e múltiplas SQS consomem em paralelo, cada fila processa independente.

### 15. EventBridge
Evolução do SNS para arquiteturas event-driven. Recebe eventos da AWS, da sua aplicação e de SaaS externos. Filtragem detalhada e **replay de eventos**. Regra: SQS = desacoplamento simples; SNS = notificar vários consumidores; EventBridge = eventos complexos.

## Bônus (saber que existem)

- **ECS/EKS + Fargate** — orquestração de containers; ECS simples e integrado, EKS (Kubernetes) mais portátil e complexo; Fargate serverless, EC2 quando precisa de GPU/controle fino
- **ECR** — registry privado de imagens Docker com scan de vulnerabilidades
- **Route 53** — DNS com roteamento por latência/localização e failover automático
- **Cognito** — autenticação gerenciada (cadastro, MFA, login social Google/Apple), retorna JWT
- **Secrets Manager** / **Parameter Store** — credenciais e chaves com rotação automática (PS é a alternativa gratuita p/ config simples)
- **Step Functions** — orquestra workflows com múltiplas Lambdas (sequência, retry, tratamento de erros)
- **ElastiCache** — Redis/Memcached gerenciado, latência submilissegundo (sessões, cache, leaderboards)
- **Kinesis** — streaming em tempo real (logs, clickstream, IoT); múltiplos consumidores no mesmo dado + replay

## Arquitetura de referência (como tudo se conecta)

```
Route 53 → CloudFront (assets estáticos do S3)
         → API Gateway (auth via Cognito)
              → Lambda
                   → DynamoDB + ElastiCache
                   → SQS → Worker → RDS
CloudWatch + X-Ray monitoram tudo
```

Cada bloco é substituível: Lambda↔EC2, EC2↔ECS, SQS↔SNS — escolha pelo caso de uso.

Mapa mental por categoria:
- **Fundação** — VPC (rede) + IAM (acesso)
- **Computação** — EC2, Lambda
- **Armazenamento** — S3, EBS
- **Banco de dados** — RDS/Aurora (relacional), DynamoDB (NoSQL), ElastiCache (cache)
- **Networking** — Route 53, CloudFront, API Gateway
- **Integração** — SQS, SNS, EventBridge
- **Observabilidade** — CloudWatch, X-Ray

## Frase-resumo

Mapa mental dos 15 serviços essenciais da AWS (segurança, rede, computação, armazenamento, banco, serverless e integração), mostrando quando usar cada um e como montar uma arquitetura típica com eles.