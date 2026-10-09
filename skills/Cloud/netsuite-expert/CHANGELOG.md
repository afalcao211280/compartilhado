# Changelog — netsuite-expert

## [2.1.0] - 2026-06-30

### Changed
- Consolidação em `skills-optimizadas` (SEM ADR e SEM compare direto — apenas otimização + correções de conformidade).
- `description` reduzida de 1117 para <600 chars (limite do schema), preservando os gatilhos de trigger essenciais (SuiteScript, SDF, SuiteQL, RESTlet, Map/Reduce, OAuth/TBA, N/record etc.).
- Path do security baseline corrigido para `reference/security-baseline.md`.
- AGENTS.md alinhado ao formato do corpus e apontando para `skills-optimizadas`.
- version bump minor 2.0.0 → 2.1.0.

### Added
- Índice (TOC) em `reference/patterns.md` (1130+ linhas) e `reference/stack.md` (>300 linhas), conforme convenção de progressive disclosure.

### Removed
- `reference/core.md` — subconjunto do SKILL.md (tabela de decisão de script type + integração + governance) e com seções truncadas/vazias (`## Padrões Obrigatórios`, `## Workflow Agentic` sem corpo). Não era referenciado pelo SKILL.md (que aponta só para `stack.md` e `patterns.md`). Redundante — removido.

### Notas
- SKILL.md já estava no formato Framework 2.0 e denso (princípio central, tabela de decisão de script type, arquitetura de integração, governance, padrões obrigatórios, workflow agentic, anti-padrões, checklist, quando perguntar). Preservado; apenas frontmatter e path do baseline corrigidos.
- keywords (`netsuite`, `suitescript`, `erp`, `cloud`, `suitecloud`, `suiteql`, `sdf`) já eram 7 termos reais — mantidas.

## [2.0.0] - 2026-05-28
### Changed
- SKILL.md padronizado no formato Framework 2.0 (caveman style)
- Adicionado versionamento semantico
- Adicionado keywords para trigger matching
- Seguranca referenciada via _shared/security/baseline.md
- Referencias reorganizadas

## [1.0.0] - 2024-01-10
### Added
- Versao inicial
