# Commands

Slash commands do Claude Code usados no fluxo de trabalho do time (Azure DevOps + stack Go). Cada arquivo `.md` é um command com front-matter (`description`, `argument-hint`) seguido do prompt.

## Commands disponíveis

| Command | O que faz |
|---|---|
| [`dev-team.md`](dev-team.md) | Workflow agêntico para uma **Feature** inteira do ADO: mapeia as US filhas, define a ordem racional/técnica de implementação, identifica o que pode rodar em paralelo sem conflito e executa o workflow `/pick-card` em cada US (branch e PR por US, commits pequenos e rastreáveis). |
| [`history-writer.md`](history-writer.md) | Workflow de **Product Discovery + escrita de User Stories** para uma Feature do ADO: pesquisa o contexto (repo + Wiki Discovery), entrevista o usuário sobre persona/problema/resultado, quebra a Feature em US no template EVEO (História/Contexto/BDD/Integrações/Fora de escopo), gera Acceptance Criteria (DoD) e Refinamento Técnico com fontes validadas, e documenta tudo no Wiki. Usa a skill [`user-story`](../skills/user-story/SKILL.md). Escreve histórias, não código. |
| [`generate-card.md`](generate-card.md) | Cria **N User Stories com Tasks já quebradas** dentro de uma Feature existente do ADO: aplica INVEST, monta Description/AC/Refinamento Técnico pelos padrões da wiki, pré-calcula Story Points (Fibonacci) e para no estado Refinamento Técnico — handoff para o `/pick-card`. |
| [`pick-card.md`](pick-card.md) | Inicia o workflow agêntico a partir de um card do ADO atribuído a mim: refinamento técnico (avaliação de complexidade via Story Points + spec-driven com OpenSpec) → desenvolvimento (rastreabilidade do Coding Agent em branch/header/PR) → QA + Security (obrigatórios, inclui `bug-exterminator`) → UAT (Wiki aninhado em EVEO/Features/Stories). |
| [`rules-generator-go.md`](rules-generator-go.md) | Gera/atualiza Project Rules (`.mdc`) de Go em `.cursor/rules/` a partir do estado real do repo e das convenções oficiais de Go. |
| [`scaffold-pipeline.md`](scaffold-pipeline.md) | Gera o CI/CD Azure DevOps de um repositório **novo** a partir do padrão real `pipeline-templates` (não o genérico): detecta stack entre 8 suportadas (Go/Python piloteados; Java/NestJS/React/Next.js/Vue/Angular como draft), roda `scaffold-repo.sh` com nomenclatura validada, valida ativamente a prontidão do ambiente (Harbor, variable groups, RBAC, agent pool) e entrega os comandos `az` de remediação para o que faltar — não provisiona infra sozinho. Usa a skill [`cicd-expert`](../skills/DevSecOps/cicd-expert/SKILL.md). |

## Instalação

Copie os commands para o diretório de commands do Claude Code:

```bash
# Globais (todos os projetos)
cp ai-hardness/commands/*.md ~/.claude/commands/

# Ou por projeto (apenas neste repo)
mkdir -p .claude/commands && cp ai-hardness/commands/*.md .claude/commands/
```

Em seguida invoque com `/dev-team`, `/history-writer`, `/generate-card`, `/pick-card`, `/rules-generator-go` ou `/scaffold-pipeline` no Claude Code. Use `argument-hint` para saber o que passar como argumento.

> `history-writer` depende da skill `user-story` instalada em `~/.claude/skills/user-story/` (versionada verbatim em [`../skills/user-story/`](../skills/user-story/)). Copie-a junto: `cp -R ai-hardness/skills/user-story ~/.claude/skills/`.

> `scaffold-pipeline` depende da skill `cicd-expert` instalada em `~/.claude/skills/DevSecOps/cicd-expert/`. Copie-a junto: `cp -R ai-hardness/skills/DevSecOps/cicd-expert ~/.claude/skills/DevSecOps/`.

## Dependências entre os artefatos

- `history-writer` faz a discovery e escreve as US da Feature (com AC e Refinamento Técnico) e documenta a Discovery no Wiki — upstream de `generate-card`/`pick-card`. Usa a skill `user-story` (ver [`../skills/user-story/`](../skills/user-story/)) como metodologia-base.
- `generate-card` cria as US (com Tasks) dentro de uma Feature e entrega cada uma em Refinamento Técnico — estado que o `/pick-card` assume como ponto de partida.
- `dev-team` orquestra uma Feature inteira executando o workflow `/pick-card` em cada US filha.
- `pick-card` chama `/rules-generator-go` na etapa de preparação do projeto.
- `pick-card` assume os hooks `git-commit-validate` e `go-fmt-fix` ativos (ver [`../hooks/`](../hooks/)).
- `pick-card` usa a skill `bug-exterminator` (ver [`../skills/DevSecOps/bug-exterminator/`](../skills/DevSecOps/bug-exterminator/)) na etapa de QA e a CLI `openspec` para tarefas de alta complexidade (Story Points 8+).
- `scaffold-pipeline` usa a skill `cicd-expert` (ver [`../skills/DevSecOps/cicd-expert/SKILL.md`](../skills/DevSecOps/cicd-expert/SKILL.md), seção "EVEO — Padrão Real") como fonte do padrão `pipeline-templates` — é standalone hoje (não é chamado automaticamente por `pick-card`/`dev-team`), pensado para repositórios **novos**.
