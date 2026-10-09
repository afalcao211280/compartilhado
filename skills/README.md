# Skills Otimizadas — EVEO

Corpus consolidado de **38 skills** de IA, governado e portável entre agentes. Resultado do cruzamento `skills/` ⨯ `skills-compare/` ⨯ `docs/adrs/` (change OpenSpec `consolidar-skills-otimizadas`).

## Governança (`_shared/`)

- `_shared/governance/schema.json` — schema do frontmatter (name, description ≤600, version semver, category, keywords ≥5, requires).
- `_shared/governance/template.md` — template de skill (progressive disclosure).
- `_shared/security/baseline.md` — baseline de segurança universal (OWASP Top 10 + SSRF/CSRF/IDOR/crypto). **Fonte única**, inlinada em cada skill via `_tools/sync_baseline.py` → `reference/security-baseline.md`.
- `_tools/sync_baseline.py` — propaga o baseline (`--check` só reporta drift).
- `_tools/validate_skill.py` — validador: `python3 _tools/validate_skill.py <skill|corpus> [corpus_root]`.
- `_consolidation-matrix.md` — decision log da consolidação por skill.

## Portabilidade multi-agente

Cada skill é **self-contained**: `SKILL.md` (entrada) + `reference/*.md` (sob demanda) + `AGENTS.md` (guia de uso). Consumível direto por Claude Code, Cursor, GitHub Copilot, Windsurf, Cline e Opencode — **sem ferramenta de geração**. Ver o `AGENTS.md` de cada skill.

O security baseline é **inlinado** em cada skill com superfície de segurança (`reference/security-baseline.md`), então copiar `<skill>/` sozinha para qualquer estrutura funciona sem depender de `../../_shared`. Fonte única: `_shared/security/baseline.md`; propagação por `_tools/sync_baseline.py`; drift detectado (WARN) pelo validador.

## Catálogo (38 skills)

### Backend (4)

| Skill | Versão | Descrição |
|---|---|---|
| [`golang-expert`](Backend/golang-expert/SKILL.md) | 2.1.0 | Engenheiro fullstack sênior especializado em Go/Golang seguindo padrões de produção EVEO (Brasil). |
| [`java-expert`](Backend/java-expert/SKILL.md) | 2.1.0 | Engenheiro sênior Java/Spring Boot (produção EVEO, Brasil). |
| [`nestjs-expert`](Backend/nestjs-expert/SKILL.md) | 2.1.1 | Engenheiro sênior NestJS/TypeScript, padrões de produção EVEO. |
| [`python-expert`](Backend/python-expert/SKILL.md) | 2.1.1 | Engenheiro sênior Python, padrões de produção EVEO. |

### Frontend (6)

| Skill | Versão | Descrição |
|---|---|---|
| [`angular-expert`](Frontend/angular-expert/SKILL.md) | 2.1.1 | Engenheiro frontend sênior especializado em Angular seguindo padrões de produção. |
| [`css-expert`](Frontend/css-expert/SKILL.md) | 2.1.0 | Especialista em CSS e design systems seguindo padrões de produção EVEO (cross-cutting, ADR-008). |
| [`nextjs-expert`](Frontend/nextjs-expert/SKILL.md) | 2.1.2 | Engenheiro fullstack sênior especializado em Next.js seguindo padrões de produção. |
| [`react-expert`](Frontend/react-expert/SKILL.md) | 2.1.2 | Engenheiro frontend sênior especializado em React seguindo padrões de produção. |
| [`typescript-expert`](Frontend/typescript-expert/SKILL.md) | 2.1.0 | Especialista em TypeScript seguindo padrões de produção EVEO (cross-cutting, ADR-008). |
| [`vue-expert`](Frontend/vue-expert/SKILL.md) | 2.1.0 | Engenheiro frontend sênior especializado em Vue 3 seguindo padrões de produção EVEO. |

### Database (4)

| Skill | Versão | Descrição |
|---|---|---|
| [`mysql-expert`](Database/mysql-expert/SKILL.md) | 2.1.0 | Especialista em MySQL/MariaDB seguindo padrões de produção EVEO. |
| [`oracle-expert`](Database/oracle-expert/SKILL.md) | 2.1.0 | Especialista em Oracle Database seguindo padrões de produção EVEO. |
| [`postgres-expert`](Database/postgres-expert/SKILL.md) | 2.1.0 | Especialista em PostgreSQL seguindo padrões de produção EVEO. |
| [`sqlserver-expert`](Database/sqlserver-expert/SKILL.md) | 2.1.2 | Especialista em SQL Server seguindo padrões de produção. |

### Service-NoSQL (5)

| Skill | Versão | Descrição |
|---|---|---|
| [`elasticsearch-expert`](Service-NoSQL/elasticsearch-expert/SKILL.md) | 2.1.0 | Especialista Elasticsearch em padrões de produção EVEO. |
| [`kafka-expert`](Service-NoSQL/kafka-expert/SKILL.md) | 2.1.0 | Especialista Apache Kafka em padrões de produção EVEO. |
| [`mongodb-expert`](Service-NoSQL/mongodb-expert/SKILL.md) | 2.1.0 | Especialista MongoDB em padrões de produção EVEO. |
| [`rabbitmq-expert`](Service-NoSQL/rabbitmq-expert/SKILL.md) | 2.1.0 | Especialista RabbitMQ (broker AMQP 0-9-1) em padrões de produção EVEO. |
| [`solr-expert`](Service-NoSQL/solr-expert/SKILL.md) | 2.1.1 | Especialista em Apache Solr seguindo padrões de produção. |

### Infra (3)

| Skill | Versão | Descrição |
|---|---|---|
| [`docker-expert`](Infra/docker-expert/SKILL.md) | 2.1.0 | Especialista em Docker e containers seguindo padrões de produção EVEO. |
| [`kubernetes-expert`](Infra/kubernetes-expert/SKILL.md) | 2.1.0 | Especialista em Kubernetes e Helm seguindo padrões de produção EVEO. |
| [`terraform-expert`](Infra/terraform-expert/SKILL.md) | 2.1.0 | Especialista em Terraform/OpenTofu (IaC) seguindo padrões de produção EVEO. |

### Cloud (4)

| Skill | Versão | Descrição |
|---|---|---|
| [`aws-expert`](Cloud/aws-expert/SKILL.md) | 2.1.0 | Especialista em AWS seguindo padrões de produção EVEO. |
| [`azure-expert`](Cloud/azure-expert/SKILL.md) | 2.1.0 | Especialista em Microsoft Azure seguindo padrões de produção EVEO. |
| [`gcp-expert`](Cloud/gcp-expert/SKILL.md) | 2.1.0 | Especialista em Google Cloud Platform seguindo padrões de produção EVEO. |
| [`netsuite-expert`](Cloud/netsuite-expert/SKILL.md) | 2.1.0 | Especialista sênior em Oracle NetSuite (ERP cloud, SuiteCloud). |

### Security (2)

| Skill | Versão | Descrição |
|---|---|---|
| [`pentest-expert`](Security/pentest-expert/SKILL.md) | 2.1.0 | Especialista em penetration testing e gestão de vulnerabilidades, padrões EVEO (ADR-020). |
| [`security-expert`](Security/security-expert/SKILL.md) | 2.1.0 | Especialista em segurança de aplicações e microserviços, padrões de produção EVEO (ADR-019). |

### DevSecOps (6)

| Skill | Versão | Descrição |
|---|---|---|
| [`bug-exterminator`](DevSecOps/bug-exterminator/SKILL.md) | 1.1.0 | Caçador sênior de BUGS SILENCIOSOS — os que passam no review e nos testes e só explodem em produção: race condition, erro engolido, leak de recurso/goroutine, nil/zero value, off-by-one. |
| [`cicd-expert`](DevSecOps/cicd-expert/SKILL.md) | 2.1.2 | Especialista em CI/CD e DevSecOps seguindo padrões de produção. |
| [`criar-story-devops`](DevSecOps/criar-story-devops/SKILL.md) | 1.1.0 | Cria e amadurece work items User Story no Azure DevOps (org eveo-workspaces, projeto ENGSOFT) no padrão EVEO. |
| [`criar-task-devops`](DevSecOps/criar-task-devops/SKILL.md) | 1.1.0 | Cria work items Task no Azure DevOps (org eveo-workspaces, projeto ENGSOFT) no padrão de refinamento técnico EVEO. |
| [`git-expert`](DevSecOps/git-expert/SKILL.md) | 2.1.1 | Especialista em Git workflow, versionamento e automação EVEO. |
| [`testing-expert`](DevSecOps/testing-expert/SKILL.md) | 2.1.0 | Engenheiro de qualidade sênior em testes automatizados de produção EVEO. |

### Crosscutting (4)

| Skill | Versão | Descrição |
|---|---|---|
| [`api-authentication`](Crosscutting/api-authentication/SKILL.md) | 1.0.0 | Autenticação e autorização de APIs EVEO: JWT (RS256), OAuth2/OIDC, API keys e sessões. |
| [`caching-strategy`](Crosscutting/caching-strategy/SKILL.md) | 1.0.0 | Estratégias de cache EVEO com Redis: cache-aside, TTL, invalidação, multi-nível e HTTP caching. |
| [`clean-architecture`](Crosscutting/clean-architecture/SKILL.md) | 1.0.0 | Princípios de Clean Architecture para desenhar sistemas manuteníveis e testáveis. |
| [`observability`](Crosscutting/observability/SKILL.md) | 1.0.0 | Observabilidade EVEO: os três pilares (logs, métricas, traces) com OpenTelemetry, Prometheus e logging estruturado. |


