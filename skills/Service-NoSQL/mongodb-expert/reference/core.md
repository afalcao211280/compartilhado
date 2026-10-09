# MongoDB Expert — Padrões de Código

Snippets prontos para produção. Para design de schema (embed vs reference, patterns, anti-patterns), ver `schema-design.md`.

## Índice
1. Mongoose Schema + TypeScript (Node)
2. Repository Pattern (Node/TypeScript)
3. Aggregation Pipeline
4. Beanie ODM (Python + FastAPI)
5. Design de Schema — Decisões
6. Índices — Estratégia
7. Testcontainers (Node/TypeScript)
8. Anti-patterns

## 1. Mongoose Schema + TypeScript (Node)

```typescript
// src/models/user.model.ts
import { Schema, model, Document, type InferSchemaType } from 'mongoose';

const userSchema = new Schema(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      match: [/^\S+@\S+\.\S+$/, 'Email inválido'],
    },
    name: { type: String, required: true, minlength: 2, maxlength: 100, trim: true },
    passwordHash: { type: String, required: true, select: false }, // nunca retornar por padrão
    role: { type: String, enum: ['admin', 'editor', 'viewer'], default: 'viewer' },
    active: { type: Boolean, default: true },
    metadata: { type: Schema.Types.Mixed },
  },
  {
    timestamps: true, // createdAt + updatedAt automáticos
    versionKey: false,
    toJSON: {
      transform: (_doc, ret) => {
        ret['id'] = ret['_id'];
        delete ret['_id'];
        delete ret['passwordHash'];
      },
    },
  },
);

// Índices
userSchema.index({ createdAt: -1 });
userSchema.index({ active: 1, createdAt: -1 });

export type UserDocument = Document & InferSchemaType<typeof userSchema>;
export const UserModel = model<UserDocument>('User', userSchema);
```

---

## 2. Repository Pattern (Node/TypeScript)

```typescript
// src/repositories/user.repository.ts
import type { FilterQuery } from 'mongoose';
import { UserModel, type UserDocument } from '@/models/user.model';

export class UserRepository {
  async findById(id: string): Promise<UserDocument | null> {
    return UserModel.findById(id);
  }

  async findByEmail(email: string): Promise<UserDocument | null> {
    return UserModel.findOne({ email: email.toLowerCase() }).select('+passwordHash');
  }

  async existsByEmail(email: string): Promise<boolean> {
    return UserModel.exists({ email: email.toLowerCase() }).then(Boolean);
  }

  async create(data: { name: string; email: string; passwordHash: string }): Promise<UserDocument> {
    return UserModel.create(data);
  }

  async findPaginated(
    filter: FilterQuery<UserDocument>,
    page: number,
    limit: number,
  ): Promise<{ items: UserDocument[]; total: number }> {
    const [items, total] = await Promise.all([
      UserModel.find(filter)
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit),
      UserModel.countDocuments(filter),
    ]);
    return { items, total };
  }

  async updateById(id: string, data: Partial<UserDocument>): Promise<UserDocument | null> {
    return UserModel.findByIdAndUpdate(id, { $set: data }, { new: true, runValidators: true });
  }
}
```

---

## 3. Aggregation Pipeline

```typescript
// Agregação: usuários ativos com contagem de pedidos no último mês
const result = await UserModel.aggregate([
  // Stage 1: Filtrar usuários ativos
  { $match: { active: true } },

  // Stage 2: Lookup (join) com collection orders
  {
    $lookup: {
      from: 'orders',
      let: { userId: '$_id' },
      pipeline: [
        {
          $match: {
            $expr: { $eq: ['$userId', '$$userId'] },
            status: 'completed',
            createdAt: { $gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) },
          },
        },
      ],
      as: 'recentOrders',
    },
  },

  // Stage 3: Adicionar campo calculado
  { $addFields: { orderCount: { $size: '$recentOrders' } } },

  // Stage 4: Filtrar apenas com pedidos
  { $match: { orderCount: { $gt: 0 } } },

  // Stage 5: Projetar campos de saída
  {
    $project: {
      _id: 0,
      id: '$_id',
      name: 1,
      email: 1,
      orderCount: 1,
    },
  },

  // Stage 6: Ordenar
  { $sort: { orderCount: -1 } },

  // Stage 7: Paginação
  { $limit: 20 },
]);
```

---

## 4. Beanie ODM (Python + FastAPI)

```python
# models/user.py
from beanie import Document, Indexed
from pydantic import EmailStr, Field
from datetime import datetime, timezone
from typing import Optional

class User(Document):
    email: Indexed(EmailStr, unique=True)  # type: ignore[valid-type]
    name: str = Field(..., min_length=2, max_length=100)
    password_hash: str = Field(exclude=True)  # não serializa
    role: str = Field(default="viewer", pattern="^(admin|editor|viewer)$")
    active: bool = True
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "users"
        indexes = [
            [("active", 1), ("created_at", -1)],
        ]

# main.py — inicialização
from beanie import init_beanie
from motor.motor_asyncio import AsyncIOMotorClient

async def init_db():
    client = AsyncIOMotorClient(settings.MONGODB_URI)
    await init_beanie(database=client.db_name, document_models=[User])
```

---

## 5. Design de Schema — Decisões

```typescript
// EMBED quando: dados são acessados sempre juntos, não crescem ilimitadamente
// Exemplo: endereços de um usuário (máx. 5)
const userSchema = new Schema({
  name: String,
  addresses: [{
    type: { type: String, enum: ['home', 'work', 'other'] },
    street: String,
    city: String,
    primary: Boolean,
  }],
});

// REFERENCE quando: dados são grandes, acessados independentemente ou têm muitos
// Exemplo: pedidos de um usuário (podem ser milhares)
const orderSchema = new Schema({
  userId: { type: Schema.Types.ObjectId, ref: 'User', index: true },
  items: [{ productId: Schema.Types.ObjectId, quantity: Number, price: Number }],
  total: Number,
  status: String,
}, { timestamps: true });

// TTL Index — deletar automaticamente após N segundos
const sessionSchema = new Schema({
  userId: Schema.Types.ObjectId,
  token: String,
  createdAt: { type: Date, default: Date.now, expires: 86400 }, // 24h
});
```

---

## 6. Índices — Estratégia

```javascript
// Compound index — campo de maior seletividade primeiro
db.orders.createIndex({ userId: 1, status: 1, createdAt: -1 });

// Text index para busca full-text
db.products.createIndex({ name: 'text', description: 'text' }, { weights: { name: 3, description: 1 } });

// Partial index — apenas docs que satisfazem a condição
db.users.createIndex(
  { email: 1 },
  { partialFilterExpression: { active: true } }
);

// Sparse index — apenas docs com o campo presente
db.users.createIndex({ deletedAt: 1 }, { sparse: true });

// Ver uso de índices
db.orders.aggregate([{ $indexStats: {} }]);
```

---

## 7. Testcontainers (Node/TypeScript)

```typescript
// src/tests/setup.ts
import { MongoDBContainer, type StartedMongoDBContainer } from '@testcontainers/mongodb';
import mongoose from 'mongoose';

let container: StartedMongoDBContainer;

beforeAll(async () => {
  container = await new MongoDBContainer('mongo:8.0').start();
  await mongoose.connect(container.getConnectionString(), { directConnection: true });
}, 60_000);

afterAll(async () => {
  await mongoose.disconnect();
  await container?.stop();
});

afterEach(async () => {
  // Limpar todas as collections entre testes
  const collections = mongoose.connection.collections;
  for (const key in collections) {
    await collections[key]?.deleteMany({});
  }
});
```

---

## 8. Anti-patterns

### ❌ Arrays ilimitados em documentos
**Problema:** O desenvolvedor embute uma lista que cresce sem limite dentro do documento (ex: `user.comments`, `post.likes`).
**Por quê evitar:** Documentos MongoDB têm limite de 16 MB; arrays que crescem indefinidamente degradam performance de leitura e escrita e eventualmente estouam esse limite.
**Solução:**
```javascript
// Errado — array cresce para sempre
await User.updateOne({ _id: userId }, { $push: { comments: newComment } });

// Correto — use uma collection separada ou bucketing
const commentSchema = new Schema({
  userId: { type: Schema.Types.ObjectId, ref: 'User', index: true },
  text: String,
  createdAt: { type: Date, default: Date.now },
});
// Insira em sua própria collection; use $lookup quando necessário
```

---

### ❌ `findOne` em loop (problema N+1)
**Problema:** O desenvolvedor chama `findOne` dentro de um `for` para buscar documentos relacionados, gerando N round trips ao banco.
**Por quê evitar:** Cada iteração abre uma conexão de rede separada; para N=100 documentos, o tempo de resposta aumenta linearmente com a latência de rede.
**Solução:**
```typescript
// Errado — N round trips
for (const order of orders) {
  order.user = await UserModel.findById(order.userId); // N consultas
}

// Correto — 1 round trip com $in
const userIds = orders.map((o) => o.userId);
const users = await UserModel.find({ _id: { $in: userIds } });
const userMap = new Map(users.map((u) => [u._id.toString(), u]));
for (const order of orders) {
  order.user = userMap.get(order.userId.toString());
}
```

---

### ❌ Queries sem índice (COLLSCAN)
**Problema:** O desenvolvedor executa queries em campos sem índice, forçando o MongoDB a escanear toda a collection.
**Por quê evitar:** Um COLLSCAN em uma collection com milhões de documentos pode levar segundos e bloquear outros clientes; uso de CPU e I/O disparam.
**Solução:**
```javascript
// Verificar se a query usa índice
db.orders.find({ userId: ObjectId("..."), status: "pending" }).explain("executionStats");
// IXSCAN no campo correto — criar índice composto
db.orders.createIndex({ userId: 1, status: 1, createdAt: -1 });
```

---

### ❌ ObjectId armazenado como string
**Problema:** O desenvolvedor persiste o `_id` como `"507f1f77bcf86cd799439011"` (string) em vez de usar o tipo nativo `ObjectId`.
**Por quê evitar:** Comparações entre ObjectId e string falham silenciosamente, índices perdem eficiência e ocupa mais espaço (24 bytes string vs 12 bytes BSON).
**Solução:**
```typescript
import { Types } from 'mongoose';

// Errado
const userId = '507f1f77bcf86cd799439011'; // string
await Order.find({ userId }); // não encontra nada se userId é ObjectId no schema

// Correto
const userId = new Types.ObjectId('507f1f77bcf86cd799439011');
await Order.find({ userId });
```

---

### ❌ Uso de `$where` com JavaScript
**Problema:** O desenvolvedor usa `$where: "this.price > 100"` para filtros dinâmicos.
**Por quê evitar:** Expressões `$where` desabilitam o uso de índices (sempre COLLSCAN), executam código JavaScript no servidor, são vetores de injeção e foram depreciadas no MongoDB 5.1+.
**Solução:**
```javascript
// Errado
db.products.find({ $where: "this.price > 100 && this.active == true" });

// Correto — use operadores nativos que aproveitam índices
db.products.find({ price: { $gt: 100 }, active: true });
```

---

### ❌ Transações para toda operação
**Problema:** O desenvolvedor envolve cada operação CRUD em uma transação multi-documento, mesmo quando o escopo é um único documento.
**Por quê evitar:** Transações adicionam overhead de coordenação entre nós (dois round trips de lock), aumentam latência e reduzem throughput; documentos MongoDB são atômicos por natureza.
**Solução:**
```typescript
// Errado — transação desnecessária para atualizar um documento
const session = await mongoose.startSession();
session.startTransaction();
await UserModel.findByIdAndUpdate(id, { $set: { name } }, { session });
await session.commitTransaction();

// Correto — operação atômica nativa; sem overhead de transação
await UserModel.findByIdAndUpdate(id, { $set: { name } }, { new: true, runValidators: true });

// Reserve transações para escrita em múltiplas collections
// ex: debitar conta A e creditar conta B ao mesmo tempo
```

---

### ❌ Documentos profundamente aninhados (>3 níveis)
**Problema:** O desenvolvedor modela dados com hierarquias como `org.department.team.member.profile`, tornando atualizações pontuais complexas.
**Por quê evitar:** Atualizações exigem caminhos como `$set: { "org.department.team.member.profile.email": "..." }`, que são frágeis, difíceis de indexar e propensos a erros silenciosos de tipagem.
**Solução:**
```typescript
// Errado — aninhamento profundo
const orgSchema = new Schema({
  name: String,
  department: { team: { member: { profile: { email: String } } } },
});

// Correto — achatar ou referenciar
const memberSchema = new Schema({
  orgId: { type: Schema.Types.ObjectId, ref: 'Org', index: true },
  teamId: { type: Schema.Types.ObjectId, ref: 'Team', index: true },
  email: String, // campo de primeiro nível — fácil de indexar e atualizar
});
```

---

### ❌ Omitir `writeConcern: "majority"` em dados financeiros
**Problema:** O desenvolvedor usa o `writeConcern` padrão (`w: 1`) para gravar transações financeiras ou dados críticos.
**Por quê evitar:** Com `w: 1`, o dado é confirmado apenas no primary; se o primary falhar antes de replicar, a escrita pode ser perdida em um failover, causando inconsistência financeira.
**Solução:**
```typescript
await PaymentModel.create(
  [{ orderId, amount, status: 'confirmed' }],
  {
    // Aguarda confirmação da maioria dos nós antes de retornar
    writeConcern: { w: 'majority', j: true },
  }
);
```
