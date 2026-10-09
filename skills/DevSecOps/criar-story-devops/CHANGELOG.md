# Changelog — criar-story-devops

## [1.1.0] - 2026-06-30

### Changed
- Padronização ao formato governado (`skills-optimizadas`): frontmatter agora com `version`, `category: Outras` e `keywords` (8 keywords reais de trigger).
- `description` mantida pushy e ampliada com org/projeto e menção ao MCP azure-devops.
- SKILL.md reorganizado: seção **Princípios** (com o porquê) no topo; **Anti-padrões**; **Cross-references**. Todo o conteúdo EVEO original preservado (fonte-wiki, fluxo de estados, modo story existente).

### Added
- **Consolidação** (cruzamento skills/ ⨯ skills-compare/ ⨯ ADR-024).
- Seção **Qualidade da story (3 C's + INVEST)** no SKILL.md + `reference/qualidade-story.md` — condensado de `skills-compare/user-stories` (3 C's, INVEST, template de AC) adaptado ao contexto EVEO (Gherkin citando stack real).
- Seção **Alinhamento ADR-024** documentando o que vale do ADR e as divergências deliberadas.
- `AGENTS.md` (padrão do corpus) e este `CHANGELOG.md` (a skill original tinha só SKILL.md).

### Decisões de divergência ADR-024
- **Estados**: skill vence — o projeto usa estados customizados (`Priorizado`/`User Story`/`Refinamento Técnico`/`Em Desenvolvimento`), não o `New → Active → Resolved → Closed` genérico do ADR. ADR não editado (é decisão de plataforma; a skill reflete a customização real do process template).
- **Sprint/Iteration**: skill vence — o time não usa sprints; `IterationPath` fixo. O ADR-024 assume sprint cadence semanal, não aplicável ao ENGSOFT.

### Descartes (skills-compare)
- **create-prd** (PRD 8 seções): fora de escopo — PRD é artefato de produto anterior à story; a skill parte de uma descrição já existente e cria a story. Não incorporado; conceito de "problema/objetivo/valor" já coberto pelo formato "Como/quero/para" + Description.
- **user-stories** — "Further Reading" (link externo) e o exemplo em inglês (Recently Viewed) descartados; mantido só o núcleo conceitual (3 C's + INVEST), reescrito em pt-BR e ancorado na stack EVEO.

## [1.0.0] - 2026-06-11

### Added
- Versão inicial (EVEO): fluxo de criação de User Story no Azure DevOps buscando o padrão na wiki ENGSOFT; fluxo de estados; modo story existente.
