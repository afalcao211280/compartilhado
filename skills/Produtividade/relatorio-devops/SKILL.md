---
name: relatorio-devops
description: >
  Gera relatório diário de DevOps no Notion consultando Azure DevOps (User Stories
  em PRIORIZADO, REFINAMENTO TÉCNICO, EM DESENVOLVIMENTO e UAT), ordenadas por due date,
  com vencidas em tabela separada e gráfico de status. Use quando o usuário pedir
  "relatório devops", "relatório diário", "status das minhas stories" ou "gerar relatório".
user-invocable: true
---

# relatorio-devops

Gera um relatório diário de DevOps no Notion a partir das User Stories do Azure DevOps.

## O que faz

1. Consulta o Azure DevOps via WIQL por User Stories atribuídas ao usuário atual nos estados:
   - PRIORIZADO
   - REFINAMENTO TÉCNICO
   - EM DESENVOLVIMENTO
   - UAT

2. Ordena por due date (mais perto de vencer primeiro)

3. Marca em vermelho as que faltam ≤3 dias para vencer

4. Move vencidas para tabela separada (mais tempo vencida primeiro)

5. Gera gráfico de status (vencido / ≤3 dias / saudável)

6. Cria ou atualiza página "Relatório Diário Devops" no Notion (sob "Daily Eveo")

## Execução

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\deveo\engsoft-stack-devops-ai\ai-hardness\skills\relatorio-devops\relatorio-devops.ps1"
```

### Parâmetros

| Parâmetro | Obrigatório | Descrição |
|-----------|-------------|-----------|
| `-NotionPageId` | Não | ID da página pai no Notion (auto-descoberto se omitido) |
| `-Force` | Não | Recria a página mesmo se já existir |

### Agendamento

Há uma Scheduled Task do Windows (`RelatorioDevops`) que roda automaticamente ao fazer login:
- Só executa em dias úteis (segunda a sexta)
- Roda uma única vez por dia (na primeira vez que o usuário loga)
- Cria/atualiza a página no Notion automaticamente

## Requisitos

- **Azure DevOps PAT**: env var `AZURE_DEVOPS_EXT_PAT` (ou `AZURE_DEVOPS_PAT` / `ADO_PAT`)
- **Notion PAT**: env var `NOTION_PAT` (ou `NOTION_API`)
- **Página "Daily Eveo"** deve existir no workspace do Notion

## Estrutura no Notion

```
Daily Eveo (página pai)
  |- Relatório Diário Devops - DD/MM/YYYY (child page)
       |- Relatório Diário Devops (heading 1)
       |- Resumo: X ativas | Y vencidas
       |- Status dos Work Items (gráfico text-based)
       |- Work Items Ativos (tabela ordenada por due date)
       |    |- [ID] Título | Estado | Due Date | Dias
       |    |- itens em vermelho se ≤3 dias
       |- Work Items Vencidos (tabela, mais vencida primeiro)
            |- [ID] Título | Estado | Due Date | Dias vencido
```
