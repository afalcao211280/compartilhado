# Vue Expert — Built-ins, Performance e Split de Componentes

Leia quando a tarefa exigir um built-in (Slots/Teleport/Suspense/KeepAlive/Transition), otimização de performance, ou decisão de quebra de componente. Conteúdo opcional — não aplique por padrão.

## Índice

1. [Data Flow + Split de Componentes](#1-data-flow--split-de-componentes)
2. [Guia de decisão de built-ins](#2-guia-de-decisão-de-built-ins)
3. [Slots](#3-slots)
4. [Teleport](#4-teleport)
5. [Transition](#5-transition)
6. [KeepAlive](#6-keepalive)
7. [Suspense](#7-suspense)
8. [Passe de performance](#8-passe-de-performance)

---

## 1. Data Flow + Split de Componentes

**Princípio**: Props down / Events up. Fluxo unidirecional escala melhor.

- Props são **read-only**. Nunca mutar prop no filho — emita evento, use `v-model`/`defineModel`, ou faça cópia local.
- Prefira `props`/`emit` a `ref` de componente. `ref` só para API imperativa (ex.: `panel.open()`), e nesse caso tipe com `useTemplateRef` (3.5+) e exponha só o necessário com `defineExpose`.
- Eventos de componente **não fazem bubble**. Re-emita explicitamente nos níveis intermediários.
- `defineModel()` para two-way binding (3.4+). O padrão antigo `modelValue` + `update:modelValue` só para Vue < 3.4.
- `provide`/`inject` para dependência cross-tree (> ~3 níveis). Mantenha mutação centralizada no provider, exponha `readonly(state)` + ações explícitas, e use `InjectionKey<T>` tipado (nunca string solta).

```ts
// keys.ts
export const themeKey: InjectionKey<Readonly<Theme>> = Symbol('theme')
export const themeActionsKey: InjectionKey<{ toggle: () => void }> = Symbol('theme-actions')
// Provider: provide(themeKey, readonly(theme)); provide(themeActionsKey, { toggle })
```

### Metodologia de split

Antes de implementar feature não-trivial, faça um **mapa de componentes**: responsabilidade única de cada um em uma frase + contrato `props`/`emits`. Componentes de entrada/raiz e de rota (`pages/`, `views/`) ficam **finos** — só app shell, wiring de providers e composição de features. Não coloque implementação de feature neles.

**Gatilhos objetivos — quebre se QUALQUER um for verdadeiro:**
- Possui orquestração/estado **e** markup apresentacional substancial de múltiplas seções.
- Tem 3+ seções de UI distintas (ex.: form, filtros, lista, footer/status).
- Um bloco de template se repete ou pode virar reutilizável (linhas de item, cards).

Para CRUD/list (todo, tabela, catálogo, inbox), quebre no mínimo em: container da feature + form/input + lista (e/ou item) + footer/ações ou filtro/status. Arquivo único só para demo descartável muito pequena (justifique).

- **Seções de UI** → componentes filhos (props in, events out).
- **Estado/side effects** → composables (`useXxx()`).

---

## 2. Guia de decisão de built-ins

Não adicione por padrão. Use só quando o requisito existir.

| Necessidade | Use |
|---|---|
| Pai controla conteúdo/layout do filho | **Slots** |
| Overlay/portal escapando de overflow/`transform`/stacking context | **Teleport** |
| Animar entrada/saída de **um** elemento/componente | **Transition** |
| Animar mutações de **lista** (insert/remove/reorder) | **TransitionGroup** |
| Preservar estado de view ao alternar (tabs, multi-step) | **KeepAlive** |
| Coordenar dependências assíncronas com fallback | **Suspense** |
| UI pesada/raramente usada → lazy | `defineAsyncComponent` |
| Comportamento DOM-específico (sem fit em composable/componente) | Diretiva customizada |

Ordem canônica de aninhamento quando combinados: `RouterView` → `Transition` → `KeepAlive` → `Suspense`.

---

## 3. Slots

- Sintaxe curta `#nome` (não `v-slot:nome`).
- Renderize wrapper opcional só quando há conteúdo: `<header v-if="$slots.header">`. Evita DOM vazio com borda/spacing.
- Tipe slots escopados com `defineSlots<{...}>()` em `<script setup lang="ts">` — dá autocomplete e checagem estática.
- Forneça fallback: `<slot>Submit</slot>`.
- Para reuso de **lógica pura**, prefira composable a renderless component.

```vue
<script setup lang="ts">
defineProps<{ products: Product[] }>()
defineSlots<{
  default(props: { product: Product; index: number }): any
  empty(): any
}>()
</script>
<template>
  <ul v-if="products.length">
    <li v-for="(product, index) in products" :key="product.id">
      <slot :product="product" :index="index" />
    </li>
  </ul>
  <slot v-else name="empty" />
</template>
```

---

## 4. Teleport

`<Teleport>` move a posição no DOM preservando a hierarquia Vue (props/emits/slots/inject continuam funcionando).

- Use para modais, toasts, tooltips, dropdowns — qualquer UI que precise escapar de `overflow`, `position: fixed` ou stacking context. Ancestral com `transform`/`filter`/`perspective` quebra `position: fixed` dos filhos; Teleport resolve.
- Alvo: `to="body"` ou container dedicado (`#modals`, `#notifications`).
- Múltiplos teleports no mesmo alvo empilham em ordem de declaração — use container compartilhado e `z-index` só quando precisar de camada explícita.
- `:disabled` para responsivo (renderiza inline no mobile, teleporta no desktop).

```vue
<Teleport to="body" :disabled="isMobile">
  <div v-if="open" class="modal">...</div>
</Teleport>
```

---

## 5. Transition

`<Transition>` anima entrada/saída de **um** elemento/componente.

- Apenas **um** filho direto. Múltiplos nós → envolva em um wrapper.
- Entre o mesmo tipo de tag (`<p v-if>`/`<p v-else>`), adicione `key` distinta — senão Vue reusa o elemento e não dispara enter/leave.
- `mode="out-in"` ao trocar componentes/views para evitar sobreposição.
- Anime **`transform`** e **`opacity`** (GPU-friendly). Evite `height`/`margin`/`top` (disparam layout).

```vue
<Transition name="fade" mode="out-in">
  <component :is="currentView" :key="currentView" />
</Transition>
```

---

## 6. KeepAlive

`<KeepAlive>` **cacheia instâncias** em vez de destruí-las. Preserva estado ao alternar, mas exige gestão de tamanho e frescor.

- **Use** em tabs, multi-step forms, dashboards onde estado deve persistir.
- **NÃO use** em páginas de busca/filtro (usuário espera resultado fresco), views memory-heavy (mapas, tabelas grandes, players), ou fluxos sensíveis cujos dados devem ser limpos na saída.
- Limite o cache com `:max` e restrinja com `include`/`exclude` (casam com o `name` do componente — declare via `defineOptions({ name: 'TabA' })`).
- Componentes cacheados **não** disparam `onMounted`/`onUnmounted` ao alternar — use `onActivated` (refresh) e `onDeactivated` (pausar timers).
- Não há API para invalidar instância específica: force refresh com `:key` dinâmica.

```vue
<KeepAlive :max="5" include="Dashboard,Settings">
  <component :is="currentView" :key="`${currentView}-${viewKeys[currentView]}`" />
</KeepAlive>
```

---

## 7. Suspense

> Experimental. Em produção, mantenha boundaries mínimos e documentados.

`<Suspense>` coordena dependências assíncronas (componentes async ou `async setup`) e mostra fallback enquanto resolvem.

- **Um** nó-raiz nos slots default E `#fallback`.
- Re-entra em pending **apenas** quando o nó-raiz do slot default muda. Para re-disparar ao trocar conteúdo profundo, mude o `:key` da raiz (`<component :is="tabs[tab]" :key="tab">`).
- `:timeout="200"` para evitar flicker quando já resolvido e novo async inicia.
- Suspense aninhado: `suspensible` no boundary interno (3.3+) para o pai coordenar.
- `@pending`/`@resolve`/`@fallback` para barra de loading global / analytics.

```vue
<Suspense :timeout="200" @pending="loading = true" @resolve="loading = false">
  <AsyncPage />
  <template #fallback><PageSkeleton /></template>
</Suspense>
```

---

## 8. Passe de performance

Performance é passe **pós-funcionalidade**. Não otimize antes do comportamento correto e verificado. Perfile com Vue DevTools antes de aplicar.

### Virtualizar listas grandes (impacto ALTO)
Listas com > 50–100 itens criam DOM excessivo (memória + render lento). Virtualize: renderiza só os ~20 visíveis.
- Libs: `vue-virtual-scroller` (geral; `DynamicScroller` para altura variável) ou `@tanstack/vue-virtual` (headless, layouts complexos).
- Container precisa de altura fixa. **Não** virtualize listas < 50 itens simples, conteúdo que precisa estar todo no DOM para screen readers/print/SEO.

```vue
<RecycleScroller :items="users" :item-size="80" key-field="id" v-slot="{ item }">
  <UserCard :user="item" />
</RecycleScroller>
```

### `v-once` / `v-memo` (impacto MÉDIO)
- `v-once`: renderiza uma vez, pula todas as atualizações futuras. Para conteúdo estático que usa dado de runtime mas nunca muda (footer, termos).
- `v-memo="[deps]"`: memoiza subtree em lista — só re-renderiza quando uma dep muda. `v-memo="[item.id === selectedId]"` re-renderiza só os 2 itens cuja seleção mudou, não a lista inteira. `v-memo="[]"` ≡ `v-once`.
- **Não** use em conteúdo que precisa atualizar, nem com `v-model` no filho, nem quando o ganho é mínimo.

```vue
<div v-for="item in list" :key="item.id" v-memo="[item.id === selectedId]">
  <ExpensiveItem :item="item" :selected="item.id === selectedId" />
</div>
```

### Evitar over-abstração em listas quentes (impacto MÉDIO)
Instância de componente é mais cara que nó DOM nativo. 100 itens × 5 níveis de wrapper = 500 instâncias. Em hot paths (item de lista), **achate** a hierarquia: use elementos nativos (`<div class="card">`, `<button class="btn">`) e classes/Tailwind em vez de `<Card>`/`<CardHeader>`/`<Text>`. Abstração ainda vale quando: encapsula comportamento complexo, é reusada fora do hot path, a lista é pequena (< 20), ou há virtualização (só ~20 instâncias existem).

### Evitar trabalho caro em `onUpdated` (impacto MÉDIO)
`onUpdated` roda após **cada** re-render. Nunca faça API call (dispara a cada mudança) nem mute estado reativo (loop infinito) ali. Para reagir a dado específico, use `watch`/`watchEffect` (com `{ immediate: true }` em vez de chamada inicial duplicada) ou `computed` para derivados. Reserve `onUpdated` só para sincronização DOM de baixo nível (ex.: scroll após mudança de altura, refresh de widget de terceiros). Debounce (`useDebounceFn` do VueUse) operações caras.
