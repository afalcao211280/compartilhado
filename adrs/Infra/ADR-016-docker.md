# ADR-016: Docker/Podman — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Padronização de build e runtime de containers para produção na EVEO. Containers são a unidade de deploy fundamental em microserviços e Kubernetes. Sem padronização, imagens vulneráveis, tamanho desnecessário e configurações inseguras tornam-se risco sistêmico.

## Decisão

Adotar Docker/Podman como runtime de container com práticas production-grade: multi-stage builds, imagens distroless/Alpine, non-root user, healthchecks obrigatórios e scanning de segurança no CI.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| Container Runtime | Docker / Podman | 24+ / 4+ | containerd (direto) | Docker é padrão de mercado; Podman é compatível e rootless |
| Build Strategy | Multi-stage builds | - | Single-stage | Reduz tamanho da imagem final em 60-80% |
| Base Image | Distroless / Alpine | - | Ubuntu/Debian full | Menor attack surface, menor tamanho |
| Registry | Azure Container Registry (ACR) | Premium | Docker Hub, GHCR | Integração nativa Azure, geo-replication, scan nativo |
| Security Scanner | Trivy | 0.50+ | Grype, Snyk Container | Open source, CI-native, CIS benchmarks |
| Image Signing | Cosign (Sigstore) | 2+ | Notary v2 | Supply chain integrity, integração com GitHub/Azure |
| Compose | Docker Compose | v3+ | v2 | v3 suporta deploy, healthchecks e resource limits |

## Padrões Obrigatórios

### Dockerfile

- Multi-stage builds SEMPRE (estágio `build` → estágio `runtime`)
- Tags específicos de base image (nunca `latest`): `golang:1.23-alpine`, `node:20-slim`
- Non-root user com uid > 10000: `USER appuser`
- `COPY --chown=appuser:appuser` para permissões corretas
- `.dockerignore` exaustivo: `node_modules`, `.git`, `*.md`, arquivos de teste, `.env`
- Ordem de layers: dependências → código fonte (maximizar cache)
- `HEALTHCHECK` obrigatório em toda imagem de produção
- Nenhum pacote desnecessário (sem `curl`, `vim`, `debug-tools` em produção)
- Proibido `sudo` em Dockerfile

### Docker Compose

- Versão v3+ obrigatória
- Healthchecks em todos os serviços
- Resource limits (CPU/memória) definidos
- Networks isoladas por contexto (frontend, backend, database)
- Variáveis sensíveis via `.env` (nunca hard-coded)
- Restart policies: `unless-stopped` para serviços críticos
- Volumes nomeados para dados persistentes

### Segurança de Container

- Distroless ou Alpine quando possível (menor attack surface)
- `readOnlyRootFilesystem: true` no Kubernetes
- Nenhum secret em imagem (usar Vault ou env injection do Kubernetes)
- Trivy scan obrigatório no CI antes do push ao registry
- Container signing com Cosign para supply chain integrity
- `CAP_DROP ALL` — dropar todas as capabilities Linux
- Seccomp profile (default Docker é aceitável; customizar se necessário)
- Network isolation com bridge networks separadas

## Estrutura de Projeto / Configuração

```
repositorio/
├── docker/
│   ├── Dockerfile
│   ├── Dockerfile.dev          # Desenvolvimento (hot-reload)
│   └── .dockerignore
├── docker-compose.yml           # Desenvolvimento local
├── docker-compose.override.yml  # Overrides locais (gitignored)
├── k8s/                         # Manifests Kubernetes
└── scripts/
    └── docker-build.sh          # Helper de build
```

### Template de Dockerfile (Multi-stage)

```dockerfile
# Build stage
FROM golang:1.23-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /bin/app ./cmd/api

# Runtime stage
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /bin/app /bin/app
USER 65532:65532
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD ["/bin/app", "--health"]
ENTRYPOINT ["/bin/app"]
```

## Anti-padrões

- Usar `latest` como tag de base image
- Rodar como root em produção
- Instalar ferramentas de debug em imagem de produção
- Usar `ADD` ao invés de `COPY` (ambiguidade de URL/extrair)
- Armazenar secrets em variáveis de ambiente do Dockerfile (`ARG` com valor sensível)
- Não definir healthcheck
- Não definir resource limits em Compose/K8s
- Imagem single-stage para produção
- Commitar `.env` com secrets reais
- Usar `sudo` em Dockerfile

## Consequências

**Positivas:**
- Imagens menores (60-80% de redução com multi-stage)
- Menor superfície de ataque (distroless/Alpine)
- Supply chain verificado (Cosign + Trivy)
- Reprodutibilidade e cache eficiente
- Healthchecks permitem auto-healing no Kubernetes

**Negativas:**
- Debug em produção requer imagem específica com tools
- Distroless dificulta `exec` no container (usar `kubectl debug` ou ephemeral container)
- Curva de aprendizado para multi-stage builds
- Multi-arch builds adicionam complexidade ao CI

**Riscos:**
- Imagem sem shell dificulta troubleshooting — mitiga-se com ephemeral containers
- Base images Alpine podem ter incompatibilidades musl vs glibc — usar `-alpine` only quando testado

## Referências

- `skills/Infra/docker-expert/SKILL.md`
- Docker Best Practices: https://docs.docker.com/develop/dev-best-practices/
- Trivy: https://aquasecurity.github.io/trivy/
- Cosign: https://github.com/sigstore/cosign
- Distroless: https://github.com/GoogleContainerTools/distroless
- ADR-017 (Kubernetes) — deploy das imagens
- ADR-018 (Terraform) — provisionamento de registry
- ADR-019 (App Security) — container security context
- ADR-022 (CI/CD) — scanning no pipeline