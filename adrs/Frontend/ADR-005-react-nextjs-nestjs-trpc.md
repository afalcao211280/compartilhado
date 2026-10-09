# ADR-005: React + Next.js + NestJS + tRPC — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Projetos fullstack frontend na EVEO exigem uma arquitetura unificada que garanta type-safety end-to-end, SSR/SSG performático, BFF robusto e monorepo escalável. A ausência de padronização gera inconsistências entre projetos, duplicação de tipos entre frontend e backend, e dificuldade de manutenção.

## Decisão

Adotar a stack fullstack frontend monorepo com Next.js 15 (App Router, RSC, Server Actions) como frontend, NestJS como BFF/API layer, e tRPC 11 como ponte type-safe entre ambos. React 19 como biblioteca base. Zod 4 para validação compartilhada. pnpm 10 + Turborepo 2 como infra de monorepo.

Server Components por padrão. `'use client'` apenas quando interatividade exige. O monorepo compartilha schemas Zod e tipos entre apps/web e apps/api via packages/shared.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| Framework Frontend | Next.js | 15 (App Router) | Remix, Astro | RSC, Server Actions, caching granular, ecosistema |
| Biblioteca UI | React | 19 | Vue, Svelte | RSC, ecosystem, hiring pool |
| BFF/API | NestJS | 10+ | Express, Fastify | Modular, decorators, Swagger automático |
| Type-safe API | tRPC | 11 | GraphQL, REST manual | Type inference end-to-end, sem codegen |
| Validação | Zod | 4 | Yup, Joi | Inferência de tipos, compartilhável via monorepo |
| Client State | TanStack Query | v5 | SWR, RTK Query | Cache, refetch, optimistic updates |
| Forms | React Hook Form | 8 | Formik, Conform | Performance (uncontrolled), Zod integration |
| Estilos | Tailwind CSS | 3.4 | CSS Modules, Styled Components | Utility-first, JIT, design tokens |
| Monorepo | pnpm + Turborepo | 10 / 2 | Nx, Lerna | Workspaces, caching, pipelines |
| ORM (NestJS) | TypeORM ou Prisma | — | Drizzle, MikroORM | Perguntar ao usuário (TypeORM para complexidade, Prisma para DX) |
| Auth | next-auth v5 | v5 | Custom JWT, Lucia | SSR-compatible, providers, callbacks |
| Testes Unit | Vitest + RTL | — | Jest | Velocidade, ESM nativo |
| Testes E2E | Playwright | — | Cypress | Multi-browser, trace, auto-wait |
| Lint | ESLint + Prettier | — | Biome | Ecosistema, plugins |

## Padrões Obrigatórios

- **Server Components por default**. `'use client'` apenas com event handlers, hooks, ou browser APIs
- **Server Actions** para mutations com validação Zod obrigatória
- **tRPC router** no NestJS como procedural layer type-safe; expor também Swagger/OpenAPI para consumidores externos
- **Monorepo structure**: `apps/web` (Next.js), `apps/api` (NestJS), `packages/shared` (schemas Zod, tipos, utils)
- **Zod schemas** como single source of truth para validação — frontend e backend derivam tipos de `packages/shared`
- **`loading.tsx`** em cada route segment — nunca tela em branco
- **`error.tsx`** em cada route segment — error boundary automático
- **Metadata API** para SEO — nunca `<head>` manual
- **`next/image`** para todas as imagens — nunca `<img>`
- **Auth verification** em Server Actions: `const session = await auth()`
- **CSRF protection** via Server Actions (nativo); Route Handlers exigem middleware customizado
- **Environment isolation**: `NEXT_PUBLIC_` apenas para valores públicos; secrets ficam no servidor
- **NestJS module-per-feature**: não criar God modules; exports apenas o que outros módulos consomem
- **NestJS DTOs**: input/output separados; `class-validator` + `class-transformer` para validação
- **NestJS Repository Pattern**: Service → Repository → Entity; nunca ORM calls diretas no Service

## Estrutura de Projeto

```
monorepo/
├── apps/
│   ├── web/                          # Next.js 15 (App Router)
│   │   ├── src/
│   │   │   ├── app/
│   │   │   │   ├── layout.tsx         # Root layout
│   │   │   │   ├── page.tsx           # Home
│   │   │   │   ├── loading.tsx
│   │   │   │   ├── error.tsx
│   │   │   │   ├── not-found.tsx
│   │   │   │   ├── (auth)/
│   │   │   │   │   ├── login/page.tsx
│   │   │   │   │   └── register/page.tsx
│   │   │   │   └── dashboard/
│   │   │   │       ├── page.tsx
│   │   │   │       └── [id]/page.tsx
│   │   │   ├── components/
│   │   │   │   ├── ui/                # Primitivos (Button, Input, etc.)
│   │   │   │   └── features/          # Componentes de domínio
│   │   │   ├── lib/
│   │   │   │   ├── auth.ts
│   │   │   │   └── utils.ts
│   │   │   ├── server/
│   │   │   │   ├── actions/           # Server Actions
│   │   │   │   └── queries/           # Data fetchers
│   │   │   └── types/
│   │   ├── next.config.ts
│   │   ├── tailwind.config.ts
│   │   └── package.json
│   └── api/                           # NestJS BFF
│       ├── src/
│       │   ├── modules/
│       │   │   └── user/
│       │   │       ├── user.module.ts
│       │   │       ├── user.controller.ts
│       │   │       ├── user.service.ts
│       │   │       ├── user.repository.ts
│       │   │       └── dto/
│       │   │           ├── create-user.dto.ts
│       │   │           └── user-response.dto.ts
│       │   ├── trpc/
│       │   │   ├── trpc.module.ts
│       │   │   └── routers/
│       │   │       └── user.router.ts
│       │   ├── common/
│       │   │   ├── filters/
│       │   │   ├── guards/
│       │   │   ├── interceptors/
│       │   │   └── decorators/
│       │   └── config/
│       └── package.json
├── packages/
│   └── shared/
│       ├── src/
│       │   ├── schemas/               # Zod schemas (single source of truth)
│       │   │   ├── user.schema.ts
│       │   │   └── auth.schema.ts
│       │   ├── types/                 # Tipos derivados dos schemas
│       │   │   └── index.ts           # z.infer<typeof ...>
│       │   └── utils/
│       └── package.json
├── turbo.json
├── pnpm-workspace.yaml
└── package.json
```

## Anti-padrões

| Proibido | Alternativa |
|---|---|
| `'use client'` desnecessário | Server Component |
| `fetch` em `useEffect` no client | Server Component data fetch ou TanStack Query |
| Prop drilling profundo (>2 níveis) | Context / Zustand / composition |
| `useEffect` para buscar dados | TanStack Query v5 |
| Tipos duplicados entre frontend e backend | `packages/shared` com Zod schemas |
| `any` type | `unknown` + type guards / Zod inference |
| Inline styles dinâmicos | Tailwind classes / design tokens |
| Business logic em Route Handlers | Server Actions |
| God modules no NestJS | Module-per-feature |
| ORM calls diretas no Service | Repository Pattern |
| REST manual quando frontend e backend são do mesmo monorepo | tRPC para type-safety |
| `index` como key em listas | ID estável |
| `// @ts-ignore` | Corrigir o tipo |

## Consequências

**Positivas**:
- Type-safety end-to-end: frontend e backend compartilham tipos via `packages/shared` e tRPC
- SSR/SSG/ISR configurável por rota com App Router
- Monorepo com caching Turborepo reduz build times
- Zod como single source of truth elimina drift de validação
- NestJS BFF centraliza auth, rate limiting, composição de APIs

**Negativas**:
- Complexidade inicial do monorepo (setup Turborepo + pnpm workspaces)
- Curva de aprendizado: tRPC + Zod + Server Actions + App Router
- NestJS como BFF adiciona uma camada — pode ser over-engineering para projetos simples
- Hot reload em monorepo requer configuração cuidadosa

**Riscos**:
- Over-engineering em projetos pequenos — NestJS BFF pode ser substituído por Route Handlers diretos
- Version mismatch entre `packages/shared` e consumidores se não houver discipline no versionamento
- TypeORM vs Prisma é decisão crítica que impacta toda a arquitetura do BFF — **perguntar ao usuário**

## Referências

- `skills/Frontend/nextjs-expert/SKILL.md`
- `skills/Frontend/react-expert/SKILL.md`
- `skills/Backend/nestjs-expert/SKILL.md`
- `skills/Frontend/css-expert/SKILL.md`
- `skills/Frontend/typescript-expert/SKILL.md`
- Documentação Next.js App Router: https://nextjs.org/docs/app
- Documentação tRPC v11: https://trpc.io
- Documentação NestJS: https://docs.nestjs.com
- Documentação Zod: https://zod.dev