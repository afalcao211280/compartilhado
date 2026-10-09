# 1. Visão Geral da Arquitetura

## 1.1 Escopo do Projeto

Plataforma e-commerce SaaS de alto desempenho com integração de AI agents, utilizando arquitetura de microsserviços, micro frontends, e tecnologias state-of-the-art para 2025/2026.

## 1.2 Decisões Arquiteturais Chave

| ADR | Decisão | Justificativa |
|-----|---------|---------------|
| ADR-001 | Monorepo com Go + Python | Co-location de código relacionado, shared tooling |
| ADR-002 | Go para Backend/BFF | Performance, type safety, concurrency nativa |
| ADR-003 | Python para AI | Ecossistema maduro, LangChain/CrewAI |
| ADR-004 | CrewAI Flows + LangGraph | Híbrido: CrewAI para orchestration, LangGraph para critical paths |
| ADR-005 | pgvector | Simplicidade, integra com Postgres |
| ADR-006 | KEDA para scaling | Scaling baseado em eventos (filas) |

## 1.3 Mapa de Domínios

```
┌─────────────────────────────────────────────────────────────┐
│                     DOMAIN MAP                               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │    AUTH     │    │   PRODUCT   │    │    ORDER    │    │
│  │  - Login    │    │  - Catalog  │    │  - Create   │    │
│  │  - SSO      │    │  - Search   │    │  - Status   │    │
│  │  - RBAC     │    │  - Inventory│    │  - Cancel   │    │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │  PAYMENT    │    │   SHIPPING  │    │    CHAT     │    │
│  │  - Stripe   │    │  - Quote    │    │  - Agents   │    │
│  │  - Mercado  │    │  - Track    │    │  - Guardrails│   │
│  │  - Refund   │    │  - Label    │    │  - RAG      │    │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 1.4 Data Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                     REQUEST FLOW                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. Client → API Gateway (WAF + Rate Limit)                       │
│                    ↓                                              │
│  2. Auth Middleware (JWT Validation)                              │
│                    ↓                                              │
│  3. BFF Service (Aggregation + Caching)                          │
│                    ↓                                              │
│  4. gRPC → Backend Microservice                                  │
│                    ↓                                              │
│  5. Database / Cache                                             │
│                                                                   │
│                     RESPONSE FLOW                                 │
│                                                                   │
│  6. Database → Service → BFF → Client                           │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## 1.5 Technology Matrix

| Service | Language | Framework | Database | Cache | Port |
|---------|----------|-----------|---------|-------|------|
| auth-service | Go | Gin | PostgreSQL | Redis | 8080 |
| product-service | Go | Gin | PostgreSQL | Redis | 8081 |
| order-service | Go | Gin | PostgreSQL | Redis | 8082 |
| payment-service | Go | Gin | PostgreSQL | - | 8083 |
| shipping-service | Go | Gin | PostgreSQL | Redis | 8084 |
| bff-auth | Go | Fiber | - | Redis | 3001 |
| bff-catalog | Go | Fiber | - | Redis | 3002 |
| bff-checkout | Go | Fiber | - | Redis | 3003 |
| bff-chat | Go | Fiber | - | Redis | 3004 |
| ai-orchestrator | Python | CrewAI | pgvector | Redis | 8000 |
| ai-agents | Python | LangGraph | pgvector | - | 8001 |

## 1.6 Non-Functional Requirements

| Requirement | Target | Measurement |
|-------------|--------|-------------|
| Availability | 99.9% | Uptime monitoring |
| Latency P95 | < 200ms | APM tracing |
| Concurrent Users | 10,000+ | Load testing |
| Data Retention | 7 years | Backup policy |
| Recovery Time | < 1 hour | DR testing |
| Recovery Point | < 1 hour | Backup frequency |

## 1.7 Constraints

- **Budget**: Cloud costs optimized with auto-scaling
- **Timeline**: 9 months to production
- **Team**: 8-10 developers, multi-disciplinary
- **Compliance**: LGPD (Brazil), PCI-DSS (payments)