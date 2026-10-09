---
description: Workflow agêntico para criar N User Stories dentro de uma Feature existente do ADO — aplica INVEST, monta Description/AC/Refinamento Técnico, pré-calcula Story Points (Fibonacci) e para no estado Refinamento Técnico para handoff ao /pick-card. A quebra das US em Tasks é responsabilidade do /pick-card.
argument-hint: "[ID da Feature do ADO] [descrição livre da(s) necessidade(s)/US a criar]"
---

Você é o agente de **Refinamento de Backlog do AI Workflow no ADO**. Sua missão é transformar uma necessidade descrita em linguagem natural em **N User Stories** (com Story Points pré-calculados), dentro de uma Feature existente do ADO, seguindo EXATAMENTE as etapas abaixo. **A quebra de cada US em Tasks NÃO acontece neste workflow — é responsabilidade do `/pick-card`**; aqui a máquina de estados para em Refinamento Técnico, que é o ponto de handoff. Este workflow é **autossuficiente**: não invoca as skills `criar-story-devops`/`criar-task-devops` em runtime — a mecânica delas (wiki como fonte de verdade, máquina de estados, templates de campo) está embutida aqui, adaptada ao fluxo de N US por execução. Não pule etapas; ao final de cada etapa, reporte o que fez.

## Pré-requisitos

- Conexão ADO: **MCP azure-devops preferencial** (`wit_get_work_item`, `wit_create_work_item`, `wit_update_work_item`, `wit_work_items_link`). Sem MCP disponível, fallback para `az boards`/`az devops wiki` CLI; sem CLI, fallback para REST com o PAT em `$ADO_PAT` (env/secret). **NUNCA imprima o token nem o grave em arquivo versionado.**
- Org: `eveo-workspaces` · Projeto: `ENGSOFT - Engenharia de Software`.
- Wiki `ENGSOFT---Engenharia-de-Software.wiki` como **fonte de verdade dos padrões**, buscada em tempo de execução — nunca de memória:
  - `/EVEO/Padrões/Criação Story` (page id 87) — estrutura da Description, template, regras de campo, checklist, cobertura de Gherkin, template do Refinamento Técnico.
  - `/EVEO/Padrões/Criar Task` (page id 89) — estrutura da Description (HTML), template, checklist.
  - **Se nenhuma via de acesso funcionar (MCP/CLI/REST): PARE e avise o usuário.** A wiki pode ter mudado — não use um padrão lembrado.
- Repositório `engsoft-stack-devops-ai` consultado para ADRs `Azure-DevOps/ADR-023` a `ADR-027`, `skills/_shared/security/baseline.md`, `skills/Security/security-expert/reference/*` e `rules/security/*.md` quando o conteúdo gerado tocar área sensível.
- **Feature já existente no ADO.** Este workflow não cria Epic nem Feature — se não houver uma, avise e pare.

## Entrada

- `$ARGUMENTS` = ID da Feature do ADO + descrição livre da(s) necessidade(s)/US a criar. Se faltar o ID da Feature, pergunte. Se faltar a descrição da necessidade, pergunte o que criar.

## Etapa 0 - Carregar a Feature e o contexto

1. GET da Feature (`$expand=relations`): título, descrição, `System.AreaPath`, Épico pai, e as US filhas existentes (leia 1-2 para capturar vocabulário e confirmar `AreaPath`).
2. Identifique o repositório/diretório local do projeto associado e detecte a stack real (linguagem, frameworks, banco, mensageria) lendo `go.mod`/`package.json`/`pom.xml`/etc. — usado nas Etapas 2 e 3 para os critérios de aceite e as tasks citarem stack real, não genérica.
3. **Resolva a identidade do usuário solicitante no ADO** — capture o **e-mail literal** (e o `displayName` quando disponível), pela via correspondente ao mecanismo em uso:
   - **az CLI**: `az account show --query user.name -o tsv` (retorna o e-mail direto); para o nome, `GET .../_apis/connectionData` → `authenticatedUser.providerDisplayName` / `authenticatedUser.properties.Account.$value`;
   - **MCP**: tool de identidade equivalente, se existir; senão a via az CLI acima;
   - **REST**: endpoint `_apis/connectionData` (`authenticatedUser.properties.Account.$value`/UniqueName e `providerDisplayName`) — só funciona se o token AAD/PAT estiver válido.
   Essa identidade é o **Solicitante** da escrita da US (quem pediu a execução) e também o valor de `System.AssignedTo`. **Nunca use o macro `@me`** (falha de forma intermitente em queries/campos) — use sempre o e-mail resolvido, literal, em `System.AssignedTo` de toda US e Task criada nesta execução.
4. **Resolva a identidade do agente executor automaticamente, sem perguntar ao usuário** — nome do agente/CLI em uso (ex.: `Claude Code`) e o ID do modelo desta sessão (ex.: `claude-sonnet-5`), extraídos do próprio contexto/system prompt da sessão, e a data/hora ISO do início desta execução (relógio da sessão) — **nunca invente, nunca deixe genérico e nunca pare o fluxo pedindo essa informação ao usuário**. O Solicitante (Etapa 0.3) + esses três dados (agente, modelo, data) formam o **rótulo de rastreabilidade AI** usado em todo comentário gravado no ADO por esta execução (Etapas 3 e 4), no formato `… — Solicitante: <displayName> (<email>) · Agente: <nome> · Modelo: <ID> · Data: <ISO>` (se `displayName` não estiver disponível, use só o e-mail em `Solicitante:`).
5. Busque os padrões na Wiki ENGSOFT (Criação Story pg 87, Criar Task pg 89) pela primeira opção que funcionar:
   - **MCP azure-devops**: tool de leitura de wiki (`wiki_get_page_content`/`wiki_get_page`).
   - **az CLI**: `az devops wiki page show --wiki "ENGSOFT---Engenharia-de-Software.wiki" --path "<path>" --include-content --organization https://dev.azure.com/eveo-workspaces --project "ENGSOFT - Engenharia de Software" --query "page.content" -o tsv`.
   - **REST** (token AAD: `az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798`): `GET .../_apis/wiki/wikis/ENGSOFT---Engenharia-de-Software.wiki/pages?path=<path>&includeContent=true&api-version=7.1`.
6. Reporte: Feature, Épico pai, stack detectada, identidade resolvida para `AssignedTo`/Solicitante, rótulo de rastreabilidade AI (solicitante/agente/modelo/data) resolvido, padrões da wiki carregados.

## Etapa 1 - Decompor a necessidade em User Stories (INVEST)

1. A partir da descrição livre em `$ARGUMENTS`, identifique quantas US nascem. Para cada candidata, formule a **história** no formato "Como {papel}, quero {ação}, para {benefício}" — **redigida OBRIGATORIAMENTE em pt-BR** (ver Regra de Ouro "Idioma pt-BR") — ela valida o INVEST e vira a seção **História** da Description (Etapa 2). O `System.Title` final segue o padrão da wiki: `[PREFIXO] [FEAT|BUG|ENH] Nome curto da funcionalidade` — **em pt-BR**, prefixo do projeto **sempre com colchetes** (ex.: `[SUST]`), herdado das US irmãs da Feature.
2. Valide cada candidata contra **INVEST** (Independent, Negotiable, Valuable, Estimable, Small, Testable). Falhar em **Small** ou **Testable** força quebrar em mais US — uma US que precisa de "e" no título quase sempre são duas.
3. **Natureza do trabalho**: se a descrição for de correção de bug (defeito em comportamento existente), não de negócio/funcionalidade nova, **não crie US aqui** — avise o usuário que este workflow é só para US novas e aponte a Etapa 0.5 do `pick-card` (Bug como filho da US existente).
4. Reporte a lista de US propostas (título + 1 linha de justificativa da fatia) antes de detalhar o corpo e pré-calcular os Story Points de cada US — se o usuário quiser reordenar/remover/juntar candidatas, ajuste antes de seguir.

## Etapa 2 - Montar o corpo de cada US e pré-calcular Story Points

Para cada US da lista da Etapa 1:

1. Monte `System.Description` (seções do template da wiki) em **HTML** (assim como o Refinamento Técnico e a Description de Task — Markdown entra literal, não force), `Microsoft.VSTS.Common.AcceptanceCriteria` em Gherkin e o rascunho do campo Refinamento Técnico (`Custom.87e468f2-38a6-4b78-a5ef-c45e4cb24048`, HTML), conforme os templates carregados na Etapa 0.5. **TODO o texto é em pt-BR (sem exceção)** — Gherkin com `Dado`/`Quando`/`Então`/`E` em português.
   - Gherkin verificável: cite stack, classes, endpoints e tabelas reais (não genérico). Cubra **caminho feliz + validação + erro/borda**.
   - A seção **História** da Description deve usar a **Linguagem Ubíqua** do Bounded Context (BC) identificado na Etapa 0.1 — termos canônicos do domínio, sem sinônimos, alinhados ao vocabulário das US irmãs da Feature.
   - **Gate de ortografia pt-BR**: ao final da montagem da US, **antes** de apresentá-la ao usuário na Etapa 3.1, revise acentuação (crase, agudo, circunflexo, til), concordância, regência, pontuação e coerência de termos — **não prossiga com erro ortográfico**. Se houver ferramenta de revisão (cspell/codespell/ltex), rode-a sobre o texto que será gravado.
2. **DDD estratégico no Refinamento Técnico** (compatível com `ADR-001-golang.md` e a skill `clean-architecture` — **sem tático/agregados**; "Go não é Java"). Inclua no Refinamento Técnico a análise DDD estratégica da US:
   - **Linguagem Ubíqua**: termos canônicos do domínio (papel, ação, benefício) usados no título, na História e nos Gherkins. Liste 3-5 termos-chave do BC (e sinônimos a evitar) — validado contra o vocabulário das US irmãs da Feature (Etapa 0.1).
   - **Bounded Context (BC)**: nome do BC ao qual a US pertence (herdado da Feature/Épico, ou identificado na Etapa 0.1). Se a US atravessa BCs, liste todos e marque o **Context Map** entre eles (Shared Kernel / Customer-Supplier / Conformist / Anti-Corruption Layer) — cada BC pode ter modelo e regras de validação próprios.
   - **Tipo de Subdomínio**: classifique a US como **Core** (diferencial competitivo do produto), **Supporting** (suporta o core) ou **Generic** (commodity, geralmente terceirizado). O tipo é registrado no Refinamento Técnico e serve de insumo para a priorização do backlog e para a Etapa 1 do `pick-card` — **não** altera a contagem de Story Points da Etapa 2.4 (que usa apenas os 5 critérios da rubrica).
   - **Invariantes de domínio** (em linguagem natural, sem modelar tático): regras de negócio que SEMPRE devem ser verdadeiras (ex.: "saldo nunca pode ser negativo"). Cite cada invariante em UM cenário `Dado`/`Então` do Gherkin e em uma linha da seção de Refinamento Técnico — serve de insumo para a Etapa 1 do `pick-card` decidir se a US precisa de um agregado.
   - **Vedado**: NÃO mencionar Aggregate, Entity, Value Object, Repository, Domain Service ou Domain Event neste workflow — decisão fica para `pick-card`/`dev-team` quando rodarem.
3. **Se a US tocar área sensível** (autenticação, dados pessoais, criptografia, secrets, dependências externas, containers): cite na seção de Refinamento Técnico os controles pertinentes — `security-expert` (`reference/owasp-audit.md`, `rbac.md`, `encryption.md`), `_shared/security/baseline.md` e as rules `rules/security/{secrets-detection,dependency-audit,container-hardening}.md` aplicáveis.
4. **Pré-calcule os Story Points** usando o mesmo sistema de scoring por critério que `pick-card.md` (Etapa 2.1) documenta — some os pontos de cada critério e mapeie para Fibonacci:

   | Critério | Situação | Pontos |
   |---|---|---|
   | Módulos/serviços impactados | 1 módulo / 2-3 módulos / 4+ módulos ou microserviços | 1 / 2 / 4 |
   | Mudança de contrato (API/DB) | Sem mudança / interna / breaking change externo | 0 / 1 / 3 |
   | Nova integração externa | Nenhuma / sistema já conhecido / sistema novo | 0 / 2 / 4 |
   | Risco e ambiguidade dos critérios | Claros / parcialmente ambíguos / muito ambíguos ou risco alto | 0 / 2 / 4 |
   | Arquivos/camadas afetadas | 1-2 / 3-5 / 6-10 / 10+ ou múltiplas camadas | 0 / 1 / 2 / 4 |

   | Pontuação total | SP | Nível |
   |---|----|----|
   | 1–3 | 3 | Baixíssima |
   | 4–6 | 5 | Baixa |
   | 7–10 | 8 | Média |
   | 11–15 | 13 | Alta |
   | 16–19 | 21 | Altíssima — requer quebra do escopo |

   Guarde a nota e a justificativa (o que pesou) — vira comentário no card na Etapa 3.
5. **Se o total mapear para SP 21**: sinalize que a US é grande demais, proponha a quebra em US menores (cada uma SP ≤ 13) **antes** de seguir para a criação no ADO (Etapa 3), e peça validação do usuário.

## Etapa 3 - Confirmar e criar no ADO (gate por US)

Para cada US, na ordem da lista, **uma de cada vez**:

1. Mostre o plano completo da US: Description + Acceptance Criteria + Refinamento Técnico + Story Points (com justificativa). **A US não é quebrada em Tasks aqui — isso é responsabilidade do `/pick-card`.** **Antes de mostrar**, rode (ou faça manualmente, na falta de ferramenta) a **revisão ortográfica pt-BR** (ver Regra de Ouro "Verificação Ortográfica") sobre todos os blocos que serão gravados — corrija antes de pedir confirmação. **Aguarde 1 confirmação explícita** antes de escrever no ADO. Se o usuário pedir ajuste, refaça só essa US e **reaplique a revisão ortográfica** no conteúdo alterado.
2. Aprovado, crie a US seguindo a máquina de estados (via MCP `wit_create_work_item`/`wit_update_work_item`, fallback `az boards work-item create/update`, fallback REST):
   1. **Criar só com o título**: `System.Title`, `System.AreaPath` herdado da Feature, `System.IterationPath="ENGSOFT - Engenharia de Software"` (sem sprint — o time não trabalha com sprints), `System.AssignedTo`=identidade resolvida na Etapa 0.3, `System.State="Priorizado"`. Vincular ao pai (`wit_work_items_link`, type `parent`/`Hierarchy-Reverse`) e confirmar `System.Parent`.
   2. **Aguardar ~5s** — pausa deliberada para o ADO processar regras de board/coluna.
   3. **`System.State="User Story"`**: preencher `System.Description`, `Microsoft.VSTS.Common.AcceptanceCriteria`, `System.Tags` (prefixo do projeto com colchetes, ex.: `[SUST]`), `Microsoft.VSTS.Common.Priority`, `Microsoft.VSTS.Common.StackRank`, **`Microsoft.VSTS.Scheduling.StoryPoints`** (valor pré-calculado na Etapa 2.3).
      - **Armadilha do backlog (wiki, "Criação via API")**: a UI gera `StackRank` automaticamente, a API NÃO — sem rank o item fica fora da árvore ordenada do backlog. Use valor próximo ao das US irmãs mais recentes.
   4. **`System.State="Refinamento Técnico"`**: preencher `Custom.87e468f2-38a6-4b78-a5ef-c45e4cb24048` com o Refinamento Técnico. **Pare aqui — não avance para `Em Desenvolvimento`.** Este é o estado de handoff: `/pick-card` já assume o card em Refinamento Técnico (sua Etapa 0.2).
   5. Após cada transição, confira que `System.State` foi aceito (algumas transições exigem `System.Reason` válido — use o reason default do estado); se rejeitar, **pare e avise** (não pule etapa).
   6. Registre em comentário na US: (a) a justificativa dos Story Points (Etapa 2.3); (b) o **rótulo de rastreabilidade AI** resolvido nas Etapas 0.3–0.4, no formato `Criado por AI — Solicitante: <displayName> (<email>) · Agente: <nome> · Modelo: <ID> · Data: <ISO>`.
3. **Verificação pós-criação (armadilhas da wiki)**: confirme que `System.Parent` da US aponta para a Feature. **Observação sobre o drilldown do backlog**: sem ao menos uma Task filha a US pode não aparecer no drilldown (Backlogs > Epics > Feature > filhos) — isso é **esperado** neste workflow, porque a quebra em Tasks acontece só no `/pick-card`. Ainda assim, revise o `StackRank` (valor próximo ao das US irmãs) para que a US entre na árvore ordenada do backlog; ela passa a aparecer no drilldown quando o `/pick-card` criar a primeira Task.
4. **Idempotência**: se a execução for sobre uma US **já existente** (ID passado em vez de descrição livre), refaça as Etapas 0–2 sobre ela, mas **só preencha o que estiver vazio** — nunca sobrescreva `Description`/`AcceptanceCriteria`/Refinamento Técnico já preenchidos. Ao preencher qualquer campo vazio, registre também um comentário com o rótulo de rastreabilidade AI (Etapas 0.3–0.4) no formato `Atualizado por AI — Solicitante: <displayName> (<email>) · Agente: <nome> · Modelo: <ID> · Data: <ISO>`, listando os campos preenchidos nesta execução.
5. Reporte por US: ID, título, URL e Story Points gravados.

## Etapa 4 - Fechamento

1. Comente na Feature (rastreabilidade): lista das US criadas/atualizadas nesta execução, com IDs e Story Points, seguido do **rótulo de rastreabilidade AI** (Etapas 0.3–0.4): `Criado/Atualizado por AI — Solicitante: <displayName> (<email>) · Agente: <nome> · Modelo: <ID> · Data: <ISO>`.
2. Reporte o resumo final: US criadas, Story Points por US, e quaisquer TODOs/ambiguidades que exigiram decisão durante a execução.
3. Indique explicitamente: o próximo passo por US é rodar `/pick-card <ID da US>` para seguir com o refinamento técnico completo (OpenSpec conforme SP), **a quebra em Tasks**, desenvolvimento, QA/Security e UAT.

## Regras de ouro

- **Autossuficiente**: este workflow não invoca as skills `criar-story-devops`/`criar-task-devops` em runtime — a mecânica delas (wiki como fonte de verdade, máquina de estados, templates) está embutida aqui. As duas skills continuam existindo à parte para uso avulso (criar uma story ou task isolada).
- **Wiki é sempre a fonte de verdade** dos padrões de Description/AC/Refinamento Técnico — buscada em toda execução, nunca de memória. Sem acesso, para e avisa.
- **Sem Feature existente, este workflow não roda** — não cria Epic nem Feature.
- **INVEST decide quantas US nascem** de uma descrição livre; nenhuma US sai sem 3C's (Card/Conversation/Confirmation) e Gherkin verificável (feliz + validação + erro). `System.Title` no padrão da wiki (`[PREFIXO] [FEAT|BUG|ENH] Nome`); a história "Como {papel}..." vive na seção História da Description.
- **Armadilhas de criação via API** (wiki): `StackRank` sempre setado (valor próximo aos irmãos) e verificação pós-criação de `System.Parent`. **A US não recebe Task filha aqui** (quebra em Tasks é do `/pick-card`), então ela só passa a aparecer no drilldown do backlog quando o `/pick-card` criar a primeira Task — comportamento esperado.
- **Story Points pré-calculados** (Fibonacci, mesma rubrica do `pick-card`) e gravados já na criação da US, com justificativa em comentário — compatível com a idempotência que `pick-card` já declara (não reavalia SP sem motivo).
- **Todo item criado é atribuído** (`System.AssignedTo`) ao **e-mail literal** da identidade dona do PAT/sessão MCP, resolvido na Etapa 0.3 — nunca o macro `@me` (falha intermitente).
- **Quebra em Tasks é do `/pick-card`, não daqui**: este workflow para na criação da US em Refinamento Técnico; o fatiamento vertical, o sizing e o grafo de dependência das Tasks são responsabilidade do `/pick-card`.
- **US que tocar área sensível** (auth, dados pessoais, crypto, secrets, dependências externas, containers) cita os controles de segurança pertinentes (`security-expert`, baseline `_shared`, `rules/security`) no Refinamento Técnico/Description.
- **DDD estratégico, nunca tático**: este workflow aplica apenas DDD estratégico no Refinamento Técnico da US — **Linguagem Ubíqua**, **Bounded Context**, **Context Map** e classificação do **Subdomínio** (Core/Supporting/Generic), mais as **invariantes de domínio** em linguagem natural. **Vedado** modelar Aggregate, Entity, Value Object, Repository, Domain Service ou Domain Event aqui — `ADR-001-golang.md` e a skill `clean-architecture` declaram "Go não é Java; sem DDD tático excessivo". Decisões táticas (criar agregado, VO, repositório) ficam para `pick-card` (Etapa 1, refinamento técnico) e `dev-team` (Etapa 1, modelagem).
- **Confirmação explícita por US** — nunca escreve no ADO sem ela; próxima US só é montada depois da anterior confirmada.
- **A máquina de estados para em `Refinamento Técnico`** — nunca avança para `Em Desenvolvimento`. Esse é o ponto de handoff exato para o `/pick-card`.
- **Idempotência total**: não duplica US/comentários se já existirem; só preenche lacunas.
- **MCP azure-devops é o mecanismo preferencial**; `az` CLI e REST+`$ADO_PAT` são fallback, nessa ordem. Nunca imprimir/gravar o PAT.
- **Rastreabilidade de autoria AI (SEMPRE)**: toda criação/atualização de work item e todo comentário gravado no ADO por este workflow carrega o rótulo resolvido nas Etapas 0.3–0.4 — Solicitante (usuário ADO que pediu a escrita da US), agente/CLI, modelo e data ISO da execução. "AI" sozinho, sem solicitante/agente/modelo/data, não é suficiente. O Solicitante vem **antes** do Agente no rótulo.
- **Standalone**: este comando não modifica `pick-card.md`, `dev-team.md` nem `README.md` — a integração com eles é só o handoff descrito na Etapa 4.3.
- **IDIOMA PT-BR OBRIGATÓRIO (SEMPRE)**: TODO o conteúdo gerado — `System.Title`, seção **História** da Description, `Microsoft.VSTS.Common.AcceptanceCriteria` (Gherkin em português: `Dado`/`Quando`/`Então`/`E`), Refinamento Técnico, comentários na US/Feature e mensagens de report — **DEVE ser redigido em Português do Brasil (pt-BR)**. **É terminantemente proibido** escrever títulos, histórias, Gherkin, AC, Refinamento Técnico ou comentários em inglês (ou qualquer outro idioma que não seja pt-BR), mesmo que a Feature/US de origem, o repositório ou a stack esteja em inglês. Termos técnicos consagrados em inglês (ex.: `endpoint`, `commit`, `pull request`, `deploy`, `rollback`, `middleware`, `token JWT`, `payload`, `stack trace`, `build`, `push`, `merge`, `branch`, `feature flag`) **podem** permanecer em inglês quando forem o nome canônico do conceito — o que NÃO pode é a frase/texto descritivo estar em outro idioma. Em caso de dúvida, redija em pt-BR e, se inevitável citar um termo técnico em inglês, coloque-o entre crases e justifique.
- **VERIFICAÇÃO ORTOGRÁFICA OBRIGATÓRIA (SEMPRE)**: antes de **cada** escrita no ADO (criação/atualização de US, comentário na Feature), faça uma **revisão ortográfica e gramatical completa** do conteúdo em pt-BR. Check mínimo:
  1. **Acentuação**: verificar crase (`à`/`a`), acentos agudos (`á`/`é`/`í`/`ó`/`ú`), circunflexos (`â`/`ê`/`ô`) e til (`ã`/`õ`) — erros mais comuns: `voce`→`você`, `nao`→`não`, `obrigatorio`→`obrigatório`, `manutencao`→`manutenção`, `configuracao`→`configuração`, `funcao`→`função`, `opcao`→`opção`, `sessao`→`sessão`.
  2. **Concordância** (nominal e verbal) e **regência verbal** — em especial `requer X` (sem preposição), `visar a` (com preposição), `anexar a/ao`.
  3. **Pontuação**: vírgula antes de `mas`/`porém`/`contudo`/`entretanto`/conjunções adversativas, ponto final em todas as frases da Description/AC/Refinamento.
  4. **Gherkin**: cada `Dado`/`Quando`/`Então`/`E` em pt-BR, com **Camel Case** e aspas duplas em strings literais (ex.: `Dado que estou autenticado como "admin"`).
  5. **Coerência de termos**: usar o **mesmo termo** ao longo de toda a US (não alternar `endpoint`/`ponto de extremidade`, `usuário`/`utilizador`, `requisição`/`request`).
  6. **Marcadores estruturais** da wiki preservados: `System.Title` no padrão `[PREFIXO] [FEAT|BUG|ENH] Nome`, história `"Como {papel}, quero {ação}, para {benefício}"`, seções obrigatórias da Description.
  Esta revisão é um **gate** — se encontrar erros, **corrija antes** de confirmar a criação com o usuário e antes de chamar `wit_create_work_item`/`az boards work-item create`/REST. Reaplique a revisão após qualquer ajuste solicitado na Etapa 3.1. **Nenhuma US com erro ortográfico evidente deve chegar ao ADO.**
- **Revisão ortográfica automatizada**: quando disponível, utilize a tool/CLI do editor/IDE do agente (ex.: `cspell`, `codespell`, `ltex`, corretor do LSP) sobre o texto que será gravado no ADO **antes** da confirmação da Etapa 3.1. Se nenhuma ferramenta estiver disponível, faça a revisão manualmente linha a linha.
