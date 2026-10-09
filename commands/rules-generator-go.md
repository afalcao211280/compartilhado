---
description: Gera/atualiza regras de projeto em .claude/rules (.md) para um repositório Go, a partir do estado real do repo e das convenções oficiais de Go, com lógica de regras globais vs. por-tarefa.
argument-hint: "[caminho opcional de arquivo auxiliar .md/.txt/.json/.yaml]"
---

Atue como um "Project Rule Builder" para este repositório Go.

Objetivo: criar/atualizar um conjunto de regras de projeto em **pt-BR** dentro de `.claude/rules/` (arquivos `.md`) + manter um índice no `CLAUDE.md` do projeto, baseadas:
1) no estado REAL do projeto (pastas, dependências, padrões já usados);
2) nas convenções oficiais de Go:
   - Effective Go: https://go.dev/doc/effective_go
   - Standard Project Layout: https://github.com/golang-standards/project-layout
   - Se não conseguir acessar os links, derive as regras a partir do `go.mod`, `.golangci.yml` e do código existente.

## Modelo de aplicação no Claude Code (global vs. por-tarefa)
O Claude Code **não tem auto-attach por glob** como o Cursor. Reproduza a mesma lógica assim:
- **Regras globais (sempre aplicam)**: devem entrar em todo o contexto. Coloque-as em arquivos `.claude/rules/*.md` e **importe-as no `CLAUDE.md`** do projeto com `@.claude/rules/<arquivo>.md` (imports do `CLAUDE.md` são sempre carregados).
- **Regras por-tarefa (sob demanda)**: arquivos `.claude/rules/*.md` que **NÃO** são importados sempre. No `CLAUDE.md`, mantenha um **índice** listando cada arquivo com: descrição + **gatilho** ("Leia quando ..." + globs/padrões de caminho de referência). O Claude lê o arquivo on-demand quando a tarefa casar com o gatilho.
- Cada arquivo de regra começa com um cabeçalho curto:
  ```
  # <Título>
  Aplicação: Global (sempre) | Por-tarefa
  Gatilho: <quando ler>  ·  Globs de referência: `internal/**`, `**/*.go`
  ```
  Seguido de: Objetivo, Regras, Anti-padrões, Checklist.

## DEVE / NÃO DEVE
- Caso tenha alguma dúvida ou algo que não esteja claro, **VOCÊ DEVE** perguntar ao usuário para esclarecer antes de continuar.
- Caso tenha alguma dúvida ou algo que não esteja claro, **VOCÊ NÃO DEVE** continuar sem esclarecer.

## Entrada opcional (arquivo auxiliar)
Arquivo auxiliar fornecido em `$ARGUMENTS` (se vazio, ignore esta seção).
- Formatos aceitos: `.md`, `.mdc`, `.txt`, `.json`, `.yaml`.
- Leia integralmente e extraia diretrizes úteis (decisões arquiteturais, exceções locais, convenções do time, restrições de segurança).
- Em caso de conflito entre o arquivo auxiliar e o estado real do repositório, **priorize o repositório** e registre a divergência nos TODOs do resumo final.
- Não copie o conteúdo na íntegra; incorpore como regras objetivas alinhadas ao código e às lints.
- No resumo final indique `Fonte auxiliar: <caminho/arquivo>`.

## O que analisar no repo
- `go.mod` e `go.sum` (dependências → frameworks web, ORMs, libs de DI, observabilidade).
- `.golangci.yml`/`golangci.yaml` (linters configurados).
- Estrutura conforme golang-standards: `/cmd`, `/internal`, `/pkg`, `/api`, `/configs`, `/scripts`, `/build`, `/deployments`, `/test`, `/docs`, `/tools`, `/vendor`.
- Presença de `Makefile`, `Taskfile.yml`, `magefile.go`.
- Monorepo? (múltiplos `go.mod` → ajustar globs de referência para `services/*/` e `packages/*/`).
- `CLAUDE.md` já existente (preservar conteúdo do usuário; só adicionar/atualizar a seção de regras gerada).

## Saída esperada (criar/atualizar conforme aplicável)
Arquivos em `.claude/rules/` + entradas no índice do `CLAUDE.md`. Marque cada um como **Global** ou **Por-tarefa**:

1) `.claude/rules/go-coding-standards.md` (**Global**) - gofmt/goimports, naming (MixedCaps, nunca snake_case), interfaces pequenas, error handling, `context.Context`, defer, goroutines/channels, godoc. Alinhar ao Effective Go e ao `.golangci.yml`.
2) `.claude/rules/go-project-structure.md` (**Por-tarefa**; globs ref.: `cmd/**`, `internal/**`, `pkg/**`) - golang-standards/layout, nomes de arquivos/pacotes, regras de import.
3) `.claude/rules/go-clean-architecture.md` (**Por-tarefa**; `internal/**`) - camadas handler→service→repository→domain, DIP, interfaces no consumidor, DTO vs domain, DI.
4) `.claude/rules/go-error-handling.md` (**Por-tarefa**; `**/*.go`) - nunca ignorar erro, `errors.Is/As`, wrap `%w`, sentinelas vs custom types, panic/recover só em boundary.
5) `.claude/rules/go-concurrency.md` (**Por-tarefa**; `**/*.go`) - `context.Context` sempre, `errgroup`, channels, mutexes, evitar leaks, graceful shutdown.
6) `.claude/rules/go-testing-standards.md` (**Por-tarefa**; `**/*_test.go`, `test/**`) - unit/table-driven/integration/benchmark/fuzz, testify/mockery se presente, `testdata/`, `-cover`/`-race`.
7) `.claude/rules/go-dependency-injection.md` (**Por-tarefa**; `cmd/**`, `internal/**`) - detectar lib (wire/fx/dig/manual) via deps; constructors `New*`, interfaces para testabilidade, composição no cmd.
8) `.claude/rules/commits-and-language.md` (**Global**) - Conventional Commits em pt-BR (feat/fix/chore/docs/refactor/test...), corpo o quê/por quê, referência a issues/PRs, padrão de PR.

### Opcionais (somente se o repo indicar)
- `go-api-design.md` (se houver `/api` OpenAPI/proto/GraphQL ou framework web).
- `go-database.md` (se GORM/sqlx/pgx/ent/sqlc).
- `go-observability.md` (se OpenTelemetry/Prometheus/Zap/Zerolog).
- `go-security.md` (**Global**: secrets/.env, no-logs sensíveis, validação de input, SQL injection).
- `go-docker-k8s.md` (se Dockerfile/compose/k8s).

## Requisitos de formatação
- Idioma pt-BR, direto e assertivo. Bullets curtos.
- Cabeçalho por arquivo: `Aplicação` (Global/Por-tarefa) + `Gatilho`/globs de referência (ver "Modelo de aplicação").
- Seções: Objetivo, Regras, Anti-padrões, Checklist (e "Exemplos curtos" quando útil).
- Não copiar o Effective Go inteiro; alinhe e referencie.

## CLAUDE.md (índice + imports)
- Se não existir `CLAUDE.md`, crie-o; se existir, **preserve** o conteúdo e edite só uma seção demarcada (ex.: `<!-- rules:go:start --> ... <!-- rules:go:end -->`).
- Nessa seção:
  - **Imports globais**: uma linha `@.claude/rules/<arquivo>.md` para cada regra **Global** (carregadas sempre).
  - **Índice por-tarefa**: tabela/bullets com `arquivo · descrição · Gatilho/globs` para o Claude ler on-demand.

## Passos finais
- "Resumo do que foi detectado" (framework web, ORM, DI lib, observabilidade, estrutura de pastas).
- Listar quais regras ficaram **Global** vs **Por-tarefa** e os globs de referência validados contra a árvore real.
- Propor defaults sensatos para o que estiver ambíguo e registrar TODOs.
- Se houve arquivo auxiliar, incluir `Fonte auxiliar: <caminho>` e destacar decisões derivadas dele.
