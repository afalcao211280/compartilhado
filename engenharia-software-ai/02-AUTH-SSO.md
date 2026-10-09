# 2. Sistema de Autenticação (Auth Service)

## 2.1 Overview

Microsserviço Go responsável por toda autenticação e autorização da plataforma.

## 2.2 Stack

- **Language**: Go 1.22+
- **Framework**: Gin
- **Database**: PostgreSQL
- **Cache**: Redis (sessions)
- **Protocol**: gRPC + REST

## 2.3 Fluxo OAuth2/OIDC

```
┌─────────────────────────────────────────────────────────────────┐
│                 AUTHORIZATION CODE FLOW + PKCE                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Client → GET /auth/oauth/{provider}                         │
│     ← Redirect to Provider (Google/Facebook/etc)                 │
│                                                                  │
│  2. Provider → Callback /auth/oauth/{provider}/callback          │
│     with ?code=AUTH_CODE&state=STATE                            │
│                                                                  │
│  3. Server exchanges code for tokens (PKCE verified)             │
│                                                                  │
│  4. Server creates/updates local user                          │
│                                                                  │
│  5. Server issues JWT pair:                                    │
│     - Access Token (15 min)                                     │
│     - Refresh Token (7 days)                                    │
│                                                                  │
│  6. Client stores tokens, uses access for API calls            │
│                                                                  │
│  7. On expiry, client → POST /auth/refresh                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 2.4 Endpoints

```yaml
REST Endpoints:
  POST   /auth/register              # Local registration
  POST   /auth/login                 # Local login
  POST   /auth/logout                # Invalidate session
  POST   /auth/refresh               # Refresh tokens
  GET    /auth/oauth/{provider}      # Initiate OAuth
  GET    /auth/oauth/{provider}/cb   # OAuth callback
  POST   /auth/password/reset       # Request reset
  POST   /auth/password/change       # Change password
  GET    /auth/profile               # Get profile
  PUT    /auth/profile               # Update profile
  POST   /auth/mfa/setup             # Setup MFA
  POST   /auth/mfa/verify            # Verify MFA

gRPC Methods:
  ValidateToken(ctx, token) → (user_id, claims)
  RefreshToken(ctx, refresh_token) → (new_access_token, new_refresh_token)
  GetProfile(ctx, user_id) → (Profile)
```

## 2.5 JWT Structure

```json
{
  "header": {
    "alg": "RS256",
    "typ": "JWT",
    "kid": "key-id-2025"
  },
  "payload": {
    "sub": "user-uuid",
    "email": "user@example.com",
    "roles": ["customer"],
    "permissions": ["profile:read", "orders:create"],
    "iat": 1704067200,
    "exp": 1704068100,
    "iss": "auth-service",
    "aud": ["api-gateway"]
  }
}
```

## 2.6 Database Schema

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255), -- NULL for OAuth-only
    name VARCHAR(255),
    avatar_url TEXT,
    status VARCHAR(20) DEFAULT 'active',
    mfa_enabled BOOLEAN DEFAULT FALSE,
    mfa_secret VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE oauth_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(50) NOT NULL, -- google, facebook, apple
    provider_user_id VARCHAR(255) NOT NULL,
    access_token TEXT,
    refresh_token TEXT,
    token_expires_at TIMESTAMP,
    UNIQUE(provider, provider_user_id)
);

CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT
);

CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT
);

CREATE TABLE user_roles (
    user_id UUID REFERENCES users(id),
    role_id UUID REFERENCES roles(id),
    PRIMARY KEY (user_id, role_id)
);

CREATE TABLE role_permissions (
    role_id UUID REFERENCES roles(id),
    permission_id UUID REFERENCES permissions(id),
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    refresh_token VARCHAR(512) NOT NULL,
    user_agent TEXT,
    ip_address INET,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_oauth_provider ON oauth_accounts(provider, provider_user_id);
CREATE INDEX idx_sessions_user ON sessions(user_id);
CREATE INDEX idx_sessions_expires ON sessions(expires_at);
```

## 2.7 RBAC Configuration

```yaml
roles:
  admin:
    description: "Full system access"
    permissions:
      - users:*
      - products:*
      - orders:*
      - payments:*
      - settings:*
      - admin:*

  manager:
    description: "Business management"
    permissions:
      - products:read,create,update
      - products:delete
      - orders:read,update
      - customers:read
      - reports:read

  customer:
    description: "End customer"
    permissions:
      - profile:read,update
      - orders:create,read
      - cart:*
      - wishlist:*
      - addresses:*

  agent:
    description: "Support agent"
    permissions:
      - tickets:*
      - orders:read
      - customers:read
      - chat:*

  guest:
    description: "Unauthenticated user"
    permissions:
      - products:read
      - cart:read
```

## 2.8 Security Measures

```yaml
security:
  password_policy:
    min_length: 8
    require_uppercase: true
    require_lowercase: true
    require_numbers: true
    require_special: true
    hash_algorithm: argon2id
    max_attempts: 5
    lockout_duration: 15m

  rate_limiting:
    login: 5/minute/IP
    register: 3/minute/IP
    password_reset: 3/minute/email
    api: 100/minute/user

  session:
    access_token_ttl: 15m
    refresh_token_ttl: 7d
    max_sessions_per_user: 5
    rotation_on_use: true
```

## 2.9 Providers Configuration

```yaml
providers:
  google:
    client_id_env: GOOGLE_CLIENT_ID
    client_secret_env: GOOGLE_CLIENT_SECRET
    scopes:
      - openid
      - profile
      - email
    enabled: true

  facebook:
    client_id_env: FACEBOOK_CLIENT_ID
    client_secret_env: FACEBOOK_CLIENT_SECRET
    scopes:
      - email
      - public_profile
    enabled: true

  apple:
    client_id_env: APPLE_CLIENT_ID
    team_id_env: APPLE_TEAM_ID
    key_id_env: APPLE_KEY_ID
    scopes:
      - email
      - name
    enabled: false
```

## 2.10 Implementation Structure

```
auth-service/
├── cmd/
│   └── server/
│       └── main.go
├── internal/
│   ├── domain/
│   │   ├── entity/
│   │   │   ├── user.go
│   │   │   ├── session.go
│   │   │   └── oauth.go
│   │   ├── repository/
│   │   │   ├── user_repository.go
│   │   │   ├── session_repository.go
│   │   │   └── oauth_repository.go
│   │   └── service/
│   │       ├── auth_service.go
│   │       ├── oauth_service.go
│   │       └── mfa_service.go
│   ├── handler/
│   │   ├── auth_handler.go
│   │   ├── oauth_handler.go
│   │   └── profile_handler.go
│   ├── middleware/
│   │   ├── auth.go
│   │   ├── ratelimit.go
│   │   └── logging.go
│   ├── config/
│   │   └── config.go
│   └── pkg/
│       ├── jwt/
│       ├── argon2/
│       └── errors/
├── migrations/
├── proto/
├── api/
│   └── openapi.yaml
└── Dockerfile
```

## 2.11 Testing Strategy

```go
// Test patterns
func TestAuthService_Login(t *testing.T) {
    // Arrange
    repo := &mockUserRepository{}
    service := NewAuthService(repo, nil)
    
    // Act
    result, err := service.Login(context.Background(), LoginRequest{
        Email:    "test@example.com",
        Password: "password123",
    })
    
    // Assert
    require.NoError(t, err)
    require.NotEmpty(t, result.AccessToken)
    require.NotEmpty(t, result.RefreshToken)
}

func TestAuthService_Login_InvalidCredentials(t *testing.T) {
    // Test wrong password
    // Test non-existent user
    // Test locked account
}

func TestJWT_ValidateToken(t *testing.T) {
    // Test valid token
    // Test expired token
    // Test invalid signature
    // Test wrong issuer
}
```