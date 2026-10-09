# 18. Regras de Desenvolvimento

## 18.1 Regras Gerais

```markdown
# Git Workflow

## Branch Naming
feature/<ticket>-<description>
bugfix/<ticket>-<description>
hotfix/<ticket>-<description>
release/<version>

## Commit Messages
<type>(<scope>): <description>

Types:
- feat: Nova funcionalidade
- fix: Correção de bug
- docs: Documentação
- style: Formatação
- refactor: Refatoração
- test: Testes
- chore: Tarefas diversas

Examples:
- feat(auth): add password reset flow
- fix(cart): resolve quantity update bug
- docs(api): update payment endpoints

## Pull Request
- Title: feat(<scope>): <description>
- Description: Template com test plan
- Reviews: Mínimo 1 approved
- CI: Todos checks passando
- Merge: Squash/rebase
```

## 18.2 Regras Golang

```markdown
# Golang Style Guide

## Package Structure
```
cmd/server/main.go
internal/
  domain/
    entity/       # Domain models
    repository/   # Repository interfaces
    service/     # Business logic
  handler/       # HTTP/gRPC handlers
  middleware/    # Auth, logging, etc
  config/        # Configuration
  pkg/
    errors/      # Error types
    jwt/         # JWT utilities
migrations/
proto/
api/
  openapi.yaml
```

## Imports (grupo por linha em branco)
1. stdlib
2. external (gin, grpc, uuid, etc)
3. internal packages

## Error Handling
```go
// ERRADO
func Get() {
    data, _ := repo.Find() // ignorando erro
}

// CERTO
func Get() (*Data, error) {
    data, err := repo.Find(ctx, id)
    if err != nil {
        if errors.Is(err, repo.ErrNotFound) {
            return nil, &Error{Code: "NOT_FOUND", Message: "Resource not found"}
        }
        return nil, fmt.Errorf("finding data: %w", err)
    }
    return data, nil
}
```

## Context Usage
- Context sempre como primeiro parâmetro
- Nunca store context em structs
- Propagar context em todas as camadas
- Usar context.WithTimeout para operações longas

## Naming Conventions
- Variáveis: camelCase
- Constantes: PascalCase ou SCREAMING_SNAKE_CASE
- Funções exportadas: PascalCase
- Funções não exportadas: camelCase
- Interfaces: PascalCase, sufixo com "er" (Repository, Handler)
- Errors: struct com campos Code, Message

## Testing
```go
func TestProductService_GetByID(t *testing.T) {
    tests := []struct {
        name    string
        id      string
        wantErr bool
        errCode string
    }{
        {
            name:    "success",
            id:      validUUID,
            wantErr: false,
        },
        {
            name:    "not found",
            id:      invalidUUID,
            wantErr: true,
            errCode: "NOT_FOUND",
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result, err := service.GetByID(ctx, tt.id)
            if tt.wantErr {
                assert.Error(t, err)
                assert.Equal(t, tt.errCode, err.(*Error).Code)
                return
            }
            assert.NoError(t, err)
        })
    }
}
```
```

## 18.3 Regras React/TypeScript

```markdown
# React/TypeScript Style Guide

## File Structure
```
app/                    # Next.js App Router
  (auth)/
    login/
      page.tsx
      components/
  (shop)/
    products/
      page.tsx
      [id]/
        page.tsx
  layout.tsx
  globals.css
components/
  ui/              # Design system
  features/        # Feature-specific
lib/
  api/
  utils/
types/
```

## Component Rules
- Server Components por padrão
- 'use client' apenas se necessário:
  - useState/useEffect
  - event handlers
  - browser APIs
  - useContext (se não puder usar Server Component)

## Type Definitions
```typescript
// Interfaces para objetos
interface Product {
  id: string;
  name: string;
  price: number;
  category: Category;
}

// Types para unions/primitivos
type UserRole = 'admin' | 'customer' | 'agent';
type Status = 'pending' | 'processing' | 'completed';

// Evitar any
// Se necessário, usar unknown e validar
```

## State Management
- Server State: React Query (TanStack Query)
- Client State: Zustand
- Form State: React Hook Form + Zod
- URL State: nuqs

## Naming
- Componentes: PascalCase
- Arquivos: kebab-case ou PascalCase para components
- Hooks: camelCase com prefixo use
- Utils: camelCase
```

## 18.4 Regras Python

```markdown
# Python Style Guide

## Import Order
```python
# 1. Stdlib
from typing import Optional
from dataclasses import dataclass

# 2. Third-party
from crewai import Agent, Task
from langchain_openai import ChatOpenAI
from pydantic import BaseModel

# 3. Local
from .models import Product
from .database import db
```

## Type Hints
```python
# Sempre usar type hints
def process_order(order_id: str, user_id: str) -> Order:
    ...

# Usar typing para collections
from typing import List, Dict, Optional

def get_products(category: str) -> List[Product]:
    ...

# Pydantic para models
class ProductInput(BaseModel):
    name: str
    price: float
    category: Optional[str] = None
```

## Async
```python
# Preferir async/await
async def process_message(message: str) -> str:
    result = await llm.invoke(message)
    return result

# Usar asyncio.gather para paralelismo
import asyncio

async def fetch_all():
    results = await asyncio.gather(
        get_products(),
        get_categories(),
        get_user_preferences()
    )
    return results
```

## Error Handling
```python
try:
    result = await process_order(order_id)
except OrderNotFoundError:
    raise ValidationError("Order not found")
except PaymentDeclinedError:
    raise ValidationError("Payment declined")
except Exception as e:
    logger.error(f"Unexpected error: {e}")
    raise
```

## Logging
```python
import logging

logger = logging.getLogger(__name__)

# Usar structured logging
logger.info("Processing order", extra={
    "order_id": order_id,
    "user_id": user_id,
    "amount": amount
})
```
```

## 18.5 Regras de Segurança

```markdown
# Security Checklist

## NEVER DO
- ❌ Commitar secrets, API keys, passwords
- ❌ Armazenar tokens em texto plain
- ❌ Ignorar validação de input
- ❌ Usar SQL dinámico (use parameterized queries)
- ❌ Usar eval() ou exec()
- ❌ Confiar em client-side validation
- ❌ Expor stack traces em produção

## ALWAYS DO
- ✅ Sanitizar toda input do usuário
- ✅ Usar parameterized queries
- ✅ Hash passwords com Argon2 ou bcrypt
- ✅ Validar JWT em cada request
- ✅ Implementar rate limiting
- ✅ Usar HTTPS em produção
- ✅ Headers de segurança (CSP, HSTS, X-Frame-Options)
- ✅ Logs sem dados sensíveis

## OWASP Top 10 Checklist
- [ ] A01: Broken Access Control - Verificar autorização em cada endpoint
- [ ] A02: Cryptographic Failures - Usar criptografia forte
- [ ] A03: Injection - Parameterized queries, sanitização
- [ ] A04: Insecure Design - Threat modeling
- [ ] A05: Security Misconfiguration - Hardening
- [ ] A06: Vulnerable Components - Dependabot/Snyk
- [ ] A07: Auth Failures - MFA, session management
- [ ] A08: Data Integrity - Validação server-side
- [ ] A09: Logging Failures - Audit trail
- [ ] A10: SSRF - Validate URLs, block internal access
```

## 18.6 Regras de Performance

```markdown
# Performance Checklist

## Database
- [ ] Índices para queries frequentes
- [ ] Connection pooling
- [ ] Evitar N+1 queries
- [ ] Paginação para listas grandes
- [ ] Query analysis (EXPLAIN ANALYZE)

## API
- [ ] Response caching (Redis, CDN)
- [ ] Compression (gzip, brotli)
- [ ] Pagination para listas
- [ ] Field filtering (select only needed)
- [ ] Rate limiting por cliente

## Frontend
- [ ] Code splitting
- [ ] Lazy loading
- [ ] Image optimization
- [ ] Bundle size analysis
- [ ] Critical CSS

## AI
- [ ] Response caching
- [ ] Streaming para UX
- [ ] Token optimization
- [ ] Batch processing para múltiplas queries
```

## 18.7 Regras de Documentação

```markdown
# Documentation Standards

## Code Comments
- Docstrings para funções públicas
- Explain WHY, not WHAT
- Keep comments updated

## API Documentation
- OpenAPI 3.0
- Request/response examples
- Error codes
- Authentication requirements

## README.md Structure
1. Description
2. Quick Start
3. Architecture
4. Development
5. Testing
6. Deployment
7. API Reference
8. Contributing
```