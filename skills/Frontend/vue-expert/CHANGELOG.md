# Changelog — vue-expert

## [2.1.0] - 2026-06-30

### Changed
- Consolidação em `skills-optimizadas` (cruzamento skills/ ⨯ skills-compare/vue-best-practices ⨯ ADR-006).
- Path do security baseline corrigido para `reference/security-baseline.md`.
- `keywords` corrigidas: de `['vue-expert']` (nome da skill) para 8 keywords reais de trigger.
- SKILL.md reescrito no padrão Framework 2.1 (Princípios com porquê, Stack canônica, Workflow agentic).
- Stack alinhada ao ADR-006 e às últimas estáveis (jun/2026): Vue 3.5+, Pinia 3, Vite 8, VueUse 14+, Vitest 4, Zod 4, TanStack Query (Vue) 5, VeeValidate 4, Vue Router 4 (v5 disponível — nota de migração).

### Added
- `reference/advanced.md` (do compare): guia de decisão de built-ins (Slots/Teleport/Suspense/KeepAlive/Transition), passe de performance (virtualização, `v-once`/`v-memo`, anti over-abstração em listas, `onUpdated`) e metodologia de split de componentes (gatilhos objetivos + data flow).
- Seção **Performance** (resumo) e ameaças de segurança específicas de frontend Vue no SKILL.md.
- VeeValidate+Zod, Playwright (E2E) e TanStack Query (server-state) promovidos a itens canônicos da Stack (alinhamento ADR-006).

### Removed
- `reference/patterns.md` (era byte-a-byte idêntico a `reference/core.md` — duplicata).

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
