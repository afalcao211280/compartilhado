# Angular — Práticas Modernas (Angular 19+)

Origem: `angular-developer` (compare), condensado — 36 tópicos. Standalone + Signals por padrão.

## Reatividade
- Signals por padrão (`signal`/`computed`/`effect`); `linkedSignal`; `resource()` p/ async.
- RxJS só onde streams fazem sentido (eventos, websockets).

## Componentes
- Standalone components (sem NgModules); `OnPush`/signals. Host elements; styling encapsulado.
- Component harnesses p/ testes de UI.

## Formulários
- Signal forms ou Reactive forms (tipados). Template-driven só p/ casos simples.

## DI
- Fundamentos + hierarchical injectors; injection context; providers explícitos.

## Roteamento
- Rotas standalone; guards; resolvers; lazy loading; router lifecycle; outlets nomeados; route animations.

## Renderização
- Estratégias de rendering/loading; SSR + hydration onde aplicável.

## Entradas/Saídas
- `input()`/`output()` signal-based (não `@Input`/`@Output` legado).

## Testes
- Testing fundamentals; router testing; e2e.

## Ferramentas
- Angular CLI; migrations (`ng update`); Tailwind CSS; MCP.
