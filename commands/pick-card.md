---
description: Inicia o workflow agêntico a partir de um card do ADO atribuído a mim - refinamento técnico (com avaliação de complexidade + spec-driven via OpenSpec) → desenvolvimento → QA + Security (obrigatórios) → UAT.
argument-hint: "[ID do work item do ADO; se vazio, lista meus cards]"
---

Você é o agente do **AI Workflow no ADO** (feature [IE-07]). Conduza o card do ADO de ponta a ponta, do refinamento técnico até o UAT, seguindo EXATAMENTE as etapas abaixo. Não pule etapas; ao final de cada etapa, reporte o que fez.

## Pré-requisitos
- Conexão ADO via REST: use o PAT em `$ADO_PAT` (env/secret). NUNCA imprima o token nem o grave em arquivo versionado.
- Org: `eveo-workspaces` · Projeto: `ENGSOFT - Engenharia de Software`.
- Repositório de stack/skills/rules/hooks do time: `engsoft-stack-devops-ai` (Azure Repos do mesmo projeto). É a **fonte de verdade** de skills, hooks, rules e baselines — sempre consultado, nunca presumido de memória.
- `openspec` CLI instalado (spec-driven development). Schema padrão `spec-driven`: artefatos `proposal → specs → design → tasks`. Usado para tarefas complexas (ver Etapa 2).

## Entrada
- `$ARGUMENTS` = ID do work item. Se vazio: consulte via WIQL os work items com `System.AssignedTo = @me` na coluna/etapa de **Refinamento Técnico** e me pergunte qual iniciar.

## Etapa 0 - Carregar o card
1. GET do work item (`$expand=relations`): tipo, título, descrição, critérios de aceite, parent, repositório associado e o campo `Microsoft.VSTS.Scheduling.StoryPoints`.
2. Confirme que está atribuído a mim e na etapa de **Refinamento Técnico**. Se não estiver, me avise antes de prosseguir.
3. **Garantia de pontuação (sempre)**: TODA US trabalhada pelo workflow precisa ter Story Points. Se o card já passou do Refinamento (ex.: Desenvolvimento/QA/UAT) e está **sem Story Points**, execute apenas a avaliação de complexidade da Etapa 2.1 em modo retroativo — avalie pelo estado atual do card/código, grave os Story Points e marque no comentário que foi um preenchimento **retroativo** — e siga o fluxo normal da etapa em que o card realmente está (não reabra o refinamento nem recrie tasks).
4. **Identificar a ferramenta de IA** (para a Convenção de Marcação de Código Gerado por IA — alimenta o dashboard DNA de Repositórios). Fixe:
   - `AI_TOOL` = id do modelo que está gerando o código, dentre `claude-sonnet-4-6` · `claude-opus-4-8` · `copilot` · `chatgpt-4o` · `gemini`. Rodando no Claude Code, use o **modelo ativo** (ex.: `claude-opus-4-8`).
   - `AI_COAUTHOR` = trailer `Co-Authored-By` correspondente. Para Claude: `Claude <Modelo> <noreply@anthropic.com>` (ex.: `Claude Opus 4.8 <noreply@anthropic.com>`); Copilot: `GitHub Copilot <copilot@github.com>`; ChatGPT/OpenAI: `ChatGPT <noreply@openai.com>`.
   - Esses valores são usados no header dos arquivos, no prefixo da branch e nos trailers de commit (Etapa 3). Reporte qual ferramenta foi identificada.

## Etapa 0.5 - Natureza do trabalho: nova US vs correção de bug
> Decida ANTES de refinar, pela **natureza da demanda** (não apenas pelo tipo do card carregado). Isso define onde o trabalho vive no ADO.

1. **Novo negócio / nova funcionalidade / mudança de comportamento** → SEMPRE crie uma **nova User Story** (parent = a Feature adequada) e conduza todo o fluxo (refinamento → SP → dev → QA/Security → UAT) sobre ela. **Nunca** pendure comportamento novo numa US já entregue.
2. **Correção de bug** → **NÃO** crie nova US. Crie um work item **Bug** como filho da **US existente** relacionada (a US onde o comportamento se origina / a mais próxima do escopo) e conduza o fluxo sobre o Bug, mantendo a rastreabilidade sob aquela US. Vincule o Bug à US (relação parent/child).
   - A US existente **mantém seus Story Points** — não repontue a US. Avalie o esforço no próprio Bug (Etapa 2.1) se precisar dimensionar.
   - Se a US de origem não for óbvia, liste as candidatas e **me pergunte** qual adotar antes de criar o Bug.
3. **Caso misto** (a correção também exige comportamento novo): separe — **Bug** para a correção (na US existente) + **nova US** para o incremento de negócio.
4. Convenção para as próximas etapas: "**a US**" = a US nova (novo negócio) ou a US-mãe do Bug (correção); "**o item de trabalho**" = a US nova ou o Bug. Branch/PR/commits referenciam o item de trabalho (`<tipo>=feat` para US nova, `<tipo>=fix` para Bug).

## Etapa 1 - Preparar o projeto (consulta OBRIGATÓRIA ao `engsoft-stack-devops-ai`)
> Esta etapa SEMPRE acontece. O repo do time é reconsultado a cada execução — nunca assuma que o que já está em `.claude/` é suficiente.

1. Identifique o repositório/diretório local do projeto do card e detecte a stack real (linguagem, frameworks, banco, mensageria, cloud, infra) lendo `go.mod`/`package.json`/`pom.xml`/etc., Dockerfiles, manifests e configs.
2. **Consulte o `engsoft-stack-devops-ai` no ADO** e selecione, pela stack detectada, o que é aplicável:
   - **Rules**: verifique `.cursor/rules/*.mdc`. Se faltarem ou estiverem desatualizadas, gere/atualize com `/rules-generator-go` (que analisa o repo + `engsoft-stack-devops-ai`: `skills/Backend/golang-expert/*`, ADRs, `_shared/security/baseline.md`).
   - **Skills (decisão autônoma — NÃO pergunte)**: você mesmo avalia o repo de skills do `engsoft-stack-devops-ai` contra (a) a stack do projeto como um todo e (b) o escopo específico da US a implementar, e **instala automaticamente** em `.claude/skills/` toda skill que julgar fazer sentido — sem pedir confirmação ao desenvolvedor. SEMPRE inclua `security-expert` + baseline `_shared`; conforme a stack: `golang-expert`, `git-expert`, `cicd-expert`, `docker-expert`, `postgres/mongodb/rabbitmq-expert`, etc. Inclua a skill `bug-exterminator` na caça a bugs silenciosos (Etapas 3 e 4). Apenas **reporte** (não pergunte) quais skills instalou e por quê (projeto vs. US). Se uma skill aplicável NÃO existir no repo, registre como TODO e me avise.
   - **Hooks**: consulte `ai-hardness/hooks/` no repo e traga para `~/.claude/hooks/` (ou `.claude/hooks/` do projeto) os hooks aplicáveis, registrando-os no `settings.json` conforme `ai-hardness/hooks/README.md`. Para projeto Go, garanta `git-commit-validate` (PreToolUse Bash) e `go-fmt-fix` (PostToolUse Edit|Write|MultiEdit) ativos.
   - Se uma skill/hook aplicável NÃO existir no repo, registre como TODO e me avise.
3. Reporte: stack detectada, rules presentes/geradas, skills instaladas e hooks trazidos/ativados.

## Etapa 2 - Refinamento técnico (avaliação de complexidade + spec-driven)

### 2.1 - Avaliar complexidade e gravar Story Points
1. Avalie a complexidade da US e atribua **Story Points** usando o sistema de scoring por critério abaixo. Some os pontos de cada critério e mapeie o total para a escala Fibonacci:

   **Critério 1 — Módulos/serviços impactados**
   | Situação | Pontos |
   |---|---|
   | 1 módulo | 1 |
   | 2–3 módulos | 2 |
   | 4+ módulos ou microserviços distintos | 4 |

   **Critério 2 — Mudança de contrato (API ou DB)**
   | Situação | Pontos |
   |---|---|
   | Sem mudança de contrato | 0 |
   | Mudança interna (sem impacto externo) | 1 |
   | Breaking change externo | 3 |

   **Critério 3 — Nova integração externa**
   | Situação | Pontos |
   |---|---|
   | Nenhuma integração nova | 0 |
   | Integração com sistema já conhecido | 2 |
   | Integração com sistema novo/desconhecido | 4 |

   **Critério 4 — Risco e ambiguidade dos critérios de aceite**
   | Situação | Pontos |
   |---|---|
   | Critérios claros e objetivos | 0 |
   | Parcialmente ambíguos | 2 |
   | Muito ambíguos ou risco alto | 4 |

   **Critério 5 — Arquivos/camadas afetadas**
   | Situação | Pontos |
   |---|---|
   | 1–2 arquivos | 0 |
   | 3–5 arquivos | 1 |
   | 6–10 arquivos | 2 |
   | 10+ arquivos ou múltiplas camadas | 4 |

   **Mapeamento total → SP Fibonacci**
   | Pontuação total | SP | Nível | Significado |
   |---|----|----|---|
   | 1–3 | 3 | Baixíssima | mudança trivial/localizada |
   | 4–6 | 5 | Baixa | escopo claro, um módulo |
   | 7–10 | 8 | Média | múltiplos arquivos/camadas, risco moderado |
   | 11–15 | 13 | Alta | múltiplos módulos/serviços, muda contrato de API/DB, nova integração, risco alto ou critérios ambíguos |
   | 16–19 | 21 | Altíssima | escopo grande demais — **requer quebra do escopo da US** antes de prosseguir |
2. **Toda US trabalhada pelo workflow PRECISA ter Story Points — sem exceção.** Grave o valor no campo via REST PATCH no field `Microsoft.VSTS.Scheduling.StoryPoints` (JSON Patch: `[{"op":"add","path":"/fields/Microsoft.VSTS.Scheduling.StoryPoints","value":<SP>}]`). Justifique a nota em um comentário no card (o que pesou na complexidade). Confirme no GET seguinte que o campo ficou gravado.
3. **Idempotência/retroativo**: se o card já tiver Story Points, não sobrescreva sem motivo — só reavalie se a complexidade mudou de fato (e registre o porquê no comentário). Se a gravação for retroativa (card fora do Refinamento, conforme Etapa 0.3), deixe isso explícito no comentário.
4. Se **SP = 21** e o card ainda está em Refinamento: NÃO prossiga com a implementação. Proponha a quebra da US em US/fatias menores (cada uma com SP ≤ 13), crie/sugira esses work items e me peça validação antes de continuar. (Em preenchimento retroativo de card já entregue, apenas registre a nota 21 e a recomendação de quebra — não reabra o que já foi feito.)

### 2.2 - Definir abordagem conforme a complexidade
- **SP 3 (simples)**: quebra direta em tasks. Para cada task, crie o work item Task no ADO (parent = a US) com a **descrição contendo o plano de implementação** (objetivo, abordagem técnica, arquivos afetados, critério de pronto). Vincule dependências (Predecessor/Successor) quando houver. Não use OpenSpec.
- **SP 5-8 (baixa/média)**: OpenSpec **obrigatório em modo leve** — gere ao menos `proposal` + `tasks` (acrescente `specs`/`design` se o escopo pedir). As Tasks do ADO espelham as tasks do OpenSpec (2.3.5).
- **SP 13 (alta)**: OpenSpec **obrigatório e completo** (`proposal → specs → design → tasks`).

### 2.3 - Spec-driven com OpenSpec (quando acionado)
> Objetivo: planejamento de qualidade ancorado no **estado REAL do projeto no momento da implementação** e nas **rules do projeto** — não em suposições.
1. `openspec init` se o projeto ainda não tiver OpenSpec; depois `openspec new change <nome-curto-kebab>`.
2. Antes de escrever cada artefato, **leia o estado real**: a árvore atual do repo, os módulos/contratos afetados, as `.cursor/rules/*.mdc`, ADRs e o `_shared/security/baseline.md` do `engsoft-stack-devops-ai`. A proposal deve refletir o código como ele está HOJE, não como a descrição do card imagina.
3. Gere os artefatos na ordem `proposal → specs → design → tasks` (use `openspec instructions <artefato> --change <id>` como guia). A proposal documenta o porquê e o impacto; os specs, o comportamento esperado; o design, as decisões técnicas e trade-offs alinhados às rules; as tasks, o passo a passo executável.
4. Rode `openspec validate <change>` e corrija até passar.
5. Crie as Tasks no ADO espelhando as tasks do OpenSpec (parent = a US), cada uma com o plano na descrição e link ao change do OpenSpec.

### 2.4 - Fechar o refinamento
- Vincule dependências entre as tasks quando houver.
- Mova o card para o **Done do Refinamento Técnico**.
- Reporte: SP atribuído + justificativa, abordagem escolhida (simples vs OpenSpec) e, se houver, o nome do change do OpenSpec e o resultado da validação.

## Etapa 3 - Desenvolvimento
1. Mova o card para **Desenvolvimento**.
2. **Revisitar o `engsoft-stack-devops-ai` no ADO antes de codificar** — para deixar a codificação cada vez mais assertiva:
   - **Skills (decisão autônoma — NÃO pergunte)**: reconsulte `ai-hardness/skills/` e revalide se as skills em `.claude/skills/` cobrem a stack real do card e o escopo da US. Você mesmo decide e **instala/atualiza automaticamente** o que faltar — sem pedir confirmação (sempre `security-expert` + baseline `_shared`). Apenas reporte o que instalou/atualizou. Se uma skill aplicável não existir no repo, registre como TODO e me avise.
   - **Hooks**: reconfirme que os hooks aplicáveis (`ai-hardness/hooks/`) estão em `~/.claude/hooks/` e ativos no `settings.json`.
   - Reporte: skills revalidadas/instaladas e hooks confirmados.

> **Toda a marcação abaixo segue a Convenção de Marcação de Código Gerado por IA do time** (v1.0) — ela alimenta o ETL do dashboard DNA de Repositórios. Siga-a à risca.

3. **Branch** com prefixo de IA (regex do ETL: `^ai[-/]`): `ai/<tipo>/<ref-da-US>-descricao-curta` quando o desenvolvimento é majoritariamente conduzido pela IA (caso padrão deste workflow), ou `ai-assist/<tipo>/<ref-da-US>-descricao-curta` quando a IA só assistiu. `<tipo>` = `feat`/`fix`/etc. `<ref-da-US>` = referência do work item (ex.: `us2002` ou a chave do projeto como `DSA-XXXX`). Ex.: `ai/feat/us2002-validacao-juridica-cnpjws`.
4. **Header `@ai` em todo arquivo gerado/editado por IA** — primeira linha do arquivo (logo após shebang quando houver), no caractere de comentário da linguagem:
   - Formato: `<comentário> @ai: <AI_TOOL> | <escopo>` — escopo `full` (arquivo 100% gerado por IA) ou `assisted` (criado por humano, editado por IA). Arquivos novos criados pelo workflow → `full`.
   - Exemplos: Go/TS `// @ai: claude-opus-4-8 | full` · Python/YAML/Dockerfile `# @ai: claude-opus-4-8 | full` · SQL `-- @ai: claude-opus-4-8 | full`.
   - Para arquivos sem suporte a comentário (ex.: JSON puro), não force o header. Idempotência: não duplique o header se já existir.
   - **Blocos** dentro de arquivo não marcado no cabeçalho: envolva o trecho gerado por IA com `<comentário> @ai-begin: <AI_TOOL>` … `<comentário> @ai-end`.
5. Implemente seguindo as `.cursor/rules`, as skills e — quando houver — as **tasks do change do OpenSpec** (marque cada task como concluída no OpenSpec à medida que avança). Commits **estruturados** (Conventional Commits pt-BR — o hook `git-commit-validate` valida; o `go-fmt-fix` formata `.go`), commits por task, **com os trailers da convenção ao final da mensagem**:
   - `Co-Authored-By: <AI_COAUTHOR>` (ex.: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`);
   - `Ai-Scope: <full|partial|assisted>` — `full` (todo o código do commit é da IA), `partial` (parte) ou `assisted` (humano escreveu, IA revisou/sugeriu).
   - `Ai-Skills: <lista>` — skills do `engsoft-stack-devops-ai` efetivamente usadas naquele trabalho, separadas por vírgula (ex.: `Ai-Skills: golang-expert, security-expert, bug-exterminator, testing-expert`). Liste as que guiaram o código do commit (mínimo: `security-expert`). Se nenhuma skill foi usada no commit, omita o trailer.
6. **Pull Request**: abra a PR **a partir da branch `ai/`/`ai-assist/`** (é o que o ETL detecta) — título em Conventional Commits referenciando a US (ex.: `feat(validacao): validação jurídica via CNPJws`), e o corpo referenciando US e task(s). A rastreabilidade de IA na PR vem da branch `ai/` + dos trailers nos commits (não de marcação no título).
7. Em cada task do ADO, registre **nos comentários** como de fato implementou (arquivos, decisões, commits, ferramenta de IA) e mova a task para Done.
8. Se usou OpenSpec, ao concluir a implementação rode `openspec archive <change>` para consolidar os specs.

## Etapa 4 - QA + Security (OBRIGATÓRIOS, sempre)
> Só avance para o UAT depois que AMBOS passarem. Esta etapa nunca é opcional.
1. **QA**: rode a skill/comando de QA (ex.: `/code-review` ou a skill `testing-expert`) e a skill **`bug-exterminator`** para caçar bugs silenciosos (race conditions, erros engolidos, leaks de recurso, problemas específicos do ambiente de produção). Corrija os achados e rode os testes (`go test -race -cover ./...`) e o lint (`golangci-lint run`) até ficarem verdes.
2. **Documentação de QA (OBRIGATÓRIA)**: após rodar o QA, gere uma documentação de QA daquela implementação contendo, no mínimo: escopo analisado (US/tasks/arquivos), ferramentas/skills usadas (QA + `bug-exterminator`), **o que foi identificado** (bugs/achados, severidade), **o que foi feito para corrigir** cada item, e o estado final dos testes/lint/cobertura. Salve em `docs/qa/US-<ID>-qa.md` no repo do projeto (crie a pasta se faltar) — esse arquivo também alimenta o Wiki na Etapa 5.
3. **Security**: rode a skill/comando de segurança (ex.: `/security-review` ou a skill `security-expert`, com o `_shared/security/baseline.md`). Corrija vulnerabilidades/segredos expostos.
4. **Documentação de Security (OBRIGATÓRIA)**: após rodar o Security, gere uma documentação de Security daquela implementação contendo, no mínimo: escopo e baseline aplicado (`_shared/security/baseline.md`), **o que foi identificado** (vulnerabilidades/segredos/CWE, severidade), **o que foi feito para corrigir** cada item, e os riscos residuais aceitos (se houver). Salve em `docs/security/US-<ID>-security.md` no repo do projeto (crie a pasta se faltar) — esse arquivo também alimenta o Wiki na Etapa 5.
5. Reporte o resultado de QA, do bug-exterminator e de Security (com os ajustes feitos) e os caminhos das duas documentações geradas. **Toda implementação termina com uma doc de QA e uma de Security — sem exceção.**

## Etapa 5 - UAT + notificação
1. Mova o card para **UAT**.
2. Notifique-me (Teams/Email) com o link do card e um resumo do que foi entregue, para validação.
3. **Documente no Wiki** do ADO (vinculando a US): detalhes técnicos, decisões, trechos de código e diagramas Mermaid (ver feature [IE-07], US #1988). Se houve OpenSpec, referencie os specs arquivados.
   - **Estrutura obrigatória do Wiki (NUNCA escreva na raiz)**: a hierarquia espelha o ADO — a doc da US vive em
     `EVEO / <Épico> / <Feature> / <US> / <página de doc>`, onde:
     - `EVEO` é a home do Wiki;
     - `<Épico>` = título do work item Épico pai da Feature (obtenha subindo a hierarquia: US → Feature → Épico via relations; se a Feature não tiver Épico pai, me pergunte sob qual Épico documentar);
     - `<Feature>` = título do work item Feature pai da US (ex.: `[IE-05] Orquestrador ...`);
     - `<US>` = uma **pasta** nomeada `US <ID> - <título>` (ex.: `US 2002 - [IE-05] Solução Provisória de Automação`);
     - a documentação é uma (ou mais) página(s) **dentro** dessa pasta da US.
   - Garanta que cada nível do caminho exista, criando as páginas-pai que faltarem (`EVEO` → `<Épico>` → `<Feature>` → `<US>`) antes de escrever a doc. Use a Wiki REST API (`PUT .../wiki/wikis/{wikiId}/pages?path=<caminho-encodado>&api-version=7.0`), encodando `/` e espaços no path.
   - **Migração**: se encontrar doc desta US na estrutura antiga (`EVEO/Features/<Feature>/Stories/<US>`), mova o conteúdo para o caminho novo e não escreva mais na estrutura antiga.
   - **Inclua as docs de QA e Security** geradas na Etapa 4 (`docs/qa/US-<ID>-qa.md` e `docs/security/US-<ID>-security.md`) como páginas dentro da pasta da US (ex.: `.../US <ID> - <título>/QA` e `.../US <ID> - <título>/Security`), refletindo o que foi identificado e como foi corrigido.
   - Idempotência: se a página já existir, atualize-a (não crie duplicata nem escreva na raiz).

## Regras de ouro
- A consulta ao `engsoft-stack-devops-ai` (skills + hooks + rules) é **obrigatória e sempre reexecutada** — Etapa 1 instala, Etapa 3 revalida.
- **Skills são decididas e instaladas pelo agente, nunca opcionais**: o agente avalia o projeto e a US e adiciona automaticamente as skills aplicáveis, sem perguntar ao desenvolvedor — apenas reporta o que instalou e por quê.
- **Nova US vs Bug** (Etapa 0.5): novo negócio/funcionalidade → **sempre uma nova User Story**; correção de bug → **Bug dentro da US existente** (nunca nova US para bug). Caso misto → separa Bug (US existente) + nova US (incremento).
- Story Points são gravados na US e definem o caminho: 3 simples (sem OpenSpec), **5 pra cima sempre tem OpenSpec** — 5-8 leve obrigatório, 13 completo, 21 quebra a US. Em correção de bug, a US existente mantém seus SP (não repontuar).
- OpenSpec lê o estado REAL do repo + as rules no momento do planejamento — nunca planeje em cima da descrição do card isoladamente.
- QA (incl. `bug-exterminator`) e Security **sempre** rodam antes do UAT — sem exceção, e **cada um gera sua documentação** (`docs/qa/US-<ID>-qa.md` e `docs/security/US-<ID>-security.md`) com o que foi identificado e como foi corrigido. Toda implementação termina com as duas docs.
- **Marcação de código gerado por IA** (Convenção do time → dashboard DNA): branch com prefixo `ai/`/`ai-assist/`, header `@ai: <modelo> | <full|assisted>` na 1ª linha dos arquivos (ou blocos `@ai-begin`/`@ai-end`), e trailers `Co-Authored-By` + `Ai-Scope` + `Ai-Skills` (skills usadas no trabalho) em todo commit com código de IA.
- **Wiki sempre aninhado** em `EVEO/<Épico>/<Feature>/<US>/...` — nunca na raiz.
- Quem move o card para UAT é o agente; quem valida o UAT sou eu.
- Idempotência: não duplicar tasks/comentários/transições/changes do OpenSpec se o card já tiver sido processado.
