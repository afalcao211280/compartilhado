---
name: criar-story-devops
description: >
  Cria e amadurece work items User Story no Azure DevOps (org eveo-workspaces,
  projeto ENGSOFT) no padrão EVEO. Busca o padrão na wiki ENGSOFT em tempo de
  execução (fonte da verdade — nunca de memória), monta Description + Acceptance
  Criteria (Gherkin) + Refinamento Técnico e roda o fluxo de estados via MCP
  azure-devops. Acionar SEMPRE que pedirem: "cria uma story", "criar story no
  devops", "abre uma US", "monta a story", "refina essa story", "transforma
  isso em story".
version: "1.1.0"
category: Outras
keywords:
  - azure-devops
  - user-story
  - work-item
  - backlog
  - gherkin
  - acceptance-criteria
  - refinamento-tecnico
  - boards
---

# Criar User Story no Azure DevOps (padrão EVEO)

Transforma uma descrição curta em um work item **User Story** no padrão EVEO e o cria no Azure DevOps. O padrão (estrutura das seções, template, regras de campo, checklist, cobertura de Gherkin) vive na **wiki ENGSOFT** — esta skill define o **fluxo e a mecânica de criação**. Não duplique o padrão aqui.

## Princípios

1. **Wiki é a fonte da verdade** — busque o padrão em tempo de execução; nunca monte de memória. Mudou na wiki, muda aqui.
2. **Criação é escrita** — nunca crie direto. Monte o plano, mostre, aguarde UMA confirmação explícita.
3. **A story amadurece por estados** — nasce só com o título e ganha corpo a cada transição, não de uma vez.
4. **Herdar contexto, não inventar** — AreaPath vem do pai; vocabulário vem das stories irmãs; pergunte só o bloqueante.
5. **Sem sprint** — o time não trabalha com sprints. `IterationPath` é sempre `ENGSOFT - Engenharia de Software`.
6. **Preencher, não sobrescrever** — em story existente, só completa lacunas; campo preenchido fica intacto.

## Fonte do padrão (buscar SEMPRE)

| Onde | Valor |
|---|---|
| Organização | `https://dev.azure.com/eveo-workspaces` |
| Projeto | `ENGSOFT - Engenharia de Software` |
| Wiki | `ENGSOFT---Engenharia-de-Software.wiki` |
| Página | `/EVEO/Padrões/Criação Story` (page id 87) |

Buscar (primeira opção que funcionar):

1. **MCP azure-devops**: tool de leitura de wiki (ex.: `wiki_get_page_content` / `wiki_get_page`) com wiki e path acima.
2. **az CLI**:
   ```
   az devops wiki page show --wiki "ENGSOFT---Engenharia-de-Software.wiki" --path "/EVEO/Padrões/Criação Story" --include-content --organization https://dev.azure.com/eveo-workspaces --project "ENGSOFT - Engenharia de Software" --query "page.content" -o tsv
   ```
3. **REST** (token AAD: `az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798`):
   ```
   GET https://dev.azure.com/eveo-workspaces/ENGSOFT%20-%20Engenharia%20de%20Software/_apis/wiki/wikis/ENGSOFT---Engenharia-de-Software.wiki/pages?path=%2FEVEO%2FPadr%C3%B5es%2FCria%C3%A7%C3%A3o%20Story&includeContent=true&api-version=7.1
   ```

**Se nenhuma opção funcionar: PARE e avise o usuário.** A wiki pode ter mudado — não use um padrão lembrado.

## Fluxo (não pule etapas)

A story **não** é criada de uma vez. Nasce só com o título e amadurece por estados até `Em Desenvolvimento`, preenchendo o corpo e o Refinamento Técnico em cada etapa. O fluxo oficial e os nomes de estado vivem na wiki (seção "Fluxo de criação e transição de status") — siga-os de lá.

1. **Buscar o padrão** na wiki (acima) e seguir EXATAMENTE o que a página define: fluxo de criação e transição de status, seções obrigatórias da Description, template, regras de campo, cobertura mínima do Gherkin e o **template do campo Refinamento Técnico**.
2. **Coletar contexto.** Feature pai (ID), prefixo/tag do projeto (mesmo das stories irmãs), assignedTo, prioridade. Herde `System.AreaPath` da feature pai via `wit_get_work_item` (ler 1-2 stories irmãs ajuda a capturar o vocabulário do projeto). Para `System.IterationPath`, usar **sempre** `ENGSOFT - Engenharia de Software` (sem sprint). Pergunte SÓ o estritamente faltante e bloqueante.
3. **Montar o plano completo** (sem escrever no ADO ainda): título + `System.Description` (Markdown, 6 seções) + `Microsoft.VSTS.Common.AcceptanceCriteria` (Html) + **rascunho do Refinamento Técnico** (campo `Custom.87e468f2-38a6-4b78-a5ef-c45e4cb24048`, HTML) conforme os templates da wiki.
4. **Validar** com o "Checklist antes de salvar" da página wiki.
5. **Mostrar o plano completo** e **aguardar UMA confirmação explícita**. Aprovado, rode toda a sequência do passo 6 sem novas paradas.
6. **Executar o fluxo de status** (em ordem, cada transição via `wit_update_work_item` em `System.State`):
   1. **Criar só com o título.** `wit_create_work_item` (workItemType="User Story") com `System.Title`, `System.AreaPath` herdado da feature, `System.IterationPath="ENGSOFT - Engenharia de Software"` e `System.State="Priorizado"`. Vincular ao pai: `wit_work_items_link` (id=story, linkToId=pai, type="parent") e confirmar `System.Parent`. **Sem Description/AC/Tags ainda.**
   2. **Aguardar ~5s** — pausa deliberada para o ADO processar regras de board/coluna.
   3. **`System.State="User Story"`** e escrever o corpo: `System.Description`, `Microsoft.VSTS.Common.AcceptanceCriteria`, `System.Tags`, `Microsoft.VSTS.Common.Priority`, `Microsoft.VSTS.Common.StackRank`.
   4. **`System.State="Refinamento Técnico"`** e preencher `Custom.87e468f2-38a6-4b78-a5ef-c45e4cb24048` (HTML) com o refinamento técnico (template da wiki).
   5. **`System.State="Em Desenvolvimento"`**. Fim do fluxo.
   - Sem MCP: `az boards work-item create`/`update` ou REST para cada transição/campo.
   - Após cada transição, conferir que o `System.State` foi aceito; se rejeitar, **parar e avisar** (não pular etapa).
7. **Devolver** ID, título e URL editável do work item no ADO.

## Modo: story já existente (preencher lacunas, não sobrescrever)

Quando o usuário passar uma story **já criada** (ex.: "roda o fluxo na 2392"):

- Ler a WI (`wit_get_work_item`) e identificar campos já preenchidos vs vazios (`System.Description`, `Microsoft.VSTS.Common.AcceptanceCriteria`, `Custom.87e468f2-38a6-4b78-a5ef-c45e4cb24048`, `System.Tags`...).
- Marchar pelos estados **a partir do estado atual** até `Em Desenvolvimento` (com a pausa ~5s), mas **preencher SÓ o que está vazio**. Normalmente só falta o Refinamento Técnico.
- **Nunca** reescrever Description/AC existentes, mesmo fora do padrão. Só preencher lacunas. Se faltar algo essencial e for arriscado inferir, avisar o usuário em vez de chutar.
- Gate de confirmação continua valendo: mostrar o que vai preencher + a sequência de transições antes de escrever.

## Qualidade da story (3 C's + INVEST)

Além do template da wiki, uma boa story respeita:

- **3 C's** — *Card* (título curto no formato "Como {papel}, quero {ação}, para {benefício}"), *Conversation* (a Description detalha a intenção), *Confirmation* (Acceptance Criteria testáveis).
- **INVEST** — Independent, Negotiable, Valuable, Estimable, Small, Testable. Se a story não for pequena/testável, quebre-a antes de criar.
- **Gherkin verificável** — cada critério cita stack, classes, endpoints e tabelas reais (não genérico). Cobrir caminho feliz + validação + erro.

Detalhes e checklist em `reference/qualidade-story.md`.

## Alinhamento ADR-024 (Boards e Workflow)

Esta skill implementa o padrão EVEO real do projeto ENGSOFT. Pontos do ADR-024 que valem e onde há divergência deliberada:

- **Vale**: hierarquia Epic → Feature → Story → Task; Story sempre com Description + Acceptance Criteria; `AreaPath` e `Priority` obrigatórios; Story vinculada ao pai (Feature).
- **Divergência (deliberada, skill vence)**:
  - **Estados**: o projeto usa estados customizados (`Priorizado` → `User Story` → `Refinamento Técnico` → `Em Desenvolvimento`), não o `New → Active → Resolved → Closed` genérico do ADR. A wiki é a fonte da verdade dos estados.
  - **Sprint/Iteration**: o time **não** usa sprints; `IterationPath` é fixo `ENGSOFT - Engenharia de Software`. O ADR-024 assume sprint cadence semanal — não aplicável aqui.

## Anti-padrões

- ❌ Montar o padrão de memória em vez de buscar na wiki.
- ❌ Criar tudo de uma vez (título + corpo + estado final) sem passar pelas transições.
- ❌ Sobrescrever Description/AC de story existente.
- ❌ Story sem Acceptance Criteria ou com Gherkin genérico.
- ❌ Preencher `IterationPath` com uma sprint.
- ❌ Escrever no ADO sem confirmação explícita.

## Estilo

- Conteúdo em pt-BR; identificadores técnicos no original.
- Gherkin rico e verificável — cite stack, classes, endpoints, tabelas.
- Nunca incluir segredos/tokens reais.

## Referências (sob demanda)

- `reference/qualidade-story.md` — 3 C's, INVEST, template e checklist de story bem-formada (condensado de padrões de mercado, adaptado ao contexto EVEO).

## Cross-references

- `criar-task-devops` — quebrar a story em Tasks técnicas após `Em Desenvolvimento`.
- ADR-024 (Boards e Workflow), ADR-023 (Git — work item no commit), ADR-025 (CI/CD — build validation), ADR-027 (Testes — Test Case vinculado à Story).
