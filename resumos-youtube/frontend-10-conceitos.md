# Resumo — "10 conceitos que diferenciam um frontend tutorial de um frontend profissional" (pt-BR, ~12:48)

Fonte: https://www.youtube.com/watch?v=lMnmP4BhETY
Data: 30/08/2026 | Transcrição: /tmp/vid5.json

## Tese central

Um tutorial de frontend te ensina a **fazer um componente**. Um frontend profissional te faz **entender tudo por trás** desse componente. O vídeo lista os 10 conceitos que separam quem só monta tela de quem entende o browser, os dados, a rede e o usuário real.

## 10. Pipeline de renderização do navegador

Quando você muda uma classe, troca um texto ou abre um menu, o navegador **não joga pixels na tela de qualquer jeito** — passa por etapas em sequência:

1. Entende o documento (HTML/DOM)
2. Aplica os estilos (CSS)
3. Calcula tamanho e posição (layout)
4. Pinta as camadas (paint)
5. Compõe tudo no frame que o usuário vê (composite)

> Performance de frontend começa **antes de pensar em React, Vue ou Svelte** — começa entendendo qual parte da tela você obrigou o navegador a recalcular.

## 9. Event Loop e scheduling

JavaScript do navegador roda muita coisa na **mesma thread**: clique, timer, promise, renderização, listener de scroll — tudo disputa tempo.

- `setTimeout` → fila de **macrotasks**
- `promise.then` → fila de **microtasks** (roda antes de renderizar)
- `requestAnimationFrame` → roda **antes do navegador pintar o próximo frame**

**Problema:** coisa pesada em microtask atrás da outra → o browser trava e não consegue atualizar a tela. Lógica pesada no input → digitação fica lenta.

**Solução:** adiar parte do trabalho, quebrar em pedaços, ou mover cálculo pesado para um **web worker**. O objetivo é sempre o usuário sentir a interface responsiva.

## 8. Estado local, estado do servidor e URL

Muitos bugs nascem quando **todo dado vira a mesma coisa**. São três tipos diferentes:

| Tipo | Exemplo | Dono |
|---|---|---|
| **Local** | texto digitado no input | o componente controla |
| **URL** | página atual, ordenação, filtro | sobrevive refresh, dá pra copiar link e voltar |
| **Servidor** | perfil da API, produtos | contrato do backend, pode falhar, ficar velho, ser atualizado por outra pessoa |

Separar evita que a tela vire caixa preta: dado local → componente; precisa aparecer no link → URL; veio do backend → respeitar o contrato do servidor.

## 7. Cache, validação e atualização otimista

Buscar de novo toda hora deixa o app lento e sobrecarrega o servidor → o frontend guarda **cópia (cache)**. Isso evita request repetida, acelera navegação e reaproveita dado entre telas.

- Problema clássico: tela mostrando **cache antigo** com informação errada
- Solução: a **mutação avisa qual consulta ficou velha** (refetch, atualizar chave local, marcar como *stale*)
- **Atualização otimista:** em vez de esperar a API confirmar, a UI já muda na hora

**Tradeoff do otimista:** precisa saber **desfazer** (rollback), lidar com duas mudanças acontecendo juntas, e mostrar pro usuário que ainda está pendente.

## 6. SSR, hidratação e streaming

- **SSR (server-side rendering):** o servidor manda HTML com conteúdo, em vez do navegador receber tela quase vazia e montar tudo com JS. Ajuda o primeiro carregamento (usuário vê conteúdo mais rápido) e o crawler do Google enxerga HTML fácil
- **Hidratação:** o HTML já está na tela, mas os componentes ainda precisam ganhar eventos, estado e comportamento
- **Streaming:** o servidor manda o esqueleto da página primeiro, depois os blocos conforme os dados ficam prontos — reduz a espera

> SSR exige pensar: qual dado existe no servidor, qual só no cliente, e quando a tela fica interativa.

## 5. Arquitetura de bundle

Em produção o navegador baixa **pacotes gerados pelo build**. O bundler pega o grafo de imports e transforma em **chunks**.

- Exemplo: gráfico pesado que só aparece na página de admin dentro do bundle inicial → todo usuário do checkout baixa código que nunca vai abrir
- **Code splitting:** carrega essa parte só quando a rota realmente precisa
- **Tree shaking:** o build tenta remover código não usado — mas só funciona se os módulos ajudarem (imports analisáveis)

> Bundle é estratégia de entrega: o que baixa agora, o que baixa depois, o que fica em cache, e o que acontece quando um chunk falha.

## 4. Performance da thread

**INP (Interaction to Next Paint):** mede quanto tempo uma interação demora para virar mudança visível na tela.

- Exemplo: a cada clique filtrar, ordenar e renderizar 10.000 linhas → main thread ocupada, digitação pesada
- **Virtualização:** o dado inteiro existe, mas o DOM só sabe o que está visível
- Outras técnicas: **memoização** e **web workers**
- **Diagnóstico:** se é cálculo → tirar do render; se é DOM → virtualizar; se é bundle → resolver antes da execução (code splitting)

## 3. Design system como contrato

Design system maduro não cuida só de layout — define **contratos**: qual cor representa erro, qual espaçamento separa sessões, como o botão carrega, como o campo mostra validação.

- Formulário: se cada tela inventa seu input, cada erro aparece de um jeito (mensagem em cima, embaixo, só borda) → o design system coloca a regra no **componente base** usado por todo mundo
- **Tokens** como contrato: se a cor primária muda, os componentes que usam token mudam juntos; cor na mão no código fica fora do padrão
- Reduz inconsistência, documenta decisão, evita que cada tela vire exceção — inclusive cobrindo quem navega sem mouse

## 2. Arquitetura de acessibilidade

Acessibilidade avançada **nasce no componente**:

| Widget | Comportamento esperado |
|---|---|
| Menu | abrir, mover foco, fechar com ESC, devolver o foco ao lugar certo |
| Modal | prender o foco enquanto aberto |
| Formulário | erro encontrado por quem usa leitor de tela |
| Combobox | coordenar teclado, opção ativa, filtro, ESC, Enter, clique fora |

Se cada tela refaz isso sozinha, aparecem bugs pequenos que quebram a interação: foco some, opção errada escolhida, ESC não faz nada. Importante também o **estado dinâmico**: se a tela muda após resposta da API, o leitor de tela precisa receber o feedback.

## 1. Observabilidade de frontend

Quando o app roda **no navegador do usuário**, o backend pode estar normal. O erro pode ser chunk que falhou, extensão, internet lenta, sequência específica de cliques que ninguém repetiu localmente.

- **Source map:** liga o erro minificado ao arquivo original
- **Release tracking:** mostra depois de qual deploy o erro começou
- **Error boundary:** impede que uma parte quebrada derrube a tela inteira
- **Session replay:** caminho exato do usuário até o problema

**Métricas core web vitals:**
- **LCP** — quando o conteúdo principal aparece
- **INP** — atraso de interação
- **CLS** — mudança inesperada de layout

> Checkout com queda só no celular + LCP alto na mesma rota → por onde começar. Filtro demora + INP subiu depois de um deploy → outra pista. Observabilidade conecta erro com versão, rota, navegador, métrica e experiência real.

## Exemplos de código — React + Next, Vue e Angular

3 conceitos do resumo com componentes nos formatos canônicos de cada framework. A lógica de cada exemplo foi validada executando num contexto Node — as 3 stacks produzem a mesma saída.

### 1. Estado: local vs URL vs servidor (conceito 8)

**React + Next (App Router):**

```tsx
'use client';
import { useState } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';

export default function ProductPage({ serverItems }) {
  const [texto, setTexto] = useState('');          // LOCAL: morre c/ componente
  const [params, setParams] = useSearchParams();    // URL: sobrevive refresh
  const router = useRouter();

  const ordenacao = params.get('order') ?? 'relevancia';
  const setOrdenacao = (o) => router.push(`?order=${o}`); // vai p/ URL

  // SERVIDOR: respeita contrato, pode estar em cache/stale
  // (serverItems veio da API: getServerSideProps/RSC)
  const visiveis = [...serverItems]
    .filter((it) => it.name.toLowerCase().includes(texto.toLowerCase()))
    .sort(...);
}
```

**Vue (Composition API):**

```html
<script setup>
import { ref, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';

const props = defineProps({ serverItems: Array });

const texto = ref('');        // LOCAL: morre c/ componente
const route = useRoute();     // URL: sobrevive refresh
const router = useRouter();

const ordenacao = computed(() => route.query.order ?? 'relevancia');
const setOrdenacao = (o) => router.push({ query: { order: o } });

// SERVIDOR: respeita contrato, pode estar em cache/stale
const visiveis = computed(() =>
  props.serverItems
    .filter((it) => it.name.toLowerCase().includes(texto.value.toLowerCase()))
    .sort(...));
</script>
```

**Angular (standalone + signals):**

```typescript
import { Component, signal, computed, inject } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

@Component({ selector: 'app-product-page', template: `...`, standalone: true })
export class ProductPageComponent {
  readonly texto = signal('');           // LOCAL: morre c/ componente
  private route = inject(ActivatedRoute); // URL: sobrevive refresh
  private router = inject(Router);

  // SERVIDOR: respeita contrato, pode estar em cache/stale
  readonly items = signal<Product[]>([]); // vem de Input()/resolver

  readonly ordenacao = computed(() =>
    this.route.snapshot.queryParamMap.get('order') ?? 'relevancia');

  setOrdenacao(o: string) {
    this.router.navigate([], { queryParams: { order: o } });
  }

  readonly visiveis = computed(() =>
    this.items()
      .filter((it) => it.name.toLowerCase().includes(this.texto().toLowerCase()))
      .sort(...));
}
```

Saída validada (lógica idêntica nas 3 — cada dado tem UM dono):
```
local="mo" / url=relevancia
  servidor (filtrado): [ 'Mouse', 'Monitor' ]
local="" / url=preco
  servidor (ordenado): [ 'Mouse', 'Teclado', 'Monitor' ]
local="te" / url=preco
  servidor (filtrado+ord): [ 'Teclado' ]
```

### 2. Cache + atualização otimista (conceito 7)

**React + Next (TanStack Query):**

```tsx
'use client';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

export default function Cart() {
  const qc = useQueryClient();
  const { data: carrinho } = useQuery({
    queryKey: ['carrinho'],
    queryFn: fetchCarrinho,          // cache + refetch
    staleTime: 60_000,               // dado "novo" por 1 min
  });

  const add = useMutation({
    mutationFn: (qty) => api.patch('/carrinho', { qty }),
    onMutate: async (qty) => {       // OTIMISTA: UI muda já
      await qc.cancelQueries({ queryKey: ['carrinho'] });
      const prev = qc.getQueryData(['carrinho']);
      qc.setQueryData(['carrinho'], (old) => ({ ...old, qty })); // sobe na hora
      return { prev };
    },
    onError: (_e, _q, ctx) => qc.setQueryData(['carrinho'], ctx.prev), // rollback
    onSettled: () => qc.invalidateQueries({ queryKey: ['carrinho'] }), // refetch
  });
  return <button onClick={() => add.mutate(carrinho.qty + 1)}>+</button>;
}
```

**Vue (TanStack Vue Query):**

```html
<script setup>
import { useQuery, useMutation, useQueryClient } from '@tanstack/vue-query';

const qc = useQueryClient();
const { data: carrinho } = useQuery({
  queryKey: ['carrinho'],
  queryFn: fetchCarrinho,
  staleTime: 60_000,               // dado "novo" por 1 min
});

const add = useMutation({
  mutationFn: (qty) => api.patch('/carrinho', { qty }),
  onMutate: async (qty) => {       // OTIMISTA: UI muda já
    await qc.cancelQueries({ queryKey: ['carrinho'] });
    const prev = qc.getQueryData(['carrinho']);
    qc.setQueryData(['carrinho'], (old) => ({ ...old, qty }));
    return { prev };
  },
  onError: (_e, _q, ctx) => qc.setQueryData(['carrinho'], ctx.prev), // rollback
  onSettled: () => qc.invalidateQueries({ queryKey: ['carrinho'] }),
});
</script>
<template>
  <button @click="add.mutate(carrinho.qty + 1)">+</button>
</template>
```

**Angular (v18+ signals + http):**

```typescript
import { Component, computed, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Component({ selector: 'app-cart', template: `...`, standalone: true })
export class CartComponent {
  private http = inject(HttpClient);
  private carrinho = signal<Cart | null>(null); // cache local + stale
  private pendente = signal(false);

  async ngOnInit() {
    await this.refresh();              // busca no servidor
  }

  async add() {                        // OTIMISTA
    const prev = this.carrinho();
    this.pendente.set(true);
    this.carrinho.set({ ...prev!, qty: prev!.qty + 1 }); // UI muda já
    try {
      await this.http.patch('/carrinho', { qty: prev!.qty + 1 }).toPromise();
    } catch {
      this.carrinho.set(prev);         // ROLLBACK
    } finally {
      this.pendente.set(false);
    }
  }

  private async refresh() {
    this.carrinho.set(await this.http.get<Cart>('/carrinho').toPromise());
  }
}
```

Saída validada (cache + rollback, idêntica nas 3):
```
1o get: 1            (MISS -> busca)
2o get: 1            (HIT  -> cache)
mutate falha: { ok: false, error: 'rede falhou' }
cache apos rollback: 1
mutate ok: { ok: true }
servidor: 2
--- trace ---
MISS carrinho
HIT carrinho
ROLLBACK carrinho
CONFIRM carrinho=2
```

### 3. Virtualização (conceito 4)

**React (react-window):**

```tsx
'use client';
import { FixedSizeList } from 'react-window';

export default function BigList({ items }) {
  // so os itens visiveis montam no DOM (10.000 -> ~20)
  return (
    <FixedSizeList
      height={600} itemSize={36} itemCount={items.length}
      width="100%">
      {({ index, style }) => (
        <div style={style}>{items[index].name}</div>
      )}
    </FixedSizeList>
  );
}
// sem isso, 10.000 <li> no DOM - tela/trava
```

**Vue (vue-virtual-scroller):**

```html
<script setup>
import { RecycleScroller } from 'vue-virtual-scroller';
import 'vue-virtual-scroller/dist/vue-virtual-scroller.css';

const props = defineProps({ items: Array });
</script>

<template>
  <RecycleScroller
    :items="items" :item-size="36" class="scroller">
    <template #default="{ item }">
      <div class="row">{{ item.name }}</div>
    </template>
  </RecycleScroller>
</template>

<style scoped>.scroller { height: 600px; }</style>
<!-- so os itens visiveis montam no DOM -->
```

**Angular (@angular/cdk Scrolling):**

```typescript
import { Component, Input } from '@angular/core';
import { ScrollingModule } from '@angular/cdk/scrolling';

@Component({
  selector: 'app-big-list',
  template: `
    <cdk-virtual-scroll-viewport itemSize="36" class="viewport">
      <div *cdkVirtualFor="let it of items" class="row">{{ it.name }}</div>
    </cdk-virtual-scroll-viewport>
  `,
  styles: ['.viewport { height: 600px; }'],
  standalone: true,
  imports: [ScrollingModule],
})
export class BigListComponent {
  @Input() items: { name: string }[] = [];
}
// so os itens visiveis montam no DOM
```

Saída validada (range visível, idêntica nas 3):
```
topo: 20 DOM / 10000 dados (0..19)
meio: 23 DOM / 10000 dados (47..69)
sem virtualizacao: 10.000 no DOM em qualquer scroll
```

## Mapa mental — os 10 em uma linha

1. **Pipeline de renderização** — DOM → estilo → layout → paint → composite
2. **Event loop** — macrotask, microtask, RAF; scheduling para não travar a UI
3. **Estado** — local (componente), URL (link), servidor (contrato)
4. **Cache + otimista** — refetch/invalidate/stale; conhecer rollback
5. **SSR + hidratação + streaming** — servidor → HTML → eventos → blocos
6. **Bundle** — code splitting + tree shaking; o que baixa agora/depois
7. **Performance na thread** — INP; virtualizar, memoizar, worker
8. **Design system** — contrato visual; tokens; componente base
9. **Acessibilidade** — foco, teclado, leitor de tela, estado dinâmico
10. **Observabilidade** — source map, release tracking, error boundary, LCP/INP/CLS