# Workflow — Scaffold e Geracao de Codigo

## Quando Usar

- Ao criar **projeto novo** Spring Boot
- Ao gerar **feature nova**

## Decisoes Iniciais

1. JPA ou jOOQ?
2. Banco: PostgreSQL / MySQL / MongoDB
3. Auth: JWT / OAuth2 / Session

## Scaffold de Projeto Novo

1. Spring Initializr ou `spring boot init`
2. `pom.xml` / `build.gradle`
3. `src/main/resources/application.yml`
4. `Application.java`
5. `config/SecurityConfig.java`
6. `exception/GlobalExceptionHandler.java`
7. Docker multi-stage

## Workflow de Feature Nova

```
Entity → Migration → Repository → Service Interface → Service Impl → DTO/Record → Mapper → Controller → Test
```

1. Entity JPA
2. Flyway migration
3. Repository interface
4. Service interface
5. Service implementation
6. DTO/Record
7. MapStruct mapper
8. Controller
9. Testes

## Checklist de Scaffold

- [ ] `mvn compile` compila
- [ ] `mvn test` passa
- [ ] Health endpoint funciona
- [ ] Docker build funciona
