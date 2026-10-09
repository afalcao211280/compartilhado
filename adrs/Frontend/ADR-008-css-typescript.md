# ADR-008: CSS + TypeScript — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Projetos frontend na EVEO necessitam padronização de estilos (CSS) e tipagem (TypeScript) que atravessam frameworks. A ausência de diretrizes gera inconsistências: `any` types, CSS inline, dark mode mal implementado, e falta de design tokens. Este ADR unifica as decisões de CSS e TypeScript como cross-cutting concerns aplicáveis a qualquer projeto frontend (React, Vue, Angular).

## Decisão

**CSS**: Tailwind CSS 3.4+ como sistema utility-first. CSS Custom Properties como design tokens. PostCSS para processamento. Mobile-first obrigatório. Dark mode via `class` strategy.

**TypeScript**: TypeScript 5+ strict mode obrigatório. Zero `any`. Branded types para domain IDs. `satisfies` operator para type narrowing. Zod para validação runtime em API/form boundaries.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| Utility CSS | Tailwind CSS | 3.4+ | UnoCSS, WindiCSS | Ecossistema, JIT, plugins |
| Design Tokens | CSS Custom Properties | — | Sass variables, design-tokens JSON | Nativo, runtime, tema dinâmico |
| Scoped CSS | CSS Modules | — | Styled Components, Emotion | Zero runtime, build-time |
| Processamento | PostCSS | — | Sass (legacy) | Autoprefixer, nesting nativo |
| Tipagem | TypeScript | 5+ (strict) | — | Type safety obrigatório |
| Validação Runtime | Zod | 4 | Yup, Joi | Inferência de tipos, composição |
| Ícones | Heroicons / Phosphor | — | Font Awesome | Tree-shakeable, SVG-first |
| Animações | Tailwind + CSS keyframes | — | Framer Motion (React-only) | Cross-framework, CSS-native |
| Lint TS | ESLint `@typescript-eslint` | — | TSLint (deprecated) | Modern, strict rules |

## Padrões Obrigatórios — CSS

- **Utility-first**: composição de classes Tailwind. Sem CSS custom para layouts comuns.
- **Responsive: mobile-first**. `sm:`, `md:`, `lg:`, `xl:`.
- **Dark mode**: `darkMode: 'class'` no `tailwind.config`. Tokens com `.dark` variant.
- **`@apply`** apenas em componentes base (`src/components/ui/`). Nunca em features.
- **Container queries** (`@container`) para componentes responsivos isolados.
- **`aspect-ratio`** para proporções fixas. Never padding-bottom hack.
- **Grid layout** para layouts complexos. Flexbox para alinhamentos simples.
- **`clamp()`** para fluid typography. Never breakpoint-only font sizes.
- **Design tokens** via CSS Custom Properties:
  ```css
  :root {
    --color-primary-500: #3b82f6;
    --spacing-unit: 0.25rem;
    --font-size-base: clamp(1rem, 1rem + 0.5vw, 1.125rem);
  }
  .dark {
    --color-primary-500: #60a5fa;
  }
  ```
- **`prefers-reduced-motion`**: respeitar preferência de usuário para animações.
- **Acessibilidade**: contraste WCAG AA mínimo. ARIA labels em componentes interativos.

## Padrões Obrigatórios — TypeScript

- **`strict: true`** + `noUncheckedIndexedAccess` no `tsconfig.json`.
- **Zero `any`** em produção. Type-coverage > 95% (medido com `type-coverage`).
- **Branded types** para domain IDs:
  ```typescript
  type UserId = string & { readonly __brand: unique symbol }
  const UserId = (id: string): UserId => id as UserId
  ```
- **`satisfies` operator** para type narrowing sem widening.
- **Zod schemas** em todos API/form boundaries. Tipos derivados com `z.infer<>`.
- **Discriminated unions** para state machines:
  ```typescript
  type RequestState<T> =
    | { status: 'idle' }
    | { status: 'loading' }
    | { status: 'success'; data: T }
    | { status: 'error'; error: Error }
  ```
- **Result/Either pattern** para error handling sem exceptions:
  ```typescript
  type Result<T, E = Error> = { ok: true; value: T } | { ok: false; error: E }
  ```
- **Barrel files** com cuidado — favorizar import direto por path para tree-shaking.
- **ESLint rules**: `@typescript-eslint/no-explicit-any`, `@typescript-eslint/no-unsafe-assignment`.

## Estrutura de Projeto — Design Tokens

```
src/
├── styles/
│   ├── tokens/
│   │   ├── colors.css          # CSS Custom Properties
│   │   ├── spacing.css
│   │   ├── typography.css
│   │   ├── shadows.css
│   │   └── breakpoints.css
│   ├── base.css                # Reset + tokens import
│   └── components.css          # @apply components (apenas ui/)
├── tailwind.config.ts
├── postcss.config.js
└── tsconfig.json               # strict: true, noUncheckedIndexedAccess
```

## Anti-padrões

| Proibido | Alternativa |
|---|---|
| Inline styles dinâmicos | Tailwind classes / design tokens |
| `!important` | Especificidade via Tailwind layer ou refatoração |
| CSS global não tokenizado | CSS Custom Properties (tokens) |
| `@apply` em features/components | Apenas em `src/components/ui/` |
| `any` type | `unknown` + type guards / Zod |
| `// @ts-ignore` ou `// @ts-expect-error` sem justificativa | Corrigir o tipo |
| Barrel files que quebram tree-shaking | Import direto por path |
| `padding-bottom` hack para aspect ratio | `aspect-ratio` CSS |
| Breakpoint-only font sizes | `clamp()` fluid typography |
| Animações sem `prefers-reduced-motion` | `motion-reduce:` variant |
| Mixin Sass (legacy) | Tailwind utilities + CSS Custom Properties |
| `scoped` styles soltos sem sistema | Tailwind + tokens centralizados |

## Consequências

**Positivas**:
- Tailwind utility-first elimina CSS morto e inconsistência de naming
- CSS Custom Properties permitem theming dinâmico (dark mode, multi-brand)
- TypeScript strict + Zed garante type-safety em compile-time e runtime
- Branded types previnem erros de ID swap (passar UserId onde OrderId é esperado)
- Cross-framework: padrões aplicáveis a React, Vue, Angular

**Negativas**:
- Tailwind gera classes longas em templates — exigir Prettier plugin para organizar
- CSS Custom Properties não são tipados por padrão — articular com tokens JSON quando necessário
- Branded types adicionam ceremony — justificar uso apenas em boundaries críticos

**Riscos**:
- Time pouco familiar com utility-first pode gerar classes inconsistentes — Prettier + `prettier-plugin-tailwindcss`
- Zod schemas podem divergir de tipos TypeScript se não derivados — sempre `z.infer<>`
- `@apply` pode ser overused — restringir strictamente a `src/components/ui/`

## Referências

- `skills/Frontend/css-expert/SKILL.md`
- `skills/Frontend/typescript-expert/SKILL.md`
- Documentação Tailwind CSS: https://tailwindcss.com
- Documentação TypeScript: https://www.typescriptlang.org
- Documentação Zod: https://zod.dev