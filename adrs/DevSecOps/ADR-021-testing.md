# ADR-021: Testes Automatizados — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Sem padronização de testes, cada projeto adota ferramentas e níveis de coverage diferentes. Resultado: testes instáveis (flaky), coverage insuficiente e pipeline lento. A padronização garante pirâmide de testes consistente, ferramentas por linguagem e coverage mínimo de 80%.

## Decisão

Adotar a pirâmide de testes (70% unitários / 20% integração / 10% E2E) como padrão EVEO, com stack definida por linguagem, coverage mínimo de 80%, mutation testing (Stryker) e zero tolerância para flaky tests (quarantine policy).

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| **Go** | | | | |
| Test Framework | testify | 1.9+ | stdlib testing | Assertions rica, suite setup/teardown |
| Integration | testcontainers-go | 0.32+ | Docker Compose manual | Containers reais, cleanup automático |
| Load Test | k6 | 0.50+ | Artillery, Locust | Go-native output, Prometheus integration |
| **Python** | | | | |
| Test Framework | pytest | 8.x+ | unittest, nose | Fixtures, parametrize, plugins |
| Integration | testcontainers-python | 4.x+ | Docker Compose manual | Containers reais, cleanup automático |
| Load Test | Locust | 2.x+ | k6, Artillery | Python-native, distributed |
| **Java** | | | | |
| Test Framework | JUnit 5 | 5.11+ | JUnit 4, TestNG | JUnit 5: extensions, parametrized |
| Mocking | Mockito | 5.x+ | EasyMock, PowerMock | Padrão de mercado, bem integrado com Spring |
| Integration | Testcontainers | 1.20+ | Docker Compose manual | JUnit 5 integration, containers reais |
| **Frontend** | | | | |
| Unit/Integration | Vitest | 2.x+ | Jest | Mais rápido, ESM-native, Vite-native |
| Component | React Testing Library (RTL) | 16.x+ | Enzyme | Accessible queries, behavior over implementation |
| E2E | Playwright | 1.45+ | Cypress | Multi-browser, auto-wait, melhor debugging |
| **Cross-language** | | | | |
| Mutation Testing | Stryker | 8.x+ | PITest (Java-only) | Multi-language: JS/TS, .NET, Java |
| Contract Testing | Pact | 10.x+ | Spring Cloud Contract | Consumer-driven, polyglot |

## Padrões Obrigatórios

### Pirâmide de Testes

```
        /----------\
       /    E2E      \     10% — Smoke + Critical paths
      /----------------\
     /   Integration    \   20% — API, DB, External services
    /--------------------\
   /      Unit            \  70% — Business logic, edge cases
  /__________________________\
```

- 70% testes unitários — rápidos, determinísticos, sem I/O
- 20% testes de integração — com containers reais (testcontainers)
- 10% testes E2E — smoke tests e critical paths
- Coverage target: >80%

### Por Linguagem

**Go:**
- `testify` para assertions e suites
- `testcontainers-go` para integração (PostgreSQL, Redis, Kafka)
- `k6` para load testing
- Table-driven tests para casos edge

**Python:**
- `pytest` com fixtures e parametrize
- `testcontainers-python` para integração
- `Locust` para load testing

**Java:**
- `JUnit 5` + `Mockito` para unitários
- `Testcontainers` para integração (PostgreSQL, Kafka, etc.)
- `PITest` para mutation testing (alternativa Stryker para Java)

**Frontend:**
- `Vitest` + `RTL` para unit/component tests
- `Playwright` para E2E
- `Testing Library` para queries accessible

### Mutation Testing

- Stryker configurado em CI (weekly ou por trigger)
- Mutation score mínimo: 60%
- Tipos de mutação: string, arithmetic, conditional, boundary
- Não obrigatório em todos os PRs — rodar semanalmente ou manualmente

### Flaky Tests (Zero Tolerância)

- Quarantine policy: teste flaky é removido do pipeline imediatamente
- Issue criada automaticamente para cada flaky test detectado
- Re-run não é solução — testes devem ser determinísticos
- Timeout explícito em todos os testes assíncronos

## Estrutura de Projeto / Configuração

```
src/
├── module/
│   ├── service.go
│   ├── service_test.go          # Unit
│   └── service_integration_test.go  # Integration (build tag)
├── testdata/                     # Fixtures
│   ├── golden/
│   └── mocks/
└── e2e/
    ├── e2e_test.go
    └── fixtures/

scripts/
├── test-unit.sh
├── test-integration.sh
└── test-e2e.sh

.github/workflows/               # ou azure-pipelines.yml
├── ci.yml                       # lint → SAST → unit → SCA → integration
└── e2e.yml                       # E2E em staging
```

### Config de CI (Quality Gates)

```yaml
quality_gates:
  unit_coverage:
    threshold: 80                 # Mínimo 80%
    fail_on_decrease: true        # Falha se coverage diminuir
  mutation_score:
    threshold: 60                 # Mínimo 60%
    frequency: weekly             # Rodar semanalmente
  flaky_tests:
    tolerance: 0                  # Zero tolerância
    quarantine: true              # Remove automaticamente
```

## Anti-padrões

- Teste de implementação (testar métodos privados) — testar comportamento
- Flaky tests aceitos (re-run não é solução)
- Coverage < 80% sem justificativa documentada
- Testes E2E para lógica de negócio (pertence ao unit test)
- Mockar tudo (testes de integração devem usar containers reais)
- Sem build tag separador (unit vs integration rodando juntos no CI)
- Fixtures hardcoded sem golden files
- Sleep/wait hardcoded em testes assíncronos (usar retry/poll)
- Mutation testing obrigatório em todo PR (muito lento — rodar weekly)
- Não rodar testcontainers cleanup (containers órfãos)

## Consequências

**Positivas:**
- Consistência: pirâmide 70/20/10 aplicada em todos os projetos
- Coverage >80% garante confiança no refactoring
- Mutation testing valida a qualidade dos testes
- Zero flaky tests = pipeline determinística
- Ferramentas padronizadas por linguagem

**Negativas:**
- testcontainers adiciona overhead ao CI (~30s para containers)
- Playwright multi-browser é mais lento que Cypress
- Mutation testing semanal pode não pegar regressões imediatas
- Stryker tem limitações em Go (PITest como alternativa Java)

**Riscos:**
- Pressão para atingir 80% coverage pode gerar testes sem valor — code review deve focar em qualidade
- testcontainers em CI pode ter instabilidade em runners congestionados — retry policy
- E2E flaky por natureza — mitigar com retries e selectors estáveis

## Referências

- `skills/DevSecOps/testing-expert/SKILL.md`
- `exemplos/padronizacao/azure/testes.md`
- testcontainers: https://testcontainers.com/
- Stryker: https://stryker-mutator.io/
- k6: https://k6.io/
- Playwright: https://playwright.dev/
- ADR-020 (Pentest) — testes de segurança no pipeline
- ADR-022 (CI/CD) — integração de testes no pipeline
- ADR-027 (Testes Automatizados Azure DevOps) — pipeline de testes