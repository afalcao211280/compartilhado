# 10. Bancos de Dados

## 10.1 Visão Geral

Stack de bancos de dados para diferentes propósitos.

## 10.2 PostgreSQL

### Schema: Auth Service

```sql
-- Users
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    name VARCHAR(255),
    avatar_url TEXT,
    status VARCHAR(20) DEFAULT 'active',
    email_verified BOOLEAN DEFAULT FALSE,
    mfa_enabled BOOLEAN DEFAULT FALSE,
    mfa_secret VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP
);

CREATE INDEX idx_users_email ON users(lower(email));
CREATE INDEX idx_users_status ON users(status);

-- OAuth Accounts
CREATE TABLE oauth_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(50) NOT NULL,
    provider_user_id VARCHAR(255) NOT NULL,
    access_token TEXT,
    refresh_token TEXT,
    token_expires_at TIMESTAMP,
    UNIQUE(provider, provider_user_id)
);

-- Sessions
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    refresh_token VARCHAR(512) NOT NULL,
    user_agent TEXT,
    ip_address INET,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_sessions_user ON sessions(user_id);
CREATE INDEX idx_sessions_expires ON sessions(expires_at);
```

### Schema: Product Service

```sql
-- Categories
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID REFERENCES categories(id),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    description TEXT,
    image TEXT,
    position INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    path VARCHAR(255) NOT NULL, -- /electronics/phones
    level INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_categories_slug ON categories(slug);
CREATE INDEX idx_categories_parent ON categories(parent_id);
CREATE INDEX idx_categories_path ON categories(path);

-- Products
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    compare_at_price DECIMAL(10,2),
    category_id UUID REFERENCES categories(id),
    brand_id UUID,
    status VARCHAR(20) DEFAULT 'draft',
    weight DECIMAL(10,3),
    height DECIMAL(10,2),
    width DECIMAL(10,2),
    depth DECIMAL(10,2),
    seo_title VARCHAR(255),
    seo_description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_status ON products(status);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_created ON products(created_at DESC);

-- Product Variants
CREATE TABLE product_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    sku VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    compare_at_price DECIMAL(10,2),
    inventory INT DEFAULT 0,
    attributes JSONB DEFAULT '{}',
    image TEXT,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_variants_product ON product_variants(product_id);
CREATE INDEX idx_variants_sku ON product_variants(sku);
CREATE INDEX idx_variants_inventory ON product_variants(inventory);

-- Product Images
CREATE TABLE product_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    alt VARCHAR(255),
    position INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_images_product ON product_images(product_id, position);
```

### Schema: Order Service

```sql
-- Orders
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    subtotal DECIMAL(10,2) NOT NULL,
    shipping_cost DECIMAL(10,2) DEFAULT 0,
    discount DECIMAL(10,2) DEFAULT 0,
    total DECIMAL(10,2) NOT NULL,
    shipping_address JSONB NOT NULL,
    billing_address JSONB,
    payment_id VARCHAR(255),
    payment_status VARCHAR(50),
    shipping_id UUID,
    tracking_code VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created ON orders(created_at DESC);
CREATE INDEX idx_orders_tracking ON orders(tracking_code);

-- Order Items
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL,
    variant_id UUID,
    sku VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    quantity INT NOT NULL,
    total DECIMAL(10,2) NOT NULL
);

CREATE INDEX idx_order_items_order ON order_items(order_id);

-- Order Status History
CREATE TABLE order_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL,
    comment TEXT,
    created_by UUID,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_order_history_order ON order_status_history(order_id, created_at DESC);
```

## 10.3 Redis

### Data Structures

```redis
# Session storage
session:{session_id} -> HASH
  user_id: uuid
  created_at: timestamp
  last_activity: timestamp
  metadata: {}
EXPIRE session:{session_id} 604800  # 7 days

# User session list
user_sessions:{user_id} -> SET of session_ids
EXPIRE user_sessions:{user_id} 604800

# Product cache
product:{product_id} -> JSON
  name, price, inventory, etc
EXPIRE product:{product_id} 3600  # 1 hour

# Category cache
category:{category_id} -> JSON
  name, path, children, etc
EXPIRE category:{category_id} 86400  # 24 hours

# Cart storage
cart:{user_id} -> HASH
  items: [JSON array]
  updated_at: timestamp
  total: decimal
EXPIRE cart:{user_id} 2592000  # 30 days

# Quote storage
quote:{quote_id} -> JSON
  origin, destination, packages, quotes[]
EXPIRE quote:{quote_id} 86400  # 24 hours

# Rate limiting
ratelimit:{ip}:{endpoint} -> counter
  INCR + EXPIRE 60

# Chat context
chat:context:{session_id} -> JSON
  messages[], recent_context, user_info
EXPIRE chat:context:{session_id} 86400  # 24 hours

# LLM response cache
llm_cache:{hash(message)} -> JSON
  response, tokens_used, model
EXPIRE llm_cache:{hash} 3600  # 1 hour

# Distributed locks
lock:{resource} -> string (holder_id)
  with NX + EXPIRE for atomic lock
```

### Lua Scripts

```lua
-- Rate limiting script
local key = KEYS[1]
local limit = tonumber(ARGV[1])
local window = tonumber(ARGV[2])

local current = redis.call('INCR', key)
if current == 1 then
    redis.call('EXPIRE', key, window)
end

if current > limit then
    return 0
end
return 1

-- Cart add item script
local cart_key = KEYS[1]
local item = ARGV[1]

local items = redis.call('HGET', cart_key, 'items')
if items then
    items = cjson.decode(items)
else
    items = {}
end

table.insert(items, cjson.decode(item))
redis.call('HSET', cart_key, 'items', cjson.encode(items))
redis.call('EXPIRE', cart_key, 2592000)

return #items
```

## 10.4 Elasticsearch

### Index Mappings

```json
// Products Index
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "analysis": {
      "analyzer": {
        "portuguese_analyzer": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "portuguese_stemmer"]
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "id": { "type": "keyword" },
      "sku": { "type": "keyword" },
      "name": {
        "type": "text",
        "analyzer": "portuguese_analyzer",
        "fields": {
          "keyword": { "type": "keyword" },
          "autocomplete": {
            "type": "text",
            "analyzer": "autocomplete"
          }
        }
      },
      "description": { "type": "text", "analyzer": "portuguese_analyzer" },
      "price": { "type": "scaled_float", "scaling_factor": 100 },
      "category_id": { "type": "keyword" },
      "category_path": { "type": "keyword" },
      "brand_id": { "type": "keyword" },
      "brand_name": { "type": "text" },
      "status": { "type": "keyword" },
      "attributes": { "type": "object", "enabled": true },
      "variants": {
        "type": "nested",
        "properties": {
          "id": { "type": "keyword" },
          "name": { "type": "keyword" },
          "price": { "type": "scaled_float", "scaling_factor": 100 },
          "inventory": { "type": "integer" }
        }
      },
      "images": { "type": "keyword" },
      "created_at": { "type": "date" },
      "updated_at": { "type": "date" }
    }
  }
}

// Orders Index (for analytics)
{
  "settings": {
    "index.lifecycle.name": "orders-policy",
    "index.lifecycle.rollover_alias": "orders"
  },
  "mappings": {
    "properties": {
      "order_id": { "type": "keyword" },
      "customer_id": { "type": "keyword" },
      "status": { "type": "keyword" },
      "total": { "type": "scaled_float" },
      "items_count": { "type": "integer" },
      "category": { "type": "keyword" },
      "created_at": { "type": "date" }
    }
  }
}
```

### Search Examples

```python
# Product search with filters
def search_products(es, query, filters=None):
    must = []
    
    if query:
        must.append({
            "multi_match": {
                "query": query,
                "fields": ["name^3", "description^2", "brand_name", "sku"],
                "fuzziness": "AUTO"
            }
        })
    
    if filters:
        if filters.get("category"):
            must.append({"term": {"category_id": filters["category"]}})
        
        if filters.get("brands"):
            must.append({"terms": {"brand_id": filters["brands"]}})
        
        if filters.get("price_min") or filters.get("price_max"):
            price_range = {}
            if filters.get("price_min"):
                price_range["gte"] = filters["price_min"]
            if filters.get("price_max"):
                price_range["lte"] = filters["price_max"]
            must.append({"range": {"price": price_range}})
    
    return es.search(
        index="products",
        body={
            "query": {"bool": {"must": must}} if must else {"match_all": {}},
            "aggs": {
                "categories": {"terms": {"field": "category_id"}},
                "brands": {"terms": {"field": "brand_id"}},
                "price_range": {"range": {"field": "price", "ranges": [
                    {"to": 50}, {"from": 50, "to": 100},
                    {"from": 100, "to": 200}, {"from": 200}
                ]}}
            },
            "from": (filters.get("page", 1) - 1) * filters.get("page_size", 20),
            "size": filters.get("page_size", 20)
        }
    )
```

## 10.5 Vector Database (pgvector)

```sql
-- Enable extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Product embeddings table
CREATE TABLE product_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    chunk_index INT,
    content TEXT NOT NULL,
    embedding vector(1536),
    created_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT product_embedding_unique UNIQUE (product_id, chunk_index)
);

CREATE INDEX ON product_embeddings 
USING ivfflat (embedding vector_cosine_ops) 
WITH (lists = 100);

-- Policy embeddings
CREATE TABLE policy_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    embedding vector(1536),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX ON policy_embeddings 
USING ivfflat (embedding vector_cosine_ops);

-- Chat history embeddings
CREATE TABLE chat_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id VARCHAR(255) NOT NULL,
    message_id UUID NOT NULL,
    role VARCHAR(20) NOT NULL,
    content TEXT NOT NULL,
    embedding vector(1536),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX ON chat_embeddings 
USING ivfflat (embedding vector_cosine_ops);

-- Similarity search example
SELECT 
    id, product_id, 
    1 - (embedding <=> $1) as similarity,
    content
FROM product_embeddings
WHERE embedding <=> $1 < 0.3  -- Cosine distance < 0.3
ORDER BY embedding <=> $1
LIMIT 5;
```

## 10.6 Backup Strategy

```yaml
backup:
  postgresql:
    schedule: "0 * * * *"  # Hourly
    retention: 30 days
    type: pg_dump
    compression: lz4
    destination: s3://bucket/postgres-backups
  
  redis:
    schedule: "0 2 * * *"  # Daily at 2am
    retention: 7 days
    type: rdb_snapshot
    destination: s3://bucket/redis-backups
  
  elasticsearch:
    schedule: "0 3 * * *"  # Daily at 3am
    retention: 90 days
    type: snapshot
    destination: s3://bucket/elasticsearch-snapshots
  
  vector_db:
    schedule: "0 4 * * *"  # Daily at 4am
    retention: 30 days
    type: pg_dump + vector dump
    destination: s3://bucket/vector-backups
```