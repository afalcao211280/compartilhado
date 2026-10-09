# Workflow — Scaffold e Geracao de Codigo

## Quando Usar

- Ao criar **projeto novo** NestJS
- Ao gerar **feature nova**

## Decisoes Iniciais

1. TypeORM ou Prisma?
2. Tipo: API / Worker / Microservice
3. Auth: JWT / OAuth2 / API Key

## Scaffold de Projeto Novo

1. `nest new <project>`
2. Configurar `tsconfig.json` (strict)
3. `src/main.ts` — bootstrap
4. `src/app.module.ts`
5. `src/common/` — guards, filters, interceptors
6. `src/config/` — env validation
7. Docker multi-stage

## Workflow de Feature Nova

```
Entity/Prisma schema → Migration → Repository → Service → DTO → Controller → Module → Test
```

1. Entity (TypeORM) ou Schema (Prisma)
2. Migration
3. Repository
4. Service
5. DTOs (Create/Update/Response)
6. Controller
7. Module
8. Testes

## Checklist de Scaffold

- [ ] `npm run build` compila
- [ ] `npm run test` passa
- [ ] Swagger docs funcionam
- [ ] Docker build funciona
