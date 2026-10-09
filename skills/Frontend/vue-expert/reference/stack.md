# Vue Expert — Stack Canônica

## Vue 3.5+ / TypeScript 5+ / Vite 8 — Versão Canônica EVEO

> Versões = última estável (jun/2026). Use sempre a última estável dentro da major canônica.

| Categoria | Lib | Versão | Link | Notas |
|-----------|-----|--------|------|-------|
| **Core** | | | | |
| Framework | Vue | 3.5+ (Composition API) | https://vuejs.org | `<script setup>` padrão. Options API: legado. 3.6 (Vapor) em beta |
| Linguagem | TypeScript | 5+ | https://typescriptlang.org | `strict: true` obrigatório |
| Build | Vite | 8.x | https://vite.dev | Rolldown (Rust). Via `create-vue` ou Nuxt |
| SSR/Full-stack | Nuxt | 4.x | https://nuxt.com | Quando precisar de SSR (decisão em ADR separado) |
| **Estado** | | | | |
| Estado global | Pinia | 3.x | https://pinia.vuejs.org | Substitui Vuex. `defineStore()`. Exige Vue 3 + TS 5+ |
| Estado servidor | TanStack Query (Vue) | 5.x | https://tanstack.com/query | `useQuery`, `useMutation` via Vue Query |
| Forms | VeeValidate | 4.x | https://vee-validate.logaretm.com | Composition API nativa. `@vee-validate/zod` |
| Validação | Zod | 4.x | https://zod.dev | Schema + tipos (`z.infer<>`). Integra com VeeValidate |
| Utilidades | VueUse | 14+ | https://vueuse.org | Composables prontos. Exige Vue 3.5+ |
| **Roteamento** | | | | |
| Router | Vue Router | 4.x | https://router.vuejs.org | Canônico (ADR-006). SPA. v5 já estável — migração futura |
| **Estilo** | | | | |
| CSS Utilities | Tailwind CSS | 4.x | https://tailwindcss.com | Padrão EVEO frontend (ver `css-expert`) |
| Componentes | PrimeVue | 4.x | https://primevue.org | Alternativa: Vuetify 3.x |
| Ícones | Heroicons / Lucide | latest | https://heroicons.com | Consistência com shadcn/ui |
| **HTTP** | | | | |
| HTTP client | Axios | 1.x | https://axios-http.com | Com interceptors de auth |
| Alternativa | ofetch | latest | https://github.com/unjs/ofetch | Nativo em Nuxt/UnJS |
| **Testes** | | | | |
| Unit/Component | Vitest | 4.x | https://vitest.dev | ESM nativo, integração Vite |
| Component testing | Vue Test Utils | 2.x | https://test-utils.vuejs.org | Monte e interaja com componentes |
| E2E | Playwright | 1.45+ | https://playwright.dev | Multi-browser, trace |
| **Qualidade** | | | | |
| Linting | ESLint | 9.x (flat config) | https://eslint.vuejs.org | `@vue/eslint-config-typescript` |
| Formatação | Prettier | 3.x | https://prettier.io | + `prettier-plugin-tailwindcss` |
| Type check | vue-tsc | 3.x | https://github.com/vuejs/language-tools | `vue-tsc --noEmit`. IDE: Volar |

## tsconfig.json — Template Canônico Vue 3

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "useDefineForClassFields": true,
    "module": "ESNext",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "preserve",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src/**/*.ts", "src/**/*.d.ts", "src/**/*.tsx", "src/**/*.vue"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```
