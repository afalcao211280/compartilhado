# Workflow — Scaffold e Geracao de Codigo

## Quando Usar

- Ao criar **projeto novo** do zero
- Ao gerar **feature nova** em projeto existente

## Decisoes Iniciais

1. FastAPI ou Django?
2. Banco: PostgreSQL (sqlc+tern) / MongoDB / Nenhum
3. Deps externas: Redis, Celery, RabbitMQ

## Scaffold de Projeto Novo

1. `pyproject.toml`
2. `app/core/config.py`
3. `app/core/logging.py`
4. `app/database.py`
5. `app/core/exceptions.py`
6. `app/api/v1/router.py`
7. `app/main.py`
8. `docker/Dockerfile`
9. `docker/docker-compose.yml`
10. `tests/conftest.py`

## Workflow de Feature Nova

```
model → migration → schema pydantic → repository → service → router → test
```

1. Model SQLAlchemy
2. Migration Alembic
3. Schema Pydantic (Create/Update/Response)
4. Repository
5. Service
6. Router + handler
7. Testes

## Checklist de Scaffold

- [ ] `make build` compila
- [ ] `make test` passa
- [ ] Health endpoint funciona
- [ ] Docker build funciona
