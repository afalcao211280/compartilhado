# Angular — Formulários (Angular 19+)

Duas abordagens estáveis: **Reactive Forms** (tipados — canônico EVEO para produção) e
**Template-Driven** (só casos triviais). **Signal Forms** existe como preview experimental — cobre-se
aqui para reconhecimento, mas **não é para produção** até estabilizar. Leia antes de gerar qualquer
formulário.

## Índice

1. [Reactive Forms tipados (canônico)](#1-reactive-forms-tipados-canônico)
2. [Binding no template](#2-binding-no-template)
3. [Validação e mensagens de erro](#3-validação-e-mensagens-de-erro)
4. [FormArray dinâmico](#4-formarray-dinâmico)
5. [Estado e eventos de mudança](#5-estado-e-eventos-de-mudança)
6. [Template-Driven Forms (casos simples)](#6-template-driven-forms-casos-simples)
7. [Signal Forms (experimental — preview)](#7-signal-forms-experimental--preview)
8. [Anti-padrões de formulários](#8-anti-padrões-de-formulários)

---

## 1. Reactive Forms tipados (canônico)

Classes de `@angular/forms`: `FormControl` (um input), `FormGroup` (objeto de controls),
`FormArray` (lista indexada), `FormBuilder`/`NonNullableFormBuilder` (factory).

Prefira **`NonNullableFormBuilder`** (`inject(NonNullableFormBuilder)` ou
`fb.nonNullable`): `reset()` volta ao valor inicial em vez de `null`, e os tipos ficam sem `| null`.

```ts
import { Component, inject } from '@angular/core';
import { NonNullableFormBuilder, Validators, ReactiveFormsModule } from '@angular/forms';

@Component({
  selector: 'app-profile-form',
  imports: [ReactiveFormsModule],
  templateUrl: './profile-form.html',
})
export class ProfileForm {
  private readonly fb = inject(NonNullableFormBuilder);

  readonly form = this.fb.group({
    firstName: this.fb.control('', [Validators.required, Validators.minLength(2)]),
    email: this.fb.control('', [Validators.required, Validators.email]),
    address: this.fb.group({
      street: this.fb.control(''),
      city: this.fb.control(''),
    }),
    aliases: this.fb.array<string>([]),
  });

  onSubmit() {
    if (this.form.invalid) { this.form.markAllAsTouched(); return; }
    const value = this.form.getRawValue(); // tipado, sem null
    // ... enviar value
  }
}
```

- `getRawValue()` inclui controls desabilitados; `form.value` os omite (tipo `Partial`).
- Tipagem é inferida do `group()` — não anote manualmente. Zod pode validar no boundary da API
  (ver `typescript-expert`), separado da validação de UI.

## 2. Binding no template

```html
<form [formGroup]="form" (ngSubmit)="onSubmit()">
  <input type="text" formControlName="firstName" />

  <div formGroupName="address">
    <input type="text" formControlName="street" />
  </div>

  <div formArrayName="aliases">
    @for (alias of form.controls.aliases.controls; track $index) {
      <input type="text" [formControlName]="$index" />
    }
  </div>

  <button type="submit" [disabled]="form.invalid">Enviar</button>
</form>
```

Diretivas (de `ReactiveFormsModule`): `[formGroup]`, `formControlName`, `formGroupName`,
`formArrayName`, `[formControl]` (control standalone).

## 3. Validação e mensagens de erro

- Síncronos: `Validators.required`, `min/max`, `minLength`, `email`, `pattern`, ou validador custom
  `(c: AbstractControl): ValidationErrors | null`.
- Assíncronos: 3º argumento do control (`AsyncValidatorFn`, ex.: unicidade de e-mail via API).
- Exibir erro só após interação: `@if (ctrl.touched && ctrl.hasError('required'))`.

```ts
export function forbiddenName(re: RegExp): ValidatorFn {
  return (c) => re.test(c.value) ? { forbidden: { value: c.value } } : null;
}
```

```html
@let email = form.controls.email;
@if (email.touched && email.invalid) {
  @if (email.hasError('required')) { <p class="err">Obrigatório.</p> }
  @if (email.hasError('email')) { <p class="err">E-mail inválido.</p> }
}
```

## 4. FormArray dinâmico

```ts
get aliases() { return this.form.controls.aliases; }
addAlias() { this.aliases.push(this.fb.control('')); }
removeAlias(i: number) { this.aliases.removeAt(i); }
```

`track $index` no `@for` (ver §2). Reindexação é automática via `[formControlName]="$index"`.

## 5. Estado e eventos de mudança

- Flags: `valid`/`invalid`, `pristine`/`dirty`, `touched`/`untouched`, `pending` (async em curso).
- Programático: `setValue` (objeto completo), `patchValue` (parcial), `reset`, `disable`/`enable`.
- Stream unificado (v18+): `control.events` emite `ValueChangeEvent`, `StatusChangeEvent`,
  `TouchedChangeEvent`, `PristineChangeEvent` num único Observable. Alternativa a assinar
  `valueChanges`/`statusChanges` separadamente.
- Consumir como signal: `readonly value = toSignal(this.form.valueChanges, { initialValue: this.form.getRawValue() })`.

## 6. Template-Driven Forms (casos simples)

Apenas para formulários triviais (1–3 campos, sem lógica). `FormsModule` + `[(ngModel)]`.

```html
<form #f="ngForm" (ngSubmit)="onSubmit(f)">
  <input required [(ngModel)]="user.name" name="name" #nameCtrl="ngModel" />
  @if (nameCtrl.invalid && nameCtrl.touched) { <p>Nome obrigatório.</p> }
  <button type="submit" [disabled]="f.invalid">Enviar</button>
</form>
```

**Todo** elemento com `[(ngModel)]` **precisa** de `name` — é como o control é registrado no `NgForm`.
Para tipagem forte, validação complexa ou testabilidade, use Reactive Forms.

## 7. Signal Forms (experimental — preview)

> **Experimental.** API `@angular/forms/signals` sujeita a mudança; não usar em produção EVEO até
> estabilizar. Reconheça e saiba migrar; a escolha canônica continua Reactive Forms tipados.

Modela o form em cima de um signal de modelo. Não há `FormBuilder`; não importe
`FormControl`/`FormGroup` de `@angular/forms` junto.

```ts
import { form, submit, required, minLength } from '@angular/forms/signals';

readonly model = signal({ username: '', email: '' });

readonly userForm = form(this.model, (s) => {
  required(s.username);
  minLength(s.username, 3);
  required(s.email);
});

onSubmit() {
  submit(this.userForm, async () => {          // callback DEVE ser async e retornar Promise
    await this.api.save(this.model());
  });
}
```

Pegadinhas críticas (erros mais comuns):

| Cenário | Errado | Certo |
|---|---|---|
| Acessar flags | `form.field.valid()` | `form.field().valid()` |
| Acessar valor | `form.field.value()` | `form.field().value()` |
| Gravar valor | `form.field.set(x)` | atualizar o modelo: `model.update(...)` |
| Flags da raiz | `form.invalid()` | `form().invalid()` |
| Callback submit | `submit(form, () => …)` | `submit(form, async () => …)` |
| Comprimento de array | `form.items().length` | `form.items.length` (estrutural) |
| `when` em validador | `pattern(p.x, /…/, { when })` | `when` só funciona com `required()` |
| Params async | `params: s.field` | `params: ({ value }) => value()` |

## 8. Anti-padrões de formulários

| Proibido | Alternativa |
|---|---|
| `FormBuilder` nullable para form de produção | `NonNullableFormBuilder` |
| Template-driven para form complexo/tipado | Reactive Forms |
| Ler `form.value` esperando tipo completo | `getRawValue()` (tipado, inclui disabled) |
| Mostrar erro antes de tocar o campo | gate por `touched`/`dirty` |
| `[(ngModel)]` sem `name` | sempre incluir `name` |
| Assinar `valueChanges`/`statusChanges` sem cleanup | `toSignal(...)` ou `takeUntilDestroyed()` |
| Signal Forms em produção agora | Reactive Forms (Signal Forms é experimental) |
