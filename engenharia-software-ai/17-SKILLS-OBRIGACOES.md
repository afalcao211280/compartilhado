# 17. Skills para Desenvolvimento Assistido por AI

## 17.1 Habilidades Obrigatórias do Sistema

### Skill: Golang Backend

```yaml
name: golang-backend-dev
description: |
  Use QUANDO desenvolver microsserviços em Go, handlers, repositories,
  middleware, ou qualquer código backend Go. Ativado por:
  - "implementar serviço Go"
  - "criar handler"
  - "repositório"
  - "gRPC"
  - "BFF"

rules:
  - Use packages padrão: net/http, gin, grpc, errors
  - Estrutura: cmd/, internal/, pkg/, migrations/, proto/
  - Context: primeiro parâmetro, nunca armazenar em struct
  - Errors: retornar com tipo customizado, nunca ignorar com _
  - Tests: *_test.go, naming: Test<Function>_<Scenario>
  - Coverage: >= 80%

examples:
  service: |
    type ProductService struct {
        repo ProductRepository
    }
    
    func (s *ProductService) GetByID(ctx context.Context, id uuid.UUID) (*Product, error) {
        product, err := s.repo.FindByID(ctx, id)
        if err != nil {
            if errors.Is(err, repository.ErrNotFound) {
                return nil, &Error{Code: "NOT_FOUND", Message: "Product not found"}
            }
            return nil, fmt.Errorf("get product: %w", err)
        }
        return product, nil
    }

  handler: |
    func (h *ProductHandler) GetProduct(c *gin.Context) {
        id := c.Param("id")
        uid, err := uuid.Parse(id)
        if err != nil {
            c.JSON(400, ErrorResponse{Error: "invalid id"})
            return
        }
        
        product, err := h.service.GetByID(c.Request.Context(), uid)
        if err != nil {
            handleError(c, err)
            return
        }
        
        c.JSON(200, ProductResponse{...})
    }
```

### Skill: React/Next.js Frontend

```yaml
name: react-frontend-dev
description: |
  Use QUANDO desenvolver componentes React, páginas Next.js, micro frontends,
  ou código frontend. Ativado por:
  - "componente React"
  - "página Next.js"
  - "micro frontend"
  - "Module Federation"

rules:
  - Next.js 14+ App Router, Server Components por padrão
  - 'use client' apenas quando necessário
  - Tipos: Interface para objetos, Type para unions
  - Estado: React Query (server), Zustand (client)
  - Imports: absolute paths via @/

examples:
  server_component: |
    // app/products/[id]/page.tsx (Server Component)
    export default async function ProductPage({ params }: { params: { id: string } }) {
      const product = await getProduct(params.id)
      
      return (
        <main>
          <h1>{product.name}</h1>
          <p>R$ {product.price}</p>
          <AddToCart productId={product.id} />
        </main>
      )
    }

  client_component: |
    'use client'
    
    export function AddToCart({ productId }: { productId: string }) {
      const [loading, setLoading] = useState(false)
      const { mutate } = useCart()
      
      const handleAdd = async () => {
        setLoading(true)
        await mutate({ productId, quantity: 1 })
        setLoading(false)
      }
      
      return (
        <button onClick={handleAdd} disabled={loading}>
          {loading ? 'Adicionando...' : 'Adicionar ao Carrinho'}
        </button>
      )
    }

  module_federation: |
    // Host config
    new NextFederationPlugin({
      name: 'host',
      remotes: {
        catalogMf: 'catalogMf@http://localhost:3002/remoteEntry.js',
      },
      shared: { react: { singleton: true, eager: true } }
    })
    
    // Remote (catalog MF)
    new NextFederationPlugin({
      name: 'catalogMf',
      filename: 'remoteEntry.js',
      exposes: { './Catalog': './components/Catalog.tsx' }
    })
```

### Skill: Python AI Development

```yaml
name: python-ai-dev
description: |
  Use QUANDO desenvolver AI agents, guardrails, RAG, ou código Python para AI.
  Ativado por:
  - "agent CrewAI"
  - "orchestrador LangGraph"
  - "guardrails"
  - "RAG"
  - "embeddings"

rules:
  - Python 3.11+
  - Type hints obrigatórios
  - Async/await preferível
  - Pydantic para validação
  - Testar com pytest
  - Logging estruturado

examples:
  crewai_agent: |
    from crewai import Agent, Task, Crew, Process
    
    class EcommerceOrchestrator:
        def __init__(self):
            self.orchestrator = Agent(
                role="Orquestrador",
                goal="Identificar intent e rotear para agente correto",
                backstory="Especialista em atendimento...",
                llm=llm,
                tools=[classify_intent, get_context]
            )
        
        def process(self, message: str, context: dict) -> str:
            result = self.orchestrator.kickoff(inputs={
                "message": message,
                "context": context
            })
            return result

  guardrail_input: |
    from dataclasses import dataclass
    from typing import Optional
    
    @dataclass
    class ValidationResult:
        safe: bool
        sanitized: str
        blocked_reason: Optional[str] = None
    
    def validate_input(message: str) -> ValidationResult:
        if detect_injection(message):
            return ValidationResult(safe=False, sanitized="", blocked_reason="injection")
        if detect_pii(message):
            message = mask_pii(message)
        return ValidationResult(safe=True, sanitized=message)

  rag_pipeline: |
    from langchain_community.vectorstores import pgvector
    from langchain_openai import OpenAIEmbeddings
    
    def retrieve_context(query: str, k: int = 5) -> list[str]:
        vectorstore = pgvector.PGVector.from_existing_collection(
            embedding=OpenAIEmbeddings(),
            collection_name="products"
        )
        docs = vectorstore.similarity_search(query, k=k)
        return [doc.page_content for doc in docs]
```

### Skill: Kubernetes & DevOps

```yaml
name: kubernetes-devops
description: |
  Use QUANDO criar manifests K8s, Helm charts, ou configurações de infra.
  Ativado por:
  - "Kubernetes"
  - "Helm"
  - "deployment"
  - "HPA"
  - "KEDA"

rules:
  - Usar namespaces para separação
  - Resource limits obrigatórios
  - Liveness/Readiness probes
  - ServiceAccount dedicado por service
  - Secrets via Vault ou Sealed Secrets
  - Network policies entre namespaces

examples:
  deployment: |
    apiVersion: apps/v1
    kind: Deployment
    spec:
      replicas: 3
      template:
        spec:
          containers:
            - name: app
              image: IMAGE:TAG
              resources:
                requests: { memory: "256Mi", cpu: "100m" }
                limits: { memory: "512Mi", cpu: "500m" }
              livenessProbe:
                httpGet: { path: /healthz, port: 8080 }
              readinessProbe:
                httpGet: { path: /readyz, port: 8080 }

  hpa: |
    apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    spec:
      minReplicas: 3
      maxReplicas: 50
      metrics:
        - type: Resource
          resource:
            name: cpu
            target:
              type: Utilization
              averageUtilization: 70
```

### Skill: Security Review

```yaml
name: security-review
description: |
  Use QUANDO revisar código por vulnerabilidades ou implementar segurança.
  Ativado por:
  - "segurança"
  - "vulnerabilidade"
  - "XSS"
  - "SQL injection"
  - "autenticação"
  - "autorização"

rules:
  - Nunca expor secrets no código
  - Usar parameterized queries
  - Sanitizar INPUT do usuário
  - Hash passwords com Argon2/bcrypt
  - Validar JWT em todas requests
  - Implementar rate limiting
  - Headers de segurança (CSP, HSTS)

checklist:
  input_validation: ["sanitize all input", "parameterized queries", "length limits"]
  authentication: ["JWT validation", "session management", "MFA"]
  authorization: ["RBAC", "ownership checks", "least privilege"]
  data_protection: ["encryption at rest", "encryption in transit", "PII handling"]
  infrastructure: ["WAF", "network policies", "secrets management"]
```

## 17.2 Prompts Otimizados

```markdown
# DO: Prompts específicos com contexto
---
"Implemente o padrão Repository para Order em Go seguindo a estrutura em
internal/domain/repository/interfaces.go. Use context.Context, UUID, e
error handling customizado com tipo Error{Code, Message}."

# DON'T: Prompts vagos
---
"Fazer repositório" ou "criar agent"

# DO: Para AI agents
---
"Crie um CrewAI agent para produtos com:
- Role: Especialista em Produtos
- Goal: Auxiliar com informações de produtos
- Tools: search_products (via Elasticsearch), get_details (via API)
- Few-shot: incluir 2 exemplos de conversas
- RAG: integrar com banco vetorial para contexto
- Output: resposta em português, max 500 tokens"

# DON'T: Sem detalhes
---
"Fazer agent de produtos"

# DO: Para Kubernetes
---
"Crie um Deployment para product-service em production namespace:
- Replicas: 3, com HPA até 50
- Resources: 256Mi-512Mi memory, 100m-500m CPU
- Probes: /healthz e /readyz
- Affinity: anti-affinity para dispersão
- SecurityContext: non-root, read-only filesystem"
```

## 17.3 Code Review Assistido

```markdown
# Template para AI Code Review

## Prompt
"Revise o seguinte código seguindo os padrões do projeto:

VERIFICAR:
1. Segurança (SQL injection, XSS, secrets)
2. Performance (N+1, memory leaks)
3. Padrões (aderência aos templates)
4. Testes (cobertura, edge cases)
5. Documentação (comentários necessários)

CÓDIGO:
```[code here]
```

EXPECTATIVA DE OUTPUT:
- Lista de issues categorizados (critical/high/medium/low)
- Sugestões de correção
- Approve/Request Changes"
```