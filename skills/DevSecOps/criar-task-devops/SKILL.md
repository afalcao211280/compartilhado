---
name: criar-task-devops
description: >
  Cria work items Task no Azure DevOps (org eveo-workspaces, projeto ENGSOFT) no
  padrão de refinamento técnico EVEO. Busca o padrão na wiki ENGSOFT em tempo de
  execução (fonte da verdade — nunca de memória), monta a Description técnica
  (HTML) e vincula à US/Feature pai via MCP azure-devops. Acionar SEMPRE que
  pedirem: "cria uma task", "criar task no devops", "abre uma task", "monta a
  task", "refina essa task", "transforma isso em task", "quebra a story em
  tasks".
version: "1.1.0"
category: Outras
keywords:
  - azure-devops
  - task
  - work-item
  - refinamento-tecnico
  - task-breakdown
  - boards
  - subtarefa
  - test-case
---

# Criar Task no Azure DevOps (padrão de refinamento EVEO)

Transforma uma descrição curta em um work item **Task** no padrão de refinamento técnico EVEO e o cria no Azure DevOps. O padrão (estrutura das seções, template HTML, regras de campo, checklist) vive na **wiki ENGSOFT** — esta skill define o **fluxo e a mecânica de criação**. Não duplique o padrão aqui.

## Princípios

1. **Wiki é a fonte da verdade** — busque o padrão em tempo de execução; nunca monte de memória.
2. **Criação é escrita** — nunca crie direto. Monte o rascunho, mostre, aguarde confirmação explícita.
3. **Task sempre tem pai** — vincule à US/Feature via `Hierarchy-Reverse`. Task órfã é anti-padrão.
4. **Description é HTML rich text** — Markdown entra literal. Critérios vão dentro da Description (Task não tem campo Acceptance Criteria nativo).
5. **Herdar contexto, não inventar** — AreaPath vem do pai; pergunte só o bloqueante.
6. **Sem sprint** — `IterationPath` é sempre `ENGSOFT - Engenharia de Software`.

## Fonte do padrão (buscar SEMPRE)

| Onde | Valor |
|---|---|
| Organização | `https://dev.azure.com/eveo-workspaces` |
| Projeto | `ENGSOFT - Engenharia de Software` |
| Wiki | `ENGSOFT---Engenharia-de-Software.wiki` |
| Página | `/EVEO/Padrões/Criar Task` (page id 89) |

Buscar (primeira opção que funcionar):

1. **MCP azure-devops**: tool de leitura de wiki (ex.: `wiki_get_page_content` / `wiki_get_page`) com wiki e path acima.
2. **az CLI**:
   ```
   az devops wiki page show --wiki "ENGSOFT---Engenharia-de-Software.wiki" --path "/EVEO/Padrões/Criar Task" --include-content --organization https://dev.azure.com/eveo-workspaces --project "ENGSOFT - Engenharia de Software" --query "page.content" -o tsv
   ```
3. **REST** (token AAD: `az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798`):
   ```
   GET https://dev.azure.com/eveo-workspaces/ENGSOFT%20-%20Engenharia%20de%20Software/_apis/wiki/wikis/ENGSOFT---Engenharia-de-Software.wiki/pages?path=%2FEVEO%2FPadr%C3%B5es%2FCriar%20Task&includeContent=true&api-version=7.1
   ```

**Se nenhuma opção funcionar: PARE e avise o usuário.** A wiki pode ter mudado — não use um padrão lembrado.

## Fluxo (não pule etapas)

1. **Buscar o padrão** na wiki (acima) e seguir EXATAMENTE o que a página define: seções obrigatórias, template HTML, regras de campo.
2. **Coletar contexto.** Objetivo, serviço/repo alvo, US/feature pai (ex.: US814), tags, ambiente. Herde `System.AreaPath` da US pai via `wit_get_work_item`. Para `System.IterationPath`, usar **sempre** `ENGSOFT - Engenharia de Software` (sem sprint). Pergunte SÓ o estritamente faltante e bloqueante.
3. **Montar** título + `System.Description` (HTML — o campo da Task é rich text, Markdown entra literal) conforme o template da wiki. Lembre: Task NÃO tem campo Acceptance Criteria nativo — critérios vão dentro da Description.
4. **Validar** com o "Checklist antes de salvar" da página wiki.
5. **Mostrar o rascunho** e **aguardar confirmação explícita** — criação é escrita, nunca crie direto.
6. **Criar e vincular** via `wit_create_work_item` (workItemType="Task"):
   - US pai como `System.LinkTypes.Hierarchy-Reverse`.
   - Dependências como `System.LinkTypes.Dependency-Forward`.
   - Sem MCP: `az boards work-item create` ou REST.
7. **Devolver** ID, título e URL do work item criado.

## Quebrar uma story em Tasks

Quando o pedido for quebrar uma US em várias Tasks (ex.: "quebra a US814 em tasks"), aplique fatiamento antes de criar cada Task:

1. **Mapear o grafo de dependência** — o que precisa existir antes do quê (schema → API → cliente → UI). Construa a fundação primeiro.
2. **Fatiar verticalmente** — cada Task entrega uma fatia funcional testável de ponta a ponta, não uma camada horizontal isolada ("toda a API", "todo o front").
3. **Dimensionar** — Task ideal cabe em uma sessão focada (S/M). Se o título pede um "e", ou toca 2+ subsistemas, ou passa de ~5 arquivos, quebre mais.
4. **Ordenar** — dependências satisfeitas primeiro; tarefas de risco cedo (fail fast); cada Task deixa o sistema funcional.
5. **Nomear** — cada Task no padrão "{Verbo} {o que fazer}" (ADR-024), com objetivo verificável na Description.

Detalhes (grafo, fatiamento vertical, sizing) em `reference/quebra-de-tarefas.md`.

## Tasks de teste (ADR-027)

Ao criar Tasks de escrita/automação de teste, alinhe ao ADR-027:

- **Categoria explícita na Description** — que nível da pirâmide a Task cobre e a tag correspondente: `@unit` (60%), `@integration` (20%), `@e2e` (10%), `@contract`, `@performance`, `@security`.
- **Estágio de execução** — indicar onde o teste roda (commit/PR, CI, staging), conforme a matriz do ADR-027.
- **Test Case** — Test Cases automatizados são associados à **User Story** pai (não à Task). A Task descreve o trabalho de implementar o teste; o resultado é reportado no Azure DevOps Test Plans.
- **Metas** — coverage ≥ 80%, zero flaky. Não criar Task de "rodar E2E em todo commit" (E2E pertence a staging).

## Anti-padrões

- ❌ Montar o padrão de memória em vez de buscar na wiki.
- ❌ Task sem pai (US/Feature).
- ❌ Description em Markdown (o campo é HTML — entra literal).
- ❌ Task grande demais (2+ subsistemas, título com "e", >5 arquivos) sem quebrar.
- ❌ Task de teste sem tag de categoria (`@unit`/`@integration`/...).
- ❌ Escrever no ADO sem confirmação explícita.

## Estilo

- Conteúdo em pt-BR; identificadores técnicos no original.
- Refinamento técnico detalhado — cite stack, serviços, endpoints, variáveis de ambiente.
- Nunca incluir segredos/tokens reais.

## Referências (sob demanda)

- `reference/quebra-de-tarefas.md` — grafo de dependência, fatiamento vertical, sizing S/M/L e checklist (condensado de padrões de task breakdown, adaptado ao contexto EVEO).

## Cross-references

- `criar-story-devops` — criar a US pai antes de quebrar em Tasks.
- ADR-024 (Boards — Task sob Story, nomenclatura "{Verbo} {o que}"), ADR-027 (Testes — categorias/tags, Test Case na Story), ADR-023 (Git — work item no commit), ADR-025 (CI/CD — build validation).
