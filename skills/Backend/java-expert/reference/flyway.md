# Flyway — Migrations

Leia `core.md` secao Migrations para detalhes.

## Estrutura

```
src/main/resources/db/migration/
  V001__create_users.sql
  V002__add_orders_table.sql
```

## Migration

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL
);
```

## Regras
- Versionamento: VNNN__descricao.sql
- DDL em migrations
- DML em scripts separados
- Nunca editar migration ja aplicada
