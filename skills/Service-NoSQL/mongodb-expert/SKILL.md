---
name: mongodb-expert
description: >
  Especialista MongoDB em padrões de produção EVEO. Stack: MongoDB 8+,
  Mongoose/Node driver, Beanie/Motor (Python), mongo-driver (Go), Atlas.
  Gera schemas, repositories, aggregation pipelines, índices, validation rules,
  decisões de embed vs reference e patterns de modelagem. Acionar SEMPRE que
  mencionar MongoDB, Mongo, Mongoose, aggregation, document model, schema design,
  embed/reference, ou quando o contexto for um banco de documentos.
version: "2.1.0"
category: Service-NoSQL
keywords:
  - mongodb
  - mongoose
  - aggregation
  - schema-design
  - nosql
  - document-model
  - atlas
requires:
  - security-expert
---

# MongoDB Expert — Padrões EVEO

Especialista MongoDB. Stack canônica, código pronto para produção.

## Princípios

1. **Schema-conscious, não schemaless** — document-oriented e flexível, mas flexibilidade não é desculpa para não validar. Esquema por aplicação, não por acidente.
2. **Dados acessados juntos, armazenados juntos** — modele em torno das queries, não das entidades. Embed elimina join e round-trip; referencie só quando precisar.
3. **`validator` obrigatório em produção** — `$jsonSchema` na coleção é a última linha de defesa contra dado inválido.
4. **`explain()` antes de índice** — cada índice custa escrita e RAM; só crie com query justificada.
5. **Write concern explícito** — `{ w: "majority" }` para durabilidade; `{ w: 1 }` só para dados toleráveis a perda (logs).
6. **Sem arrays unbounded** — embed limita ~100 subdocs; acima, referencie. 16MB é limite rígido.

> Código pronto para commit. Para design de schema detalhado, ver `reference/schema-design.md`.

## Versão / Stack Canônica

- **MongoDB 8+** (última estável; ADR-012 fixa 7+ como piso). Atlas para managed.
- Driver/ODM: **Mongoose 8** + Node driver 6 (Node/TS), **Beanie + Motor** (Python), **mongo-driver** (Go), Spring Data (Java).
- Migrations: migrate-mongo (Node) / Mongock (multi-lang) / atlas-cli.
- Testes: testcontainers (`mongo:8.0`) + mongodb-memory-server.

> Stack completa, versões e `mongod.conf` em `reference/stack.md`.

## Padrões Obrigatórios

- **Schema validation**: `db.createCollection()` com `validator` (`$jsonSchema`) — nunca schemaless em produção. Em coleção existente: `moderate`+`warn` → `strict`+`error`.
- **Connection pooling**: reutilize connections, configure `maxPoolSize`/`minPoolSize`.
- **Read preference** explícito por query: `primary` | `primaryPreferred` | `secondaryPreferred` | `nearest`.
- **Write concern** explícito: `{ w: "majority", j: true }` para durabilidade.
- **Transactions** só quando necessário (escrita em múltiplas coleções). Documento é atômico por natureza — prefira embed/reference estratégico.
- **TTL indexes** para dados temporários: sessions, logs, tokens (`expireAfterSeconds`).
- **Índices**: `explain("executionStats")` por query crítica. Compound respeitando **ESR** (Equality → Sort → Range). Covered queries via projection coberta pelo índice.
- **Replica set** sempre (mínimo 3 nós em produção). Sharding quando >1TB ou write throughput > single shard.

## Schema Design (decisão rápida)

| Relação | Cardinalidade | Decisão |
|---|---|---|
| 1:1 sempre junto | — | **Embed** (subdocumento) |
| 1:few (≤~100, junto) | 1:N | **Embed array** (com `maxItems`) |
| 1:many (unbounded/independente) | 1:N | **Reference** + índice no FK |
| M:N | M:N | **Reference**; embed na direção primária de query |

- **Subset/hot-cold**: hot fields no doc principal, cold em coleção separada — densidade de cache.
- **Extended reference**: cache de campos de exibição (name, status) para evitar `$lookup`; sync via `updateMany`/`cachedAt`.
- **Bucket / time series**: séries temporais → time series collection (bucketing + compressão automáticos; 8.0 acelera analítico).
- **Attribute**: muitos campos opcionais → array `{k,v}` + multikey index (evita N índices parciais).
- **Polymorphic**: tipos relacionados em uma coleção com discriminador `type`.
- **Outlier / Archive / Computed / Approximation / Versioning**: ver `reference/schema-design.md`.

## Anti-padrões Críticos

- ❌ Schema sem `validator` em produção.
- ❌ Arrays unbounded (embed sem limite) — reference acima de ~100 subdocs.
- ❌ Índice sem query justificada; índice redundante (prefixo de composto). Remova com **hide → monitor → drop**.
- ❌ `$where` (sempre COLLSCAN, injeção, deprecado 5.1+) — use operadores nativos.
- ❌ MapReduce — use aggregation pipeline.
- ❌ `findOne` em loop (N+1) — use `$in` ou `$lookup`.
- ❌ `ObjectId` armazenado como string (comparação falha, índice ineficiente).
- ❌ Coleção como substituto de índice (uma por dia/tenant) — uma coleção + índice.
- ❌ `$lookup` excessivo em hot path — denormalize (meça antes).
- ❌ `{ w: 1 }` em dado financeiro/crítico — `{ w: "majority", j: true }`.

## Workflow Agentic

1. **Entender o acesso** — quais endpoints/páginas, o que cada um retorna, read vs write frequency.
2. **Decidir embed vs reference** por padrão de acesso (não por cardinalidade isolada).
3. **Definir `validator`** (`$jsonSchema`, required, enum, `maxItems`).
4. **Gerar** schema/model + repository + queries/aggregation + índices justificados.
5. **`explain()`** as queries críticas; ajustar índices (ESR).
6. **Testar** com testcontainers (`mongo:8.0`).
7. **Apresentar diff** — arquivos criados/editados + decisão de modelagem e porquê.

## Checklist

- [ ] `validator` com `$jsonSchema` definido (required, enum, `maxItems`)
- [ ] Embed vs reference decidido por padrão de acesso
- [ ] Sem arrays unbounded (limite ou coleção separada)
- [ ] Índices justificados com `explain()` (ESR; sem redundantes)
- [ ] Connection pooling (`maxPoolSize`/`minPoolSize`)
- [ ] Write concern / read preference explícitos
- [ ] TTL para dados temporários
- [ ] Backup (Atlas snapshots ou `mongodump` + oplog) e monitoring (Atlas / Prometheus)
- [ ] Shard key escolhido se escala horizontal necessária

## Quando Perguntar

Antes de codar: padrões de acesso (o que é lido junto)? volume e crescimento esperado? consistência forte necessária? dado sensível (CSFLE)? escala horizontal (sharding)?

## Referências (sob demanda — progressive disclosure)

Leia conforme a tarefa (não entram no contexto automaticamente):

- **`reference/core.md`** — Snippets prontos: Mongoose+TS, repository, aggregation, Beanie, índices, testcontainers, anti-patterns. Leia antes de gerar código.
- **`reference/schema-design.md`** — Design de schema (fundamentos, patterns e anti-padrões oficiais MongoDB): embed vs reference, relacionamentos, validation, tamanho de doc, bucket, attribute, polymorphic, outlier, archive, computed, time series, versioning. Leia ao modelar/revisar schema.
- **`reference/stack.md`** — Stack canônica: versões, drivers, migrations, `mongod.conf`. Leia ao configurar projeto novo.

## Cross-references

- `security-expert` — auth (SCRAM/X.509), TLS, secrets, CSFLE, encryption at rest.
- Skills de backend (golang/node) — driver e camada de aplicação.

## Segurança (Baseline Compartilhado)

Regras universais em `reference/security-baseline.md`. Ameaças específicas do domínio MongoDB:

- **Auth sempre**: SCRAM ou X.509 — nunca produção sem auth. RBAC com privilégio mínimo (`readWrite`, `dbAdmin`, `clusterAdmin`).
- **TLS/SSL obrigatório**: `net.tls.mode: requireTLS`. `bindIp` nunca `0.0.0.0` sem auth.
- **Encryption at rest**: Atlas encryption ou WiredTiger encryption. **CSFLE** (field-level) para dados sensíveis (CPF, cartão).
- **Network isolation**: VPC peering, private endpoints, IP allowlist restritiva.
- **Audit log**: Atlas audit log ou `--auditDestination`.
- **Connection string** com auth e `authSource`; secret em vault, nunca em código/log.

> **Atenção**: esta skill cobre a parte **MongoDB** do ADR-012. Para busca full-text/analytics use Elasticsearch; para enterprise search com faceting use Solr — não usar MongoDB como search engine.
