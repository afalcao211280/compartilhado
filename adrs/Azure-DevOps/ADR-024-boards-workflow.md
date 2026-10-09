# ADR-024: Boards e Workflow — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Sem padronização de boards, cada time organiza work items de forma diferente, criando inconsistência na rastreabilidade, dificuldade de reporting e desalinhamento entre desenvolvimento e negócio. A padronização garante visibilidade, rastreabilidade e ceremonies consistentes.

## Decisão

Adotar a estrutura de work items do Azure DevOps (Epic, Feature, User Story, Bug, Task, Test Case) com nomenclatura padronizada `[PROJ]-[tipo]-[descrição]`, Kanban com colunas definidas, sprint cadence semanal, e ceremonies alinhados (Planning, Daily, Review, Retrospective).

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| Board Platform | Azure DevOps Boards | - | Jira, Trello | Integração nativa com repos, pipelines e test plans |
| Work Item Hierarchy | Epic → Feature → Story → Task/Bug | - | Flat list, Story-only | Rastreabilidade hierárquica completa |
| Sprint Cadence | Semanal | - | Bienal, Mensal | Feedback rápido, delivery contínuo |
| Process Template | Agile (customizado) | - | Scrum, CMMI | Flexibilidade do Agile com campos customizados |

## Padrões Obrigatórios

### 1. Tipos de Work Items e Hierarquia

```
Epic (Capacidade)
  └─ Feature (Funcionalidade)
       └─ User Story (PBI)
            ├─ Task (subtarefas técnicas)
            └─ Bug (defeitos encontrados)
Test Case ← associado a User Story
```

| Tipo | Descrição | Exemplo |
|------|-----------|---------|
| Epic | Grande capacidade de negócio | `[PLAT] Epic - Módulo de Checkout` |
| Feature | Funcionalidade entregável | `[PLAT] Feature - Integração com Gateway de Pagamento` |
| User Story | Incremento de valor do usuário | `Como cliente, quero pagar com PIX, para agilizar pagamento` |
| Bug | Defeito a ser corrigido | `[PLAT] Bug - Erro ao processar pagamento acima de R$10mil` |
| Task | Subtarefa técnica | `[PLAT] Task - Criar endpoint de consulta de pedido` |
| Test Case | Caso de teste automatizado | `Validar pagamento PIX com sucesso` |

### 2. Nomenclatura de Work Items

**Padrão:** `[{PROJETO}-{ID}] {Tipo} - {Descrição Curta}`

| Tipo | Padrão de Descrição |
|------|-------------------|
| Epic | `"{Capacidade/Funcionalidade}"` |
| Feature | `"Implementar {funcionalidade}"` |
| Story | `"Como {papel}, quero {ação}, para {benefício}"` |
| Task | `"{Verbo} {o que fazer}"` |
| Bug | `"Corrigir {problema} em {local}"` |

### 3. Kanban — Colunas do Board

```
Backlog → To Do → In Progress → In Review → Testing → Done
```

| Coluna | Critério de Entrada | WIP Limit |
|--------|-------------------|-----------|
| Backlog | Item criado, não priorizado | - |
| To Do | Priorizado, assignado, com acceptance criteria | - |
| In Progress | Desenvolvimento ativo | 3 por pessoa |
| In Review | PR aberto, aguardando review | 2 por pessoa |
| Testing | Em teste (unit/integration/E2E) | - |
| Done | Merge em develop/main, testes passando | - |

### 4. Swimlanes por Prioridade

| Prioridade | Critério | Cor |
|------------|----------|-----|
| P0 — Crítico | Bloqueia release, incidente em produção | Vermelho |
| P1 — Alto | Funcionalidade importante, deadline próximo | Laranja |
| P2 — Médio | Funcionalidade planejada | Amarelo |
| P3 — Baixo | Nice-to-have, sem urgência | Verde |

### 5. Campos Obrigatórios

| Campo | Obrigatório | Para |
|-------|-------------|------|
| Title | Sim | Todos |
| Description/AC | Sim | Story, Bug, Feature |
| Assigned To | Sim | Todos (exceto Epic) |
| Area Path | Sim | Todos |
| Iteration Path | Sim | Todos (exceto Backlog) |
| Priority | Sim | Todos |
| Story Points | Sim | Story, Feature |
| Severity | Sim | Bug |
| Component | Não | Recomendado |

### 6. Sprint Cadence

| Cerimônia | Frequência | Duração | Participantes |
|-----------|------------|---------|---------------|
| Planning | Semanal | 2h | Devs + PO |
| Daily | Diário | 15min | Devs |
| Review | Semanal | 1h | Devs + PO + Stakeholders |
| Retrospective | Semanal | 45min | Devs |

### 7. Workflow de States

**Story:**
```
New → Active → Resolved → Closed
                ↘ Removed
```

**Bug:**
```
New → Active → Resolved → Closed
  ↓      ↓         ↑
Proposed  Verified  ↗
```

**Regras de Transição:**
- New → Active: deve ter Assigned To e Description
- Active → Resolved: deve ter PR vinculado
- Resolved → Closed: testes passando, PO validou
- Bug Resolved → Closed: deve ter passos de reprodução verificados

### 8. Configuração de Projeto

**Areas:**
```
Plataforma Digital
├── Backend
│   ├── User Auth
│   ├── Payment
│   ├── Orders
│   └── ...
├── Frontend
│   ├── Web Portal
│   ├── Mobile
│   └── Admin
├── Infraestrutura
├── QA
└── Management
```

**Iterations (Sprints):**
```
Plataforma Digital
├── Sprint 2026-W01
├── Sprint 2026-W02
├── ...
└── Sprint 2026-W20
```

### 9. Dashboards e Queries

**Dashboards Recomendados:**
- Sprint burndown chart
- velocity (story points por sprint)
- bug trend (abertos vs fechados)
- lead time (tempo de criação até Done)

**Queries Úteis:**
- `Assigned to me` — minhas tarefas ativas
- `Open bugs by priority` — bugs abertos ordenados por severidade
- `Stale items (>7 days in progress)` — items parados
- `Items without linked PR` — items sem PR vinculado

## Anti-padrões

- Story sem acceptance criteria
- Bugs sem passos de reprodução
- Epic sem Feature filhas
- Task sem Story pai
- Work items sem Area Path ou Iteration Path
- Mover items para Done sem testes
- Sprint sem Planning
- Mais de 3 items In Progress por pessoa (WIP excessivo)
- Bugs críticos sem severity
- Não atualizar status do board
- Story_points atribuídos sem estimativa

## Consequências

**Positivas:**
- Rastreabilidade completa (Epic → Feature → Story → Task → PR → Deploy)
- Visibilidade do progresso via Kanban
- Sprint cadence garante delivery contínuo
- Nomenclatura padronizada facilita busca e reporting
- WIP limits previnem sobrecarga

**Negativas:**
- Overhead de preencher campos obrigatórios
- Cerimônias semanais consomem tempo
- Azure DevOps Boards tem customização limitada vs Jira

**Riscos:**
- WIP limits podem ser ignorados — mitigar com(board policies)
- Story points subjetivos — mitigar com Planning Poker
- Epics órfãs sem Features — mitigar com review semanal de backlog

## Referências

- `exemplos/padronizacao/azure/boards.md`
- Azure DevOps Boards: https://docs.microsoft.com/pt-br/azure/devops/boards/
- ADR-023 (Git) — work items referenciados nos commits
- ADR-025 (CI/CD) — build validation vinculado a work items
- ADR-026 (Repositórios) — estrutura de repo vinculada ao board
- ADR-027 (Testes) — Test Cases vinculados a Stories