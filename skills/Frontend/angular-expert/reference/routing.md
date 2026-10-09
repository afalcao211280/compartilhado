# Angular — Roteamento (Angular 19+)

Router standalone via `provideRouter`. Rotas com lazy loading por padrão, guards e resolvers
funcionais, binding de inputs. Leia ao definir rotas, proteger acesso, pré-carregar dados ou navegar.

## Índice

1. [Configuração de rotas](#1-configuração-de-rotas)
2. [Estratégias de loading (lazy)](#2-estratégias-de-loading-lazy)
3. [Guards funcionais](#3-guards-funcionais)
4. [Resolvers de dados](#4-resolvers-de-dados)
5. [Binding de inputs (`withComponentInputBinding`)](#5-binding-de-inputs-withcomponentinputbinding)
6. [Navegação (RouterLink / Router)](#6-navegação-routerlink--router)
7. [Outlets (nomeados / aninhados)](#7-outlets-nomeados--aninhados)
8. [Eventos e lifecycle do router](#8-eventos-e-lifecycle-do-router)
9. [Anti-padrões de roteamento](#9-anti-padrões-de-roteamento)

---

## 1. Configuração de rotas

```ts
// app.routes.ts
import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: '', component: Home, title: 'Início' },
  { path: 'articles', redirectTo: 'blog', pathMatch: 'full' },
  { path: 'blog', component: Blog, title: 'Blog' },
  {
    path: 'settings',
    loadComponent: () => import('./settings/settings').then(m => m.Settings),
    children: [
      { path: 'profile', component: Profile },
      { path: 'security', component: Security },
    ],
  },
  { path: '**', component: NotFound }, // wildcard por último
];
```

```ts
// app.config.ts
export const appConfig: ApplicationConfig = {
  providers: [provideRouter(routes, withComponentInputBinding())],
};
```

- `title` (string ou via `ResolveFn`/`TitleStrategy`) para acessibilidade e SEO.
- `pathMatch: 'full'` em redirects de path vazio. Wildcard `**` sempre por último.
- Dados/providers por rota: `data: {...}` e `providers: [...]` (escopo de rota — ver `di.md` §4).

## 2. Estratégias de loading (lazy)

- **Eager** (`component`): incluído no bundle inicial. Só para o que aparece no primeiro paint.
- **Lazy component** (`loadComponent`): busca o componente sob demanda.
- **Lazy children** (`loadChildren`): busca um conjunto de rotas.

```ts
{ path: 'admin', loadComponent: () => import('./admin/admin').then(m => m.Admin) }
{ path: 'reports', loadChildren: () => import('./reports/reports.routes').then(m => m.reportRoutes) }
```

O loader roda no **injection context** da rota — pode usar `inject()` para decidir o que carregar:

```ts
{
  path: 'dashboard',
  loadComponent: () => inject(FeatureFlags).isPremium
    ? import('./premium-dashboard').then(m => m.PremiumDashboard)
    : import('./basic-dashboard').then(m => m.BasicDashboard),
}
```

Recomendação EVEO: lazy loading em **todas** as feature routes; eager só para shell/landing.

## 3. Guards funcionais

Guards são funções desde Angular 15. Rodam em injection context (podem `inject()`).

```ts
import { CanActivateFn, CanMatchFn, Router } from '@angular/router';
import { inject } from '@angular/core';

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  return auth.isLoggedIn() ? true : router.parseUrl('/login');
};

export const featureGuard: CanMatchFn = (route, segments) =>
  inject(FeatureFlags).enabled('beta');
```

- Tipos: `CanActivateFn`, `CanActivateChildFn`, `CanMatchFn`, `CanDeactivateFn`.
- `CanMatchFn` decide se a rota **casa** (permite variar `loadComponent`/redirect por condição sem
  expor a rota) — preferível a `CanActivate` para gating de acesso, pois evita até o download do chunk.
- Retornos: `boolean`, `UrlTree`/`RedirectCommand` (redirect), ou `Observable`/`Promise` desses.
- **Segurança**: guards são UX, não autorização real. A autorização definitiva é no backend.

```ts
{ path: 'admin', canMatch: [authGuard], loadComponent: () => import('./admin/admin').then(m => m.Admin) }
```

## 4. Resolvers de dados

Pré-carregam dados antes de ativar a rota. Implemente `ResolveFn`:

```ts
export const userResolver: ResolveFn<User> = (route) => {
  const id = route.paramMap.get('id')!;
  return inject(UserService).getUser(id);
};

// rota
{ path: 'user/:id', component: UserProfile, resolve: { user: userResolver } }
```

Erros: capture no resolver (`catchError` → redirect/`EMPTY`) para não navegar com dado quebrado.
Use resolver com parcimônia — atrasa a navegação; muitas vezes `resource()`/`httpResource` no
componente (com loading state) dá melhor UX.

## 5. Binding de inputs (`withComponentInputBinding`)

Com `withComponentInputBinding()` no `provideRouter`, params de rota, query params, `data` e dados
resolvidos são passados direto para inputs do componente (nome do input = chave):

```ts
// componente da rota user/:id com resolve { user }
readonly id = input.required<string>();   // param :id
readonly user = input.required<User>();   // dado resolvido
readonly tab = input('overview');          // query param ?tab=
```

Elimina injetar `ActivatedRoute` só para ler params. Combina com signal inputs (`computed`/`effect`).

## 6. Navegação (RouterLink / Router)

Declarativa:

```html
<a routerLink="/dashboard" routerLinkActive="active">Dashboard</a>
<a [routerLink]="['/user', userId]" [queryParams]="{ tab: 'info' }">Perfil</a>
```

Programática:

```ts
private router = inject(Router);
private route = inject(ActivatedRoute);

this.router.navigate(['/search'], { queryParams: { q: 'angular' }, fragment: 'results' });
this.router.navigate(['edit'], { relativeTo: this.route });          // relativa
this.router.navigateByUrl('/products/123?view=details');
this.router.navigateByUrl('/login', { replaceUrl: true });           // substitui histórico
```

Paths absolutos começam com `/`; relativos sem `/` (use `../` para subir). `navigate` (array de
comandos) para relativa/params; `navigateByUrl` (string) para absoluta.

## 7. Outlets (nomeados / aninhados)

`<router-outlet />` é o placeholder onde o componente da rota é inserido (como irmão logo após o outlet).

- **Aninhados**: rota filha precisa de seu próprio `<router-outlet />` no template do pai.
- **Nomeados (rotas secundárias)**: outlet com `name` e rota com `outlet` correspondente.

```html
<router-outlet />                    <!-- primary -->
<router-outlet name="sidebar" />     <!-- secundário -->
```

```ts
{ path: 'chat', component: Chat, outlet: 'sidebar' }
```

Passar dado ao componente da rota sem params: `routerOutletData`.

## 8. Eventos e lifecycle do router

`router.events` emite (cronologicamente): `NavigationStart` → `RoutesRecognized` →
`GuardsCheckStart/End` → `ResolveStart/End` → `NavigationEnd` (ou `NavigationCancel`/`NavigationError`).

```ts
this.router.events.pipe(
  filter((e): e is NavigationEnd => e instanceof NavigationEnd),
  takeUntilDestroyed(),
).subscribe(() => this.analytics.pageView(this.router.url));
```

Usos comuns: barra de loading global (`NavigationStart`/`NavigationEnd`), scroll-to-top, page view
tracking. Debug: `provideRouter(routes, withDebugTracing())`.

## 9. Anti-padrões de roteamento

| Proibido | Alternativa |
|---|---|
| `component` (eager) em toda feature | `loadComponent`/`loadChildren` (lazy) |
| Guard como autorização real | backend autoriza; guard é UX + `canMatch` |
| Injetar `ActivatedRoute` só p/ ler params | `withComponentInputBinding()` + `input()` |
| Wildcard `**` fora do fim | sempre por último |
| Resolver pesado bloqueando navegação | `resource()` no componente com loading state |
| `.subscribe(router.events)` sem cleanup | `takeUntilDestroyed()` |
| Redirect de path vazio sem `pathMatch: 'full'` | incluir `pathMatch: 'full'` |
