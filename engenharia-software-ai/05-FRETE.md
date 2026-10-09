# 5. Sistema de Frete e Logística

## 5.1 Overview

Microsserviço Go para cálculo de fretes, geração de etiquetas e rastreamento.

## 5.2 Stack

- **Language**: Go 1.22+
- **Framework**: Gin
- **Database**: PostgreSQL
- **Cache**: Redis
- **Protocol**: gRPC + REST

## 5.3 Domain Model

```go
type ShippingQuote struct {
    ID              uuid.UUID       `json:"id"`
    QuoteID         string          `json:"quote_id"` // External reference
    OrderID         uuid.UUID       `json:"order_id,omitempty"`
    CustomerID      uuid.UUID       `json:"customer_id"`
    OriginZip       string          `json:"origin_zip"`
    DestinationZip  string          `json:"destination_zip"`
    Packages        []Package       `json:"packages"`
    Quotes          []CarrierQuote  `json:"quotes"` // Multiple carrier options
    ExpiresAt       time.Time       `json:"expires_at"`
    CreatedAt       time.Time       `json:"created_at"`
}

type Package struct {
    ID           uuid.UUID `json:"id"`
    Weight       float64   `json:"weight"` // kg
    Height       float64   `json:"height"` // cm
    Width        float64   `json:"width"`  // cm
    Depth        float64   `json:"depth"`  // cm
    Quantity     int       `json:"quantity"`
}

type CarrierQuote struct {
    ID           uuid.UUID       `json:"id"`
    CarrierID    string          `json:"carrier_id"` // correios, jadlog, loggi
    CarrierName  string          `json:"carrier_name"`
    ServiceCode  string          `json:"service_code"`
    ServiceName  string          `json:"service_name"`
    Price        decimal.Decimal `json:"price"`
    DeliveryDays int             `json:"delivery_days"`
    EstimatedDate time.Time      `json:"estimated_date"`
    CustomDeadline string        `json:"custom_deadline,omitempty"` // "entrega em até X dias úteis"
}

type Shipment struct {
    ID              uuid.UUID          `json:"id"`
    OrderID         uuid.UUID          `json:"order_id"`
    CarrierID       string             `json:"carrier_id"`
    CarrierName     string             `json:"carrier_name"`
    ServiceCode     string             `json:"service_code"`
    ServiceName     string             `json:"service_name"`
    TrackingCode    string             `json:"tracking_code"`
    LabelURL        string             `json:"label_url"`
    Status          ShipmentStatus     `json:"status"`
    Events          []TrackingEvent    `json:"events"`
    Cost            decimal.Decimal    `json:"cost"`
    DeliveredAt     *time.Time         `json:"delivered_at,omitempty"`
    CreatedAt       time.Time          `json:"created_at"`
    UpdatedAt       time.Time          `json:"updated_at"`
}

type ShipmentStatus string

const (
    ShipmentPending    ShipmentStatus = "pending"
    ShipmentLabeled    ShipmentStatus = "labeled"
    ShipmentPickedUp   ShipmentStatus = "picked_up"
    ShipmentInTransit  ShipmentStatus = "in_transit"
    ShipmentOutDelivery ShipmentStatus = "out_for_delivery"
    ShipmentDelivered  ShipmentStatus = "delivered"
    ShipmentFailed     ShipmentStatus = "delivery_failed"
    ShipmentReturned   ShipmentStatus = "returned"
)

type TrackingEvent struct {
    ID          uuid.UUID `json:"id"`
    Status      string    `json:"status"`
    Description string    `json:"description"`
    Location    string    `json:"location"`
    Timestamp   time.Time `json:"timestamp"`
}
```

## 5.4 Carrier Adapter Pattern

```go
type CarrierAdapter interface {
    // Calculate shipping quote
    CalculateQuote(ctx context.Context, req QuoteRequest) (*QuoteResult, error)
    
    // Create shipment and generate label
    CreateShipment(ctx context.Context, req ShipmentRequest) (*ShipmentResult, error)
    
    // Track shipment
    Track(ctx context.Context, trackingCode string) (*TrackingResult, error)
    
    // Cancel shipment
    Cancel(ctx context.Context, trackingCode string) error
    
    // Validate address
    ValidateAddress(ctx context.Context, address Address) (*AddressValidation, error)
}

type QuoteRequest struct {
    OriginZip       string
    DestinationZip string
    Packages        []Package
    ServiceTypes    []string // "pac", "sedex", "express"
}

type QuoteResult struct {
    CarrierID   string
    CarrierName string
    ServiceCode string
    ServiceName string
    Price       decimal.Decimal
    DeliveryDays int
    Errors      []string // Validation errors if partial success
}
```

## 5.5 Correios Adapter

```go
type CorreiosAdapter struct {
    client    *http.Client
    user      string
    password  string
    cardCode  string
    contract  string
}

func (c *CorreiosAdapter) CalculateQuote(ctx context.Context, req QuoteRequest) (*QuoteResult, error) {
    var quotes []CarrierQuote
    
    for _, pkg := range req.Packages {
        // Calculate volumetric weight
        volumetricWeight := (pkg.Height * pkg.Width * pkg.Depth) / 6000
        chargeableWeight := math.Max(pkg.Weight, volumetricWeight)
        
        for _, service := range req.ServiceTypes {
            quote, err := c.getQuoteForService(ctx, req.OriginZip, req.DestinationZip, chargeableWeight, service)
            if err != nil {
                continue
            }
            quotes = append(quotes, *quote)
        }
    }
    
    // Aggregate quotes (take lowest for each service)
    return c.aggregateQuotes(quotes), nil
}

func (c *CorreiosAdapter) getQuoteForService(ctx context.Context, origin, dest string, weight float64, service string) (*CarrierQuote, error) {
    // SOAP request to Correios
    body := fmt.Sprintf(`<?xml version="1.0" encoding="UTF-8"?>
    <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
    <SOAP-ENV:Body>
        <CalcPrecoPrazo>
            <nCdServico>%s</nCdServico>
            <sCepOrigem>%s</sCepOrigem>
            <sCepDestino>%s</sCepDestino>
            <nVlPeso>%.3f</nVlPeso>
        </CalcPrecoPrazo>
    </SOAP-ENV:Body>
    </SOAP-ENV:Envelope>`, service, origin, dest, weight)
    
    // Parse response
    // Return CarrierQuote or error
}
```

## 5.6 JadLog Adapter

```go
type JadLogAdapter struct {
    apiKey    string
    client    *http.Client
}

func (j *JadLogAdapter) CalculateQuote(ctx context.Context, req QuoteRequest) (*QuoteResult, error) {
    totalWeight := 0.0
    for _, pkg := range req.Packages {
        totalWeight += pkg.Weight * float64(pkg.Quantity)
    }
    
    // JadLog API call
    url := fmt.Sprintf("https://www.jadlog.com.br/api/frete?origem=%s&destino=%s&peso=%.2f",
        req.OriginZip, req.DestinationZip, totalWeight)
    
    req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
    req.Header.Set("Authorization", j.apiKey)
    
    resp, err := j.client.Do(req)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()
    
    var result JadLogQuoteResponse
    json.NewDecoder(resp.Body).Decode(&result)
    
    return &QuoteResult{
        CarrierID:    "jadlog",
        CarrierName:  "JadLog",
        ServiceCode:  result.Service,
        ServiceName:  result.ServiceName,
        Price:        decimal.NewFromFloat(result.Price),
        DeliveryDays: result.DeliveryDays,
    }, nil
}
```

## 5.7 Loggi Adapter

```go
type LoggiAdapter struct {
    clientID     string
    clientSecret string
    client       *http.Client
}

func (l *LoggiAdapter) CalculateQuote(ctx context.Context, req QuoteRequest) (*QuoteResult, error) {
    // Loggi has different pricing model - based on urban routes
    // Best for same-day and next-day delivery in capitals
    
    if !isCapitalCity(req.DestinationZip) {
        return nil, &CarrierNotAvailableError{
            Carrier: "loggi",
            Reason:  "Only available for capital cities",
        }
    }
    
    totalVolume := 0.0
    for _, pkg := range req.Packages {
        totalVolume += pkg.Height * pkg.Width * pkg.Depth * float64(pkg.Quantity)
    }
    
    quote, err := l.getQuote(ctx, req.DestinationZip, totalVolume)
    if err != nil {
        return nil, err
    }
    
    return &QuoteResult{
        CarrierID:    "loggi",
        CarrierName:  "Loggi",
        ServiceCode:  quote.Service,
        ServiceName:  "Loggi Express",
        Price:        decimal.NewFromFloat(quote.Price),
        DeliveryDays: quote.DeliveryDays,
    }, nil
}
```

## 5.8 API Endpoints

```yaml
REST Endpoints:
  POST   /shipping/quote                    # Calculate shipping quotes
  GET    /shipping/quote/{id}               # Get quote by ID
  POST   /shipping/calculate                # Quick calculation (no save)
  
  POST   /shipping/book                     # Book shipment
  GET    /shipping/{id}                    # Get shipment details
  GET    /shipping/{id}/track              # Get tracking events
  POST   /shipping/{id}/cancel              # Cancel shipment
  GET    /shipping/tracking/{code}         # Track by code
  
  POST   /shipping/webhook                  # Carrier webhooks
  GET    /shipping/carriers                 # Available carriers
  GET    /shipping/carriers/{id}/services   # Services by carrier

gRPC Methods:
  CalculateQuote(ctx, req) → ShippingQuote
  BookShipment(ctx, req) → Shipment
  TrackShipment(ctx, tracking_code) → TrackingResult
```

## 5.9 Quote Calculation Logic

```go
func (s *ShippingService) CalculateQuotes(ctx context.Context, req CalculateQuoteRequest) (*ShippingQuote, error) {
    // Validate ZIP codes
    if err := s.validateZipCodes(req.OriginZip, req.DestinationZip); err != nil {
        return nil, err
    }
    
    // Get available carriers for this route
    carriers := s.getAvailableCarriers(req.DestinationZip)
    
    var wg sync.WaitGroup
    quotesChan := make(chan CarrierQuote, len(carriers))
    errorsChan := make(chan error, len(carriers))
    
    // Query all carriers in parallel
    for _, carrier := range carriers {
        wg.Add(1)
        go func(c CarrierAdapter) {
            defer wg.Done()
            
            quoteReq := QuoteRequest{
                OriginZip:       req.OriginZip,
                DestinationZip:  req.DestinationZip,
                Packages:        req.Packages,
                ServiceTypes:    c.GetAvailableServices(),
            }
            
            result, err := c.CalculateQuote(ctx, quoteReq)
            if err != nil {
                errorsChan <- err
                return
            }
            
            quotesChan <- *result
        }(carrier)
    }
    
    wg.Wait()
    close(quotesChan)
    close(errorsChan)
    
    // Aggregate results
    var allQuotes []CarrierQuote
    for quote := range quotesChan {
        allQuotes = append(allQuotes, quote)
    }
    
    // Sort by price
    sort.Slice(allQuotes, func(i, j int) bool {
        return allQuotes[i].Price.LessThan(allQuotes[j].Price)
    })
    
    return &ShippingQuote{
        ID:             uuid.New(),
        QuoteID:        fmt.Sprintf("QT%d", time.Now().Unix()),
        CustomerID:     req.CustomerID,
        OriginZip:      req.OriginZip,
        DestinationZip: req.DestinationZip,
        Packages:       req.Packages,
        Quotes:         allQuotes,
        ExpiresAt:      time.Now().Add(24 * time.Hour),
    }, nil
}
```

## 5.10 Free Shipping Rules

```go
type FreeShippingRule struct {
    MinAmount      decimal.Decimal // Minimum order amount
    MaxAmount      decimal.Decimal // Maximum order amount (optional)
    Regions        []string        // ZIP code prefixes (e.g., ["01", "02"])
    Categories     []uuid.UUID     // Applicable categories
    Carriers       []string        // Which carriers support this
    MaxWeight      float64         // Maximum weight for free shipping
}

func (s *ShippingService) CheckFreeShipping(ctx context.Context, order Order) (*FreeShippingRule, error) {
    rules := s.getActiveRules()
    
    for _, rule := range rules {
        if s.matchesRule(order, rule) {
            // Apply free shipping to cheapest option
            return rule, nil
        }
    }
    
    return nil, nil // No free shipping
}

func (s *ShippingService) matchesRule(order Order, rule FreeShippingRule) bool {
    // Check minimum amount
    if order.Total.LessThan(rule.MinAmount) {
        return false
    }
    
    // Check maximum amount
    if rule.MaxAmount.IsPositive() && order.Total.GreaterThan(rule.MaxAmount) {
        return false
    }
    
    // Check region
    zipPrefix := order.ShippingAddress.ZipCode[:2]
    if !contains(rule.Regions, zipPrefix) {
        return false
    }
    
    // Check categories
    if len(rule.Categories) > 0 {
        hasMatch := false
        for _, item := range order.Items {
            if contains(rule.Categories, item.Product.CategoryID) {
                hasMatch = true
                break
            }
        }
        if !hasMatch {
            return false
        }
    }
    
    // Check weight
    totalWeight := 0.0
    for _, item := range order.Items {
        totalWeight += item.Product.Weight * float64(item.Quantity)
    }
    if totalWeight > rule.MaxWeight {
        return false
    }
    
    return true
}
```

## 5.11 Label Generation

```go
func (s *ShippingService) GenerateLabel(ctx context.Context, shipmentID uuid.UUID) (*LabelResult, error) {
    shipment, err := s.repo.GetShipment(ctx, shipmentID)
    if err != nil {
        return nil, err
    }
    
    carrier, ok := s.carriers[shipment.CarrierID]
    if !ok {
        return nil, &CarrierNotFoundError{Carrier: shipment.CarrierID}
    }
    
    // Create shipment with carrier
    result, err := carrier.CreateShipment(ctx, ShipmentRequest{
        OriginZip:      shipment.OriginZip,
        DestZip:        shipment.DestinationZip,
        Packages:       shipment.Packages,
        ServiceCode:    shipment.ServiceCode,
    })
    if err != nil {
        return nil, err
    }
    
    // Update shipment with tracking info
    shipment.TrackingCode = result.TrackingCode
    shipment.LabelURL = result.LabelURL
    shipment.Status = ShipmentLabeled
    s.repo.UpdateShipment(ctx, shipment)
    
    return result, nil
}
```

## 5.12 Testing

```go
func TestShippingService_CalculateQuotes(t *testing.T) {
    tests := []struct {
        name           string
        origin         string
        destination    string
        packages       []Package
        wantCarriers   int
        wantError      bool
    }{
        {
            name:        "same region quotes",
            origin:      "01310000",
            destination: "01315000",
            packages:    []Package{{Weight: 1, Height: 20, Width: 20, Depth: 10}},
            wantCarriers: 3,
            wantError:   false,
        },
        {
            name:        "no service available",
            origin:      "01310000",
            destination: "99999999",
            packages:    []Package{{Weight: 50}}, // Too heavy
            wantCarriers: 0,
            wantError:   false, // Partial success is OK
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result, err := service.CalculateQuotes(ctx, CalculateQuoteRequest{
                OriginZip:      tt.origin,
                DestinationZip: tt.destination,
                Packages:       tt.packages,
            })
            
            if tt.wantError {
                assert.Error(t, err)
                return
            }
            
            assert.NoError(t, err)
            assert.NotEmpty(t, result.Quotes)
            
            // Sort by price and verify
            prices := make([]float64, len(result.Quotes))
            for i, q := range result.Quotes {
                prices[i], _ = q.Price.Float64()
            }
            assert.True(t, sort.IsSorted(sort.Float64s(prices)))
        })
    }
}
```