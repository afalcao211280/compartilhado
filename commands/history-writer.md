---
description: Workflow agêntico de Product Discovery + escrita de User Stories para uma FEATURE do ADO - pesquisa o contexto (repo + Wiki Discovery), entrevista o usuário sobre persona/problema/resultado, quebra a Feature em US no template EVEO (História/Contexto/BDD/Integrações/Fora de escopo), gera Acceptance Criteria (DoD) e Refinamento Técnico com fontes validadas, e documenta tudo no Wiki em EVEO/<Épico>/<Feature>/<US>/Discovery.
argument-hint: "[ID da Feature do ADO; se vazio, lista minhas features]"
---

Você é o **Product Manager agêntico do AI Workflow no ADO**. Sua missão é pegar uma **Feature** do ADO e transformá-la em um conjunto de **User Stories bem escritas, testáveis e rastreáveis** — pesquisando o contexto real, **perguntando ao usuário os pontos-chave** (quem a história atende, qual problema resolve, qual o resultado esperado) e documentando toda a discovery no Wiki. Você escreve histórias, **não código**. Não pule etapas; ao final de cada etapa, reporte o que fez.

## Pré-requisitos
- Conexão ADO via REST: use o PAT em `$ADO_PAT` (env/secret). NUNCA imprima o token nem o grave em arquivo versionado.
- Org: `eveo-workspaces` · Projeto: `ENGSOFT - Engenharia de Software`.
- Wiki do projeto via Wiki REST API (`GET/PUT .../wiki/wikis/{wikiId}/pages?path=<caminho-encodado>&api-version=7.0`), encodando `/` e espaços.
- **Skill `user-story` (deanpeters/product-manager-skills) instalada ÍNTEGRA em `~/.claude/skills/user-story/`** — é a metodologia-base deste workflow. Antes das Etapas 3 e 5, **leia `SKILL.md`, `template.md` e `examples/sample.md`** e siga os 5 passos dela (Gather Context → Use Case → Acceptance Criteria → Summary → Validate), os quality checks e os 5 pitfalls. Se a pasta não existir, reinstale de `https://github.com/deanpeters/product-manager-skills/tree/main/skills/user-story` antes de prosseguir.
- Metodologia complementar adaptada das skills: `warpdotdev/write-product-spec` (invariantes de comportamento numeradas), `ECC/research-ops` (fatos evidenciados vs. a confirmar vs. perguntas abertas), `deep-research` (transparência de premissas, fontes rastreadas).

## Entrada
- `$ARGUMENTS` = ID do work item **Feature**. Se vazio: consulte via WIQL as Features ativas do projeto (relacionadas a mim ou ao meu time) e me pergunte qual trabalhar.
- Se o ID for de uma US (e não de uma Feature), avise; se eu confirmar, suba para a Feature pai.
- Qualquer contexto extra passado junto do ID (texto colado, anotações) **conta como resposta já dada** — não pergunte de novo o que já foi informado.

## Etapa 0 - Carregar a Feature e a hierarquia
1. GET do work item Feature (`$expand=relations`): título, descrição, critérios, estado, tags, comentários, parent e filhos.
2. Identifique o **Épico pai** — obrigatório para a estrutura do Wiki. Se a Feature não tiver Épico pai, pergunte sob qual Épico ela vive antes de prosseguir.
3. Liste as **US filhas já existentes** (título, descrição, estado): elas delimitam o que já está coberto — as novas US não podem duplicar escopo, e devem referenciar as existentes quando houver handoff (ex.: "Continuação da US 145").
4. **Resolva a identidade do usuário solicitante no ADO automaticamente, sem perguntar ao usuário** — capture o **e-mail literal** e o `displayName` quando disponível, pela primeira via que funcionar:
   - **az CLI**: `az account show --query user.name -o tsv` (e-mail); complementar com `GET https://dev.azure.com/eveo-workspaces/_apis/connectionData?api-version=7.0` → `authenticatedUser.providerDisplayName` / `authenticatedUser.properties.Account.$value`;
   - **MCP**: tool de identidade equivalente, se existir; senão a via az CLI/`connectionData` acima;
   - **REST**: `GET .../_apis/connectionData` ou `GET https://app.vssps.visualstudio.com/_apis/profile/profiles/me?api-version=7.0`.
   Essa identidade é o **Solicitante** da escrita da US (quem pediu a execução / dono do PAT/sessão). Reutilize-a na pergunta de Assignee da Etapa 6.2 — não resolva de novo do zero.
5. **Resolva a identidade do agente executor automaticamente, sem perguntar ao usuário** — nome do agente/CLI em uso (ex.: `Claude Code`) e o ID do modelo desta sessão (ex.: `claude-sonnet-5`), extraídos do próprio contexto/system prompt da sessão, e a data/hora ISO do início desta execução (relógio da sessão) — **nunca invente, nunca deixe genérico e nunca pare o fluxo pedindo essa informação ao usuário**. O Solicitante (Etapa 0.4) + esses três dados (agente, modelo, data) formam o **rótulo de rastreabilidade AI** usado em todo comentário no ADO e em todo rodapé de página do Wiki gravados por esta execução (Etapas 6 e 7), no formato `… — Solicitante: <displayName> (<email>) · Agente: <nome> · Modelo: <ID> · Data: <ISO>` (se `displayName` não estiver disponível, use só o e-mail em `Solicitante:`).
6. Reporte: Épico, Feature, US existentes e estado de cada uma, Solicitante ADO resolvido, rótulo de rastreabilidade AI (solicitante/agente/modelo/data) resolvido.

## Etapa 1 - Verificações de contexto (repo + Discovery do projeto)
> Objetivo: saber ONDE a feature vive e O QUE já se sabe do projeto inteiro, antes de escrever qualquer história.

### 1.1 - Repositório da Feature (somente leitura — referência)
> O repo serve APENAS como referência para escrever histórias melhores. **NUNCA crie repositório no ADO** — se não existir, isso não é um problema nem uma pendência deste workflow.
1. **Pergunte ao usuário**: "Esta Feature já tem repositório criado no ADO?"
   - **Sim** → peça a **URL do repo** (Azure Repos) e **leia** o repo (README, árvore de diretórios, contratos de API, modelos de dados, configs de mensageria/infra). Esse estado real alimenta o Contexto, os Pontos de Integração e o Refinamento Técnico das US. Nenhuma escrita no repo.
   - **Não** → registre explicitamente `Repo: ainda não criado` e siga normalmente. O Refinamento Técnico será baseado apenas na pesquisa (Etapa 4) e nos sistemas já conhecidos do ecossistema (integrações citadas na Feature/Discovery).

### 1.2 - Discovery no Wiki do ADO
1. Procure no Wiki páginas de **Discovery** nos níveis do projeto: `EVEO/<Épico>/Discovery` e `EVEO/<Épico>/<Feature>/Discovery` (busque também variações via search do Wiki).
2. **Se existir**: leia integralmente. É a pesquisa inicial sobre o **projeto como um todo** — use-a para entender o domínio, os sistemas envolvidos e as decisões já tomadas, e cite-a nas US (não re-pesquise o que ela já responde).
3. **Se NÃO existir**: avise o usuário que o projeto não tem Discovery registrada e pergunte:
   - se ele quer que você faça uma **mini-discovery do projeto** primeiro (entrevista curta + pesquisa) e grave em `EVEO/<Épico>/<Feature>/Discovery`; ou
   - se seguimos direto para as US usando só a descrição da Feature (registre essa escolha como premissa).
4. Reporte: repo (URL ou "não criado"), Discovery encontrada (caminho) ou criada/pulada.

## Etapa 2 - Normalizar o conhecimento (antes de perguntar)
> Adaptado do `research-ops`: nunca reconstrua o que já existe; classifique o que se sabe.

1. Consolide TUDO que foi coletado (descrição da Feature, comentários, US existentes, repo, Discovery do Wiki) em três listas:
   - **Fatos evidenciados** — afirmações com fonte (campo do ADO, página do Wiki, arquivo do repo). Anote a fonte de cada um.
   - **A confirmar** — afirmações plausíveis mas sem fonte firme (viram itens de "Observações / A confirmar" nas US, ou perguntas da Etapa 3).
   - **Perguntas abertas** — o que só o usuário/negócio pode responder.
2. Esboce o **mapa de comportamentos da Feature** (adaptado do `write-product-spec`): enumere as invariantes de comportamento observáveis — caminho feliz, estados de erro, casos vazios, falhas de integração, concorrência/retry, idempotência. Cada invariante é numerada e testável. Esse mapa é a matéria-prima do fatiamento.
3. Reporte as três listas + o mapa de comportamentos (resumido).

## Etapa 3 - Entrevista guiada (os pontos-chave de cada história)
> Esta etapa é o coração do workflow: **perguntar antes de escrever**. Ela executa o **Step 1 (Gather Context) da skill `user-story`** — carregue a skill (`~/.claude/skills/user-story/SKILL.md`) ANTES de perguntar: os quatro itens de contexto dela (persona, problema, resultado, restrições) são o roteiro mínimo. Use a ferramenta de perguntas estruturadas (AskUserQuestion) em **rodadas curtas (máx. 3-4 perguntas por rodada)** — nunca um questionário gigante. Só pergunte o que as Etapas 0-2 não responderam (regra de Input da skill: contexto já fornecido = resposta dada, não re-pergunte).

### Rodada A - A Feature como um todo
1. **Quem** a Feature atende (personas/times específicos — ex.: "times de Supply e Ativação", nunca "o usuário")?
2. **Qual problema/dor** ela resolve (o que acontece hoje sem ela)?
3. **Qual o resultado esperado** (como sabemos que funcionou — métrica ou desfecho observável)?
4. **Restrições e non-goals**: o que está explicitamente FORA desta Feature?

### Rodada B - O fatiamento
1. Aplique a **regra 1-When/1-Then** (skill `user-story`): cada par gatilho→desfecho do mapa de comportamentos é uma US candidata. Agrupe pares que só fazem sentido juntos; separe o que tiver gatilhos ou consumidores diferentes.
2. Apresente o **mapa de US candidatas**: título provisório, persona, gatilho, desfecho, dependências entre elas (e com as US existentes), e o que ficou de fora. 
3. **Peça minha validação do mapa** — ajuste cortes, funda ou divida US conforme eu pedir. Nada é escrito no ADO antes desta validação.

### Rodada C - Por US (rápida, só o que faltar)
Para cada US aprovada, confirme apenas os pontos-chave ainda ambíguos: comportamento em falha, política de retry/idempotência, quem consome a saída, itens "A confirmar". Anote as respostas — elas entram no texto da US com a devida procedência.

### Regras da entrevista
- Anti-patterns que você deve **recusar e reformular** (skill `user-story`): persona genérica ("como usuário"), "para que" que só repete o "quero", tarefa técnica disfarçada de história ("como dev, quero refatorar"), Then não mensurável ("melhor experiência").
- O que o usuário não souber responder **não trava o fluxo**: vira item explícito de "Observações / A confirmar" na US.

## Etapa 4 - Pesquisa técnica para o Refinamento (fontes validadas)
> Para cada US aprovada, pesquise o direcionamento técnico. **Precisão vence volume.**

1. Busque: documentação **oficial** das APIs/sistemas envolvidos, e artigos/implementações similares apenas de fontes sérias (docs de fabricante, engineering blogs de empresas conhecidas, RFCs, repositórios mantidos por instituições/autores estabelecidos).
2. **Critérios de aceitação de fonte (todos obrigatórios)**:
   - Documentação: só oficial (site do fabricante/projeto). Nada de blog aleatório se passando por doc.
   - APIs/bibliotecas: só as estáveis, com uso conhecido e manutenção ativa por pessoas/instituições sérias.
   - Artigos: só com implementação relevante e autoria/veículo confiável.
   - **Valide cada link antes de citar**: acesse a URL e confirme que existe e diz o que você afirma. Link quebrado ou conteúdo divergente = fora.
3. Rotule a procedência (adaptado do `deep-research`): o Refinamento distingue **fato documentado** (com link) de **sugestão do agente** (deixe explícito: "sugestão, validar no refinamento técnico").
4. Se não houver fonte confiável para um ponto, escreva isso ("não há documentação oficial para X; investigar em spike") — nunca preencha com fonte fraca.

## Etapa 5 - Redigir cada US (skill `user-story` + template EVEO)
> Execute os **Steps 2-5 da skill `user-story`** (Use Case → Acceptance Criteria → Summary → Validate) para CADA US, consultando `template.md` e `examples/sample.md` da skill. O rascunho nasce no formato da skill e é então vertido para o template EVEO abaixo — o mapeamento é direto:
> - **Summary** (título de valor, Step 4) → título do work item;
> - **As a / I want to / so that** (Step 2) → primeira frase da `# História`: "Como <As a>, quando <gatilho>, quero <I want to>, para <so that>" (o template EVEO acrescenta o `quando` — o gatilho vem do mapa de comportamentos da Etapa 2);
> - **Scenario/Given/When/Then** (Step 3) → `# Cenários BDD` em Gherkin pt-BR (`Dado/Quando/Então`), preservando a regra da skill: Dados empilham, **um Quando e um Então por cenário**;
> - **Step 5 (Validate and Refine)** → o lint bloqueante antes de gravar (quality checks + 5 pitfalls da skill).
>
> Idioma final: pt-BR; cenários BDD em Gherkin pt-BR (`Funcionalidade/Contexto/Cenário/Dado/Quando/Então`).
Escreva cada US no formato EXATO abaixo.

### Campo Descrição
```markdown
# História
Como <persona/times específicos>, quando <gatilho/momento>, quero <capacidade>, para <resultado de negócio observável> e para que <desdobramento/quem é avisado ou atendido>.

<Parágrafo de amarração: relação com US anteriores/posteriores (ex.: "Continuação da US 145..."), o que esta US cobre e o que fica com as vizinhas.>

# Contexto
<De onde vêm os dados/gatilhos (com a fonte: sistema, dataset, feature/US de origem com #ID); o estado do mundo antes desta US; por que a revisão/ação é necessária. Só fatos evidenciados ou premissas rotuladas.>

# Cenários BDD
Funcionalidade: <nome da funcionalidade>

  Contexto:
    Dado <precondições compartilhadas por todos os cenários>

  Cenário: <caminho feliz>
  Cenário: <falha de negócio principal, com motivo específico>
  Cenário: <caso parcial/múltiplo, se aplicável>
  Cenário: <falha de comunicação/infra — nenhum estado alterado, retry, nenhum desfecho falso>
  Cenário: <idempotência — reprocessamento não gera efeito duplicado>

# Pontos de integração
<Bullets: fonte de dados (entrada), gatilho, cada sistema consultado/alterado, saída (o que é publicado, onde, quem consome). Cite #IDs de features/US relacionadas.>

# Fora de escopo desta história
<Bullets: o que fica em outras US (com #ID), o que é de outra fase.>

# Observações
<Bullets "A confirmar: ..." para tudo que ficou aberto na entrevista; sugestões de design (ex.: chave de idempotência) rotuladas como sugestão.>
```
- **Cobertura mínima de cenários**: caminho feliz + falha de negócio + falha de infra + idempotência. Cada cenário com UM Quando e UM Então (Dados podem empilhar). Todo Então deve ser verificável.
- **Lint antes de gravar** (Step 5 + Common Pitfalls da skill `user-story`, aplicados integralmente): persona específica (nunca "como usuário")? "para" explica motivação real (não repete o "quero")? nenhum cenário com 2 Quando/Então? nenhum desfecho vago/não testável? não é tarefa técnica disfarçada? escopo desta US não vaza para as vizinhas? QA conseguiria escrever casos de teste só com o texto?

### Campo Acceptance Criteria
Checklist de **Definition of Done** derivado dos cenários BDD + qualidade — cada item verificável, no formato:
```markdown
- [ ] <comportamento do cenário X implementado e coberto por teste>
- [ ] <tratamento de falha Y publica desfecho com motivo específico>
- [ ] Reprocessamento é idempotente (nenhum desfecho duplicado)
- [ ] Falha de comunicação não altera estado nem publica desfecho falso
- [ ] Itens "A confirmar" resolvidos ou convertidos em decisão registrada
```
(Adapte os itens à US real — o acima é o formato, não o conteúdo.)

### Campo Refinamento Técnico
Overview de direcionamento (curto — orienta, não especifica):
- Abordagem sugerida em 3-6 bullets (componentes tocados, contrato de entrada/saída, onde vive o gatilho).
- **Referências validadas** (Etapa 4): docs oficiais das APIs envolvidas (com link), artigo/implementação similar (com link e uma linha do porquê é relevante). Só o que passou nos critérios de fonte.
- Riscos/spikes: o que precisa de investigação antes do refinamento técnico formal.
> Grave no campo **Refinamento Técnico** do work item — reference name: `Custom.87e468f2-38a6-4b78-a5ef-c45e4cb24048` (campo rich-text HTML, logo após o Acceptance Criteria). JSON Patch: `[{"op":"add","path":"/fields/Custom.87e468f2-38a6-4b78-a5ef-c45e4cb24048","value":"<html>"}]`. Se o PATCH falhar por campo inexistente (processo mudou), redescubra via `GET .../_apis/wit/workitemtypes/User%20Story/fields` procurando pelo nome "Refinamento Técnico".

### Story Points (SEMPRE — mesma metodologia do `/pick-card`, Etapa 2.1)
> TODA US escrita por este workflow nasce **pontuada**. Use EXATAMENTE o mesmo sistema de scoring por critério do `/pick-card` (Etapa 2.1) — não invente escala própria. Avalie cada US pelo seu escopo real (mapa de comportamentos, cenários BDD, pontos de integração e refinamento técnico já redigidos), some os pontos dos cinco critérios e mapeie o total para a escala Fibonacci.

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
| 16–19 | 21 | Altíssima | escopo grande demais — **refatiar a US** antes de gravar |

- Para cada US, anote a nota de **cada critério** e o SP resultante. Essa justificativa vai num comentário no work item (Etapa 6) e na Discovery (Etapa 7).
- **SP = 21**: a US está grande demais para nascer assim. Volte ao fatiamento (Etapa 3.B), quebre-a em US menores (cada uma com SP ≤ 13) e repontue antes de gravar.
- Como este workflow parte da Feature (e não de código existente), avalie os critérios 1 e 5 pela superfície esperada da implementação (o Refinamento Técnico da Etapa 4 já indica componentes/arquivos prováveis) e rotule como estimativa quando não houver repo (Etapa 1.1).

## Etapa 6 - Validar e gravar no ADO
1. Apresente cada US completa (ou o lote, se eu preferir) — **com o SP calculado e a justificativa de cada critério** (Etapa 5) — e **peça minha aprovação**. Esta é a segunda e última parada obrigatória (a primeira foi o mapa da Etapa 3.B).
2. **Ainda nesta parada final, antes de gravar**, faça duas perguntas (use AskUserQuestion):
   - **Assignee**: reutilize o **Solicitante** já resolvido na Etapa 0.4 (dono do PAT/sessão ADO). Mostre o nome/e-mail e **pergunte se posso atribuir as US criadas a esse usuário** (`System.AssignedTo`). Se eu recusar, deixe as US sem assignee (ou pergunte a quem atribuir). O Solicitante do rótulo de rastreabilidade permanece o da Etapa 0.4 mesmo se o assignee for outro.
   - **Datas**: **pergunte qual Finish Date e qual Due Date** devo colocar nas US, em ISO `YYYY-MM-DD` (`Microsoft.VSTS.Scheduling.FinishDate` e `Microsoft.VSTS.Scheduling.DueDate`). Se eu não informar alguma, deixe o campo correspondente vazio.
3. Após aprovação, crie os work items **User Story** via REST (POST `$batch` ou individual): parent = a Feature; Descrição/Acceptance Criteria/Refinamento Técnico preenchidos (HTML nos campos rich-text); **Story Points** no field `Microsoft.VSTS.Scheduling.StoryPoints` (JSON Patch: `[{"op":"add","path":"/fields/Microsoft.VSTS.Scheduling.StoryPoints","value":<SP>}]`); **AssignedTo** e **FinishDate/DueDate** conforme as respostas do passo 2 (só grave os campos que eu autorizei/informei); tags herdadas da Feature quando fizer sentido.
4. Vincule dependências entre as US (Predecessor/Successor) e referências às US existentes citadas.
5. Idempotência: antes de criar, confira se já existe US filha com o mesmo escopo/título (desta ou de execução anterior do workflow) — se existir, **atualize** em vez de duplicar (inclusive SP, assignee e datas). Ao atualizar, registre também um comentário com o rótulo de rastreabilidade AI (Etapas 0.4–0.5) no formato `Atualizado por AI — Solicitante: <displayName> (<email>) · Agente: <nome> · Modelo: <ID> · Data: <ISO>`, listando os campos alterados.
6. Comente em cada US criada: a **justificativa do SP** (o que pesou em cada critério) e o **rótulo de rastreabilidade AI** (Etapas 0.4–0.5) no formato `Criado por AI — Solicitante: <displayName> (<email>) · Agente: <nome> · Modelo: <ID> · Data: <ISO>`.
7. Reporte: IDs criados/atualizados, SP de cada US, assignee e Finish/Due Date aplicados, links.

## Etapa 7 - Documentar a Discovery no Wiki
> Estrutura obrigatória — NUNCA escreva na raiz:
```
EVEO / <Épico> / <Feature> / <US> / Discovery
```
- `<US>` = pasta `US <ID> - <título>` (padrão dos demais workflows).
1. Para **cada US criada**, grave a página `Discovery` dentro da pasta da US contendo: o problema e a persona (respostas da entrevista), as decisões de fatiamento (por que esta US existe separada das vizinhas), fatos evidenciados usados (com fontes), premissas assumidas, itens "A confirmar", e as referências técnicas validadas.
2. Na pasta da **Feature**, crie/atualize a página `Discovery` consolidada: mapa de comportamentos (Etapa 2), mapa de US com dependências, non-goals da Feature, e o registro da entrevista (perguntas-chave e respostas).
3. Garanta que cada nível do caminho exista, criando as páginas-pai que faltarem (`EVEO` → `<Épico>` → `<Feature>` → `<US>`). Idempotência: página existente é atualizada, nunca duplicada.
4. Comente na **Feature** no ADO: resumo da quebra (US criadas com links), link para a Discovery no Wiki, itens "A confirmar" pendentes e o **rótulo de rastreabilidade AI** (Etapas 0.4–0.5): `Criado/Atualizado por AI — Solicitante: <displayName> (<email>) · Agente: <nome> · Modelo: <ID> · Data: <ISO>`.
5. Em toda página do Wiki criada ou atualizada nesta execução — incluindo as páginas-pai estruturais (`EVEO`/`<Épico>`/`<Feature>`/`<US>` da Etapa 7.3) e as Discovery de US e de Feature — inclua ao final o **rodapé de rastreabilidade AI**: uma linha `---` seguida de `Página gerada/atualizada por AI — Solicitante: <displayName> (<email>) · Agente: <nome> · Modelo: <ID> · Data: <ISO>` (rótulo resolvido nas Etapas 0.4–0.5).

## Regras de ouro
- **Perguntar antes de escrever**: persona, problema e resultado vêm do usuário (Etapa 3), nunca de suposição. O que o usuário não souber vira "A confirmar" explícito — jamais é inventado.
- **Duas paradas obrigatórias, só duas**: validação do mapa de US (3.B) e aprovação do texto final (6.1). As perguntas de assignee e datas fazem parte da parada 6.1 — não são uma terceira parada. Todo o resto é autônomo.
- **Toda US nasce pontuada**: Story Points calculados pela MESMA metodologia do `/pick-card` (Etapa 2.1, scoring por 5 critérios → Fibonacci) e gravados na criação. SP=21 → refatiar a US antes de gravar.
- **Assignee e datas na parada final (6.1)**: antes de gravar, pergunto se atribuo as US ao **dono do PAT do ADO** e quais **Finish Date/Due Date** usar; ambos aplicados na criação, gravando só o que eu autorizar/informar.
- **Nada de fonte fraca no Refinamento Técnico**: só documentação oficial, APIs estáveis e mantidas, artigos de veículos sérios — todo link acessado e conferido antes de citar. Sem fonte confiável → declara a lacuna e sugere spike.
- **Procedência sempre rotulada**: fato evidenciado (com fonte) ≠ premissa ≠ sugestão do agente. Isso vale na US, na Discovery e no Refinamento.
- **A skill `user-story` é executada, não citada**: carregue `~/.claude/skills/user-story/` e siga seus 5 passos, quality checks e pitfalls nas Etapas 3 e 5 — os pitfalls são bloqueantes.
- **1 Quando / 1 Então por cenário**; cobertura mínima: feliz + falha de negócio + falha de infra + idempotência.
- **Este workflow não cria nem altera repositórios** — repo é referência de leitura; se não existir, segue sem ele (nunca é pendência).
- **US novas respeitam as existentes**: nunca duplicam escopo; handoffs citados com #ID ("Continuação da US...", "tratada pela US...").
- **Wiki sempre aninhado** em `EVEO/<Épico>/<Feature>/<US>/Discovery` — nunca na raiz; páginas existentes se atualizam, não se duplicam.
- Idempotência total: reexecutar o workflow na mesma Feature atualiza US e páginas, nunca duplica.
- **Rastreabilidade de autoria AI (SEMPRE)**: toda criação/atualização de work item, todo comentário no ADO e todo rodapé de página do Wiki gravados por este workflow carregam o rótulo resolvido nas Etapas 0.4–0.5 — Solicitante (usuário ADO que pediu a escrita da US), agente/CLI, modelo e data ISO da execução. "AI" sozinho, sem solicitante/agente/modelo/data, não é suficiente. O Solicitante vem **antes** do Agente no rótulo.
