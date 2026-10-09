# NestJS Expert — Stack Canônica

## NestJS 10+ / Node.js 20+ / TypeScript 5.x — Versão Canônica EVEO

| Categoria | Lib | Versão | Link | Notas |
|-----------|-----|--------|------|-------|
| **Framework** | | | | |
| Core | NestJS | 10.x | https://nestjs.com | Sempre |
| Runtime | Node.js | 20+ LTS | https://nodejs.org | LTS. 22 LTS também aceito |
| Linguagem | TypeScript | 5.x | https://www.typescriptlang.org | `strict: true` obrigatório |
| **ORM** | | | | |
| ORM padrão A | TypeORM | 0.3.x | https://typeorm.io | Decorator-based entities. Perguntar usuário. |
| ORM padrão B | Prisma | 5.x | https://www.prisma.io | Schema-first. Perguntar usuário. |
| **Validação** | | | | |
| Validação | class-validator | 0.14+ | https://github.com/typestack/class-validator | Decoradores em DTOs |
| Transformação | class-transformer | 0.5+ | https://github.com/typestack/class-transformer | `@Transform`, `@Type` |
| **Auth e Segurança** | | | | |
| JWT | @nestjs/jwt | 10.x | https://github.com/nestjs/jwt | `JwtModule.registerAsync()` |
| Passport | @nestjs/passport | 10.x | https://github.com/nestjs/passport | Strategies: jwt, local |
| Helmet | helmet | 7.x | https://helmetjs.github.io | `app.use(helmet())` no main.ts |
| Rate limiting | @nestjs/throttler | 5.x | https://github.com/nestjs/throttler | `ThrottlerModule.forRoot()` |
| **Logging** | | | | |
| Estruturado | nestjs-pino | 4.x | https://github.com/iamolegga/nestjs-pino | JSON logging. Preferido. |
| Alternativa | NestJS Logger | (built-in) | — | Para projetos simples |
| **Tarefas e Filas** | | | | |
| Queue | BullMQ | 5.x | https://bullmq.io | Preferido sobre Bull |
| NestJS Bull | @nestjs/bullmq | 10.x | https://github.com/nestjs/bull | Integração NestJS para BullMQ |
| Scheduled | @nestjs/schedule | 4.x | https://github.com/nestjs/schedule | Cron jobs |
| **Cache** | | | | |
| Abstração | @nestjs/cache-manager | 2.x | https://github.com/nestjs/cache-manager | `@Cacheable()` via decorador |
| Store | cache-manager-redis-yet | 5.x | https://github.com/jaredwray/cacheable | Redis store para cache-manager |
| **HTTP Client** | | | | |
| HTTP client | @nestjs/axios | 3.x | https://github.com/nestjs/axios | `HttpModule`, `HttpService` |
| Alternativa | fetch (Node 18+) | built-in | — | Para chamadas simples sem módulo |
| **Circuit Breaker** | | | | |
| Circuit Breaker | opossum | 8.x | https://nodeshift.dev/opossum/ | Wrap de funções async |
| **Mensageria** | | | | |
| RabbitMQ | @nestjs/microservices | 10.x | — | Transport: `Transport.RMQ` |
| Kafka | @nestjs/microservices | 10.x | — | Transport: `Transport.KAFKA` |
| **API Docs** | | | | |
| OpenAPI / Swagger | @nestjs/swagger | 7.x | https://github.com/nestjs/swagger | `SwaggerModule.setup()` |
| **Observabilidade** | | | | |
| Métricas | @willsoto/nestjs-prometheus | 6.x | https://github.com/willsoto/nestjs-prometheus | Endpoint `/metrics` |
| Tracing | @opentelemetry/sdk-node | 0.52+ | https://opentelemetry.io/docs/languages/js/ | Inicializar ANTES do NestJS |
| **Testes** | | | | |
| Unit | Jest | 29.x | https://jestjs.io | `@nestjs/testing` para TestingModule |
| E2E | supertest | 7.x | https://github.com/ladjs/supertest | Com `@nestjs/testing` |
| Coverage | jest coverage | built-in | — | `--coverage --coverageThreshold=80` |
| Mocks de HTTP | nock | 13.x | https://github.com/nock/nock | Mock de chamadas HTTP |
| **Qualidade** | | | | |
| Linting | ESLint | 9.x | https://eslint.org | Flat config (`eslint.config.mjs`) |
| Formatação | Prettier | 3.x | https://prettier.io | `.prettierrc` |
| Type check | TypeScript compiler | 5.x | — | `tsc --noEmit` no CI |
| Audit | npm audit | built-in | — | `npm audit --audit-level=high` |
| **Container** | | | | |
| Imagem base | `node:20-alpine` | — | — | Runtime de prod |
| Builder | `node:20` | — | — | Estágio de build |

## tsconfig.json — Template Canônico

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2022",
    "sourceMap": true,
    "outDir": "./dist",
    "baseUrl": "./",
    "incremental": true,
    "skipLibCheck": true,
    "strictNullChecks": true,
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "forceConsistentCasingInFileNames": true,
    "noFallthroughCasesInSwitch": true
  }
}
```
