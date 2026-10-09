# MapStruct — Entity ↔ DTO Mapping

Leia `core.md` secao Mapping para detalhes.

## Mapper

```java
@Mapper(componentModel = "spring")
public interface UserMapper {
  User toEntity(UserCreateRequest request);
  UserResponse toResponse(User user);
  List<UserResponse> toResponseList(List<User> users);
}
```

## Regras
- Compile-time mapping (zero reflexao)
- Interface com @Mapper
- Spring component model
