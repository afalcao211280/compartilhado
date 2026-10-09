# Pydantic v2 — Schemas e Validacao

Leia `core.md` secao 6 para detalhes.

## Schemas

```python
from pydantic import BaseModel, EmailStr, Field, ConfigDict

class UserCreate(BaseModel):
    model_config = ConfigDict(strict=True)
    email: EmailStr
    name: str = Field(min_length=2, max_length=100)

class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    email: EmailStr
    name: str
```

## Regras
- Sempre separar input (Create/Update) de output (Response)
- strict=True em schemas de entrada
- Nunca expor modelo ORM direto
