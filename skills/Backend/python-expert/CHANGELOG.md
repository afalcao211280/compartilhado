# Changelog — python-expert

## [2.1.1] - 2026-07-01

### Added
- `reference/packaging.md` (novo): toolchain e empacotamento no padrão EVEO — fluxo `uv` (add/sync/lock/run, `--frozen`), `pyproject.toml` canônico, `[dependency-groups]`, src vs app layout, config completa de Ruff e mypy `--strict` (3.13), Dockerfile multi-stage com uv, CI (matriz 3.12/3.13) + pre-commit, e seção de descartes (Poetry/black/setuptools/pip).

### Changed
- `reference/python-advanced.md`: aprofundada a concorrência async — producer/consumer com `Queue` (backpressure), background tasks fire-and-forget com tracking, async generator para streaming (SSE/export); typing ganhou `Concatenate` (DI decorator).
- `reference/testing.md`: adicionadas estratégia de teste por camada, e2e com `ASGITransport`, mock HTTP com `respx`, integração com `testcontainers` (Redis), e factory fixture com cleanup.
- `SKILL.md`: alvo de execução atualizado para Python 3.13 (mínimo 3.12+), com ponteiro para `reference/packaging.md`.

## [2.1.0] - 2026-06-30

### Changed
- Consolidação em skills-optimizadas (skills/ ⨯ skills-compare/ ⨯ ADR): baseline `../../`, keywords/description ajustadas, dedup core/patterns quando idêntico.


## [2.0.0] - 2024-06-15
### Changed
- SKILL.md reduzido de 366 para ~95 linhas (caveman style)
- Conteudo granularizado em arquivos de referencia
- Seguranca movida para _shared/security/baseline.md
- Adicionado versionamento semantico

## [1.0.0] - 2024-01-10
### Added
- Versao inicial com stack EVEO 2026
- FastAPI + Django suporte
- SQLAlchemy 2.0 async
- Pydantic v2, structlog, Celery
