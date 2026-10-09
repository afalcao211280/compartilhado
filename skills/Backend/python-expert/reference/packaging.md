# Packaging & Toolchain — uv, pyproject, CI

Gerência de dependências, empacotamento e toolchain de qualidade no padrão EVEO. **`uv` é o package manager canônico** (ADR-003): 10-100x mais rápido que pip, resolve + instala + gera lock + gerencia a versão do Python. Poetry/pip/black **não** são usados em projeto novo (ver [Descartes](#8-descartes-nao-usar-na-eveo)).

## Índice

1. [uv — fluxo de trabalho](#1-uv--fluxo-de-trabalho)
2. [pyproject.toml canônico](#2-pyprojecttoml-canonico)
3. [Layout de projeto](#3-layout-de-projeto)
4. [Ruff — lint + format](#4-ruff--lint--format)
5. [mypy --strict](#5-mypy---strict)
6. [Dockerfile multi-stage com uv](#6-dockerfile-multi-stage-com-uv)
7. [CI (GitHub Actions) + pre-commit](#7-ci-github-actions--pre-commit)
8. [Descartes (não usar na EVEO)](#8-descartes-nao-usar-na-eveo)

---

## 1. uv — fluxo de trabalho

```bash
uv init --package meu-servico     # cria pyproject.toml + estrutura
uv python pin 3.13                # grava .python-version; uv baixa o interpretador se faltar

uv add fastapi "sqlalchemy[asyncio]>=2.0" asyncpg pydantic-settings   # runtime deps
uv add --group dev pytest pytest-asyncio ruff mypy respx testcontainers  # deps de dev

uv sync                           # instala tudo do lock em .venv (cria/atualiza .venv)
uv sync --frozen                  # falha se uv.lock estiver desatualizado (usar em CI/Docker)
uv lock                           # regenera uv.lock após mexer nas deps manualmente
uv lock --upgrade                 # sobe versões respeitando os constraints

uv run pytest                     # roda no .venv sem ativar shell
uv run ruff check . && uv run mypy app
uv build                          # gera sdist + wheel em dist/ (libs)
uv export --no-dev > requirements.txt   # só se um consumidor exigir requirements.txt
```

**Regras EVEO:**
- **Commite `uv.lock`** — ele é a fonte de verdade de builds reprodutíveis (aplicações). Bibliotecas commitam o lock também, mas publicam ranges no `pyproject.toml`.
- **`.python-version`** commitado fixa o interpretador do time e do CI.
- Docker e CI usam **`uv sync --frozen`** — build falha se o lock divergir do `pyproject.toml`, nunca resolve silenciosamente.
- Nunca `pip install` num projeto uv; use `uv add`/`uv run`.

## 2. pyproject.toml canônico

Arquivo único: metadados, deps, e config de **todas** as ferramentas (ruff, mypy, pytest, coverage).

```toml
[project]
name = "meu-servico"
version = "0.1.0"
description = "Microsserviço EVEO"
requires-python = ">=3.12"          # mínimo suportado; alvo de execução é 3.13
dependencies = [
    "fastapi>=0.115",
    "sqlalchemy[asyncio]>=2.0",
    "asyncpg>=0.29",
    "pydantic-settings>=2.0",
    "structlog>=24.0",
    "httpx>=0.27",
]

# Grupos de dev não vão para a imagem de produção (uv sync --no-dev)
[dependency-groups]
dev = [
    "pytest>=8.0",
    "pytest-asyncio>=0.23",
    "pytest-cov>=5.0",
    "respx>=0.21",
    "testcontainers>=4.0",
    "hypothesis>=6.0",
    "ruff>=0.4",
    "mypy>=1.9",
    "bandit>=1.7",
]

[build-system]                      # necessário só para libs empacotáveis (uv build)
requires = ["hatchling"]
build-backend = "hatchling.build"

[project.scripts]                   # entrypoints de CLI, se houver
meu-servico = "app.cli:main"

[tool.uv]
package = true                      # false para apps que não são instaladas como pacote
```

- **Aplicação (serviço)**: deps com pisos (`>=`), o `uv.lock` fixa as versões exatas. `package = false` se não for instalável.
- **Biblioteca**: deps com ranges (`>=x,<y`), `[build-system]` obrigatório, adicione `py.typed` (marcador PEP 561) em `app/` para exportar os type hints.

## 3. Layout de projeto

Serviços EVEO usam o layout `app/` (ver `core.md` / SKILL.md — Clean Architecture). Bibliotecas publicáveis usam **src layout** para evitar import acidental do diretório de trabalho:

```
minha-lib/
├── pyproject.toml
├── uv.lock
├── .python-version
├── src/
│   └── minha_lib/
│       ├── __init__.py
│       └── py.typed          # exporta os type hints (PEP 561)
└── tests/
```

```toml
# pyproject.toml da lib com src layout
[tool.hatch.build.targets.wheel]
packages = ["src/minha_lib"]
```

## 4. Ruff — lint + format

Ruff substitui flake8 + isort + black + pyupgrade numa ferramenta em Rust. **Não** rode black em paralelo — `ruff format` é o formatador.

```toml
[tool.ruff]
target-version = "py313"
line-length = 100

[tool.ruff.lint]
select = [
    "E", "W",   # pycodestyle
    "F",        # pyflakes
    "I",        # isort (ordenação de imports)
    "UP",       # pyupgrade (moderniza sintaxe p/ a versão alvo)
    "B",        # flake8-bugbear (bugs sutis)
    "S",        # flake8-bandit (segurança)
    "ANN",      # exige type annotations
    "ASYNC",    # armadilhas de asyncio (ex.: sleep bloqueante)
    "C4",       # comprehensions
    "SIM",      # simplificações
]
ignore = ["ANN401"]   # permite Any explícito e justificado em casos raros

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S101", "ANN"]   # asserts e menos rigor de tipos em testes
"__init__.py" = ["F401"]       # re-exports intencionais
```

Comandos: `uv run ruff check --fix .` e `uv run ruff format .`.

## 5. mypy --strict

```toml
[tool.mypy]
python_version = "3.13"
strict = true                     # liga o conjunto completo de checagens
warn_return_any = true
warn_unused_ignores = true        # detecta `# type: ignore` que não faz mais efeito
disallow_untyped_defs = true
disallow_any_generics = true      # proíbe list/dict "pelados"
no_implicit_optional = true

# Libs de terceiros sem stubs: isolar o ignore, nunca global
[[tool.mypy.overrides]]
module = ["some_untyped_lib.*"]
ignore_missing_imports = true
```

`strict = true` já liga a maioria das flags acima; listá-las torna a intenção explícita e sobrevive a mudanças de default entre versões. Rode `uv run mypy app` no CI — zero erros é gate de merge.

## 6. Dockerfile multi-stage com uv

```dockerfile
# ---- builder: resolve deps com uv, sem toolchain no runtime ----
FROM python:3.13-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy
WORKDIR /app

# Camada de deps cacheável: copia só os manifests primeiro
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev

COPY . .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev        # instala o projeto; --no-dev exclui deps de teste

# ---- runtime: imagem slim só com o venv ----
FROM python:3.13-slim AS runtime
RUN useradd -m -u 1000 app
WORKDIR /app
COPY --from=builder --chown=app:app /app /app
ENV PATH="/app/.venv/bin:$PATH"
USER app
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

- `--frozen` garante build reprodutível (usa exatamente o `uv.lock`).
- `--no-dev` mantém a imagem sem pytest/ruff/mypy.
- Separar o `uv sync` das deps (manifests) do `uv sync` do projeto (código) maximiza cache de camada.
- Roda como usuário não-root.

## 7. CI (GitHub Actions) + pre-commit

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.12", "3.13"]
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v3
        with:
          enable-cache: true
      - run: uv python pin ${{ matrix.python-version }}
      - run: uv sync --frozen
      - run: uv run ruff check .
      - run: uv run ruff format --check .
      - run: uv run mypy app
      - run: uv run bandit -r app
      - run: uv run pytest --cov=app --cov-fail-under=80
```

```yaml
# .pre-commit-config.yaml — mesmos gates rodando localmente antes do commit
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.4.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.9.0
    hooks:
      - id: mypy
        additional_dependencies: [pydantic]
```

`uv run pre-commit install` uma vez; depois roda a cada commit. Testar a matriz `3.12`/`3.13` garante que o mínimo suportado e o alvo continuam verdes.

## 8. Descartes (não usar na EVEO)

Padrões comuns em tutoriais Python que **não** entram em projeto novo:

- **Poetry / `poetry add` / `poetry.lock`** → use `uv`. Não misture os dois.
- **`black`** → `ruff format` é o formatador (evita conflito de dois formatadores).
- **`setup.py` / `setuptools` / `MANIFEST.in`** → legado; `pyproject.toml` + hatchling.
- **`pip install -e .` + `requirements.txt` manual** → `uv sync` + `uv.lock`. Gere `requirements.txt` só com `uv export` se um consumidor externo exigir.
- **`pip freeze > requirements.txt`** → não determinístico entre plataformas; o lock resolve isso.
- **`[project.optional-dependencies].dev`** para dev deps → prefira `[dependency-groups]` (PEP 735, entendido nativamente pelo uv e excluído do build).
