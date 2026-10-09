# Angular — Injeção de Dependência (Angular 19+)

DI é o mecanismo de fornecimento de serviços/valores. Padrão EVEO: `inject()` (nunca constructor
injection), services `providedIn: 'root'`, providers explícitos onde escopo importa. Leia ao criar
services, tokens, ou lidar com escopo/hierarquia de injetores.

## Índice

1. [`inject()` e services](#1-inject-e-services)
2. [Injection context — onde `inject()` funciona](#2-injection-context--onde-inject-funciona)
3. [`runInInjectionContext` e `assertInInjectionContext`](#3-runininjectioncontext-e-assertininjectioncontext)
4. [Injetores hierárquicos](#4-injetores-hierárquicos)
5. [Modificadores de resolução](#5-modificadores-de-resolução)
6. [`providers` vs `viewProviders`](#6-providers-vs-viewproviders)
7. [Providers: `useClass` / `useValue` / `useFactory` / `useExisting` / `multi`](#7-providers-useclass--usevalue--usefactory--useexisting--multi)
8. [`InjectionToken` e funções `provide*`](#8-injectiontoken-e-funções-provide)
9. [Anti-padrões de DI](#9-anti-padrões-de-di)

---

## 1. `inject()` e services

Service singleton na raiz — tree-shakeable (removido do bundle se não usado):

```ts
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Injectable({ providedIn: 'root' })
export class UserService {
  private readonly http = inject(HttpClient); // field initializer = injection context
  getUser(id: string) { return this.http.get<User>(`/api/users/${id}`); }
}
```

- `inject()` no field initializer ou constructor. Mais limpo que constructor params e melhor para
  herança/mixins e funções utilitárias de injeção.
- `providedIn: 'root'` para singletons de app. Escopos alternativos: escopo de rota (`providers` na
  rota) ou de componente (`providers` no `@Component`).

## 2. Injection context — onde `inject()` funciona

`inject()` só funciona dentro de um **injection context**, disponível automaticamente em:

1. **Field initializers** de classes instanciadas por DI (`@Injectable`, `@Component`, `@Directive`, `@Pipe`).
2. **Constructors** dessas classes.
3. **Factory functions** de `useFactory` ou `InjectionToken`.
4. **APIs funcionais** executadas pelo Angular: guards funcionais, resolvers, interceptors, loaders de rota.

```ts
@Component({ /* … */ })
export class Example {
  private router = inject(Router);   // ✅ field initializer
  constructor() { const http = inject(HttpClient); } // ✅ constructor
  onClick() { /* ❌ inject(AuthService) aqui lança erro — fora de contexto */ }
}
```

## 3. `runInInjectionContext` e `assertInInjectionContext`

Para usar `inject()` fora de contexto (criação dinâmica, callbacks), rode dentro de um injector:

```ts
import { inject, EnvironmentInjector, runInInjectionContext } from '@angular/core';

private injector = inject(EnvironmentInjector);
doDynamic() {
  runInInjectionContext(this.injector, () => {
    const router = inject(Router); // ✅ válido aqui
  });
}
```

`assertInInjectionContext(fn)` em funções utilitárias garante contexto válido com erro claro:

```ts
export function injectNativeElement<T extends Element>(): T {
  assertInInjectionContext(injectNativeElement);
  return inject(ElementRef).nativeElement;
}
```

## 4. Injetores hierárquicos

Duas hierarquias paralelas:

1. **`EnvironmentInjector`** — `providedIn: 'root'`, `ApplicationConfig.providers` (bootstrap),
   providers de rota. Singletons de ambiente.
2. **`ElementInjector`** — implícito em cada elemento DOM; configurado via `providers`/`viewProviders`
   em `@Component`/`@Directive`. Nova instância por elemento.

Resolução de uma dependência:

1. Sobe a árvore de **`ElementInjector`** (do componente pedinte até o elemento raiz).
2. Se não achar, sobe a árvore de **`EnvironmentInjector`** (do mais próximo até o root).
3. Se ainda não achar, erro (a menos que `@Optional()`/`{ optional: true }`).

Fornecer no componente cria instância isolada por instância do componente — útil para state
component-scoped (ex.: `ComponentStore`).

## 5. Modificadores de resolução

Passe options em `inject(Token, { ... })` (ou decorators legados):

- `{ optional: true }` → retorna `null` em vez de erro se ausente.
- `{ self: true }` → busca só no ElementInjector do próprio elemento.
- `{ skipSelf: true }` → pula o próprio elemento, começa no pai.
- `{ host: true }` → limita a busca ao componente host.

```ts
private parentForm = inject(ControlContainer, { optional: true, skipSelf: true });
```

## 6. `providers` vs `viewProviders`

No nível de componente:

- **`providers`**: disponível ao componente, sua view **e** conteúdo projetado (`<ng-content>`).
- **`viewProviders`**: disponível ao componente e sua view, **mas não** ao conteúdo projetado. Use
  para isolar serviços internos do conteúdo passado pelo consumidor.

## 7. Providers: `useClass` / `useValue` / `useFactory` / `useExisting` / `multi`

```ts
@Component({
  providers: [
    LocalService,                                         // atalho de useClass
    { provide: Logger, useClass: BetterLogger },          // troca de implementação
    { provide: API_URL, useValue: 'https://api.example.com' }, // valor estático
    { provide: ApiClient, useFactory: (http = inject(HttpClient)) => new ApiClient(http) }, // dinâmico
    { provide: OldLogger, useExisting: NewLogger },        // alias (mesma instância)
    { provide: HTTP_INTERCEPTORS, useClass: AuthInterceptor, multi: true }, // agrega em array
  ],
})
export class Example {}
```

`multi: true` acumula vários providers do mesmo token num array (interceptors, initializers).

## 8. `InjectionToken` e funções `provide*`

Para dependências não-classe (config, funções, primitivos), use `InjectionToken`. Com `factory`,
é auto-provisionado e tree-shakeable:

```ts
export interface AppConfig { apiUrl: string; }
export const APP_CONFIG = new InjectionToken<AppConfig>('app.config', {
  providedIn: 'root',
  factory: () => ({ apiUrl: 'https://api.example.com' }),
});

// consumo
private config = inject(APP_CONFIG);
```

Bibliotecas devem exportar funções `provide*` que retornam arrays de providers (padrão de
`provideRouter`, `provideHttpClient`):

```ts
export function provideAnalytics(config: AnalyticsConfig): Provider[] {
  return [{ provide: ANALYTICS_CONFIG, useValue: config }, AnalyticsService];
}
```

## 9. Anti-padrões de DI

| Proibido | Alternativa |
|---|---|
| Constructor injection em código novo | `inject()` |
| String como token de config | `InjectionToken<T>` tipado |
| `inject()` fora de injection context | `runInInjectionContext` / mover para field/constructor |
| `new Service()` manual | DI (`inject`) — preserva escopo e testabilidade |
| Service com `providedIn: 'root'` guardando state por-componente | providers no `@Component` (instância isolada) |
| Serviço interno exposto a `<ng-content>` sem querer | `viewProviders` |
