# Solr Expert — Padrões de Código

## 1. Schema Design via Schema API

```bash
# Adicionar field types e fields via Schema API (SolrCloud)
curl -X POST http://localhost:8983/solr/products/schema \
  -H 'Content-Type: application/json' \
  -d '{
    "add-field-type": {
      "name": "text_pt",
      "class": "solr.TextField",
      "positionIncrementGap": "100",
      "indexAnalyzer": {
        "tokenizer": { "class": "solr.StandardTokenizerFactory" },
        "filters": [
          { "class": "solr.LowerCaseFilterFactory" },
          { "class": "solr.StopFilterFactory", "words": "lang/stopwords_pt.txt", "ignoreCase": "true" },
          { "class": "solr.BrazilianStemFilterFactory" }
        ]
      },
      "queryAnalyzer": {
        "tokenizer": { "class": "solr.StandardTokenizerFactory" },
        "filters": [
          { "class": "solr.LowerCaseFilterFactory" },
          { "class": "solr.StopFilterFactory", "words": "lang/stopwords_pt.txt", "ignoreCase": "true" },
          { "class": "solr.BrazilianStemFilterFactory" },
          { "class": "solr.SynonymGraphFilterFactory", "synonyms": "synonyms.txt", "expand": "true" }
        ]
      }
    }
  }'

# Adicionar campos
curl -X POST http://localhost:8983/solr/products/schema \
  -H 'Content-Type: application/json' \
  -d '{
    "add-field": [
      { "name": "name", "type": "text_pt", "stored": true, "indexed": true },
      { "name": "name_exact", "type": "string", "stored": false, "indexed": true },
      { "name": "description", "type": "text_pt", "stored": true, "indexed": true },
      { "name": "category", "type": "string", "stored": true, "indexed": true },
      { "name": "price", "type": "pdouble", "stored": true, "indexed": true },
      { "name": "tags", "type": "string", "stored": true, "indexed": true, "multiValued": true },
      { "name": "active", "type": "boolean", "stored": true, "indexed": true },
      { "name": "created_at", "type": "pdate", "stored": true, "indexed": true }
    ],
    "add-copy-field": [
      { "source": "name", "dest": "name_exact" },
      { "source": "name", "dest": "_text_" },
      { "source": "description", "dest": "_text_" }
    ]
  }'
```

---

## 2. SolrJ — Indexação e Busca (Java)

```java
// SolrConfig.java
@Configuration
public class SolrConfig {

    @Value("${solr.url:http://localhost:8983/solr}")
    private String solrUrl;

    @Bean
    public SolrClient solrClient() {
        return new Http2SolrClient.Builder(solrUrl)
            .withConnectionTimeout(10, TimeUnit.SECONDS)
            .withRequestTimeout(30, TimeUnit.SECONDS)
            .build();
    }
}

// ProductSolrDocument.java
public record ProductSolrDocument(
    @Field("id")          String id,
    @Field("name")        String name,
    @Field("description") String description,
    @Field("category")    String category,
    @Field("price")       Double price,
    @Field("tags")        List<String> tags,
    @Field("active")      Boolean active,
    @Field("created_at")  Date createdAt
) {}

// ProductSolrRepository.java
@Repository
public class ProductSolrRepository {

    private final SolrClient solrClient;
    private static final String COLLECTION = "products";

    public void index(ProductSolrDocument doc) throws SolrServerException, IOException {
        solrClient.addBean(COLLECTION, doc);
        solrClient.commit(COLLECTION);
    }

    public void bulkIndex(List<ProductSolrDocument> docs) throws SolrServerException, IOException {
        solrClient.addBeans(COLLECTION, docs);
        solrClient.commit(COLLECTION, false, true, true); // waitFlush=false, waitSearcher=true, softCommit=true
    }

    public SolrDocumentList search(String query, String category, int page, int rows)
            throws SolrServerException, IOException {
        SolrQuery solrQuery = new SolrQuery()
            .setQuery(query != null && !query.isBlank() ? query : "*:*")
            .setFilterQuery(
                "active:true",
                category != null ? "category:\"" + ClientUtils.escapeQueryChars(category) + "\"" : null
            )
            .setFields("id", "name", "category", "price", "score")
            .setStart((page - 1) * rows)
            .setRows(rows)
            .setSort("score", SolrQuery.ORDER.desc)
            .addSort("created_at", SolrQuery.ORDER.desc)
            .setHighlight(true)
            .setHighlightFragsize(150)
            .addHighlightField("name")
            .addHighlightField("description");

        // Facets
        solrQuery.setFacet(true)
                 .addFacetField("category", "tags")
                 .setFacetMinCount(1)
                 .setFacetLimit(20);

        QueryResponse response = solrClient.query(COLLECTION, solrQuery);
        return response.getResults();
    }
}
```

---

## 3. Query Patterns — Solr Query Syntax

```bash
# Full-text search com boost
q=name:laptop^3 OR description:laptop

# DisMax / eDisMax — melhor para buscas de usuário (sem syntax errors)
q=laptop wireless
defType=edismax
qf=name^3 description^1
pf=name^5   # phrase boost (palavras próximas = score maior)
mm=75%      # mínimo 75% dos termos devem aparecer

# Filtros (não afetam score, são cacheados)
fq=active:true
fq=category:"Eletrônicos"
fq=price:[50 TO 500]
fq=created_at:[NOW-30DAYS TO NOW]
fq=tags:(wireless OR bluetooth)

# Ordenação
sort=score desc, created_at desc

# Paginação
start=0&rows=20

# Highlighting
hl=true&hl.fl=name,description&hl.fragmenter=gap&hl.fragsize=150

# Facets
facet=true&facet.field=category&facet.field=tags&facet.mincount=1
facet.range=price&facet.range.start=0&facet.range.end=1000&facet.range.gap=100

# Spell check
spellcheck=true&spellcheck.q=laptpo&spellcheck.collate=true
```

---

## 4. pysolr — Cliente Python

```python
# src/search/product_search.py
import pysolr
from typing import Any

class ProductSearchRepository:
    def __init__(self, solr_url: str):
        self.solr = pysolr.Solr(
            f"{solr_url}/products",
            timeout=30,
            auth=None,  # BasicAuth: pysolr.Solr(url, auth=('user', 'pass'))
        )

    def index(self, product: dict[str, Any]) -> None:
        self.solr.add([product], commit=True)

    def bulk_index(self, products: list[dict[str, Any]]) -> None:
        self.solr.add(products, commit=False)
        self.solr.commit()

    def search(
        self,
        query: str = "*:*",
        category: str | None = None,
        min_price: float | None = None,
        max_price: float | None = None,
        page: int = 1,
        rows: int = 20,
    ) -> dict[str, Any]:
        fq = ["active:true"]
        if category:
            fq.append(f'category:"{pysolr.escape(category)}"')
        if min_price is not None or max_price is not None:
            lo = min_price if min_price is not None else "*"
            hi = max_price if max_price is not None else "*"
            fq.append(f"price:[{lo} TO {hi}]")

        results = self.solr.search(
            query,
            defType="edismax",
            qf="name^3 description",
            fq=fq,
            start=(page - 1) * rows,
            rows=rows,
            sort="score desc, created_at desc",
            hl="true",
            **{"hl.fl": "name,description", "hl.fragsize": "150"},
        )

        return {
            "items": list(results),
            "total": results.hits,
            "highlighting": results.highlighting,
        }

    def delete(self, doc_id: str) -> None:
        self.solr.delete(id=doc_id, commit=True)
```

---

## 5. Diagnóstico e Operação

```bash
# Status do cluster SolrCloud
curl http://localhost:8983/solr/admin/collections?action=CLUSTERSTATUS&wt=json

# Ver configsets disponíveis
curl http://localhost:8983/solr/admin/configs?action=LIST&wt=json

# Reload collection após mudança de config
curl "http://localhost:8983/solr/admin/collections?action=RELOAD&name=products&wt=json"

# Optimize (forcemerge) — apenas em manutenção, não em produção contínua
curl "http://localhost:8983/solr/products/update?optimize=true&waitFlush=false"

# Análise de token (debug de analyzer)
curl "http://localhost:8983/solr/products/analysis/field?analysis.fieldname=name&analysis.fieldvalue=laptop+sem+fio&wt=json"

# Query debug — ver como query foi parsada e scores
curl "http://localhost:8983/solr/products/select?q=laptop&debugQuery=true&wt=json"

# Stats de cache
curl "http://localhost:8983/solr/products/admin/mbeans?cat=CACHE&wt=json"
```

---

## Anti-patterns

### ❌ Editar schema.xml diretamente em vez de usar Schema API
**Problema:** Modificar `managed-schema` ou `schema.xml` manualmente via SSH ou editor de texto.
**Por quê evitar:** Em SolrCloud, mudanças manuais no arquivo XML não propagam para outros nós via ZooKeeper — nós ficam com schemas divergentes causando comportamento imprevisível.
**Solução:**
```bash
# Use Schema API para toda mudança de campo
curl -X POST "http://localhost:8983/solr/products/schema" \
  -H "Content-Type: application/json" \
  -d '{"add-field": {"name": "marca", "type": "string", "stored": true, "indexed": true}}'
# ZooKeeper propaga automaticamente para todos os nós
```

### ❌ Paginação deep com rows=10000
**Problema:** Usar `rows=10000&start=50000` para paginar resultados em coleções grandes.
**Por quê evitar:** Solr busca e descarta os N primeiros documentos em cada shard — em SolrCloud o custo multiplica pelo número de shards; para grandes volumes usa-se cursorMark.
**Solução:**
```bash
# Primeira página
curl "...?q=*:*&sort=id+asc&rows=100&cursorMark=*"
# Próximas páginas: usar nextCursorMark retornado pela resposta anterior
curl "...?q=*:*&sort=id+asc&rows=100&cursorMark=<VALOR_RETORNADO>"
```

### ❌ autoSoftCommit ausente ou com intervalo muito longo
**Problema:** Não configurar `autoSoftCommit` no `solrconfig.xml` — ou definir intervalo de 60 segundos.
**Por quê evitar:** Sem soft commit, documentos indexados não ficam visíveis para busca; com intervalo muito longo, há latência inaceitável entre indexação e visibilidade em tempo real.
**Solução:**
```xml
<!-- solrconfig.xml — recomendado: 1 segundo -->
<autoSoftCommit>
  <maxTime>1000</maxTime>
</autoSoftCommit>
<autoCommit>
  <maxTime>15000</maxTime>  <!-- hard commit a cada 15s para durabilidade -->
  <openSearcher>false</openSearcher>
</autoCommit>
```

### ❌ Usar campo string para busca textual
**Problema:** Definir campos de texto como `type="string"` e usá-los em buscas full-text.
**Por quê evitar:** Tipo `string` armazena o valor como token único sem tokenização/stemming — busca por "notebooks" não encontra documentos com "notebook"; `text_general` ou `text_pt` fazem análise correta.
**Solução:**
```bash
# Correto: tipo text com analyzer de Portuguese
curl -X POST ".../schema" -d '{
  "add-field": {"name": "descricao", "type": "text_pt", "stored": true, "indexed": true}
}'
```

### ❌ fq ausente em facets — usar q para filtrar
**Problema:** Colocar filtros de facet (categoria, faixa de preço) no parâmetro `q` em vez de `fq`.
**Por quê evitar:** Filtros em `q` participam do cálculo de score (desnecessário para filtros) e não são cacheados pelo `filterCache` — performance 5-20x inferior ao `fq`.
**Solução:**
```bash
# Correto: filtros em fq (cacheados no filterCache)
curl "...?q=laptop&fq=categoria:notebooks&fq=preco:[0+TO+5000]&facet=true&facet.field=marca"
```

### ❌ fl=* retornando todos os campos
**Problema:** Não especificar `fl` (field list), retornando todos os campos armazenados.
**Por quê evitar:** Campos grandes (descrição completa, HTML, dados binários) são transferidos desnecessariamente da rede — aumenta latência e banda.
**Solução:**
```bash
# Retorne apenas os campos necessários para a listagem
curl "...?q=laptop&fl=id,nome,preco,imagem_url,score"
```

### ❌ Não usar facet.mincount=1
**Problema:** Omitir `facet.mincount=1` em queries com facets.
**Por quê evitar:** Solr retorna por padrão todos os valores do campo (incluindo os com 0 documentos) — resposta volumosa, lenta e com ruído no frontend.
**Solução:**
```bash
curl "...?q=laptop&facet=true&facet.field=categoria&facet.mincount=1&facet.limit=20"
```
