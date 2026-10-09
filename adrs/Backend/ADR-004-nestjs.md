# ADR-004: NestJS — Decisões de Stack e Padrões (Backend/BFF)

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: A EVEO utiliza NestJS como framework backend/BFF em TypeScript para APIs REST, microserviços e integração com o frontend Next.js. Era necessário formalizar a stack canônica, versões mínimas, padrões arquiteturais e anti-padrões para garantir consistência com o ecossistema EVEO (PostgreSQL, Redis, MongoDB, RabbitMQ). O NestJS funciona como BFF (Backend for Frontend) no contexto do monorepo Turborepo, servindo dados ao frontend Next.js via tRPC ou REST.

## Decisão

Adotar NestJS 10+ com TypeScript strict como stack canônica EVEO 2026 para backends/BFFs em Node.js. Clean Architecture (Controller → Service → Repository → Entity), class-validator + class-transformer para validação, e JWT + Passport para auth. A escolha entre TypeORM e Prisma é uma decisão arquitetural crítica que **deve ser perguntada ao usuário** — nunca assumida.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| Framework | NestJS | 10+ | Express raw, Fastify raw | DI, modules, guards, interceptors — enterprise-ready |
| Linguagem | TypeScript | 5.x (strict) | JavaScript | Type safety, DX, refactoring seguro |
| ORM (Opção A) | TypeORM | 0.3.x | Prisma (ver decisão abaixo) | Decorator-based, SQL controle, migrations artesanais |
| ORM (Opção B) | Prisma | 5.x+ | TypeORM (ver decisão abaixo) | Schema-first, type-safe, migrations automáticas |
| Validation | class-validator + class-transformer | latest | Zod (no NestJS context) | Decorators, `ValidationPipe` global integrado |
| Auth | @nestjs/jwt + @nestjs/passport | latest | custom middleware | JWT guards, strategies, integrado |
| API docs | @nestjs/swagger | latest | tRPC (para BFF) | OpenAPI 3.0 automático |
| Cache | @nestjs/cache-manager + Redis | latest | in-memory | Cache-aside distribuído |
| Queue | Bull / BullMQ | latest | RabbitMQ client direto | Job queues, retries, rate limiting |
| Redis | ioredis | 5.x | node-redis | Cache, locks, pub/sub |
| HTTP Client | fetch nativo (Node 18+) ou axios | — | got, undici | Simplicidade, sem dependência extra |
| Logging | NestJS Logger ou PinoLogger | — | winston | Integrado ao DI, structured |
| Tracing | OpenTelemetry | 1.27+ | — | Vendor-agnostic, exporter OTLP |
| Métricas | prom-client | latest | — | Endpoint `/metrics` |
| Testes unit | Jest | 29.x | Vitest (em avaliação) | Padrão NestJS, mocking integrado |
| Testes API | supertest | latest | — | HTTP integration tests |
| E2E | @nestjs/testing | — | — | Module-based test harness |
| Linting | ESLint + Prettier | latest | Biome (em avaliação) | Padrão da indústria |
| Container | Docker multi-stage | — | — | builder → node:20-alpine runtime |

## Decisão Arquitetural Crítica: TypeORM vs Prisma

**Esta é a primeira pergunta a fazer em qualquer projeto novo com banco relacional. Não escolher sozinho — confirmar com o usuário.**

### Use TypeORM quando:
- Precisa de mixin patterns, subqueries complexas, raw SQL frequente
- Time prefere decorator-based entities (estilo JPA/ActiveRecord)
- Quer migrations artesanais com controle total do SQL
- Projeto já usa TypeORM (não misture ORMs)

### Use Prisma quando:
- Quer type-safety máxima no query layer (Prisma Client gera tipos)
- Schema-first approach (arquivo `.prisma` como fonte da verdade)
- Migrations automáticas via `prisma migrate` são desejáveis
- Time prefere declarative schema over decorators
- Queries são CRUD padrão sem complexidade extrema

> **Nunca misture TypeORM e Prisma no mesmo projeto.** Escolha UM.

## Padrões Obrigatórios

### Clean Architecture
- **Controller** (`@Controller`) → **Service** (`@Injectable`) → **Repository** (`@Injectable`) → **Entity** (ORM)
- Controller: HTTP concerns, `@Body()`, `@Param()`, delega para Service
- Service: lógica de negócio, orquestra repositories
- Repository: acesso a dados via ORM — Service nunca toca ORM direto
- Entity: modelo persistente, nunca exposto em Controller

### Naming
- `kebab-case` para arquivos: `user-service.ts`, `create-user.dto.ts`
- `PascalCase` para classes, interfaces, types, enums: `UserService`, `UserResponse`
- `camelCase` para métodos, variáveis, propriedades: `findById`, `userRepository`
- `UPPER_SNAKE` para constantes: `MAX_RETRY_ATTEMPTS`
- Módulos: `{Feature}Module`
- DTOs: `Create{Feature}Dto`, `Update{Feature}Dto`, `{Feature}ResponseDto`

### Module Structure
```typescript
// user.module.ts
@Module({
  imports: [
    TypeOrmModule.forFeature([User]), // ou PrismaModule
    CacheModule.register({ ttl: 300 }),
  ],
  controllers: [UserController],
  providers: [UserService, UserRepository],
  exports: [UserService], // exporta apenas o que outros módulos precisam
})
export class UserModule {}
```
- Não criar God modules — um módulo por feature
- `exports` apenas o que outros módulos consomem (geralmente Service)
- Importar módulos, não services diretamente, quando houver dependência circular

### DTOs (Input/Output Separation)
- DTOs separados: `CreateUserDto`, `UpdateUserDto`, `UserResponseDto`
- `@ApiProperty()` em todos os DTOs de response para Swagger
- `class-validator` decorators: `@IsString()`, `@IsEmail()`, `@IsOptional()`
- Nunca usar Entity como DTO — sempre mapear

### Repository Pattern
```typescript
// user.repository.ts
@Injectable()
export class UserRepository {
  constructor(
    @InjectRepository(User) private readonly repo: Repository<User>,
  ) {}

  async findById(id: string): Promise<User | null> {
    return this.repo.findOne({ where: { id } });
  }
}
```
- Service nunca toca ORM diretamente — sempre via Repository
- Repository retorna Entity ou `null` — nunca levanta HTTP exception

### Controller
```typescript
// user.controller.ts
@Controller('users')
@ApiTags('Users')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(@Body() dto: CreateUserDto): Promise<UserResponseDto> {
    return this.userService.create(dto);
  }
}
```
- Thin controllers — lógica de negócio no Service
- Sempre tipar response com DTO

### Exception Handling
- NestJS built-in: `NotFoundException`, `BadRequestException`, `ForbiddenException`
- Domain exceptions customizadas: `BusinessException`, `ValidationException`
- `@ControllerAdvice` equivalente: `ExceptionFilter` global
- Erros com contexto — sem catch vazio
- Nunca `throw new Error('algo')` — usar domain exception

### Validation (Global Pipe)
```typescript
// main.ts
app.useGlobalPipes(
  new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  }),
);
```
- `whitelist: true` — strip propriedades não declaradas
- `forbidNonWhitelisted: true` — rejeita payload com campos extras
- `transform: true` — converte tipos automaticamente

### Config (Environment)
- `@nestjs/config` com `ConfigModule.forRoot()` — zero `process.env` direto
- `.env` para development, env vars para staging/prod
- Schema de validação com `class-validator` ou `Joi`
- Nunca secrets hardcoded

### Security (Built-in)
- Input validation: `class-validator` + `ValidationPipe` global com `whitelist: true` e `forbidNonWhitelisted: true`
- SQL injection: 100% parameterized via ORM. Zero SQL cru concatenado
- Secrets: `@nestjs/config` lendo de env vars. Zero hardcoded
- CORS: `app.enableCors({ origin: ['https://app.eveo.com'] })` — nunca `*` em prod
- Rate limiting: `@nestjs/throttler` configurado globalmente
- Auth: JWT guards (`@nestjs/jwt` + `@nestjs/passport`) — `@UseGuards(JwtAuthGuard)`
- Helmet: `app.use(helmet())` no `main.ts`
- DTO whitelist: impossível injetar campos extras no payload
- Dependencies: `npm audit` no CI — zero vulnerabilidades críticas

## Estrutura de Projeto

```
project/
├── src/
│   ├── main.ts                      # Bootstrap + global pipes/filters
│   ├── app.module.ts                 # Root module
│   ├── common/                       # Cross-cutting concerns
│   │   ├── guards/
│   │   │   └── jwt-auth.guard.ts
│   │   ├── interceptors/
│   │   │   ├── logging.interceptor.ts
│   │   │   └── transform.interceptor.ts
│   │   ├── filters/
│   │   │   └── all-exceptions.filter.ts
│   │   ├── decorators/
│   │   │   └── current-user.decorator.ts
│   │   └── pipes/
│   │       └── validation.pipe.ts
│   ├── config/
│   │   ├── config.module.ts
│   │   └── configuration.ts
│   ├── modules/
│   │   └── user/
│   │       ├── user.module.ts
│   │       ├── user.controller.ts
│   │       ├── user.service.ts
│   │       ├── user.repository.ts
│   │       ├── entities/
│   │       │   └── user.entity.ts      # TypeORM entity ou Prisma schema
│   │       ├── dto/
│   │       │   ├── create-user.dto.ts
│   │       │   ├── update-user.dto.ts
│   │       │   └── user-response.dto.ts
│   │       └── user.module.ts
│   └── prisma/                        # se Prisma
│       ├── schema.prisma
│       └── migrations/
├── test/
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── docker/
│   ├── Dockerfile                      # multi-stage
│   └── docker-compose.yml
├── nest-cli.json
├── tsconfig.json                      # strict: true
├── package.json
├── .eslintrc.js
├── .prettierrc
├── Makefile
└── README.md
```

### Regras de Importação Invioláveis
- `Controller` importa de `Service`, `DTO` — nunca de `Repository` ou `Entity`
- `Service` importa de `Repository`, `DTO`, `Entity` — nunca de `Controller`
- `Repository` importa de `Entity` — nunca de `Service` ou `Controller`
- `common/` é transversal — guards, interceptors, filters, decorators
- `config/` é isolado — `ConfigModule` importado onde necessário
- Imports cíclicos: `controller → service → repository → entity`, sempre unidirecional

## Anti-padrões

- **God modules** — um módulo por feature, nunca EverythingModule
- **Service tocando ORM diretamente** — sempre via Repository
- **Entity exposta no Controller** — sempre DTO de response
- **`process.env` direto** — usar `@nestjs/config` `ConfigService`
- **`console.log`** — usar NestJS `Logger` ou `PinoLogger`
- **Catch vazio** — sempre logar e/ou rethrow com contexto
- **`any` type** — TypeScript strict, zero `any`
- **Imports circulares** — `controller → service → repository → entity`
- **Lógica de negócio no Controller** — delegar para Service
- **Socket/Redis sem timeout** — sempre configurar timeouts e retries
- **Testes de implementação** — testar behavior, não internals
- **Misturar TypeORM e Prisma** — escolher UM ORM por projeto
- **`whitelist: false` no ValidationPipe** — sempre `true` + `forbidNonWhitelisted: true`
- **CORS `*` em produção** — sempre origins explícitas

## Consequências

### Positivas
- NestJS oferece DI, modules, guards, interceptors — enterprise-ready sem overhead
- TypeScript strict garante type safety end-to-end
- class-validator + ValidationPipe elimina input validation boilerplate
- TypeORM oferece controle fino sobre SQL; Prisma oferece type-safety máxima
- Monorepo com Turborepo permite compartilhar tipos com Next.js frontend
- Jest integrado com `@nestjs/testing` simplifica testes
- Estrutura modular facilita escalar para microserviços

### Negativas
- NestJS tem curva de aprendizado maior que Express puro — decorators, DI, modules
- TypeORM tem bugs históricos e documentação inconsistente (mitigado com Prisma)
- Prisma gera cliente gigante para schemas grandes
- Decorator boilerplate pode ser excessivo para projetos pequenos
- Runtime overhead do decorator metadata no startup

## Referências

- Skill: `skills/Backend/nestjs-expert/SKILL.md`
- Padronização EVEO: documentação interna Frontend/NestJS
- NestJS Docs: https://docs.nestjs.com/
- TypeORM: https://typeorm.io/
- Prisma: https://www.prisma.io/