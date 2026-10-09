# ADR-017: Kubernetes/Helm — Decisões de Stack e Padrões

**Status**: Aceito
**Data**: 2026-05-17
**Contexto**: Kubernetes é a plataforma de orquestração de containers para todos os microserviços EVEO. Sem padronização, manifestos inconsistentes, falta de probes, recursos sem limites e configurações inseguras comprometem disponibilidade e segurança.

## Decisão

Adotar Kubernetes 1.28+ com Helm 3 como gerenciador de packages, ArgoCD para GitOps, e práticas de production-grade: probes obrigatórios, resource limits, NetworkPolicies default-deny, RBAC least-privilege e PodDisruptionBudgets para deployments críticos.

## Stack Canônica

| Categoria | Escolha | Versão | Alternativa Considerada | Justificativa |
|---|---|---|---|---|
| Orquestração | Kubernetes | 1.28+ | Docker Swarm, Nomad | Padrão de mercado, ecossistema maduro |
| Package Manager | Helm | 3.x | Kustomize (fixo), Carvel | Helm 3 remove Tiller, charts reutilizáveis |
| Kustomize | Kustomize | integrado kubectl | Helm alone | Overlays por ambiente, complementa Helm |
| GitOps | ArgoCD | 2.9+ | Flux v2 | UI madura, sync waves, rollback visual |
| Service Mesh | Istio / Linkerd | 1.20+ / 2.14+ | Consul Connect | Istio para casos complexos, Linkerd para simples |
| Monitoring | Prometheus + Grafana | 2.50+ / 10+ | Datadog, New Relic | Open source, integração nativa K8s |
| Ingress | NGINX Ingress Controller | 1.9+ | Traefik, Kong | Padrão de mercado, documentação ampla |
| Secret Management | External Secrets Operator / Sealed Secrets | 0.9+ / 0.24+ | Vault Injector | ESO integra com Azure Key Vault nativamente |
| Policy Engine | OPA Gatekeeper / Kyverno | 3.14+ / 1.11+ | PodSecurityPolicy (deprecated) | Kyverno: policy as K8s resource; OPA: Rego poderoso |
| Image Scanning Admission | Kyverno / OPA | 1.11+ / 3.14+ | Gatekeeper only | Validar images antes do deploy |

## Padrões Obrigatórios

### Manifests

- `readinessProbe` + `livenessProbe` + `startupProbe` obrigatórios
- Resource `requests` + `limits` sempre (CPU e memória)
- Labels padronizados: `app`, `version`, `team`, `env`
- Annotations para rollout: `argocd.argoproj.io/sync-wave`
- Anti-affinity para HA (`preferredDuringScheduling`)
- PDB (PodDisruptionBudget) para deployments críticos
- NetworkPolicies default deny egress/ingress

### Helm

- Helm 3 obrigatório (sem Tiller)
- Charts versionados com semver
- Values separados por ambiente (`values-dev.yaml`, `values-prod.yaml`)
- Schema validation (`values.schema.json`) obrigatório
- Charts reutilizáveis (um por serviço genérico, não por instância)
- `.helmignore` exaustivo

### Segurança

- RBAC least privilege (nunca `cluster-admin`)
- ServiceAccount por app (nunca `default`)
- Pod Security Standards (`restricted` profile)
- Container Security Context: `runAsNonRoot`, `readOnlyRootFilesystem`, `drop ALL` capabilities
- Network policies default deny
- Sealed Secrets ou External Secrets Operator (nunca secrets em plaintext no Git)
- Image scanning admission webhook (Kyverno/OPA)

### Observabilidade

- Prometheus `ServiceMonitor` para métricas
- Estrutura de logging: `stdout` (JSON), `stderr` (erros)
- Trace com OpenTelemetry (propagação de context)
- HPA configurado para serviços com variabilidade

## Estrutura de Projeto / Configuração

```
charts/
└── meu-servico/
    ├── Chart.yaml
    ├── values.yaml              # Base
    ├── values-dev.yaml          # Dev overrides
    ├── values-staging.yaml      # Staging overrides
    ├── values-prod.yaml          # Prod overrides
    ├── values.schema.json       # Validação
    ├── templates/
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   ├── ingress.yaml
    │   ├── hpa.yaml
    │   ├── pdb.yaml
    │   ├── networkpolicy.yaml
    │   ├── serviceaccount.yaml
    │   └── _helpers.tpl
    └── .helmignore
```

### ArgoCD (GitOps)

```
argocd/
├── apps/
│   ├── meu-servico-dev.yaml
│   ├── meu-servico-staging.yaml
│   └── meu-servico-prod.yaml
├── appsets/
│   └── application-set.yaml    # Generator para múltiplos envs
└── projects/
    └── projeto.yaml
```

## Anti-padrões

- Rodar como root em produção
- Não definir probes (readiness/liveness/startup)
- Não definir resource limits (pod pode consumir todo o nó)
- Usar `cluster-admin` para ServiceAccounts
- Secrets em plaintext no Git
- Deploy manual (`kubectl apply`) em produção — usar GitOps
- Helm charts monolíticos (um chart para tudo)
- Usar latest tag em imagens
- Não configurar PDB para serviços críticos
- NetworkPolicy default allow
- Ignorar horizontal pod autoscaler quando o serviço tem carga variável

## Consequências

**Positivas:**
- GitOps: Git como single source of truth, auditoria, rollback
- Resiliência: probes + PDB + anti-affinity garantem disponibilidade
- Segurança: default-deny, RBAC, PodSecurity restrict
- Reprodutibilidade: Helm charts versionados + Kustomize overlays
- Observabilidade nativa com Prometheus + OTEL

**Negativas:**
- Complexidade operacional inicial (curva de aprendizado K8s/Helm/ArgoCD)
- GitOps adiciona latência no deploy (push → ArgoCD sync)
- Políticas restritivas podem bloquear deploys legados (migração gradual)

**Riscos:**
- Over-engineering para workloads simples — considerar App Service ou Cloud Run
- Helm chart sprawl se não houver governança de charts reutilizáveis
- NetworkPolicies default-deny pode quebrar serviços legados — implementar incrementalmente

## Referências

- `skills/Infra/kubernetes-expert/SKILL.md`
- Kubernetes Best Practices: https://kubernetes.io/docs/concepts/configuration/overview/
- Helm Best Practices: https://helm.sh/docs/chart_best_practices/
- ArgoCD: https://argoproj.github.io/argo-cd/
- ADR-016 (Docker) — imagem de container
- ADR-018 (Terraform) — provisionamento do cluster
- ADR-019 (App Security) — security context, mTLS
- ADR-022 (CI/CD) — GitOps pipeline