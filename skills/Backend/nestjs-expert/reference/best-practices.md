# NestJS — Boas Práticas (aprofundado)

Origem: `nestjs-best-practices` (compare), 40 regras — aqui com o **porquê** e o **como** de cada uma.
Versão-alvo: **NestJS 11** (Node.js 20/22, TypeScript 5.x strict). Aplicar ao gerar e ao revisar código.
Segurança universal (SQLi, secrets, headers, deps) vive em `security-baseline.md`; abaixo só o que é específico de NestJS.

## Índice

1. [Arquitetura](#1-arquitetura)
2. [Dependency Injection](#2-dependency-injection)
3. [API](#3-api)
4. [Erros](#4-erros)
5. [Banco de Dados](#5-banco-de-dados)
6. [Segurança (além do baseline)](#6-seguranca-alem-do-baseline)
7. [Performance](#7-performance)
8. [Microservices](#8-microservices)
9. [DevOps](#9-devops)
10. [Testes](#10-testes)

---

## 1. Arquitetura

### 1.1 Organizar por feature modules — Impacto: CRÍTICO
**Por quê:** Cada módulo encapsula uma funcionalidade completa (controller, service, repository, entity, DTOs). Organizar por camada técnica (todos os controllers juntos, todos os services juntos) espalha uma feature por várias pastas e encarece qualquer mudança. Feature modules dão 3-5x mais velocidade de onboarding e de entrega.
```typescript
// modules/users/users.module.ts — self-contained
@Module({
  imports: [TypeOrmModule.forFeature([User])],
  controllers: [UsersController],
  providers: [UsersService, UsersRepository],
  exports: [UsersService],
})
export class UsersModule {}
```

### 1.2 Single Responsibility nos services — Impacto: CRÍTICO
**Por quê:** Cada service deve ter uma responsabilidade única e bem definida. "God services" que misturam domínios (nome com "And", ex.: `UserAndBillingService`) viram inimigos do teste e da mudança. Separar responsabilidades melhora testabilidade em 40%+.
```typescript
// Errado: UsersService que também cobra cartão e envia e-mail
// Certo: UsersService, BillingService, NotificationService — cada um com um foco
@Injectable()
export class UsersService {
  constructor(private readonly repo: UsersRepository) {}
  // só regras de usuário
}
```

### 1.3 Compartilhamento correto de módulos — Impacto: CRÍTICO
**Por quê:** Providers do NestJS são singletons por módulo. Se um mesmo service for declarado em `providers` de dois módulos, cada módulo ganha uma **instância separada** — estado divergente, memória desperdiçada e bugs difíceis. A regra: encapsule o service num módulo, `exports` explícito, e `imports` do módulo onde for preciso.
```typescript
// Errado: declarar UsersService em providers de dois módulos → 2 instâncias
// Certo: exportar do módulo dono e importar o módulo
@Module({ providers: [UsersService], exports: [UsersService] })
export class UsersModule {}

@Module({ imports: [UsersModule] }) // reusa a MESMA instância
export class OrdersModule {}
```

### 1.4 Evitar dependências circulares — Impacto: CRÍTICO
**Por quê:** Módulo A importa B e B importa A (direta ou transitivamente). `forwardRef()` até resolve, mas é sinal de problema arquitetural e é a **causa nº1 de crash em runtime** no NestJS. Prefira extrair um módulo compartilhado ou usar eventos para quebrar o ciclo.
```typescript
// Último recurso quando o ciclo é inevitável:
@Module({ imports: [forwardRef(() => OrdersModule)] })
export class UsersModule {}
// constructor(@Inject(forwardRef(() => OrdersService)) private orders: OrdersService)
// Melhor: extrair SharedModule ou publicar um evento (ver 1.6).
```

### 1.5 Repository pattern para acesso a dados — Impacto: ALTO
**Por quê:** Encapsular queries e lógica de persistência em repositories mantém o service focado em regra de negócio, facilita mock em teste e permite trocar a implementação de banco sem tocar no service.
```typescript
@Injectable()
export class UsersRepository {
  constructor(@InjectRepository(User) private readonly orm: Repository<User>) {}
  findById(id: string): Promise<User | null> {
    return this.orm.findOne({ where: { id } });
  }
}
// Service consome UsersRepository, nunca o Repository<User> do ORM diretamente.
```

### 1.6 Arquitetura orientada a eventos para desacoplar — Impacto: MÉDIO-ALTO
**Por quê:** `@nestjs/event-emitter` para eventos intra-serviço e message broker para inter-serviço. Eventos deixam um módulo reagir a mudanças sem depender diretamente de outro — melhora modularidade e habilita processamento assíncrono (ex.: enviar e-mail de boas-vindas sem acoplar `UsersService` ao `MailService`).
```typescript
// emissor
this.eventEmitter.emit('user.created', new UserCreatedEvent(user.id));

// ouvinte, em outro módulo
@OnEvent('user.created')
async handleUserCreated(event: UserCreatedEvent) {
  await this.mail.sendWelcome(event.userId);
}
```

---

## 2. Dependency Injection

### 2.1 Preferir constructor injection — Impacto: CRÍTICO
**Por quê:** Injeção via construtor torna as dependências explícitas, deixa o TypeScript checar tipos na instanciação e simplifica o teste (basta passar mocks no `new`). Property injection (`@Inject()` em campo) esconde dependências e permite instanciar a classe sem elas. Use property injection só para dependências opcionais (`@Optional()`).
```typescript
@Injectable()
export class UsersService {
  constructor(
    private readonly repo: UsersRepository,
    @Inject('CONFIG') private readonly config: ConfigType,
  ) {}
}
```

### 2.2 Injection tokens para interfaces — Impacto: ALTO
**Por quê:** Interfaces do TypeScript são apagadas em compile time e **não servem** como token de injeção. Para injetar por contrato (e trocar implementação em teste/ambiente), use string/symbol token ou classe abstrata.
```typescript
export const PAYMENT_GATEWAY = Symbol('PAYMENT_GATEWAY');
export interface PaymentGateway { charge(amount: number): Promise<void>; }

@Module({
  providers: [{ provide: PAYMENT_GATEWAY, useClass: StripeGateway }],
})
export class PaymentModule {}

// constructor(@Inject(PAYMENT_GATEWAY) private gateway: PaymentGateway) {}
```

### 2.3 Entender escopos de provider — Impacto: CRÍTICO
**Por quê:** Há três escopos: `DEFAULT` (singleton), `REQUEST` (instância por request) e `TRANSIENT` (nova a cada injeção). A maioria deve ser singleton. `REQUEST` "borbulha" por toda a cadeia de dependências e degrada performance; usado sem necessidade causa vazamento de memória e compartilhamento incorreto de dados.
```typescript
@Injectable({ scope: Scope.REQUEST }) // só quando realmente precisa do contexto da request
export class RequestContextService {
  constructor(@Inject(REQUEST) private readonly req: Request) {}
}
```

### 2.4 Interface Segregation — Impacto: ALTO
**Por quê:** Clientes não devem depender de métodos que não usam. Interfaces "gordas" (e-mail + SMS + push + log num único contrato) forçam acoplamento desnecessário. Quebre em interfaces pequenas por papel — reduz acoplamento e melhora testabilidade em 30-50%.
```typescript
// Errado: interface Notifier { email; sms; push; log; }
// Certo: contratos focados
export interface EmailSender { sendEmail(to: string, body: string): Promise<void>; }
export interface SmsSender { sendSms(to: string, body: string): Promise<void>; }
```

### 2.5 Honrar Liskov Substitution — Impacto: ALTO
**Por quê:** Qualquer implementação de uma interface/classe abstrata deve ser substituível sem quebrar quem a chama. Um `MockPaymentService` de teste precisa devolver as mesmas formas de retorno e tratar erros como o real; senão os testes passam e a produção quebra ao trocar a implementação.
```typescript
// mock deve honrar o mesmo contrato do real (mesmos shapes, mesmos erros lançados)
class FakePaymentGateway implements PaymentGateway {
  async charge(amount: number): Promise<void> {
    if (amount <= 0) throw new BadRequestException('valor inválido'); // igual ao real
  }
}
```

### 2.6 Evitar o anti-padrão Service Locator — Impacto: ALTO
**Por quê:** Resolver dependências em runtime via `ModuleRef.get()` ou container global esconde as dependências, quebra a testabilidade e anula os ganhos da DI. Use constructor injection. `ModuleRef` só se justifica para resolução verdadeiramente dinâmica (ex.: escolher uma strategy por chave em runtime).
```typescript
// Errado: this.moduleRef.get(UsersService) dentro de um método
// Certo: injetar no construtor
constructor(private readonly users: UsersService) {}
```

---

## 3. API

### 3.1 DTOs e serialização nas respostas — Impacto: MÉDIO
**Por quê:** Nunca retorne entidades direto do controller — você expõe campos sensíveis (hash de senha, notas internas) por acidente e amarra o contrato ao schema do banco. Use response DTOs com `class-transformer` (`@Exclude()`/`@Expose()`) e `ClassSerializerInterceptor` para controlar exatamente o que sai.
```typescript
export class UserResponseDto {
  @Expose() id: string;
  @Expose() email: string;
  @Exclude() passwordHash: string; // nunca serializado
  constructor(partial: Partial<UserResponseDto>) { Object.assign(this, partial); }
}
// app.useGlobalInterceptors(new ClassSerializerInterceptor(app.get(Reflector)));
```

### 3.2 Pipes para transformação de input — Impacto: MÉDIO
**Por quê:** Pipes tiram a validação/transformação do controller. Use os built-in (`ParseIntPipe`, `ParseUUIDPipe`, `DefaultValuePipe`) para conversões comuns e pipes custom para regras de negócio — o handler recebe dados já limpos e tipados.
```typescript
@Get(':id')
findOne(@Param('id', ParseUUIDPipe) id: string) { /* id já validado como UUID */ }

@Get()
list(@Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number) {}
```

### 3.3 Interceptors para cross-cutting concerns — Impacto: MÉDIO-ALTO
**Por quê:** Interceptors envolvem a execução do handler (acesso aos streams de request e response) e permitem logging, transformação de resposta, cache e medição de latência sem poluir a lógica de negócio.
```typescript
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger(LoggingInterceptor.name);
  intercept(ctx: ExecutionContext, next: CallHandler): Observable<unknown> {
    const started = Date.now();
    return next.handle().pipe(tap(() => this.logger.log(`+${Date.now() - started}ms`)));
  }
}
```

### 3.4 Versionamento de API — Impacto: MÉDIO
**Por quê:** Ao introduzir mudança quebradora, versione (URI, header ou media type) e aplique de forma consistente. Assim clientes antigos continuam funcionando enquanto os novos usam a versão atualizada.
```typescript
// main.ts
app.enableVersioning({ type: VersioningType.URI, defaultVersion: '1' });

@Controller({ path: 'users', version: '2' })
export class UsersV2Controller {}
```

---

## 4. Erros

### 4.1 Exception filters para tratamento de erros — Impacto: ALTO
**Por quê:** Nunca capture exceções e monte a resposta de erro manualmente no controller. Use exception filters para tratamento consistente e centralizado: um filter global para o catch-all e filters específicos por tipo. Padroniza o corpo de erro e evita vazar stack trace ao cliente.
```typescript
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);
  catch(exception: unknown, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse();
    const status = exception instanceof HttpException
      ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;
    this.logger.error(exception instanceof Error ? exception.stack : String(exception));
    res.status(status).json({ statusCode: status, timestamp: new Date().toISOString() });
  }
}
```

### 4.2 Lançar HTTP exceptions dos services — Impacto: ALTO
**Por quê:** Lançar subclasses de `HttpException` (`NotFoundException`, `ConflictException`) direto do service mantém o controller fino e deixa o service comunicar o estado de erro adequado. Para services realmente agnósticos de transporte, use domain exceptions e mapeie para HTTP no filter.
```typescript
async findById(id: string): Promise<User> {
  const user = await this.repo.findById(id);
  if (!user) throw new NotFoundException(`usuário ${id} não encontrado`);
  return user;
}
```

### 4.3 Tratar erros assíncronos corretamente — Impacto: ALTO
**Por quê:** O NestJS captura erros de handlers async automaticamente, mas erros de tarefas em background, event handlers e promises criadas à mão podem derrubar o processo (unhandled rejection). Trate explicitamente e mantenha handlers globais como rede de segurança.
```typescript
// background job: capture e logue, não deixe rejeitar sem tratamento
this.queue.process(async (job) => {
  try { await this.handle(job); }
  catch (err) { this.logger.error('falha no job', err as Error); throw err; }
});
// rede de segurança (main.ts): process.on('unhandledRejection', ...)
```

---

## 5. Banco de Dados

### 5.1 Usar migrations — Impacto: ALTO
**Por quê:** Nunca `synchronize: true` em produção — ele altera o schema silenciosamente e pode apagar dados. Migrations dão versionamento do banco, rollback seguro e consistência entre ambientes.
```typescript
// data-source.ts
export default new DataSource({ /* ... */ synchronize: false, migrations: ['dist/migrations/*.js'] });
// npm run typeorm migration:generate / migration:run
// Prisma: prisma migrate dev / deploy
```

### 5.2 Transações para operações multi-etapa — Impacto: ALTO
**Por quê:** Quando várias operações precisam suceder ou falhar juntas, envolva-as numa transação para evitar estado parcial/inconsistente. Use `DataSource.transaction()` (rollback automático) ou o `QueryRunner` para cenários complexos.
```typescript
async createOrder(userId: string, items: OrderItem[]): Promise<Order> {
  return this.dataSource.transaction(async (manager) => {
    const order = await manager.save(Order, { userId, status: 'pending' });
    for (const item of items) await manager.save(OrderItem, { orderId: order.id, ...item });
    return order; // rollback automático se qualquer save lançar
  });
}
```

### 5.3 Evitar N+1 queries — Impacto: ALTO
**Por quê:** Buscar uma lista e, para cada item, disparar outra query para dados relacionados gera 1+N queries (100 pedidos = 101 queries). É um dos maiores matadores de performance. Use `relations`/eager loading, `join` no query builder ou DataLoader para agrupar.
```typescript
// Errado: for (const u of users) u.orders = await repo.findOrders(u.id);
// Certo: uma query com join
const users = await this.repo.find({ relations: { orders: true } });
```

---

## 6. Segurança (além do baseline)

> Regras universais (SQLi, secrets, headers, `npm audit`) em `security-baseline.md`. Aqui, o específico de NestJS.

### 6.1 Validar todo input com DTOs e Pipes — Impacto: ALTO
**Por quê:** Primeira linha de defesa. Valide body, query e params com `class-validator` nos DTOs e o `ValidationPipe` global. Nunca confie em input do cliente.
```typescript
// main.ts
app.useGlobalPipes(new ValidationPipe({
  whitelist: true,             // remove props não declaradas
  forbidNonWhitelisted: true,  // rejeita props extras (não ignora silenciosamente)
  transform: true,
}));
```

### 6.2 Guards para autenticação e autorização — Impacto: ALTO
**Por quê:** Guards decidem se a request prossegue com base em auth/roles/permissões e rodam **antes** de pipes e interceptors — lugar ideal para controle de acesso. Use guards em vez de checagens manuais no controller.
```typescript
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}
  canActivate(ctx: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<string[]>('roles', [ctx.getHandler(), ctx.getClass()]);
    if (!required?.length) return true;
    const { user } = ctx.switchToHttp().getRequest();
    return required.some((r) => user?.roles?.includes(r));
  }
}
```

### 6.3 Autenticação JWT segura — Impacto: CRÍTICO
**Por quê:** Use `@nestjs/jwt` + `@nestjs/passport`. Guarde o secret de forma segura (env/secret manager), use lifetime curto no access token, implemente refresh token e **nunca** coloque dado sensível no payload do JWT (ele é apenas assinado, não criptografado — qualquer um lê o payload).
```typescript
JwtModule.registerAsync({
  inject: [ConfigService],
  useFactory: (cfg: ConfigService) => ({
    secret: cfg.getOrThrow('JWT_SECRET'),
    signOptions: { expiresIn: '15m', issuer: 'eveo', audience: 'eveo-api' },
  }),
});
// payload: só id/roles — nunca senha, e-mail completo ou PII sensível
```

### 6.4 Rate limiting — Impacto: ALTO
**Por quê:** `@nestjs/throttler` limita a taxa de requests por cliente. Aplique limites diferentes por rota (mais rígido em auth, mais folgado em leitura) e use Redis como storage em deploy clusterizado (senão cada instância conta separado).
```typescript
ThrottlerModule.forRoot({ throttlers: [{ ttl: 60_000, limit: 100 }] });
// { provide: APP_GUARD, useClass: ThrottlerGuard }
@Throttle({ default: { ttl: 60_000, limit: 5 } }) // rota de login mais restrita
@Post('login') login() {}
```

### 6.5 Sanitizar output contra XSS — Impacto: ALTO
**Por quê:** APIs NestJS normalmente devolvem JSON (o browser não executa), mas há risco de XSS ao renderizar HTML, ao armazenar conteúdo do usuário ou quando o frontend trata a resposta indevidamente. Sanitize conteúdo gerado por usuário antes de persistir e use `Content-Type` correto.
```typescript
import sanitizeHtml from 'sanitize-html';
// antes de salvar comentário/bio do usuário
const safe = sanitizeHtml(dto.bio, { allowedTags: [], allowedAttributes: {} });
```

---

## 7. Performance

### 7.1 Cache estratégico — Impacto: ALTO
**Por quê:** `CacheModule` (`@nestjs/cache-manager`) para operações caras, dados muito acessados e chamadas a APIs externas. Defina TTL adequado e estratégia de invalidação. Não faça cache de tudo — foque em pontos de alto impacto e cuidado com dados que mudam.
```typescript
@Injectable()
export class ProductsService {
  constructor(@Inject(CACHE_MANAGER) private cache: Cache, private repo: ProductsRepository) {}
  async getFeatured(): Promise<Product[]> {
    const hit = await this.cache.get<Product[]>('featured');
    if (hit) return hit;
    const data = await this.repo.findFeatured();
    await this.cache.set('featured', data, 300_000); // 5 min
    return data;
  }
}
```

### 7.2 Otimizar queries de banco — Impacto: ALTO
**Por quê:** A maior parte da lentidão de API vem do banco. Selecione só as colunas necessárias, use índices adequados e evite over-fetch de relações. `SELECT *` e relações desnecessárias custam I/O e memória.
```typescript
const users = await this.repo.createQueryBuilder('u')
  .select(['u.id', 'u.email'])          // só o necessário
  .where('u.status = :s', { s: 'active' })
  .getMany();
// + índice em status: @Index('idx_users_status', ['status'])
```

### 7.3 Lazy loading de módulos grandes — Impacto: MÉDIO
**Por quê:** O NestJS permite carregar módulos sob demanda (`LazyModuleLoader`), adiando a inicialização até o primeiro uso. Vale para features raramente usadas, serverless (cold start) e módulos com inicialização pesada.
```typescript
constructor(private lazy: LazyModuleLoader) {}
async onReport() {
  const { ReportModule } = await import('./report/report.module');
  const ref = await this.lazy.load(() => ReportModule);
  return ref.get(ReportService).generate();
}
```

### 7.4 Usar lifecycle hooks async corretamente — Impacto: ALTO
**Por quê:** Hooks (`onModuleInit`, `onApplicationBootstrap`) suportam async, mas usá-los mal bloqueia o startup ou cria race conditions. Entenda a ordem do ciclo de vida e não faça trabalho pesado/serial demais que trave o boot.
```typescript
@Injectable()
export class SeedService implements OnApplicationBootstrap {
  async onApplicationBootstrap(): Promise<void> {
    await this.ensureDefaults(); // roda uma vez, após todos os módulos inicializados
  }
}
```

---

## 8. Microservices

### 8.1 Message vs Event patterns — Impacto: MÉDIO
**Por quê:** Microservices NestJS têm dois padrões: request-response (`@MessagePattern`, espera resposta) e event-based (`@EventPattern`, fire-and-forget). Usar o errado gera bug de comunicação (esperar resposta de um evento que não responde, ou bloquear onde deveria ser assíncrono).
```typescript
@MessagePattern({ cmd: 'get_user' })   // precisa de resposta
getUser(@Payload() id: string) { return this.users.findById(id); }

@EventPattern('user.created')          // fire-and-forget
handleCreated(@Payload() data: UserCreatedEvent) { this.audit.log(data); }
```

### 8.2 Filas para background jobs — Impacto: MÉDIO-ALTO
**Por quê:** `@nestjs/bullmq` desacopla tarefas longas do request HTTP, dá retry, e distribui carga entre workers. Use para e-mail, processamento de arquivo, notificações — qualquer coisa que não deva bloquear a request do usuário.
```typescript
// produtor
await this.mailQueue.add('welcome', { userId }, { attempts: 3, backoff: { type: 'exponential', delay: 1000 } });

// consumidor
@Processor('mail')
export class MailProcessor extends WorkerHost {
  async process(job: Job): Promise<void> { await this.mail.send(job.data); }
}
```

### 8.3 Health checks — Impacto: MÉDIO-ALTO
**Por quê:** `@nestjs/terminus` para liveness (o serviço deve ser reiniciado?) e readiness (pode receber tráfego?). Health checks corretos permitem que Kubernetes e load balancers roteiem tráfego certo e reciclem instâncias travadas.
```typescript
@Controller('health')
export class HealthController {
  constructor(private health: HealthCheckService, private db: TypeOrmHealthIndicator) {}
  @Get('ready') @HealthCheck()
  readiness() { return this.health.check([() => this.db.pingCheck('database')]); }
}
```

---

## 9. DevOps

### 9.1 ConfigModule para configuração — Impacto: BAIXO-MÉDIO
**Por quê:** `@nestjs/config` para configuração por ambiente, **validada no startup** (fail-fast em misconfiguração). Config namespaced (`registerAs`) dá organização e type-safety. Nunca `process.env` espalhado pelo código.
```typescript
ConfigModule.forRoot({
  isGlobal: true,
  load: [databaseConfig],
  validationSchema: Joi.object({
    NODE_ENV: Joi.string().valid('development', 'production', 'test').required(),
    DB_HOST: Joi.string().required(),
    JWT_SECRET: Joi.string().min(32).required(),
  }),
});
// uso: this.config.getOrThrow('database.host')
```

### 9.2 Logging estruturado — Impacto: MÉDIO-ALTO
**Por quê:** Logger do NestJS (ou `nestjs-pino`) com saída JSON em produção e contexto (request id, user id, operação) para rastrear requests entre serviços. Nunca `console.log`; respeite níveis de log.
```typescript
private readonly logger = new Logger(UsersService.name);
this.logger.log({ msg: 'usuário criado', userId: user.id, correlationId });
// produção: nestjs-pino para JSON estruturado + redaction de campos sensíveis
```

### 9.3 Graceful shutdown — Impacto: MÉDIO-ALTO
**Por quê:** Tratar SIGTERM/SIGINT para desligar sem perda: parar de aceitar requests novas, esperar as em voo, fechar conexões de banco e limpar recursos. Evita erros de conexão e perda de dados em deploy (zero-downtime).
```typescript
// main.ts
app.enableShutdownHooks();

@Injectable()
export class DatabaseService implements OnApplicationShutdown {
  async onApplicationShutdown(signal?: string): Promise<void> {
    this.logger.log(`encerrando (${signal})`);
    await this.connection.destroy();
  }
}
```

---

## 10. Testes

### 10.1 TestingModule para unit tests — Impacto: ALTO
**Por quê:** `@nestjs/testing` cria ambientes de teste isolados com dependências mockadas — testes rápidos, sem serviço externo, focados na regra de negócio. Substitua o repositório real por mock via `getRepositoryToken`.
```typescript
const module = await Test.createTestingModule({
  providers: [
    UsersService,
    { provide: getRepositoryToken(User), useValue: { findOne: jest.fn(), save: jest.fn() } },
  ],
}).compile();
const service = module.get(UsersService);
```

### 10.2 Mock de serviços externos — Impacto: ALTO
**Por quê:** Nunca chame API, banco ou fila reais em unit test — deixa o teste lento, não-determinístico e caro. Mocke com dados realistas e cubra casos de borda (timeout, erro), não só o caminho feliz.
```typescript
const mailMock = { send: jest.fn().mockResolvedValue(undefined) };
// override no TestingModule:
// .overrideProvider(MailService).useValue(mailMock)
mailMock.send.mockRejectedValueOnce(new Error('timeout')); // testar o caminho de erro
```

### 10.3 E2E com Supertest — Impacto: ALTO
**Por quê:** Testes e2e disparam requests HTTP reais contra a app (via Supertest), exercitando a stack inteira — middleware, guards, pipes, interceptors. Pegam problemas de integração que unit tests não pegam.
```typescript
const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
const app = moduleRef.createNestApplication();
await app.init();
await request(app.getHttpServer())
  .post('/api/v1/users').send({ email: 'a@eveo.com', name: 'Ana' })
  .expect(201);
```
