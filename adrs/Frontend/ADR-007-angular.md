# ADR-007: Angular 17+ — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Projetos frontend que utilizam Angular na EVEO exigem modernização para Signals, Standalone Components e padrões de produção. Legados em NgModule e constructor injection geram código verboso e difícil de testar. A padronização reduz fragmentação entre projetos Angular.

## Decisão

Adotar Angular 17+ com Signals como primitivo reativo principal. Standalone Components obrigatórios — zero NgModules em código novo. `inject()` ao invés de constructor DI. Signals-based inputs/outputs: `input()`, `output()`, `model()`. RxJS 7 para streams assíncronos (HTTP, WebSocket, events) com `toSignal()` para integração com Signals.

NgRx ComponentStore para state management local/global. Alternativa: Signals Store pattern para state simples.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| Framework | Angular | 17+ (Signals) | Vue, React | Enterprise ecosystem, Signals, standalone |
| State Management | NgRx ComponentStore ou Signals Store | — | NgRx Store (full), Akita, Ngxs | Escalável,Signals-native ou tree-shakeable |
| Reactive | RxJS | 7 | Signals-only | Streams assíncronos, `toSignal()` bridge |
| UI Library | Angular Material ou PrimeNG | 17+ / 17+ | NgZorro, CDK only | Official vs enterprise feature-rich |
| Testes Unit | Jest (esbuild builder) | — | Karma + Jasmine | Velocidade, ESM, esbuild |
| Testes E2E | Playwright | — | Cypress, Protractor | Multi-browser, Angular integration |
| Estilos | Tailwind CSS | 3.4 | SCSS, CSS Modules | Utility-first, design tokens |
| Forms | Reactive Forms + Signals | — | Template-driven | Type-safe, testável, Signal integration |
| HTTP | HttpClient + interceptors | — | fetch | Interceptors, auth, error handling |
| Lint | ESLint angular | — | TSLint (deprecated) | Modern, rules angular-specific |
| Tipagem | TypeScript | 5+ (strict) | — | Type safety, Angular requires TS |

## Padrões Obrigatórios

- **Standalone components**. `standalone: true`. Zero NgModules. Imports diretos.
- **`inject()`** ao invés de constructor injection. Mais limpo, melhor testabilidade.
- **Signals** para state local e reativo: `signal()`, `computed()`, `effect()`.
- **Signals-based inputs/outputs**: `input()`, `output()`, `model()`. Não `@Input()` / `@Output()`.
- **RxJS → Signals bridge**: `toSignal(observable)` para consumir streams como Signals.
- **`DestroyRef` + `takeUntilDestroyed()`** para unsubscribe automático — nunca `.subscribe()` manual sem gerenciamento.
- **`HttpInterceptor`** para auth tokens e error handling global.
- **Lazy loading**: `loadComponent` e `loadChildren` em todas as feature routes.
- **Error handling**: global `ErrorHandler` + component-level `try/catch`.
- **TypeScript strict**: `noUncheckedIndexedAccess`, zero `any`, branded types para domain IDs.
- **Feature-based structure**: `src/app/features/<feature>/`. Não feature-flat nem God modules.
- **Forms**: Reactive Forms com Typed Forms. Nunca Template-driven forms.
- **Change Detection**: `OnPush` por padrão em novos componentes. Signals tornam isso natural (zoneless).

## Estrutura de Projeto

```
src/app/
├── core/
│   ├── guards/                    # Auth guards, canMatch
│   ├── interceptors/              # HTTP interceptors
│   ├── utils/                     # Helpers, validators
│   └── services/                  # Singleton services
├── shared/
│   ├── components/                # Dumb/reusable components
│   ├── pipes/                     # Custom pipes
│   ├── directives/                # Custom directives
│   └── models/                    # Interfaces, types, Zod schemas
├── features/
│   ├── auth/
│   │   ├── components/
│   │   ├── services/
│   │   ├── store/                 # NgRx ComponentStore or Signals
│   │   └── auth.routes.ts
│   ├── users/
│   │   ├── components/
│   │   ├── services/
│   │   ├── store/
│   │   └── users.routes.ts
│   └── dashboard/
│       ├── components/
│       ├── services/
│       └── dashboard.routes.ts
├── app.routes.ts                  # Root routes with lazy loading
├── app.config.ts                  # Application config (provideRouter, etc.)
└── app.component.ts               # Root standalone component
```

## Anti-padrões

| Proibido | Alternativa |
|---|---|
| NgModules em código novo | Standalone components |
| Constructor injection | `inject()` |
| `@Input()` / `@Output()` | `input()` / `output()` / `model()` Signals-based |
| `.subscribe()` sem unsubscribe | `takeUntilDestroyed()` ou `async` pipe |
| God components (>300 linhas) | Split por responsabilidade |
| Business logic em templates | Component class methods / Signals |
| `any` type | `unknown` + type guards |
| `ChangeDetectorRef.detectChanges()` | Signals (zoneless change detection) |
| `ngOnDestroy` manual para subscriptions | `DestroyRef` + `takeUntilDestroyed()` |
| Services com state via setters | Signals no service |
| Template-driven forms | Reactive Forms + Typed Forms |
| Karma + Jasmine | Jest (esbuild builder) |

## Consequências

**Positivas**:
- Signals eliminam zone.js overhead (caminho para zoneless)
- Standalone Components reduzem boilerplate de NgModules
- `inject()` melhora testabilidade e legibilidade
- Feature-based structure escala bem em projetos enterprise

**Negativas**:
- Migração de projetos legados (NgModule → Standalone) requer esforço
- Curva de aprendizado: Signals + Signals-based inputs são paradigma novo
- Angular Material pode limitar customização de design

**Riscos**:
- Mistura de padrões (Signals vs RxJS) pode confundir — definir boundary: Signals para state local, RxJS para async streams
- NgRx ComponentStore vs Signals Store exige decisão por projeto — Signals Store para state simples, ComponentStore para state complexo com side effects

## Referências

- `skills/Frontend/angular-expert/SKILL.md`
- `skills/Frontend/css-expert/SKILL.md`
- `skills/Frontend/typescript-expert/SKILL.md`
- Documentação Angular Signals: https://angular.dev/signals
- Documentação Angular Standalone: https://angular.dev/standalone-components