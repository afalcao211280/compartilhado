# Angular — Componentes e Renderização (Angular 19+)

Componentes standalone (default no v19 — `standalone: true` implícito), control flow nativo
(`@if`/`@for`/`@switch`/`@defer`), change detection `OnPush`/zoneless e SSR + hydration. Leia ao criar
componentes, otimizar renderização ou configurar SSR.

## Índice

1. [Componente standalone](#1-componente-standalone)
2. [Control flow no template](#2-control-flow-no-template)
3. [`@defer` — lazy no template](#3-defer--lazy-no-template)
4. [Host bindings](#4-host-bindings)
5. [Change detection: OnPush e zoneless](#5-change-detection-onpush-e-zoneless)
6. [Estratégias de rendering (CSR / SSG / SSR)](#6-estratégias-de-rendering-csr--ssg--ssr)
7. [Hydration](#7-hydration)
8. [Anti-padrões de renderização](#8-anti-padrões-de-renderização)

---

## 1. Componente standalone

No v19 componentes são standalone por padrão — não declare `standalone: true` (é implícito) e não use
NgModules em código novo. Importe dependências direto em `imports`.

```ts
import { Component, ChangeDetectionStrategy, input } from '@angular/core';

@Component({
  selector: 'app-user-card',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DatePipe, UserBadge],
  template: `
    <h3>{{ user().name }}</h3>
    <app-user-badge [role]="user().role" />
    <time>{{ user().createdAt | date }}</time>
  `,
})
export class UserCard {
  readonly user = input.required<User>();
}
```

- Templates inline curtos; `templateUrl`/`styleUrl` quando crescem.
- `OnPush` sempre (com signals é o caminho para zoneless — ver §5).
- Prefira template separado quando passar de ~30 linhas de HTML.

## 2. Control flow no template

Sintaxe de bloco nativa (substitui `*ngIf`/`*ngFor`/`*ngSwitch` — não use as diretivas legadas):

```html
@if (user(); as u) {
  <p>{{ u.name }}</p>
} @else if (loading()) {
  <app-spinner />
} @else {
  <p>Sem usuário.</p>
}

@for (item of items(); track item.id) {
  <li>{{ item.label }}</li>
} @empty {
  <li>Lista vazia.</li>
}

@switch (status()) {
  @case ('active') { <app-active /> }
  @case ('paused') { <app-paused /> }
  @default { <app-unknown /> }
}
```

- **`track` é obrigatório** no `@for` — use id estável (`item.id`), nunca `$index` para dados que
  reordenam. `track` correto evita recriação de DOM e preserva estado/foco.
- `@empty` para estado vazio; `as` no `@if` para alias do valor truthy.
- Variáveis implícitas no `@for`: `$index`, `$first`, `$last`, `$even`, `$odd`, `$count`.
- `@let` para variáveis locais de template: `@let total = price() * qty();`.

## 3. `@defer` — lazy no template

Carrega parte do template (e seus imports) sob demanda, reduzindo o bundle inicial:

```html
@defer (on viewport; prefetch on idle) {
  <app-heavy-chart [data]="data()" />
} @placeholder (minimum 500ms) {
  <div class="skeleton"></div>
} @loading (after 100ms; minimum 1s) {
  <app-spinner />
} @error {
  <p>Falha ao carregar.</p>
}
```

Triggers: `on idle` (default), `on viewport`, `on interaction`, `on hover`, `on immediate`,
`on timer(2s)`, ou `when <condição>`. `prefetch on <trigger>` baixa o chunk antes de renderizar.
Blocos `@placeholder`/`@loading`/`@error` são opcionais. Base para hydration incremental (§7).

## 4. Host bindings

Prefira `host` no decorator a `@HostBinding`/`@HostListener` legados:

```ts
@Component({
  selector: 'app-toggle',
  host: {
    '[class.active]': 'isActive()',
    '[attr.aria-pressed]': 'isActive()',
    '(click)': 'toggle()',
    'role': 'button',
  },
})
export class Toggle {
  readonly isActive = signal(false);
  toggle() { this.isActive.update(v => !v); }
}
```

Colisões de binding no host: o valor do componente que aplica a diretiva vence conforme regras de
precedência; evite duplicar a mesma propriedade. `@Attribute`/`inject(new HostAttributeToken('x'))`
para ler atributos estáticos do host.

## 5. Change detection: OnPush e zoneless

- **`OnPush`** em todo componente: só re-renderiza em mudança de input, evento do template, ou signal
  lido no template que muda. Com signals, o tracking é granular e dispensa `markForCheck` manual.
- **Zoneless** (experimental no v19): remova `zone.js` e use
  `provideExperimentalZonelessChangeDetection()` no bootstrap. Requer state 100% em signals (ou
  `markForCheck` manual). Elimina o overhead do Zone.js.
- Nunca chame `ChangeDetectorRef.markForCheck()`/`detectChanges()` manualmente em código novo com
  signals — sinal de state fora de signal.

## 6. Estratégias de rendering (CSR / SSG / SSR)

| Estratégia | Quando | Como |
|---|---|---|
| **CSR** (client-side) | apps internos, dashboards atrás de login | default SPA |
| **SSG / Prerender** | conteúdo estático, marketing, docs | `ng build` com prerender de rotas |
| **SSR** | SEO + first paint rápido em conteúdo dinâmico | `@angular/ssr` + `provideServerRendering()` |

SSR/SSG: adicione com `ng add @angular/ssr`. Rotas prerenderizadas via `getPrerenderParams`.
SSR é decisão de arquitetura — confirme necessidade (SEO, TTFB) antes de adotar.

## 7. Hydration

Hydration torna o HTML renderizado no servidor interativo no cliente sem re-renderizar do zero.

```ts
// app.config.ts
providers: [provideClientHydration(withEventReplay())]
```

- **Full hydration**: app inteiro fica interativo de uma vez.
- **Incremental hydration** (dev preview v19): partes hidratam sob demanda via `@defer (hydrate on …)`.
- **Event replay** (`withEventReplay()`): captura e reexecuta eventos do usuário ocorridos antes da
  hidratação terminar.
- Evite manipular DOM diretamente antes da hidratação (quebra o match servidor↔cliente); use
  `afterRenderEffect`/`afterNextRender` para DOM.

## 8. Anti-padrões de renderização

| Proibido | Alternativa |
|---|---|
| `*ngIf`/`*ngFor`/`*ngSwitch` | `@if`/`@for`/`@switch` |
| `@for` sem `track` (ou `track $index` em lista reordenável) | `track item.id` estável |
| NgModules / `standalone: true` explícito em código novo | standalone implícito (v19) |
| `ChangeDetectorRef.detectChanges()` manual com signals | signals + `OnPush` |
| Componente sem `OnPush` | `ChangeDetectionStrategy.OnPush` |
| Lógica de negócio no template | `computed()`/métodos da classe |
| `@HostBinding`/`@HostListener` em código novo | `host: {}` no decorator |
| Manipular DOM em `effect`/constructor no SSR | `afterRenderEffect`/`afterNextRender` |
| Importar chart/editor pesado eager | `@defer (on viewport)` |
