# Vue Expert — Padrões de Código (Vue 3 Composition API)

## Índice

1. [Componente com `<script setup>` + TypeScript](#1-componente-com-script-setup--typescript)
2. [Pinia Store](#2-pinia-store)
3. [Composable com TanStack Query (Vue Query)](#3-composable-com-tanstack-query-vue-query)
4. [Form com VeeValidate + Zod](#4-form-com-veevalidate--zod)
5. [Axios Instance com Interceptors](#5-axios-instance-com-interceptors)
6. [Vue Router com Guards](#6-vue-router-com-guards)
7. [Teste com Vitest + Vue Test Utils](#7-teste-com-vitest--vue-test-utils)
8. [Anti-patterns](#anti-patterns)

---

## 1. Componente com `<script setup>` + TypeScript

```vue
<!-- src/components/features/user/UserCard.vue -->
<script setup lang="ts">
import { computed } from 'vue';
import type { User } from '@/types/user';

interface Props {
  user: User;
  onEdit?: (id: string) => void;
}

const props = defineProps<Props>();

const badgeVariant = computed(() =>
  props.user.active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-600',
);
</script>

<template>
  <div class="flex items-center gap-4 rounded-lg border p-4">
    <div class="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center font-medium">
      {{ user.name[0] }}
    </div>
    <div class="flex-1">
      <p class="font-medium">{{ user.name }}</p>
      <p class="text-sm text-muted-foreground">{{ user.email }}</p>
    </div>
    <span :class="['rounded-full px-2 py-1 text-xs font-medium', badgeVariant]">
      {{ user.active ? 'Ativo' : 'Inativo' }}
    </span>
    <button
      v-if="onEdit"
      class="text-sm text-primary hover:underline"
      @click="onEdit(user.id)"
    >
      Editar
    </button>
  </div>
</template>
```

---

## 2. Pinia Store

```typescript
// src/stores/authStore.ts
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import type { User } from '@/types/user';

export const useAuthStore = defineStore(
  'auth',
  () => {
    const user = ref<User | null>(null);
    const token = ref<string | null>(null);

    const isAuthenticated = computed(() => Boolean(token.value));

    function setAuth(newUser: User, newToken: string) {
      user.value = newUser;
      token.value = newToken;
    }

    function clearAuth() {
      user.value = null;
      token.value = null;
    }

    return { user, token, isAuthenticated, setAuth, clearAuth };
  },
  { persist: true }, // pinia-plugin-persistedstate
);
```

---

## 3. Composable com TanStack Query (Vue Query)

```typescript
// src/composables/useUsers.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/vue-query';
import { userApi } from '@/api/users';
import type { UserCreate } from '@/types/user';

export const USER_KEYS = {
  all: ['users'] as const,
  list: () => [...USER_KEYS.all, 'list'] as const,
  detail: (id: string) => [...USER_KEYS.all, id] as const,
};

export function useUsers() {
  return useQuery({
    queryKey: USER_KEYS.list(),
    queryFn: userApi.list,
    staleTime: 5 * 60 * 1000,
  });
}

export function useUser(id: string) {
  return useQuery({
    queryKey: USER_KEYS.detail(id),
    queryFn: () => userApi.getById(id),
    enabled: Boolean(id),
  });
}

export function useCreateUser() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: UserCreate) => userApi.create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: USER_KEYS.list() });
    },
  });
}
```

---

## 4. Form com VeeValidate + Zod

```vue
<!-- src/components/features/user/CreateUserForm.vue -->
<script setup lang="ts">
import { useForm } from 'vee-validate';
import { toTypedSchema } from '@vee-validate/zod';
import { z } from 'zod';
import { useCreateUser } from '@/composables/useUsers';

const schema = toTypedSchema(
  z.object({
    name: z.string().min(2, 'Nome deve ter ao menos 2 caracteres').max(100),
    email: z.string().email('Email inválido'),
    password: z.string().min(8, 'Senha deve ter ao menos 8 caracteres'),
  }),
);

const { defineField, handleSubmit, resetForm, errors } = useForm({ validationSchema: schema });
const [name, nameProps] = defineField('name');
const [email, emailProps] = defineField('email');
const [password, passwordProps] = defineField('password');

const createUser = useCreateUser();

const onSubmit = handleSubmit(async (values) => {
  await createUser.mutateAsync(values);
  resetForm();
});
</script>

<template>
  <form class="space-y-4" @submit="onSubmit">
    <div>
      <label class="text-sm font-medium">Nome</label>
      <input v-model="name" v-bind="nameProps" class="mt-1 w-full rounded border px-3 py-2" />
      <p v-if="errors.name" class="mt-1 text-sm text-red-600">{{ errors.name }}</p>
    </div>
    <div>
      <label class="text-sm font-medium">Email</label>
      <input v-model="email" v-bind="emailProps" type="email" class="mt-1 w-full rounded border px-3 py-2" />
      <p v-if="errors.email" class="mt-1 text-sm text-red-600">{{ errors.email }}</p>
    </div>
    <button
      type="submit"
      :disabled="createUser.isPending.value"
      class="rounded bg-primary px-4 py-2 text-white disabled:opacity-50"
    >
      {{ createUser.isPending.value ? 'Criando...' : 'Criar Usuário' }}
    </button>
  </form>
</template>
```

---

## 5. Axios Instance com Interceptors

```typescript
// src/api/client.ts
import axios from 'axios';
import { useAuthStore } from '@/stores/authStore';

export const apiClient = axios.create({
  baseURL: import.meta.env['VITE_API_URL'],
  timeout: 10_000,
  headers: { 'Content-Type': 'application/json' },
});

apiClient.interceptors.request.use((config) => {
  const auth = useAuthStore();
  if (auth.token) {
    config.headers.Authorization = `Bearer ${auth.token}`;
  }
  return config;
});

apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (axios.isAxiosError(error) && error.response?.status === 401) {
      useAuthStore().clearAuth();
      window.location.href = '/login';
    }
    return Promise.reject(error);
  },
);
```

---

## 6. Vue Router com Guards

```typescript
// src/router/index.ts
import { createRouter, createWebHistory } from 'vue-router';
import { useAuthStore } from '@/stores/authStore';

export const router = createRouter({
  history: createWebHistory(import.meta.env['BASE_URL']),
  routes: [
    { path: '/', component: () => import('@/views/HomeView.vue') },
    { path: '/login', component: () => import('@/views/LoginView.vue') },
    {
      path: '/dashboard',
      component: () => import('@/views/DashboardView.vue'),
      meta: { requiresAuth: true },
    },
  ],
});

router.beforeEach((to) => {
  const auth = useAuthStore();
  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return '/login';
  }
});
```

---

## 7. Teste com Vitest + Vue Test Utils

```typescript
// src/components/features/user/UserCard.test.ts
import { render, screen } from '@testing-library/vue';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import UserCard from './UserCard.vue';

const mockUser = {
  id: '1',
  name: 'João Silva',
  email: 'joao@eveo.com',
  active: true,
};

describe('UserCard', () => {
  it('renderiza nome e email', () => {
    render(UserCard, { props: { user: mockUser } });
    expect(screen.getByText('João Silva')).toBeInTheDocument();
    expect(screen.getByText('joao@eveo.com')).toBeInTheDocument();
  });

  it('chama onEdit ao clicar em Editar', async () => {
    const onEdit = vi.fn();
    render(UserCard, { props: { user: mockUser, onEdit } });
    await userEvent.click(screen.getByRole('button', { name: /editar/i }));
    expect(onEdit).toHaveBeenCalledWith('1');
  });
});
```

---

## Anti-patterns

### ❌ Mutar estado do Pinia diretamente fora de actions
**Problema:** O desenvolvedor acessa o store e altera propriedades diretamente no componente, sem passar por uma action.
**Por quê evitar:** Quebra o fluxo unidirecional de dados, torna as mutações rastreáveis impossíveis no devtools e impede o uso de `$patch` ou plugins de persistência corretamente.
**Solução:**
```typescript
// Errado
const store = useAuthStore();
store.user = newUser; // mutação direta

// Correto
const store = useAuthStore();
store.setAuth(newUser, token); // via action definida no store
```

---

### ❌ Usar `reactive()` para valores primitivos
**Problema:** O desenvolvedor usa `reactive()` para envolver strings, números ou booleanos ao invés de `ref()`.
**Por quê evitar:** `reactive()` só funciona com objetos — aplicado a primitivos retorna o valor sem proxy, perdendo a reatividade completamente e gerando bugs silenciosos.
**Solução:**
```typescript
// Errado
const count = reactive(0);       // sem reatividade
const name = reactive('João');   // sem reatividade

// Correto
const count = ref(0);
const name = ref('João');
```

---

### ❌ `v-for` sem `:key` ou usando index como chave em listas dinâmicas
**Problema:** O desenvolvedor omite a diretiva `:key` ou usa o índice do array como chave em listas cujos itens podem ser reordenados, removidos ou inseridos.
**Por quê evitar:** O Vue não consegue rastrear corretamente os nós do DOM, causando re-renderizações incorretas, perda de estado local de componentes filhos e bugs visuais difíceis de reproduzir.
**Solução:**
```html
<!-- Errado -->
<li v-for="user in users">{{ user.name }}</li>
<li v-for="(user, index) in users" :key="index">{{ user.name }}</li>

<!-- Correto: chave estável e única por item -->
<li v-for="user in users" :key="user.id">{{ user.name }}</li>
```

---

### ❌ Chamar composables condicionalmente ou dentro de loops
**Problema:** O desenvolvedor invoca um composable dentro de um `if`, `for` ou dentro de uma função assíncrona executada após a montagem.
**Por quê evitar:** As chamadas de composables dependem da ordem de execução e do contexto do `setup()`. Chamadas condicionais quebram o sistema de rastreamento de efeitos do Vue, causando erros de runtime e comportamentos imprevisíveis.
**Solução:**
```typescript
// Errado
if (isAdmin.value) {
  const { data } = useAdminData(); // NÃO faça isso
}

// Correto: chame sempre no nível raiz do setup
const { data: adminData } = useAdminData();
// use computed/watch para reagir condicionalmente ao resultado
const visibleData = computed(() => isAdmin.value ? adminData.value : null);
```

---

### ❌ Não usar `computed()` para estado derivado — recalcular no template
**Problema:** O desenvolvedor coloca expressões complexas diretamente no template ao invés de usar `computed()`.
**Por quê evitar:** Expressões no template são recalculadas a cada re-renderização sem cache. `computed()` memoriza o resultado e só recalcula quando as dependências mudam, melhorando a performance.
**Solução:**
```typescript
// Errado — recalcula toda re-renderização
// No template: {{ users.filter(u => u.active).length }}

// Correto
const activeUsersCount = computed(() => users.value.filter(u => u.active).length);
// No template: {{ activeUsersCount }}
```

---

### ❌ Usar `watch` com `deep: true` desnecessariamente (ou esquecer quando necessário)
**Problema:** O desenvolvedor aplica `deep: true` em todo watcher por precaução, ou deixa de usá-lo quando observa um objeto reativo cujas propriedades aninhadas precisam ser monitoradas.
**Por quê evitar:** `deep: true` desnecessário percorre recursivamente todo o objeto a cada mudança, degradando a performance. Omiti-lo quando necessário faz o watcher não disparar para mutações em propriedades aninhadas.
**Solução:**
```typescript
// Desnecessário — ref primitiva não precisa de deep
watch(count, (val) => { /* ... */ }, { deep: true }); // overhead sem ganho

// Necessário — objeto reativo com propriedades aninhadas
watch(formData, (val) => { /* ... */ }, { deep: true });

// Melhor — observe a propriedade específica com getter
watch(() => formData.value.address.city, (city) => { /* ... */ });
```

---

### ❌ Memory leak: não limpar event listeners ou timers em `onUnmounted`
**Problema:** O desenvolvedor adiciona event listeners globais (`window`, `document`) ou timers (`setInterval`, `setTimeout`) no `onMounted` sem removê-los no `onUnmounted`.
**Por quê evitar:** Quando o componente é desmontado, os listeners e timers continuam ativos, causando vazamentos de memória, callbacks disparando em contexto errado e potenciais erros de referência nula.
**Solução:**
```typescript
import { onMounted, onUnmounted } from 'vue';

const handleResize = () => { /* ... */ };
let timerId: ReturnType<typeof setInterval>;

onMounted(() => {
  window.addEventListener('resize', handleResize);
  timerId = setInterval(() => { /* ... */ }, 1000);
});

onUnmounted(() => {
  window.removeEventListener('resize', handleResize);
  clearInterval(timerId);
});
```

---

### ❌ Misturar Options API com `<script setup>` no mesmo componente
**Problema:** O desenvolvedor usa `data()`, `methods`, `computed` ou hooks do Options API dentro de um componente que já usa `<script setup>`.
**Por quê evitar:** `<script setup>` e Options API são paradigmas mutuamente exclusivos no mesmo bloco `<script>`. Misturá-los causa erros de compilação ou comportamentos indefinidos, além de tornar o código inconsistente e ilegível.
**Solução:**
```vue
<!-- Errado: mistura de paradigmas -->
<script>
export default { data() { return { count: 0 }; } }
</script>
<script setup>
const name = ref('Vue');
</script>

<!-- Correto: apenas <script setup> -->
<script setup lang="ts">
import { ref } from 'vue';
const count = ref(0);
const name = ref('Vue');
</script>
```

---

### ❌ `defineProps` e `defineEmits` sem tipos TypeScript
**Problema:** O desenvolvedor usa `defineProps` e `defineEmits` sem anotações de tipo, usando apenas arrays de strings.
**Por quê evitar:** Sem tipos, não há verificação em tempo de compilação dos valores recebidos/emitidos, os erros aparecem apenas em runtime e o autocomplete da IDE não funciona. A Composition API do Vue 3 com TypeScript foi projetada para aproveitar tipagem estática completa.
**Solução:**
```typescript
// Errado
const props = defineProps(['user', 'onEdit']);
const emit = defineEmits(['update', 'delete']);

// Correto — com tipos explícitos
interface Props {
  user: User;
  readonly?: boolean;
}
const props = defineProps<Props>();
const emit = defineEmits<{
  update: [user: User];
  delete: [id: string];
}>();
```

---

### ❌ Acessar estado do store diretamente sem getters/computed
**Problema:** O desenvolvedor desestrutura propriedades do store diretamente, perdendo a reatividade, ao invés de usar `storeToRefs()` ou getters.
**Por quê evitar:** Desestruturar um store Pinia sem `storeToRefs()` cria cópias reativas quebradas — os valores não atualizam quando o store muda, causando bugs silenciosos de UI desatualizada.
**Solução:**
```typescript
// Errado — perde reatividade
const { user, token } = useAuthStore();

// Correto — mantém reatividade com storeToRefs
import { storeToRefs } from 'pinia';
const authStore = useAuthStore();
const { user, token } = storeToRefs(authStore);
// actions não precisam de storeToRefs
const { setAuth, clearAuth } = authStore;
```
