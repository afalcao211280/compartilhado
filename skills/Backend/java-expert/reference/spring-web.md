# Spring Web — Controllers, REST, Exception Handling

Leia `core.md` secoes Controller e Exception para detalhes.

## Controller

```java
@RestController
@RequestMapping("/api/v1/users")
public class UserController {
  private final UserService userService;

  @PostMapping
  public ResponseEntity<UserResponse> create(@Valid @RequestBody UserCreateRequest request) {
    return ResponseEntity.status(HttpStatus.CREATED).body(userService.create(request));
  }

  @GetMapping("/{id}")
  public ResponseEntity<UserResponse> findById(@PathVariable UUID id) {
    return ResponseEntity.ok(userService.findById(id));
  }
}
```

## Exception Handler

```java
@ControllerAdvice
public class GlobalExceptionHandler {
  @ExceptionHandler(NotFoundError.class)
  public ResponseEntity<ErrorResponse> handleNotFound(NotFoundError ex) {
    return ResponseEntity.status(HttpStatus.NOT_FOUND).body(new ErrorResponse("NOT_FOUND", ex.getMessage()));
  }
}
```

## Regras
- Sempre retornar DTO/Record
- @Valid em request bodies
- HTTP status apropriado
- ExceptionHandler global
