# ADR-027: Testes Automatizados — Decisões de Stack e Padrões (Azure DevOps)

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Sem padronização de testes no contexto Azure DevOps, cada projeto define tags, categorias e pipeline integration de forma diferente. A padronização garante pirâmide de testes consistente, execução no estágio correto da pipeline e reporting integrado com boards.

## Decisão

Adotar pirâmide de testes com 6 categorias (unit, integration, contract, E2E, performance, security) com tags padronizadas, execução em estágios específicos da pipeline Azure DevOps e reporting integrado com boards.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| **Go** | | | | |
| Unit/Integration | testify | 1.9+ | stdlib testing | Assertions rica, suite setup/teardown |
| Integration Containers | testcontainers-go | 0.32+ | Docker Compose | Cleanup automático, real DB |
| Load | k6 | 0.50+ | Artillery, Locust | Prometheus integration, JS scripts |
| **Python** | | | | |
| Unit/Integration | pytest | 8.x+ | unittest | Fixtures, parametrize, plugins |
| Integration Containers | testcontainers-python | 4.x+ | Docker Compose | Cleanup automático |
| Load | Locust | 2.x+ | k6 | Python-native, distributed |
| **Java** | | | | |
| Unit | JUnit 5 | 5.11+ | JUnit 4 | Modern assertions, parametrized |
| Mocking | Mockito | 5.x+ | EasyMock | Padrão Spring ecosystem |
| Integration Containers | Testcontainers | 1.20+ | Docker Compose | JUnit 5 integration |
| **Frontend** | | | | |
| Unit/Component | Vitest + RTL | 2.x+ / 16.x+ | Jest + Enzyme | Vite-native, accessible queries |
| E2E | Playwright | 1.45+ | Cypress | Multi-browser, auto-wait |
| **Cross-language** | | | | |
| Contract | Pact | 10.x+ | Spring Cloud Contract | Consumer-driven, polyglot |
| Mutation | Stryker | 8.x+ | PITest (Java-only) | Multi-language |
| Security (DAST) | OWASP ZAP | 2.15+ | Burp Suite (manual) | CI-native, automation |

## Padrões Obrigatórios

### 1. Pirâmide de Testes

```
            /────────────\
           /  Performance  \    5% — Pré-prod/destaque
          /    Security     \   5% — CI + Release
         /──────────────────\
        /      E2E           \  10% — Dev + Hmg
       /─────────────────────\
      /    Integration         \ 20% — CI + Dev
     /─────────────────────────\
    /      Unit                  \60% — CI (commit + PR)
   /─────────────────────────────\
```

| Tipo | Proporção | Executar em | Tags |
|------|-----------|-------------|------|
| Unitários | 60% | Commit + PR | `@unit` |
| Integração | 20% | CI + Dev | `@integration` |
| Contrato | 5% | CI | `@contract` |
| E2E | 10% | Dev + Hmg | `@e2e` |
| Performance | 5% | Pré-prod | `@performance` |
| Segurança | 5% | CI + Release | `@security` |

### 2. Tags e Categorias

| Tag | Descrição | Executar em |
|-----|-----------|-------------|
| `@unit` | Testes unitários | CI |
| `@integration` | Testes de integração | CI + Dev |
| `@contract` | Testes de contrato | CI |
| `@e2e` | Testes end-to-end | Dev + Hmg |
| `@smoke` | Testes de smoke | Deploy |
| `@regression` | Testes de regressão | Hmg |
| `@performance` | Testes de performance | Pré-prod |
| `@security` | Testes de segurança | CI + Release |
| `@slow` | Testes lentos | Noturnos |
| `@skip` | Testes pulados | Never |

**Exemplos de uso:**

**Go:**
```go
func TestPaymentService_Process(t *testing.T) {
    // teste unitário — executado em todo CI
}
//go:build integration
func TestPaymentRepository_Save(t *testing.T) {
    // teste de integração — executado com testcontainers
}
```

**Python:**
```python
@pytest.mark.unit
def test_calculate_total():
    ...

@pytest.mark.integration
def test_save_order(db_session):
    ...
```

**Java:**
```java
@Tag("unit")
class PaymentServiceTest { ... }

@Tag("integration")
class PaymentRepositoryIT { ... }
```

**Frontend:**
```javascript
describe('UserService', () => {
  test('should create user', async () => {
    // ...
  }, { tags: ['unit', 'fast'] });
});
```

### 3. Pipeline de Testes

**Pipeline CI com Testes:**

```yaml
# azure-pipelines-ci.yml
stages:
  - stage: Lint_TypeCheck
    jobs:
      - job: Lint_TypeCheck
        steps:
          - script: make lint
          - script: make typecheck

  - stage: SAST
    jobs:
      - job: SAST
        steps:
          - task: Semgrep@1
          - task: gitleaks@1

  - stage: Unit_Tests
    dependsOn: Lint_TypeCheck
    jobs:
      - job: Unit
        steps:
          - script: make test-unit          # @unit
          - task: PublishTestResults@2
          - task: PublishCodeCoverageResults@1
            inputs:
              codeCoverageTool: 'Cobertura'
              summaryFileLocation: 'coverage.xml'

  - stage: SCA
    jobs:
      - job: SCA
        steps:
          - task: Snyk@1

  - stage: Build_Scan
    dependsOn: [Unit_Tests, SCA]
    jobs:
      - job: Build_Scan
        steps:
          - script: docker build -t app:$(Build.BuildId) .
          - script: trivy image app:$(Build.BuildId)

  - stage: Integration_Tests
    dependsOn: Build_Scan
    jobs:
      - job: Integration
        steps:
          - script: make test-integration    # @integration

  - stage: Contract_Tests
    dependsOn: Build_Scan
    jobs:
      - job: Contract
        steps:
          - script: make test-contract       # @contract
```

**Pipeline E2E (Staging):**

```yaml
# azure-pipelines-e2e.yml
trigger: none

stages:
  - stage: Deploy_Staging
    jobs:
      - deployment: staging
        environment: staging

  - stage: E2E_Tests
    dependsOn: Deploy_Staging
    jobs:
      - job: Smoke
        steps:
          - script: make test-smoke           # @smoke

      - job: E2E
        dependsOn: Smoke
        steps:
          - script: make test-e2e              # @e2e

      - job: Performance
        dependsOn: Smoke
        steps:
          - script: make test-performance      # @performance

      - job: Security_DAST
        dependsOn: Smoke
        steps:
          - script: make test-security-dast    # @security (ZAP)
```

### 4. Matriz de Execução

| Fase | Testes Executados | Ambiente |
|------|-------------------|----------|
| Commit | Unitários | - |
| PR | Unitários + Lint + SAST | - |
| Merge Develop | Unitários + Integração | DEV |
| Deploy DEV | Smoke Tests | DEV |
| Deploy HMG | Smoke + Integração + E2E | HMG |
| Deploy PROD | Smoke + Contract | PROD |
| Release | Performance + Security | HMG |
| Noturno | Regression + E2E completo | DEV/HMG |

### 5. Relatórios e Monitoramento

**Ferramentas de Relatório:**
- Azure DevOps Test Plans — reporting nativo
- Cobertura — coverage trends por pipeline
- Allure Report — para testes E2E Playwright
- k6 Dashboard — para testes de performance

**Métricas de Qualidade:**

| Métrica | Target | Ação se abaixo |
|---------|--------|---------------|
| Coverage | > 80% | Block pipeline |
| Flaky rate | < 1% | Quarantine + investigate |
| E2E pass rate | > 95% | Block deploy |
| Performance p99 | < SLA | Alert + investigate |
| Security (DAST) | 0 Críticas | Block release |

### 6. Ambiente de Testes

**Dados de Teste:**
- Fixtures gerenciadas (golden files)
- Factories para dados dinâmicos (testcontainers)
- Nunca dados de produção em ambiente de teste
- Database seeds versionados com migrations

**Configuração de Ambiente:**

| Ambiente | Purpose | Infra |
|----------|---------|-------|
| CI (ephemeral) | Unit + Integration | testcontainers |
| DEV | Smoke + Development | Namespace K8s |
| HMG | E2E + Regression | Staging K8s |
| PROD | Smoke + Contract | Production K8s |

## Anti-padrões

- Rodar E2E em todo commit (pertence a staging)
- Sem tags de categoria (`@unit`, `@integration`) — impossível rodar seletivamente
- Coverage < 80% sem justificativa documentada
- Flaky tests aceitos (re-run não é solução)
- Testes de segurança apenas antes de release (shift-left)
- Dados de produção em ambiente de teste
- Sem build tag para separar unit vs integration
- Fixtures hardcoded (usar golden files)
- Sleep/wait hardcoded em testes assíncronos
- Não publicar resultados no Azure DevOps Test Plans
- Testes E2E para lógica de negócio (pertence ao unit test)

## Consequências

**Positivas:**
- Pirâmide de testes consistente em todos os projetos
- Tags permitem execução seletiva por estágio
- Pipeline integration garante quality gates
- Reporting integrado com Azure DevOps Boards
- Matriz de execução clara (qual teste, quando, onde)

**Negativas:**
- Pipeline mais complexo (múltiplos stages)
- testcontainers adiciona overhead (~30s startup)
- E2E em staging requer ambiente estável
- Manutenção de fixtures e golden files

**Riscos:**
- Flaky E2E — mitigar com selectors estáveis e retry policy
- Coverage darwinismo (testes para atingir 80% sem valor) — mitigar com code review focado em qualidade
- Pipeline lento — mitigar com paralelismo e cache de dependências

## Referências

- `exemplos/padronizacao/azure/testes.md`
- `skills/DevSecOps/testing-expert/SKILL.md`
- Azure DevOps Test Plans: https://docs.microsoft.com/pt-br/azure/devops/test/
- Playwright: https://playwright.dev/
- k6: https://k6.io/
- Pact: https://pact.io/
- ADR-021 (Testing) — testes por linguagem
- ADR-022 (CI/CD) — pipeline de segurança
- ADR-025 (CI/CD Azure DevOps) — pipeline CI/CD