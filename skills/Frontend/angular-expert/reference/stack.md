# Angular Expert — Stack Canônica

## Angular 17+ / TypeScript 5.x / Node.js 20+ — Versão Canônica EVEO

| Categoria | Lib | Versão | Link | Notas |
|-----------|-----|--------|------|-------|
| **Core** | | | | |
| Framework | Angular | 17.x+ | https://angular.dev | Standalone Components padrão. NgModules: legado |
| Linguagem | TypeScript | 5.x | https://typescriptlang.org | `strict: true` obrigatório |
| Build | Angular CLI | 17.x+ | https://angular.dev/tools/cli | `@angular/build` (esbuild) padrão no v17+ |
| SSR | Angular SSR | 17.x+ | https://angular.dev/guide/ssr | Substitui Angular Universal |
| **Estado** | | | | |
| Estado reativo | RxJS | 7.x | https://rxjs.dev | Observables. Async pipe obrigatório em templates |
| Estado global | NgRx | 17.x | https://ngrx.io | Para apps com estado complexo |
| Estado simples | Angular Signals | built-in 17+ | — | `signal()`, `computed()`, `effect()` — preferir |
| HTTP | HttpClient | built-in | — | `provideHttpClient(withInterceptors([]))` |
| Forms | Reactive Forms | built-in | — | `FormGroup`, `FormControl`. Template-driven: evitar |
| Validação | Zod / class-validator | 3.x / 0.14+ | — | Zod para schema TS, class-validator para DTOs |
| **Roteamento** | | | | |
| Router | Angular Router | built-in | — | Lazy loading por rota obrigatório |
| Guards | `CanActivateFn` | built-in 15+ | — | Functional guards, sem classes |
| **Estilo** | | | | |
| CSS Utilities | Tailwind CSS | 3.x | https://tailwindcss.com | Padrão EVEO |
| Componentes | Angular Material | 17.x | https://material.angular.io | MDC-based desde v15 |
| CDK | Angular CDK | 17.x | https://material.angular.io/cdk | Overlay, DragDrop, a11y |
| **HTTP / Data** | | | | |
| Interceptors | `HttpInterceptorFn` | built-in 15+ | — | Functional interceptors, sem classes |
| Retry | RxJS `retry` operator | built-in | — | `retry({ count: 3, delay: 1000 })` |
| Cache | `HttpContext` + cache service | custom | — | Por meio de interceptor |
| **Testes** | | | | |
| Unit | Jest | 29.x | https://jestjs.io | `jest-preset-angular` — mais rápido que Karma |
| Component | Angular Testing Library | latest | https://testing-library.com/angular | Queries acessíveis |
| E2E | Playwright | 1.45+ | https://playwright.dev | Substitui Protractor/Cypress |
| **Qualidade** | | | | |
| Linting | ESLint | 9.x + `angular-eslint` | https://github.com/angular-eslint/angular-eslint | |
| Formatação | Prettier | 3.x | https://prettier.io | |
| Type check | `tsc --noEmit` | built-in | — | |

## angular.json — Opções Essenciais

```json
{
  "projects": {
    "app": {
      "architect": {
        "build": {
          "builder": "@angular-devkit/build-angular:application",
          "options": {
            "outputPath": "dist/app",
            "index": "src/index.html",
            "browser": "src/main.ts",
            "tsConfig": "tsconfig.app.json",
            "inlineStyleLanguage": "css",
            "assets": ["src/favicon.ico", "src/assets"],
            "styles": ["src/styles.css"],
            "budgets": [
              { "type": "initial", "maximumWarning": "500kB", "maximumError": "1MB" },
              { "type": "anyComponentStyle", "maximumWarning": "2kB", "maximumError": "4kB" }
            ]
          }
        }
      }
    }
  }
}
```

## tsconfig.json — Template Canônico Angular

```json
{
  "compileOnSave": false,
  "compilerOptions": {
    "outDir": "./dist/out-tsc",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noPropertyAccessFromIndexSignature": true,
    "forceConsistentCasingInFileNames": true,
    "esModuleInterop": true,
    "sourceMap": true,
    "declaration": false,
    "experimentalDecorators": true,
    "moduleResolution": "bundler",
    "importHelpers": true,
    "target": "ES2022",
    "module": "ES2022",
    "useDefineForClassFields": false,
    "lib": ["ES2022", "dom"],
    "paths": {
      "@/*": ["src/*"]
    }
  }
}
```
