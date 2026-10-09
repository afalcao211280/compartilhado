# ADR-028: Git Workflow Automation — Hooks, AI Attribution e Release

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: ADR-023 estabelece o GitFlow, branch naming, Conventional Commits e SemVer para os repositórios EVEO. Porém, sem automação local (hooks) e CI enforcement, os padrões dependem de disciplina manual e são violados com frequência. Além disso, a adoção de AI Coding Assistants (Claude Code, Cursor, OpenCode) exige rastreabilidade de código gerado por AI. E processos de release manual são propensos a erros de versão e changelog incompleto.

**Decisão**: Padronizar hooks locais via pre-commit framework, tornar obrigatória a declaração `Assisted-by` em commits com código AI-generated, adotar semantic-release ou conventional-changelog para automação de releases, e definir procedimentos claros de rollback.

> Regras de branching, naming e PR template: ver ADR-023. Este ADR cobre apenas automação, hooks e release.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa | Justificativa |
|-----------|---------|--------|-------------|---------------|
| Hook framework | pre-commit | 3.7+ | husky (apenas Node) | Language-agnostic, pinned versions, config versionada |
| Hook manager JS | husky | 9.x+ | pre-commit | Para projetos Node/TS que já usam npm |
| Commit validation | commitlint | 19.x+ | gitlint | Ecossistema maior, config JS flexível |
| Secret detection | gitleaks | 8.x+ | truffleHog | Mais rápido como hook, regras customizáveis |
| Release (full-auto) | semantic-release | 24.x+ | conventional-changelog | CI-driven, multi-ecosystem plugins |
| Release (semi-auto) | conventional-changelog | 8.x+ | semantic-release | Para projetos internos sem publicação automática |
| PR CLI | gh (GitHub CLI) / az (Azure CLI) | 2.50+ / 2.60+ | — | Criação e automação de PRs via script |

## Padrões Obrigatórios

### 1. Hooks Locais — pre-commit (obrigatório em todo repositório)

Todo repositório EVEO deve ter `.pre-commit-config.yaml` com pelo menos:

```yaml
repos:
  # Verificações gerais
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0          # Sempre pinned version — nunca "latest"
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
        args: ['--maxkb=500']
      - id: no-commit-to-branch
        args: ['--branch', 'main', '--branch', 'develop']

  # Secret detection — obrigatório
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.4
    hooks:
      - id: gitleaks

  # Commit message validation — obrigatório (stage: commit-msg)
  - repo: https://github.com/alessandrojcm/commitlint-pre-commit-hook
    rev: v9.13.0
    hooks:
      - id: commitlint
        stages: [commit-msg]
        additional_dependencies: ['@commitlint/config-conventional']
```

Hooks de lint específicos por linguagem são adicionais (Go, Python, Node). Ver `skills/DevSecOps/git-expert/reference/patterns.md`.

**Regras de hooks**:
- Toda versão de repo de hook **pinned** (sem `latest`, sem `@main`)
- Hooks devem completar em < 5 segundos (pre-commit) ou < 30 segundos (pre-push)
- `no-commit-to-branch` para `main` e `develop` é obrigatório
- `gitleaks` **não pode ser removido** — é requisito de segurança EVEO

### 2. AI Attribution — Obrigatório na EVEO

Quando o diff de um commit foi **gerado ou majoramente escrito por AI Coding Assistant**, o footer `Assisted-by:` é obrigatório.

```
# Formato obrigatório
Assisted-by: <NomeDoAssistente> <modelo>

# Exemplos
Assisted-by: Claude claude-sonnet-4-6
Assisted-by: Cursor gpt-4o
Assisted-by: OpenCode claude-opus-4-7
```

**Quando aplicar**:
- O assistente gerou a maior parte do código do arquivo
- O assistente gerou a lógica de negócio (não apenas boilerplate)
- Reviewers precisam saber que o código veio de AI

**Quando não é necessário**:
- Correções triviais de formatação / typo
- Sugestão de autocomplete de uma linha
- Documentação de código que o dev escreveu

**Por que rastrear**: auditoria de qualidade, compliance (AI-generated code em código crítico), análise de produtividade do time.

### 3. Release Automation

**Opção A — semantic-release** (projetos com CI/CD completo e publicação de artefatos):

```yaml
# .github/workflows/release.yml ou azure-pipelines.yml
- name: Release
  run: npx semantic-release
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    NPM_TOKEN: ${{ secrets.NPM_TOKEN }}   # Se npm
```

Resultado automático por push em `main`:
- Calcula próxima versão via commits
- Gera `CHANGELOG.md`
- Cria tag Git anotada
- Cria GitHub/Azure Release com release notes
- Publica artefato (npm, PyPI, Docker) se configurado

**Opção B — conventional-changelog** (projetos internos sem publicação):

```bash
# Gerar changelog manualmente antes do release
conventional-changelog -p conventionalcommits -i CHANGELOG.md -s -r 0

# Tag manual após revisão do changelog
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

**Regra de escolha**: se o projeto publica artefato (npm, Docker Hub, PyPI) → semantic-release. Se é serviço interno com deploy via pipeline sem publicação → conventional-changelog.

### 4. Rollback — Procedimentos Obrigatórios

| Situação | Comando Correto | Proibido |
|----------|----------------|----------|
| Commit local não pushado | `git reset HEAD~1 --soft` (mantém staged) | — |
| Commit pushado em branch pessoal | `git revert <hash>` | `git reset --hard` no branch compartilhado |
| Commit em develop/main | `git revert <hash>` (cria commit de reversão) | `git reset --hard` |
| Feature branch inteira | `git revert -m 1 <merge-commit-hash>` | Force push em branch protegida |
| Tag/release errado | Deletar tag local + remoto + criar nova | Reutilizar mesmo número de tag |

**Comunicação obrigatória antes de rollback em develop/main**:
1. Notificar o time no canal do projeto
2. Criar issue ou work item documentando o rollback e o motivo
3. Executar o revert com mensagem explicativa:
   ```
   revert(auth): revert "feat(auth): add OAuth2 flow" #PLAT-999
   
   Reverting due to regression in token refresh — tracked in #PLAT-1000.
   Original commit: abc1234
   ```

### 5. Branch Protection (complemento ao ADR-023)

| Policy | Configuração |
|--------|-------------|
| Build validation no PR | Obrigatório: pipeline deve passar antes do merge |
| Commitlint no CI | Validar todos os commits do PR no pipeline |
| Gitleaks no CI | Rodar gitleaks no diff do PR (além do hook local) |
| Squash merge | Preferencial para feature→develop (histórico limpo) |
| Delete branch after merge | Habilitado por padrão |

## Anti-padrões

- Hook pinned em `latest` ou `@main` — quebra ao atualizar
- `--no-verify` como hábito (bypass de hooks) — somente em emergências documentadas
- `push --force` em `main`, `develop` ou `release/*` — bloqueado por policy e proibido por segurança
- Reutilizar número de versão (re-tag `v1.2.0` após deletar) — quebra SemVer imutabilidade
- Release sem `CHANGELOG.md` atualizado
- Código AI-generated sem `Assisted-by:` footer — não rastreável
- Gitleaks removido do `.pre-commit-config.yaml` por "causar problemas" — deve ser corrigido, nunca removido
- Branches de release deletadas antes do merge completo em main E develop

## Consequências

**Positivas:**
- Commits validados automaticamente antes de entrar no repositório
- Secrets nunca chegam ao remote (gitleaks local + CI)
- Rastreabilidade de código AI-generated em todo o histórico
- Releases consistentes e automatizados com changelog completo
- Rollback sempre possível com procedimento documentado

**Negativas:**
- pre-commit adiciona ~2-5s por commit (aceitável)
- semantic-release exige disciplina total nos commits (qualquer `fix` pode gerar um release)
- AI attribution pode gerar atrito se não automatizado via hook

**Riscos:**
- Developer usa `--no-verify` para contornar hooks → CI falha e serve de safety net
- semantic-release em `develop` gera pre-releases indesejados → configurar `prerelease: true` com controle
- Rotação de secrets commitados acidentalmente tem janela de risco → gitleaks detecta antes do push

## Referências

- ADR-023: GitFlow, branching, Conventional Commits, PR template, SemVer
- ADR-021: Testing → pipeline de testes integrado ao CI de validação de PR
- ADR-022: CI/CD → pipeline que valida hooks e executa commitlint/gitleaks
- `skills/DevSecOps/git-expert/SKILL.md` — skill agentic de Git
- `skills/DevSecOps/git-expert/reference/patterns.md` — configurações completas
- `skills/DevSecOps/git-expert/reference/pr-review-checklist.md` — checklist de revisão
- pre-commit: https://pre-commit.com/
- semantic-release: https://semantic-release.gitbook.io/
- gitleaks: https://github.com/gitleaks/gitleaks
- Conventional Commits: https://www.conventionalcommits.org/
