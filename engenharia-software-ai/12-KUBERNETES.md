# 12. Kubernetes & Infrastructure

## 12.1 Cluster Architecture

```yaml
# Cluster Overview
cluster:
  provider: AWS EKS  # or GKE, AKS
  version: "1.29"
  regions:
    primary: us-east-1
    secondary: us-east-2
  availability_zones: 3

# Node Groups
node_groups:
  system:
    name: system
    instance_type: t3.medium
    min_size: 2
    max_size: 4
    labels:
      workload: system
  
  app:
    name: application
    instance_type: t3.large
    min_size: 3
    max_size: 20
    labels:
      workload: application
  
  ai:
    name: ai-workers
    instance_type: g4dn.xlarge
    min_size: 1
    max_size: 10
    labels:
      workload: ai
      gpu: "true"
  
  db:
    name: database
    instance_type: r5.large
    min_size: 2
    max_size: 6
    labels:
      workload: database
```

## 12.2 Namespaces

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production
---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    environment: staging
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    prometheus: enabled
```

## 12.3 Deployment Templates

```yaml
# deployments/product-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: production
  labels:
    app: product-service
    version: v1
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
        version: v1
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
    spec:
      serviceAccountName: product-service
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: product-service
                topologyKey: kubernetes.io/hostname
      containers:
        - name: product-service
          image: ghcr.io/org/product-service:latest
          ports:
            - containerPort: 8080
              name: http
            - containerPort: 9090
              name: metrics
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: product-service-secrets
                  key: database-url
            - name: REDIS_URL
              valueFrom:
                configMapKeyRef:
                  name: product-service-config
                  key: redis-url
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: product-service-config
                  key: log-level
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /readyz
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 3
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 10"]
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: product-service
```

## 12.4 Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: product-service-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: product-service
  minReplicas: 3
  maxReplicas: 50
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
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
        - type: Pods
          value: 4
          periodSeconds: 15
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
        - type: Pods
          value: 2
          periodSeconds: 60
      selectPolicy: Min
```

## 12.5 KEDA for Event-Driven Scaling

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: order-processor-scaled
  namespace: production
spec:
  scaleTargetRef:
    name: order-processor
  pollingInterval: 15
  cooldownPeriod: 300
  minReplicaCount: 2
  maxReplicaCount: 20
  fallback:
    failureThreshold: 3
    replicas: 5
  triggers:
    # Scale based on Redis queue length
    - type: redis
      metadata:
        address: REDIS_URL
        listName: order_queue
        listLength: "10"
        activationListLength: "5"
    
    # Scale based on Kafka lag
    - type: kafka
      metadata:
        bootstrapServers: kafka:9092
        consumerGroup: order-processor
        topic: orders
        lagThreshold: "100"
    
    # Scale based on Prometheus metrics
    - type: prometheus
      metadata:
        serverAddress: http://prometheus:9090
        metricName: http_requests_per_second
        threshold: "50"
        query: sum(rate(http_requests_total{service="order-processor"}[2m]))
```

## 12.6 Service with Circuit Breaker

```yaml
apiVersion: v1
kind: Service
metadata:
  name: product-service
  namespace: production
  annotations:
    prometheus.io/scrape: "true"
spec:
  type: ClusterIP
  ports:
    - port: 8080
      targetPort: 8080
      name: http
    - port: 9090
      targetPort: 9090
      name: metrics
  selector:
    app: product-service
---
# VirtualService for Istio with circuit breaker
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: product-service-destination
  namespace: production
spec:
  host: product-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        h2UpgradePolicy: UPGRADE
        http1MaxRequestMessagePerConnection: 100
    loadBalancer:
      simple: LEAST_CONN
    circuitBreakers:
      thresholds:
        - maxConnections: 100
          maxPendingRequests: 100
          maxRequests: 100
          maxRetries: 10
          consecutiveGatewayErrors: 5
          interval: 10s
          baseEjectionTime: 30s
```

## 12.7 Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: product-service-network-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: product-service
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
        - podSelector:
            matchLabels:
              app: bff-catalog
      ports:
        - port: 8080
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring
      ports:
        - port: 9090
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - port: 5432
    - to:
        - podSelector:
            matchLabels:
              app: redis
      ports:
        - port: 6379
    - to:
        - podSelector:
            matchLabels:
              app: elasticsearch
      ports:
        - port: 9200
```

## 12.8 Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "40"
    requests.memory: 80Gi
    limits.cpu: "80"
    limits.memory: 160Gi
    persistentvolumeclaims: "10"
    pods: "100"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
  namespace: production
spec:
  limits:
    - max:
        memory: 1Gi
        cpu: "1"
      default:
        memory: 256Mi
        cpu: 200m
      defaultRequest:
        memory: 128Mi
        cpu: 100m
      type: Container
```

## 12.9 Helm Chart Structure

```
helm/
├── Chart.yaml
├── values.yaml
├── values-staging.yaml
├── values-production.yaml
└── templates/
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── service.yaml
    ├── hpa.yaml
    ├── serviceaccount.yaml
    ├── configmap.yaml
    ├── secrets.yaml
    └── networkpolicy.yaml
```

## 12.10 ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: product-service
  namespace: argocd
spec:
  project: production
  source:
    repoURL: https://github.com/org/infra
    targetRevision: HEAD
    path: helm/values/production/product-service
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
```

## 12.11 Backup Strategy

```yaml
# Velero backup schedule
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"
  template:
    includedNamespaces:
      - production
      - staging
    excludedResources:
      - events
      - events.events.k8s.io
    storageLocation: default
    ttl: 720h
    hooks:
      resources:
        - name: backup-postgres
          includedNamespaces:
            - production
          labelSelector:
            matchLabels:
              app: postgres
          pre:
            - exec:
                container: postgres
                command:
                  - /bin/bash
                  - -c
                  - pg_dump -U postgres > /backup/pre.sql
                onError: Fail
```

## 12.12 Disaster Recovery

```yaml
# DR Configuration
disaster_recovery:
  rto_target: 1h
  rpo_target: 1h
  
  cross_region:
    enabled: true
    secondary_region: us-west-2
    replication: async
  
  databases:
    postgres:
      backup_frequency: hourly
      retention: 30d
      pitr_enabled: true
      pitr_window: 7d
    
    redis:
      replication: enabled
      backup_frequency: daily
      persistence: rdb
      
    elasticsearch:
      snapshot_lifecycle: daily
      cross_cluster_replication: true
  
  dns:
    failover:
      enabled: true
      health_check_interval: 30s
      failover_timeout: 60s
```