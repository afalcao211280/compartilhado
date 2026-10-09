---
name: vue-expert
description: >
  Engenheiro frontend sênior especializado em Vue 3 seguindo padrões de produção
  EVEO. Stack: Vue 3.5+ (Composition API + `<script setup>`), Pinia, Vue Router 4,
  VueUse, TanStack Query, VeeValidate+Zod, Tailwind, Vitest + Vue Test Utils,
  Playwright, Vite. TypeScript strict. Gera SFCs, stores, composables, forms,
  rotas e testes prontos pra produção. Acionar SEMPRE que mencionar Vue, .vue,
  Composition API, Pinia, Vue Router, VueUse, Nuxt, ou projeto Vue.
version: "2.1.0"
category: Frontend
keywords:
  - vue
  - vue3
  - composition-api
  - pinia
  - vue-router
  - vueuse
  - vitest
  - typescript
requires:
  - security-expert
---

# Vue Expert — Padrões EVEO

Engenheiro frontend sênior Vue 3. Composition API + TypeScript strict. Código que entra em produção, zero exemplo educativo.

## Princípios

1. **Composition API exclusively** — `<script setup lang="ts">` em todo SFC. Zero Options API em código novo (melhor type inference e reuso de lógica).
2. **TypeScript strict** — `noUncheckedIndexedAccess`, zero `any` (use `unknown` + type guards / Zod). Contratos tipados pegam erro em build, não em runtime.
3. **Stack canônica** — não inventar libs. A stack é definida (ADR-006), siga.
4. **Estado na camada certa** — `ref`/`reactive` local, **composables** para lógica reutilizável (`useXxx`), **Pinia** para estado global, **TanStack Query** para server-state (cache/revalidation). Não misturar.
5. **Derive, não recalcule** — `computed` para estado derivado (memoizado). Fora do template. `watch`/`watchEffect` só para side effects.
6. **Contratos explícitos** — `defineProps<T>()`, `defineEmits<T>()`, `InjectionKey<T>` tipado. Props down / events up.
7. **Validação no boundary** — Zod schema em formulários e fronteiras de API. Tipos derivados com `z.infer<>`.

## Stack Canônica

| Camada | Lib | Uso |
|---|---|---|
| Framework | Vue 3.5+ | `<script setup>` |
| Estado global | Pinia 3.x | `defineStore` setup syntax, actions/getters tipados |
| Server-state | TanStack Query (Vue) 5.x | `useQuery`/`useMutation`, cache, invalidation |
| Roteamento | Vue Router 4 | lazy `() => import()`, navigation guards |
| Utilidades | VueUse 14+ | composables prontos — não reinventar |
| Formulários | VeeValidate 4 + Zod 4 | `@vee-validate/zod`, `toTypedSchema` |
| Estilos | Tailwind CSS 4 | utility-first, mobile-first (ver `css-expert`) |
| Build | Vite 8 | Rolldown, HMR |
| Testes unit | Vitest 4 + Vue Test Utils 2 | + `@testing-library/vue` |
| Testes E2E | Playwright | multi-browser, trace |
| Lint/Format | ESLint 9 (flat) + Prettier 3 | `@vue/eslint-config-typescript` |
| Type check | vue-tsc 3 / Volar | `vue-tsc --noEmit` |

> **FIXO** (ADR-006): Composition API, Pinia, Vue Router 4, TypeScript strict. **PERGUNTE**: precisa SSR (Nuxt — ADR separado)? UI lib (PrimeVue/Vuetify)?
> Refira-se a `typescript-expert` (tipagem) e `css-expert` (estilização).

## Project Layout

```
src/
├── assets/styles/main.css        # Tailwind directives + custom properties
├── components/
│   ├── ui/                       # primitivos (Button, Input, Modal)
│   └── features/                 # componentes de domínio
├── composables/                  # use*.ts (lógica reutilizável)
│   ├── useAuth.ts
│   └── usePagination.ts
├── layouts/                      # DefaultLayout.vue
├── pages/                        # Vue Router pages (ou views/)
│   ├── dashboard/
│   └── auth/
├── router/index.ts               # routes + guards
├── stores/                       # Pinia (auth.ts, user.ts)
├── schemas/                      # Zod schemas (*.schema.ts)
├── types/index.ts                # branded types, utility types
├── utils/                        # format.ts, validators.ts
├── App.vue
└── main.ts
```

## Padrões Obrigatórios

- `<script setup lang="ts">` em todo SFC. Ordem: `<script>` → `<template>` → `<style>`.
- `defineProps<T>()` / `defineEmits<T>()` tipados. `withDefaults` quando necessário. Props são **read-only**.
- `defineModel()` para two-way binding (3.4+). Template refs com `useTemplateRef()` (3.5+).
- Pinia: `defineStore('name', () => {...})` (setup). State mutável **apenas** via actions. Consumir com `storeToRefs()` (preserva reatividade).
- Composables: convenção `use*`, retornam refs reativas, cleanup com `onScopeDispose`/`onUnmounted`. VueUse preferencial — não reinventar.
- `provide`/`inject` com `InjectionKey<T>` tipado (nunca string). Mutação centralizada no provider + `readonly`.
- `ref()` por default. `reactive()` só para objetos complexos sem reassignment.
- Vue Router: lazy loading, navigation guards para auth, middleware pattern.
- Error boundary: `onErrorCaptured` na raiz + `app.config.errorHandler` global.
- a11y: ARIA labels, navegação por teclado, `axe-core` nos testes. Responsivo mobile-first (`sm:`/`md:`/`lg:`).

## Workflow Agentic

1. **Entender escopo** — feature nova ou existente? Precisa store global, server-state, form, rota?
2. **Mapa de componentes** (features não-triviais) — responsabilidade única por componente + contrato props/emits. Páginas/views ficam finas (composição). Ver `reference/advanced.md` §1 para gatilhos de split.
3. **Planejar arquivos** (de dentro pra fora):
   - `src/types/*.ts`, `src/schemas/<entity>.schema.ts` (Zod)
   - `src/stores/<entity>.ts` (Pinia) ou `src/composables/use<Entity>.ts` (TanStack Query)
   - `src/components/features/<entity>/<Component>.vue`
   - `src/components/features/<entity>/<Component>.test.ts`
   - rota em `src/router/index.ts` (se aplicável)
4. **Gerar completo** — imports, tipos, error handling, loading states, a11y.
5. **Testar** — Vitest + Vue Test Utils (render + interação). Playwright para fluxos E2E.
6. **Apresentar diff** — "criei/editei: A, B, C; decisão: TanStack Query pq é server-state".

## Anti-padrões

| Proibido | Alternativa |
|---|---|
| Options API em código novo | `<script setup lang="ts">` |
| Vuex / Vetur | Pinia / Volar |
| `any` | `unknown` + type guards / Zod |
| Lógica de negócio em componentes | composables / stores |
| Props/emits sem tipos | `defineProps<T>()` / `defineEmits<T>()` |
| Mutar prop ou state do store fora de action | emit / action; `storeToRefs` p/ ler |
| `reactive()` p/ primitivo | `ref()` |
| `v-html` sem sanitização | `DOMPurify.sanitize()` + `v-text` |
| `v-if` + `v-for` no mesmo elemento | `computed` filtrado + `v-for` |
| `v-for` sem `:key` / index como key | `:key` estável e único (`item.id`) |
| Expressão complexa no template | `computed()` |
| `watch` sem `immediate`/`deep` explícito | `watchEffect` ou documentar razão |
| Composable em `if`/loop/após async | chamar no nível raiz do `setup()` |
| Memory leak: listener/timer sem cleanup | `onUnmounted`/`onScopeDispose` |
| Event bus global / mixins | Pinia ou provide/inject / composables |
| API calls sem cache | TanStack Query (Vue) |
| Barrel files que quebram tree-shaking | import direto por path |

## Checklist

- [ ] TypeScript strict (`noUncheckedIndexedAccess`, zero `any`)
- [ ] Composition API exclusively (`<script setup lang="ts">`)
- [ ] Props/emits tipados; `storeToRefs` ao consumir Pinia
- [ ] Zod schema em forms e boundaries de API
- [ ] Estado derivado em `computed` (fora do template)
- [ ] Cleanup de listeners/timers; composables no nível raiz
- [ ] Testes Vitest >80% em composables e stores
- [ ] a11y: axe-core, ARIA labels, navegação por teclado
- [ ] Error boundary global (`app.config.errorHandler`)
- [ ] ESLint + Prettier; bundle size check (vite-bundle-visualizer)

## Performance (passe pós-funcionalidade)

Não otimize antes do comportamento correto. Perfile com Vue DevTools. Detalhe em `reference/advanced.md` §8:
- Listas > 50–100 itens → **virtualizar** (`vue-virtual-scroller` / `@tanstack/vue-virtual`).
- Conteúdo estático/condicionalmente estático → `v-once` / `v-memo="[deps]"`.
- **Evitar over-abstração** em listas quentes (achatar hierarquia, elementos nativos).
- Nunca API call ou mutação de estado em `onUpdated` (use `watch`/`computed`).

## Quando Perguntar

Antes de codar: precisa SSR (Nuxt)? UI lib (PrimeVue/Vuetify)? state em Pinia vs composable vs provide/inject? auth flow?
Decisões que não se assume: Vite config avançada (SSR, library mode), estratégia de migração Nuxt, design patterns (compound/renderless components).

## Referências (sob demanda — progressive disclosure)

- **`reference/core.md`** — Padrões de código completos (SFC, Pinia, composable TanStack Query, form VeeValidate+Zod, Axios interceptors, router guards, teste Vitest) + 10 anti-padrões detalhados com o porquê. Leia antes de gerar código.
- **`reference/stack.md`** — Stack canônica: versões, `tsconfig.json` template. Leia ao configurar projeto novo.
- **`reference/advanced.md`** — Built-ins (Slots/Teleport/Suspense/KeepAlive/Transition), passe de performance e metodologia de split. Leia ao usar built-in, otimizar, ou quebrar componente.

## Cross-references

- `typescript-expert` — tipagem avançada, branded types
- `css-expert` — Tailwind, design tokens, responsivo
- `security-expert` — auth, CSP, secrets

## Segurança (Baseline Compartilhado)

Regras universais em `reference/security-baseline.md`. Ameaças específicas de frontend Vue:

- **XSS**: auto-escaping de templates é a defesa primária. `v-html` **apenas** com `DOMPurify.sanitize()` — nunca renderizar input de usuário direto. CSP no servidor como defesa em profundidade.
- Sanitizar input antes de enviar à API. Validar com Zod no boundary.
- Secrets via env vars (`import.meta.env`) — nunca hardcoded. `VITE_*` é exposto no bundle: nunca colocar segredo de backend ali.
- Tokens: preferir cookie `HttpOnly`+`Secure`+`SameSite` a `localStorage` (mitiga roubo via XSS).

> **Atenção**: SSR é decisão de ADR separado (Nuxt). Esta skill cobre SPA Vue 3; para SSR, valide o ADR de Nuxt antes.
