# 7. Arquitetura de Micro Frontends e BFF

## 7.1 Visão Geral

Arquitetura de micro frontends usando Module Federation com BFF dedicado em Golang.

## 7.2 Arquitetura

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SHELL (HOST APPLICATION)                        │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Next.js 15 App Router + Module Federation Host                 │    │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐     │    │
│  │  │  Auth   │ │ Catalog │ │  Cart   │ │Checkout │ │  Chat   │     │    │
│  │  │   MF    │ │   MF    │ │   MF    │ │   MF    │ │   MF    │     │    │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘     │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                          BFF LAYER (Golang)                              │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐            │
│  │  BFF    │ │  BFF    │ │  BFF    │ │  BFF    │ │  BFF    │            │
│  │  Auth   │ │ Catalog │ │  Cart   │ │Checkout │ │  Chat   │            │
│  │ Port:3001│ │ Port:3002│ │ Port:3003│ │ Port:3004│ │ Port:3005│            │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘            │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                      BACKEND SERVICES (Go)                               │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │
│  │  Auth   │ │Product  │ │  Order  │ │Payment  │ │Shipping │           │
│  │Service  │ │Service  │ │Service  │ │Service  │ │Service  │           │
│  │ gRPC    │ │ gRPC    │ │ gRPC    │ │ gRPC    │ │ gRPC    │           │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘           │
└─────────────────────────────────────────────────────────────────────────┘
```

## 7.3 Module Federation Configuration

### Shell (Host) - next.config.js

```javascript
const NextFederationPlugin = require('@module-federation/nextjs-mf')

/** @type {import('next').NextConfig} */
const nextConfig = {
  plugins: [
    new NextFederationPlugin({
      name: 'shell',
      filename: 'static/chunks/remoteEntry.js',
      remotes: {
        authMf:     'authMf@http://localhost:3001/remoteEntry.js',
        catalogMf:  'catalogMf@http://localhost:3002/remoteEntry.js',
        cartMf:     'cartMf@http://localhost:3003/remoteEntry.js',
        checkoutMf: 'checkoutMf@http://localhost:3004/remoteEntry.js',
        chatMf:     'chatMf@http://localhost:3005/remoteEntry.js',
      },
      shared: {
        react: { 
          singleton: true, 
          eager: true,
          requiredVersion: '^18.0.0',
          packageName: 'react'
        },
        'react-dom': { 
          singleton: true, 
          eager: true,
          requiredVersion: '^18.0.0',
          packageName: 'react-dom'
        },
        'react-dom/server': { 
          singleton: true,
          requiredVersion: '^18.0.0'
        },
      },
      exposePages: true,
      automaticPageRouting: true,
      skipValidationNext: false,
    })
  ],
  webpack(config, { isServer }) {
    if (!isServer) {
      config.optimization.splitChunks = {
        chunks: 'all',
        cacheGroups: {
          ...config.optimization.splitChunks.cacheGroups,
          common: {
            name: 'common',
            chunks: 'all',
            minSize: 1000,
          },
        },
      }
    }
    return config
  }
}

module.exports = nextConfig
```

### Remote (Catalog MF) - next.config.js

```javascript
const NextFederationPlugin = require('@module-federation/nextjs-mf')

const nextConfig = {
  plugins: [
    new NextFederationPlugin({
      name: 'catalogMf',
      filename: 'remoteEntry.js',
      exposes: {
        './ProductList':    './components/ProductList.tsx',
        './ProductDetail':  './components/ProductDetail.tsx',
        './ProductSearch':  './components/ProductSearch.tsx',
        './CategoryTree':   './components/CategoryTree.tsx',
        './ProductFilters': './components/ProductFilters.tsx',
        './Page':           './app/page.tsx',
      },
      shared: {
        react: { 
          singleton: true,
          packageName: 'react'
        },
        'react-dom': { 
          singleton: true,
          packageName: 'react-dom'
        },
      },
    })
  ],
  basePath: '/catalog',
}

module.exports = nextConfig
```

## 7.4 Shell Integration

```typescript
// app/layout.tsx (Shell)
import { ReactNode } from 'react'

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="pt-BR">
      <body>
        <AppProviders>
          <Navigation />
          <main>{children}</main>
          <Footer />
        </AppProviders>
      </body>
    </html>
  )
}

// app/catalog/[[...catchAll]]/page.tsx
import dynamic from 'next/dynamic'

const CatalogMF = dynamic(
  () => import('catalogMf/Page'),
  { 
    ssr: false,
    loading: () => <ProductListSkeleton />
  }
)

export default function CatalogPage() {
  return <CatalogMF />
}

// Or use exposed component directly
import dynamic from 'next/dynamic'

const ProductList = dynamic(
  () => import('catalogMf/ProductList'),
  { ssr: false }
)

// app/cart/page.tsx
import dynamic from 'next/dynamic'

const CartPage = dynamic(
  () => import('cartMf/Page'),
  { ssr: false }
)
```

## 7.5 Design System Shared

```typescript
// packages/design-system/src/index.ts
export { Button } from './components/Button'
export { Input } from './components/Input'
export { Card } from './components/Card'
export { Badge } from './components/Badge'
export { Modal } from './components/Modal'
export { Toast, ToastProvider } from './components/Toast'
export { Spinner } from './components/Spinner'
export { useToast } from './hooks/useToast'

// Types
export type { ButtonProps } from './components/Button'
export type { InputProps } from './components/Input'

// Constants
export { colors, spacing, typography } from './theme'
```

## 7.6 Shared State (Zustand)

```typescript
// packages/shared-store/src/index.ts
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface CartStore {
  items: CartItem[]
  addItem: (item: CartItem) => void
  removeItem: (productId: string) => void
  updateQuantity: (productId: string, quantity: number) => void
  clearCart: () => void
  total: () => number
}

export const useCartStore = create<CartStore>()(
  persist(
    (set, get) => ({
      items: [],
      addItem: (item) => set((state) => {
        const existing = state.items.find(i => i.productId === item.productId)
        if (existing) {
          return {
            items: state.items.map(i => 
              i.productId === item.productId 
                ? { ...i, quantity: i.quantity + item.quantity }
                : i
            )
          }
        }
        return { items: [...state.items, item] }
      }),
      removeItem: (productId) => set((state) => ({
        items: state.items.filter(i => i.productId !== productId)
      })),
      updateQuantity: (productId, quantity) => set((state) => ({
        items: state.items.map(i =>
          i.productId === productId ? { ...i, quantity } : i
        )
      })),
      clearCart: () => set({ items: [] }),
      total: () => get().items.reduce((sum, i) => sum + i.price * i.quantity, 0)
    }),
    { name: 'cart-storage' }
  )
)

// Usage in remote MF
import { useCartStore } from '@/shared/store'
```

## 7.7 BFF Architecture (Golang)

### Structure

```
bff-catalog/
├── cmd/
│   └── server/
│       └── main.go
├── internal/
│   ├── handler/
│   │   ├── product_handler.go
│   │   ├── search_handler.go
│   │   └── category_handler.go
│   ├── middleware/
│   │   ├── auth.go
│   │   ├── logging.go
│   │   └── ratelimit.go
│   ├── client/
│   │   ├── product_service.go
│   │   ├── search_service.go
│   │   └── cache.go
│   ├── mapper/
│   │   └── dto.go
│   └── config/
│       └── config.go
├── go.mod
└── Dockerfile
```

### Product Handler

```go
type ProductHandler struct {
    productClient *grpc.ProductServiceClient
    cache         *redis.Client
    logger        *log.Logger
}

type ProductListRequest struct {
    CategoryID  string     `query:"category_id"`
    Page        int        `query:"page"`
    PageSize    int        `query:"page_size"`
    SortBy      string     `query:"sort_by"`
    SortOrder   string     `query:"sort_order"`
    Filters     []string   `query:"filters"` // brand=apple&color=red
}

type ProductListResponse struct {
    Products    []ProductDTO `json:"products"`
    Pagination  PaginationDTO `json:"pagination"`
    Facets      FacetsDTO     `json:"facets"`
}

func (h *ProductHandler) ListProducts(c *gin.Context) {
    var req ProductListRequest
    if err := c.ShouldBindQuery(&req); err != nil {
        c.JSON(400, ErrorResponse{Error: "invalid parameters"})
        return
    }
    
    // Set defaults
    if req.Page < 1 {
        req.Page = 1
    }
    if req.PageSize < 1 || req.PageSize > 50 {
        req.PageSize = 20
    }
    
    // Check cache
    cacheKey := fmt.Sprintf("products:list:%s:%d:%d", req.CategoryID, req.Page, req.PageSize)
    if cached := h.getCache(c, cacheKey); cached != nil {
        c.JSON(200, cached)
        return
    }
    
    // Call product service
    filter := &pb.ProductFilter{
        CategoryId: req.CategoryID,
        Page:        int32(req.Page),
        PageSize:    int32(req.PageSize),
        SortBy:      req.SortBy,
        SortOrder:   req.SortOrder,
    }
    
    resp, err := h.productClient.ListProducts(c.Request.Context(), filter)
    if err != nil {
        h.logger.Error("product list failed", "error", err)
        c.JSON(500, ErrorResponse{Error: "internal error"})
        return
    }
    
    // Map to DTO
    result := h.mapProductList(resp)
    
    // Cache result
    h.setCache(c, cacheKey, result, 5*time.Minute)
    
    c.JSON(200, result)
}

func (h *ProductHandler) getCache(c *gin.Context, key string) []byte {
    data, err := h.cache.Get(c.Request.Context(), key).Bytes()
    if err != nil {
        return nil
    }
    return data
}

func (h *ProductHandler) setCache(c *gin.Context, key string, data interface{}, ttl time.Duration) {
    jsonData, _ := json.Marshal(data)
    h.cache.Set(c.Request.Context(), key, jsonData, ttl)
}
```

### Search Handler with Elasticsearch

```go
func (h *ProductHandler) Search(c *gin.Context) {
    var req SearchRequest
    if err := c.ShouldBindQuery(&req); err != nil {
        c.JSON(400, ErrorResponse{Error: "invalid parameters"})
        return
    }
    
    // Build Elasticsearch query
    query := h.buildSearchQuery(req)
    
    // Execute search
    result, err := h.esClient.Search().
        Index("products").
        Query(query).
        From((req.Page - 1) * req.PageSize).
        Size(req.PageSize).
        Do(c.Request.Context())
    
    if err != nil {
        c.JSON(500, ErrorResponse{Error: "search failed"})
        return
    }
    
    // Map results
    products := h.mapSearchResults(result)
    
    c.JSON(200, SearchResponse{
        Products:   products,
        Total:      result.TotalHits(),
        Page:       req.Page,
        PageSize:   req.PageSize,
    })
}

func (h *ProductHandler) buildSearchQuery(req SearchRequest) *elastic.BoolQuery {
    boolQuery := elastic.NewBoolQuery()
    
    // Full-text search
    if req.Query != "" {
        boolQuery.Must(
            elastic.NewMultiMatchQuery(req.Query, "name^3", "description", "brand").
                Type("best_fields").
                Fuzziness("AUTO").
                PrefixLength(2)
        )
    }
    
    // Category filter
    if req.CategoryID != "" {
        boolQuery.Filter(elastic.NewTermQuery("category_id", req.CategoryID))
    }
    
    // Price range
    if req.MinPrice > 0 || req.MaxPrice > 0 {
        rangeQuery := elastic.NewRangeQuery("price")
        if req.MinPrice > 0 {
            rangeQuery.Gte(req.MinPrice)
        }
        if req.MaxPrice > 0 {
            rangeQuery.Lte(req.MaxPrice)
        }
        boolQuery.Filter(rangeQuery)
    }
    
    // Brand filter
    if len(req.Brands) > 0 {
        boolQuery.Filter(elastic.NewTermsQuery("brand_id", req.Brands...))
    }
    
    // Attributes filter (e.g., color=red, size=M)
    for key, value := range req.Attributes {
        boolQuery.Filter(elastic.NewTermQuery("attributes."+key, value))
    }
    
    return boolQuery
}
```

## 7.8 BFF Chat Handler

```go
type ChatHandler struct {
    orchestratorClient *grpc.OrchestratorClient
    cache              *redis.Client
    logger             *log.Logger
}

type SendMessageRequest struct {
    Message    string   `json:"message" binding:"required"`
    SessionID  string   `json:"session_id"`
    UserID     string   `json:"user_id"`
    History    []Message `json:"history,omitempty"`
}

type SendMessageResponse struct {
    Message          string       `json:"message"`
    Agent            string       `json:"agent"`
    SuggestedActions []string     `json:"suggested_actions,omitempty"`
    Timestamp        time.Time    `json:"timestamp"`
}

func (h *ChatHandler) SendMessage(c *gin.Context) {
    var req SendMessageRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, ErrorResponse{Error: "invalid request"})
        return
    }
    
    // Rate limit check
    if h.isRateLimited(c) {
        c.JSON(429, ErrorResponse{Error: "rate limit exceeded"})
        return
    }
    
    // Get or create session
    sessionID := req.SessionID
    if sessionID == "" {
        sessionID = uuid.New().String()
    }
    
    // Load context from cache
    context := h.loadContext(c, sessionID)
    
    // Call AI orchestrator
    result, err := h.orchestratorClient.ProcessMessage(c.Request.Context(), &ai.ChatInput{
        Message:   req.Message,
        SessionID: sessionID,
        UserID:    req.UserID,
        Context:   context,
    })
    
    if err != nil {
        h.logger.Error("chat process failed", "error", err, "session", sessionID)
        c.JSON(500, ErrorResponse{Error: "processing failed"})
        return
    }
    
    // Update context cache
    h.updateContext(c, sessionID, result.Context)
    
    c.JSON(200, SendMessageResponse{
        Message:          result.Message,
        Agent:            result.AgentName,
        SuggestedActions: result.SuggestedActions,
        Timestamp:        time.Now(),
    })
}

func (h *ChatHandler) loadContext(c *gin.Context, sessionID string) *ai.Context {
    key := fmt.Sprintf("chat:context:%s", sessionID)
    data, err := h.cache.Get(c.Request.Context(), key).Bytes()
    if err != nil {
        return &ai.Context{}
    }
    
    var ctx ai.Context
    json.Unmarshal(data, &ctx)
    return &ctx
}

func (h *ChatHandler) updateContext(c *gin.Context, sessionID string, ctx *ai.Context) {
    key := fmt.Sprintf("chat:context:%s", sessionID)
    data, _ := json.Marshal(ctx)
    h.cache.Set(c.Request.Context(), key, data, 24*time.Hour)
}
```

## 7.9 Communication Between MFs

### Events (Event Bus)

```typescript
// packages/event-bus/src/index.ts
type EventMap = {
  'cart:updated': { items: CartItem[]; total: number }
  'user:logged-in': { userId: string; email: string }
  'product:viewed': { productId: string }
  'checkout:started': { orderId: string }
  'order:completed': { orderId: string }
}

class EventBus {
  private listeners = new Map<string, Set<Function>>()
  
  on<T extends keyof EventMap>(event: T, callback: (data: EventMap[T]) => void) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set())
    }
    this.listeners.get(event)!.add(callback)
    
    return () => {
      this.listeners.get(event)?.delete(callback)
    }
  }
  
  emit<T extends keyof EventMap>(event: T, data: EventMap[T]) {
    this.listeners.get(event)?.forEach(cb => cb(data))
  }
}

export const eventBus = new EventBus()

// Usage
eventBus.emit('cart:updated', { items: cartItems, total: 99.90 })

// Listen in another MF
eventBus.on('order:completed', ({ orderId }) => {
  console.log('Order completed:', orderId)
  clearCart()
})
```

## 7.10 Docker Configuration

```dockerfile
# bff-catalog/Dockerfile
FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o bff-catalog ./cmd/server

FROM alpine:3.19
WORKDIR /app
COPY --from=builder /app/bff-catalog .
COPY --from=builder /app/certs /app/certs

EXPOSE 3002

ENV GIN_MODE=release
ENV PORT=3002

CMD ["./bff-catalog"]
```

```dockerfile
# mf-catalog/Dockerfile
FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/.next /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 3002

CMD ["nginx", "-g", "daemon off;"]
```