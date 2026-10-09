# Angular — Testes (Angular 19+)

Unit/integração com Jest (esbuild builder) e `TestBed`; UI de libs com Component Harnesses; rotas com
`RouterTestingHarness`; E2E com Playwright. Filosofia zoneless e async-first. Leia ao escrever ou
revisar testes. Meta EVEO: >80% em services e stores.

## Índice

1. [Filosofia: zoneless e async-first](#1-filosofia-zoneless-e-async-first)
2. [`TestBed` e `ComponentFixture`](#2-testbed-e-componentfixture)
3. [Testar signals e inputs](#3-testar-signals-e-inputs)
4. [Testar services (HTTP)](#4-testar-services-http)
5. [Component Harnesses](#5-component-harnesses)
6. [`RouterTestingHarness`](#6-routertestingharness)
7. [E2E com Playwright](#7-e2e-com-playwright)
8. [Anti-padrões de teste](#8-anti-padrões-de-teste)

---

## 1. Filosofia: zoneless e async-first

Mudanças de state agendam updates de forma assíncrona. Padrão **Act → Wait → Assert**:

1. **Act**: mude state ou dispare ação (set de input, click).
2. **Wait**: `await fixture.whenStable()` para processar o update agendado e renderizar.
3. **Assert**: verifique o resultado.

**Não** use `fixture.detectChanges()` para forçar updates em código novo — use `whenStable()`.

## 2. `TestBed` e `ComponentFixture`

```ts
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { MyComponent } from './my.component';

describe('MyComponent', () => {
  let fixture: ComponentFixture<MyComponent>;
  let component: MyComponent;

  beforeEach(() => {
    TestBed.configureTestingModule({ imports: [MyComponent] }); // standalone → imports
    fixture = TestBed.createComponent(MyComponent);
    component = fixture.componentInstance;
  });

  it('atualiza o título após mudança de state', async () => {
    component.title.set('Novo Título');   // Act
    await fixture.whenStable();           // Wait
    const h1: HTMLElement = fixture.nativeElement.querySelector('h1');
    expect(h1.textContent).toContain('Novo Título'); // Assert
  });
});
```

- `TestBed.configureTestingModule({ imports, providers })` — componentes standalone vão em `imports`.
- `fixture.componentInstance` (classe), `fixture.nativeElement` (DOM raiz),
  `fixture.debugElement.query(By.css('p'))` (query platform-agnóstica).
- Substitua deps com providers: `{ provide: UserService, useValue: mock }`.

## 3. Testar signals e inputs

```ts
it('reflete input required', async () => {
  fixture.componentRef.setInput('user', { name: 'Ana', role: 'admin' });
  await fixture.whenStable();
  expect(fixture.nativeElement.textContent).toContain('Ana');
});

it('computed deriva total', () => {
  const store = TestBed.inject(CartStore);
  store.add({ id: '1', price: 10, qty: 2 });
  expect(store.total()).toBe(20); // ler signal direto, sem fixture
});
```

- `componentRef.setInput('nome', valor)` para signal inputs (`input()`/`input.required()`).
- Signals de service: leia direto (`store.total()`) — não precisa de fixture.

## 4. Testar services (HTTP)

```ts
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';

beforeEach(() => {
  TestBed.configureTestingModule({
    providers: [provideHttpClient(), provideHttpClientTesting()],
  });
});

it('busca usuário', () => {
  const service = TestBed.inject(UserService);
  const ctrl = TestBed.inject(HttpTestingController);
  service.getUser('1').subscribe(u => expect(u.name).toBe('Ana'));
  ctrl.expectOne('/api/users/1').flush({ name: 'Ana' });
  ctrl.verify(); // nenhuma requisição pendente
});
```

## 5. Component Harnesses

Harnesses testam componentes (Material/CDK ou próprios) por uma API estável, sem acoplar ao DOM
interno — o teste sobrevive a refactors de markup.

```ts
import { TestbedHarnessEnvironment } from '@angular/cdk/testing/testbed';
import { HarnessLoader } from '@angular/cdk/testing';
import { MatButtonHarness } from '@angular/material/button/testing';

let loader: HarnessLoader;
beforeEach(() => {
  fixture = TestBed.createComponent(MyContainer);
  loader = TestbedHarnessEnvironment.loader(fixture);
});

it('clica no botão Submit', async () => {
  const btn = await loader.getHarness(MatButtonHarness.with({ text: 'Submit' }));
  expect(await btn.isDisabled()).toBe(false);
  await btn.click(); // API do harness aguarda async/CD automaticamente
});
```

- `TestbedHarnessEnvironment.loader(fixture)` → `HarnessLoader`.
- `loader.getHarness(Harness)` / `getAllHarnesses`; filtre com `Harness.with({ text, selector, … })`.
- Métodos (`click`, `getText`, `getValue`) já esperam CD/async. Componentes próprios: estenda
  `ComponentHarness`.

## 6. `RouterTestingHarness`

```ts
import { provideRouter } from '@angular/router';
import { RouterTestingHarness } from '@angular/router/testing';

let harness: RouterTestingHarness;
beforeEach(async () => {
  TestBed.configureTestingModule({
    providers: [provideRouter([
      { path: '', component: Dashboard },
      { path: 'heroes/:id', component: HeroDetail },
    ])],
  });
  harness = await RouterTestingHarness.create(); // navega para '/' inicialmente
});

it('navega para detalhe', async () => {
  const cmp = await harness.navigateByUrl('/heroes/42', HeroDetail);
  expect(cmp).toBeInstanceOf(HeroDetail);
  expect(harness.routeNativeElement?.textContent).toContain('42');
});
```

Forneça só as rotas necessárias ao componente sob teste. `navigateByUrl(url, ComponentType)`
retorna a instância ativada e tipa o retorno.

## 7. E2E com Playwright

Multi-browser, trace viewer, auto-wait. Rode com `ng e2e` (configurado) ou `npx playwright test`.

```ts
import { test, expect } from '@playwright/test';

test('login redireciona ao dashboard', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('E-mail').fill('user@example.com');
  await page.getByLabel('Senha').fill('secret');
  await page.getByRole('button', { name: 'Entrar' }).click();
  await expect(page).toHaveURL('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

- Prefira locators por papel/acessibilidade (`getByRole`, `getByLabel`) a seletores CSS frágeis.
- `expect(locator)` tem auto-wait — evite `waitForTimeout` fixo.
- Fluxos críticos ponta-a-ponta (auth, checkout); unit/harness cobre o resto.

## 8. Anti-padrões de teste

| Proibido | Alternativa |
|---|---|
| `fixture.detectChanges()` (zoneless) | `await fixture.whenStable()` |
| `component.input = x` para signal input | `componentRef.setInput('input', x)` |
| Asserção acoplada ao DOM interno de lib | Component Harness |
| Query CSS frágil no E2E | `getByRole`/`getByLabel` |
| `waitForTimeout` fixo | auto-wait de `expect(locator)` |
| HTTP real em unit test | `provideHttpClientTesting` + `HttpTestingController` |
| Esquecer `ctrl.verify()` | verificar requisições pendentes |
| Testar só happy path | incluir erro/estado vazio/loading |
