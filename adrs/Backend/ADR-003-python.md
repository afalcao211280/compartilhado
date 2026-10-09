# ADR-003: Python/FastAPI — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: A EVEO utiliza Python para microsserviços de API, workers assíncronos e automações internas. Era necessário formalizar a stack canônica, versões mínimas, padrões arquiteturais e anti-padrões para garantir consistência entre times e alinhar com a infraestrutura EVEO (PostgreSQL, Redis, MongoDB, Elasticsearch, RabbitMQ, Kafka, MinIO). A versão de referência é a padronização Python EVEO 2026, executável via skill.

## Decisão

Adotar Python 3.12+ com FastAPI como framework padrão para APIs e microsserviços. Clean Architecture (handler → service → repository → model), SQLAlchemy 2.0 + Alembic para SQL, Pydantic v2 para schemas. Django é alternativa para projetos full-stack com admin e templates — a escolha entre FastAPI e Django **deve ser perguntada ao usuário** quando houver dúvida.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| Linguagem | Python | 3.12+ | — | Type hints melhorados, performance, asyncio maduro |
| Web framework | FastAPI | 0.115+ | Django (ver decisão abaixo) | Async nativo, OpenAPI automático, type hints |
| ORM (FastAPI) | SQLAlchemy 2.0 | 2.0+ | Django ORM, Tortoise | Async, maduro, migrations via Alembic |
| Migrations | Alembic | 1.13+ | Django migrations | Manual, auditável, integrado com SQLAlchemy |
| Validation | Pydantic v2 | 2.x | marshmallow | FastAPI nativo, typesafe, performance |
| Settings | pydantic-settings | 2.x | python-decouple | Validação de env, tipos, `.env` |
| Logging | loguru | 0.7+ | stdlib logging | Structured, zero-config, rotation |
| HTTP client | httpx | 0.27+ | requests | Async, HTTP/2, type hints |
| Circuit breaker | pybreaker | 1.x | circuitbreaker | Simples, integra com httpx |
| NoSQL (MongoDB) | Motor | 3.4+ | pymongo (sync) | Async driver oficial para MongoDB |
| NoSQL (Elasticsearch) | elasticsearch-py | 8.12+ | — | Client oficial ES v8, async support |
| Cache | redis-py | 5.0+ | aioredis (merged) | Cache, locks distribuídos, rate limiting |
| Fila clássica | aio-pika | 9.4+ | pika (sync) | Async RabbitMQ, pub/sub, work queues |
| Streaming | aiokafka | 0.11+ | confluent-kafka (sync) | Async Kafka consumer/producer |
| Object storage | fsspec + s3fs | 2024+ | boto3 (sync), minio-py | S3-compatible async |
| PDF | weasyprint | 60.0+ | reportlab, pdfkit | HTML→PDF, CSS support |
| Tracing | OpenTelemetry | 1.27+ | — | Vendor-agnostic, exporter OTLP |
| Métricas | prometheus-client | 0.20+ | — | Endpoint `/metrics`, histogramas |
| Error tracking | Sentry | 2.0+ | — | Exception tracking, performance |
| Package manager | uv | latest | pip, poetry | 10-100x mais rápido que pip |
| Linting | ruff | 0.9+ | flake8, pylint | Linter + formatter em Rust, ultra-rápido |
| Type checking | mypy | 1.14+ | pyright | Strict mode, CI integrado |
| Testes unit | pytest | 8.0+ | unittest | Plugins, fixtures, async |
| Testes async | pytest-asyncio | 0.23+ | — | Suporte a coroutines no pytest |
| Testes integração | testcontainers | latest | Docker Compose manual | Postgres, Redis reais em container |
| Load test | Locust | latest | k6 (para Python) | Scripts Python, distribuído |
| SAST | bandit | latest | — | Security linter no CI |

## Decisão Arquitetural: FastAPI vs Django

**Perguntar ao usuário se não ficou claro. Não escolher sozinho.**

### Use FastAPI quando:
- API pura (REST/JSON), sem admin, sem templates
- Async nativo é requisito (I/O pesado, WebSockets, SSE)
- Microsserviço isolado
- Quer documentação OpenAPI automática
- Time prefere type hints e validação Pydantic

### Use Django quando:
- Projeto full-stack: templates, admin, auth, forms
- Time prefere convention over configuration
- Precisa do Django Admin ou ORM maduro com migrations automáticas
- Monolito estruturado com apps bem definidos

> **Nunca misture FastAPI e Django no mesmo projeto.** Escolha UM.

## Padrões Obrigatórios

### Clean Architecture
- `handler` (route) → `service` → `repository` → `model`
- **handler**: FastAPI router, HTTP concerns, `Depends()` para injeção
- **service**: lógica de negócio, orquestra repositories
- **repository**: acesso a dados (SQL, NoSQL, cache, storage)
- **model**: entidades de domínio + schemas Pydantic/SQLAlchemy

### Naming
- `snake_case` para variáveis, funções, módulos, pacotes
- `PascalCase` para classes, tipos Pydantic, modelos ORM
- `UPPER_SNAKE` para constantes
- Arquivos: `user_service.py`, `user_repository.py`
- Schemas: `{Entity}Create`, `{Entity}Update`, `{Entity}Response`, `{Entity}ListResponse`

### Dependency Injection (FastAPI)
```python
# app/core/deps.py
async def get_user_repository(db: AsyncSession = Depends(get_db)) -> UserRepository:
    return UserRepository(db)

async def get_user_service(repo: UserRepository = Depends(get_user_repository)) -> UserService:
    return UserService(repo)
```
- Funções `get_*` em `core/deps.py`
- Nunca instanciar dependências diretamente no handler

### Schemas (Pydantic v2)
- `model_config = ConfigDict(strict=True)` para schemas de entrada
- `Field(validators)` para validação de campos
- Separar: `UserCreate`, `UserUpdate`, `UserResponse`
- Nunca expor modelo ORM diretamente — sempre schema de response

### Repository Pattern
- Interface implícita (Protocol) ou ABC se o time prefere explícito
- Repository nunca levanta HTTP exceptions — retorna `None` ou levanta domain exception
- Service decide o que fazer com `None`

### Error Handling
- Domain exceptions: `NotFoundException`, `BusinessException`, `ValidationException`
- Handler converte domain exception → HTTP response via exception handlers
- Erros wrapped com contexto: `raise ServiceError("criar usuário") from e`
- Nunca `except Exception: pass`

### Logging
- `loguru` com structured logging
- JSON em produção, text em desenvolvimento
- Nunca `print()` ou `logging` stdlib

### Async
- FastAPI com `async def` handlers
- SQLAlchemy async session (`AsyncSession`)
- httpx async, Motor async, redis-py async
- I/O-bound sempre async; CPU-bound → `run_in_executor`

### Security (Built-in)
- Input validation via Pydantic `strict=True` + `Field(validators)`
- JWT/OAuth2 via `fastapi-users` ou custom
- CORS configurado explicitamente — nunca `*` em prod
- Rate limiting via `slowapi`
- Secrets via `pydantic-settings` de env vars
- `bandit` no CI para SAST

## Estrutura de Projeto

```
project/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI app ou Django WSGI/ASGI
│   ├── core/                 # config, deps, security
│   │   ├── config.py         # Settings via pydantic-settings
│   │   ├── deps.py           # FastAPI Depends (get_db, get_service)
│   │   ├── security.py       # JWT, OAuth2, password hash
│   │   └── database.py       # AsyncSession, engine
│   ├── api/                  # routers
│   │   ├── __init__.py
│   │   ├── v1/
│   │   │   ├── __init__.py
│   │   │   └── user_router.py
│   │   └── deps.py           # dependencies compartilhadas
│   ├── services/             # lógica de negócio
│   │   ├── __init__.py
│   │   └── user_service.py
│   ├── repositories/         # acesso a dados
│   │   ├── __init__.py
│   │   └── user_repository.py
│   ├── models/               # SQLAlchemy models / ORM
│   │   ├── __init__.py
│   │   └── user.py
│   ├── schemas/              # Pydantic schemas
│   │   ├── __init__.py
│   │   └── user_schema.py    # UserCreate, UserUpdate, UserResponse
│   └── exceptions/           # domain exceptions + handlers
│       ├── __init__.py
│       └── handlers.py
├── migrations/                # Alembic
│   ├── env.py
│   └── versions/
│       └── 001_create_users.py
├── tests/
│   ├── unit/
│   ├── integration/
│   └── conftest.py
├── docker/
│   ├── Dockerfile             # multi-stage
│   └── docker-compose.yml
├── pyproject.toml             # uv/poetry config
├── alembic.ini
├── ruff.toml
├── Makefile
└── README.md
```

### Regras de Importação Invioláveis
- `api/` importa de `services/`, `schemas/`, `core/` — nunca de `repositories/` ou `models/`
- `services/` importa de `repositories/`, `models/`, `schemas/`
- `repositories/` importa de `models/` — nunca de `services/` ou `api/`
- `models/` é o núcleo — não importa de `api/`, `services/`, ou `repositories/`
- `schemas/` são Pydantic puro — zero dependência de ORM

## Anti-padrões

- **Variáveis globais** — usar injeção de dependência via `Depends()`
- **Ignorar erros** (`result = await do_something()` sem try/except) — sempre tratar com contexto
- **Type `Any`** — usar type hints específicos sempre
- **Expor modelo ORM no response** — sempre schema Pydantic
- **`print()` ou `logging` stdlib** — usar `loguru` structured
- **`except Exception: pass`** — sempre logar e/ou rethrow
- **Lógica de negócio no handler** — delegar para service
- **Repository levantando HTTP exception** — retornar `None` ou domain exception
- **Síncrono em handler async** — I/O-bound sempre `async def`; CPU-bound → `run_in_executor`
- **Imports cíclicos** — api → services → repositories → models, sempre unidirecional
- **Secrets hardcoded** — usar `pydantic-settings` de env vars
- **ORM divergence** — nunca usar `orm_mode` com `strict=True` incompatível

## Consequências

### Positivas
- FastAPI + Pydantic v2 oferece type safety end-to-end com OpenAPI automático
- Async nativo para I/O pesado (PostgreSQL, Redis, MongoDB, HTTP outbound)
- SQLAlchemy 2.0 async + Alembic é maduro e bem documentado
- loguru simplifica structured logging sem configuração complexa
- httpx é o client HTTP moderno com suporte async
- ruff substitui flake8 + isort + black em uma ferramenta Rust ultra-rápida
- Testcontainers garante testes de integração com bancos reais

### Negativas
- Ecossistema Python async ainda tem edge cases (adaptação de libs sync)
- Alembic requer cuidado com migrations automáticas vs manuais
- FastAPI não tem admin UI como Django
- mypy strict pode gerar fricção em projetos com muitas lib sem type stubs
- Motor (MongoDB async) é mais lento que pymongo sync em operações triviais

## Referências

- Skill: `skills/Backend/python-expert/SKILL.md`
- Padronização EVEO: documentação interna Python
- FastAPI: https://fastapi.tiangolo.com/
- SQLAlchemy 2.0: https://docs.sqlalchemy.org/en/20/