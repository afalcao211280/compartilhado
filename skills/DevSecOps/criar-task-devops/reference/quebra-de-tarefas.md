# Quebra de Tarefas — grafo, fatiamento vertical, sizing

Guia de apoio para transformar uma User Story em Tasks bem-dimensionadas. **O template da Task vive na wiki ENGSOFT** (`/EVEO/Padrões/Criar Task`) — este arquivo resume os critérios de decomposição, adaptados ao contexto EVEO. Em conflito, a wiki vence.

## Grafo de dependência

Mapeie o que depende do quê e construa a fundação primeiro (bottom-up):

```
Schema de banco (migration)
    ├── Models / types da API
    │       ├── Endpoints da API
    │       │       └── Cliente da API (front)
    │       │               └── Componentes de UI
    │       └── Validação
    └── Seed / migrations
```

A ordem de implementação segue o grafo de baixo para cima.

## Fatiamento vertical (não horizontal)

Cada Task deve entregar uma **fatia funcional testável de ponta a ponta**, não uma camada isolada.

**Ruim (horizontal):**
```
Task 1: Construir todo o schema
Task 2: Construir todos os endpoints
Task 3: Construir toda a UI
Task 4: Conectar tudo
```

**Bom (vertical):**
```
Task 1: Usuário cria conta (schema + endpoint + UI de cadastro)
Task 2: Usuário faz login (schema auth + endpoint + UI de login)
Task 3: Usuário cria pedido (schema + endpoint + UI)
```

Cada fatia vertical entrega funcionalidade que dá pra testar.

## Sizing

| Tamanho | Arquivos | Escopo | Exemplo |
|---|---|---|---|
| **XS** | 1 | Função ou config única | Adicionar regra de validação |
| **S** | 1-2 | Um componente ou endpoint | Novo endpoint de consulta |
| **M** | 3-5 | Uma fatia de feature | Fluxo de cadastro |
| **L** | 5-8 | Feature multi-componente | Busca com filtro e paginação |
| **XL** | 8+ | **Grande demais — quebre** | — |

O agente rende melhor em Tasks **S** e **M**. L ou maior → quebre.

**Quebre a Task quando:**
- Levaria mais de uma sessão focada (~2h+ de trabalho).
- Não dá pra descrever o critério em até 3 bullets.
- Toca 2+ subsistemas independentes (ex.: auth e billing).
- O título precisa de um "e" (sinal de que são duas Tasks).

## Ordenação e checkpoints

1. Dependências satisfeitas primeiro (fundação antes).
2. Cada Task deixa o sistema em estado funcional.
3. Tarefas de risco cedo (fail fast).
4. Checkpoint de verificação a cada 2-3 Tasks.

## Paralelização

- **Seguro paralelizar**: fatias de feature independentes, testes de feature já pronta, documentação.
- **Deve ser sequencial**: migrations de banco, mudanças de estado compartilhado, cadeias de dependência.
- **Precisa de coordenação**: features que compartilham contrato de API (defina o contrato primeiro, depois paralelize).

## Checklist antes de criar cada Task

- [ ] Título no padrão "{Verbo} {o que fazer}" (ADR-024).
- [ ] Vinculada à US/Feature pai (`Hierarchy-Reverse`).
- [ ] Objetivo verificável na Description (Task não tem AC nativo — critérios vão na Description).
- [ ] Fatia vertical, não camada horizontal.
- [ ] Tamanho S ou M (L+ → quebrar).
- [ ] Dependências identificadas (`Dependency-Forward` quando houver).
- [ ] Se for Task de teste: categoria/tag do ADR-027 na Description.
- [ ] Alinhada ao "Checklist antes de salvar" da wiki (fonte da verdade).
