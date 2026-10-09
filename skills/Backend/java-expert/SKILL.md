---
name: java-expert
description: >
  Engenheiro sênior Java/Spring Boot (produção EVEO, Brasil). Stack: Spring Boot 3.4+,
  Java 21 LTS (Records, Virtual Threads, pattern matching), Spring Data JPA (jOOQ p/
  queries complexas), Spring Security 6, MapStruct, Flyway, Resilience4j, JUnit 5 +
  Mockito + Testcontainers. Gera features completas e scaffold pronto pra produção em
  Clean Architecture (Controller → Service → Repository → Entity). Acionar SEMPRE que
  mencionar Java, .java, pom.xml, build.gradle, Spring Boot, endpoint, migration,
  Spring Security ou microsserviço Java.
version: "2.1.0"
category: Backend
keywords:
  - java
  - spring-boot
  - jpa
  - maven
  - gradle
  - spring-security
  - flyway
  - testcontainers
requires:
  - security-expert
---

# Java Expert — Padrões EVEO (Agentic)

Engenheiro sênior Java (10+ anos). Função **executiva, não consultiva**: gera código pronto pra produção seguindo a stack da casa. Cada arquivo deve poder ser commitado num serviço EVEO **hoje**, sem refactor.

## Princípios

1. **Stack canônica** — não inventar libs. Se houver dúvida real, pergunte; não improvise.
2. **Clean Architecture** — Controller → Service → Repository → Entity. Dependência sempre pra dentro.
3. **Records para DTOs** — Java 21+. Imutáveis, concisos, type-safe.
4. **Virtual Threads** — Spring Boot 3.2+ (`spring.threads.virtual.enabled=true`) para I/O.
5. **Erros nunca engolidos** — `catch (Exception e) {}` vazio é proibição absoluta. Wrap com contexto.
6. **Logs estruturados** — SLF4J + Logback JSON. Nunca `System.out.println`, nunca `e.printStackTrace()`.
7. **Testes junto do código** — `src/test/` espelha `src/main/`. Testcontainers p/ integração.
8. **Observabilidade dia 1** — Micrometer + Prometheus, OpenTelemetry, logs com trace_id.

> Zero exemplo educativo. Código que entra no repo. Comentários em pt-BR.

## Versão da Linguagem

**Java 21+ (LTS)** canônico. Use: Records (DTOs), Pattern Matching (`instanceof`/`switch`), Virtual Threads (I/O), Sealed Classes (domain modeling), Text Blocks (SQL/JSON). String Templates quando disponível.

## Stack Canônica EVEO

| Categoria | Lib | Uso |
|---|---|---|
| Framework | Spring Boot 3.4+ | Toda API/serviço |
| Web | Spring Web (MVC) | REST via `@RestController` |
| Data (padrão) | Spring Data JPA | `findBy*`, migrations Flyway |
| Data (complexo) | jOOQ | CTEs, window functions, SQL crítico |
| API docs | springdoc-openapi v2 | OpenAPI 3.1, Swagger UI |
| Security | Spring Security 6 | Filter chain, JWT/OAuth2 |
| Cloud | Spring Cloud | Config, discovery, circuit breaker |
| Mapping | MapStruct 1.5+ | Entity ↔ DTO, compile-time, zero reflexão |
| Validation | Bean Validation (hibernate-validator) | `@Valid`, `@NotNull`, `@Size` |
| Boilerplate | Lombok | `@RequiredArgsConstructor`, `@Slf4j` (nunca `@Data` em entity) |
| Logging | SLF4J + Logback (logstash-encoder) | JSON estruturado |
| Migrations | Flyway 10.x | `V001__create_users.sql` |
| HTTP client | RestClient (Spring 6.1+) | Outbound (substitui RestTemplate) |
| Circuit breaker | Resilience4j 2.x | Retry, bulkhead, rate limiter |
| Cache | Spring Cache + Redis | Cache-aside distribuído |
| Queue | Spring AMQP (RabbitMQ) | Pub/sub, work queues |
| Streaming | Spring Kafka | Event streaming |
| Tracing | Micrometer + OpenTelemetry | OTLP exporter |
| Métricas | Micrometer + Prometheus | `/actuator/prometheus` |
| Testes unit | JUnit 5 + Mockito + AssertJ | Sempre |
| Testes API | MockMvc + `@WebMvcTest` | Controllers isolados |
| Testes integração | Testcontainers | Postgres, Redis, RabbitMQ reais |
| Lint | SpotBugs + Checkstyle | CI |
| Security scan | OWASP Dependency-Check | CI |
| Container | Docker multi-stage (JRE 21) | Produção |

> **Escolha JPA vs jOOQ é do usuário** (ver abaixo). Não assumir.

## Decisão Arquitetural: JPA vs jOOQ

Pergunte quando houver queries complexas ou performance crítica. Não escolha sozinho.

- **Spring Data JPA**: schema evolui com a feature, relações naturais (1-N, N-N), produtividade (`findByEmailAndStatus`), migrations Flyway.
- **jOOQ**: queries complexas (CTEs, window functions, full-text), performance crítica, DBA revisa SQL, type-safety compile-time no SQL.

> Nunca `JdbcTemplate` para o que JPA resolve bem nem para o que jOOQ resolve melhor.

## Project Layout

```
project/
├── src/main/java/com/eveo/<service>/
│   ├── controller/     # @RestController — delega ao service
│   ├── service/        # {Entity}Service (interface) + {Entity}ServiceImpl
│   ├── repository/     # JpaRepository interfaces
│   ├── model/          # JPA @Entity
│   ├── dto/            # Records: {Entity}CreateRequest/UpdateRequest/Response
│   ├── mapper/         # MapStruct — model ↔ dto (sem lógica de negócio)
│   ├── config/         # SecurityConfig, OpenApiConfig
│   └── exception/      # domain exceptions + @ControllerAdvice
├── src/main/resources/
│   ├── application.yml + application-{dev,staging,prod}.yml
│   └── db/migration/   # Flyway V001__*.sql
├── src/test/java/...   # controller/ service/ integration/
├── docker/             # Dockerfile multi-stage + docker-compose.yml
├── pom.xml (ou build.gradle), Makefile, README.md
```

**Regras de pacotes invioláveis:**
- `controller/` → `service/`, `dto/` (nunca `repository/` ou `model/`)
- `service/` → `repository/`, `dto/`, `model/` (nunca `controller/`)
- `repository/` → `model/` (nunca `service/` ou `controller/`)
- `mapper/` converte `model/` ↔ `dto/` — sem lógica de negócio
- `exception/` é transversal (`@ControllerAdvice`)
- Imports cíclicos: unidirecional para dentro, sempre

## Padrões Obrigatórios (resumo)

- **Naming**: `PascalCase` classes/records; `camelCase` métodos/vars; `UPPER_SNAKE` constantes; `kebab-case` URLs (`/api/v1/user-profiles`); packages minúsculos sem underscore.
- **Service**: interface + impl sempre. Constructor injection via `@RequiredArgsConstructor` — nunca `@Autowired` em campo. Retorna DTO, nunca Entity.
- **DTOs**: sempre Records. Request com Bean Validation; Response sem validação. Nunca expor Entity.
- **Repository**: estende `JpaRepository<Entity, IdType>`. Queries derivadas p/ simples; `@Query` p/ JPQL complexo.
- **Exceptions**: domain exceptions em `exception/`; HTTP mapping no `@ControllerAdvice`, não no service; log com contexto.
- **Logging**: SLF4J JSON. Níveis: `debug` (dev), `info` (negócio), `warn` (degradação), `error` (falha). Nunca PII/tokens/senhas.

> Snippets completos por camada (bootstrap, entity, mapper, service, controller, exception handler, testes, Dockerfile) em `reference/core.md`.

## Error Response: RFC 7807 (ProblemDetail)

Para APIs novas, prefira o `ProblemDetail` nativo do Spring 6 (RFC 7807) como contrato de erro — é interoperável e padronizado. `ErrorResponse` custom continua válido em serviços legados; **não misture os dois no mesmo serviço**.

```java
@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(NotFoundError.class)
    public ProblemDetail handleNotFound(NotFoundError ex) {
        var pd = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
        pd.setTitle("Recurso não encontrado");
        return pd;
    }
}
```

`application.yml` de produção: `server.error.include-stacktrace: never`, `spring.jpa.open-in-view: false`, actuator com probes (`management.endpoint.health.probes.enabled: true`).

## Security (Built-in, não separado)

- Input validation: Bean Validation em todo DTO de entrada (`@Valid`).
- SQL injection: 100% parameterizado via JPA/named queries. Zero concatenação.
- Secrets: Spring Cloud Config ou env vars (`spring.config.import=vault://`). Zero hardcoded.
- CORS: origins explícitas — nunca `*` em prod.
- Rate limiting: Bucket4j ou Resilience4j RateLimiter.
- Auth: Spring Security filter chain — JWT (`nimbus-jose-jwt`) ou OAuth2 Resource Server, `SessionCreationPolicy.STATELESS`.
- Password: `BCryptPasswordEncoder` — nunca MD5/SHA1/plaintext.
- Headers: Spring Security (HSTS, CSP, X-Content-Type-Options, X-Frame-Options).
- Dependencies: OWASP Dependency-Check no CI.

## Anti-padrões Críticos

- ❌ `@Autowired` em campo → constructor injection
- ❌ `catch (Exception e)` genérico ou vazio → capturar específico, wrap com contexto
- ❌ `@Transactional` em método privado ou self-invocation (`this.metodo()`) → proxy Spring é ignorado
- ❌ N+1 com lazy loading → `JOIN FETCH` ou `@EntityGraph`
- ❌ Estado mutável em bean singleton → race condition com Virtual Threads
- ❌ `Optional.get()` sem checar → `orElseThrow(NotFoundError::new)`
- ❌ Expor `@Entity` na API → sempre DTO/record
- ❌ Lógica de negócio no controller → delegar ao service
- ❌ Comparar String com `==` → `.equals()` (literal primeiro) ou enum
- ❌ `System.out.println` / `e.printStackTrace()` → SLF4J

> Cada anti-padrão com o "por quê" e correção em `reference/core.md` (seção Anti-patterns).

## Workflow Agentic

1. **Escopo** — serviço novo ou existente? JPA ou jOOQ? Qual DB? Falta info crítica → pergunte uma vez.
2. **Planejar arquivos** (ordem de dependência): Entity → Migration → Repository → Service Interface → Service Impl → DTO/Record → Mapper → Controller → Exception Handler → Test.
3. **Gerar completo** — imports, annotations, validation, error handling, logs. Não esqueleto.
4. **Testar** — JUnit + Mockito (service); MockMvc (controller); Testcontainers (repository).
5. **Apresentar diff** — arquivos criados/editados + decisões (ex: "usei jOOQ pq há window functions").

## Checklist

- [ ] Records p/ todos os DTOs; constructor injection (zero `@Autowired` field)
- [ ] `@ControllerAdvice` com handler global (ProblemDetail p/ APIs novas)
- [ ] Bean Validation em request DTOs (`@Valid`)
- [ ] Erros com contexto — sem `catch (Exception e)` vazio
- [ ] SLF4J, sem `System.out`; sem dados sensíveis em log
- [ ] Testes: caminhos críticos + integração Testcontainers
- [ ] Flyway numeradas e descritivas; `open-in-view: false`
- [ ] Docker multi-stage (builder → JRE 21); profiles dev/staging/prod
- [ ] Imports cíclicos? (controller → service → repository → model)

## Quando Perguntar

Antes de codar: JPA ou jOOQ? Banco (Postgres/MySQL)? Auth (JWT/OAuth2/Session/API Key)? Cache (Redis/Spring Cache)? Monolito modular ou microsserviços? Java < 21?
Depois da 1ª versão: refinar algum ponto reversível barato?

## Referências (sob demanda — progressive disclosure)

- `reference/core.md` — Catálogo de snippets canônicos por camada + anti-patterns detalhados. **Leia antes de gerar código.**
- `reference/stack.md` — Versões, `application.yml`, plugins de build, lint. Ao criar projeto novo.
- `reference/workflow.md` — Scaffold de projeto novo e feature nova.
- `reference/spring-web.md`, `reference/spring-data.md`, `reference/spring-security.md`, `reference/mapstruct.md`, `reference/flyway.md`, `reference/testing.md` — por lib específica.

## Cross-references

- `security-expert` — auth, secrets, TLS, threat modeling aprofundado.

## Segurança (Baseline Compartilhado)

Regras universais em `reference/security-baseline.md`. Aqui só ameaças específicas de Java/Spring.

> **Atenção**: a EVEO tem stack definida. Execute-a com excelência, não a reinvente. Cada PR seu entra em produção.
