# 4. Sistema de Pagamentos

## 4.1 Overview

Microsserviço Go para processamento de pagamentos com múltiplos provedores.

## 4.2 Arquitetura

```
┌─────────────────────────────────────────────────────────────────────┐
│                      PAYMENT ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Client → BFF Checkout → Payment Service → Gateway Adapter           │
│                                      ↓                               │
│                         ┌─────────────────────────┐                  │
│                         │    ADAPTER LAYER       │                  │
│                         │  ┌────────┐ ┌────────┐  │                  │
│                         │  │ Stripe │ │Mercado │  │                  │
│                         │  │        │ │  Pago  │  │                  │
│                         │  └────────┘ └────────┘  │                  │
│                         │  ┌────────┐            │                  │
│                         │  │PAGSEGURO│            │                  │
│                         │  │        │            │                  │
│                         │  └────────┘            │                  │
│                         └─────────────────────────┘                  │
│                                      ↓                               ���
│                         ┌─────────────────────────┐                  │
│                         │   EVENT PUBLISHING     │                  │
│                         │  order.payment.*       │                  │
│                         │  payment.webhook.*     │                  │
│                         └─────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────────┘
```

## 4.3 Domain Model

```go
type Payment struct {
    ID              uuid.UUID       `json:"id"`
    OrderID         uuid.UUID       `json:"order_id"`
    CustomerID      uuid.UUID       `json:"customer_id"`
    Amount          decimal.Decimal `json:"amount"`
    Currency        string          `json:"currency"` // BRL, USD
    Status          PaymentStatus   `json:"status"`
    Method          PaymentMethod   `json:"method"`
    Provider        PaymentProvider `json:"provider"` // stripe, mercadopago
    ProviderID      string          `json:"provider_id,omitempty"`
    ProviderRef     string          `json:"provider_ref,omitempty"`
    IdempotencyKey  string          `json:"idempotency_key"`
    Metadata        JSONMap         `json:"metadata,omitempty"`
    Refunds         []Refund        `json:"refunds,omitempty"`
    CreatedAt       time.Time       `json:"created_at"`
    UpdatedAt       time.Time       `json:"updated_at"`
}

type PaymentStatus string

const (
    PaymentPending   PaymentStatus = "pending"
    PaymentProcessing PaymentStatus = "processing"
    PaymentAuthorized PaymentStatus = "authorized"
    PaymentCaptured  PaymentStatus = "captured"
    PaymentFailed    PaymentStatus = "failed"
    PaymentCancelled PaymentStatus = "cancelled"
    PaymentRefunded  PaymentStatus = "refunded"
    PaymentPartialRefunded PaymentStatus = "partial_refunded"
)

type PaymentMethod string

const (
    MethodCreditCard  PaymentMethod = "credit_card"
    MethodDebitCard   PaymentMethod = "debit_card"
    MethodPIX         PaymentMethod = "pix"
    MethodBoleto      PaymentMethod = "boleto"
    MethodBankTransfer PaymentMethod = "bank_transfer"
)

type Refund struct {
    ID            uuid.UUID       `json:"id"`
    PaymentID     uuid.UUID       `json:"payment_id"`
    Amount        decimal.Decimal `json:"amount"`
    Reason        string          `json:"reason"`
    Status        string          `json:"status"`
    ProviderRefundID string       `json:"provider_refund_id"`
    CreatedAt     time.Time       `json:"created_at"`
}
```

## 4.4 Gateway Adapter Pattern

```go
type PaymentGateway interface {
    // Create payment intent/charge
    CreatePayment(ctx context.Context, req CreatePaymentRequest) (*PaymentResult, error)
    
    // Capture authorized payment
    Capture(ctx context.Context, providerPaymentID string, amount decimal.Decimal) (*CaptureResult, error)
    
    // Cancel/refund payment
    Refund(ctx context.Context, providerPaymentID string, amount decimal.Decimal, reason string) (*RefundResult, error)
    
    // Get payment status
    GetStatus(ctx context.Context, providerPaymentID string) (*StatusResult, error)
    
    // Validate webhook signature
    ValidateWebhook(ctx context.Context, payload []byte, signature string) (*WebhookEvent, error)
}

type CreatePaymentRequest struct {
    Amount        decimal.Decimal
    Currency      string
    Method        PaymentMethod
    CustomerID    string
    OrderID       string
    CardToken     string // For card payments
    PayerEmail    string
    PayerName     string
    Metadata      map[string]string
}

type PaymentResult struct {
    ProviderPaymentID string
    Status            string
    AuthorizationCode string
    RawResponse       map[string]any
}
```

## 4.5 Stripe Adapter

```go
type StripeAdapter struct {
    client *stripe.Client
}

func (s *StripeAdapter) CreatePayment(ctx context.Context, req CreatePaymentRequest) (*PaymentResult, error) {
    idempotencyKey := req.Metadata["idempototency_key"]
    
    params := &stripe.PaymentIntentParams{
        Amount:   stripe.Int64(int64(req.Amount * 100)), // Stripe uses cents
        Currency: stripe.String(strings.ToLower(req.Currency)),
    }
    
    if req.CardToken != "" {
        params.PaymentMethod = stripe.String(req.CardToken)
    }
    
    switch req.Method {
    case MethodCreditCard:
        params.PaymentMethodTypes = []*string{stripe.String("card")}
    case MethodPIX:
        params.PaymentMethodTypes = []*string{stripe.String("pix")}
    }
    
    params.Metadata = req.Metadata
    params.Description = stripe.String(fmt.Sprintf("Order %s", req.OrderID))
    
    pi, err := s.client.PaymentIntents.New(params)
    if err != nil {
        return nil, fmt.Errorf("stripe create: %w", err)
    }
    
    return &PaymentResult{
        ProviderPaymentID: pi.ID,
        Status:            string(pi.Status),
        AuthorizationCode: pi.ID,
        RawResponse:       map[string]any{"client_secret": pi.ClientSecret},
    }, nil
}

func (s *StripeAdapter) ValidateWebhook(ctx context.Context, payload []byte, signature string) (*WebhookEvent, error) {
    event, err := s.client.WebhookPorts.ConstructEvent(
        payload,
        signature,
        webhookSecret,
    )
    if err != nil {
        return nil, err
    }
    
    return &WebhookEvent{
        Type: event.Type,
        Data: event.Data.Raw,
    }, nil
}
```

## 4.6 MercadoPago Adapter

```go
type MercadoPagoAdapter struct {
    client *mercadopago.Client
}

func (m *MercadoPagoAdapter) CreatePayment(ctx context.Context, req CreatePaymentRequest) (*PaymentResult, error) {
    payment := mercadopago.Payment{
        TransactionAmount: float64(req.Amount),
        Description:       fmt.Sprintf("Pedido %s", req.OrderID),
        PaymentMethodID:   m.mapMethod(req.Method),
        ExternalReference: req.OrderID,
        Metadata:          req.Metadata,
    }
    
    if req.Method == MethodCreditCard {
        payment.Token = req.CardToken
        payment.Payer = &mercadopago.Payer{
            Email: req.PayerEmail,
        }
    } else if req.Method == MethodPIX {
        payment.PaymentMethodID = "pix"
    }
    
    result, err := m.client.Payment.Create(payment)
    if err != nil {
        return nil, fmt.Errorf("mercadopago create: %w", err)
    }
    
    status := m.mapStatus(result.Status)
    
    response := &PaymentResult{
        ProviderPaymentID: strconv.Itoa(result.ID),
        Status:            status,
    }
    
    // PIX-specific data
    if req.Method == MethodPIX && result.PointOfInteraction != nil {
        response.RawResponse = map[string]any{
            "pix_qr_code":      result.PointOfInteraction.Data,
            "pix_expiration":  result.DateOfExpiration,
        }
    }
    
    return response, nil
}
```

## 4.7 API Endpoints

```yaml
REST Endpoints:
  POST   /payments/intent                    # Create payment intent
  GET    /payments/{id}                     # Get payment status
  POST   /payments/{id}/capture              # Capture authorized payment
  POST   /payments/{id}/cancel               # Cancel payment
  POST   /payments/{id}/refund               # Full refund
  POST   /payments/{id}/refund/partial       # Partial refund
  POST   /payments/webhook/stripe            # Stripe webhooks
  POST   /payments/webhook/mercadopago       # MercadoPago webhooks
  POST   /payments/webhook/pagseguro         # PAGSEGURO webhooks
  GET    /payments/methods                   # Available payment methods
  GET    /payments/{id}/history              # Payment history

gRPC Methods:
  CreatePaymentIntent(ctx, req) → Payment
  CapturePayment(ctx, payment_id) → Payment
  RefundPayment(ctx, req) → Refund
  GetPayment(ctx, payment_id) → Payment
```

## 4.8 Idempotency Implementation

```go
type IdempotencyService struct {
    redis *redis.Client
}

func (s *IdempotencyService) Check(ctx context.Context, key string) (*IdempotentRequest, error) {
    cached, err := s.redis.Get(ctx, fmt.Sprintf("idempotency:%s", key)).Bytes()
    if err == nil {
        var req IdempotentRequest
        json.Unmarshal(cached, &req)
        return &req, nil
    }
    return nil, nil
}

func (s *IdempotencyService) Store(ctx context.Context, key string, response interface{}) error {
    data, _ := json.Marshal(response)
    return s.redis.Set(ctx, fmt.Sprintf("idempotency:%s", key), data, 24*time.Hour)
}

// Usage in handler
func (h *PaymentHandler) CreateIntent(c *gin.Context) {
    idempotencyKey := c.GetHeader("Idempotency-Key")
    if idempotencyKey == "" {
        c.JSON(400, ErrorResponse{Error: "Idempotency-Key required"})
        return
    }
    
    // Check if already processed
    existing := h.idempotencyService.Check(c.Request.Context(), idempotencyKey)
    if existing != nil {
        c.JSON(200, existing.Response)
        return
    }
    
    // Process payment
    result, err := h.service.CreatePayment(c.Request.Context(), req)
    if err != nil {
        return err
    }
    
    // Store for future idempotent calls
    h.idempotencyService.Store(c.Request.Context(), idempotencyKey, result)
    
    return c.JSON(200, result)
}
```

## 4.9 Webhook Processing

```go
type WebhookHandler struct {
    stripeAdapter    PaymentGateway
    mercadoAdapter   PaymentGateway
    pagseguroAdapter PaymentGateway
}

func (h *WebhookHandler) HandleStripe(c *gin.Context) {
    payload, _ := io.ReadAll(c.Request.Body)
    signature := c.GetHeader("Stripe-Signature")
    
    event, err := h.stripeAdapter.ValidateWebhook(c.Request.Context(), payload, signature)
    if err != nil {
        c.JSON(400, gin.H{"error": "invalid signature"})
        return
    }
    
    switch event.Type {
    case "payment_intent.succeeded":
        h.processPaymentSuccess(event)
    case "payment_intent.payment_failed":
        h.processPaymentFailure(event)
    case "charge.refunded":
        h.processRefund(event)
    }
    
    c.JSON(200, gin.H{"received": true})
}

func (h *WebhookHandler) processPaymentSuccess(event *WebhookEvent) {
    var intent stripe.PaymentIntent
    json.Unmarshal(event.Data, &intent)
    
    // Update payment status in database
    // Publish event for order service
    h.eventBus.Publish(OrderPaymentCaptured{
        OrderID:   intent.Metadata["order_id"],
        PaymentID: intent.ID,
        Amount:    decimal.NewFromInt(intent.Amount),
    })
}
```

## 4.10 Testing

```go
func TestPaymentService_CreatePayment(t *testing.T) {
    tests := []struct {
        name        string
        req         CreatePaymentRequest
        mockSetup   func(*mockGateway)
        wantErr     bool
        wantStatus  PaymentStatus
    }{
        {
            name: "credit card success",
            req: CreatePaymentRequest{
                Amount:    decimal.NewFromInt(9990),
                Currency:  "BRL",
                Method:    MethodCreditCard,
                CardToken: "tok_valid",
            },
            mockSetup: func(m *mockGateway) {
                m.On("CreatePayment", mock.Anything, mock.Anything).Return(&PaymentResult{
                    ProviderPaymentID: "pi_123",
                    Status:            "requires_capture",
                }, nil)
            },
            wantErr:    false,
            wantStatus: PaymentAuthorized,
        },
        {
            name: "insufficient funds",
            req: CreatePaymentRequest{
                Amount:    decimal.NewFromInt(9990),
                Currency:  "BRL",
                Method:    MethodCreditCard,
                CardToken: "tok_declined",
            },
            mockSetup: func(m *mockGateway) {
                m.On("CreatePayment", mock.Anything, mock.Anything).Return(nil, &PaymentDeclinedError{
                    Code: "insufficient_funds",
                })
            },
            wantErr:    true,
            wantStatus: PaymentFailed,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            payment, err := service.CreatePayment(ctx, tt.req)
            if tt.wantErr {
                assert.Error(t, err)
                return
            }
            assert.NoError(t, err)
            assert.Equal(t, tt.wantStatus, payment.Status)
        })
    }
}
```