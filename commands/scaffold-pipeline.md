---
description: Gera/atualiza o CI/CD Azure DevOps (azure-pipelines.yml + charts + config) de um repositório novo a partir do padrão real pipeline-templates da EVEO, cobrindo 8 stacks (Go/Python piloteados; Java/NestJS/React/Next.js/Vue/Angular como draft), valida ativamente (read-only) se Harbor/variable groups/RBAC/agent pool/branch policies já estão prontos para a pipeline rodar, e entrega os comandos az de remediação para o que faltar — não provisiona infra sozinho. Em repo já scaffolded, roda só a validação de prontidão.
argument-hint: "[caminho do repo; se vazio, usa o atual — se já tiver azure-pipelines.yml do padrão, só valida prontidão]"
---

Atue como um **Pipeline Scaffolder** para este repositório. Sua missão é gerar o CI/CD Azure DevOps de um repositório novo aplicando literalmente o padrão real `pipeline-templates` da EVEO (não o padrão genérico de mercado). Não pule etapas; ao final de cada etapa, reporte o que fez.

## Pré-requisitos
- Repositório `pipeline-templates` clonado localmente (padrão: `~/projetos/pipeline-templates`) — é a fonte real dos templates (`pr/`, `cicd/`) e do `scaffold-repo.sh`. Se não existir, pare e peça para cloná-lo (`ENGSOFT - Engenharia de Software/pipeline-templates`, org `eveo-workspaces`).
- Skill `cicd-expert` carregada — consulte a seção "EVEO — Padrão Real" (nomes de stage/job, gates, variable groups, gotchas) antes de gerar qualquer coisa.
- Acesso Azure DevOps só é necessário para os passos manuais finais (variable groups, registro de pipeline) — este command nunca executa esses comandos, apenas os gera.

## DEVE / NÃO DEVE
- VOCÊ DEVE recusar o scaffold, explicando o motivo, quando a stack detectada não for Go nem Python.
- VOCÊ DEVE avisar e pedir confirmação explícita quando o remote `origin` do repositório não for Azure DevOps (ex.: GitLab ativo com `.gitlab-ci.yml`).
- VOCÊ NÃO DEVE executar comandos `az` que criem ou alterem recursos (variable group, pipeline, branch policy) — gere-os como checklist para o usuário rodar.
- VOCÊ NÃO DEVE inventar um template para stacks não suportadas (Node/Java) — aponte a lacuna e pare.
- Caso haja dúvida sobre serviços, portas ou secrets, pergunte ao usuário antes de gerar arquivos.

## Entrada
`$ARGUMENTS` = caminho do repositório a ser scaffolded. Se vazio, usa o repositório atual. Se os serviços (nome/tipo/dockerfile) não puderem ser inferidos automaticamente, pergunte ao usuário.

## Etapa 0 — Coletar contexto
1. Confirmar que `pipeline-templates` existe localmente; se não existir, parar.
2. Reler a seção EVEO da skill `cicd-expert` (incluindo "Pré-requisitos de execução") para não reinventar convenção de nomes/gates/checagens.
3. Verificar o remote `origin` do repositório-alvo: se apontar para um host que não seja Azure DevOps e houver `.gitlab-ci.yml` (ou equivalente) ativo, avisar e pedir confirmação explícita antes de continuar.
4. Verificar se o repositório-alvo **já tem** `azure-pipelines.yml` com bloco `resources.repositories` apontando para `pipeline-templates`. Se sim: este é um repo **já scaffolded** — pular as Etapas 1-3 (não regerar nada), extrair os parâmetros (`namespace`, `imageProject`, `services`, variable groups) direto desse arquivo, e ir direto para a Etapa 4 (modo "só validar prontidão").
5. **Resolva a identidade do agente executor automaticamente, sem perguntar ao usuário** — nome do agente/CLI em uso (ex.: `Claude Code`) e o ID do modelo desta sessão (ex.: `claude-sonnet-5`), extraídos do próprio contexto/system prompt da sessão, e a data/hora ISO do início desta execução (relógio da sessão) — **nunca invente, nunca deixe genérico e nunca pare o fluxo pedindo essa informação ao usuário**. Esse rótulo (agente, modelo, data) é inserido como cabeçalho de comentário nos arquivos gerados na Etapa 3.

Reporte: repositório-alvo, remote detectado, se `pipeline-templates` foi encontrado, se o repo já está scaffolded (modo validação) ou é scaffold novo (fluxo completo), rótulo de rastreabilidade AI (agente/modelo/data) resolvido.

## Etapa 1 — Detectar stack e serviços
1. Inspecionar o repositório para detectar a stack entre as **8 suportadas** e escolher o template correspondente em `pipeline-templates/pr/`:

   | Sinal no repo | Stack | Template |
   |---|---|---|
   | `go.mod` | Go | `pr-pipeline.yml` (piloteado) |
   | `requirements.txt`/`pyproject.toml` | Python | `pr-pipeline-python.yml` (piloteado) |
   | `pom.xml` e/ou `build.gradle`/`build.gradle.kts` | Java | `pr-pipeline-java.yml` (draft) |
   | `package.json` com dep `@nestjs/core` | NestJS | `pr-pipeline-nestjs.yml` (draft) |
   | `package.json` com dep `next` | Next.js | `pr-pipeline-react-next.yml` (draft) |
   | `package.json` com dep `react` (sem `next`) | React | `pr-pipeline-react-next.yml` (draft) |
   | `package.json` com dep `vue` | Vue.js | `pr-pipeline-vue.yml` (draft) |
   | `angular.json` presente | Angular | `pr-pipeline-angular.yml` (draft) |

2. Se a stack não for nenhuma das 8 acima: **PARAR**. Informar que `pipeline-templates` ainda não tem template para essa stack e recomendar contato com o time de plataforma antes de prosseguir.
3. Se o template escolhido for um dos **draft** (Java, NestJS, React, Next.js, Vue, Angular): avisar explicitamente ao usuário que esse template ainda não foi piloteado em produção (diferente de Go/Python) e tratar o primeiro run como validação, não como certeza — confirmar que o usuário quer prosseguir mesmo assim.
4. Ambiguidade a resolver perguntando ao usuário, nunca adivinhando: Java com `pom.xml` **e** `build.gradle` ao mesmo tempo (qual `buildTool` declarar no parâmetro do template); Node com mais de um lockfile presente (`package-lock.json` + `pnpm-lock.yaml`, por exemplo).
5. Mapear serviços: nome, tipo (`http` ou `worker`), caminho do Dockerfile, chart path. Se não houver Dockerfile localizável para algum serviço, perguntar ao usuário.

Reporte: stack detectada, template escolhido, se é piloteado ou draft, lista de serviços com tipo.

## Etapa 2 — Calcular parâmetros com checklist de consistência
1. Derivar um único slug canônico do repositório (kebab-case, hífen — nunca underscore) e usá-lo como base de `namespace`, `imageProject`, `configMapName`, `secretName` e do prefixo de `secretVarGroup`. Nenhum desses campos deve divergir do slug sem justificativa explícita registrada.
2. Definir `smokeDeployment` sempre de forma explícita: primeiro serviço `http`, com fallback para o primeiro serviço de qualquer tipo — nunca deixar vazio.
3. Se algum serviço exigir secret condicional por ambiente (ex.: Redis só em uat/prd), validar que o `extends` de cada ambiente realmente aponta para o conjunto de `secretKeys` coerente com essa regra, em vez de copiar cegamente um exemplo.
4. Confirmar `kubeVarGroup` isolado por ambiente (`kube-dev`/`kube-uat`/`kube-prd`), salvo exceção que o usuário confirme explicitamente.

Reporte: tabela final de parâmetros (`namespace`, `imageProject`, `configMapName`, `secretName`, `secretVarGroup`, `kubeVarGroup` por ambiente, `smokeDeployment`) — peça confirmação do usuário antes de gerar os arquivos.

## Etapa 3 — Rodar o scaffold
1. Rodar `pipeline-templates/scaffold-repo.sh` com os parâmetros validados na Etapa 2.
2. Se a stack não for Go, editar o `azure-pipelines.yml` gerado trocando `pr/pr-pipeline.yml@templates` pelo template escolhido na Etapa 1 (o script sempre gera a variante Go por padrão, independente da stack real). Para Java, incluir o parâmetro `buildTool` (`maven`/`gradle`/`auto`) resolvido na Etapa 1.4.
3. Revisar os arquivos gerados (`azure-pipelines.yml`, `charts/<svc>/`, `config/<env>.env`, `values-<env>.yaml`) contra o checklist da Etapa 2.
4. Inserir, como comentário `#` no topo de cada arquivo gerado ou alterado nesta execução (`azure-pipelines.yml`, arquivos em `charts/<svc>/`, `config/<env>.env`, `values-<env>.yaml`), o **cabeçalho de rastreabilidade AI** resolvido na Etapa 0.5: `# Gerado por AI — Agente: <nome> · Modelo: <ID> · Data: <ISO>`. Em reexecuções sobre repositório já scaffolded (modo validação, Etapa 4), não regravar esse cabeçalho — ele só é escrito quando o arquivo é (re)gerado ou alterado por este workflow.

Reporte: lista de arquivos criados/alterados.

## Etapa 4 — Validar prontidão de execução (checagem ativa, read-only)
Objetivo: não entregar só um checklist para o humano ler — **tentar checar de fato** cada pré-requisito (ver seção "Pré-requisitos de execução" da skill `cicd-expert`), usando somente comandos de **leitura** (`list`, `get`, `show`, `curl GET`, `helm show chart`). Para cada item abaixo, o resultado é sempre um destes três estados — nunca um quarto estado implícito de "deve estar ok":
- **OK** — consultado e confirmado presente/configurado.
- **FALTA** — consultado e confirmado ausente; incluir o comando exato de criação (nunca executá-lo).
- **NÃO VERIFICÁVEL** — a sessão não tem credencial/rede/CLI para checar; dizer exatamente o que falta para checar (ex.: "sem `az login`", "sem kubeconfig de uat", "Harbor não alcançável desta rede") e pedir confirmação manual do item.

1. **Harbor**: `curl`/API do Harbor para `GET /api/v2.0/projects?name=<imageProject>` → projeto existe? `scan_on_push` habilitado? Se não verificável (sem endpoint/credencial), marcar como tal.
2. **Azure DevOps — variable groups**: `az pipelines variable-group list --group-name harbor|kube-<env>|<vg-prefix>-<env>` → grupo existe? Comparar as chaves declaradas em `secretKeys` (Etapa 2) contra `az pipelines variable-group variable list` — toda chave declarada tem valor real na variable group? (é exatamente o tipo de bug já visto: comentário promete uma coisa, `extends` usa outra, variable group não tem a chave).
3. **Azure DevOps — pipeline e políticas**: `az pipelines list` (a pipeline já foi registrada?), `az repos policy list` (branch policies de dev/uat/prd e 2-revisores em prd já configuradas?).
4. **Azure DevOps — agent pool**: `az pipelines pool list` / capacidade do `pool-build` — há agente online?
5. **Kubernetes, por ambiente (dev/uat/prd)**: `kubectl get ns <namespace> --context <ctx-do-env>` (namespace existe?), `kubectl get rolebinding cicd-deployer harbor-pull -n <namespace> --context <ctx-do-env>` (RBAC presente? sintoma se faltar: `cannot get resource "configmaps" in the namespace "<ns>"`). Ambiente sem kubeconfig disponível na sessão → **NÃO VERIFICÁVEL**, não bloqueia os demais ambientes.
6. **Aplicação**: `/healthz`/`/readyz` implementados no código (grep local); Dockerfile existe no path declarado; `helm show chart oci://<registry>/charts` do chart `common` responde.

Reporte: uma tabela com os 4 grupos acima, cada item com estado (OK/FALTA/NÃO VERIFICÁVEL) e, quando FALTA, o comando exato de remediação — nada disso é executado automaticamente pelo agente.

## Regras de ouro
- Nunca gerar `azure-pipelines.yml` para stack fora das 8 suportadas — recusar é melhor que entregar algo que não builda.
- Nunca deixar de avisar quando o template escolhido é draft (Java/NestJS/React/Next.js/Vue/Angular) — o usuário decide se prossegue sabendo que não foi piloteado, nunca por omissão.
- Nunca sobrepor a esteira de um repositório cujo CI ativo já é outro (GitLab etc.) sem confirmação explícita do usuário.
- Nunca criar ou alterar recursos Azure DevOps/Kubernetes/Harbor diretamente — apenas checagens de leitura (Etapa 4) e comandos de criação como texto (mesmo limite que o próprio `scaffold-repo.sh` já respeita).
- Nunca reportar um item como OK sem tê-lo checado de fato, e nunca tratar "não verificável" como "ok" — são estados diferentes e a diferença importa.
- Nomenclatura consistente (Etapa 2) é obrigatória, não sugestão — repos reais já quebraram por divergência de nome entre `namespace`/`imageProject`/`secretVarGroup`.
- **Rastreabilidade de autoria AI (SEMPRE)**: todo arquivo de pipeline gerado ou alterado por este workflow carrega no topo o cabeçalho `# Gerado por AI — Agente/Modelo/Data` (Etapa 0.5/3.4). Nunca gerar ou alterar arquivo de pipeline sem esse cabeçalho.
- Idioma: pt-BR em toda comunicação e relatório.
