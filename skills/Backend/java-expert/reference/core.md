# Java Expert — Padrões de Código

Catálogo de snippets canônicos EVEO por camada. Leia a seção do que vai gerar **antes** de codar — são o ponto de partida pronto pra produção, não exemplos educativos.

## Índice

1. [Spring Boot — Bootstrap Completo](#1-spring-boot--bootstrap-completo)
2. [Entity (JPA) com Records Complementares](#2-entity-jpa-com-records-complementares)
3. [DTOs como Records (Java 21+)](#3-dtos-como-records-java-21)
4. [MapStruct Mapper](#4-mapstruct-mapper)
5. [Repository (Spring Data JPA)](#5-repository-spring-data-jpa)
6. [Service Layer](#6-service-layer)
7. [Controller](#7-controller)
8. [Global Exception Handler](#8-global-exception-handler)
9. [Resilience4j — Circuit Breaker](#9-resilience4j--circuit-breaker)
10. [JUnit 5 + Mockito — Testes de Service](#10-junit-5--mockito--testes-de-service)
11. [Testcontainers — Integration Test](#11-testcontainers--integration-test)
12. [Dockerfile Multi-stage](#12-dockerfile-multi-stage)
13. [Anti-patterns](#anti-patterns)

## 1. Spring Boot — Bootstrap Completo

```java
// src/main/java/com/eveo/service/ServiceApplication.java
@SpringBootApplication
public class ServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(ServiceApplication.class, args);
    }
}
```

```yaml
# src/main/resources/application.yml
spring:
  threads:
    virtual:
      enabled: true   # Virtual Threads — Spring Boot 3.2+
  jpa:
    open-in-view: false
    hibernate:
      ddl-auto: validate
```

---

## 2. Entity (JPA) com Records Complementares

```java
// src/main/java/com/eveo/service/model/User.java
@Entity
@Table(name = "users")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EqualsAndHashCode(of = "id")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(unique = true, nullable = false, length = 255)
    private String email;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 50)
    private UserRole role = UserRole.READER;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // Factory method — não usar new User() diretamente
    public static User create(String email, String name, String passwordHash) {
        var user = new User();
        user.email = email;
        user.name = name;
        user.passwordHash = passwordHash;
        return user;
    }

    @PreUpdate
    public void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }
}
```

---

## 3. DTOs como Records (Java 21+)

```java
// src/main/java/com/eveo/service/dto/UserCreateRequest.java
public record UserCreateRequest(
    @NotNull @Email String email,
    @NotBlank @Size(min = 2, max = 100) String name,
    @NotBlank @Size(min = 8, max = 128) String password,
    @NotNull UserRole role
) {}

// src/main/java/com/eveo/service/dto/UserResponse.java
public record UserResponse(
    UUID id,
    String email,
    String name,
    UserRole role,
    LocalDateTime createdAt
) {}

// src/main/java/com/eveo/service/dto/PagedResponse.java
public record PagedResponse<T>(
    List<T> content,
    int page,
    int size,
    long totalElements,
    int totalPages
) {
    public static <T> PagedResponse<T> from(Page<T> page) {
        return new PagedResponse<>(
            page.getContent(),
            page.getNumber(),
            page.getSize(),
            page.getTotalElements(),
            page.getTotalPages()
        );
    }
}
```

---

## 4. MapStruct Mapper

```java
// src/main/java/com/eveo/service/mapper/UserMapper.java
@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.ERROR)
public interface UserMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "passwordHash", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    User toEntity(UserCreateRequest request);

    UserResponse toResponse(User user);

    List<UserResponse> toResponseList(List<User> users);
}
```

---

## 5. Repository (Spring Data JPA)

```java
// src/main/java/com/eveo/service/repository/UserRepository.java
@Repository
public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);

    @Query("SELECT u FROM User u WHERE u.role = :role AND u.createdAt >= :since")
    Page<User> findActiveByRole(
        @Param("role") UserRole role,
        @Param("since") LocalDateTime since,
        Pageable pageable
    );
}
```

---

## 6. Service Layer

```java
// src/main/java/com/eveo/service/service/UserServiceImpl.java
@Service
@RequiredArgsConstructor
@Slf4j
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;

    @Override
    @Transactional
    public UserResponse create(UserCreateRequest request) {
        log.info("criando usuário email={}", request.email());

        if (userRepository.existsByEmail(request.email())) {
            throw new ConflictError("Usuário", request.email());
        }

        var user = User.create(
            request.email(),
            request.name(),
            passwordEncoder.encode(request.password())
        );
        var saved = userRepository.save(user);
        log.info("usuário criado id={}", saved.getId());
        return userMapper.toResponse(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public UserResponse findById(UUID id) {
        return userRepository.findById(id)
            .map(userMapper::toResponse)
            .orElseThrow(() -> new NotFoundError("Usuário", id.toString()));
    }

    @Override
    @Transactional(readOnly = true)
    public PagedResponse<UserResponse> findAll(Pageable pageable) {
        var page = userRepository.findAll(pageable).map(userMapper::toResponse);
        return PagedResponse.from(page);
    }
}
```

---

## 7. Controller

```java
// src/main/java/com/eveo/service/controller/UserController.java
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
@Tag(name = "Users", description = "Operações de usuário")
@Slf4j
public class UserController {

    private final UserService userService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Criar usuário")
    public UserResponse create(@Valid @RequestBody UserCreateRequest request) {
        return userService.create(request);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Buscar usuário por ID")
    public UserResponse findById(@PathVariable UUID id) {
        return userService.findById(id);
    }

    @GetMapping
    @Operation(summary = "Listar usuários paginado")
    public PagedResponse<UserResponse> findAll(Pageable pageable) {
        return userService.findAll(pageable);
    }
}
```

---

## 8. Global Exception Handler

```java
// src/main/java/com/eveo/service/exception/GlobalExceptionHandler.java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(NotFoundError.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ErrorResponse handleNotFound(NotFoundError ex) {
        log.warn("recurso não encontrado: {}", ex.getMessage());
        return new ErrorResponse("NOT_FOUND", ex.getMessage());
    }

    @ExceptionHandler(ConflictError.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public ErrorResponse handleConflict(ConflictError ex) {
        log.warn("conflito: {}", ex.getMessage());
        return new ErrorResponse("CONFLICT", ex.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ValidationErrorResponse handleValidation(MethodArgumentNotValidException ex) {
        var errors = ex.getFieldErrors().stream()
            .map(f -> new FieldError(f.getField(), f.getDefaultMessage()))
            .toList();
        log.warn("erro de validação: {} campos", errors.size());
        return new ValidationErrorResponse("VALIDATION_ERROR", errors);
    }

    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public ErrorResponse handleGeneric(Exception ex) {
        log.error("erro inesperado", ex);
        return new ErrorResponse("INTERNAL_ERROR", "Erro interno do servidor");
    }
}

// ErrorResponse como record
public record ErrorResponse(String code, String message) {}
public record FieldError(String field, String message) {}
public record ValidationErrorResponse(String code, List<FieldError> errors) {}
```

---

## 9. Resilience4j — Circuit Breaker

```java
// src/main/java/com/eveo/service/client/PaymentClient.java
@Component
@RequiredArgsConstructor
@Slf4j
public class PaymentClient {

    private final RestClient restClient;

    @CircuitBreaker(name = "paymentService", fallbackMethod = "fallbackCharge")
    @Retry(name = "paymentService")
    public PaymentResponse charge(ChargeRequest request) {
        log.info("cobrando via serviço externo order_id={}", request.orderId());
        return restClient.post()
            .uri("/v1/charges")
            .body(request)
            .retrieve()
            .body(PaymentResponse.class);
    }

    private PaymentResponse fallbackCharge(ChargeRequest request, Exception ex) {
        log.warn("circuit breaker ativo para pagamento order_id={}", request.orderId(), ex);
        throw new ServiceUnavailableError("Serviço de pagamento temporariamente indisponível");
    }
}
```

```yaml
# application.yml
resilience4j:
  circuitbreaker:
    instances:
      paymentService:
        sliding-window-size: 10
        failure-rate-threshold: 50
        wait-duration-in-open-state: 30s
        permitted-number-of-calls-in-half-open-state: 3
  retry:
    instances:
      paymentService:
        max-attempts: 3
        wait-duration: 1s
        exponential-backoff-multiplier: 2
```

---

## 10. JUnit 5 + Mockito — Testes de Service

```java
// src/test/java/com/eveo/service/service/UserServiceTest.java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private UserMapper userMapper;

    @Mock
    private PasswordEncoder passwordEncoder;

    @InjectMocks
    private UserServiceImpl userService;

    @Test
    @DisplayName("deve criar usuário com sucesso quando email não existe")
    void create_success() {
        // Arrange
        var request = new UserCreateRequest("joao@eveo.com", "João", "senha123", UserRole.READER);
        var user = User.create(request.email(), request.name(), "hash");
        var expected = new UserResponse(UUID.randomUUID(), "joao@eveo.com", "João", UserRole.READER, LocalDateTime.now());

        when(userRepository.existsByEmail(request.email())).thenReturn(false);
        when(passwordEncoder.encode(request.password())).thenReturn("hash");
        when(userRepository.save(any(User.class))).thenReturn(user);
        when(userMapper.toResponse(user)).thenReturn(expected);

        // Act
        var result = userService.create(request);

        // Assert
        assertThat(result.email()).isEqualTo("joao@eveo.com");
        verify(userRepository).save(any(User.class));
    }

    @Test
    @DisplayName("deve lançar ConflictError quando email já existe")
    void create_emailDuplicate_throwsConflict() {
        var request = new UserCreateRequest("joao@eveo.com", "João", "senha123", UserRole.READER);
        when(userRepository.existsByEmail(request.email())).thenReturn(true);

        assertThatThrownBy(() -> userService.create(request))
            .isInstanceOf(ConflictError.class)
            .hasMessageContaining("joao@eveo.com");
    }
}
```

---

## 11. Testcontainers — Integration Test

```java
// src/test/java/com/eveo/service/integration/UserRepositoryIT.java
@SpringBootTest
@Testcontainers
@ActiveProfiles("test")
class UserRepositoryIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
        .withDatabaseName("test_db")
        .withUsername("test")
        .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private UserRepository userRepository;

    @Test
    @Transactional
    void save_and_findByEmail() {
        var user = User.create("test@eveo.com", "Test User", "hash");
        userRepository.save(user);

        var found = userRepository.findByEmail("test@eveo.com");
        assertThat(found).isPresent().get()
            .extracting(User::getName)
            .isEqualTo("Test User");
    }
}
```

---

## 12. Dockerfile Multi-stage

```dockerfile
# docker/Dockerfile
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -q
COPY src ./src
RUN mvn package -DskipTests -q

FROM eclipse-temurin:21-jre-jammy AS runtime
WORKDIR /app
RUN addgroup --system app && adduser --system --ingroup app app
COPY --from=builder /app/target/*.jar app.jar
USER app
EXPOSE 8080
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]
```

---

## Anti-patterns

### ❌ Capturar Exception ou Throwable genérico
**Problema:** O desenvolvedor escreve `catch (Exception e)` ou `catch (Throwable e)` para tratar todos os erros de uma vez.
**Por quê evitar:** Engole exceções de sistema como `OutOfMemoryError`, `InterruptedException` e erros de lógica distintos, tornando debugging impossível e ocultando falhas reais.
**Solução:**
```java
// Errado
try {
    userService.create(request);
} catch (Exception e) {
    log.error("erro", e);
}

// Correto
try {
    userService.create(request);
} catch (ConflictError e) {
    log.warn("conflito de email: {}", e.getMessage());
    throw e;
} catch (DataAccessException e) {
    log.error("falha de banco de dados", e);
    throw new ServiceUnavailableError("Banco indisponível");
}
```

---

### ❌ @Transactional em método privado
**Problema:** O desenvolvedor anota um método `private` com `@Transactional` esperando que a transação seja gerenciada pelo Spring.
**Por quê evitar:** O Spring AOP age via proxy: métodos privados não são interceptados pelo proxy, portanto a anotação é silenciosamente ignorada e nenhuma transação é criada.
**Solução:**
```java
// Errado — @Transactional não terá efeito
@Service
public class OrderService {
    @Transactional
    private void persistOrder(Order order) { ... }
}

// Correto — método public no bean gerenciado
@Service
public class OrderService {
    @Transactional
    public void persistOrder(Order order) { ... }
}
```

---

### ❌ Problema N+1 com lazy loading JPA
**Problema:** O desenvolvedor carrega uma lista de entidades e depois acessa associações lazy dentro de um loop, disparando uma query por item.
**Por quê evitar:** Com 1000 pedidos, serão executadas 1001 queries ao banco. Destrói a performance e pode esgotar o pool de conexões.
**Solução:**
```java
// Errado — N+1: uma query por Order para buscar items
List<Order> orders = orderRepository.findAll();
orders.forEach(o -> o.getItems().size()); // lazy load em loop

// Correto — JOIN FETCH numa única query
@Query("SELECT o FROM Order o LEFT JOIN FETCH o.items WHERE o.status = :status")
List<Order> findWithItemsByStatus(@Param("status") OrderStatus status);

// Alternativa com @EntityGraph
@EntityGraph(attributePaths = {"items", "customer"})
List<Order> findAll();
```

---

### ❌ Estado mutável em beans Spring (singleton)
**Problema:** O desenvolvedor declara campos de instância mutáveis (contadores, listas, mapas) em um `@Service` ou `@Component`.
**Por quê evitar:** Beans Spring são singletons por padrão. Com Virtual Threads ou requisições concorrentes, o estado compartilhado sofre race conditions sem sincronização.
**Solução:**
```java
// Errado — campo mutável em singleton
@Service
public class ReportService {
    private List<String> cache = new ArrayList<>(); // não thread-safe
}

// Correto — use variáveis locais ou estruturas thread-safe
@Service
public class ReportService {
    private final ConcurrentHashMap<String, Report> cache = new ConcurrentHashMap<>();
    // ou injete um bean de escopo @RequestScope para estado por-requisição
}
```

---

### ❌ Optional.get() sem verificação de presença
**Problema:** O desenvolvedor chama `optional.get()` diretamente após uma busca no repositório sem checar `isPresent()`.
**Por quê evitar:** Lança `NoSuchElementException` em runtime se o valor estiver ausente, causando 500 em vez de 404 no cliente.
**Solução:**
```java
// Errado
User user = userRepository.findByEmail(email).get();

// Correto — use orElseThrow com exceção de negócio
User user = userRepository.findByEmail(email)
    .orElseThrow(() -> new NotFoundError("Usuário", email));

// Ou mapeie diretamente
return userRepository.findByEmail(email)
    .map(userMapper::toResponse)
    .orElseThrow(() -> new NotFoundError("Usuário", email));
```

---

### ❌ Expor entidades JPA diretamente na API REST
**Problema:** O controller retorna objetos `@Entity` diretamente como resposta JSON, sem DTO intermediário.
**Por quê evitar:** Causa vazamento de dados sensíveis (passwordHash, campos internos), referências circulares que estourem a serialização JSON, e acopla o contrato da API ao modelo de banco.
**Solução:**
```java
// Errado — expõe passwordHash, lazy associations podem causar LazyInitializationException
@GetMapping("/{id}")
public User findById(@PathVariable UUID id) {
    return userRepository.findById(id).orElseThrow(...);
}

// Correto — use um DTO/record como contrato de saída
@GetMapping("/{id}")
public UserResponse findById(@PathVariable UUID id) {
    return userService.findById(id); // retorna UserResponse record
}
```

---

### ❌ Auto-invocação de método @Transactional no mesmo bean
**Problema:** Um método do bean chama outro método `@Transactional` do mesmo bean diretamente (`this.metodo()`).
**Por quê evitar:** A chamada ignora o proxy Spring AOP, portanto a nova anotação `@Transactional` (com propagação diferente, por exemplo `REQUIRES_NEW`) não é aplicada — a transação original continua sendo usada.
**Solução:**
```java
// Errado — self-invocation: @Transactional(propagation = REQUIRES_NEW) é ignorado
@Service
public class AuditService {
    public void process() {
        this.saveAudit(); // chama via 'this', bypassa proxy
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void saveAudit() { ... }
}

// Correto — extraia para outro bean ou injete o próprio bean via ApplicationContext
@Service
@RequiredArgsConstructor
public class AuditService {
    private final AuditPersistenceService auditPersistenceService;

    public void process() {
        auditPersistenceService.saveAudit(); // chama via proxy
    }
}
```

---

### ❌ Não fechar recursos (streams, connections)
**Problema:** O desenvolvedor abre `InputStream`, `Connection` ou `PreparedStatement` e esquece de fechá-los em caso de exceção.
**Por quê evitar:** Vaza recursos, esgota pool de conexões e degrada a aplicação em produção com carga.
**Solução:**
```java
// Errado — recurso não fechado se ocorrer exceção
InputStream is = new FileInputStream(file);
process(is);
is.close();

// Correto — try-with-resources garante fechamento automático
try (InputStream is = new FileInputStream(file)) {
    process(is);
}

// Com múltiplos recursos
try (Connection conn = dataSource.getConnection();
     PreparedStatement ps = conn.prepareStatement(sql)) {
    ps.executeQuery();
}
```

---

### ❌ Comparar Strings com ==
**Problema:** O desenvolvedor usa `==` para comparar o conteúdo de duas `String` em Java.
**Por quê evitar:** `==` compara referências de objeto, não conteúdo. Pode retornar `false` mesmo para strings com o mesmo texto se forem instâncias distintas no heap.
**Solução:**
```java
// Errado
if (user.getRole() == "ADMIN") { ... }   // sempre false fora do pool

// Correto
if ("ADMIN".equals(user.getRole())) { ... }  // literal primeiro evita NPE
// ou, preferível com enums:
if (user.getRole() == UserRole.ADMIN) { ... } // enum usa == corretamente
```

---

### ❌ Lógica de negócio no Controller
**Problema:** O desenvolvedor coloca validações de regra de negócio, queries ao banco ou cálculos diretamente no método do `@RestController`.
**Por quê evitar:** Quebra a separação de responsabilidades, impede reutilização, dificulta testes unitários e torna o código impossível de manter conforme cresce.
**Solução:**
```java
// Errado — regras de negócio no controller
@PostMapping("/orders")
public OrderResponse create(@Valid @RequestBody OrderRequest req) {
    if (req.getTotal().compareTo(BigDecimal.ZERO) <= 0) throw new BadRequestException("...");
    var inventory = inventoryRepository.findBySku(req.getSku());
    if (inventory.getQuantity() < req.getQuantity()) throw new ConflictException("...");
    // ... mais lógica
}

// Correto — controller delega tudo ao service
@PostMapping("/orders")
@ResponseStatus(HttpStatus.CREATED)
public OrderResponse create(@Valid @RequestBody OrderRequest req) {
    return orderService.create(req);
}
```
