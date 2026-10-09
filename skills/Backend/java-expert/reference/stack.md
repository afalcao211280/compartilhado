# Java Expert — Stack Canônica

## Java 21+ LTS — Versão Canônica EVEO

| Categoria | Lib | Versão | Link | Notas |
|-----------|-----|--------|------|-------|
| **Framework** | | | | |
| Core | Spring Boot | 3.3+ | https://spring.io/projects/spring-boot | Sempre. Toda API/serviço |
| Web | Spring Web | 6.1+ | https://docs.spring.io/spring-framework | REST via `@RestController` |
| Data | Spring Data JPA | 3.3+ | https://spring.io/projects/spring-data-jpa | ORM padrão. Flyway para migrations |
| Security | Spring Security | 6.3+ | https://spring.io/projects/spring-security | JWT/OAuth2 Resource Server |
| Cloud | Spring Cloud | 2023.0+ | https://spring.io/projects/spring-cloud | Config Server, Discovery, Circuit Breaker |
| **ORM** | | | | |
| JPA (padrão) | Hibernate | 6.4+ | https://hibernate.org | Via Spring Data JPA |
| Type-safe SQL | jOOQ | 3.19+ | https://www.jooq.org | Para queries complexas (CTEs, window functions) |
| Migrations | Flyway | 10.x | https://flywaydb.org | Versionamento de schema |
| **Mapeamento** | | | | |
| Entity ↔ DTO | MapStruct | 1.5+ | https://mapstruct.org | Compile-time, zero reflexão |
| Boilerplate | Lombok | 1.18+ | https://projectlombok.org | `@RequiredArgsConstructor`, `@Slf4j`, `@Builder` |
| **Logging** | | | | |
| API | SLF4J | 2.x | https://www.slf4j.org | Interface. Implementação: Logback |
| Implementação | Logback | 1.5+ | https://logback.qos.ch | Com encoder JSON logstash |
| JSON encoder | logstash-logback-encoder | 7.4+ | https://github.com/logfellow/logstash-logback-encoder | Structured logging JSON |
| **HTTP Client** | | | | |
| Client moderno | Spring RestClient | 6.1+ | https://docs.spring.io/spring-framework | Substitui RestTemplate (fluent API) |
| Client reativo | WebClient | 6.1+ | https://docs.spring.io/spring-framework | Para projetos reactive |
| **Resiliência** | | | | |
| Circuit Breaker | Resilience4j | 2.2+ | https://resilience4j.readme.io | CB + Rate Limiter + Bulkhead + Retry |
| **Cache** | | | | |
| Abstração | Spring Cache | 6.x | https://docs.spring.io/spring-framework | `@Cacheable`, `@CacheEvict` |
| Store | Redis (Lettuce) | 6.x | https://lettuce.io | Via `spring-boot-starter-data-redis` |
| **Mensageria** | | | | |
| RabbitMQ | Spring AMQP | 3.x | https://spring.io/projects/spring-amqp | Pub/sub, work queues |
| Kafka | Spring Kafka | 3.2+ | https://spring.io/projects/spring-kafka | Event streaming |
| **Observabilidade** | | | | |
| Métricas | Micrometer + Prometheus | 1.13+ | https://micrometer.io | `management.prometheus.metrics.export.enabled=true` |
| Tracing | OpenTelemetry Java Agent | 2.x | https://opentelemetry.io/docs/languages/java/ | Agente JAR ou SDK |
| Health | Spring Actuator | 3.x | https://docs.spring.io/spring-boot | `/actuator/health`, `/actuator/metrics` |
| API Docs | Springdoc OpenAPI | 2.5+ | https://springdoc.org | Swagger UI auto-gerado |
| **Testes** | | | | |
| Unit | JUnit 5 | 5.11+ | https://junit.org/junit5/ | `@Test`, `@ParameterizedTest`, `@ExtendWith` |
| Mock | Mockito | 5.x | https://mockito.org | `@Mock`, `@InjectMocks`, `verify()` |
| Controller | MockMvc | (Spring) | — | `@WebMvcTest` + `MockMvc` |
| Integração | Testcontainers | 1.20+ | https://testcontainers.com | Postgres, Redis, Kafka reais |
| Assertions | AssertJ | 3.x | https://assertj.github.io | Mais legível que JUnit assertions |
| Load | k6 | 0.50+ | https://k6.io | Scripts JS na pasta `load-tests/` |
| **Build** | | | | |
| Build tool | Maven (preferido) | 3.9+ | https://maven.apache.org | `pom.xml`. Alternativa: Gradle |
| Plugin Lint | SpotBugs | 4.8+ | https://spotbugs.github.io | Bug patterns |
| Plugin Lint | PMD | 7.x | https://pmd.github.io | Code style violations |
| Plugin Lint | Checkstyle | 10.x | https://checkstyle.org | Google/EVEO style guide |
| Security | OWASP Dep-Check | 9.x | https://jeremylong.github.io/DependencyCheck/ | CVEs no CI |
| Container | Docker multi-stage + JRE | — | — | Builder Gradle/Maven → JRE 21 runtime |

## application.yml — Template Canônico

```yaml
spring:
  application:
    name: eveo-service
  datasource:
    url: ${DATABASE_URL}
    driver-class-name: org.postgresql.Driver
  jpa:
    hibernate:
      ddl-auto: validate      # nunca create-drop em prod; Flyway gerencia
    open-in-view: false       # desabilitar OSIV — evita N+1 acidentais
  flyway:
    enabled: true
    locations: classpath:db/migration

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  metrics:
    export:
      prometheus:
        enabled: true

logging:
  level:
    root: INFO
    com.eveo: DEBUG
```
