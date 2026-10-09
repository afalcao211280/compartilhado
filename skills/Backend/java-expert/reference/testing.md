# JUnit 5 + Mockito — Testes

Leia `core.md` secao Testing para detalhes.

## Unit Test

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {
  @Mock UserRepository userRepository;
  @Mock UserMapper userMapper;
  @InjectMocks UserServiceImpl userService;

  @Test
  void shouldCreateUser() {
    // given, when, then
  }
}
```

## Integration Test

```java
@SpringBootTest
@Testcontainers
class UserRepositoryIntegrationTest {
  @Container
  static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");
}
```

## Regras
- JUnit 5 + Mockito para unit
- Testcontainers para integracao
- MockMvc para controllers
- Coverage >80%
