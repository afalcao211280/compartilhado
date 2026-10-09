# ADR-002: Java/Spring Boot — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: A EVEO opera microsserviços Java/Spring Boot para APIs REST e integrações enterprise. Era necessário formalizar a stack canônica, versões mínimas, padrões arquiteturais e anti-padrões para garantir consistência entre times, simplificar onboarding e reduzir decisões repetitivas em projetos Java.

## Decisão

Adotar Java 21+ com Spring Boot 3.4+ como stack canônica EVEO 2026, Clean Architecture (Controller → Service → Repository → Entity), project layout padronizado, e Spring Data JPA como ORM padrão (com jOOQ como alternativa para queries complexas). A escolha entre Spring Data JPA e jOOQ é uma decisão que **deve ser perguntada ao usuário** quando relevante.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| Linguagem | Java | 21+ | 17, 11 | Records, pattern matching, virtual threads |
| Framework | Spring Boot | 3.4+ | Quarkus, Micronaut | Ecossistema maduro, adotado na EVEO |
| Web | Spring Web (MVC) | 6.1+ | WebFlux | Simplicidade, virtual threads para concorrência |
| API docs | springdoc-openapi | v2.8+ | Swagger 2 (legacy) | OpenAPI 3.1, Spring Boot 3 nativo |
| Data | Spring Data JPA | 3.4+ | jOOQ (ver decisão abaixo) | Abstração produtiva, `findBy*` convenções |
| Security | Spring Security | 6+ | Auth0 custom | Filter chain, OAuth2, JWT |
| Cloud | Spring Cloud | 2024.x | — | Config, discovery, circuit breaker para microservices |
| Mapping | MapStruct | 1.5+ | ModelMapper | Zero reflexão, compile-time, typesafe |
| Validation | Bean Validation (hibernate-validator) | 8.x | manual | `@Valid`, `@NotNull`, `@Size` |
| Logging | SLF4J + Logback (logstash-logback) | — | Log4j2 | Structured logging JSON em prod |
| Migrations | Flyway | 10.x | Liquibase | SQL puro, versionado, convensão `V001__` |
| HTTP Client | RestClient (Spring 6.1+) | — | RestTemplate (deprecated), WebClient | API moderna, non-blocking friendly |
| Circuit Breaker | Resilience4j | 2.x | Hystrix (deprecated) | Timelimiter, retry, bulkhead |
| Cache | Spring Cache + Caffeine | — | Redis (quando distribuído) | Local first; Redis quando cache-aside é necessário |
| Tasks | Spring Async + Virtual Threads | — | CompletableFuture raw | Virtual threads em Java 21+ simplifica concorrência |
| Queue | Spring AMQP (RabbitMQ) | 3.x | Kafka (para streaming) | Pub/sub, work queues, RPC |
| Streaming | Spring Kafka | 3.x | — | Event streaming, alto throughput |
| NoSQL (MongoDB) | Spring Data MongoDB | 4.x | — | Quando documento é a unidade natural |
| NoSQL (Elasticsearch) | Spring Data Elasticsearch | 5.x | — | Busca texto, agregações |
| PDF | iText 7 + PDFBox | 7.x | Apache POI (xls) | Geração e manipulação de PDF |
| Tracing | Micrometer + OpenTelemetry | 1.27+ | — | Vendor-agnostic, exporter OTLP |
| Métricas | Micrometer + Prometheus | — | Dropwizard | Endpoint `/actuator/prometheus` |
| Testes unit | JUnit 5 + Mockito | 5.10+ | TestNG | Padrão de indústria, Spring Boot nativo |
| Testes asserts | AssertJ | 3.25+ | Hamcrest | Fluent API, legível |
| Testes integração | Testcontainers | 1.19+ | Docker Compose manual | Postgres, Redis, RabbitMQ reais |
| Testes API | MockMvc + `@WebMvcTest` | — | REST Assured | Controllers isolados, Spring context leve |
| Linter | SpotBugs + Checkstyle | — | PMD | CI pipeline |
| Security scan | OWASP Dependency-Check | — | Snyk (pago) | CI pipeline |
| Quality | SonarQube | — | — | Quality gates, debt analysis |
| Container | Docker multi-stage (GraalVM optional) | — | Jib | Produção, slim runtime |

## Decisão Arquitetural: JPA vs jOOQ

**Perguntar ao usuário quando houver queries complexas ou performance crítica.**

### Use Spring Data JPA quando:
- Schema evolui com a feature, relações são naturais (1-N, N-N)
- Quer produtividade: `findByEmailAndStatus` sem escrever SQL
- Time prefere abstração sobre controle fino
- Migrations gerenciadas por Flyway

### Use jOOQ quando:
- Queries complexas: CTEs, window functions, full-text search
- Performance crítica — precisa otimizar SQL específico
- Time tem DBA e quer controle total do SQL gerado
- Relatórios e agregações complexas

## Padrões Obrigatórios

### Clean Architecture
- **Controller** (`@RestController`) → **Service** (interface + `@Service` impl) → **Repository** (`JpaRepository`) → **Entity** (JPA `@Entity`)
- Controller: HTTP concerns apenas, delega para Service
- Service: lógica de negócio, orquestra repositories
- Repository: acesso a dados via Spring Data JPA
- Entity: modelo persistente, nunca exposto em controllers

### Naming
- `PascalCase` para classes, interfaces, records
- `camelCase` para métodos, variáveis, parâmetros
- `UPPER_SNAKE` para constantes
- `kebab-case` para URLs: `/api/v1/user-profiles`
- Packages: minúsculas, sem underscore: `com.eveo.userservice`
- DTOs: `{Entity}CreateRequest`, `{Entity}UpdateRequest`, `{Entity}Response`
- Services: `{Entity}Service` (interface), `{Entity}ServiceImpl` (implementação)

### Service Layer
- Interface + implementação para toda Service
- `@Transactional(readOnly = true)` como default na classe
- `@Transactional` (write) apenas em métodos que modificam
- Nunca expor Entity no controller — sempre DTO/Record

### DTOs (Records)
- Java 21+ Records para todos os DTOs
- `UserCreateRequest`, `UserUpdateRequest`, `UserResponse`
- Bean Validation em request DTOs: `@NotBlank`, `@Email`, `@Size`
- Nunca usar Lombok `@Data` em entidades JPA (problemas com `hashCode`/`equals`)

### Repository
- Estender `JpaRepository<Entity, Long>`
- Query methods: `findByEmailAndStatus`
- `@Query` para queries customizadas quandoDerivation não basta
- Nunca ser invocado diretamente pelo controller

### Exception Handling
- `@ControllerAdvice` com `GlobalExceptionHandler`
- Exceptions customizadas: `NotFoundException`, `BusinessException`, `ValidationException`
- Erros com contexto — sem `catch (Exception e)` vazio
- Response padronizado: `{ "code": "NOT_FOUND", "message": "..." }`

### Logging
- SLF4J (`@Slf4j` do Lombok) — nunca `System.out`
- Structured logging JSON em produção via `logstash-logback-encoder`
- Never log dados sensíveis (senhas, tokens, PII)

### Security (Built-in)
- Spring Security 6 com filter chain
- JWT/OAuth2 como mecanismos de auth
- CORS configurado explicitamente — nunca `*` em prod
- OWASP Dependency-Check no CI
- Input validation via Bean Validation em todos os endpoints

## Estrutura de Projeto

```
project/
├── src/main/java/com/eveo/<service>/
│   ├── controller/           # @RestController + @RequestMapping
│   │   └── UserController.java
│   ├── service/              # Interface + Impl
│   │   ├── UserService.java
│   │   └── UserServiceImpl.java
│   ├── repository/           # Spring Data JPA interfaces
│   │   └── UserRepository.java
│   ├── model/                # JPA Entities
│   │   └── User.java
│   ├── dto/                  # Records: request/response
│   │   ├── UserCreateRequest.java
│   │   ├── UserUpdateRequest.java
│   │   └── UserResponse.java
│   ├── mapper/               # MapStruct mappers
│   │   └── UserMapper.java
│   ├── config/               # @Configuration classes
│   │   ├── SecurityConfig.java
│   │   └── OpenApiConfig.java
│   └── exception/            # Custom exceptions + @ControllerAdvice
│       ├── AppError.java
│       ├── NotFoundError.java
│       └── GlobalExceptionHandler.java
├── src/main/resources/
│   ├── application.yml       # config por profile
│   ├── application-dev.yml
│   ├── application-staging.yml
│   ├── application-prod.yml
│   └── db/migration/         # Flyway: V001__create_users.sql
├── src/test/java/com/eveo/<service>/
│   ├── controller/
│   │   └── UserControllerTest.java
│   ├── service/
│   │   └── UserServiceTest.java
│   └── integration/
│       └── UserRepositoryIntegrationTest.java
├── docker/
│   ├── Dockerfile            # multi-stage
│   └── docker-compose.yml
├── pom.xml (ou build.gradle)
├── Makefile
└── README.md
```

### Regras de Pacotes Invioláveis
- `controller/` importa de `service/`, `dto/` — nunca de `repository/` ou `model/`
- `service/` implementa interface. Importa de `repository/`, `dto/`, `model/`
- `repository/` importa de `model/` — nunca de `service/` ou `controller/`
- `mapper/` converte `model/` ↔ `dto/` — não contém lógica de negócio
- `exception/` é transversal — `GlobalExceptionHandler` em `@ControllerAdvice`

## Anti-padrões

- **Campos públicos em classes** — `private` com getters/setters ou Lombok `@Getter`/`@Setter`
- **`@Data` em entidades JPA** — problemas com `hashCode`/`equals`. Usar `@Getter`/`@Setter`
- **`@Autowired` field injection** — usar constructor injection sempre
- **Transactions desnecessárias em reads** — `@Transactional(readOnly = true)` para queries
- **Expor Entity no controller** — sempre DTO/Record
- **Lógica de negócio no controller** — delegar para Service
- **`System.out.println`** — usar SLF4J
- **Secrets hardcoded** — usar variáveis de ambiente e Spring Config
- **`catch (Exception e)` vazio** — sempre logar e/ou rethrow com contexto
- **Imports cíclicos** — controller → service → repository → model, sempre unidirecional
- **Testes de implementação** — testar behavior, não internals
- **Flyway migrations com `V` sem descrição** — sempre `V001__create_users.sql`

## Consequências

### Positivas
- Java 21+ com Records e Virtual Threads reduz boilerplate e simplifica concorrência
- Spring Boot 3.4+ com Spring Security 6 oferece filter chain moderna e segura
- MapStruct gera código em compile-time, zero reflexão em runtime
- Testcontainers garante testes de integração com bancos reais
- Flyway com SQL versionado é auditável e DBA-friendly
- Ecossistema Spring maduro: auto-config, starters, actuator, observabilidade

### Negativas
- Spring Boot tem startup time mais lento que Go/NestJS (mitigado com GraalVM ou virtual threads)
- JPA opera com overhead para queries simples (mitigado com DTO projections)
- Stack maior que micronaut/quarkus — justified pela maturidade e adesão da EVEO
- MapStruct требует annotation processor — build time levemente maior

## Referências

- Skill: `skills/Backend/java-expert/SKILL.md`
- Padronização EVEO: documentação interna Java
- Spring Boot Reference: https://docs.spring.io/spring-boot/docs/current/reference/
- jOOQ: https://www.jooq.org/