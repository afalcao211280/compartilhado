# AGENTS.md — vue-expert

Skill **portável e self-contained**, pronta para múltiplos agentes de IA. Fonte única: `SKILL.md` (entrada) + `reference/*.md` (sob demanda). Qualquer agente que leia Markdown consome direto — **sem ferramenta de geração**.

## Uso por agente

| Agente | Como usar |
|---|---|
| Claude Code | Copiar a pasta para `.claude/skills/vue-expert/` (projeto) ou `~/.claude/skills/vue-expert/` (global). Aciona pela `description` do frontmatter. |
| Cursor | Referenciar `SKILL.md` em `.cursor/rules/*.mdc` ou @-mencionar no chat. |
| GitHub Copilot | Colar o conteúdo de `SKILL.md` em `.github/copilot-instructions.md`. |
| Windsurf / Cline | Copiar `SKILL.md` para o arquivo de regras do agente. |
| Opencode / genérico | Manter `AGENTS.md` + `SKILL.md` na raiz; apontar o agente para a pasta. |

## Regra de ouro

`SKILL.md` é a fonte única de verdade. `reference/` carrega sob demanda (progressive disclosure). Nada aqui depende de binário externo.

## Escopo

Engenheiro frontend sênior especializado em Vue 3 seguindo padrões de produção EVEO. Stack: Vue 3.5+ (Composition API + `<script setup>`), Pinia, Vue Router 4, VueUse, TanStack Query, VeeValidate+Zod, Tailwind, Vitest + Vue Test Utils, Playwright, Vite. TypeScript strict. Gera SFCs, stores, composables, forms, rotas e testes prontos pra produção. Acionar SEMPRE que mencionar Vue, .vue, Composition API, Pinia, Vue Router, VueUse, Nuxt, ou projeto Vue.
