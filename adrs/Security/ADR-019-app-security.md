# ADR-019: Segurança de Aplicação — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Segurança em microserviços não é opcional — é requisito fundamental. Sem padronização de autenticação, autorização, validação de entrada e proteção de dados, cada serviço implementa segurança de forma inconsistente, criando brechas e inconsistências.

## Decisão

Adotar OAuth2/OIDC como padrão de autenticação, JWT short-lived com refresh tokens, RBAC+ABAC para autorização, OPA para microserviços, validação de entrada em todas as camadas, HTTPS obrigatório, security headers, mTLS entre serviços e gestão centralizada de secrets.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| Autenticação | OAuth2/OIDC | 2.0/OIDC Core | SAML, JWT manual | Padrão moderno, SSO nativo, ampla adoção |
| Identity Provider | Auth0 / Keycloak / Cognito | - | Okta, Azure AD B2C | Auth0: SaaS completo; Keycloak: open-source; Cognito: AWS-native |
| Token | JWT | RS256 | Opaque tokens | JWT: stateless, verificável; RS256: chave pública verificável |
| Autorização | RBAC + ABAC | - | RBAC only | ABAC para regras dinâmicas ( contexto, atributos) |
| Policy Engine (Microserviços) | OPA (Open Policy Agent) | 0.62+ | Casbin, ABAC custom | Decouple policy da aplicação, Rego expressive |
| Input Validation | Zod / class-validator / Bean Validation | 3.23+ / 0.14+ / 3.x | Joi, Pydantic | Zod: TS runtime; class-validator: NestJS; Bean Validation: Java |
| API Gateway | Kong / Azure API Management | 3.6+ / - | Traefik, NGINX | Rate limiting, WAF, auth, logging centralizado |
| Secrets Management | HashiCorp Vault / Azure Key Vault | 1.16+ / - | AWS Secrets Manager | Vault: multi-cloud; Key Vault: Azure-native |
| mTLS | Istio / Linkerd | 1.20+ / 2.14+ | Consul Connect | Service mesh gerencia certificados automaticamente |
| Password Hashing | bcrypt / argon2 | - | SHA-256, MD5 | bcrypt: provado; argon2: resistente a GPU/ASIC |

## Padrões Obrigatórios

### Autenticação

- OAuth2 + OIDC para toda autenticação (nunca auth custom)
- Identity Provider centralizado (Auth0, Keycloak ou Cognito)
- JWT short-lived (15 min access token) + refresh token (7 dias)
- RS256 para assinatura (nunca HS256 em microserviços)
- Token relay entre serviços (não re-auth no backend)
- Logout com revogação de refresh token

### Autorização

- RBAC como base (roles definidas por serviço)
- ABAC para regras dinâmicas (contexto, atributos, tempo)
- OPA como policy engine para microserviços (policy-as-code)
- Permission check por endpoint (decorator/middleware)
- Never trust client-side authorization checks

### Segurança de API

- HTTPS obrigatório (TLS 1.3+, nunca 1.0/1.1)
- Security headers: `X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security`, `Content-Security-Policy`, `X-XSS-Protection`
- Rate limiting por IP e por usuário
- CORS configurado explicitamente (nunca `*` em produção)
- Input validation em todas as camadas (handler → service → repository)
- Schema-based validation (Zod/class-validator/Bean Validation)
- Output encoding para prevenir XSS

### Proteção de Dados

- Encryption at rest: AES-256 (cloud-managed ou customer-managed keys)
- Encryption in transit: TLS 1.3+
- PII masking em logs (nunca logar dados sensíveis)
- Password hashing: bcrypt/argon2 (nunca SHA simples ou MD5)
- Key rotation automático
- HSM para key management crítico

### Segurança de Microserviços

- mTLS entre serviços (service mesh ou sidecar)
- API Gateway como entrypoint único (rate limit, auth, WAF)
- Zero trust network
- Network policies default-deny (Kubernetes)
- Secrets: Vault ou cloud-native (Key Vault/Secrets Manager)
- Circuit breaker para falhas em cascata (gobreaker/resilience4j)

## Estrutura de Projeto / Configuração

```
middleware/
├── auth/
│   ├── jwt-validator.ts       # ou .go, .java
│   ├── rbac-guard.ts
│   └── opa-client.ts
├── validation/
│   ├── schemas/                # Zod/class-validator schemas
│   └── sanitize.ts
└── security/
    ├── headers.ts
    ├── rate-limiter.ts
    └── cors.ts

policies/                       # OPA policies
├── authz/
│   ├── allow.rego
│   └── rbac.rego
└── data/
    └── roles.json
```

## Anti-padrões

- Autenticação custom (sempre usar OAuth2/OIDC)
- JWT com HS256 em microserviços (usar RS256)
- Autorização apenas no frontend
- CORS `*` em produção
- HTTP para comunicação entre serviços
- Logar PII (senhas, tokens, CPF, dados bancários)
- Senhas em plaintext ou hashing fraco (SHA, MD5)
- Hardcoded secrets no código ou variáveis de ambiente sem Vault
- Validação de entrada apenas no frontend
- Desabilitar certificate validation (`insecure: true`)
- Service mesh sem mTLS

## Consequências

**Positivas:**
- Autenticação centralizada e consistente
- Autorização flexível (RBAC + ABAC via OPA)
- Zero trust entre microserviços
- Validação de entrada em camadas — defense in depth
- Observabilidade de security events via logs mascarados
- Compliance com LGPD/GDPR (PII masking, encryption)

**Negativas:**
- Overhead de latência (mTLS, OPA, Gateway)
- Complexidade operacional (Identity Provider, Vault, Service Mesh)
- Curva de aprendizado para Rego (OPA)
- JWT invalidation é eventual (short TTL mitiga)

**Riscos:**
- Single point of failure no Identity Provider — mitigar com HA
- Key rotation pode causar downtime se mal planejada — usar versões de chave
- OPA pode se tornar bottleneck se policies sao muito complexas — cache e monitorar latência

## Referências

- `skills/Security/security-expert/SKILL.md`
- OWASP API Security: https://owasp.org/www-project-web-security-testing-guide/
- OPA: https://www.openpolicyagent.org/
- Auth0: https://auth0.com/
- Keycloak: https://www.keycloak.org/
- ADR-016 (Docker) — security context de container
- ADR-017 (Kubernetes) — RBAC, NetworkPolicies, PodSecurity
- ADR-020 (Pentest) — validação das medidas de segurança
- ADR-022 (CI/CD) — SAST/SCA no pipeline