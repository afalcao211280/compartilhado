# Kubernetes Expert — Stack Canônica

## Kubernetes 1.31+ — Versão Canônica EVEO

| Categoria | Ferramenta | Versão | Link | Notas |
|-----------|-----------|--------|------|-------|
| **Cluster Gerenciado** | | | | |
| Azure | AKS (Azure Kubernetes Service) | 1.31+ | https://learn.microsoft.com/aks | Padrão EVEO Azure |
| AWS | EKS (Elastic Kubernetes Service) | 1.31+ | https://aws.amazon.com/eks | Managed control plane |
| GCP | GKE Autopilot | 1.31+ | https://cloud.google.com/kubernetes-engine | Autopilot: sem node management |
| Dev local | kind | 0.24+ | https://kind.sigs.k8s.io | k8s em Docker. Para testes |
| Dev local alt | k3d / k3s | — | https://k3d.io | Mais leve. Para CI |
| **CLI** | | | | |
| CLI | kubectl | 1.31+ | https://kubernetes.io/docs/tasks/tools | `kubectl` versão ≤ cluster version + 1 |
| Context | kubectx + kubens | latest | https://github.com/ahmetb/kubectx | Trocar contexto e namespace |
| Debug | kubectl debug | built-in | — | Ephemeral containers para debug |
| Logs | stern | 1.30+ | https://github.com/stern/stern | Multi-pod log tailing |
| **Package Manager** | | | | |
| Helm | Helm | 3.x | https://helm.sh | Padrão para deploy de apps. Charts versionados |
| GitOps | ArgoCD **ou** Flux v2 | ArgoCD 2.9+ / Flux 2.x | argoproj.github.io/cd · fluxcd.io | Ferramenta por projeto (sem default EVEO). ArgoCD: UI/sync waves. Flux: GitOps puro, sem UI |
| **Ingress** | | | | |
| Ingress Controller | NGINX Ingress Controller | 1.10+ | https://kubernetes.github.io/ingress-nginx | Padrão. AKS App Gateway: alternativa |
| Cert Manager | cert-manager | 1.14+ | https://cert-manager.io | TLS automático via Let's Encrypt |
| **Service Mesh** | | | | |
| Service Mesh | Istio | 1.21+ | https://istio.io | Para mTLS, observabilidade avançada |
| Alternativa | Linkerd | 2.x | https://linkerd.io | Mais simples que Istio |
| **Observabilidade** | | | | |
| Métricas | Prometheus + Grafana | 2.x + 10.x | https://prometheus.io | kube-prometheus-stack |
| Logs | Loki | 3.x | https://grafana.com/oss/loki | Logs como Labels (como Prometheus) |
| Tracing | Jaeger / Tempo | — | https://grafana.com/oss/tempo | Distributed tracing |
| **Segurança** | | | | |
| Policy | OPA Gatekeeper / Kyverno | — | https://kyverno.io | Admission controller para policies |
| Secrets | External Secrets Operator | 0.9+ | https://external-secrets.io | Sync de Key Vault/Secrets Manager para k8s Secrets |
| RBAC | kubeaudit | latest | https://github.com/Shopify/kubeaudit | Auditoria de RBAC |
| **Scaling** | | | | |
| HPA | HorizontalPodAutoscaler | built-in | — | CPU/Memory scaling |
| KEDA | KEDA | 2.14+ | https://keda.sh | Scaling por métricas externas (SQS, Redis, etc.) |
| VPA | VerticalPodAutoscaler | 1.x | https://github.com/kubernetes/autoscaler | Ajusta requests/limits automaticamente |

## Versões de API Estáveis (1.31)

```
Apps:          apps/v1     → Deployment, StatefulSet, DaemonSet, ReplicaSet
Core:          v1          → Pod, Service, ConfigMap, Secret, PVC, ServiceAccount
Batch:         batch/v1    → Job, CronJob
Networking:    networking.k8s.io/v1 → Ingress, NetworkPolicy
RBAC:          rbac.authorization.k8s.io/v1 → Role, ClusterRole, RoleBinding
Autoscaling:   autoscaling/v2 → HPA
```
