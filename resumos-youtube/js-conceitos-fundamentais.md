# Resumo — "JavaScript: os Conceitos que Você Precisa Saber" (pt-BR, ~13:19)

Fonte: https://www.youtube.com/watch?v=vvC5g9_U0wg
Data: 30/08/2026 | Transcrição: /tmp/tr_js.json

## Tese central

"Esse código imprime `undefined`, mas não dá erro. Por quê?" — se você não consegue explicar, não entende JavaScript de verdade. O vídeo cobre os conceitos fundamentais para entrevistas e dia a dia: **hoisting, escopos, closures, event loop, promises, garbage collection e tratamento de erros** — e como eles se conectam.

## 1. Hoisting ("içamento")

- O JS **puxa as declarações pro topo do escopo** antes de executar. A declaração sobe; a **atribuição fica onde está**.
  ```js
  console.log(nome);  // undefined (não dá erro)
  var nome = 'João';
  ```
- `let`/`const` também içam, mas ficam numa **temporal dead zone** (do início do bloco até a declaração) — acessar dá erro.
- **Funções declaradas** (`function f() {}`) içam inteiras (nome + corpo). **Expressões de função** (`const f = function() {}`) seguem regras de variável (undefined, não é função).

## 2. Escopos: global, função, bloco

- **Global**: existe em qualquer lugar. **Função**: só dentro da função (`var`). **Bloco**: só dentro das chaves (`let`/`const`).
- `var` ignora blocos → o bug clássico do loop:
  ```js
  for (var i = 0; i < 3; i++)          // var: UMA variável i
    setTimeout(() => console.log(i));  // 3 3 3
  for (let i = 0; i < 3; i++)          // let: cópia por iteração
    setTimeout(() => console.log(i));  // 0 1 2
  ```
- **Scope chain**: procura no escopo atual, sobe pro pai, etc.
- Regra: `const` por padrão, `let` quando precisar reatribuir, evite `var`.

## 3. Closures

- Uma **closure** = função + o **ambiente léxico** onde foi criada (variáveis que estavam no escopo na definição). A função interna sobrevive depois que a externa terminou e **lembra** as variáveis.
- Cada chamada cria um closure independente (contadores separados).
- **Encapsulamento real**:
  ```js
  function criarConta() {
    let saldo = 100;
    return { depositar(v) { saldo += v; }, ver() { return saldo; } };
  }
  const c = criarConta();
  console.log(c.saldo);   // undefined (saldo só existe no closure)
  console.log(c.ver());   // 100
  ```
- **Cuidado com memória**: closure segurando array gigante só para usar `length` → extraia só o que precisa.

## 4. Event loop

- JS é **single-threaded** (uma coisa por vez), mas faz HTTP, timers e eventos "ao mesmo tempo". Peças:
  - **Call stack** (LIFO): onde o código executa.
  - **Web APIs**: timers, HTTP, eventos (o callback espera lá).
  - **Fila de callbacks** → o **event loop** só pega um item da fila quando a stack está **vazia**.
  - `setTimeout(fn, 0)` não é "executa agora" — é "executa assim que a stack esvaziar".
- **Microtasks vs macrotasks**: promises/microtasks vão na fila de microtasks; timers/IO na de macrotasks. **Depois de cada macrotask, esvazia TODAS as microtasks.**
  ```js
  setTimeout(() => console.log('timer'), 0);   // macrotask
  Promise.resolve().then(() => console.log('promise')); // microtask
  console.log('sync');
  // sync → promise → timer
  ```
- **Nunca bloqueie a thread**: código síncrono pesado congela a página (nenhum callback roda). Use Web Workers.

## 5. Promises

- Objeto que representa um **resultado futuro**: `pending` → `fulfilled` (valor) | `rejected` (erro).
- `resolve`/`reject` no executor; `.then` encadeia sucesso (retorna nova promise), `.catch` pega erro de qualquer ponto, `.finally` roda sempre (limpeza).
- **`Promise.all`** — todas juntas (se uma falha, todas falham); **`Promise.race`** — primeira a resolver (timeouts/fallbacks); **`Promise.allSettled`** — resultado de cada uma, sucesso ou falha.
- **`async`/`await`**: `await` pausa até a promise resolver. Não use `await` em sequência para operações independentes — com `Promise.all` são ~1s; em série são ~3s.

## 6. Garbage collection

- JS aloca e libera memória automaticamente (sem `malloc`/`free`). Ciclo: **alocar → usar → liberar**.
- **Alcançabilidade** (reachability): objeto é alcançável se há caminho de uma **raiz** (globals, funções em execução). Sem caminho = lixo.
- **Mark and Sweep**: marca os alcançáveis, varre o resto.
- **Vazamentos reais** (o GC não pega):
  - `setInterval` referenciando dados → **limpe o interval** (guarde o ID).
  - Listener que mantém closure vivo → remova no cleanup (React: `useEffect`).
  - Esquecer `let`/`const` → **variável global acidental** (strict mode pega).
  - `Map` normal mantém chaves vivas; **`WeakMap`** mantém referências fracas (perfeito para caches).

## 7. Tratamento de erros

- `try`/`catch`/`finally`: `finally` roda sempre — mas **evite `return` no finally** (substitui o return do try); use só para limpeza.
- Objeto de erro: `name`, `message`, `stack`. Use **tipos específicos** e **erros customizados** (`class MeuErro extends Error { campo }`), cheque com `instanceof`.
- **Promise sem `.catch` é bomba-relógio** (no Node, rejeição não tratada derruba o processo). `async`/`await` → use `try/catch` normal.
- **Handlers globais** (rede de segurança): logue e notifique monitoramento. **Nunca engula erros silenciosamente**; relance o que não sabe tratar.

## Mapa de sintomas

| Sintoma | Conceito |
|---|---|
| Callback na ordem errada | Event loop |
| `undefined` quando não devia | Hoisting / escopo |
| Função lembrando valor antigo | Closures |
| Código assíncrono na ordem errada | Promises + event loop |
| Memória crescendo sem parar | GC + closures |
| Erro derrubando o app | Tratamento de erros |

---

## Exemplos de código — JavaScript (Node 24)

### 1. Hoisting, escopos e o bug do `var` vs `let`
```js
// Node 24 — hoisting + escopo + closure no loop
console.log(nome);        // undefined: var iça, atribuicao nao
var nome = 'Joao';

// console.log(idade);    // ReferenceError: temporal dead zone
let idade = 30;

console.log(typeof saudar);           // function: declaracao iça inteira
function saudar() { return 'oi'; }

console.log(typeof falar);            // undefined: expressao iça como var
var falar = function () { return 'tchau'; };

// bug classico: var no loop
const callbacksVar = [];
for (var i = 0; i < 3; i++) {
  callbacksVar.push(() => i);
}
// let no loop: copia por iteracao
const callbacksLet = [];
for (let j = 0; j < 3; j++) {
  callbacksLet.push(() => j);
}
console.log('var :', callbacksVar.map(f => f()));  // [3, 3, 3]
console.log('let :', callbacksLet.map(f => f()));  // [0, 1, 2]
// undefined
// function
// undefined
// var : [ 3, 3, 3 ]
// let : [ 0, 1, 2 ]
```

### 2. Closures + encapsulamento + event loop
```js
// Node 24 — closure com estado privado + event loop
function criarContador() {
  let contagem = 0;                 // so existe no closure
  return {
    incr() { return ++contagem; },
    ver() { return contagem; },
  };
}
const a = criarContador();
const b = criarContador();
a.incr(); a.incr(); b.incr();
console.log('a:', a.ver(), 'b:', b.ver(), 'a.contagem:', a.contagem);
// a: 2 b: 1 a.contagem: undefined (encapsulado)

// event loop: microtasks antes de macrotasks
console.log('sync');
setTimeout(() => console.log('timer (macrotask)'), 0);
Promise.resolve().then(() => console.log('promise (microtask)'));
queueMicrotask(() => console.log('microtask manual'));
// sync
// promise (microtask)
// microtask manual
// timer (macrotask)
```

### 3. Promises, GC e tratamento de erros
```js
// Node 24 — Promise.all vs sequencial + WeakMap + erros
const espera = ms => new Promise(r => setTimeout(r, ms));

async function sequencial() {
  const t0 = Date.now();
  await espera(200); await espera(200);   // 400ms
  console.log('sequencial:', Date.now() - t0, 'ms');
}
async function paralelo() {
  const t0 = Date.now();
  await Promise.all([espera(200), espera(200)]);  // ~200ms
  console.log('paralelo:', Date.now() - t0, 'ms');
}

// WeakMap: chave fraca — cache que nao vaza
const cache = new WeakMap();
const obj = { id: 1 };
cache.set(obj, 'valor pesado');
console.log('cache:', cache.get(obj));   // valor pesado
// (quando obj sair de escopo, a entrada e coletada)

// erros customizados + instanceof
class CampoInvalidoError extends Error {
  constructor(campo) { super(`campo invalido: ${campo}`); this.campo = campo; }
}
try {
  throw new CampoInvalidoError('email');
} catch (e) {
  if (e instanceof CampoInvalidoError) {
    console.log('erro de dominio:', e.campo);  // erro de dominio: email
  } else {
    throw e;   // relanca o que nao sabe tratar
  }
} finally {
  console.log('limpeza sempre roda');
}

(async () => {
  await sequencial();   // sequencial: ~400 ms
  await paralelo();     // paralelo: ~200 ms
})();
// cache: valor pesado
// erro de dominio: email
// limpeza sempre roda
// sequencial: ~400 ms
// paralelo: ~200 ms
```

---

## Destaques

- **Hoisting**: declaração sobe, atribuição fica; `let`/`const` = temporal dead zone; função declarada iça inteira.
- **Escopo**: global/função/bloco; `var` ignora bloco (bug do loop); `const` por padrão.
- **Closure** = função + ambiente léxico; encapsula estado e vaza memória se não cuidar.
- **Event loop**: microtasks esvaziam antes de cada macrotask; `setTimeout(0)` = "quando a stack esvaziar".
- **Promises**: `all` paralelo vs `await` em sequência; sempre `.catch`.
- **GC**: mark-and-sweep por alcançabilidade; vazamentos = timers/listeners/closures/globais — `WeakMap` para caches.
- **Erros**: tipos específicos, `instanceof`, `finally` só para limpeza, nunca engolir.