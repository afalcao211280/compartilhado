# Prisma — Schema, Client, Migrations

Leia `core.md` secoes Prisma para detalhes.

## Schema

```prisma
model User {
  id        String   @id @default(uuid())
  email     String   @unique
  name      String
  createdAt DateTime @default(now())
}
```

## Regras
- Schema-first approach
- Prisma Client gera tipos automaticamente
- Migrations via `prisma migrate`
- Nunca misturar TypeORM e Prisma
