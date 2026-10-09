# Resumo — "O que React, Vue e Angular fazem por baixo dos panos" (pt-BR, ~12:48)

Fonte: https://www.youtube.com/watch?v=JsvVohoIdt8
Data: 30/08/2026 | Transcrição: /tmp/vid6.json

## Tese central

Você usa React, Vue ou Angular todo dia — mas sabe o que esses frameworks fazem **por baixo dos panos**? Os 10 conceitos internos explicam por que frameworks se comportam de certas maneiras e como evitar bugs comuns.

## 10. Gerenciamento de estado

Todo framework resolve **como os dados fluem entre componentes**.

- **Prop drilling:** nome do usuário logado no componente raiz, mas quem mostra é um componente 5 níveis abaixo → precisa passar por intermediários que nem usam o dado. A solução é um **canal direto** entre quem produz e quem consome (context/store/provide-inject)
- **Estado local** (input, item selecionado) fica dentro do componente e morre com ele
- **Estado global** (usuário logado, tema, carrinho) para dados que vários componentes precisam
- Cuidado: colocar tudo no global rerenderiza componentes que não precisavam atualizar

> **Valor derivado:** se algo pode ser calculado a partir de outro estado (ex.: `filtrados` a partir de `itens` + `filtro`), **não crie estado novo — apenas derive**. Com estado duplicado, esquecer de atualizar o derivado deixa os dois fora de sincronia.

## 9. Agrupamento de atualizações (batching)

Clicou num botão e mudou 3 estados (nome, e-mail, endereço):

- **Sem batching:** framework renderizaria o componente 3 vezes
- **Com batching:** coleta as mudanças, joga numa fila e processa tudo junto — **o DOM é atualizado uma vez** com o resultado final

> Pegadinha clássica: mudou estado e tentou ler o DOM logo em seguida → valor ainda é o antigo (o DOM só atualiza depois que o framework processa a fila).

## 8. Tree shaking e code splitting

O bundler junta todos os arquivos JS num pacote — app grande pode passar de 2 MB, e o usuário baixa tudo antes de ver qualquer coisa.

- **Tree shaking:** remove funções/módulos não importados. Importar lodash inteiro = 70 KB; importar só `debounce` = 2 KB. Importar de forma específica ajuda mais ainda
- **Code splitting:** divide o bundle em pedaços — Home baixa só o JS da Home, Dashboard só o chunk do Dashboard quando navega. Marcar componente como **lazy** → baixa só quando o usuário precisa

> Tree shaking remove **código morto**; code splitting divide o **código vivo** em pedaços menores.

## 7. Ciclo de vida do componente

Três fases: **monta** (aparece na tela), **atualiza** (estado/props mudam), **desmonta** (sai da tela). Cada framework dá hooks para executar código nessas fases.

> **Cleanup é essencial:** componente de chat que abre WebSocket ao montar precisa fechar ao desmontar. Trocar de sala 3 vezes sem cleanup = 3 conexões abertas. Timers, event listeners e conexões que nunca fecham acumulam lixo na memória.

## 6. Compilação

O navegador **não entende** JSX, templates `.vue` ou extensões próprias — tudo é transformado em JS puro no build:

- Templates viram **instruções de DOM**, expressões viram **lógica de atualização**
- **Tradeoff:** frameworks com mais runtime no navegador (mais flexibilidade em runtime) vs frameworks que fazem mais no compilador (instruções específicas por componente, quase nada de runtime)

## 5. Roteamento no cliente

- **Site tradicional:** clicar num link → requisição ao servidor → HTML novo → renderiza do zero (pisca, perde estado, ~meio segundo)
- **SPA:** JS intercepta o clique, atualiza a URL e troca o conteúdo na tela — sem requisição, praticamente instantâneo
- Por baixo: **History API** — `pushState` muda a URL sem requisição; `popstate` dispara no botão voltar
- **Problema:** digitar `site.com/produtos` direto → servidor precisa estar configurado para devolver `index.html` para todas as rotas, senão 404 (fallback de rota)

## 4. Hydration

Com SSR, o servidor manda HTML completo → usuário vê a página quase instantânea, mas estática (botões não respondem). Aí o JS carrega e **conecta event listeners e estado a cada elemento** — isso é hydration.

- Vantagem: conteúdo visível antes do JS carregar (conexão lenta = usuário fica)
- **Divergência de hydration:** se o HTML do servidor difere do que o JS gera no cliente, o framework reclama ou renderiza tudo de novo (perde a vantagem do SSR)
- **Arquitetura de ilhas:** página quase toda em HTML puro, só os componentes interativos recebem hydration → menos JS, carrega mais rápido

## 3. Sistema de reatividade

Como o framework descobre o que mudou quando o estado muda?

- **Virtual DOM:** a cada mudança, cria cópia da árvore na memória, compara com a antiga e aplica só as diferenças no DOM. Você escreve como se renderizasse tudo — o framework atualiza só o que mudou
- **Signals:** o framework sabe exatamente qual variável está ligada a qual elemento — quando `count` muda, vai direto no elemento certo, sem diff nem varredura. Em runtime com proxies, ou em tempo de compilação gerando JS que já sabe quais instruções rodar

> Virtual DOM funciona bem para a maioria; em listas com milhares de itens ou animações pesadas, signals têm vantagem (pulam a comparação).

## 2. Reconciliação

Algoritmo que descobre **o que mudou entre um render e outro**:

- **Tipo do elemento mudou** (div → span): destrói o antigo e cria novo do zero
- **Mesmo tipo:** só atualiza as props que mudaram
- **Listas precisam de key:** sem key compara por **posição** (primeiro com primeiro, segundo com segundo). Deletou o item do meio → acha que os últimos mudaram e recria
- **Com key** compara por **identidade** — só o item removido sai, os outros preservados

> **Erro mais comum:** usar o `index` da lista como key. Só funciona em lista estática; ao adicionar/remover/reordenar, o framework confunde componentes, inputs perdem texto, animações resetam, estado vaza. E para resetar um componente de propósito, basta mudar a key (remonta do zero).

## 1. O DOM (a base de tudo)

O navegador transforma HTML numa **árvore de objetos na memória** — cada tag vira um nó com propriedades, métodos e relações. JavaScript interage com a página **através do DOM**: `querySelector` acessa um objeto na memória; `textContent` atualiza a tela.

- Cada mudança no DOM tem custo: recalcular estilos, recalcular layout, repintar pixels
- Mudanças em sequência deixam o navegador lento
- **Frameworks existem para minimizar quantas vezes o DOM é tocado** — reconciliação, reatividade e batching giram em torno disso, e também para você ser produtivo (estado, ciclo de vida, routing organizam o código)

## Exemplos de código — React + Next, Vue e Angular

3 conceitos com componentes reais nos formatos canônicos de cada framework. A lógica de cada exemplo foi validada executando num contexto Node (as 3 stacks produzem a mesma saída).

### 1. Estado derivado — sem estado duplicado

**React + Next (App Router):**

```tsx
'use client';
import { useMemo, useState } from 'react';

export default function ProductList({ items }) {
  const [query, setQuery] = useState('');
  // filtrados é DERIVADO de items + query — não é estado próprio
  const filtered = useMemo(
    () => items.filter((it) => it.name.toLowerCase().includes(query.toLowerCase())),
    [items, query],
  );
  return (
    <>
      <input value={query} onChange={(e) => setQuery(e.target.value)} />
      <ul>{filtered.map((it) => <li key={it.id}>{it.name}</li>)}</ul>
    </>
  );
}
```

**Vue (Composition API):**

```html
<script setup>
import { ref, computed } from 'vue';

const props = defineProps({ items: Array });
const query = ref('');

// filtrados é DERIVADO de items + query — não é estado próprio
const filtered = computed(() =>
  props.items.filter((it) =>
    it.name.toLowerCase().includes(query.value.toLowerCase())));
</script>

<template>
  <input v-model="query" />
  <ul><li v-for="it in filtered" :key="it.id">{{ it.name }}</li></ul>
</template>
```

**Angular (standalone + signals):**

```typescript
import { Component, computed, signal } from '@angular/core';

@Component({
  selector: 'app-product-list',
  template: `
    <input [value]="query()" (input)="query.set($any($event.target).value)" />
    <ul>
      <li *ngFor="let it of filtered(); trackBy: trackById">{{ it.name }}</li>
    </ul>
  `,
  standalone: true,
})
export class ProductListComponent {
  query = signal('');
  items = signal([...]); // vem de Input() num app real

  // filtrados é DERIVADO (computed) — não é estado próprio
  filtered = computed(() =>
    this.items().filter((it) =>
      it.name.toLowerCase().includes(this.query().toLowerCase())));

  trackById(_i: number, it: { id: number }) { return it.id; }
}
```

Saída validada (lógica idêntica nas 3):
```
query      : mo
filtrados  : [ 'Mouse', 'Monitor' ]
query nova : te
filtrados  : [ 'Teclado' ]
```

### 2. Ciclo de vida — cleanup de conexão (WebSocket)

**React:**

```tsx
'use client';
import { useEffect } from 'react';

export default function ChatRoom({ roomId }) {
  useEffect(() => {
    const ws = connect(roomId);         // montou -> abre conexão
    return () => ws.close();            // desmontou -> fecha (cleanup)
  }, [roomId]);                         // trocou de sala -> abre/fecha de novo
  return <div className="chat">…</div>;
}
```

**Vue:**

```html
<script setup>
import { onMounted, onUnmounted } from 'vue';

const props = defineProps({ roomId: String });
let ws;

onMounted(() => { ws = connect(props.roomId); });   // montou -> abre
onUnmounted(() => ws.close());                      // desmontou -> fecha
</script>

<template><div class="chat">…</div></template>
```

**Angular:**

```typescript
import { Component, DestroyRef, inject } from '@angular/core';

@Component({
  selector: 'app-chat-room',
  template: `<div class="chat">…</div>`,
  standalone: true,
})
export class ChatRoomComponent {
  private ws: any;
  private destroyRef = inject(DestroyRef);

  constructor() {
    this.ws = connect(this.roomId);        // montou -> abre
    this.destroyRef.onDestroy(() => this.ws.close()); // desmontou -> fecha
  }
}
```

Saída validada (contador de conexões abertas, idêntica nas 3):
```
[mount] conexao aberta (sala a) — total 1
[unmount] conexao fechada — total 0
[mount] conexao aberta (sala b) — total 1
[mount] conexao aberta (sala c) — total 1
[fim] total de conexoes abertas: 0
```

### 3. Reconciliação — key / trackBy (identidade vs posição)

**React** — `key`:

```tsx
<ul>
  {items.map((it) => (
    <li key={it.id}>{it.name}</li>   // key = identidade
  ))}
</ul>
// ERRADO: key={index} — quebra ao adicionar/remover/reordenar
```

**Vue** — `:key`:

```html
<ul>
  <li v-for="it in items" :key="it.id">{{ it.name }}</li>
</ul>
<!-- ERRADO: :key="index" — só funciona em lista estática -->
```

**Angular** — `trackBy`:

```typescript
// no template: *ngFor="let it of items; trackBy: trackById"
trackById(_index: number, it: { id: number }) {
  return it.id;   // identidade preservada
}
// ERRADO: sem trackBy — compara por posição
```

Saída validada (diff simulado, idêntica nas 3 — remover Bruno do meio):
```
=== SEM key (por posicao) ===
atualiza pos 1: Bruno -> Carla
remove Carla da pos 2

=== COM key (por identidade) ===
remove Bruno (era o do meio)
move Carla p/ pos 1
```

Sem key o framework acha que Carla mudou (perde estado/input); com key só Bruno sai.

## Mapa mental — os 10 em uma linha

1. **Estado** — local (componente), global (context/store); **derive, não duplique**
2. **Batching** — agrupa mudanças, DOM atualiza uma vez; não ler DOM logo após setState
3. **Tree shaking + code splitting** — remove código morto, divide o vivo (lazy)
4. **Ciclo de vida** — monta/atualiza/desmonta; cleanup sempre (ws, timer, listener)
5. **Compilação** — JSX/template → JS puro no build; tradeoff runtime vs compilador
6. **Roteamento cliente** — History API (pushState/popstate); fallback do servidor p/ todas as rotas
7. **Hydration** — HTML do SSR ganha vida; divergência = problema; ilhas p/ menos JS
8. **Reatividade** — Virtual DOM (diff) vs signals (direto no elemento)
9. **Reconciliação** — tipo mudou → remonta; mesmas props → atualiza; key = identidade
10. **DOM** — árvore de objetos; tocar o DOM é caro; frameworks minimizam os toques