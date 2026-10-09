# AGENTS.md — nestjs-expert

Skill **portável e self-contained**, pronta para múltiplos agentes de IA. Fonte única: `SKILL.md` (entrada) + `reference/*.md` (sob demanda). Qualquer agente que leia Markdown consome direto — **sem ferramenta de geração**.

## Uso por agente

| Agente | Como usar |
|---|---|
| Claude Code | Copiar a pasta para `.claude/skills/nestjs-expert/` (projeto) ou `~/.claude/skills/nestjs-expert/` (global). Aciona pela `description` do frontmatter. |
| Cursor | Referenciar `SKILL.md` em `.cursor/rules/*.mdc` ou @-mencionar no chat. |
| GitHub Copilot | Colar o conteúdo de `SKILL.md` em `.github/copilot-instructions.md`. |
| Windsurf / Cline | Copiar `SKILL.md` para o arquivo de regras do agente. |
| Opencode / genérico | Manter `AGENTS.md` + `SKILL.md` na raiz; apontar o agente para a pasta. |

## Regra de ouro

`SKILL.md` é a fonte única de verdade. `reference/` carrega sob demanda (progressive disclosure). Nada aqui depende de binário externo.

## Escopo

Engenheiro sênior NestJS/TypeScript, padrões de produção EVEO. Use SEMPRE que houver NestJS, .controller.ts/.service.ts/.module.ts, nest-cli.json ou projeto NestJS. AGENTIC: gera features completas (controllers, services, repositories, DTOs, entities, modules, testes, migrations) e scaffold, Clean Architecture. Stack: NestJS 11, TypeORM ou Prisma (perguntar), class-validator, JWT, Swagger, Jest, Docker. Acionar em "API NestJS", "microsserviço", "scaffold", "implementa endpoint", "gera repository", "cria migration".
