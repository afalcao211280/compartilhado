# ADR-023: Git Branching e Versionamento — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Sem padronização de branching e commits, cada projeto adota estratégias diferentes, gerando conflitos frequentes, histórico ilegível e deploys sem rastreabilidade. A padronização garante fluxo consistente, histórico legível e versionamento semântico.

## Decisão

Adotar GitFlow Adaptado como estratégia de branching, Conventional Commits como padrão de mensagens, branch naming com IDs do work item, PR templates com checklist obrigatório e SemVer para versionamento de releases.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| Branching Strategy | GitFlow Adaptado | - | Trunk-Based, GitHub Flow | Equilibra estabilidade (main) e paralelismo (feature branches) |
| Commit Pattern | Conventional Commits | 1.0+ | Semantic Release custom | Padrão de mercado, enables auto-changelog |
| Versionamento | Semantic Versioning (SemVer) | 2.0.0 | CalVer | Rastreabilidade, breaking changes claros |
| PR Review | Azure DevOps PR Policies | - | GitHub PR, GitLab MR | Integração nativa com boards e pipelines |
| Branch Protection | Azure DevOps Branch Policies | - | GitHub Rulesets | Required reviewers, build validation, merge strategy |

## Padrões Obrigatórios

### 1. Estratégia de Branching — GitFlow Adaptado

```
main ─────────────────────────────────────────────────────►
  ↑                                  ↑
  merge (hotfix)                     merge (release)
  ↑                                  ↑
hotfix/{ID}-{descricao}       release/v{MAJOR}.{MINOR}.{PATCH}
                                     ↑
develop ────────────────────────────►
  ↑
feature/{ID}-{descricao}
```

| Branch | Origem | Destino | Quem Pode Criar |
|--------|--------|---------|-----------------|
| `main` | - | - | Apenas Admins |
| `develop` | `main` | `main` | Admins |
| `release/*` | `develop` | `main` + `develop` | Tech Leads |
| `feature/*` | `develop` | `develop` | Developers |
| `hotfix/*` | `main` | `main` + `develop` | Developers |

### 2. Branch Naming

| Tipo | Padrão | Exemplo |
|------|--------|---------|
| Feature | `feature/{ID}-{descricao-curta}` | `feature/PLAT-123-add-payment-gateway` |
| Hotfix | `hotfix/{ID}-{descricao-curta}` | `hotfix/PLAT-456-fix-payment-timeout` |
| Release | `release/v{MAJOR}.{MINOR}.{PATCH}` | `release/v1.2.0` |
| Task Técnica | `task/{ID}-{descricao-curta}` | `task/PLAT-789-update-dependencies` |

### 3. Conventional Commits

```
<tipo>(<escopo>): <descrição>

[corpo opcional]

[footer opcional]
```

| Tipo | Descrição |
|------|-----------|
| `feat` | Nova funcionalidade |
| `fix` | Correção de bug |
| `docs` | Documentação |
| `style` | Formatação (não afeta lógica) |
| `refactor` | Refatoração de código |
| `test` | Adição/modificação de testes |
| `chore` | Tarefas de manutenção |
| `ci` | Alterações em pipelines |
| `build` | Alterações no build/deps |
| `perf` | Melhoria de performance |
| `revert` | Reversão de commit anterior |

**Regras:**
- Mensagem no imperativo (`add`, não `added`)
- Máximo 72 caracteres no título
- Referência ao work item: `feat(payment): add PIX support #PLAT-123`
- Breaking changes: `feat(api)!: change authentication flow`

### 4. Pull Request Template

```markdown
## Descrição
[Descrição clara da mudança]

## Tipo de Mudança
- [ ] feat: Nova funcionalidade
- [ ] fix: Correção de bug
- [ ] refactor: Refatoração
- [ ] docs: Documentação
- [ ] test: Testes
- [ ] ci: Pipeline
- [ ] breaking change: Mudança não retrocompatível

## Work Item
Relates to #{ID do Work Item}

## Checklist
- [ ] Código segue padrões do projeto
- [ ] Testes unitários adicionados/atualizados
- [ ] Testes de integração passando
- [ ] Documentação atualizada (se aplicável)
- [ ] Sem secrets ou credenciais no código
- [ ] Coverage não diminuiu
```

### 5. Regras de Aprovação

| Ambiente | Aprovadores | Mínimo |
|----------|-------------|--------|
| Feature → Develop | 1 Developer | 1 |
| Release → Main | 1 Tech Lead | 1 |
| Hotfix → Main | 1 Tech Lead | 1 |

### 6. Tags e Versionamento (SemVer)

```
v{MAJOR}.{MINOR}.{PATCH}

MAJOR: breaking changes
MINOR: novas funcionalidades (backward compatible)
PATCH: correções de bugs (backward compatible)
```

- Todas as releases recebem tag: `v1.2.0`
- Hotfixes incrementam PATCH: `v1.2.1`
- Features incrementam MINOR: `v1.3.0`
- Breaking changes incrementam MAJOR: `v2.0.0`

### 7. Branch Protection Rules

| Branch | Policy |
|--------|--------|
| `main` | Require reviewers (2), build validation, no force push, no delete |
| `develop` | Require reviewers (1), build validation, no force push |
| `release/*` | Require reviewers (1 Tech Lead), build validation |

## Anti-padrões

- Commit direto em `main` ou `develop`
- Mensagens de commit vagas (`fix bug`, `update code`)
- Não referenciar work item no commit/PR
- Branch protection desabilitada
- Merge sem build validation
- Tags sem versionamento semântico
- Force push em branches protegidas
- Long-lived feature branches (>7 dias sem merge)
- Não fazer rebase antes de merge
- Deletar branches de release antes do merge completo

## Consequências

**Positivas:**
- Histórico de commits legível e rastreável
- Versionamento semântico permite automation (auto-changelog)
- Branch protection garante qualidade mínima
- PR template padroniza review
- Referência a work items no commit rastreia mudanças

**Negativas:**
- GitFlow Adaptado adiciona complexidade vs Trunk-Based
- Conventional Commits exige disciplina e hook de validação
- Branch protection pode atrasar merges urgentes

**Riscos:**
- Feature branches long-lived geram conflitos — mitigar com rebase diário
- Hotfixes em `main` requerem sync com `develop` — mitigar com cherry-pick automático

## Referências

- `exemplos/padronizacao/azure/git.md`
- Conventional Commits: https://www.conventionalcommits.org/
- Semantic Versioning: https://semver.org/
- Azure DevOps Branch Policies: https://docs.microsoft.com/pt-br/azure/devops/repos/git/branch-policies
- ADR-024 (Boards) — work items referenciados nos commits
- ADR-025 (CI/CD) — build validation em PR