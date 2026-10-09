# 8. Backend: Microsserviços em Golang

## 8.1 Arquitetura de Microsserviços

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          BACKEND SERVICES                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐        │
│  │    API    │   │    API    │   │    API    │   │    API    │        │
│  │  Gateway  │   │  Gateway  │   │  Gateway  │   │  Gateway  │        │
│  │  (Kong)   │   │  (Kong)   │   │  (Kong)   │   │  (Kong)   │        │
│  └─────┬─────┘   └─────┬─────┘   └─────┬─────┘   └─────┬─────┘        │
│        │               │               │               │                 │
│        └───────────────┴───────────────┴───────────────┘                 │
│                            │ gRPC                                        │
│        ┌───────────────────┼───────────────────┐                        │
│        │                   │                   │                        │
│  ┌─────▼─────┐       ┌─────▼─────┐       ┌─────▼─────┐                  │
│  │   Auth    │       │  Product  │       │   Order   │                  │
│  │  Service  │       │  Service  │       │  Service  │                  │
│  │    (Go)   │       │    (Go)   │       │    (Go)   │                  │
│  └─────┬─────┘       └─────┬─────┘       └─────┬─────┘                  │
│        │                   │                   │                         │
│  ┌─────▼─────┐       ┌─────▼─────┐       ┌─────▼─────┐                  │
│  │   Auth    │       │  Product  │       │   Order   │                  │
│  │   BFF     │       │   BFF     │       │   BFF     │                  │
│  └───────────┘       └───────────┘       └───────────┘                  │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                         MESSAGE BUS                               │   │
│  │                    (RabbitMQ / Kafka)                            │   │
│  │  order.created → payment.process → shipping.book → notify.user   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

## 8.2 Service Template Structure

```go
// cmd/server/main.go
package main

import (
    "context"
    "log"
    "net"
    "os"
    "os/signal"
    "syscall"
    
    "github.com/gin-gonic/gin"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/trace"
    "google.golang.org/grpc"
    "google.golang.org/grpc/reflection"
    
    "github.com/org/service/internal/config"
    "github.com/org/service/internal/handler"
    "github.com/org/service/internal/middleware"
    "github.com/org/service/internal/repository"
    "github.com/org/service/internal/service"
    pb "github.com/org/service/proto"
)

func main() {
    ctx := context.Background()
    
    // Initialize tracing
    tracerProvider := initTracer(ctx)
    defer tracerProvider.Shutdown(ctx)
    
    // Load config
    cfg := config.Load()
    
    // Initialize dependencies
    db, err := repository.NewPostgres(ctx, cfg.DatabaseURL)
    if err != nil {
        log.Fatalf("failed to connect to database: %v", err)
    }
    defer db.Close()
    
    redis := repository.NewRedis(ctx, cfg.RedisURL)
    defer redis.Close()
    
    repo := repository.NewRepository(db)
    svc := service.NewService(repo, redis)
    h := handler.NewHandler(svc)
    
    // gRPC server
    go func() {
        lis, err := net.Listen("tcp", cfg.GRPCAddr)
        if err != nil {
            log.Fatalf("failed to listen: %v", err)
        }
        
        grpcServer := grpc.NewServer(
            grpc.UnaryInterceptor(otelgrpc.UnaryServerInterceptor()),
        )
        pb.RegisterServiceServer(grpcServer, h)
        reflection.Register(grpcServer)
        
        log.Printf("gRPC server listening on %s", cfg.GRPCAddr)
        if err := grpcServer.Serve(lis); err != nil {
            log.Fatalf("failed to serve: %v", err)
        }
    }()
    
    // HTTP server
    r := gin.New()
    r.Use(middleware.Tracing())
    r.Use(middleware.Logging())
    r.Use(middleware.Recovery())
    r.Use(middleware.CORS())
    
    r.GET("/healthz", h.Healthz)
    r.GET("/readyz", h.Readyz)
    
    authMw := middleware.Auth(cfg.JWTPublicKey)
    r.GET("/api/v1/resource", authMw, h.GetResource)
    
    log.Printf("HTTP server listening on %s", cfg.HTTPAddr)
    
    // Graceful shutdown
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit
    
    log.Println("shutting down server...")
}
```

## 8.3 Order Service Implementation

### Domain Model

```go
// internal/domain/entity/order.go
type Order struct {
    ID              uuid.UUID       `json:"id"`
    CustomerID      uuid.UUID       `json:"customer_id"`
    Status          OrderStatus     `json:"status"`
    Items           []OrderItem     `json:"items"`
    Subtotal        decimal.Decimal `json:"subtotal"`
    ShippingCost    decimal.Decimal `json:"shipping_cost"`
    Discount        decimal.Decimal `json:"discount"`
    Total           decimal.Decimal `json:"total"`
    ShippingAddress Address         `json:"shipping_address"`
    BillingAddress  *Address        `json:"billing_address,omitempty"`
    Payment         *Payment        `json:"payment,omitempty"`
    Shipping        *Shipping       `json:"shipping,omitempty"`
    Notes           string          `json:"notes,omitempty"`
    CreatedAt       time.Time       `json:"created_at"`
    UpdatedAt       time.Time       `json:"updated_at"`
}

type OrderStatus string

const (
    OrderPending        OrderStatus = "pending"
    OrderConfirmed      OrderStatus = "confirmed"
    OrderPaid           OrderStatus = "paid"
    OrderProcessing     OrderStatus = "processing"
    OrderShipped        OrderStatus = "shipped"
    OrderDelivered      OrderStatus = "delivered"
    OrderCancelled      OrderStatus = "cancelled"
    OrderRefunded       OrderStatus = "refunded"
)

type OrderItem struct {
    ID          uuid.UUID       `json:"id"`
    ProductID   uuid.UUID       `json:"product_id"`
    VariantID   *uuid.UUID      `json:"variant_id,omitempty"`
    SKU         string          `json:"sku"`
    Name        string          `json:"name"`
    Price       decimal.Decimal `json:"price"`
    Quantity    int             `json:"quantity"`
    Total       decimal.Decimal `json:"total"`
    Image       string          `json:"image,omitempty"`
}
```

### Service Layer

```go
// internal/domain/service/order_service.go
type OrderService struct {
    repo       OrderRepository
    productSvc ProductServiceClient
    paymentSvc PaymentServiceClient
    eventBus   EventBus
    cache      *redis.Client
}

func (s *OrderService) CreateOrder(ctx context.Context, req *CreateOrderRequest) (*Order, error) {
    // Validate items exist and have stock
    items, err := s.validateAndEnrichItems(ctx, req.Items)
    if err != nil {
        return nil, err
    }
    
    // Calculate totals
    subtotal := s.calculateSubtotal(items)
    shippingCost := req.ShippingCost
    discount := req.Discount
    total := subtotal.Add(shippingCost).Sub(discount)
    
    // Create order
    order := &Order{
        ID:              uuid.New(),
        CustomerID:      req.CustomerID,
        Status:          OrderPending,
        Items:           items,
        Subtotal:        subtotal,
        ShippingCost:    shippingCost,
        Discount:        discount,
        Total:           total,
        ShippingAddress: req.ShippingAddress,
        Notes:           req.Notes,
        CreatedAt:       time.Now(),
        UpdatedAt:       time.Now(),
    }
    
    // Save to database
    if err := s.repo.Create(ctx, order); err != nil {
        return nil, fmt.Errorf("create order: %w", err)
    }
    
    // Reserve inventory
    if err := s.reserveInventory(ctx, order); err != nil {
        // Rollback order
        s.repo.Delete(ctx, order.ID)
        return nil, fmt.Errorf("reserve inventory: %w", err)
    }
    
    // Publish event
    s.eventBus.Publish(OrderCreatedEvent{
        OrderID:   order.ID,
        CustomerID: order.CustomerID,
        Total:      order.Total,
    })
    
    return order, nil
}

func (s *OrderService) ConfirmPayment(ctx context.Context, orderID uuid.UUID, paymentID string) error {
    order, err := s.repo.GetByID(ctx, orderID)
    if err != nil {
        return fmt.Errorf("get order: %w", err)
    }
    
    if order.Status != OrderPending {
        return &InvalidStatusError{Expected: OrderPending, Actual: order.Status}
    }
    
    order.Status = OrderPaid
    order.Payment = &Payment{ID: paymentID, Status: "captured"}
    order.UpdatedAt = time.Now()
    
    if err := s.repo.Update(ctx, order); err != nil {
        return fmt.Errorf("update order: %w", err)
    }
    
    // Publish event for fulfillment
    s.eventBus.Publish(OrderPaidEvent{
        OrderID:   order.ID,
        CustomerID: order.CustomerID,
        Items:      order.Items,
    })
    
    return nil
}

func (s *OrderService) CancelOrder(ctx context.Context, orderID, customerID uuid.UUID, reason string) error {
    order, err := s.repo.GetByID(ctx, orderID)
    if err != nil {
        return err
    }
    
    // Verify ownership
    if order.CustomerID != customerID {
        return ErrUnauthorized
    }
    
    // Check if cancellable
    if !order.CanCancel() {
        return &OrderCannotBeCancelledError{
            OrderID: orderID,
            Status:  order.Status,
        }
    }
    
    // Release inventory
    if err := s.releaseInventory(ctx, order); err != nil {
        log.Printf("failed to release inventory: %v", err)
    }
    
    // Refund if paid
    if order.Status == OrderPaid && order.Payment != nil {
        s.paymentSvc.Refund(ctx, order.Payment.ID, order.Total, reason)
    }
    
    order.Status = OrderCancelled
    order.UpdatedAt = time.Now()
    
    if err := s.repo.Update(ctx, order); err != nil {
        return fmt.Errorf("update order: %w", err)
    }
    
    s.eventBus.Publish(OrderCancelledEvent{
        OrderID:   order.ID,
        CustomerID: order.CustomerID,
        Reason:     reason,
    })
    
    return nil
}
```

### Repository Pattern

```go
// internal/domain/repository/order_repository.go
type OrderRepository interface {
    Create(ctx context.Context, order *Order) error
    GetByID(ctx context.Context, id uuid.UUID) (*Order, error)
    GetByCustomerID(ctx context.Context, customerID uuid.UUID, pagination Pagination) ([]*Order, int64, error)
    Update(ctx context.Context, order *Order) error
    Delete(ctx context.Context, id uuid.UUID) error
    FindByStatus(ctx context.Context, status OrderStatus, pagination Pagination) ([]*Order, error)
}

// internal/repository/postgres/order_repository.go
type PostgresOrderRepository struct {
    db *pgxpool.Pool
}

func (r *PostgresOrderRepository) Create(ctx context.Context, order *Order) error {
    query := `
        INSERT INTO orders (id, customer_id, status, subtotal, shipping_cost, discount, total,
                          shipping_address, notes, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
    `
    
    addressJSON, _ := json.Marshal(order.ShippingAddress)
    
    _, err := r.db.Exec(ctx, query,
        order.ID, order.CustomerID, order.Status, order.Subtotal, order.ShippingCost,
        order.Discount, order.Total, addressJSON, order.Notes, order.CreatedAt, order.UpdatedAt,
    )
    if err != nil {
        return err
    }
    
    // Insert items
    for _, item := range order.Items {
        itemQuery := `
            INSERT INTO order_items (id, order_id, product_id, variant_id, sku, name, price, quantity, total)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        `
        _, err := r.db.Exec(ctx, itemQuery,
            item.ID, order.ID, item.ProductID, item.VariantID, item.SKU, item.Name,
            item.Price, item.Quantity, item.Total,
        )
        if err != nil {
            return err
        }
    }
    
    return nil
}

func (r *PostgresOrderRepository) GetByID(ctx context.Context, id uuid.UUID) (*Order, error) {
    query := `
        SELECT id, customer_id, status, subtotal, shipping_cost, discount, total,
               shipping_address, billing_address, payment_id, payment_status,
               shipping_id, tracking_code, notes, created_at, updated_at
        FROM orders WHERE id = $1
    `
    
    row := r.db.QueryRow(ctx, query, id)
    
    var order Order
    var shippingAddrJSON, billingAddrJSON []byte
    var paymentID, paymentStatus, shippingID, trackingCode *string
    
    err := row.Scan(
        &order.ID, &order.CustomerID, &order.Status,
        &order.Subtotal, &order.ShippingCost, &order.Discount, &order.Total,
        &shippingAddrJSON, &billingAddrJSON,
        &paymentID, &paymentStatus, &shippingID, &trackingCode,
        &order.Notes, &order.CreatedAt, &order.UpdatedAt,
    )
    if err != nil {
        if errors.Is(err, pgx.ErrNoRows) {
            return nil, ErrOrderNotFound
        }
        return nil, err
    }
    
    json.Unmarshal(shippingAddrJSON, &order.ShippingAddress)
    if billingAddrJSON != nil {
        json.Unmarshal(billingAddrJSON, &order.BillingAddress)
    }
    
    // Get items
    items, err := r.getItems(ctx, order.ID)
    if err != nil {
        return nil, err
    }
    order.Items = items
    
    return &order, nil
}
```

## 8.4 gRPC Service Definition

```protobuf
// proto/order/v1/order.proto
syntax = "proto3";

package order.v1;

option go_package = "github.com/org/order-service/proto/order/v1";

service OrderService {
    rpc CreateOrder(CreateOrderRequest) returns (CreateOrderResponse);
    rpc GetOrder(GetOrderRequest) returns (GetOrderResponse);
    rpc ListOrders(ListOrdersRequest) returns (ListOrdersResponse);
    rpc UpdateOrderStatus(UpdateOrderStatusRequest) returns (UpdateOrderStatusResponse);
    rpc CancelOrder(CancelOrderRequest) returns (CancelOrderResponse);
    rpc AddOrderNote(AddOrderNoteRequest) returns (AddOrderNoteResponse);
}

message CreateOrderRequest {
    string customer_id = 1;
    repeated OrderItemInput items = 2;
    AddressInput shipping_address = 3;
    string shipping_cost = 4;
    string discount = 5;
    string notes = 6;
}

message OrderItemInput {
    string product_id = 1;
    string variant_id = 2;
    int32 quantity = 3;
}

message Order {
    string id = 1;
    string customer_id = 2;
    string status = 3;
    repeated OrderItem items = 4;
    string subtotal = 5;
    string shipping_cost = 6;
    string discount = 7;
    string total = 8;
    Address shipping_address = 9;
    int64 created_at = 10;
    int64 updated_at = 11;
}

message OrderItem {
    string id = 1;
    string product_id = 2;
    string variant_id = 3;
    string sku = 4;
    string name = 5;
    string price = 6;
    int32 quantity = 7;
    string total = 8;
}
```

## 8.5 Event Bus Implementation

```go
// internal/messaging/event_bus.go
type EventBus interface {
    Publish(ctx context.Context, event Event) error
    Subscribe(topic string, handler EventHandler) error
}

type Event struct {
    Type      string                 `json:"type"`
    Payload   map[string]interface{} `json:"payload"`
    Timestamp time.Time              `json:"timestamp"`
    TraceID   string                 `json:"trace_id"`
}

func NewEventBus(rabbitmqURL string) *RabbitMQEventBus {
    conn, err := amqp.Dial(rabbitmqURL)
    if err != nil {
        log.Fatalf("failed to connect to RabbitMQ: %v", err)
    }
    
    return &RabbitMQEventBus{conn: conn}
}

type RabbitMQEventBus struct {
    conn *amqp.Connection
}

func (b *RabbitMQEventBus) Publish(ctx context.Context, event Event) error {
    ch, err := b.conn.Channel()
    if err != nil {
        return err
    }
    defer ch.Close()
    
    body, _ := json.Marshal(event)
    
    err = ch.PublishWithContext(ctx,
        "orders",      // exchange
        event.Type,    // routing key
        false,         // mandatory
        false,         // immediate
        amqp.Publishing{
            ContentType:  "application/json",
            Body:         body,
            DeliveryMode: amqp.Persistent,
            Timestamp:    event.Timestamp,
            MessageId:    uuid.New().String(),
        },
    )
    
    return err
}

func (b *RabbitMQEventBus) Subscribe(topic string, handler EventHandler) error {
    ch, err := b.conn.Channel()
    if err != nil {
        return err
    }
    
    // Declare exchange
    ch.ExchangeDeclare("orders", "topic", true, false, false, false, nil)
    
    // Declare queue
    q, err := ch.QueueDeclare("", true, true, false, false)
    if err != nil {
        return err
    }
    
    // Bind queue to topic
    ch.QueueBind(q.Name, topic, "orders", false, nil)
    
    // Consume
    msgs, err := ch.Consume(q.Name, "", false, false, false, false, nil)
    
    go func() {
        for msg := range msgs {
            var event Event
            json.Unmarshal(msg.Body, &event)
            
            if err := handler.Handle(ctx, event); err != nil {
                log.Printf("event handler error: %v", err)
                msg.Nack(false, true) // Requeue
            } else {
                msg.Ack(false)
            }
        }
    }()
    
    return nil
}
```

## 8.6 Testing

```go
// internal/domain/service/order_service_test.go
func TestOrderService_CreateOrder(t *testing.T) {
    tests := []struct {
        name    string
        req     *CreateOrderRequest
        setup   func(*mockRepo, *mockProductSvc)
        wantErr bool
    }{
        {
            name: "valid order",
            req: &CreateOrderRequest{
                CustomerID: uuid.New(),
                Items: []OrderItemInput{
                    {ProductID: uuid.New(), Quantity: 2},
                },
                ShippingAddress: Address{ZipCode: "01310000"},
            },
            setup: func(repo *mockRepo, ps *mockProductSvc) {
                ps.On("CheckInventory", mock.Anything, mock.Anything, 2).Return(true, nil)
                repo.On("Create", mock.Anything, mock.Anything).Return(nil)
            },
            wantErr: false,
        },
        {
            name: "out of stock",
            req: &CreateOrderRequest{
                CustomerID: uuid.New(),
                Items: []OrderItemInput{
                    {ProductID: uuid.New(), Quantity: 100},
                },
            },
            setup: func(repo *mockRepo, ps *mockProductSvc) {
                ps.On("CheckInventory", mock.Anything, mock.Anything, 100).Return(false, nil)
            },
            wantErr: true,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            repo := newMockOrderRepo()
            ps := newMockProductSvc()
            tt.setup(repo, ps)
            
            svc := NewOrderService(repo, ps, nil, nil)
            order, err := svc.CreateOrder(context.Background(), tt.req)
            
            if tt.wantErr {
                assert.Error(t, err)
                return
            }
            
            assert.NoError(t, err)
            assert.NotNil(t, order)
            assert.Equal(t, OrderPending, order.Status)
        })
    }
}
```