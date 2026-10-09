# Angular — Reatividade com Signals (Angular 19+)

Signals são a base da reatividade no Angular moderno. Um **signal** é um wrapper em torno de
um valor que notifica consumidores quando o valor muda. É o modelo padrão de state — RxJS fica
reservado para streams assíncronos (eventos, WebSocket, HTTP composto). Leia antes de gerar ou
revisar qualquer state reativo.

## Índice

1. [Writable signals (`signal`)](#1-writable-signals-signal)
2. [Computed signals (`computed`)](#2-computed-signals-computed)
3. [Contexto reativo e `untracked`](#3-contexto-reativo-e-untracked)
4. [`linkedSignal` — state derivado porém gravável](#4-linkedsignal--state-derivado-porém-gravável)
5. [`effect` e `afterRenderEffect`](#5-effect-e-afterrendereffect)
6. [Async: `resource` / `rxResource` / `httpResource`](#6-async-resource--rxresource--httpresource)
7. [Inputs signal-based (`input` / `model`)](#7-inputs-signal-based-input--model)
8. [Outputs (`output`)](#8-outputs-output)
9. [Interop RxJS (`toSignal` / `toObservable`)](#9-interop-rxjs-tosignal--toobservable)
10. [State em services (Signal store)](#10-state-em-services-signal-store)
11. [Anti-padrões de reatividade](#11-anti-padrões-de-reatividade)

---

## 1. Writable signals (`signal`)

```ts
import { signal } from '@angular/core';

const count = signal(0);

count();            // leitura — SEMPRE via getter (chamada de função)
count.set(3);       // grava valor novo
count.update(v => v + 1); // grava a partir do anterior
```

- Leitura é sempre `count()`. Em template, `{{ count() }}`.
- Objetos/arrays: trate como **imutáveis**. `items.update(list => [...list, novo])`, nunca `.push` no
  valor interno (o signal não detecta mutação in-place; iguala por referência por padrão).
- `equal` custom quando a igualdade não é referencial: `signal(obj, { equal: _.isEqual })`.

### Exposição readonly

Serviços devem expor estado como readonly para impedir mutação externa. O `_` prefixa a fonte
gravável privada:

```ts
private readonly _count = signal(0);
readonly count = this._count.asReadonly(); // consumidor lê, não pode .set()/.update()
```

## 2. Computed signals (`computed`)

Signal read-only derivado de outros signals.

```ts
import { signal, computed } from '@angular/core';

const count = signal(0);
const doubled = computed(() => count() * 2);
```

- **Lazy**: a função só roda quando `doubled()` é lido.
- **Memoizado**: recalcula apenas quando uma dependência lida muda.
- **Dependências dinâmicas**: só os signals efetivamente lidos naquela execução são rastreados.
- Derive sempre em `computed`, nunca recalcule manualmente em `effect` gravando outro signal.
- Mantenha derivação **pura** (sem side effects, sem `.set()` de outro signal dentro).

## 3. Contexto reativo e `untracked`

Um **contexto reativo** é o runtime em que o Angular monitora leituras de signal para montar
dependências. Angular entra em contexto reativo ao avaliar: `computed`, callbacks de `effect`,
computações de `linkedSignal` e templates de componentes.

Para ler um signal **sem** criar dependência, use `untracked`:

```ts
import { effect, untracked } from '@angular/core';

effect(() => {
  // roda só quando currentUser muda; NÃO reage a counter
  log(`User: ${currentUser()}, Count: ${untracked(counter)}`);
});
```

## 4. `linkedSignal` — state derivado porém gravável

Estado gravável intrinsecamente ligado a outra fonte. Ideal para valor default derivado de um
input/signal, mas que o usuário ainda pode sobrescrever. Se a fonte muda, o `linkedSignal`
recomputa (reset).

```ts
import { signal, linkedSignal } from '@angular/core';

readonly shippingOptions = signal(['Ground', 'Air', 'Sea']);

// default = primeiro item; se options mudar, reseta para o novo primeiro
readonly selected = linkedSignal(() => this.shippingOptions()[0]);

changeShipping(i: number) { this.selected.set(this.shippingOptions()[i]); } // gravável
```

Sintaxe objeto `source`/`computation` para **preservar a escolha anterior** quando ainda válida:

```ts
readonly selected = linkedSignal<ShippingMethod[], ShippingMethod>({
  source: this.shippingOptions,
  computation: (newOptions, previous) =>
    newOptions.find(o => o.id === previous?.value.id) ?? newOptions[0],
});
```

Quando usar: `computed` (só leitura derivada) → `linkedSignal` (derivado mas gravável) →
`effect` (side effect, nunca para derivar state).

## 5. `effect` e `afterRenderEffect`

Um **effect** roda sempre que um signal rastreado muda. Rodam de forma assíncrona durante o change
detection e executam ao menos uma vez.

```ts
import { effect } from '@angular/core';

constructor() {
  effect((onCleanup) => {
    const id = this.userId();
    const timer = setTimeout(() => this.poll(id), 1000);
    onCleanup(() => clearTimeout(timer)); // roda antes da próxima execução e no destroy
  });
}
```

- Criar em **injection context** (field initializer ou constructor). Fora dele, passe
  `{ injector }` ou use `afterNextRender`/`assertInInjectionContext`.
- Limpeza automática ao destruir o contexto de injeção do owner. Registre cleanup de timers/listeners
  via o callback `onCleanup`.
- **Usos legítimos**: logging, sincronizar com API não-signal (localStorage, `<canvas>`, libs 3rd-party),
  disparar analytics. **NÃO** use effect para: derivar state (use `computed`), propagar de um signal
  para outro (loop / ordem imprevisível), ou fetch de dados (use `resource`).

`afterRenderEffect` roda **depois** do Angular atualizar o DOM — use para medir/manipular DOM ou
integrar UI de terceiros (o `effect` comum roda antes do DOM ser escrito).

## 6. Async: `resource` / `rxResource` / `httpResource`

`resource()` (developer preview no v19) integra fetch assíncrono à reatividade de signals. A entrada
reativa é `params`; o `loader` é `async`.

```ts
import { resource } from '@angular/core';

readonly userId = signal(1);

readonly userResource = resource({
  params: this.userId,                       // ⚠️ é `params`, NÃO `request`
  loader: async ({ params: id, abortSignal }) => {
    const res = await fetch(`/api/users/${id}`, { signal: abortSignal }); // sempre repasse abortSignal
    return res.json() as Promise<User>;
  },
});
```

Signals de status expostos: `userResource.value()`, `.status()` (`idle`/`loading`/`resolved`/`error`/…),
`.error()`, `.isLoading()`. Recarregar: `.reload()`. Mutação local otimista: `.value.set(...)`.

- **Abort**: se `params` muda com um loader em andamento, o `abortSignal` é acionado — repasse-o ao `fetch`.
- **`httpResource`** (dev preview): use quando o backend é chamado via `HttpClient` — passa pela stack
  HTTP do Angular (interceptors, testing) mantendo a API de resource.
- **`rxResource`**: quando o loader é um `Observable` (ex.: combina streams RxJS).

## 7. Inputs signal-based (`input` / `model`)

```ts
import { input, model } from '@angular/core';

readonly label = input('');                         // opcional, default ''
readonly userId = input.required<string>();         // obrigatório (erro se ausente)
readonly count = input(0, { alias: 'value' });      // alias de binding
readonly size = input(0, { transform: numberAttribute }); // coerção

readonly value = model(0);                           // two-way binding: [(value)]="x"
```

- Em template: `{{ label() }}`. São **read-only** por natureza (exceto `model`, que tem `.set`/`.update`).
- `model()` cria input com two-way binding — o componente pai usa `[(value)]="sig"`.
- Preferir signal inputs a `@Input()`/`@Output()` legado: integram com `computed`/`effect` sem
  `ngOnChanges`.

## 8. Outputs (`output`)

```ts
import { output } from '@angular/core';

readonly closed = output<void>();
readonly valueChanged = output<number>();

emitChange(v: number) { this.valueChanged.emit(v); }
```

- No pai: `<custom-slider (valueChanged)="onChange($event)" />`.
- Interop: `outputFromObservable(obs$)` e `outputToObservable(this.valueChanged)` para pontes com RxJS.
- Evite `@Output() EventEmitter` em código novo.

## 9. Interop RxJS (`toSignal` / `toObservable`)

Signals para state; RxJS para streams. Faça a ponte na fronteira:

```ts
import { toSignal, toObservable } from '@angular/core/rxjs-interop';

readonly user = toSignal(this.http.get<User>('/api/me'), { initialValue: null });

readonly query = signal('');
readonly results = toSignal(
  toObservable(this.query).pipe(
    debounceTime(300),
    switchMap(q => this.api.search(q)),
  ),
  { initialValue: [] },
);
```

- `toSignal` assina o Observable e cancela automaticamente no destroy do injection context.
- Use RxJS operators (`debounceTime`, `switchMap`, `combineLatest`) onde o valor de tempo/coordenação
  de streams importa; converta o resultado final em signal para consumo no template.

## 10. State em services (Signal store)

Padrão de store leve baseado em signals (sem NgRx para state simples — ver SKILL.md):

```ts
@Injectable({ providedIn: 'root' })
export class CartStore {
  private readonly _items = signal<CartItem[]>([]);
  readonly items = this._items.asReadonly();
  readonly total = computed(() => this._items().reduce((s, i) => s + i.price * i.qty, 0));
  readonly count = computed(() => this._items().length);

  add(item: CartItem) { this._items.update(list => [...list, item]); }
  remove(id: string) { this._items.update(list => list.filter(i => i.id !== id)); }
}
```

- Fonte gravável privada (`_items`), leitura readonly + `computed` públicos.
- Mutação só por métodos explícitos (imutável). NgRx `ComponentStore`/Signals Store para state
  complexo com muitos side effects (ver ADR-007).

## 11. Anti-padrões de reatividade

| Proibido | Alternativa |
|---|---|
| Derivar state em `effect` gravando outro signal | `computed` (ou `linkedSignal` se gravável) |
| `effect` para fetch de dados | `resource` / `httpResource` |
| Mutar array/objeto in-place (`arr().push(x)`) | `arr.update(a => [...a, x])` (imutável) |
| Ler signal em `effect` sem intenção de reagir | `untracked(sig)` |
| `@Input()`/`@Output()` em código novo | `input()` / `output()` / `model()` |
| Expor signal gravável do service | `asReadonly()` + métodos de mutação |
| `resource({ request })` | `resource({ params })` |
| Esquecer `abortSignal` no loader | repassar `abortSignal` ao `fetch` |
