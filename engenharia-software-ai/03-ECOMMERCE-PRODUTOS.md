# 3. E-commerce: Gestão de Produtos

## 3.1 Overview

Microsserviço Go para gestão completa do catálogo de produtos.

## 3.2 Stack

- **Language**: Go 1.22+
- **Framework**: Gin
- **Database**: PostgreSQL
- **Search**: Elasticsearch
- **Cache**: Redis
- **Protocol**: gRPC + REST

## 3.3 Domain Model

```go
type Product struct {
    ID          uuid.UUID       `json:"id"`
    SKU         string          `json:"sku"`
    Name        string          `json:"name"`
    Description string          `json:"description"`
    Price       decimal.Decimal `json:"price"`
    CompareAtPrice decimal.Decimal `json:"compare_at_price,omitempty"`
    CategoryID  uuid.UUID       `json:"category_id"`
    BrandID     uuid.UUID       `json:"brand_id,omitempty"`
    Status      ProductStatus   `json:"status"` // active, draft, archived
    Images      []ProductImage  `json:"images"`
    Variants    []ProductVariant `json:"variants"`
    Attributes  JSONMap         `json:"attributes,omitempty"`
    Weight      float64         `json:"weight,omitempty"` // kg
    Dimensions  *Dimensions     `json:"dimensions,omitempty"`
    SEO         *SEO            `json:"seo,omitempty"`
    CreatedAt   time.Time       `json:"created_at"`
    UpdatedAt   time.Time       `json:"updated_at"`
}

type ProductVariant struct {
    ID          uuid.UUID       `json:"id"`
    ProductID   uuid.UUID       `json:"product_id"`
    SKU         string          `json:"sku"`
    Name        string          `json:"name"`
    Price       decimal.Decimal `json:"price"`
    CompareAtPrice decimal.Decimal `json:"compare_at_price,omitempty"`
    Inventory   int             `json:"inventory"`
    Attributes  map[string]string `json:"attributes"` // color=red, size=M
    Images      []string        `json:"images,omitempty"`
    Status      string          `json:"status"`
}

type Category struct {
    ID          uuid.UUID  `json:"id"`
    ParentID    *uuid.UUID `json:"parent_id,omitempty"`
    Name        string     `json:"name"`
    Slug        string     `json:"slug"`
    Description string     `json:"description,omitempty"`
    Image       string     `json:"image,omitempty"`
    Position    int        `json:"position"`
    IsActive    bool       `json:"is_active"`
    Path        string     `json:"path"` // /electronics/phones/smartphones
}

type Brand struct {
    ID          uuid.UUID `json:"id"`
    Name        string    `json:"name"`
    Slug        string    `json:"slug"`
    Logo        string    `json:"logo,omitempty"`
    Description string    `json:"description,omitempty"`
    Website     string    `json:"website,omitempty"`
}
```

## 3.4 API Endpoints

```yaml
REST Endpoints:
  GET    /products                    # List products (paginated)
  GET    /products/{id}               # Get product by ID
  POST   /products                    # Create product
  PUT    /products/{id}               # Update product
  DELETE /products/{id}               # Delete product (soft)
  
  GET    /products/search             # Full-text search
  GET    /products/{id}/variants       # List variants
  POST   /products/{id}/variants       # Add variant
  PUT    /products/{id}/variants/{vid} # Update variant
  DELETE /products/{id}/variants/{vid} # Delete variant
  
  GET    /products/{id}/inventory     # Get inventory
  PUT    /products/{id}/inventory     # Update inventory
  POST   /products/{id}/inventory/batch # Batch update
  
  GET    /categories                  # List categories (tree)
  GET    /categories/{id}             # Get category
  POST   /categories                  # Create category
  PUT    /categories/{id}             # Update category
  DELETE /categories/{id}             # Delete category
  
  GET    /brands                      # List brands
  GET    /brands/{id}                 # Get brand
  POST   /brands                      # Create brand
  PUT    /brands/{id}                 # Update brand

gRPC Methods:
  GetProduct(ctx, id) → Product
  ListProducts(ctx, filter) → ProductList
  SearchProducts(ctx, query) → ProductList
  UpdateInventory(ctx, request) → InventoryResult
```

## 3.5 Elasticsearch Mapping

```json
{
  "mappings": {
    "properties": {
      "id": { "type": "keyword" },
      "sku": { "type": "keyword" },
      "name": { 
        "type": "text",
        "analyzer": " portuguese",
        "fields": { "keyword": { "type": "keyword" } }
      },
      "description": { "type": "text", "analyzer": "portuguese" },
      "price": { "type": "scaled_float", "scaling_factor": 100 },
      "category_id": { "type": "keyword" },
      "category_path": { "type": "keyword" },
      "brand_id": { "type": "keyword" },
      "brand_name": { "type": "text" },
      "status": { "type": "keyword" },
      "attributes": { "type": "object", "enabled": true },
      "variants_count": { "type": "integer" },
      "min_price": { "type": "scaled_float" },
      "max_price": { "type": "scaled_float" },
      "total_inventory": { "type": "integer" },
      "created_at": { "type": "date" },
      "updated_at": { "type": "date" }
    }
  },
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "analysis": {
      "analyzer": {
        "portuguese": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "portuguese_stemmer"]
        }
      }
    }
  }
}
```

## 3.6 Inventory Management

```go
type InventoryService struct {
    repo InventoryRepository
    cache *redis.Client
}

func (s *InventoryService) CheckAvailability(productID, variantID uuid.UUID, quantity int) (bool, int, error) {
    // Try cache first
    cacheKey := fmt.Sprintf("inventory:%s:%s", productID, variantID)
    cached, err := s.cache.Get(ctx, cacheKey).Int()
    if err == nil {
        return cached >= quantity, cached, nil
    }
    
    // Get from DB
    inventory, err := s.repo.GetInventory(ctx, productID, variantID)
    if err != nil {
        return false, 0, err
    }
    
    // Cache result (short TTL for inventory)
    s.cache.Set(ctx, cacheKey, inventory, 30*time.Second)
    
    return inventory >= quantity, inventory, nil
}

func (s *InventoryService) Reserve(ctx context.Context, items []InventoryItem) error {
    return s.db.Transaction(func(tx *sql.Tx) error {
        for _, item := range items {
            locked, err := s.repo.ReserveInventory(ctx, tx, item.ProductID, item.VariantID, item.Quantity)
            if err != nil {
                return fmt.Errorf("reserve %s:%s: %w", item.ProductID, item.VariantID, err)
            }
            if !locked {
                return &InsufficientStockError{
                    ProductID: item.ProductID,
                    VariantID: item.VariantID,
                    Requested: item.Quantity,
                }
            }
        }
        return nil
    })
}
```

## 3.7 Sync with Elasticsearch

```go
type ElasticsearchSync struct {
    esClient *elastic.Client
    postgres *pgxpool.Pool
}

func (s *ElasticsearchSync) FullReindex(ctx context.Context) error {
    // Create new index
    newIndex := fmt.Sprintf("products_%d", time.Now().Unix())
    s.createIndex(ctx, newIndex)
    
    // Stream products from PostgreSQL
    query := `SELECT id FROM products WHERE status = 'active'`
    rows, err := s.postgres.Query(ctx, query)
    if err != nil {
        return err
    }
    defer rows.Close()
    
    bulk := s.esClient.BulkProcessor(newIndex)
    defer bulk.Close()
    
    for rows.Next() {
        var id uuid.UUID
        rows.Scan(&id)
        
        product, err := s.getProductWithVariants(ctx, id)
        if err != nil {
            continue
        }
        
        doc := s.transformToDocument(product)
        bulk.Add(elastic.NewBulkIndexRequest().Index(newIndex).Doc(doc))
    }
    
    return bulk.Flush()
}

func (s *ElasticsearchSync) IncrementalSync(ctx context.Context, since time.Time) error {
    // Get products updated since timestamp
    query := `SELECT id FROM products WHERE updated_at > $1`
    // ... sync logic
}
```

## 3.8 Testing

```go
func TestProductService_GetBySKU(t *testing.T) {
    tests := []struct {
        name    string
        sku     string
        wantErr bool
    }{
        {
            name:    "existing product",
            sku:     "SKU-001",
            wantErr: false,
        },
        {
            name:    "non-existing",
            sku:     "INVALID",
            wantErr: true,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            product, err := service.GetBySKU(ctx, tt.sku)
            if tt.wantErr {
                assert.Error(t, err)
                return
            }
            assert.NoError(t, err)
            assert.Equal(t, tt.sku, product.SKU)
        })
    }
}
```