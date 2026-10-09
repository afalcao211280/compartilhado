# NestJS Expert — Padrões de Código

## 1. Bootstrap Completo (main.ts)

```typescript
// src/main.ts
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe, VersioningType } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { Logger } from 'nestjs-pino';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });

  // Logger estruturado
  app.useLogger(app.get(Logger));

  // Security headers
  app.use(helmet());

  // CORS — origins explícitas, nunca *
  app.enableCors({
    origin: process.env['ALLOWED_ORIGINS']?.split(',') ?? [],
    credentials: true,
  });

  // Versionamento de API
  app.enableVersioning({ type: VersioningType.URI });

  // Validation global
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  // Swagger (apenas em non-prod)
  if (process.env['NODE_ENV'] !== 'production') {
    const config = new DocumentBuilder()
      .setTitle('EVEO Service')
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('api/docs', app, document);
  }

  await app.listen(parseInt(process.env['PORT'] ?? '3000'));
}

bootstrap();
```

---

## 2. Feature Module Completo

```typescript
// src/modules/user/user.module.ts
@Module({
  imports: [
    TypeOrmModule.forFeature([User]),  // ou PrismaModule
    CacheModule.register({ ttl: 300 }),
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET'),
        signOptions: { expiresIn: '1h' },
      }),
    }),
  ],
  controllers: [UserController],
  providers: [UserService, UserRepository],
  exports: [UserService],
})
export class UserModule {}
```

---

## 3. DTOs com class-validator e Swagger

```typescript
// src/modules/user/dto/create-user.dto.ts
import { IsEmail, IsString, MinLength, MaxLength, IsEnum } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { UserRole } from '../entities/user.entity';

export class CreateUserDto {
  @ApiProperty({ example: 'joao@eveo.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'João Silva', minLength: 2, maxLength: 100 })
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  name: string;

  @ApiProperty({ minLength: 8, maxLength: 128 })
  @IsString()
  @MinLength(8)
  @MaxLength(128)
  password: string;

  @ApiProperty({ enum: UserRole })
  @IsEnum(UserRole)
  role: UserRole;
}

// src/modules/user/dto/user-response.dto.ts
export class UserResponseDto {
  @ApiProperty()
  id: string;

  @ApiProperty()
  email: string;

  @ApiProperty()
  name: string;

  @ApiProperty({ enum: UserRole })
  role: UserRole;

  @ApiProperty()
  createdAt: Date;

  constructor(partial: Partial<UserResponseDto>) {
    Object.assign(this, partial);
  }
}
```

---

## 4. Repository Pattern (TypeORM)

```typescript
// src/modules/user/user.repository.ts
@Injectable()
export class UserRepository {
  constructor(
    @InjectRepository(User)
    private readonly ormRepo: Repository<User>,
  ) {}

  async findById(id: string): Promise<User | null> {
    return this.ormRepo.findOne({ where: { id } });
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.ormRepo.findOne({ where: { email } });
  }

  async existsByEmail(email: string): Promise<boolean> {
    return this.ormRepo.existsBy({ email });
  }

  async create(data: Partial<User>): Promise<User> {
    const entity = this.ormRepo.create(data);
    return this.ormRepo.save(entity);
  }

  async findPaginated(page: number, limit: number): Promise<[User[], number]> {
    return this.ormRepo.findAndCount({
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });
  }
}
```

---

## 5. Service Layer

```typescript
// src/modules/user/user.service.ts
@Injectable()
export class UserService {
  private readonly logger = new Logger(UserService.name);

  constructor(
    private readonly userRepo: UserRepository,
    private readonly jwtService: JwtService,
  ) {}

  async create(dto: CreateUserDto): Promise<UserResponseDto> {
    this.logger.log(`criando usuário email=${dto.email}`);

    if (await this.userRepo.existsByEmail(dto.email)) {
      throw new ConflictException(`Usuário com email '${dto.email}' já existe`);
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);
    const user = await this.userRepo.create({ ...dto, passwordHash });
    this.logger.log(`usuário criado id=${user.id}`);
    return new UserResponseDto(user);
  }

  async findById(id: string): Promise<UserResponseDto> {
    const user = await this.userRepo.findById(id);
    if (!user) {
      throw new NotFoundException(`Usuário '${id}' não encontrado`);
    }
    return new UserResponseDto(user);
  }
}
```

---

## 6. Controller

```typescript
// src/modules/user/user.controller.ts
@Controller({ path: 'users', version: '1' })
@ApiTags('Users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Criar usuário' })
  @ApiCreatedResponse({ type: UserResponseDto })
  async create(@Body() dto: CreateUserDto): Promise<UserResponseDto> {
    return this.userService.create(dto);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Buscar usuário por ID' })
  @ApiOkResponse({ type: UserResponseDto })
  @ApiNotFoundResponse()
  async findById(@Param('id', ParseUUIDPipe) id: string): Promise<UserResponseDto> {
    return this.userService.findById(id);
  }
}
```

---

## 7. JWT Auth Guard + Decorator

```typescript
// src/common/guards/jwt-auth.guard.ts
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}

// src/common/strategies/jwt.strategy.ts
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private config: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_SECRET'),
    });
  }

  async validate(payload: { sub: string; email: string }) {
    return { id: payload.sub, email: payload.email };
  }
}

// src/common/decorators/current-user.decorator.ts
export const CurrentUser = createParamDecorator(
  (data: unknown, ctx: ExecutionContext) => ctx.switchToHttp().getRequest<Request>()['user'],
);
```

---

## 8. Exception Filter Global

```typescript
// src/common/filters/all-exceptions.filter.ts
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const message =
      exception instanceof HttpException
        ? (exception.getResponse() as string | { message: string }).toString()
        : 'Erro interno do servidor';

    if (!(exception instanceof HttpException)) {
      this.logger.error('Erro não tratado', exception instanceof Error ? exception.stack : String(exception));
    }

    response.status(status).json({
      statusCode: status,
      message,
      timestamp: new Date().toISOString(),
      path: request.url,
    });
  }
}
```

---

## 9. Config Validation

```typescript
// src/config/env.validation.ts
import { IsString, IsNumber, IsOptional, IsUrl, IsNotEmpty } from 'class-validator';
import { plainToInstance } from 'class-transformer';

export class EnvironmentVariables {
  @IsString()
  @IsNotEmpty()
  DATABASE_URL: string;

  @IsString()
  @IsNotEmpty()
  JWT_SECRET: string;

  @IsUrl({ require_tld: false })
  @IsOptional()
  REDIS_URL: string = 'redis://localhost:6379';

  @IsNumber()
  @IsOptional()
  PORT: number = 3000;

  @IsString()
  @IsOptional()
  NODE_ENV: string = 'development';
}

export function validate(config: Record<string, unknown>) {
  const validated = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });
  const errors = validateSync(validated, { skipMissingProperties: false });
  if (errors.length > 0) {
    throw new Error(errors.toString());
  }
  return validated;
}
```

---

## 10. Jest — Unit Test de Service

```typescript
// src/modules/user/user.service.spec.ts
describe('UserService', () => {
  let service: UserService;
  let userRepo: jest.Mocked<UserRepository>;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        UserService,
        {
          provide: UserRepository,
          useValue: {
            findById: jest.fn(),
            existsByEmail: jest.fn(),
            create: jest.fn(),
          } satisfies Partial<jest.Mocked<UserRepository>>,
        },
        {
          provide: JwtService,
          useValue: { sign: jest.fn(() => 'token') },
        },
      ],
    }).compile();

    service = module.get(UserService);
    userRepo = module.get(UserRepository);
  });

  it('deve criar usuário com sucesso', async () => {
    userRepo.existsByEmail.mockResolvedValue(false);
    userRepo.create.mockResolvedValue({
      id: '1', email: 'test@eveo.com', name: 'Test', role: UserRole.READER,
    } as User);

    const result = await service.create({
      email: 'test@eveo.com', name: 'Test', password: 'senha123', role: UserRole.READER,
    });

    expect(result.email).toBe('test@eveo.com');
    expect(userRepo.create).toHaveBeenCalledTimes(1);
  });

  it('deve lançar ConflictException quando email duplicado', async () => {
    userRepo.existsByEmail.mockResolvedValue(true);
    await expect(service.create({
      email: 'dup@eveo.com', name: 'Dup', password: 'senha123', role: UserRole.READER,
    })).rejects.toThrow(ConflictException);
  });
});
```

---

## 11. Dockerfile Multi-stage

```dockerfile
# docker/Dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production --ignore-scripts
COPY . .
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app
RUN addgroup --system app && adduser --system --ingroup app app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
USER app
EXPOSE 3000
CMD ["node", "dist/main"]
```

---

## Anti-patterns

### ❌ Dependências circulares entre módulos
**Problema:** O desenvolvedor cria dois módulos que se importam mutuamente e resolve usando `forwardRef()` em ambos.
**Por quê evitar:** `forwardRef()` é um sintoma de design problemático — indica que os módulos estão acoplados demais. Aumenta complexidade, dificulta testes e pode causar falhas silenciosas de injeção em tempo de boot.
**Solução:**
```typescript
// Errado — circular: UserModule importa AuthModule que importa UserModule
@Module({ imports: [forwardRef(() => AuthModule)] })
export class UserModule {}

// Correto — extraia a dependência compartilhada para um módulo comum
// SharedModule exporta o que ambos precisam
@Module({ providers: [TokenService], exports: [TokenService] })
export class SharedModule {}

@Module({ imports: [SharedModule] })
export class UserModule {}

@Module({ imports: [SharedModule] })
export class AuthModule {}
```

---

### ❌ Instanciar serviços com `new` em vez de injetar
**Problema:** O desenvolvedor cria instâncias de serviços diretamente com `new MyService()` dentro de outro provider ou controller.
**Por quê evitar:** Bypassa o container de DI do NestJS: a instância não recebe suas próprias dependências, não pode ser substituída em testes por mocks, e não é gerenciada pelo ciclo de vida do módulo.
**Solução:**
```typescript
// Errado
@Injectable()
export class OrderService {
  private emailService = new EmailService(); // sem DI, sem mock, sem lifecycle
}

// Correto — declare como dependência no constructor
@Injectable()
export class OrderService {
  constructor(private readonly emailService: EmailService) {}
}
// e registre EmailService nos providers do módulo
```

---

### ❌ Verificar req.user manualmente no controller em vez de usar Guard
**Problema:** O desenvolvedor checa `req.user` ou o header `Authorization` diretamente dentro dos métodos do controller para autenticar a requisição.
**Por quê evitar:** Duplica lógica de autenticação em cada endpoint, é fácil de esquecer em novos endpoints, e não segue o pipeline declarativo do NestJS (Guards, Interceptors, Decorators).
**Solução:**
```typescript
// Errado
@Get('profile')
getProfile(@Req() req: Request) {
  if (!req['user']) throw new UnauthorizedException();
  return req['user'];
}

// Correto — aplique o Guard no controller ou globalmente
@UseGuards(JwtAuthGuard)
@Get('profile')
getProfile(@CurrentUser() user: AuthUser) {
  return user;
}
```

---

### ❌ Retornar entidade Prisma com campos sensíveis na resposta
**Problema:** O service ou controller retorna o objeto Prisma diretamente, incluindo campos como `passwordHash`, `refreshToken` ou `secretKey`.
**Por quê evitar:** Vaza dados sensíveis na API. O cliente recebe campos que não deveria ver, violando o princípio do menor privilégio e podendo comprometer a segurança.
**Solução:**
```typescript
// Errado — retorna passwordHash para o cliente
async findById(id: string) {
  return this.prisma.user.findUniqueOrThrow({ where: { id } });
}

// Correto — projete apenas os campos necessários ou mapeie para DTO
async findById(id: string): Promise<UserResponseDto> {
  const user = await this.prisma.user.findUniqueOrThrow({
    where: { id },
    select: { id: true, email: true, name: true, role: true, createdAt: true },
    // passwordHash e refreshToken excluídos pelo select
  });
  return new UserResponseDto(user);
}
```

---

### ❌ Ausência de filtro global de exceções
**Problema:** A aplicação não registra um `ExceptionFilter` global, deixando exceções não tratadas vazar com stack trace completo na resposta HTTP.
**Por quê evitar:** Stack traces expõem estrutura interna da aplicação, caminhos de arquivo e versões de dependências — informações úteis para atacantes. Também resulta em respostas inconsistentes para o cliente.
**Solução:**
```typescript
// Errado — sem filtro global, exceções inesperadas expõem stack trace

// Correto — registre o filtro no bootstrap
async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalFilters(new AllExceptionsFilter());
  await app.listen(3000);
}

// Ou via APP_FILTER para permitir injeção de dependências no filtro
@Module({
  providers: [{ provide: APP_FILTER, useClass: AllExceptionsFilter }],
})
export class AppModule {}
```

---

### ❌ Confiar no body bruto sem DTOs e class-validator
**Problema:** O controller recebe `@Body() body: any` ou um tipo simples sem decorators de validação, aceitando qualquer payload do cliente.
**Por quê evitar:** Permite injeção de campos inesperados (mass assignment), dados inválidos e até payloads maliciosos. Sem `whitelist: true` no ValidationPipe, campos extras passam silenciosamente para o serviço.
**Solução:**
```typescript
// Errado
@Post()
async create(@Body() body: any) {
  return this.userService.create(body);
}

// Correto — DTO tipado com class-validator + ValidationPipe global com whitelist
export class CreateUserDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(8)
  password: string;
}

@Post()
async create(@Body() dto: CreateUserDto) {
  return this.userService.create(dto);
}
// ValidationPipe com { whitelist: true, forbidNonWhitelisted: true } no main.ts
```

---

### ❌ Bloquear o event loop com operações síncronas em handlers async
**Problema:** O desenvolvedor usa `crypto.createHash()` síncrono, `fs.readFileSync()` ou loops CPU-intensivos diretamente dentro de um handler de requisição.
**Por quê evitar:** Node.js é single-threaded no event loop. Operações síncronas bloqueiam todas as outras requisições simultâneas, causando aumento de latência e timeout em produção sob carga.
**Solução:**
```typescript
// Errado — bloqueia o event loop para todas as requisições concorrentes
@Post('hash')
hashData(@Body('data') data: string) {
  const hash = crypto.createHash('sha256').update(data).digest('hex'); // síncrono, OK para CPU leve
  const content = fs.readFileSync('/app/template.html', 'utf8'); // BLOQUEIA
  return { hash, content };
}

// Correto — use APIs assíncronas
@Post('hash')
async hashData(@Body('data') data: string) {
  const content = await fs.promises.readFile('/app/template.html', 'utf8');
  const hash = crypto.createHash('sha256').update(data).digest('hex');
  return { hash, content };
}
// Para hashing de senha: use bcrypt.hash() (async), nunca bcrypt.hashSync()
```

---

### ❌ Estado global mutável em providers (singleton)
**Problema:** O desenvolvedor armazena estado mutável em propriedades de instância de um `@Injectable()` provider, como arrays, objetos ou contadores.
**Por quê evitar:** Providers NestJS são singletons por padrão. Em cenários com múltiplos workers (worker_threads, cluster) ou requisições concorrentes, o estado compartilhado causa race conditions e resultados imprevisíveis.
**Solução:**
```typescript
// Errado — estado mutável em singleton
@Injectable()
export class SessionService {
  private sessions: Map<string, Session> = new Map(); // vaza entre requisições
}

// Correto — use Redis ou outro store externo para estado compartilhado
@Injectable()
export class SessionService {
  constructor(private readonly redis: RedisService) {}

  async setSession(id: string, data: Session): Promise<void> {
    await this.redis.set(`session:${id}`, JSON.stringify(data), 'EX', 3600);
  }
}
```

---

### ❌ Ausência de rate limiting em endpoints de autenticação
**Problema:** Os endpoints de login, registro e redefinição de senha não têm nenhum controle de taxa de requisições.
**Por quê evitar:** Permite ataques de força bruta em senhas, credential stuffing e enumeração de usuários. Um atacante pode tentar milhares de combinações por segundo sem nenhuma barreira.
**Solução:**
```typescript
// Correto — use @nestjs/throttler no módulo e @Throttle no endpoint sensível
// app.module.ts
@Module({
  imports: [
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 5 }]), // 5 req/min globalmente
  ],
})
export class AppModule {}

// auth.controller.ts
@Post('login')
@Throttle({ default: { ttl: 60_000, limit: 5 } }) // 5 tentativas por minuto por IP
async login(@Body() dto: LoginDto) {
  return this.authService.login(dto);
}
```

---

### ❌ Usar `any` como tipo em vez de tipos explícitos
**Problema:** O desenvolvedor escreve `any` em parâmetros, retornos de função ou variáveis para evitar erros do TypeScript.
**Por quê evitar:** Desativa completamente a verificação de tipos naquele ponto, propagando `any` para chamadores e receptores. Anula os benefícios do TypeScript, esconde bugs em tempo de compilação e impede o autocomplete do editor.
**Solução:**
```typescript
// Errado
async findUser(id: any): Promise<any> {
  const result: any = await this.prisma.user.findUnique({ where: { id } });
  return result;
}

// Correto — tipos explícitos em toda a cadeia
async findUser(id: string): Promise<UserResponseDto> {
  const user = await this.prisma.user.findUniqueOrThrow({ where: { id } });
  return new UserResponseDto(user);
}

// Para tipos dinâmicos legítimos, prefira unknown com type guard
function processPayload(payload: unknown): string {
  if (typeof payload !== 'string') throw new BadRequestException('Payload inválido');
  return payload.toUpperCase();
}
```
