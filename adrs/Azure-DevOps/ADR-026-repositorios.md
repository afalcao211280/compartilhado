# ADR-026: Repositórios — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Sem padronização de nomenclatura e estrutura de repositórios, cada projeto organiza código de forma diferente, dificultando navegação,-code ownership e governança. A padronização com prefixos por tipo e estrutura de diretórios consistente garante organização, rastreabilidade e onboarding facilitado.

## Decisão

Adotar convenção de nomenclatura com prefixos por tipo (`mib-`, `mab-`, `bff-`, `mfe-`, `fe-`, `lib-`, `infra-`, `tool-`), estrutura de projeto padronizada por tipo, Azure DevOps como plataforma de hospedagem com políticas de proteção de branch e regras de governança.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| Plataforma | Azure DevOps Repos | - | GitHub, GitLab | Integração nativa com Boards, Pipelines, Artifacts |
| Versionamento | Git | 2.x+ | SVN, Mercurial | Padrão de mercado |
| Branching | GitFlow Adaptado | - | Trunk-Based | Alinhado com ADR-023 |
| Linting por Commit | pre-commit hooks | - | Husky, lint-staged | Validação antes do push |
| Monorepo | Turborepo / Nx | - | Lerna | Monorepo apenas quando justificado (ver seção) |

## Padrões Obrigatórios

### 1. Convenção de Nomenclatura

**Padrão:** `{prefixo}-{nome-descritivo}`

| Tipo | Prefixo | Descrição | Exemplo |
|------|---------|-----------|---------|
| Backend Microservice | `mib-` | Microsserviços standalone | `mib-payment-gateway` |
| Backend Macro Service | `mab-` | Serviços monolíticos grandes | `mab-order-management` |
| BFF (Backend for Frontend) | `bff-` | APIs específicas para frontend | `bff-web-portal` |
| Micro Frontend | `mfe-` | Componentes Frontend standalone | `mfe-checkout-widget` |
| Frontend Monolítico | `fe-` | Frontends não modularizados | `fe-admin-panel` |
| Biblioteca Compartilhada | `lib-` | Código reutilizável | `lib-auth-client` |
| Infraestrutura | `infra-` | IaC, configurações de deploy | `infra-aks-cluster` |
| Ferramentas | `tool-` | Utilitários e scripts | `tool-db-migration` |

**Regras:**
- Nomes em kebab-case (minúsculas, hífens)
- Nome descritivo, nunca genérico (`mib-service` ❌ → `mib-payment-gateway` ✅)
- Sem abreviações obscuras (`mib-pgw` ❌ → `mib-payment-gateway` ✅)

### 2. Estrutura de Projeto por Tipo

**Backend (`mib-` / `mab-` / `bff-`):**
```
repositorio/
├── src/
│   ├── main/
│   │   ├── [language]/           # Código principal
│   │   └── resources/
│   └── test/
│       ├── unit/
│       └── integration/
├── docs/
│   ├── api/
│   └── architecture/
├── scripts/
├── docker/
│   └── Dockerfile
├── k8s/                          # Manifests Kubernetes
├── .github/                      # Se usar GitHub Actions
├── README.md
├── CONTRIBUTING.md
├── .gitignore
├── go.mod / pom.xml / package.json   # Dependency management
└── azure-pipelines.yml
```

**Frontend (`mfe-` / `fe-`):**
```
repositorio/
├── src/
│   ├── components/
│   ├── hooks/
│   ├── pages/
│   ├── services/
│   ├── styles/
│   └── utils/
├── public/
├── tests/
│   ├── unit/
│   └── e2e/
├── docs/
├── README.md
├── package.json
├── tsconfig.json
└── azure-pipelines.yml
```

**Biblioteca (`lib-`):**
```
repositorio/
├── src/
│   └── index.ts                  # Main export
├── tests/
├── docs/
├── README.md
├── package.json
├── tsconfig.json
└── azure-pipelines.yml
```

**Infraestrutura (`infra-`):**
```
repositorio/
├── modules/
│   ├── networking/
│   ├── aks/
│   └── sql/
├── envs/
│   ├── dev/
│   │   ├── terragrunt.hcl
│   │   └── main.tf
│   ├── staging/
│   └── prod/
├── scripts/
├── README.md
└── azure-pipelines.yml
```

### 3. Estrutura no Azure DevOps

```
Organization (Organização EVEO)
└── Project (Plataforma Digital)
    ├── Repos
    │   ├── mib-payment-gateway
    │   ├── mib-order-management
    │   ├── bff-web-portal
    │   ├── mfe-checkout-widget
    │   ├── fe-admin-panel
    │   ├── lib-auth-client
    │   ├── infra-aks-cluster
    │   └── tool-db-migration
    ├── Boards
    ├── Pipelines
    └── Artifacts
```

### 4. Políticas de Repositório

**Legibilidade e Documentação:**
- README.md obrigatório em todo repositório
- CONTRIBUTING.md com guia de contribuição
- .gitignore apropriado para a linguagem
- LICENSE definido (MIT ou комитета)

**Proteção de Código:**
- Branch protection em `main` e `develop`
- Require minimum 1 reviewer para merge
- Build validation (CI pipeline) obrigatório em PRs
- No force push em branches protegidas

**Auditoria e Compliance:**
- Audit log habilitado em todos os repositórios
- Branch policies para produção
- Reviewers obrigatórios para código sensível (infra, auth, payments)

### 5. Monorepo Strategy (Opcional)

**Quando usar monorepo:**
- Bibliotecas compartilhadas com dependência circular
- Code ownership centralizado
- Build e deploy atômicos (múltiplos pacotes versionados juntos)

**Quando NÃO usar monorepo:**
- Microsserviços independentes com deploy independente ✅ (padrão EVEO)
- Times com autonomia de deploy
- Stack tecnológica diferente entre serviços

**Ferramentas (se monorepo):**

| Ferramenta | Uso | Quando |
|-----------|-----|--------|
| Turborepo | Build caching, task pipeline | Frontend monorepo (Next.js/React) |
| Nx | Monorepo full-stack, dependency graph | Monorepo com múltiplas linguagens |
| Lerna | Versionamento independente de pacotes | Bibliotecas compartilhadas |

## Anti-padrões

- Repositórios sem README.md
- Nomes genéricos (`service-1`, `backend-app`)
- Prefixo inconsistente (sem `mib-`, `fe-`, etc.)
- Branch protection desabilitada em `main`
- Secrets hardcoded no código (usar Key Vault + Variable Groups)
- Monorepo para microsserviços independentes
- `.gitignore` vazio ou inadequado
- Binários ou dependências no repo (usar package manager)
- Repositório sem CONTRIBUTING.md
- Licença não definida
- Force push em branches protegidas

## Consequências

**Positivas:**
- Navegação intuitiva (prefixo identifica tipo imediatamente)
- Onboarding facilitado (estrutura consistente)
- Governança via branch policies
- Rastreabilidade (repo → board → pipeline → deploy)
- Code ownership claro por tipo de serviço

**Negativas:**
- Prefixos adicionam verbosidade ao nome do repo
- Múltiplos repos aumentam overhead de pipeline
- Monorepo pode ser necessário para libs compartilhadas (complexidade adicional)
- Azure DevOps Repos tem UX inferior ao GitHub

**Riscos:**
- Proliferação de repos micro (`mib-*` para cada endpoint) — mitigar com macro-service quando apropriado
- Monorepo tentação para simplificar — usar apenas quando justificado
- Branch protection muito restritivo para hotfixes — mitigar com pipeline de hotfix separado

## Referências

- `exemplos/padronizacao/azure/repositorios.md`
- Azure DevOps Repos: https://docs.microsoft.com/pt-br/azure/devops/repos/
- Turborepo: https://turbo.build/
- Nx: https://nx.dev/
- ADR-023 (Git) — branch protection e PR templates
- ADR-024 (Boards) — work items vinculados a repos
- ADR-025 (CI/CD) — pipelines vinculados a repos