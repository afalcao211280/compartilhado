---
name: angular-expert
description: >
  Engenheiro frontend sênior especializado em Angular seguindo padrões de
  produção. Use SEMPRE que houver menção a Angular, arquivos .component.ts,
  .service.ts, .module.ts, angular.json, ou quando o contexto for um projeto
  Angular. Stack: Angular 17+, Signals, RxJS, NgRx, Angular
  Material/PrimeNG, Jest, Cypress/Playwright.
version: "2.1.1"
category: Frontend
keywords:
  - angular
  - typescript
  - signals
  - rxjs
  - ngrx
  - frontend
requires: ['security-expert']
---

# Angular Expert — EVEO Production Standard

## Princípio Central

Angular moderno com Signals. Standalone components. Zero NgModules em código novo.

## Versão

- Angular 17+
- TypeScript 5+

## Stack Canônica

| Camada | Lib |
|---|---|
| Framework | Angular 17+ (Signals) |
| Reactive | RxJS 7 |
| State | NgRx ComponentStore **ou** Signals store |
| UI | Angular Material **ou** PrimeNG |
| Testes Unit | Jest (esbuild builder) |
| Testes E2E | Cypress **ou** Playwright |
| Estilos | Tailwind CSS |
| Lint | ESLint angular |
| CLI | Angular CLI |

- Refira-se a `typescript-expert` para padrões de tipagem
- Refira-se a `css-expert` para padrões de estilização

## Project Layout

```
src/app/
├── core/
│   ├── guards/
│   ├── interceptors/
│   ├── utils/
│   └── services/          # singleton services
├── shared/
│   ├── components/        # dumb/reusable
│   ├── pipes/
│   └── directives/
├── features/<feature>/
│   ├── components/
│   ├── services/
│   ├── models/
│   └── store/             # NgRx or Signals
├── app.routes.ts
├── app.config.ts
└── app.component.ts
```

## Padrões Obrigatórios

- **Signals** para state local e reativo. `signal()`, `computed()`, `effect()`.
- **Standalone components**. `standalone: true`. Zero NgModules.
- `inject()` ao invés de constructor injection. Mais limpo, melhor testabilidade.
- Signals-based inputs/outputs: `input()`, `output()`, `model()`.
- RxJS para async streams (HTTP, WebSocket, events). `Observable` → `Signal` com `toSignal()`.
- `HttpInterceptor` para auth tokens e error handling global.
- `DestroyRef` + `takeUntilDestroyed()` para unsubscribe automático.
- Lazy loading routes: `loadComponent` e `loadChildren`.
- Error handling: global `ErrorHandler` + component-level `try/catch`.

## Security

- `DomSanitizer.bypassSecurityTrustHtml()` **apenas** com conteúdo sanitizado.
- CSP headers via meta tag ou server.
- `HttpInterceptor` para JWT token injection.
- Environment isolation: `environment.ts` vs `environment.prod.ts`.
- Angular built-in XSS protection (auto-escaping em templates).
- Nunca `innerHTML` sem `DomSanitizer`.
- Route guards para auth: `canActivate`, `canMatch`.

## Anti-padrões

| Proibido | Alternativa |
|---|---|
| NgModules em código novo | Standalone components |
| `.subscribe()` sem unsubscribe | `takeUntilDestroyed()` ou `async` pipe |
| God components (>300 linhas) | Split por responsabilidade |
| Business logic em templates | Component class methods / Signals |
| `any` type | `unknown` + type guards |
| Manual `markDirty` / `ChangeDetectorRef` | Signals (zoneless) |
| `ngOnDestroy` manual para subscriptions | `DestroyRef` + `takeUntilDestroyed()` |
| Services com state introduzido por setters | Signals no service |

## Checklist

- [ ] Signals maximizados (state local, inputs, outputs)
- [ ] Standalone components exclusively
- [ ] Jest configurado (esbuild builder)
- [ ] ESLint angular rules
- [ ] a11y: ARIA labels, keyboard navigation
- [ ] Bundle budget definido no angular.json
- [ ] Lazy loading em todas as feature routes
- [ ] HttpInterceptor para auth + error
- [ ] Testes unitários >80% nos services e stores

## Quando Pedir Ajuda

- Signals vs NgRx Store (scope: local component vs global)
- Standalone vs Modules migration strategy
- SSR com Angular Universal / SSR hydration
- Micro-frontend strategy (Module Federation)
- Performance: OnPush, trackBy, virtual scroll

## Boas Práticas (referência)

- `reference/best-practices.md` — práticas modernas Angular 19+ (visão geral). Leia ao gerar/revisar código.
- `reference/signals.md` — signals, computed, effect, linkedSignal, resource() (reatividade).
- `reference/forms.md` — signal forms e reactive forms tipados, validação.
- `reference/di.md` — dependency injection, hierarchical injectors, injection context, providers.
- `reference/routing.md` — rotas standalone, guards, resolvers, lazy loading, lifecycle.
- `reference/rendering.md` — estratégias de rendering/loading, SSR + hydration.
- `reference/testing.md` — testing fundamentals, harnesses, router testing.

## Seguranca (Baseline Compartilhado)
- `reference/security-baseline.md` — Regras universais de seguranca (OWASP, secrets, headers, TLS)

