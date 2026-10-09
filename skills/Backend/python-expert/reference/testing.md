# pytest — Testes

Leia `core.md` seção 10 e os anti-padrões para o conjunto base. Config de `pytest`/`coverage`/CI em `packaging.md`.

## Estratégia por camada (Clean Architecture)

Espelhe `tests/` em `app/`. Cada camada tem o tipo de teste que faz sentido:

| Camada | Tipo | Dependências | Ferramenta |
|--------|------|--------------|------------|
| `services/` | unit | repository e clients **mockados** | `AsyncMock`, `respx` |
| `repositories/` | integração | Postgres/Redis **reais** | `testcontainers` |
| `api/` (handlers) | e2e | app inteiro via `AsyncClient` | `httpx.ASGITransport` |

Mínimo por feature: caminho feliz + erro de validação + erro de repositório (ver SKILL.md).

## Fixtures

```python
import pytest
import pytest_asyncio
from testcontainers.postgres import PostgresContainer

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
```

## Parametrize com IDs (casos legíveis no output)

```python
@pytest.mark.parametrize(
    "email,valid",
    [("user@eveo.com", True), ("invalid", False), ("@eveo.com", False)],
    ids=["valido", "sem_arroba", "sem_usuario"],
)
def test_email(email: str, valid: bool) -> None:
    assert is_valid_email(email) == valid
```

## Mock de service async (AsyncMock)

```python
from unittest.mock import AsyncMock

@pytest.mark.asyncio
async def test_get_user() -> None:
    repo = AsyncMock()
    repo.get_by_id.return_value = User(id=1, name="Alice")
    user = await UserService(repo).get_user(1)
    repo.get_by_id.assert_awaited_once_with(1)
    assert user.name == "Alice"
```

## Property-based (hypothesis) — para invariantes

```python
from hypothesis import given, strategies as st

@given(st.lists(st.integers()))
def test_sort_ordena(xs: list[int]) -> None:
    out = sorted(xs)
    assert all(out[i] <= out[i + 1] for i in range(len(out) - 1))
```

## e2e — app inteiro sem subir servidor (ASGITransport)

Testa o handler real com DI, validação e exception handlers, sem porta de rede.

```python
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.core.deps import get_user_service

@pytest.mark.asyncio
async def test_create_user_endpoint() -> None:
    app.dependency_overrides[get_user_service] = lambda: fake_service
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/api/v1/users", json={"email": "a@eveo.com", "name": "Ana"})
    assert resp.status_code == 201
    app.dependency_overrides.clear()
```

## Mock de HTTP externo (respx)

Nunca bata em serviço real no teste. `respx` intercepta chamadas do `httpx` por rota.

```python
import respx
from httpx import Response

@respx.mock
@pytest.mark.asyncio
async def test_client_retry() -> None:
    route = respx.get("https://api.parceiro.com/v1/cep/01001000").mock(
        side_effect=[Response(503), Response(200, json={"uf": "SP"})]  # falha, depois OK
    )
    result = await CepClient().buscar("01001000")
    assert result.uf == "SP"
    assert route.call_count == 2   # confirma que o retry disparou
```

## Integração com dependências reais (testcontainers)

Container por sessão amortiza o custo de subida. Postgres já está em `core.md`; Redis e RabbitMQ seguem o mesmo padrão.

```python
from testcontainers.redis import RedisContainer

@pytest.fixture(scope="session")
def redis_container():
    with RedisContainer("redis:7-alpine") as r:
        yield r

@pytest_asyncio.fixture
async def redis_client(redis_container):
    client = redis.asyncio.from_url(redis_container.get_connection_url())
    yield client
    await client.flushdb()          # isola o estado entre testes
    await client.aclose()
```

## Factory fixture (dados sob demanda + cleanup)

Evita fixtures rígidas: cada teste cria só o que precisa; o cleanup roda no teardown.

```python
@pytest_asyncio.fixture
async def user_factory(db_session):
    criados: list[User] = []
    async def _make(**kw) -> User:
        user = User(email=kw.get("email", "u@eveo.com"), name=kw.get("name", "U"))
        db_session.add(user)
        await db_session.flush()
        criados.append(user)
        return user
    yield _make
    for u in criados:
        await db_session.delete(u)
    await db_session.commit()
```

## Markers úteis

`@pytest.mark.skipif(cond, reason=...)`, `@pytest.mark.xfail(reason=...)`, markers custom (`slow`, `integration`) declarados com `--strict-markers` — rode `pytest -m "not slow"` no dev.

## Regras
- pytest-asyncio para testes async; `AsyncMock` para dependências async
- testcontainers para integracao
- respx para mock HTTP; hypothesis para invariantes
- Coverage >80% (`--cov-fail-under=80`)
