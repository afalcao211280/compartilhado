# Changelog — criar-task-devops

## [1.1.0] - 2026-06-30

### Changed
- Padronização ao formato governado (`skills-optimizadas`): frontmatter agora com `version`, `category: Outras` e `keywords` (8 keywords reais de trigger).
- `description` mantida pushy e ampliada com org/projeto, menção ao MCP azure-devops e gatilho "quebra a story em tasks".
- SKILL.md reorganizado: seção **Princípios** (com o porquê) no topo; **Anti-padrões**; **Cross-references**. Todo o conteúdo EVEO original preservado (fonte-wiki, fluxo, vínculo ao pai, Description em HTML).

### Added
- **Consolidação** (cruzamento skills/ ⨯ skills-compare/ ⨯ ADR-024 + ADR-027).
- Seção **Quebrar uma story em Tasks** no SKILL.md + `reference/quebra-de-tarefas.md` — condensado de `skills-compare/planning-and-task-breakdown` (grafo de dependência, fatiamento vertical, sizing S/M/L, paralelização) adaptado ao contexto EVEO/ADO.
- Seção **Tasks de teste (ADR-027)** — categorias/tags da pirâmide (`@unit`/`@integration`/`@e2e`/...), estágio de execução, Test Case associado à Story, metas (coverage ≥80%, zero flaky).
- `AGENTS.md` (padrão do corpus) e este `CHANGELOG.md` (a skill original tinha só SKILL.md).

### Decisões de divergência ADR-024 / ADR-027
- **Nenhuma contradição dura.** O ADR-024 (Task sob Story, nomenclatura "{Verbo} {o que}") e o ADR-027 (pirâmide/tags, Test Case na Story) são compatíveis com a skill e foram incorporados como orientação.
- **Sprint/Iteration**: como na story-devops, o time não usa sprints; `IterationPath` fixo. O ADR-024 assume sprint cadence — não aplicável ao ENGSOFT (skill vence).

### Descartes (skills-compare)
- **planning-and-task-breakdown** — "Plan Document Template" completo, "Common Rationalizations", "Red Flags" e comandos genéricos (`npm test`/`npm run build`) descartados: a skill não gera um plano em Markdown, ela cria Tasks no ADO; mantidos só os critérios de decomposição (grafo, fatiamento vertical, sizing), reescritos em pt-BR com camadas da stack EVEO.

## [1.0.0] - 2026-06-11

### Added
- Versão inicial (EVEO): fluxo de criação de Task no Azure DevOps buscando o padrão de refinamento técnico na wiki ENGSOFT; vínculo à US/Feature pai; Description em HTML.
