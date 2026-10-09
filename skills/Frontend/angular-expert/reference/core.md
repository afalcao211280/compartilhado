# Angular Expert — Padrões de Código (Angular 17+ Standalone)

## 1. Bootstrap — Standalone (main.ts)

```typescript
// src/main.ts
import { bootstrapApplication } from '@angular/platform-browser';
import { provideRouter, withComponentInputBinding } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideAnimationsAsync } from '@angular/platform-browser/animations/async';
import { AppComponent } from './app/app.component';
import { routes } from './app/app.routes';
import { authInterceptor } from './app/core/interceptors/auth.interceptor';

bootstrapApplication(AppComponent, {
  providers: [
    provideRouter(routes, withComponentInputBinding()),
    provideHttpClient(withInterceptors([authInterceptor])),
    provideAnimationsAsync(),
  ],
}).catch(console.error);
```

---

## 2. Rotas com Lazy Loading

```typescript
// src/app/app.routes.ts
import type { Routes } from '@angular/router';
import { authGuard } from './core/guards/auth.guard';

export const routes: Routes = [
  { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
  {
    path: 'login',
    loadComponent: () => import('./features/auth/login/login.component').then((m) => m.LoginComponent),
  },
  {
    path: 'dashboard',
    canActivate: [authGuard],
    loadComponent: () => import('./features/dashboard/dashboard.component').then((m) => m.DashboardComponent),
  },
  {
    path: 'users',
    canActivate: [authGuard],
    loadChildren: () => import('./features/users/users.routes').then((m) => m.usersRoutes),
  },
];
```

---

## 3. Functional Auth Guard + Interceptor

```typescript
// src/app/core/guards/auth.guard.ts
import { inject } from '@angular/core';
import { type CanActivateFn, Router } from '@angular/router';
import { AuthStore } from '../stores/auth.store';

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthStore);
  const router = inject(Router);
  if (auth.isAuthenticated()) return true;
  return router.createUrlTree(['/login']);
};
```

```typescript
// src/app/core/interceptors/auth.interceptor.ts
import { inject } from '@angular/core';
import { type HttpInterceptorFn } from '@angular/common/http';
import { catchError, throwError } from 'rxjs';
import { Router } from '@angular/router';
import { AuthStore } from '../stores/auth.store';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthStore);
  const router = inject(Router);
  const token = auth.token();

  const authedReq = token
    ? req.clone({ setHeaders: { Authorization: `Bearer ${token}` } })
    : req;

  return next(authedReq).pipe(
    catchError((err) => {
      if (err.status === 401) {
        auth.clearAuth();
        router.navigate(['/login']);
      }
      return throwError(() => err);
    }),
  );
};
```

---

## 4. Signal-based Store

```typescript
// src/app/core/stores/auth.store.ts
import { Injectable, signal, computed } from '@angular/core';
import type { User } from '@/types/user';

@Injectable({ providedIn: 'root' })
export class AuthStore {
  private _user = signal<User | null>(null);
  private _token = signal<string | null>(localStorage.getItem('token'));

  readonly user = this._user.asReadonly();
  readonly token = this._token.asReadonly();
  readonly isAuthenticated = computed(() => Boolean(this._token()));

  setAuth(user: User, token: string): void {
    this._user.set(user);
    this._token.set(token);
    localStorage.setItem('token', token);
  }

  clearAuth(): void {
    this._user.set(null);
    this._token.set(null);
    localStorage.removeItem('token');
  }
}
```

---

## 5. Service com HttpClient

```typescript
// src/app/features/users/services/user.service.ts
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '@/environments/environment';
import type { User, UserCreate } from '@/types/user';

@Injectable({ providedIn: 'root' })
export class UserService {
  private readonly http = inject(HttpClient);
  private readonly base = `${environment.apiUrl}/v1/users`;

  getAll(): Observable<User[]> {
    return this.http.get<User[]>(this.base);
  }

  getById(id: string): Observable<User> {
    return this.http.get<User>(`${this.base}/${id}`);
  }

  create(payload: UserCreate): Observable<User> {
    return this.http.post<User>(this.base, payload);
  }

  update(id: string, payload: Partial<UserCreate>): Observable<User> {
    return this.http.patch<User>(`${this.base}/${id}`, payload);
  }

  delete(id: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/${id}`);
  }
}
```

---

## 6. Standalone Component com Signals

```typescript
// src/app/features/users/components/user-card/user-card.component.ts
import { Component, input, output, computed } from '@angular/core';
import { NgClass } from '@angular/common';
import type { User } from '@/types/user';

@Component({
  selector: 'app-user-card',
  standalone: true,
  imports: [NgClass],
  template: `
    <div class="flex items-center gap-4 rounded-lg border p-4">
      <div class="h-10 w-10 rounded-full bg-blue-100 flex items-center justify-center font-medium">
        {{ user().name[0] }}
      </div>
      <div class="flex-1">
        <p class="font-medium">{{ user().name }}</p>
        <p class="text-sm text-gray-500">{{ user().email }}</p>
      </div>
      <span [ngClass]="badgeClass()">
        {{ user().active ? 'Ativo' : 'Inativo' }}
      </span>
      <button
        *ngIf="hasEditHandler()"
        class="text-sm text-blue-600 hover:underline"
        (click)="onEdit.emit(user().id)"
      >
        Editar
      </button>
    </div>
  `,
})
export class UserCardComponent {
  readonly user = input.required<User>();
  readonly onEdit = output<string>();

  protected readonly hasEditHandler = computed(() => this.onEdit.observed);
  protected readonly badgeClass = computed(() =>
    this.user().active
      ? 'rounded-full px-2 py-1 text-xs bg-green-100 text-green-800'
      : 'rounded-full px-2 py-1 text-xs bg-gray-100 text-gray-600',
  );
}
```

---

## 7. Reactive Form

```typescript
// src/app/features/users/components/create-user-form/create-user-form.component.ts
import { Component, inject } from '@angular/core';
import { ReactiveFormsModule, FormBuilder, Validators } from '@angular/forms';
import { UserService } from '../../services/user.service';

@Component({
  selector: 'app-create-user-form',
  standalone: true,
  imports: [ReactiveFormsModule],
  template: `
    <form [formGroup]="form" (ngSubmit)="onSubmit()" class="space-y-4">
      <div>
        <label class="text-sm font-medium">Nome</label>
        <input formControlName="name" class="mt-1 w-full rounded border px-3 py-2" />
        @if (form.get('name')?.invalid && form.get('name')?.touched) {
          <p class="mt-1 text-sm text-red-600">Nome deve ter ao menos 2 caracteres</p>
        }
      </div>
      <div>
        <label class="text-sm font-medium">Email</label>
        <input formControlName="email" type="email" class="mt-1 w-full rounded border px-3 py-2" />
        @if (form.get('email')?.invalid && form.get('email')?.touched) {
          <p class="mt-1 text-sm text-red-600">Email inválido</p>
        }
      </div>
      <button type="submit" [disabled]="form.invalid || loading" class="rounded bg-blue-600 px-4 py-2 text-white">
        {{ loading ? 'Criando...' : 'Criar Usuário' }}
      </button>
    </form>
  `,
})
export class CreateUserFormComponent {
  private readonly fb = inject(FormBuilder);
  private readonly userService = inject(UserService);

  protected loading = false;

  protected readonly form = this.fb.group({
    name: ['', [Validators.required, Validators.minLength(2), Validators.maxLength(100)]],
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(8)]],
  });

  protected onSubmit(): void {
    if (this.form.invalid) return;
    this.loading = true;
    this.userService.create(this.form.getRawValue() as any).subscribe({
      next: () => {
        this.form.reset();
        this.loading = false;
      },
      error: () => { this.loading = false; },
    });
  }
}
```

---

## 8. Teste com Jest + Angular Testing Library

```typescript
// src/app/features/users/components/user-card/user-card.component.spec.ts
import { render, screen } from '@testing-library/angular';
import userEvent from '@testing-library/user-event';
import { UserCardComponent } from './user-card.component';

const mockUser = { id: '1', name: 'João Silva', email: 'joao@eveo.com', active: true };

describe('UserCardComponent', () => {
  it('renderiza nome e email', async () => {
    await render(UserCardComponent, { componentInputs: { user: mockUser } });
    expect(screen.getByText('João Silva')).toBeInTheDocument();
    expect(screen.getByText('joao@eveo.com')).toBeInTheDocument();
  });

  it('não exibe botão Editar sem output handler', async () => {
    await render(UserCardComponent, { componentInputs: { user: mockUser } });
    expect(screen.queryByRole('button', { name: /editar/i })).not.toBeInTheDocument();
  });
});
```

---

## Anti-patterns

### ❌ Não cancelar Observables — vazamento de memória
**Problema:** O desenvolvedor chama `.subscribe()` num Observable (ex: `HttpClient`, `Router.events`) sem garantir o cancelamento quando o componente é destruído.
**Por quê evitar:** Subscriptions ativas após a destruição do componente mantêm referências vivas na memória, causam callbacks disparando em componentes desmontados e podem produzir erros `ExpressionChangedAfterItHasBeenCheckedError`.
**Solução:**
```typescript
import { Component, inject, OnInit } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

@Component({ standalone: true, ... })
export class UserListComponent implements OnInit {
  private readonly destroyRef = inject(DestroyRef);
  private readonly userService = inject(UserService);

  ngOnInit(): void {
    // takeUntilDestroyed cancela automaticamente no destroy
    this.userService.getAll()
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe(users => this.users = users);
  }
}
```

---

### ❌ Usar `ChangeDetectionStrategy.Default` em todos os componentes
**Problema:** O desenvolvedor mantém a estratégia de change detection padrão em componentes que recebem dados via Input/Signals, sem adotar `OnPush`.
**Por quê evitar:** A estratégia `Default` dispara a detecção de mudanças em toda a árvore de componentes a cada evento do browser, mesmo que o componente não tenha mudado, degradando seriamente a performance em aplicações grandes.
**Solução:**
```typescript
import { Component, ChangeDetectionStrategy, input } from '@angular/core';

@Component({
  selector: 'app-user-card',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush, // sempre em componentes "dumb"
  template: `<p>{{ user().name }}</p>`,
})
export class UserCardComponent {
  readonly user = input.required<User>(); // signals + OnPush = zero re-renders desnecessários
}
```

---

### ❌ Colocar lógica de negócio diretamente no componente
**Problema:** O desenvolvedor implementa chamadas HTTP, transformações de dados, regras de validação e lógica de fluxo diretamente nos métodos do componente.
**Por quê evitar:** Componentes devem ser responsáveis apenas por apresentação e interação com o usuário. Lógica no componente impede reuso, torna testes unitários mais complexos (precisam de DOM) e viola o princípio de separação de responsabilidades.
**Solução:**
```typescript
// Errado — lógica de negócio no componente
export class UserListComponent {
  users: User[] = [];
  ngOnInit() {
    this.http.get<User[]>('/api/users')
      .pipe(map(users => users.filter(u => u.active)))
      .subscribe(users => this.users = users);
  }
}

// Correto — lógica encapsulada no service
@Injectable({ providedIn: 'root' })
export class UserService {
  getActiveUsers(): Observable<User[]> {
    return this.http.get<User[]>('/api/users').pipe(
      map(users => users.filter(u => u.active)),
    );
  }
}
```

---

### ❌ Usar NgRx para todo estado — ignorar signals locais
**Problema:** O desenvolvedor usa NgRx (ou outro gerenciador de estado global) para controlar estado local de UI como loading flags, toggle de modal e dados de formulário que não precisam ser compartilhados.
**Por quê evitar:** NgRx adiciona boilerplate significativo (actions, reducers, selectors, effects) para problemas que signals do Angular resolvem com uma linha. Estado que não é compartilhado entre rotas ou módulos não pertence ao store global.
**Solução:**
```typescript
// Errado — NgRx para estado local de UI
// actions, reducer, selector, effect... só para controlar um loading

// Correto — signals para estado local
@Component({ standalone: true, ... })
export class UserFormComponent {
  protected readonly loading = signal(false);
  protected readonly error = signal<string | null>(null);

  protected submit(): void {
    this.loading.set(true);
    this.userService.create(this.form.value).subscribe({
      next: () => this.loading.set(false),
      error: (e) => { this.error.set(e.message); this.loading.set(false); },
    });
  }
}
```

---

### ❌ Encadear subscribes (subscribe dentro de subscribe)
**Problema:** O desenvolvedor faz `.subscribe()` dentro de outro `.subscribe()` para encadear operações assíncronas dependentes.
**Por quê evitar:** O aninhamento cria o "callback hell" de Observables, torna o cancelamento impossível, duplica subscriptions e impede tratamento de erro centralizado. É o equivalente RxJS do `then().then()` aninhado.
**Solução:**
```typescript
// Errado — subscribe aninhado
this.authService.login(creds).subscribe(token => {
  this.userService.getProfile(token).subscribe(user => {
    this.store.setUser(user); // impossível cancelar o inner subscribe
  });
});

// Correto — operadores de composição RxJS
this.authService.login(creds).pipe(
  switchMap(token => this.userService.getProfile(token)),
  takeUntilDestroyed(this.destroyRef),
).subscribe(user => this.store.setUser(user));
```

---

### ❌ Manipular o DOM diretamente com `document.querySelector` ou `ElementRef.nativeElement`
**Problema:** O desenvolvedor manipula o DOM diretamente via APIs nativas do browser ou acessando `nativeElement` diretamente para alterar estilos, classes e atributos.
**Por quê evitar:** Manipulação direta do DOM ignora o ciclo de change detection do Angular, quebra a renderização server-side (SSR/Universal), é incompatível com Web Workers e impede testes unitários sem ambiente de browser.
**Solução:**
```typescript
// Errado
ngAfterViewInit() {
  document.querySelector('.card')?.classList.add('active');
  this.el.nativeElement.style.color = 'red';
}

// Correto — use signals/bindings para estado de UI
protected readonly isActive = signal(false);
// No template: [class.active]="isActive()" [style.color]="textColor()"

// Para casos onde Renderer2 é necessário
private readonly renderer = inject(Renderer2);
private readonly el = inject(ElementRef);
this.renderer.addClass(this.el.nativeElement, 'active');
```

---

### ❌ Não usar `trackBy` em `*ngFor` / `@for`
**Problema:** O desenvolvedor usa `*ngFor` ou `@for` sem fornecer uma função `trackBy` (ou `track` no novo syntax) em listas que são atualizadas dinamicamente.
**Por quê evitar:** Sem `trackBy`, o Angular destrói e recria todos os elementos DOM da lista a cada atualização do array, mesmo que apenas um item tenha mudado. Em listas longas isso causa perda de estado de componentes filhos e degradação de performance.
**Solução:**
```html
<!-- Errado -->
<app-user-card *ngFor="let user of users" [user]="user" />

<!-- Correto — novo syntax @for com track (Angular 17+) -->
@for (user of users; track user.id) {
  <app-user-card [user]="user" />
}

<!-- Correto — *ngFor com trackBy -->
<app-user-card *ngFor="let user of users; trackBy: trackById" [user]="user" />
```
```typescript
protected trackById(_index: number, item: User): string {
  return item.id;
}
```

---

### ❌ Injetar serviços via constructor ao invés de `inject()`
**Problema:** O desenvolvedor usa o padrão antigo de injeção via parâmetros do constructor com decorators, ao invés da função `inject()` introduzida no Angular 14+.
**Por quê evitar:** A injeção via constructor exige mais boilerplate, não funciona fora de classes (ex: em funções de guard e interceptor funcionais) e dificulta a composição. A função `inject()` é o padrão moderno do Angular e é obrigatória no contexto de standalone/functional.
**Solução:**
```typescript
// Errado — estilo legado
@Component({ ... })
export class UserListComponent {
  constructor(
    private readonly userService: UserService,
    private readonly router: Router,
  ) {}
}

// Correto — inject() moderno
@Component({ standalone: true, ... })
export class UserListComponent {
  private readonly userService = inject(UserService);
  private readonly router = inject(Router);
}
```

---

### ❌ Usar NgModules em projetos Angular 17+ (overhead desnecessário)
**Problema:** O desenvolvedor continua criando `NgModule` para agrupar componentes em vez de usar o modelo standalone introduzido como padrão no Angular 17.
**Por quê evitar:** NgModules adicionam uma camada de indireção desnecessária, aumentam o boilerplate, dificultam o lazy loading granular e vão contra a direção oficial do framework. Componentes standalone são mais simples, testáveis e alinhados com o roadmap do Angular.
**Solução:**
```typescript
// Errado — NgModule desnecessário
@NgModule({
  declarations: [UserCardComponent],
  imports: [CommonModule],
  exports: [UserCardComponent],
})
export class UsersModule {}

// Correto — componente standalone auto-contido
@Component({
  selector: 'app-user-card',
  standalone: true,
  imports: [NgClass], // importa apenas o necessário
  template: `...`,
})
export class UserCardComponent {}
```

---

### ❌ Não usar componentes standalone — manter serviços como singleton quando escopo de componente é necessário
**Problema:** O desenvolvedor registra todos os serviços com `providedIn: 'root'`, criando singletons globais, mesmo quando o serviço guarda estado que deveria ser isolado por instância de componente ou rota.
**Por quê evitar:** Singletons globais compartilham estado entre instâncias de componentes diferentes (ex: dois `UserFormComponent` abertos ao mesmo tempo), causando conflitos de estado, bugs de dados "vazando" entre contextos e dificultando testes isolados.
**Solução:**
```typescript
// Serviço com estado local — não use providedIn: 'root'
@Injectable() // sem providedIn
export class UserFormStateService {
  readonly isDirty = signal(false);
  readonly formData = signal<Partial<User>>({});
}

// Componente provê o serviço localmente — cada instância tem o seu
@Component({
  standalone: true,
  providers: [UserFormStateService], // escopo de componente
  ...
})
export class UserFormComponent {
  private readonly state = inject(UserFormStateService);
}
```
