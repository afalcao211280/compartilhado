# Spring Data JPA — Repositories e Queries

Leia `core.md` secao Repository para detalhes.

## Repository

```java
@Repository
public interface UserRepository extends JpaRepository<User, UUID> {
  Optional<User> findByEmail(String email);
  boolean existsByEmail(String email);

  @EntityGraph(attributePaths = {"roles"})
  Optional<User> findWithRolesByEmail(String email);
}
```

## Regras
- Interface estende JpaRepository
- Queries derivadas para simples
- @Query para JPQL complexo
- Nunca retornar Entity do service
