# Cronograma Detalhado - Entregas de 2 Semanas

## Visão Geral

| Parâmetro | Valor |
|-----------|-------|
| **Duração Total** | 36 semanas (~9 meses) |
| **Sprints** | 18 sprints de 2 semanas |
| **Entregas por Sprint** | 2-4 deliverables |
| **Critério de Aceite** | Testes passando + Code review |

---

## Fase 1: Infraestrutura e Autenticação (Semanas 1-8)

### Sprint 1-2: Base Infraestrutura

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 1.1 | Cluster K8s | EKS/GKE cluster provisionado | Cluster disponível, nodes up |
| 1.2 | Container Registry | ECR/GCR configurado | Push/pull de imágenes |
| 1.3 | Namespace K8s | Namespaces: production, staging, dev | RBAC aplicado |

```bash
# Provisionamento base
eksctl create cluster --name ecommerce-prod --region us-east-1
aws ecr create-repository --repository-name ecommerce
kubectl create namespace production staging dev
```

**Definition of Done:** Cluster operacional, developers com acesso.

---

### Sprint 3-4: CI/CD Pipeline

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 2.1 | GitHub Actions | Pipeline básico configurado | Pipeline executando |
| 2.2 | Build stage | Docker build + test | Imagem no registry |
| 2.3 | Deploy stage | Deploy para staging | App no staging |
| 2.4 | Secrets config | HashiCorp Vault/K8s secrets | Secrets injetados |

```yaml
# .github/workflows/ci.yaml
name: CI/CD
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - run: docker build -t $ECR:$SHA .
      - run: docker push $ECR:$SHA
      - run: kubectl set image deployment/$APP $APP=$ECR:$SHA
```

**Definition of Done:** Commit triggers deploy automático para staging.

---

### Sprint 5-6: Auth Service - Parte 1

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 3.1 | Auth Service | Go REST API básica | Endpoints /health, /ready |
| 3.2 | PostgreSQL | Database auth provisionado | Schema criado, migrations |
| 3.3 | JWT token generation | Geração de access/refresh | Tokens válidos |
| 3.4 | /login endpoint | Credenciais validation | 200/401 responses |

```go
// internal/auth/handlers.go
func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
    var req LoginRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    
    user, err := h.validateCredentials(req.Email, req.Password)
    if err != nil {
        http.Error(w, "invalid credentials", http.StatusUnauthorized)
        return
    }
    
    tokens, err := h.generateTokens(user)
    json.NewEncoder(w).Encode(tokens)
}
```

**Definition of Done:** Login retorna JWT válido.

---

### Sprint 7-8: Auth Service - Parte 2 + MFA

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 4.1 | /register endpoint | User registration | Usuário criado |
| 4.2 | MFA setup | Google Authenticator/Twilio | QR code gerado |
| 4.3 | MFA validation | Verificação 2FA | Login bloqueia sem MFA |
| 4.4 | SSO OAuth | Google/Facebook/Apple | Login social funciona |

```go
// internal/auth/mfa.go
func (s *MFAService) SetupMFA(userID string) (*MFAConfig, error) {
    secret := base32.NewStdEncoding().EncodeToString(
        securerandom_token(20, securerandom.AlphaBet))
    
    otpURL := fmt.Sprintf(
        "otpauth://totp/Ecommerce:%s?secret=%s&issuer=Ecommerce",
        userID, secret)
    
    qrCode, err := googleed25519.QRCODEString(otpURL)
    if err != nil {
        return nil, err
    }
    
    return &MFAConfig{
        Secret:     secret,
        QRCode:     qrCode,
        BackupCodes: generateBackupCodes(10),
    }, nil
}
```

**Definition of Done:** Login completo com MFA e OAuth social.

---

## Fase 2: E-commerce Core (Semanas 9-20)

### Sprint 9-10: Produto e Catálogo

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 5.1 | Product Service | Go API CRUD | Endpoints funcionando |
| 5.2 | Database schema | Products, categories, SKUs | Schema migration |
| 5.3 | Elasticsearch | Índice products | Busca funcional |
| 5.4 | Product images | Upload para S3 | Images serving |

```go
// internal/product/handlers.go
func (h *ProductHandler) CreateProduct(w http.ResponseWriter, r *http.Request) {
    var req CreateProductRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    
    product, err := h.service.CreateProduct(r.Context(), req)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    
    // Index in Elasticsearch
    h.searchService.IndexProduct(r.Context(), product)
    
    json.NewEncoder(w).Encode(product)
}
```

**Definition of Done:** CRUD products com busca funcional.

---

### Sprint 11-12: Estoque e Inventário

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 6.1 | Inventory API | Stock management | Reservas funcionado |
| 6.2 | Redis cache | Cache de estoque | Cache hit > 80% |
| 6.3 | Webhook estoque | Notificações low stock | Alertas triggers |
| 6.4 | Stock reserva | Hold por 15min | Carrinho expira |

```go
// internal/inventory/service.go
func (s *InventoryService) ReserveStock(ctx context.Context, 
    items []ReserveItem, ttl time.Duration) (string, error) {
    
    reservationID := generateUUID()
    
    pipe := s.redis.Pipeline()
    for _, item := range items {
        key := fmt.Sprintf("stock:%s:%d", item.SKU, item.WarehouseID)
        pipe.Add(ctx, redis.NewCmd(ctx, "DECRBY", key, item.Quantity))
    }
    
    // Set expiry for auto-release
    s.redis.Set(ctx, 
        fmt.Sprintf("reservation:%s", reservationID),
        serialize(items),
        ttl)
    
    _, err := pipe.Exec(ctx)
    return reservationID, err
}
```

**Definition of Done:** Stock em tempo real, reserva automática expira.

---

### Sprint 13-14: Carrinho e Checkout

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 7.1 | Cart Service | Add/remove/update items | Carrinho persistido |
| 7.2 | Cart API | GET/POST/PUT cart | API RESTful |
| 7.3 | Checkout flow | Address, shipping, review | Fluxo completo |
| 7.4 | Order creation | Criação da order | Order com status |

```go
// internal/checkout/service.go
func (s *CheckoutService) CreateOrder(ctx context.Context,
    cartID string, shippingAddress Address) (*Order, error) {
    
    cart, err := s.cartService.GetCart(ctx, cartID)
    if err != nil {
        return nil, err
    }
    
    // Validate stock
    if err := s.inventoryService.ValidateStock(ctx, cart.Items); err != nil {
        return nil, err
    }
    
    shippingOptions := s.shippingService.Calculate(cart.Items, shippingAddress)
    
    order := &Order{
        ID:              generateUUID(),
        UserID:          cart.UserID,
        Items:           cart.Items,
        ShippingAddress: shippingAddress,
        ShippingOptions: shippingOptions,
        Status:          OrderStatusPending,
        CreatedAt:       time.Now(),
    }
    
    return s.orderRepository.Create(ctx, order)
}
```

**Definition of Done:** Fluxo checkout completo ate order created.

---

### Sprint 15-16: Pagamentos

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 8.1 | Payment Gateway | Stripe integration | Pagamento criado |
| 8.2 | PIX/Boleto | Métodos alternativos | QR Code gerado |
| 8.3 | Webhook payments | Confirmação de pagamento | Status updated |
| 8.4 | Refund API | Estorno parcial/total | Money returned |

```go
// internal/payment/service.go
func (s *PaymentService) CreatePayment(ctx context.Context,
    req CreatePaymentRequest) (*Payment, error) {
    
    order, err := s.orderService.GetOrder(ctx, req.OrderID)
    if err != nil {
        return nil, err
    }
    
    switch req.Method {
    case PaymentMethodPix:
        return s.createPixPayment(ctx, order, req)
    case PaymentMethodCard:
        return s.createCardPayment(ctx, order, req)
    case PaymentMethodBoleto:
        return s.createBoletoPayment(ctx, order, req)
    }
    
    return nil, errors.New("unsupported payment method")
}

func (s *PaymentService) createPixPayment(ctx context.Context,
    order *Order, req CreatePaymentRequest) (*Payment, error) {
    
    pixReq := &stripe.PaymentLinkParams{
        Amount:        order.TotalCents,
        Currency:      "brl",
        PaymentMethod: "pix",
        Metadata: map[string]string{
            "order_id": order.ID,
        },
    }
    
    link, err := s.stripe.PaymentLinks.Create(pixReq)
    if err != nil {
        return nil, err
    }
    
    return &Payment{
        ID:          generateUUID(),
        OrderID:     order.ID,
        Gateway:     "stripe",
        Method:      PaymentMethodPix,
        Amount:      order.TotalCents,
        Status:      PaymentStatusPending,
        QRCodigo:    link.PixRedirectURL,
        ExpiresAt:   time.Now().Add(24 * time.Hour),
    }, nil
}
```

**Definition of Done:** Pagamentos processando, webhooks funcionando.

---

### Sprint 17-18: Frete e Entrega

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 9.1 | Shipping API | Multiple carriers | Cotar funcionando |
| 9.2 | Correios/JadLog | Frete padrão | Preços retornando |
| 9.3 | Tracking webhook | Rastreamento | Status events |
| 9.4 | Delivery estimate | Previsão entrega | Datas corretas |

```go
// internal/shipping/service.go
func (s *ShippingService) CalculateFreight(req FreightRequest) ([]FreightOption, error) {
    var wg sync.WaitGroup
    var mu sync.Mutex
    results := make([]FreightOption, 0)
    
    carriers := []Carrier{Correios{}, JadLog{}, Loggi{}}
    
    for _, carrier := range carriers {
        wg.Add(1)
        go func(c Carrier) {
            defer wg.Done()
            option, err := c.Calculate(req)
            if err == nil && option != nil {
                mu.Lock()
                results = append(results, *option)
                mu.Unlock()
            }
        }(carrier)
    }
    
    wg.Wait()
    sort.Sort(ByPrice(results))
    
    return results, nil
}
```

**Definition of Done:** Múltiplos fretes funcionando, melhor preço selecionado.

---

### Sprint 19-20: Frontend E-commerce

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 10.1 | MF Shell | Module Federation host | Remote loading |
| 10.2 | Product page | Product micro frontend | Page funcionando |
| 10.3 | Cart/Checkout | Carrinho micro frontend | Checkout completo |
| 10.4 | BFF layer | Golang BFF com cache | Latência < 200ms |

```javascript
// webpack.config.js (federation host)
new ModuleFederationPlugin({
    name: 'shell',
    remotes: {
        product: 'product@https://cdn.example.com/product.js',
        cart: 'cart@https://cdn.example.com/cart.js',
        checkout: 'checkout@https://cdn.example.com/checkout.js',
    },
    shared: {
        react: { singleton: true },
        'react-dom': { singleton: true },
    },
})
```

**Definition of Done:** E-commerce operacional com micro frontends.

---

## Fase 3: AI Agents (Semanas 21-30)

### Sprint 21-22: Chat AI Setup

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 11.1 | Chat API | WebSocket Chat | Mensagens fluindo |
| 11.2 | Python API | OpenAI/Anthropic integration | Respostas gerando |
| 11.3 | Session management | Redis sessions | Hist maintained |
| 11.4 | Rate limiting | Limites por user | Limites applied |

```python
# app/api/chat.py
from fastapi import WebSocket, WebSocketDisconnect
from app.services.ai import AIService

class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[str, WebSocket] = {}
    
    async def connect(self, user_id: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[user_id] = websocket
    
    def disconnect(self, user_id: str):
        self.active_connections.pop(user_id, None)

manager = ConnectionManager()
ai_service = AIService()

@websocket.websocket("/ws/chat/{user_id}")
async def chat_endpoint(websocket: WebSocket, user_id: str):
    await manager.connect(user_id, websocket)
    try:
        while True:
            data = await websocket.receive_text()
            response = await ai_service.chat(user_id, data)
            await websocket.send_text(response)
    except WebSocketDisconnect:
        manager.disconnect(user_id)
```

**Definition of Done:** Chat funcionando com IA.

---

### Sprint 23-24: AI Agents - NLU e Intents

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 12.1 | Intent classification | Classificar user queries | Intent > 90% |
| 12.2 | Entity extraction | Products, orders, dates | Entities extraídas |
| 12.3 | Tool registry | Ferramentas disponíveis | Tools callable |
| 12.4 | Context dialog | Session context | Conversa mantida |

```python
# app/agents/intent_classifier.py
from app.services.llm import LLMService

class IntentClassifier:
    INTENTS = [
        "search_product",
        "order_status",
        "cancel_order",
        "return_product",
        "shipping_info",
        "payment_issue",
        "general_question",
    ]
    
    def __init__(self, llm: LLMService):
        self.llm = llm
    
    async def classify(self, user_message: str) -> IntentResult:
        prompt = f"""Classify this message into one of: {', '.join(self.INTENTS)}
        
Message: {user_message}
Return JSON: {{"intent": "...", "confidence": 0.0-1.0, "entities": [...]}}"""
        
        result = await self.llm.complete(prompt, response_format="json")
        return IntentResult(**result)
```

**Definition of Done:** 90%+ intent accuracy.

---

### Sprint 25-26: AI Agents - Tools

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 13.1 | Search tools | Product search | Resultados relevantes |
| 13.2 | Order tools | Status, cancel, return | Operações working |
| 13.3 | Shipping tools | Tracking, estimate | Info retornando |
| 13.4 | Escalation | Handoff para human | Ticket created |

```python
# app/agents/tools/base.py
from abc import ABC, abstractmethod
from pydantic import BaseModel
from typing import Any

class Tool(ABC):
    name: str
    description: str
    parameters: dict
    
    @abstractmethod
    async def execute(self, **kwargs) -> ToolResult:
        pass

class SearchProductsTool(Tool):
    name = "search_products"
    description = "Search for products in catalog"
    parameters = {"query": str, "filters": dict}
    
    async def execute(self, query: str, filters: dict = None) -> ToolResult:
        products = await product_service.search(query, filters)
        return ToolResult(
            success=True,
            data=[p.dict() for p in products[:5]],
            message=f"Found {len(products)} products"
        )
```

**Definition of Done:** Ferramentas integradas, agentes respondendo actions.

---

### Sprint 27-28: AI Guardrails - Input

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 14.1 | Prompt injection filter | Block malicious | Injecções blocked |
| 14.2 | PII detection | Mask sensitive data | CPFs, emails masked |
| 14.3 | Toxicity filter | Block harmful content | Toxic blocked |
| 14.4 | Rate limiting | Per-user limits | Limites applied |

```python
# app/guardrails/input.py
class InputGuardrail:
    def __init__(
        self,
        injection_detector: InjectionDetector,
        pii_detector: PIIDetector,
        toxicity_detector: ToxicityDetector,
    ):
        self.detectors = [injection_detector, pii_detector, toxicity_detector]
    
    async def check(self, user_message: str) -> GuardrailResult:
        blocked = False
        reasons = []
        
        for detector in self.detectors:
            result = await detector.check(user_message)
            if result.blocked:
                blocked = True
                reasons.append(result.reason)
        
        return GuardrailResult(
            allowed=not blocked,
            sanitized=self._sanitize(user_message),
            reasons=reasons,
        )
    
    def _sanitize(self, message: str) -> str:
        # Mask detected PII
        return self.pii_detector.mask(message)
```

**Definition of Done:** Input blocks working, latency < 100ms.

---

### Sprint 29-30: AI Guardrails - Output + Memory

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 15.1 | Output filters | Fact verification | Facts validated |
| 15.2 | Content filtering | Safe responses | Inappropriate blocked |
| 15.3 | Tool output filter | Validate tool results | Results filtered |
| 15.4 | Conversation memory | Redis/HNSW storage | Context maintained |

```python
# app/guardrails/output.py
class OutputGuardrail:
    def __init__(
        self,
        fact_verifier: FactVerifier,
        content_filter: ContentFilter,
    ):
        self.fact_verifier = fact_verifier
        self.content_filter = content_filter
    
    async def check(self, response: str, context: dict) -> GuardrailResult:
        # Check for factual errors
        facts = await self.fact_verifier.extract(response)
        verified = await self.fact_verifier.verify(facts, context)
        
        # Check content safety
        safe = await self.content_filter.check(response)
        
        if not safe.allowed:
            return GuardrailResult(
                allowed=False,
                sanitized=safe.suggested_response,
                reasons=[safe.reason],
            )
        
        return GuardrailResult(
            allowed=True,
            sanitized=response,
            verified_facts=verified,
        )
```

**Definition of Done:** Output guardrails working, memory persisted.

---

## Fase 4: Hardening e Melhorias (Semanas 31-36)

### Sprint 31-32: Observabilidade

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 16.1 | Prometheus metrics | Métricas custom | Dashboards populados |
| 16.2 | Grafana dashboards | Platform overview | Dashboards funcionais |
| 16.3 | Alert rules | Prometheus alerts | Alertas triggering |
| 16.4 | Error tracking | Sentry/Datadog | Errors tracked |

```yaml
# prometheus/rules.yaml
groups:
  - name: service_rules
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
          / sum(rate(http_requests_total[5m])) by (service) > 0.01
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate on {{ $labels.service }}"
      
      - alert: HighLatency
        expr: histogram_quantile(0.95, 
          sum(rate(http_duration_seconds_bucket[5m])) by (le, service)) > 0.5
        for: 5m
        labels:
          severity: warning
```

**Definition of Done:** Dashboards operational, alertas firing.

---

### Sprint 33-34: Performance e Caching

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 17.1 | Redis caching | Multi-layer cache | Cache hit > 85% |
| 17.2 | CDN setup | CloudFront/R2 | Assets cached |
| 17.3 | Query optimization | Database indexes | Queries < 50ms |
| 17.4 | Connection pooling | PgBouncer | Connections reused |

```go
// internal/cache/product.go
func (s *ProductService) GetProduct(id string) (*Product, error) {
    // Try cache first
    cached, err := s.cache.Get(fmt.Sprintf("product:%s", id))
    if err == nil {
        var product Product
        if json.Unmarshal([]byte(cached), &product) == nil {
            return &product, nil
        }
    }
    
    // Fetch from database
    product, err := s.repo.GetProduct(id)
    if err != nil {
        return nil, err
    }
    
    // Cache with TTL
    data, _ := json.Marshal(product)
    s.cache.SetEx(fmt.Sprintf("product:%s", id), string(data), 5*60)
    
    return product, nil
}
```

**Definition of Done:** P95 latency < 200ms, cache hit > 85%.

---

### Sprint 35-36: Security e DR

| # | Entregável | Descrição | Critério de Aceite |
|---|------------|-----------|-------------------|
| 18.1 | WAF rules | OWASP rules | attacking blocked |
| 18.2 | mTLS | Service mesh | mTLS enabled |
| 18.3 | Backup strategy | Daily backups | Restore tested |
| 18.4 | DR simulation | Failover test | RTO < 1h |

```yaml
# terraform/waf.tf
resource "aws_wafv2_web_acl" "main" {
  name        = "ecommerce-waf"
  description = "WAF for ecommerce platform"
  scope       = "REGIONAL"
  
  default_rule {
    action = "allow"
  }
  
  rule {
    name     = "OWASPTop10"
    priority = 0
    
    statement {
      and_statement {
        statement {
          regex_pattern_set_reference_statement {
            pattern_set_id = aws_wafv2_regex_pattern_set.blocked.uri_ids
            field_to_match { single_header = "uri" }
          }
        }
        statement {
          byte_match_statement {
            field_to_match { single_header = "query_string" }
            search_string = "union+select"
            positional_constraint = "CONTAINS"
          }
        }
      }
    }
    
    action { block {} }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name            = "OWASPBlocked"
    }
  }
}
```

**Definition of Done:** Security audit passed, DR RTO < 1h.

---

## Resumo de Entregas por Sprint

| Fase | Sprints | Entregáveis |
|------|---------|-------------|
| **F1: Foundation** | 1-4 | Cluster → CI/CD → Auth v1 → Auth v2+MFA |
| **F2: E-commerce** | 5-10 | Products → Stock → Checkout → Payments → Shipping → MF |
| **F3: AI Agents** | 6-15 | Chat → NLU → Tools → Input Guardrails → Output Guardrails |
| **F4: Hardening** | 16-18 | Observability → Performance → Security+DR |

---

## Marcos (Milestones)

| Marco | Sprint | Data | Critério |
|-------|--------|------|----------|
| M1: Infra Functional | 2 | Semana 4 | K8s + CI/CD |
| M2: Auth Working | 4 | Semana 8 | Login + MFA + OAuth |
| M3: E-commerce Live | 10 | Semana 20 | Checkout completo |
| M4: AI Chat Live | 11 | Semana 22 | Chat com IA |
| M5: Production Ready | 18 | Semana 36 | Full platform |

---

## Dependências Entre Sprints

```
Sprint 1-2 ──► Sprint 3-4 ──► Sprint 5-6 ──► Sprint 7-8 ──► Sprint 9-10
    │              │              │              │              │
    ▼              ▼              ▼              ▼              ▼
[Cluster]      [CI/CD]  ──►  [Auth v1]  ──►  [Products]  ──►  [Stock]
                                              ▽
                                        Sprint 11-12 ──► Sprint 13-14 ──► Sprint 15-16 ──► Sprint 17-18 ──► Sprint 19-20
                                            │              │              │              │
                                            ▼              ▼              ▼              ▼
                                       [Cart]        [Payment]    [Shipping]      [Frontend]

Sprint 21-22 ──► Sprint 23-24 ──► Sprint 25-26 ──► Sprint 27-28 ──► Sprint 29-30 ──► Sprint 31-32
    │              │              │              │              │              │
    ▼              ▼              ▼              ▼              ▼              ▼
[Chat]        [NLU]         [Tools]      [Input GL]    [Output GL]    [Observability]

Sprint 33-34 ──► Sprint 35-36
    │              │
    ▼              ▼
[Cache]     [Security+DR]
```

---

## Definition of Done por Sprint

Para cada sprint, considerar concluído quando:

1. ✅ Código mergeado na main/develop
2. ✅ Testes unitários passando (>80% coverage)
3. ✅ Testes de integração passando
4. ✅ Code review aprovado
5. ✅ Deploy para staging funcionando
6. ✅ Documentação atualizada
7. ✅ Critérios de aceite do deliverable atingidos