# Spring Security — JWT, Filters, Auth

Leia `core.md` secao Security para detalhes.

## Configuracao

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {
  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http.csrf(csrf -> csrf.disable())
        .authorizeHttpRequests(auth -> auth
          .requestMatchers("/api/auth/**").permitAll()
          .anyRequest().authenticated()
        )
        .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()));
    return http.build();
  }
}
```

## Regras
- JWT via OAuth2 Resource Server
- CORS explicito
- Rate limiting (Bucket4j)
- Password: BCrypt
