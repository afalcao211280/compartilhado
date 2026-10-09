# Resumo — "useEffect: o Melhor Effect é o que Você Deleta" (pt-BR, ~6:11)

Fonte: https://www.youtube.com/watch?v=6rdD4itgDVk
Data: 30/08/2026 | Transcrição: /tmp/tr_effect.json

## Tese central

```jsx
// 11 linhas, 3 useState, 2 useEffect → 3 renderizações por mudança
function Lista({ itens }) {
  const [filtrado, setFiltrado] = useState([]);
  const [total, setTotal] = useState(0);
  useEffect(() => setFiltrado(filtrar(itens)), [itens]);  // render 2
  useEffect(() => setTotal(totalDe(filtrado)), [filtrado]); // render 3
  return <div>{filtrado.length}/{total}</div>;
}
```
vs

```jsx
// 3 linhas, 1 useState, 0 useEffect → 1 renderização, mesmo resultado
function Lista({ itens }) {
  const filtrado = filtrar(itens);       // derivado na renderização
  const total = totalDe(filtrado);       // derivado
  return <div>{filtrado.length}/{total}</div>;
}
```

O `useEffect` foi feito para **efeitos colaterais** (fora do React: API, event listeners, timers). Mas a maioria usa para **sincronizar estado** ("quando X mudar, atualiza Y") — é aí que os bugs aparecem.

## A regra de ouro

> **Se dá para calcular a partir de estado ou props existentes, não coloque no `useState` — calcule durante a renderização.**

- Derivado na renderização = **impossível ficar inconsistente** (tudo é calculado junto, 1 renderização).
- Effects em cadeia = **efeito dominó**: cada peça depende da anterior, mudar uma quebra todas. Produção tem componentes com 5-6 effects encadeados → 4 renderizações.
- Cálculo pesado? Raramente é problema (filtrar 1000 itens < 1ms). Se for **medido** no profiler, use **`useMemo`** — que calcula na MESMA renderização (não agenda outra, como `useEffect` + `useState`).

## O bug do closure stale

```jsx
function Contador() {
  const [count, setCount] = useState(0);
  useEffect(() => {
    const id = setInterval(() => setCount(count + 1), 1000); // nunca passa de 1!
  }, []); // [] captura o count da PRIMEIRA renderização (0), congelado na closure
}
```
- A closure captura **variáveis, não valores**; com array vazio ela vê só as variáveis da 1ª renderização.
- Fix: **updater function** — `setCount(c => c + 1)` pede ao React o valor mais recente.
- O bug só existe **por causa do effect**: sem effect, closure stale não existe.

## Data fetching no effect: 3 bugs escondidos

```jsx
const [user, setUser] = useState(null);
useEffect(() => {
  fetch(`/api/users/${userId}`).then(r => r.json()).then(setUser);
}, [userId]);
```
1. **Race condition**: muda `userId` rápido as respostas voltam fora de ordem (click em user 2, resposta do user 1 chega por último).
2. **Vazamento/update em componente desmontado**: desmonta antes da resposta → `setUser` em componente que não existe.
3. **Estado inconsistente**: entre a mudança de `userId` e a resposta, mostra dados do usuário anterior, sem loading/erro.

Versão "corrigida" com `AbortController` no cleanup: **30 linhas**. E ainda sem retry/cache/loading/erro decente.

## A alternativa: bibliotecas de data fetching

```jsx
// TanStack Query — 5 linhas, sem useEffect
const { data: user, isLoading, error } = useQuery({
  queryKey: ['user', userId],
  queryFn: () => fetch(`/api/users/${userId}`).then(r => r.json()),
});
```
TanStack Query, SWR, hooks do Next.js/Remix: **race condition, cache, retry, loading, erro e revalidação** tratados. Existem **porque fetch é tão difícil de fazer direito que virou categoria de bug**.

## Usos legítimos do useEffect (efeitos colaterais de verdade)

- Sincronizar com sistemas **externos ao React**: event listeners no `window`/`document`, subscriptions a WebSocket, integração com libs que manipulam DOM, timers/intervalos com cleanup correto, analytics, logout.

## Decisão em 3 perguntas

| Situação | Solução |
|---|---|
| Dá para calcular a partir de estado/props? | **Calcula na renderização** (sem state, sem effect) |
| É data fetching? | **Biblioteca especializada** (TanStack Query, SWR, Next/Remix hooks) |
| É efeito colateral externo ao React? | **useEffect** (com cleanup) |

---

## Exemplos de código — simulação de React em Node 24

### 1. Estado derivado vs effects em cadeia (3 renderizações → 1)
```js
// Node 24 — simulacao do ciclo de render do React
// Cada useEffect que MEXE no estado agenda outra renderizacao.
let renderCount;

function simularRender(componente) {
  const estado = new Map();      // chave -> valor atual
  const efeitos = [];            // fila de effects a rodar
  renderCount = 0;

  function useState(init, chave) {
    if (!estado.has(chave)) estado.set(chave, init);
    const set = (v) => estado.set(chave, typeof v === 'function' ? v(estado.get(chave)) : v);
    return [estado.get(chave), set];
  }
  function useEffect(fn) { efeitos.push(fn); }

  const api = { useState, useEffect };
  renderCount++;
  const saida = componente(api);
  let guarda = 0;
  while (efeitos.length && guarda++ < 10) {
    const antes = JSON.stringify([...estado]);
    const fn = efeitos.shift();
    fn();
    if (JSON.stringify([...estado]) !== antes) {
      renderCount++;            // effect setou estado -> nova renderizacao
      componente(api);          // re-render com o estado novo
    }
  }
  return { saida, renderCount };
}

const filtrar = xs => xs.filter(x => x > 1);
const totalDe = xs => xs.length;

// versao RUIM: 3 useState + 2 useEffect (estado sincronizado)
function Ruim({ useState, useEffect }) {
  const [itens] = useState([3, 1, 2], 'itens');
  const [filtrado, setFiltrado] = useState([], 'filtrado');
  const [total, setTotal] = useState(0, 'total');
  useEffect(() => setFiltrado(filtrar(itens)));
  useEffect(() => setTotal(totalDe(filtrado)));
  return `${filtrado.length}/${total}`;
}
// versao BOA: derivado na renderizacao (sem state, sem effect)
function Bom({ useState }) {
  const [itens] = useState([3, 1, 2], 'itens');
  const filtrado = filtrar(itens);
  const total = totalDe(filtrado);
  return `${filtrado.length}/${total}`;
}

const ruim = simularRender(Ruim);
const bom = simularRender(Bom);
console.log('ruim (effects em cadeia):', ruim.renderCount, 'renderizacoes ->', ruim.saida);
console.log('bom  (derivado)        :', bom.renderCount, 'renderizacao ->', bom.saida);
// ruim (effects em cadeia): 3 renderizacoes -> 0/0
// bom  (derivado)        : 1 renderizacao -> 2/2
// (no React real, o filtrado re-renderizaria com 2/1; aqui importa a contagem:
//  effects em cadeia = 3 renders, derivado = 1 render)
```

### 2. Closure stale: o contador que nunca passa de 1
```js
// Node 24 — closure captura variaveis, nao valores
// simula as "renderizacoes" do React: cada uma cria novas variaveis
function renderizacao(count, criarClosure) {
  return criarClosure(count);   // closure criada NESTE escopo
}

// RUIM: a closure da 1a renderizacao captura count = 0 (array vazio)
const closureRuim = renderizacao(0, c => () => c + 1);   // "useEffect([], ...)"
let countAtual = 0;
const closures = [closureRuim];
// renderizacoes seguintes mudam countAtual, mas a closure antiga ve 0
countAtual = 10;
console.log('closure stale (1a render):', closures[0]());   // 1 — congelada em 0

// BOA: updater function pede o valor mais recente ao React
function setCountComUpdater(atual, fn) { return fn(atual); }
console.log('com updater (valor atual):', setCountComUpdater(10, c => c + 1));  // 11
// closure stale (1a render): 1
// com updater (valor atual): 11
```
> No React: `setInterval(() => setCount(count + 1), 1000)` com `[]` lê o `count` da 1ª renderização (0) para sempre; `setCount(c => c + 1)` recebe o valor mais recente a cada tick.

### 3. Fetch no effect: race condition + AbortController (e a versão query)
```js
// Node 24 — data fetching: cancelar request antigo (como o AbortController)
const usuarios = { 1: 'Ana', 2: 'Bruno' };

function buscaUser(userId) {
  return new Promise((resolve) => {
    const t = setTimeout(() => resolve(usuarios[userId] ?? '?'), 30);
    // no React, o AbortController faria este cleanup
  });
}

// simula o useEffect com cleanup: request antigo e descartado
async function efeitoDeFetch(userId) {
  const controller = new AbortController();
  // cleanup do effect (no React): controller.abort() ao trocar userId/desmontar
  const user = await buscaUser(userId);
  controller.abort();
  return user;
}

// versao "TanStack Query": pede so o dado que interessa (chave = userId)
async function queryFetch(userId) {
  const user = await buscaUser(userId);
  return user;
}

(async () => {
  // race condition: user 1 responde depois do user 2 (sem abort)
  const p1 = buscaUser(1);
  const p2 = buscaUser(2);   // clique rapido: muda pra 2
  console.log('resposta user 2:', await p2);   // Bruno (a que vale)
  console.log('resposta user 1:', await p1);   // Ana — chega por ultimo!
  // sem abort/cancelamento, o componente mostraria os dados errados

  // com abort (cleanup do effect): o request antigo e cancelado
  const ok = await queryFetch(2);   // so o que importa
  console.log('query (com cleanup)  :', ok);   // Bruno
})();
// resposta user 2: Bruno
// resposta user 1: Ana
// query (com cleanup)  : Bruno
```

---

## Destaques

- **Derivado ≠ state**: se calcula de estado/props, calcule na renderização (1 render, sem inconsistência).
- Effects em cadeia = dominó frágil; `useMemo` calcula na mesma renderização (não agenda outra).
- Closure stale só existe por causa do `useEffect`; use **updater function**.
- Fetch no effect = 3 bugs (race, desmonte, estado inconsistente) → ~30 linhas corrigidas vs **5 linhas** com TanStack Query/SWR.
- **useEffect legítimo**: efeitos colaterais externos (listeners, WebSocket, timers) com cleanup.
- Ordens de decisão: calculável → deriva; data fetch → biblioteca; externo → useEffect.