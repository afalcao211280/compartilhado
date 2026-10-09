# ADR-006: Vue 3 — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Projetos frontend que utilizam Vue.js na EVEO exigem padronização da stack,Patterns de composição e estrutura de projeto. A ausência de diretrizes gera mistura de Options API e Composition API, stores inconsistentes, e falta de type-safety.

## Decisão

Adotar Vue 3.4+ com Composition API exclusivamente (`<script setup>`). Pinia para state management. Vue Router 4 para roteamento. VueUse para composables utilitários. Vitest + Vue Test Utils para testes. Tailwind CSS para estilos. Vite como build tool. TypeScript 5+ strict mode obrigatório.

Options API é proibido em código novo. Toda lógica reativa usa `ref()`, `computed()`, `watch()`.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| Framework | Vue | 3.4+ | Vue 2, React | Composition API, `<script setup>`, performance |
| State Management | Pinia | 2.x | Vuex 4, Vuxt | TypeScript-first, modular, devtools |
| Roteamento | Vue Router | 4 | — | Official, lazy loading, guards |
| Utilidades | VueUse | 10+ | lodash, custom | Composables prontos, tree-shakeable |
| Formulários | VeeValidate + Zod | 4+ / 4+ | FormKit, vuelidate | Zod integration, TypeScript |
| Testes Unit | Vitest + Vue Test Utils | — | Jest | ESM nativo, Vite integration |
| Testes E2E | Playwright | — | Cypress | Multi-browser, trace |
| Estilos | Tailwind CSS | 3.4 | CSS Modules, UnoCSS | Utility-first, design tokens |
| Build | Vite | 5+ | Webpack, Nuxt | Velocidade, HMR, ESM |
| IDE | Volar | — | Vetur | TS support, `<script setup>` |
| Lint | ESLint + Prettier | — | Biome | Ecosystem, `@vue/eslint-config-typescript` |
| Tipagem | TypeScript | 5+ (strict) | — | Type safety, Zod integration |

## Padrões Obrigatórios

- **Composition API exclusively**. `<script setup>` em todo SFC. Zero Options API em código novo.
- **Pinia stores** com actions/getters tipados. Define store com `defineStore('name', () => {...})` (setup syntax).
- **Composables** para lógica reutilizável: `use[Xxx].ts`. Nomes começam com `use`.
- **VueUse** preferencial para utilidades comuns — não reinvente composables que VueUse já fornece.
- **TypeScript strict**: `noUncheckedIndexedAccess`, zero `any`, branded types para IDs.
- **Zod schemas** para validação de formulários e API boundaries. Tipos derivados com `z.infer<>`.
- **Vue Router**: lazy loading com `() => import()`, navigation guards para auth, middleware pattern.
- **Error boundary**: `onErrorCaptured` no componente raiz. Global error handler via `app.config.errorHandler`.
- **Props**: definição tipada com `defineProps<{ ... }>()`. Validación com `withDefaults` quando necessário.
- **Emits**: definição tipada com `defineEmits<{ ... }>()`. Nunca emits não tipados.
- **`provide`/`inject`** com typed InjectionKey — nunca strings soltas.
- **Responsive**: mobile-first com Tailwind. `sm:`, `md:`, `lg:`, `xl:`.
- **Acessibilidade**: ARIA labels, keyboard navigation, `axe-core` nos testes.

## Estrutura de Projeto

```
src/
├── assets/
│   └── styles/
│       └── main.css                # Tailwind directives + custom properties
├── components/
│   ├── ui/                         # Primitivos (Button, Input, Modal)
│   └── features/                  # Componentes de domínio
├── composables/
│   ├── useAuth.ts
│   ├── useNotification.ts
│   └── usePagination.ts
├── layouts/
│   └── DefaultLayout.vue
├── pages/                          # Vue Router pages
│   ├── HomePage.vue
│   ├── dashboard/
│   │   ├── DashboardPage.vue
│   │   └── SettingsPage.vue
│   └── auth/
│       ├── LoginPage.vue
│       └── RegisterPage.vue
├── router/
│   └── index.ts                    # Routes + guards
├── stores/
│   ├── auth.ts
│   ├── notification.ts
│   └── user.ts
├── schemas/                        # Zod schemas
│   ├── user.schema.ts
│   └── auth.schema.ts
├── types/
│   └── index.ts                    # Branded types, utility types
├── utils/
│   ├── format.ts
│   └── validators.ts
├── App.vue
└── main.ts
```

## Anti-padrões

| Proibido | Alternativa |
|---|---|
| Options API | Composition API `<script setup>` |
| Vuex | Pinia |
| Vetur | Volar |
| `any` type | `unknown` + type guards / Zod |
| Lógica de negócio em componentes | Composables / stores |
| Inline styles dinâmicos | Tailwind classes / design tokens |
| Props não tipados | `defineProps<T>()` com TypeScript |
| `watch` sem `immediate`/`deep` explícito | `watchEffect` ou documentar razão |
| Cross-component state via props/events deep | Pinia store ou provide/inject |
| API calls sem TanStack Query | Composable com cache/revalidation |
| Barrel files que quebram tree-shaking | Import direto por path |

## Consequências

**Positivas**:
- Composition API oferece melhor type inference e reutilização de lógica
- Pinia é TypeScript-native, modular e tem DevTools integration
- `<script setup>` reduz boilerplate e melhora legibilidade
- VueUse elimina composables customizados para utilidades comuns

**Negativas**:
- Projetos legados em Options API precisam de migração gradual
- Ecossistema menor que React para bibliotecas especializadas
- SSR requer Nuxt (decisão separada — Nuxt ADR)

**Riscos**:
- Time pouco familiar com Composition API pode gerar código inconsistente — enforce via ESLint
- Falta de convensão sobre composables vs stores — definir boundary: composables para lógica local, stores para state global

## Referências

- `skills/Frontend/vue-expert/SKILL.md`
- `skills/Frontend/css-expert/SKILL.md`
- `skills/Frontend/typescript-expert/SKILL.md`
- Documentação Vue 3: https://vuejs.org
- Documentação Pinia: https://pinia.vuejs.org
- Documentação VueUse: https://vueuse.org