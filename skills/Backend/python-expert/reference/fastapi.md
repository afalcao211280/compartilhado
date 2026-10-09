# FastAPI — Setup, Routers, Dependencies

Leia `core.md` seção "1. FastAPI — Setup Completo" para detalhes.

## Setup Basico

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    configure_logging()
    configure_tracing()
    await create_engine_pool()
    yield
    await close_engine_pool()

app = FastAPI(title="EVEO Service", version="1.0.0", lifespan=lifespan)
app.include_router(api_router, prefix="/api/v1")
```

## Router + Dependencies

```python
from fastapi import APIRouter, Depends

router = APIRouter(prefix="/users", tags=["Users"])

def get_user_service(db: AsyncSession = Depends(get_db)) -> UserService:
    return UserService(UserRepository(db))

@router.post("/", response_model=UserResponse, status_code=201)
async def create_user(data: UserCreate, service: UserService = Depends(get_user_service)):
    return await service.create(data)
```

## Regras
- CORS com origins explicitas (nunca * em prod)
- Lifespan para startup/shutdown
- Exception handlers globais
- Docs URL desabilitado em producao
