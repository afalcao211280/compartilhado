# Kubernetes Expert — Helm 3 (chart scaffolding)

Padrão EVEO: um chart por serviço genérico, semver, values por ambiente, `values.schema.json` obrigatório, `_helpers.tpl` para DRY. Charts crus via `helm create` servem de base — sempre endurecer (security context, probes, PDB, NetworkPolicy).

## Índice

- [1. Estrutura do chart](#1-estrutura-do-chart)
- [2. Chart.yaml (apiVersion v2)](#2-chartyaml-apiversion-v2)
- [3. _helpers.tpl (naming + labels)](#3-_helperstpl-naming--labels)
- [4. deployment.yaml (template endurecido)](#4-deploymentyaml-template-endurecido)
- [5. values.yaml (base)](#5-valuesyaml-base)
- [6. values por ambiente](#6-values-por-ambiente)
- [7. values.schema.json](#7-valuesschemajson)
- [8. Dependencies](#8-dependencies)
- [9. Hooks (migrations) + tests](#9-hooks-migrations--tests)
- [10. .helmignore](#10-helmignore)
- [11. Validação](#11-validação)

## 1. Estrutura do chart

```
charts/meu-servico/
├── Chart.yaml              # metadata (required)
├── Chart.lock             # gerado por helm dependency update
├── values.yaml            # defaults (required)
├── values-dev.yaml         # overrides por ambiente
├── values-staging.yaml
├── values-prod.yaml
├── values.schema.json      # validação (obrigatório)
├── .helmignore
└── templates/             # (required)
    ├── _helpers.tpl       # helpers (prefixados com _)
    ├── NOTES.txt          # instruções pós-install
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── hpa.yaml
    ├── pdb.yaml
    ├── networkpolicy.yaml
    ├── serviceaccount.yaml
    └── tests/test-connection.yaml
```

- **Library chart** (`type: library`): só `_helpers.tpl` compartilhados, sem `templates/` instaláveis. Usado como dependência.
- **CRDs** vão em `crds/` (não são templated, instalados antes dos templates, não são upgraded/deleted com o chart).

## 2. Chart.yaml (apiVersion v2)

```yaml
apiVersion: v2
name: meu-servico
description: Helm chart do meu-servico
type: application                # ou library
version: 1.2.3                   # versão do CHART (semver: MAJOR breaking, MINOR feature, PATCH fix)
appVersion: "2.5.0"             # versão da APLICAÇÃO (string livre)
kubeVersion: ">=1.31.0"
keywords: [api, backend]
home: https://github.com/<org>/<repo>
sources: [https://github.com/<org>/<repo>]
maintainers:
  - name: DevOps Team
    email: devops@eveo.com.br
dependencies:                    # versões pinadas (exatas)
  - name: postgresql
    version: "12.0.0"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
    tags: [database]
```

## 3. _helpers.tpl (naming + labels)

DRY de nomes e labels. Inclua `{{ include "meu-servico.labels" . | nindent N }}` em todo recurso.

```yaml
{{- define "meu-servico.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "meu-servico.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}{{- end -}}
{{- end -}}

{{- define "meu-servico.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "meu-servico.labels" -}}
helm.sh/chart: {{ include "meu-servico.chart" . }}
{{ include "meu-servico.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "meu-servico.selectorLabels" -}}
app.kubernetes.io/name: {{ include "meu-servico.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
```

## 4. deployment.yaml (template endurecido)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "meu-servico.fullname" . }}
  labels:
    {{- include "meu-servico.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  revisionHistoryLimit: {{ .Values.revisionHistoryLimit }}
  selector:
    matchLabels:
      {{- include "meu-servico.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "meu-servico.selectorLabels" . | nindent 8 }}
      annotations:
        {{- toYaml .Values.podAnnotations | nindent 8 }}
    spec:
      serviceAccountName: {{ .Values.serviceAccount.name | default (include "meu-servico.fullname" .) }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort }}
          livenessProbe:
            {{- toYaml .Values.livenessProbe | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe | nindent 12 }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          env:
            {{- toYaml .Values.env | nindent 12 }}
```

Recursos opcionais: encapsule em `{{- if .Values.ingress.enabled }}` / `{{- if .Values.podDisruptionBudget.enabled }}` etc.

## 5. values.yaml (base)

```yaml
image:
  repository: myacr.azurecr.io/meu-servico
  tag: ""                       # default .Chart.AppVersion
  pullPolicy: IfNotPresent
nameOverride: ""
fullnameOverride: ""
replicaCount: 2
revisionHistoryLimit: 10

serviceAccount:
  create: true
  name: ""

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"
  prometheus.io/path: "/metrics"

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile: { type: RuntimeDefault }
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities: { drop: [ALL] }

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

ingress:
  enabled: false
  className: nginx
  annotations: {}
  hosts:
    - host: app.eveo.com.br
      paths: [{ path: /, pathType: Prefix }]
  tls: []

resources:
  requests: { cpu: 250m, memory: 256Mi }
  limits:   { cpu: 500m, memory: 512Mi }

livenessProbe:
  httpGet: { path: /health/live, port: http }
  initialDelaySeconds: 30
  periodSeconds: 10
readinessProbe:
  httpGet: { path: /health/ready, port: http }
  initialDelaySeconds: 5
  periodSeconds: 5

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80

podDisruptionBudget:
  enabled: true
  minAvailable: 1

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - { key: app.kubernetes.io/name, operator: In, values: ['{{ include "meu-servico.name" . }}'] }
          topologyKey: kubernetes.io/hostname

env: []
serviceMonitor: { enabled: false, interval: 30s }
networkPolicy: { enabled: true, policyTypes: [Ingress, Egress] }

# Dependências (subcharts). Em produção use ESO/Sealed Secrets, nunca senha em values.
postgresql: { enabled: false }
redis: { enabled: false }
```

## 6. values por ambiente

Um arquivo por ambiente; `helm`/ArgoCD aplica `values.yaml` + override.

```yaml
# values-prod.yaml
replicaCount: 5
image: { tag: "2.5.0" }
resources:
  requests: { cpu: 500m, memory: 512Mi }
  limits:   { cpu: "1",  memory: 1Gi }
autoscaling: { enabled: true, minReplicas: 3, maxReplicas: 20 }
ingress:
  enabled: true
  hosts: [{ host: api.eveo.com.br, paths: [{ path: /, pathType: Prefix }] }]
```

```bash
helm install meu-servico ./charts/meu-servico -f values-prod.yaml -n production
```

## 7. values.schema.json

Valida `values` no install/upgrade. Obrigatório.

```json
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["image"],
  "properties": {
    "replicaCount": { "type": "integer", "minimum": 1 },
    "image": {
      "type": "object",
      "required": ["repository"],
      "properties": {
        "repository": { "type": "string" },
        "tag": { "type": "string" },
        "pullPolicy": { "type": "string", "enum": ["Always", "IfNotPresent", "Never"] }
      }
    }
  }
}
```

## 8. Dependencies

```yaml
# Chart.yaml
dependencies:
  - name: postgresql
    version: "12.0.0"            # pinar versão exata
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
    alias: db                    # referenciar como .Values.db
```

```bash
helm dependency update    # baixa subcharts + gera Chart.lock
helm dependency build     # reconstrói a partir do Chart.lock
helm dependency list
```

## 9. Hooks (migrations) + tests

Hook de migração roda antes do upgrade/install:

```yaml
# templates/migration-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "meu-servico.fullname" . }}-migration
  annotations:
    "helm.sh/hook": pre-upgrade,pre-install
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          command: ["./migrate"]
```

Tipos: `pre/post-install`, `pre/post-upgrade`, `pre/post-delete`, `pre/post-rollback`, `test`. `hook-weight` ordena (menor primeiro). Deletion policies: `before-hook-creation`, `hook-succeeded`, `hook-failed`.

Teste de smoke:

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "meu-servico.fullname" . }}-test"
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  restartPolicy: Never
  containers:
    - name: wget
      image: busybox
      command: ['wget']
      args: ['{{ include "meu-servico.fullname" . }}:{{ .Values.service.port }}']
```

```bash
helm test meu-release --logs
```

## 10. .helmignore

```
.git/
.gitignore
*.md
docs/
*.swp
*.bak
*.tmp
test/
.vscode/
.idea/
```

## 11. Validação

```bash
helm lint ./charts/meu-servico
helm template meu-servico ./charts/meu-servico --validate   # renderiza + valida no cluster
helm template meu-servico ./charts/meu-servico -f values-prod.yaml
helm install meu-servico ./charts/meu-servico --dry-run --debug -n production
helm package ./charts/meu-servico                           # gera .tgz
```

Conferir no output renderizado (gate de revisão): `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, `resources` (requests+limits), `livenessProbe`/`readinessProbe`, ServiceAccount dedicado e `values.schema.json` presente.

## Padrões de template úteis

```yaml
# Recurso condicional
{{- if .Values.ingress.enabled }}
# ...
{{- end }}

# Iterar lista
env:
{{- range .Values.env }}
  - name: {{ .name }}
    value: {{ .value | quote }}
{{- end }}

# Embutir arquivo
data:
  config.yaml: |
    {{- .Files.Get "config/application.yaml" | nindent 4 }}
```

> Sempre `| quote` strings; bloco completo via `{{- toYaml .Values.x | nindent N }}`.

## Troubleshooting

```bash
helm template my-app ./my-app --debug          # erro de rendering
helm install my-app ./my-app --dry-run --debug # falha de install
kubectl get events --sort-by='.lastTimestamp'
helm dependency update && helm dependency list # deps
```
