# Kubernetes Expert — Padrões de Código

## 1. Deployment — Production-Ready

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: myapp
  labels:
    app: api
    version: "1.0.0"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0  # zero-downtime deploy
  template:
    metadata:
      labels:
        app: api
        version: "1.0.0"
      annotations:
        # Prometheus scraping
        prometheus.io/scrape: "true"
        prometheus.io/port: "3000"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: api-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: api
          image: myacr.azurecr.io/api:1.0.0
          ports:
            - containerPort: 3000
              protocol: TCP
          env:
            - name: NODE_ENV
              value: "production"
            - name: PORT
              value: "3000"
          envFrom:
            - configMapRef:
                name: api-config
          # Secrets via External Secrets Operator (não hardcoded)
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: api-secrets
                  key: database-url
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          livenessProbe:
            httpGet:
              path: /health/live
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 30
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3
          startupProbe:
            httpGet:
              path: /health/ready
              port: 3000
            failureThreshold: 30
            periodSeconds: 5
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          volumeMounts:
            - mountPath: /tmp
              name: tmp
      volumes:
        - name: tmp
          emptyDir: {}
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: api
      terminationGracePeriodSeconds: 30
```

---

## 2. Service + Ingress + HPA

```yaml
# k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: myapp
spec:
  selector:
    app: api
  ports:
    - port: 80
      targetPort: 3000
      protocol: TCP
---
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api
  namespace: myapp
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts: [api.eveo.com]
      secretName: api-tls
  rules:
    - host: api.eveo.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 80
---
# k8s/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api
  namespace: myapp
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Aguardar 5min antes de scale down
      policies:
        - type: Pods
          value: 1
          periodSeconds: 60
```

---

## 3. External Secrets Operator — Azure Key Vault

> **Nunca** commitar `apiVersion: v1` / `kind: Secret` com `data` ou `stringData` reais (nem placeholders que pareçam senha). Isso é Sonar `secrets:S6694` (BLOCKER). O manifesto versionado é `ExternalSecret` (abaixo) ou SealedSecret; o `Secret` nativo nasce no cluster via sync/pipeline.

```yaml
# k8s/external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-keyvault
  namespace: myapp
spec:
  provider:
    azurekv:
      vaultUrl: "https://kv-myapp-prod.vault.azure.net"
      authType: WorkloadIdentity
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: api-secrets
  namespace: myapp
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: azure-keyvault
    kind: SecretStore
  target:
    name: api-secrets
    creationPolicy: Owner
  data:
    - secretKey: database-url
      remoteRef:
        key: database-url
    - secretKey: jwt-secret
      remoteRef:
        key: jwt-secret
```

---

## 4. KEDA — Scaling por SQS/Service Bus

```yaml
# k8s/keda-scaledobject.yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: worker-scaler
  namespace: myapp
spec:
  scaleTargetRef:
    name: worker
  minReplicaCount: 0   # Pode escalar para zero!
  maxReplicaCount: 20
  pollingInterval: 30
  cooldownPeriod: 300
  triggers:
    - type: azure-servicebus
      metadata:
        namespace: myapp-servicebus.servicebus.windows.net
        queueName: orders
        messageCount: "5"   # 1 pod por 5 mensagens
      authenticationRef:
        name: azure-servicebus-auth
```

---

## 5. NetworkPolicy — Isolamento de Rede

```yaml
# k8s/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-network-policy
  namespace: myapp
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 3000
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
    - to:  # DNS resolution
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
```

---

## 6. RBAC — ServiceAccount + Role + RoleBinding (least-privilege)

SA dedicado com Role namespaced e verbos mínimos. Nunca `cluster-admin`, nunca SA `default`.

```yaml
# k8s/rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-sa
  namespace: myapp
automountServiceAccountToken: false   # habilite só se o pod usa a API do K8s
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: api-role
  namespace: myapp
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]            # apenas o necessário
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: api-rolebinding
  namespace: myapp
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: api-role
subjects:
  - kind: ServiceAccount
    name: api-sa
    namespace: myapp
```

---

## 7. kubectl — Comandos Operacionais

```bash
# Ver pods com uso de recursos
kubectl top pods -n myapp --sort-by=memory

# Debug de pod com ephemeral container
kubectl debug -it -n myapp pod/api-xxxx \
  --image=busybox --target=api -- sh

# Restart rolling sem mudança de imagem
kubectl rollout restart deployment/api -n myapp

# Ver histórico de rollout
kubectl rollout history deployment/api -n myapp

# Rollback para versão anterior
kubectl rollout undo deployment/api -n myapp --to-revision=2

# Forçar deleção de pod stuck (Terminating)
kubectl delete pod api-xxxx -n myapp --grace-period=0 --force

# Port-forward para debug local
kubectl port-forward svc/postgres 5432:5432 -n myapp

# Ver events de um namespace
kubectl get events -n myapp --sort-by='.lastTimestamp'
```

---

## Anti-patterns

### ❌ Containers sem resource requests e limits
**Problema:** Não definir `resources.requests` e `resources.limits` no container spec.
**Por quê evitar:** Sem requests, o scheduler não sabe onde colocar o pod — pode lotar um nó; sem limits, um container pode consumir todos os recursos do nó causando OOMKill de outros pods (noisy neighbor).
**Solução:**
```yaml
resources:
  requests:
    cpu: "250m"      # mínimo garantido pelo scheduler
    memory: "256Mi"
  limits:
    cpu: "500m"      # máximo; throttling se exceder
    memory: "512Mi"  # OOMKill se exceder — ajuste baseado em métricas reais
```

### ❌ Ausência de liveness e readiness probes
**Problema:** Não configurar `livenessProbe` e `readinessProbe` nos containers.
**Por quê evitar:** Sem readiness, k8s roteia tráfego para pods que ainda estão iniciando (erro 502); sem liveness, pods travados ficam recebendo tráfego indefinidamente sem restart.
**Solução:**
```yaml
readinessProbe:
  httpGet: { path: /health/ready, port: 8080 }
  initialDelaySeconds: 5
  periodSeconds: 10
livenessProbe:
  httpGet: { path: /health/live, port: 8080 }
  initialDelaySeconds: 30
  failureThreshold: 3
```

### ❌ Secret plaintext versionado no Git (`secret.yaml`)
**Problema:** Commitar `infra/k8s/**/secret.yaml` (ou qualquer `kind: Secret`) com `stringData`/`data` contendo senha, token ou connection string.
**Por quê evitar:** Vazamento imediato no histórico Git; Sonar `secrets:S6694` (BLOCKER) e gitleaks falham o PR/gate.
**Solução:** ExternalSecret → Azure Key Vault (ou Sealed Secrets); valores de runtime só em variable group / vault — nunca no YAML do repo.

### ❌ Secrets armazenados em ConfigMaps
**Problema:** Colocar senhas, tokens e certificados em ConfigMaps em vez de Secrets.
**Por quê evitar:** ConfigMaps não são criptografados em etcd por padrão e são visíveis a qualquer usuário com acesso de leitura ao namespace — use External Secrets Operator com Key Vault (não Secret com valor no Git).
**Solução:**
```yaml
# Use ExternalSecret (recomendado) — NÃO kind: Secret com valores no repo
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-creds
spec:
  secretStoreRef: { name: azure-keyvault, kind: ClusterSecretStore }
  target: { name: db-creds }
  data:
    - secretKey: password
      remoteRef: { key: db-password-prod }
```

### ❌ imagePullPolicy: Always em produção
**Problema:** Usar `imagePullPolicy: Always` em Deployments de produção.
**Por quê evitar:** Cada restart de pod tenta puxar a imagem do registry — adiciona latência de startup e falha completamente se o registry estiver indisponível.
**Solução:**
```yaml
# Use IfNotPresent com tags imutáveis (SHA ou versão semver)
image: myacr.azurecr.io/api:1.2.3
imagePullPolicy: IfNotPresent
# Combine com imagePullSecrets se registry for privado
```

### ❌ Sem PodDisruptionBudget
**Problema:** Não configurar PDB em workloads de produção.
**Por quê evitar:** `kubectl drain` para manutenção de nó ou rolling update pode remover todos os pods de um Deployment simultaneamente — downtime completo.
**Solução:**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
spec:
  minAvailable: 2        # ou maxUnavailable: 1
  selector:
    matchLabels:
      app: minha-api
```

### ❌ Service Account padrão sem RBAC restritivo
**Problema:** Deixar pods usando o service account `default` do namespace sem configurar RBAC.
**Por quê evitar:** O SA `default` geralmente herda permissões amplas — qualquer exploit no container pode interagir com a API do Kubernetes com essas permissões.
**Solução:**
```yaml
# Crie SA dedicado com mínimo de permissões
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-sa
automountServiceAccountToken: false  # desabilite se não usar API k8s
---
# No Deployment
spec:
  serviceAccountName: api-sa
```

### ❌ NodePort services em produção
**Problema:** Expor serviços com `type: NodePort` em clusters de produção.
**Por quê evitar:** NodePort expõe uma porta em todos os nós (IP público incluído), sem TLS termination, sem balanceamento de carga real e em portas altas (30000-32767) — não é adequado para endpoints públicos.
**Solução:**
```yaml
# Para exposição externa: Ingress + NGINX Ingress Controller + cert-manager
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts: [api.exemplo.com.br]
      secretName: api-tls
  rules:
    - host: api.exemplo.com.br
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: { name: api-svc, port: { number: 80 } }
```
