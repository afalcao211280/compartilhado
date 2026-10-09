# Jest — Testes Unit e E2E

Leia `core.md` secoes testing para detalhes.

## Unit Test

```typescript
describe('UserService', () => {
  let service: UserService;
  let repo: jest.Mocked<UserRepository>;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [UserService, { provide: UserRepository, useValue: mockRepo() }],
    }).compile();
    service = module.get(UserService);
  });
});
```

## E2E

```typescript
describe('AppController (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = module.createNestApplication();
    await app.init();
  });
});
```

## Regras
- Jest para unit
- supertest para e2e
- Coverage >80%
