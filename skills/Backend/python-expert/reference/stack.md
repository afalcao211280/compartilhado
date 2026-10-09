# Python Expert — Stack Canônica

## Python 3.12+ (alvo 3.13) — Versão Canônica EVEO

> **Alvo atual: Python 3.13** (última estável). Mínimo suportado 3.12+. Atualize `python_version`/`target-version` no `pyproject.toml` ao subir a diretiva.

| Categoria | Lib | Versão | Link | Notas |
|-----------|-----|--------|------|-------|
| **API** | | | | |
| API framework | FastAPI | 0.110+ | https://fastapi.tiangolo.com | Toda HTTP API nova |
| Web framework | Django | 5.x | https://docs.djangoproject.com | Projetos full-stack (admin, auth) |
| ASGI server | Uvicorn | 0.29+ | https://www.uvicorn.org | Prod com Gunicorn workers |
| WSGI server | Gunicorn | 22.x | https://gunicorn.org | Manager de processos Uvicorn |
| **Validação** | | | | |
| Schemas/validação | Pydantic v2 | 2.7+ | https://docs.pydantic.dev | Sempre. Schemas, settings, DTOs |
| Settings | pydantic-settings | 2.x | https://docs.pydantic.dev/latest/concepts/pydantic_settings/ | Carregar config de env vars |
| **ORM e Banco** | | | | |
| ORM async | SQLAlchemy 2.0 | 2.0+ (async) | https://docs.sqlalchemy.org/en/20/ | Com FastAPI. `AsyncSession` |
| ORM sync | Django ORM | 5.x | https://docs.djangoproject.com/en/5.0/topics/db/ | Com Django |
| Migrations | Alembic | 1.13+ | https://alembic.sqlalchemy.org | Com SQLAlchemy |
| DB driver async | asyncpg | 0.29+ | https://magicstack.github.io/asyncpg | PostgreSQL async (FastAPI) |
| DB driver sync | psycopg3 | 3.1+ | https://www.psycopg.org/psycopg3/ | PostgreSQL sync (Django) |
| **HTTP e Circuit Breaker** | | | | |
| HTTP client | httpx | 0.27+ | https://www.python-httpx.org | Async + sync. Substitui requests |
| Retries | tenacity | 8.x | https://tenacity.readthedocs.io | Retry com backoff em httpx calls |
| Circuit breaker | circuitbreaker | 1.4+ | https://pypi.org/project/circuitbreaker/ | Decorador em httpx calls externas |
| **Cache e Mensageria** | | | | |
| Cache | redis-py | 5.x | https://redis-py.readthedocs.io | `redis.asyncio` para FastAPI |
| Tasks/queue | Celery | 5.x | https://docs.celeryq.dev | Background jobs, scheduled |
| Queue broker | kombu | 5.x | https://kombu.readthedocs.io | Usado internamente pelo Celery |
| RabbitMQ | aio-pika | 9.x | https://aio-pika.readthedocs.io | Async consumer direto (sem Celery) |
| **Logging e Observabilidade** | | | | |
| Logging estruturado | structlog | 24.x | https://www.structlog.org | JSON em prod, console dev (default da skill) |
| Logging estruturado (alt.) | loguru | 0.7+ | https://loguru.readthedocs.io | Alternativa ratificada no ADR-003. Zero-config, rotation. Escolher UM por projeto |
| Tracing | opentelemetry-sdk | 1.24+ | https://opentelemetry.io/docs/languages/python/ | OTLP gRPC exporter |
| Métricas | prometheus-client | 0.20+ | https://github.com/prometheus/client_python | Endpoint `/metrics` |
| **Testes** | | | | |
| Test framework | pytest | 8.x | https://docs.pytest.org | Sempre |
| Async test | pytest-asyncio | 0.23+ | https://pytest-asyncio.readthedocs.io | Para handlers/services async |
| Mock HTTP | respx | 0.21+ | https://lundberg.github.io/respx/ | Mock de httpx calls |
| Mock geral | pytest-mock | 3.x | https://pytest-mock.readthedocs.io | `mocker` fixture |
| Containers | testcontainers-python | 4.x | https://testcontainers-python.readthedocs.io | Postgres, Redis reais em test |
| Cobertura | pytest-cov | 5.x | https://pytest-cov.readthedocs.io | `--cov=app --cov-fail-under=80` |
| Load test | Locust | 2.x | https://locust.io | `locustfile.py` na raiz |
| **Empacotamento** | | | | |
| Package manager | uv | latest | https://docs.astral.sh/uv | Padrão EVEO (ADR-003). 10-100x mais rápido que pip; `uv sync`, `uv add`, `uv run` |
| **Qualidade** | | | | |
| Linting + format | Ruff | 0.4+ | https://docs.astral.sh/ruff | Substitui flake8 + isort + black (`ruff format`). Não usar black em paralelo |
| Type check | mypy | 1.9+ | https://mypy.readthedocs.io | `--strict` no CI |
| Security | bandit | 1.7+ | https://bandit.readthedocs.io | SAST no CI |
| Audit | pip-audit | 2.7+ | https://pypi.org/project/pip-audit/ | CVEs no CI |
| **Container** | | | | |
| Imagem base | `python:3.13-slim` | — | — | Imagem de prod |
| Builder | `python:3.13` | — | — | Estágio de build (com uv) |

## pyproject.toml — Template Canônico

```toml
[tool.mypy]
python_version = "3.12"
strict = true
disallow_untyped_defs = true
warn_return_any = true
warn_unused_ignores = true

[tool.ruff]
target-version = "py312"
line-length = 100
select = ["E", "W", "F", "I", "UP", "B", "S", "ANN"]
ignore = ["ANN101"]   # ignore self type annotation

[tool.pytest.ini_options]
asyncio_mode = "auto"
addopts = "--cov=app --cov-report=term-missing --cov-fail-under=80"
testpaths = ["tests"]

[tool.coverage.report]
exclude_lines = ["pragma: no cover", "if TYPE_CHECKING:"]
```
