# MongoDB Expert — Stack Canônica

## MongoDB 8.0+ — Versão Canônica EVEO

> ADR-012 fixa "MongoDB 7+" como piso. Alvo atual: **8.0+** (última estável). 8.0 traz block processing em time series (até +200% em pipelines analíticos), melhorias de query e sharding. Mongoose 8 + driver Node 6 são compatíveis.

| Categoria | Lib/Ferramenta | Versão | Link | Notas |
|-----------|---------------|--------|------|-------|
| **Core** | | | | |
| Banco | MongoDB | 8.0.x | https://mongodb.com | 8.0: última estável. Atlas: cloud gerenciado |
| Cloud | MongoDB Atlas | — | https://cloud.mongodb.com | Padrão para produção cloud |
| **ODM / Driver** | | | | |
| ODM (Node/TS) | Mongoose | 8.x | https://mongoosejs.com | Schema + validação. Padrão EVEO Node |
| ODM (Node/TS) alt | Typegoose | 12.x | https://typegoose.github.io/typegoose | TypeScript-first sobre Mongoose |
| Driver (Node) | MongoDB Node Driver | 6.x | https://mongodb.github.io/node-mongodb-native | Subjacente ao Mongoose |
| ODM (Python) | Beanie | 1.26+ | https://beanie-odm.dev | Async, Pydantic v2, Motor |
| Driver (Python) | Motor | 3.x | https://motor.readthedocs.io | Async driver (asyncio) |
| Driver (Python) sync | PyMongo | 4.7+ | https://pymongo.readthedocs.io | Sync. Use com threads |
| ODM (Java) | Spring Data MongoDB | 4.3+ | https://spring.io/projects/spring-data-mongodb | `@Document` entities |
| ODM (.NET) | MongoDB.Driver | 2.28+ | https://mongodb.github.io/mongo-csharp-driver | |
| ODM (Go) | mongo-driver | 1.15+ | https://pkg.go.dev/go.mongodb.org/mongo-driver | Oficial MongoDB |
| **Schema Validation** | | | | |
| App-level | Mongoose Schema / Beanie | built-in | — | Validação na camada de aplicação |
| DB-level | MongoDB JSON Schema Validator | built-in | — | `$jsonSchema` em `validator` |
| **Migrations** | | | | |
| Node | Migrate Mongo | 10.x | https://github.com/seppevs/migrate-mongo | Simples, baseado em arquivos JS |
| Multi-lang | Mongock | 5.x | https://mongock.io | Spring-friendly. Migrações como código |
| **Testes** | | | | |
| Containers | testcontainers (mongodb) | multi-lang | https://testcontainers.com | `mongo:8.0` image |
| In-memory | mongodb-memory-server | 10.x | https://github.com/nodkz/mongodb-memory-server | Para testes rápidos Node |
| **Cache** | | | | |
| TTL Index | MongoDB TTL Index | built-in | — | `expireAfterSeconds` para auto-delete |
| **Monitoramento** | | | | |
| Atlas | Atlas Performance Advisor | built-in | — | Missing indexes, slow queries |
| Self-hosted | `db.setProfilingLevel()` | built-in | — | Nível 1: queries > 100ms |
| Ops Manager | MongoDB Ops Manager | — | — | On-prem monitoring |
| **Replicação / HA** | | | | |
| Replica Set | MongoDB Replica Set | built-in | — | Mínimo 3 nós em produção |
| Sharding | MongoDB Sharded Cluster | built-in | — | Para datasets > 1TB ou alta escrita |

## Configuração — mongod.conf (Self-hosted)

```yaml
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1  # 50% da RAM disponível para MongoDB

net:
  port: 27017
  bindIp: 127.0.0.1  # Nunca 0.0.0.0 sem autenticação

security:
  authorization: enabled

operationProfiling:
  slowOpThresholdMs: 100
  mode: slowOp

replication:
  replSetName: "rs0"  # Sempre usar replica set, mesmo em dev
```
