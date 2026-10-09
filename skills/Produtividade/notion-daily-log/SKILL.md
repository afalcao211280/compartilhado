---
description: Registra tarefas concluidas na pagina Daily do Notion automaticamente. Cria sub-pagina para a proxima daily (proximo dia util) se nao existir, verifica conteudo atual para nao duplicar, filtra ruido (updates de tools, installs, config meta) e agrupa tarefas relacionadas sob um topico. Use SEMPRE que terminar uma tarefa significativa.
---

# notion-daily-log

Esta skill faz logging automatico de tarefas concluidas no Notion. Toda vez que uma IA termina uma tarefa significativa, ela registra na pagina Daily correspondente ao proximo dia util.

## Quando usar

- Ao terminar uma tarefa **produtiva e significativa** (bug fix, feature, refactor, PR, story/task no ADO, etc)
- Ao completar uma solicitacao do usuario que entrega valor
- NAO usar para tarefas triviais nem de manutencao de tooling

## O que NAO logar (filtro automatico)

O script filtra automaticamente estes padroes (use `-Force` só se precisar registrar algo filtrado):

- **Updates/instalacoes**: "update grok", "update cli", "update cursor", "install", "instalacao"
- **Meta-config do proprio Notion**: "notion-daily-log hook", "notion-daily-log config", "auto-load SessionStart"
- **Config/ hooks internos**: "hook activate", "hook config", "agents.md atualizado", "config.toml atualizado", "settings.json atualizado", "statusline config", "agentic config"
- **Broadcast/skills internas**: "broadcast-skills", "skill instalada", "reload skills", "recarregar skills"
- **Diagnostics/testes do proprio logging**: "verificar task", "verificar broadcast", "diagnostico notion", "teste notion log"
- **Setup generico**: "setup inicial", "configuracao inicial", "completar config"

## Como funciona

1. **Filtro de ruido**: rejeita tarefas que parecem meta-config/manutencao de tooling
2. O script PowerShell encontra a pagina "Daily" no workspace do Notion
3. Calcula o proximo dia util (segunda a sexta)
4. Verifica se ja existe sub-pagina "Daily DD/MM/YYYY" para esse dia
5. Se nao existir, cria a sub-pagina com estrutura (titulo, data, secao de tarefas)
6. Le o conteudo atual para nao duplicar tarefas
7. **Agrupamento por topico**: se `-Topic` for fornecido, agrupa a tarefa sob um heading h3 com o nome do topico
8. Adiciona a tarefa como bullet item com timestamp e nome da IA

## Execucao

Apos concluir uma tarefa significativa, execute:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\notion-daily-log\notion-daily-log.ps1" -Task "Descricao curta da tarefa" -AiName "NomeDaIA" -Detail "Detalhe opcional"
```

### Parametros

| Parametro | Obrigatorio | Descricao |
|-----------|-------------|-----------|
| `-Task` | Sim | Descricao curta da tarefa concluida |
| `-AiName` | Nao | Nome da IA (default: "AI") |
| `-Detail` | Nao | Detalhe adicional, contexto, arquivos alterados |
| `-Topic` | Nao | Topico para agrupar tarefas relacionadas (ex: "US-4040 normalizar pontuacao") |
| `-Force` | Nao | Ignora o filtro de ruido (use só para tarefas de config que precisem ser registradas) |
| `-Token` | Nao | Token do Notion (default: env var NOTION_PAT ou NOTION_API) |
| `-DailyPageId` | Nao | ID da pagina Daily (auto-descoberto se omitido) |

### Quando usar -Topic (merge de tarefas relacionadas)

Quando voce faz trabalho multi-step relacionado ao mesmo assunto (investigacao + fix + PR + story), use `-Topic` para agrupar tudo sob um heading na daily:

```powershell
# Passo 1: investigou o problema
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\notion-daily-log\notion-daily-log.ps1" -Task "Investigou erro proposta HubSpot VIP" -AiName "Cursor" -Topic "VIP normalizar pontuacao" -Detail "Falso positivo: razao social divergente"

# Passo 2: corrigiu
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\notion-daily-log\notion-daily-log.ps1" -Task "Fix normalizar pontuacao + PR DevOps" -AiName "Cursor" -Topic "VIP normalizar pontuacao"

# Passo 3: criou story no ADO
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\notion-daily-log\notion-daily-log.ps1" -Task "US 4040 generate-card + pick-card" -AiName "Cursor" -Topic "VIP normalizar pontuacao"
```

Resultado no Notion:
```
### VIP normalizar pontuacao
- [14:32] [Cursor] Investigou erro proposta HubSpot VIP - Falso positivo...
- [14:53] [Cursor] Fix normalizar pontuacao + PR DevOps
- [15:59] [Cursor] US 4040 generate-card + pick-card
```

### Exemplos

```powershell
# Log simples
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\notion-daily-log\notion-daily-log.ps1" -Task "Refatorado modulo de autenticacao" -AiName "Claude"

# Log com detalhe e topico
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\notion-daily-log\notion-daily-log.ps1" -Task "Corrigido bug #1234" -AiName "Crush" -Topic "bug-1234 envelope duplicado" -Detail "Lock por ticket no Orquestrador"

# Forcar log de algo que o filtro rejeitaria
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\notion-daily-log\notion-daily-log.ps1" -Task "Configurando MCP server novo" -AiName "Claude" -Force
```

## Alternativa via MCP Notion

Se a IA tiver o MCP `notion` conectado, pode usar as tools do MCP diretamente:

1. `search` com query "Daily" para encontrar a pagina pai
2. `get-block-children` na pagina Daily para ver se a sub-pagina do dia ja existe
3. `post-page` para criar a sub-pagina se necessario
4. `patch-block-children` para adicionar o bullet item da tarefa

O script PowerShell e a via preferencial por ser mais simples e robusta.

## Estrutura no Notion

```
Daily (pagina pai no workspace)
  |- Daily 14/07/2026 (child page)
  |    |- Daily - Daily 14/07/2026 (heading 1)
  |    |- Data: 2026-07-14 (paragraph)
  |    |- Tarefas Concluidas (heading 2)
  |    |- ### VIP normalizar pontuacao (heading 3 — topico)
  |    |    |- [14:32] [Cursor] Investigou erro proposta HubSpot VIP (bullet)
  |    |    |- [14:53] [Cursor] Fix normalizar pontuacao + PR DevOps (bullet)
  |    |    |- [15:59] [Cursor] US 4040 generate-card + pick-card (bullet)
  |    |- [16:57] [Cursor] Fix govulncheck Go 1.26.5 (bullet sem topico)
  |- Daily 15/07/2026 (child page)
       |- ...
```

## Configuracao

- **Env vars necessarias**: `NOTION_PAT` (preferencial) ou `NOTION_API` (fallback)
- **MCP server**: `@notionhq/notion-mcp-server` configurado com `NOTION_TOKEN`
- **Pagina Daily**: deve existir no workspace do Notion (auto-descoberta via search)
