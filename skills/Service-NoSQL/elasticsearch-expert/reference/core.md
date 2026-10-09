# Elasticsearch Expert — Padrões de Código

## 1. Mapeamento de Índice (Index Mapping)

```json
PUT /products
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 1,
    "analysis": {
      "analyzer": {
        "portuguese_analyzer": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "portuguese_stop", "portuguese_stemmer"]
        }
      },
      "filter": {
        "portuguese_stop": {
          "type": "stop",
          "stopwords": "_portuguese_"
        },
        "portuguese_stemmer": {
          "type": "stemmer",
          "language": "light_portuguese"
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "id": { "type": "keyword" },
      "name": {
        "type": "text",
        "analyzer": "portuguese_analyzer",
        "fields": {
          "keyword": { "type": "keyword", "ignore_above": 256 },
          "suggest": { "type": "completion" }
        }
      },
      "description": { "type": "text", "analyzer": "portuguese_analyzer" },
      "category": { "type": "keyword" },
      "price": { "type": "double" },
      "tags": { "type": "keyword" },
      "active": { "type": "boolean" },
      "stock": { "type": "integer" },
      "createdAt": { "type": "date", "format": "strict_date_optional_time" }
    }
  }
}
```

---

## 2. Cliente TypeScript — Configuração e CRUD

```typescript
// src/lib/elasticsearch.ts
import { Client } from '@elastic/elasticsearch';

export const esClient = new Client({
  node: process.env['ELASTICSEARCH_URL'] ?? 'http://localhost:9200',
  auth: {
    apiKey: process.env['ELASTICSEARCH_API_KEY'] ?? '',
  },
  tls: {
    rejectUnauthorized: process.env['NODE_ENV'] === 'production',
  },
});

// Health check
export async function checkElasticsearchHealth(): Promise<boolean> {
  try {
    const health = await esClient.cluster.health({ wait_for_status: 'yellow', timeout: '5s' });
    return health.status !== 'red';
  } catch {
    return false;
  }
}
```

```typescript
// src/repositories/product.search.repository.ts
import { esClient } from '@/lib/elasticsearch';
import type { Product } from '@/types/product';

const INDEX = 'products';

export class ProductSearchRepository {
  async index(product: Product): Promise<void> {
    await esClient.index({
      index: INDEX,
      id: product.id,
      document: product,
      refresh: 'wait_for', // só em dev; em prod usar 'false'
    });
  }

  async bulkIndex(products: Product[]): Promise<void> {
    const operations = products.flatMap((p) => [
      { index: { _index: INDEX, _id: p.id } },
      p,
    ]);
    const { errors, items } = await esClient.bulk({ operations, refresh: false });
    if (errors) {
      const failed = items.filter((i) => i.index?.error);
      throw new Error(`Bulk index errors: ${JSON.stringify(failed)}`);
    }
  }

  async deleteById(id: string): Promise<void> {
    await esClient.delete({ index: INDEX, id, refresh: 'wait_for' });
  }
}
```

---

## 3. Search Query — Full-text + Filtros

```typescript
// src/repositories/product.search.repository.ts (continuação)
interface ProductSearchParams {
  query?: string;
  category?: string;
  minPrice?: number;
  maxPrice?: number;
  tags?: string[];
  page?: number;
  size?: number;
}

async search(params: ProductSearchParams): Promise<{ items: Product[]; total: number }> {
  const { query, category, minPrice, maxPrice, tags, page = 1, size = 20 } = params;

  const must: object[] = [{ term: { active: true } }];
  const filter: object[] = [];

  if (query) {
    must.push({
      multi_match: {
        query,
        fields: ['name^3', 'description'],
        type: 'best_fields',
        fuzziness: 'AUTO',
      },
    });
  }

  if (category) filter.push({ term: { category } });
  if (tags?.length) filter.push({ terms: { tags } });
  if (minPrice !== undefined || maxPrice !== undefined) {
    filter.push({
      range: {
        price: {
          ...(minPrice !== undefined && { gte: minPrice }),
          ...(maxPrice !== undefined && { lte: maxPrice }),
        },
      },
    });
  }

  const response = await esClient.search<Product>({
    index: INDEX,
    from: (page - 1) * size,
    size,
    query: { bool: { must, filter } },
    sort: query ? ['_score', { createdAt: 'desc' }] : [{ createdAt: 'desc' }],
    highlight: query
      ? { fields: { name: {}, description: { fragment_size: 150 } } }
      : undefined,
  });

  return {
    items: response.hits.hits.map((h) => h._source as Product),
    total: typeof response.hits.total === 'number' ? response.hits.total : response.hits.total?.value ?? 0,
  };
}
```

---

## 4. Aggregations

```typescript
// Facets para filtros dinâmicos + stats de preço
async getFacets(query?: string) {
  const response = await esClient.search({
    index: INDEX,
    size: 0, // só aggregations, sem hits
    query: query
      ? { multi_match: { query, fields: ['name^3', 'description'], fuzziness: 'AUTO' } }
      : { match_all: {} },
    aggs: {
      categories: {
        terms: { field: 'category', size: 20 },
        aggs: {
          // Sub-aggregation: count de produtos ativos por categoria
          active_count: { filter: { term: { active: true } } },
        },
      },
      tags: { terms: { field: 'tags', size: 50 } },
      price_stats: {
        stats: { field: 'price' },
      },
      price_ranges: {
        range: {
          field: 'price',
          ranges: [
            { to: 50 },
            { from: 50, to: 200 },
            { from: 200, to: 500 },
            { from: 500 },
          ],
        },
      },
    },
  });

  return response.aggregations;
}
```

---

## 5. Autocomplete / Suggest

```typescript
// Usando completion suggester (requer campo "suggest" do tipo "completion")
async suggest(prefix: string): Promise<string[]> {
  const response = await esClient.search({
    index: INDEX,
    suggest: {
      product_suggest: {
        prefix,
        completion: {
          field: 'name.suggest',
          size: 5,
          skip_duplicates: true,
          fuzzy: { fuzziness: 1 },
        },
      },
    },
    _source: false,
  });

  return (
    response.suggest?.product_suggest?.[0]?.options?.map((opt) => {
      if ('text' in opt) return opt.text as string;
      return '';
    }).filter(Boolean) ?? []
  );
}
```

---

## 6. Sincronização com PostgreSQL (via eventos)

```typescript
// src/services/product.sync.service.ts
// Padrão: DB → Event → Elasticsearch sync

import { ProductSearchRepository } from '@/repositories/product.search.repository';
import { ProductRepository } from '@/repositories/product.repository';

export class ProductSyncService {
  constructor(
    private readonly dbRepo: ProductRepository,
    private readonly searchRepo: ProductSearchRepository,
  ) {}

  async onProductCreated(id: string): Promise<void> {
    const product = await this.dbRepo.findById(id);
    if (product) await this.searchRepo.index(product);
  }

  async onProductUpdated(id: string): Promise<void> {
    const product = await this.dbRepo.findById(id);
    if (product) await this.searchRepo.index(product);
  }

  async onProductDeleted(id: string): Promise<void> {
    await this.searchRepo.deleteById(id);
  }

  async reindexAll(): Promise<void> {
    const products = await this.dbRepo.findAll();
    await this.searchRepo.bulkIndex(products);
  }
}
```

---

## 7. Queries de Diagnóstico

```bash
# Health do cluster
GET /_cluster/health?pretty

# Status dos índices
GET /_cat/indices?v&s=docs.count:desc

# Slow queries log
PUT /products/_settings
{ "index.search.slowlog.threshold.query.warn": "1s",
  "index.search.slowlog.threshold.query.info": "500ms" }

# Explain de um query (por que o score é X)
GET /products/_explain/doc-id
{ "query": { "match": { "name": "laptop" } } }

# Forçar merge de segmentos (após bulk delete, em manutenção)
POST /products/_forcemerge?max_num_segments=1
```

---

## Anti-patterns

### ❌ Paginação deep com from/size
**Problema:** Usar `from: 10000, size: 10` para paginar resultados em ES.
**Por quê evitar:** ES carrega e descarta os N primeiros documentos em cada shard para calcular o offset — custo O(from×shards); acima de `index.max_result_window` (padrão 10k) retorna erro.
**Solução:**
```json
// Primeira página
POST /products/_search
{ "size": 10, "sort": [{"_id": "asc"}], "search_after": null }

// Próximas páginas: usar o valor de sort da última linha
{ "size": 10, "sort": [{"_id": "asc"}], "search_after": ["ultimo-id-da-pagina"] }
```

### ❌ Dynamic mapping habilitado em produção
**Problema:** Não configurar `dynamic: false` ou `dynamic: strict` no mapping do índice de produção.
**Por quê evitar:** ES infere tipos de campos novos — um campo `status: "1"` vira keyword, mas `status: 1` vira long; mapping explosion destrói performance e pode causar OutOfMemoryError.
**Solução:**
```json
PUT /products/_mapping
{
  "dynamic": "strict",
  "properties": {
    "name":  { "type": "text", "analyzer": "portuguese" },
    "price": { "type": "scaled_float", "scaling_factor": 100 }
  }
}
```

### ❌ Indexar documentos um a um em vez de bulk
**Problema:** Chamar `PUT /index/_doc/id` individualmente em um loop de importação.
**Por quê evitar:** Cada request tem overhead de rede + I/O de commit — uma importação de 100k docs pode levar horas; a Bulk API processa o mesmo em minutos.
**Solução:**
```typescript
const operations = docs.flatMap(doc => [
  { index: { _index: 'products', _id: doc.id } },
  doc,
]);
await client.bulk({ operations, refresh: false });
```

### ❌ Usar query context onde filter context é suficiente
**Problema:** Colocar filtros de negócio (status, category, date range) no `query` em vez de `filter`.
**Por quê evitar:** Query context calcula relevance score (custo CPU); filter context não calcula score e é cacheado — filtros em `query` são 10-50x mais lentos em índices grandes.
**Solução:**
```json
{
  "query": {
    "bool": {
      "must": [{ "match": { "name": "laptop" } }],  // score necessário
      "filter": [                                      // sem score, cacheado
        { "term": { "status": "available" } },
        { "range": { "price": { "lte": 5000 } } }
      ]
    }
  }
}
```

### ❌ Aggregations com size ilimitado ou muito grande
**Problema:** Usar `"size": 0` ou `"size": 100000` em `terms` aggregation.
**Por quê evitar:** ES carrega todos os buckets candidatos de cada shard na memória antes de mergear — com muitos valores únicos pode causar OOM no cluster.
**Solução:**
```json
// Limite explícito; use composite aggregation para paginação de facets
{ "aggs": { "categorias": { "terms": { "field": "category", "size": 50 } } } }

// Para paginação de aggregations: composite aggregation com after_key
{ "aggs": { "cat_page": { "composite": { "size": 100, "sources": [...], "after": { "category": "ultimo-bucket" } } } } }
```

### ❌ Buscar dados binários grandes no ES
**Problema:** Armazenar imagens, PDFs ou blobs grandes como campo `binary` em documentos ES.
**Por quê evitar:** ES não é object storage — blobs aumentam tamanho de segmentos, prejudicam performance de busca e não são comprimidos eficientemente.
**Solução:**
```
Armazene o arquivo em S3/Azure Blob/GCS.
No ES, indexe apenas metadados: { "filename": "...", "s3_url": "...", "content_type": "...", "text_content": "..." }
```

### ❌ Não configurar slow query log
**Problema:** Deixar o slow log do ES com thresholds padrão (desabilitado).
**Por quê evitar:** Queries lentas passam despercebidas — sem observabilidade não há como diagnosticar regressões de performance ao evoluir mappings ou queries.
**Solução:**
```json
PUT /products/_settings
{
  "index.search.slowlog.threshold.query.warn": "1s",
  "index.search.slowlog.threshold.query.info": "200ms",
  "index.search.slowlog.level": "info"
}
```
