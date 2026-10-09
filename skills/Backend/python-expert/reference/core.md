# Python Expert — Padrões de Código

Catálogo de snippets canônicos EVEO por camada. Leia a seção do que vai gerar **antes** de codar — são o ponto de partida pronto pra produção, não exemplos educativos.

## Índice

1. [FastAPI — Setup Completo](#1-fastapi--setup-completo)
2. [Settings (pydantic-settings)](#2-settings-pydantic-settings)
3. [SQLAlchemy 2.0 — Session Async](#3-sqlalchemy-20--session-async)
4. [Repository Pattern (SQLAlchemy)](#4-repository-pattern-sqlalchemy)
5. [Service Layer](#5-service-layer)
6. [Pydantic v2 — Schemas](#6-pydantic-v2--schemas)
7. [FastAPI Router + Dependencies](#7-fastapi-router--dependencies)
8. [Custom Exceptions + Handler](#8-custom-exceptions--handler)
9. [structlog Setup](#9-structlog-setup)
10. [pytest — Fixtures Canônicas](#10-pytest--fixtures-canônicas)
11. [httpx + tenacity (HTTP Client)](#11-httpx--tenacity-http-client)
12. [Celery Worker](#12-celery-worker)
13. [Dockerfile Multi-stage](#13-dockerfile-multi-stage)
14. [Anti-patterns](#anti-patterns)

## 1. FastAPI — Setup Completo

```python
# app/main.py
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import structlog

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.exceptions import AppError, app_error_handler
from app.core.logging import configure_logging
from app.core.tracing import configure_tracing
from app.database import create_engine_pool, close_engine_pool

log = structlog.get_logger()

@asynccontextmanager
async def lifespan(app: FastAPI):
    configure_logging()
    configure_tracing()
    await create_engine_pool()
    log.info("aplicação iniciada", env=settings.ENVIRONMENT)
    yield
    await close_engine_pool()
    log.info("aplicação encerrada")

app = FastAPI(
    title="EVEO Service",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/api/docs" if settings.ENVIRONMENT != "production" else None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,  # nunca ["*"] em prod
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_exception_handler(AppError, app_error_handler)
app.include_router(api_router, prefix="/api/v1")
```

---

## 2. Settings (pydantic-settings)

```python
# app/core/config.py
from pydantic import PostgresDsn, RedisDsn, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
    )

    ENVIRONMENT: str = "development"
    DATABASE_URL: PostgresDsn
    REDIS_URL: RedisDsn
    JWT_SECRET: SecretStr
    ALLOWED_ORIGINS: list[str] = ["http://localhost:3000"]
    LOG_LEVEL: str = "INFO"

settings = Settings()  # singleton — importar de qualquer lugar
```

---

## 3. SQLAlchemy 2.0 — Session Async

```python
# app/database.py
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

_engine = None
_session_factory = None

async def create_engine_pool() -> None:
    global _engine, _session_factory
    _engine = create_async_engine(
        str(settings.DATABASE_URL),
        pool_size=10,
        max_overflow=20,
        echo=settings.ENVIRONMENT == "development",
    )
    _session_factory = async_sessionmaker(
        _engine,
        expire_on_commit=False,
        class_=AsyncSession,
    )

async def close_engine_pool() -> None:
    if _engine:
        await _engine.dispose()

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with _session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

---

## 4. Repository Pattern (SQLAlchemy)

```python
# app/repositories/user_repository.py
from uuid import UUID
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User

class UserRepository:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_by_id(self, user_id: UUID) -> User | None:
        stmt = select(User).where(User.id == user_id)
        result = await self._db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> User | None:
        stmt = select(User).where(User.email == email)
        result = await self._db.execute(stmt)
        return result.scalar_one_or_none()

    async def create(self, user: User) -> User:
        self._db.add(user)
        await self._db.flush()  # flush, não commit — transação gerenciada pelo caller
        await self._db.refresh(user)
        return user

    async def list_paginated(
        self, offset: int = 0, limit: int = 20
    ) -> tuple[list[User], int]:
        count_stmt = select(func.count()).select_from(User)
        data_stmt = select(User).offset(offset).limit(limit)
        total = (await self._db.execute(count_stmt)).scalar_one()
        users = (await self._db.execute(data_stmt)).scalars().all()
        return list(users), total
```

---

## 5. Service Layer

```python
# app/services/user_service.py
from uuid import UUID
import structlog
from app.core.exceptions import NotFoundError, ConflictError
from app.repositories.user_repository import UserRepository
from app.schemas.user import UserCreate, UserResponse, UserListResponse
from app.models.user import User

log = structlog.get_logger()

class UserService:
    def __init__(self, repo: UserRepository) -> None:
        self._repo = repo

    async def create(self, data: UserCreate) -> UserResponse:
        log.info("criando usuário", email=data.email)
        existing = await self._repo.get_by_email(data.email)
        if existing:
            raise ConflictError("Usuário", data.email)
        user = User(email=data.email, name=data.name)
        user.set_password(data.password)
        created = await self._repo.create(user)
        log.info("usuário criado", user_id=str(created.id))
        return UserResponse.model_validate(created)

    async def get_by_id(self, user_id: UUID) -> UserResponse:
        user = await self._repo.get_by_id(user_id)
        if not user:
            raise NotFoundError("Usuário", str(user_id))
        return UserResponse.model_validate(user)
```

---

## 6. Pydantic v2 — Schemas

```python
# app/schemas/user.py
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, EmailStr, Field, ConfigDict

class UserCreate(BaseModel):
    model_config = ConfigDict(strict=True)

    email: EmailStr
    name: str = Field(min_length=2, max_length=100)
    password: str = Field(min_length=8, max_length=128)

class UserUpdate(BaseModel):
    name: str | None = Field(None, min_length=2, max_length=100)

class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)  # permite .model_validate(orm_obj)

    id: UUID
    email: EmailStr
    name: str
    created_at: datetime

class UserListResponse(BaseModel):
    items: list[UserResponse]
    total: int
    page: int
    size: int
```

---

## 7. FastAPI Router + Dependencies

```python
# app/api/v1/users.py
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.repositories.user_repository import UserRepository
from app.services.user_service import UserService
from app.schemas.user import UserCreate, UserResponse, UserListResponse

router = APIRouter(prefix="/users", tags=["Users"])

def get_user_service(db: AsyncSession = Depends(get_db)) -> UserService:
    return UserService(UserRepository(db))

@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(
    data: UserCreate,
    service: UserService = Depends(get_user_service),
) -> UserResponse:
    return await service.create(data)

@router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: UUID,
    service: UserService = Depends(get_user_service),
) -> UserResponse:
    return await service.get_by_id(user_id)
```

---

## 8. Custom Exceptions + Handler

```python
# app/core/exceptions.py
from fastapi import Request
from fastapi.responses import JSONResponse

class AppError(Exception):
    def __init__(self, message: str, status_code: int = 500) -> None:
        self.message = message
        self.status_code = status_code

class NotFoundError(AppError):
    def __init__(self, resource: str, identifier: str) -> None:
        super().__init__(f"{resource} '{identifier}' não encontrado", status_code=404)

class ConflictError(AppError):
    def __init__(self, resource: str, identifier: str) -> None:
        super().__init__(f"{resource} '{identifier}' já existe", status_code=409)

class ValidationError(AppError):
    def __init__(self, message: str) -> None:
        super().__init__(message, status_code=422)

async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.message, "type": type(exc).__name__},
    )
```

---

## 9. structlog Setup

```python
# app/core/logging.py
import logging
import structlog

def configure_logging() -> None:
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.add_log_level,
            structlog.stdlib.add_logger_name,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.JSONRenderer(),
        ],
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )
    logging.basicConfig(level=logging.INFO)
```

---

## 10. pytest — Fixtures Canônicas

```python
# tests/conftest.py
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from testcontainers.postgres import PostgresContainer

from app.main import app
from app.database import get_db
from app.models.base import Base

@pytest.fixture(scope="session")
def postgres_container():
    with PostgresContainer("postgres:16-alpine") as pg:
        yield pg

@pytest_asyncio.fixture(scope="session")
async def db_engine(postgres_container):
    engine = create_async_engine(postgres_container.get_connection_url(driver="asyncpg"))
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()

@pytest_asyncio.fixture
async def db_session(db_engine) -> AsyncGenerator[AsyncSession, None]:
    async with db_engine.begin() as conn:
        session = AsyncSession(bind=conn)
        yield session
        await session.rollback()

@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    app.dependency_overrides[get_db] = lambda: db_session
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()
```

---

## 11. httpx + tenacity (HTTP Client)

```python
# app/clients/external_api.py
from httpx import AsyncClient, HTTPStatusError
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
import structlog

log = structlog.get_logger()

class ExternalApiClient:
    def __init__(self, base_url: str, timeout: float = 10.0) -> None:
        self._client = AsyncClient(base_url=base_url, timeout=timeout)

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=10),
        retry=retry_if_exception_type((TimeoutError, ConnectionError)),
    )
    async def get_resource(self, resource_id: str) -> dict:
        log.info("buscando recurso externo", resource_id=resource_id)
        response = await self._client.get(f"/resources/{resource_id}")
        response.raise_for_status()
        return response.json()

    async def close(self) -> None:
        await self._client.aclose()
```

---

## 12. Celery Worker

```python
# app/worker/celery_app.py
from celery import Celery
from app.core.config import settings

celery_app = Celery(
    "eveo-worker",
    broker=str(settings.REDIS_URL),
    backend=str(settings.REDIS_URL),
)

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="America/Sao_Paulo",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
)

# app/worker/tasks/email.py
from app.worker.celery_app import celery_app
import structlog

log = structlog.get_logger()

@celery_app.task(bind=True, max_retries=3, default_retry_delay=60)
def send_welcome_email(self, user_id: str, email: str) -> None:
    try:
        log.info("enviando email de boas-vindas", user_id=user_id)
        # ... lógica de envio
    except Exception as exc:
        log.error("falha ao enviar email", error=str(exc), user_id=user_id)
        raise self.retry(exc=exc)
```

---

## 13. Dockerfile Multi-stage

```dockerfile
# docker/Dockerfile
FROM python:3.12 AS builder
WORKDIR /app
COPY pyproject.toml .
RUN pip install uv && uv pip install --system -r pyproject.toml

FROM python:3.12-slim AS runtime
WORKDIR /app
RUN addgroup --system app && adduser --system --group app
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --chown=app:app . .
USER app
EXPOSE 8000
CMD ["gunicorn", "app.main:app", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8000"]
```

---

## Anti-patterns

### ❌ I/O bloqueante dentro de `async def` (requests em vez de httpx)
**Problema:** O desenvolvedor usa a biblioteca `requests` (síncrona) dentro de uma função `async def` de um endpoint FastAPI.
**Por quê evitar:** A chamada bloqueia o event loop inteiro, cancelando o benefício do async e degradando a latência de todas as requisições concorrentes enquanto aguarda a resposta HTTP externa.
**Solução:**
```python
# Errado
@router.get("/external")
async def call_external():
    response = requests.get("https://api.externa.com/dados")  # bloqueia o event loop
    return response.json()

# Correto
import httpx

@router.get("/external")
async def call_external():
    async with httpx.AsyncClient() as client:
        response = await client.get("https://api.externa.com/dados")
        response.raise_for_status()
        return response.json()
```

### ❌ Acessar dicts brutos em vez de validar com Pydantic
**Problema:** O desenvolvedor recebe dados do request como `dict` bruto ou como `Request.json()` e acessa campos via `data["email"]` sem validação de schema.
**Por quê evitar:** Sem Pydantic não há coerção de tipos, validação de constraints nem mensagens de erro padronizadas; campos ausentes ou mal-formados causam `KeyError` ou comportamento incorreto silencioso em runtime.
**Solução:**
```python
# Errado
@router.post("/users")
async def create_user(request: Request):
    data = await request.json()
    email = data["email"]  # KeyError se ausente; sem validação de formato

# Correto
class UserCreate(BaseModel):
    email: EmailStr
    name: str = Field(min_length=2, max_length=100)

@router.post("/users", status_code=201)
async def create_user(data: UserCreate, service: UserService = Depends(get_user_service)):
    return await service.create(data)
```

### ❌ Lazy loading N+1 do SQLAlchemy em contexto async
**Problema:** O desenvolvedor acessa um relacionamento ORM (ex: `user.orders`) dentro de um loop após uma query de lista, sem ter feito eager loading.
**Por quê evitar:** SQLAlchemy async proíbe lazy loading implícito (lança `MissingGreenlet`); mesmo quando não lança erro, cada acesso dispara uma query extra, resultando em N+1 queries e degradação severa de performance.
**Solução:**
```python
# Errado
users = (await db.execute(select(User))).scalars().all()
for user in users:
    print(user.orders)  # MissingGreenlet em async; N+1 em sync

# Correto — eager loading com selectinload
from sqlalchemy.orm import selectinload

stmt = select(User).options(selectinload(User.orders))
users = (await db.execute(stmt)).scalars().all()
for user in users:
    print(user.orders)  # já carregado, sem queries extras
```

### ❌ Capturar `Exception` genérica e engolir o erro
**Problema:** O desenvolvedor usa `except Exception: pass` ou `except Exception as e: print(e)` nos handlers de erro da aplicação.
**Por quê evitar:** Erros críticos (falha de banco, OOM, bug de lógica) são silenciados; o sistema continua em estado inválido sem alertas, tornando diagnóstico em produção impossível.
**Solução:**
```python
# Errado
try:
    result = await service.create(data)
except Exception:
    pass  # engole tudo silenciosamente

# Correto — capturar exceções específicas e re-raise o resto
try:
    result = await service.create(data)
except ConflictError:
    raise
except Exception:
    log.exception("erro inesperado ao criar usuário", email=data.email)
    raise
```

### ❌ Argumento padrão mutável em assinatura de função
**Problema:** O desenvolvedor usa um objeto mutável (lista, dict) como valor padrão de parâmetro em Python (`def func(items=[])`).
**Por quê evitar:** Python avalia o default uma única vez na definição da função; o mesmo objeto é compartilhado entre todas as chamadas, causando acúmulo de estado entre requests em FastAPI.
**Solução:**
```python
# Errado
async def process_items(items: list = []):
    items.append("novo")  # modifica o mesmo objeto em todas as chamadas!

# Correto
async def process_items(items: list | None = None):
    if items is None:
        items = []
    items.append("novo")
```

### ❌ Não usar injeção de dependência (importar sessão globalmente)
**Problema:** O desenvolvedor importa e usa a sessão de banco de dados como variável global em vez de injetá-la via `Depends()` do FastAPI.
**Por quê evitar:** Sessões globais não são thread-safe nem task-safe em contexto async; impossibilitam rollback isolado por request e dificultam o override em testes (sem `dependency_overrides`).
**Solução:**
```python
# Errado
from app.database import global_session  # sessão compartilhada globalmente

@router.get("/users/{id}")
async def get_user(user_id: UUID):
    return await global_session.get(User, user_id)

# Correto
@router.get("/users/{user_id}")
async def get_user(
    user_id: UUID,
    service: UserService = Depends(get_user_service),  # sessão injetada e isolada
):
    return await service.get_by_id(user_id)
```

### ❌ Ler secrets diretamente de `os.environ` em vez de usar Settings
**Problema:** O desenvolvedor usa `os.environ["JWT_SECRET"]` ou `os.getenv("DATABASE_URL")` espalhados pelo código em vez de centralizar em `Settings`.
**Por quê evitar:** Sem `SecretStr` do Pydantic o valor vaza em logs e tracebacks; sem `BaseSettings` não há validação na inicialização, e erros de configuração só são descobertos em runtime quando aquele código é executado.
**Solução:**
```python
# Errado
import os
secret = os.environ["JWT_SECRET"]  # vaza em repr/logs; falha em runtime

# Correto
from app.core.config import settings  # validado na inicialização, SecretStr protege o valor

secret = settings.JWT_SECRET.get_secret_value()
```

### ❌ `await` ausente em corrotina (no-op silencioso)
**Problema:** O desenvolvedor chama uma função `async def` sem o `await`, recebendo um objeto corrotina sem executá-la.
**Por quê evitar:** Python não lança erro imediato — a corrotina nunca é executada e o resultado é sempre o objeto corrotina (truthy), causando comportamento incorreto silencioso; o warning `RuntimeWarning: coroutine was never awaited` muitas vezes é ignorado.
**Solução:**
```python
# Errado
def create_user_sync(data: UserCreate):
    result = service.create(data)  # retorna corrotina, não executa nada
    return result

# Correto
async def create_user(data: UserCreate):
    result = await service.create(data)  # executa a corrotina
    return result
```

### ❌ Usar `print()` em vez de logging estruturado
**Problema:** O desenvolvedor usa `print()` para registrar eventos e erros em vez de usar `structlog` (padrão do projeto).
**Por quê evitar:** `print()` produz texto sem estrutura, sem nível de severidade e sem contexto de request; em produção, logs não estruturados não são indexáveis em sistemas como Datadog ou Loki.
**Solução:**
```python
# Errado
print(f"criando usuário: {data.email}")
print(f"erro: {err}")

# Correto
import structlog
log = structlog.get_logger()

log.info("criando usuário", email=data.email)
log.error("falha ao criar usuário", error=str(err), email=data.email)
```

### ❌ Estado global mutável em aplicação async (thread-unsafe)
**Problema:** O desenvolvedor armazena estado da requisição (ex: usuário autenticado, tenant atual) em variáveis globais de módulo em vez de usar `contextvars` ou dependências do FastAPI.
**Por quê evitar:** Em FastAPI com múltiplos workers async, variáveis globais são compartilhadas entre corrotinas concorrentes; uma request pode sobrescrever o estado de outra, causando vazamento de dados entre usuários.
**Solução:**
```python
# Errado
current_user = None  # variável global — corrompida sob concorrência

@router.get("/me")
async def get_me():
    global current_user
    current_user = await authenticate(request)  # perigoso!
    return current_user

# Correto — usar Depends para isolar estado por request
async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    return await authenticate(token)

@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user)):
    return current_user
```
