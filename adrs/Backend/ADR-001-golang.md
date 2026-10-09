# ADR-001: Golang — Decisões de Stack e Padrões

**Status**: Aceito (revisado 2026-06-30)
**Data**: 2026-05-17

> **Revisão 2026-06-30** — DI manual e sqlc+tern **fixados** como padrão único (ratifica `golang-expert`, em uso desde a v1.0.0). Google Wire e Ent **removidos** do padrão EVEO. Ref.: `skills-optimizadas/Backend/golang-expert`.
**Contexto**: A EVEO (maior IaaS do Brasil) opera stack heterogênea com microsserviços Go para APIs HTTP, workers de fila e CLIs internas. Era necessário formalizar a stack canônica, versões mínimas, padrões arquiteturais e anti-padrões para garantir consistência entre times e reduzir decisões repetitivas. A versão de referência é `golang.md` (2026-05-07), executável via skill.

## Decisão

Adotar Go 1.23+ como versão mínima com stack canônica EVEO 2026, Clean Architecture (handler → service → repository → model), project layout seguindo `golang-standards/project-layout`, e logging estruturado via `log/slog`. O acesso a dados é **fixo: sqlc + tern** (SQL puro type-safe + migrations explícitas, PostgreSQL). Ent não é utilizado.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| Linguagem | Go | 1.23+ | — | Performance, concorrência nativa, binário estático |
| Logging | `log/slog` (stdlib) | Go 1.21+ | zap, zerolog | Stdlib, JSON em prod, text em dev, zero dependência |
| Web framework | Gin | v1.9+ | Echo, Chi, stdlib | Performance, middleware maduro, adotado na EVEO |
| API docs / OpenAPI | Huma | v2 | Swag, Fiber | Type-safe, gera OpenAPI 3.1, adapter `humagin` para Gin |
| HTTP client | Resty | v2.10+ | stdlib net/http | Builder pattern, retries, timeouts, middleware |
| Circuit breaker | gobreaker | v2.5+ | resilience-go, cb | Simples, testado, integra com Resty wrapper |
| Acesso a dados | sqlc + tern | sqlc v1.27+, tern latest | Ent, GORM | SQL puro type-safe, DBA-friendly, migrations explícitas (**PADRÃO FIXO**) |
| Migrations | tern | latest | goose, golang-migrate | SQL `up`/`down` explícito, PostgreSQL |
| NoSQL (MongoDB) | mongo-go-driver | v1.14+ | mongox, mgo | Driver oficial, suporte a transações |
| Busca (Elasticsearch) | go-elasticsearch | v8.12+ | olivere/elastic | Client oficial ES v8, tipos fortes |
| Cache / Locks | go-redis | v9.4+ | rueidis | Client Redis maduro, suporte a cluster |
| Fila clássica | amqp091-go + go-rabbitmq | latest | machinery, asynq | Protocolo AMQP, pub/sub, work queues, RPC |
| Streaming | franz-go | v2.1+ | confluent-kafka-go, sarama | Client Go nativo, sem CGO, alto desempenho |
| Object storage | minio-go | v7.0.70+ | aws-sdk-go-v2 S3 | S3-compatible (MinIO, AWS S3, GCS) |
| PDF | `html/template` + Gotenberg | v7 | wkhtmltopdf, gofpdf | Renderização HTML→PDF via HTTP API |
| Tracing | OpenTelemetry (otel) | v1.27+ | OpenTracing (depracated) | Standard de indústria, exporter OTLP gRPC |
| Métricas | Prometheus (client_golang) | v1.19+ | expvars | Endpoint `/metrics`, histogramas, contadores |
| DI | Manual (constructors `New*`) | — | Wire, dig, fx | Explícito, zero geração/reflexão, em `internal/server/server.go` (**FIXO**) |
| Testes unitários | testify | v1.9+ | stdlib apenas | `assert`, `mock`, suite — padrão EVEO |
| Mocks | mockery | v2+ | moq, counterfeiter | Configurado em `.mockery.yaml`, saída em `**/mocks/` |
| Testes integração | testcontainers-go | v0.30+ | dockertest | Postgres, Redis, RabbitMQ reais em container |
| Load test | k6 | v0.50+ | vegeta, wrk | Scripts JS, thresholds, CI integrado |
| Linter | golangci-lint + revive | v1.57+ | golint (deprecated) | Aggregator, `.golangci.yml` na raiz |

## Acesso a Dados: sqlc + tern (Fixo)

**Padrão único — não perguntar, não usar Ent.** (Revisão 2026-06-30)

- SQL puro versionado em `.sql` — DBA-friendly, code review claro, SQL exato visível e otimizável.
- Migrations explícitas com `up`/`down` (tern). PostgreSQL.
- type-safe via sqlc; suporta CTEs, window functions, full-text search.

> Ent foi removido do padrão EVEO. Caso raríssimo de legado com Ent: tratar como exceção documentada, nunca como nova escolha.

## Padrões Obrigatórios

### Clean Architecture
- `handler` → `service` → `repository` → `model` (domain)
- **handler**: Gin handlers + Huma routes, HTTP concerns only
- **service**: lógica de negócio, orquestra repos/clients
- **repository**: acesso a dados (DB, cache, storage)
- **domain/model**: entidades de domínio + DTOs, zero dependência externa

### Naming
- `camelCase` para variáveis e funções não-exportadas
- `PascalCase` para tipos, funções exportadas, constantes públicas
- **Não usar** snake_case em código Go (só em tags JSON/BSON e SQL)
- Acrônimos em CAPS: `userID`, `httpClient`, `apiKey`
- Pacotes: minúsculas, curtos, sem underscores: `user`, `httpclient`, `kafkaproducer`
- Arquivos: minúsculas com underscores se ajuda legibilidade: `user_repository.go`

### Interfaces
- Interfaces moram no **consumidor**, não no provedor
- Retornar structs, aceitar interfaces
- Interface vazia `any` → proibida fora de codec/reflect

### Error Handling
- `panic` apenas para erros irrecuperáveis na inicialização
- Em runtime, sempre retorne erro
- Wrap com `%w` e contexto operacional: `fmt.Errorf("criar usuário %q: %w", email, err)`
- Sentinel errors em `pkg/errors`
- Checagem com `errors.Is` / `errors.As`

### Context
- `context.Context` é o **primeiro parâmetro** em toda função de I/O
- Nunca usar `context.Background()` em handlers — use `c.Request.Context()`

### Logging com slog
- JSON em produção, text em desenvolvimento
- Logs via contexto com `slog.Logger`
- Nunca `fmt.Println` ou `log.Println`

### Concorrência
- Goroutines SEMPRE com `context.Context` e `sync.WaitGroup`
- Channels para comunicação; mutex para estado compartilhado
- Sem goroutines soltas — usar `errgroup`

### Dependency Injection
- Constructors `New*` sempre
- **DI manual fixo** em `internal/server/server.go` (Revisão 2026-06-30)
- Google Wire removido do padrão EVEO — não usar

## Estrutura de Projeto

```
project/
├── cmd/
│   └── <service-name>/
│       └── main.go        # entrypoint mínimo — parse de flags e server.New()
├── internal/              # código privado — não importável de fora
│   ├── config/            # Load(), structs com tags `env:""`
│   ├── handler/           # Gin handlers + Huma routes
│   ├── middleware/        # auth, correlation ID, logging, tracing, metrics
│   ├── service/           # lógica de negócio — orquestra repos/clients
│   ├── repository/        # acesso a dados (DB, cache, storage)
│   ├── domain/            # entidades de domínio + validações
│   └── model/             # DTOs de entrada/saída, structs de banco
├── pkg/                   # código público — importável por outros módulos
│   ├── logger/            # wrapper de slog (New, From, With)
│   ├── errors/            # ErrNotFound, ErrInvalidInput, NotFoundError, etc.
│   ├── tracer/            # otel init + helpers
│   ├── metrics/           # Prometheus collectors + middleware
│   ├── http/              # Resty wrapper
│   ├── circuitbreaker/    # gobreaker wrapper
│   ├── validator/         # validação de structs
│   └── crypto/            # hash, encrypt
├── api/                   # contratos: openapi.yaml, *.proto
├── migrations/            # tern (SQL up/down)
├── test/                  # integração + e2e + fixtures
├── scripts/               # build.sh, generate-proto.sh, etc.
├── docker/                # Dockerfiles, docker-compose
├── k8s/                   # manifests ou Helm chart
├── .golangci.yml
├── .revive.toml
├── .mockery.yaml
├── sqlc.yaml              # sqlc config
├── go.mod / go.sum
├── Makefile
└── README.md
```

### Regras de Importação Invioláveis
- `cmd/` nunca é importado por ninguém. Só importa `internal/` e `pkg/`.
- `internal/` é privado ao módulo. Pode importar `pkg/` mas nunca o contrário.
- `pkg/` é público. **Zero dependências de `internal/`**.
- `domain/` é o núcleo — não importa de handler, repository ou clientes externos.

## Anti-padrões

- **Variáveis globais de estado** — usar injeção de dependência
- **Ignorar erros** (`result, _ := doThing()`) — sempre tratar e wrap com contexto
- **Mutex global** — mutex no struct, nunca pacote-level
- **Goroutines sem controle** — sempre com `context.Context` e `errgroup`
- **`panic` em runtime** — apenas para erros irrecuperáveis na inicialização
- **`fmt.Println` / `log.Println`** — usar `slog`
- **Interface `any` (/`interface{}`)** — proibida fora de codec/reflect
- **DDD excessivo** — Go não é Java. Entidades em `domain/`, services em `service/`, sem agregados/valores/raízes
- **Imports cíclicos** — handler → service → repo → domain, sempre unidirecional
- **Tags JSON/BSON em PascalCase** — sempre `snake_case`
- **Testes de implementação** — testar behavior, não internals

## Consequências

### Positivas
- Stack homogênea reduz curva de aprendizado e decision fatigue
- Binary estático simplifica deploy em Kubernetes
- sqlc + tern dá controle total sobre o SQL (DBA-friendly), com padrão único
- slog como stdlib elimina debate sobre biblioteca de log
- OpenTelemetry + Prometheus como standard de observabilidade
- DI manual: zero geração de código, dependências explícitas e rastreáveis

### Negativas
- Huma v2 ainda está em evolução — adapter Gin é necessário
- Stack maior que Go idiomático mínimo — justificado pela complexidade da infra EVEO
- DI manual exige disciplina em serviços grandes (muitos constructors em `server.go`)

## Referências

- Skill: `skills/Backend/golang-expert/SKILL.md`
- Referências internas: `references/stack-and-patterns.md`, `references/project-scaffold.md`, `references/sqlc-tern-workflow.md`
- Layout: `golang-standards/project-layout`
- Padronização EVEO: `golang.md` (versão 2026-05-07)