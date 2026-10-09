# 13. Observabilidade (Logging, Métricas, Tracing)

## 13.1 Stack de Observabilidade

```
┌─────────────────────────────────────────────────────────────────────┐
│                      OBSERVABILITY STACK                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │
│   │  Services   │  │  Services  │  │  Services   │                 │
│   │  (Go/Py)    │  │  (Go/Py)    │  │  (Go/Py)    │                 │
│   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                 │
│          │                 │                 │                       │
│          └────────────────┼─────────────────┘                         │
│                           ↓                                          │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │              INSTRUMENTATION LAYER                           │   │
│   │   OpenTelemetry SDK → Traces, Metrics, Logs                 │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                           ↓                                          │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │
│   │ Prometheus  │  │    Loki     │  │   Tempo     │                 │
│   │  (Metrics)  │  │  (Logs)     │  │  (Traces)   │                 │
│   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                 │
│          │                 │                 │                       │
│          └────────────────┼─────────────────┘                         │
│                           ↓                                          │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                   GRAFANA DASHBOARDS                         │   │
│   │   Overview | Services | AI Ops | Business | Infrastructure   │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## 13.2 Logging Strategy

### Structured Log Format

```go
// Log format in Go
type LogEntry struct {
    Timestamp   string            `json:"timestamp"`
    Level       string            `json:"level"` // DEBUG, INFO, WARN, ERROR
    Service     string            `json:"service"`
    TraceID     string            `json:"trace_id,omitempty"`
    SpanID      string            `json:"span_id,omitempty"`
    Message     string            `json:"message"`
    Fields      map[string]any    `json:"fields,omitempty"`
    Error       *ErrorInfo        `json:"error,omitempty"`
}

type ErrorInfo struct {
    Type     string `json:"type"`
    Message  string `json:"message"`
    Stack    string `json:"stack,omitempty"`
}
```

### Example Log Output

```json
{
  "timestamp": "2025-01-15T10:30:00.123Z",
  "level": "ERROR",
  "service": "order-service",
  "trace_id": "4bf92b3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "message": "Failed to process payment",
  "fields": {
    "order_id": "ord_123",
    "user_id": "usr_456",
    "payment_provider": "stripe",
    "amount": 99.90
  },
  "error": {
    "type": "PaymentDeclined",
    "message": "Card declined",
    "stack": "github.com/org/order-service/internal/service\n\tpayment_process.go:123"
  }
}
```

### Fluent Bit Configuration

```yaml
# fluent-bit.conf
[SERVICE]
    Flush         5
    Log_Level     info
    Daemon        off

[INPUT]
    Name          tail
    Path          /var/log/containers/*.log
    Parser        docker
    Tag           k8s.*
    Refresh_Interval   5

[FILTER]
    Name          kubernetes
    Match         k8s.*
    Kube_URL      kubernetes.default.svc:443
    Kube_CA_File  /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    Kube_Token_File /var/run/secrets/kubernetes.io/serviceaccount/token

[FILTER]
    Name          modify
    Match         k8s.*
    Add           cluster ${CLUSTER_NAME}
    Add           environment ${ENVIRONMENT}

[OUTPUT]
    Name          loki
    Match         k8s.*
    Host          loki.monitoring.svc.cluster.local
    Port          3100
    Labels        job=fluent-bit
    auto-kubernetes-labels   true
```

## 13.3 Metrics with Prometheus

### Prometheus Metrics in Go

```go
package main

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    // HTTP metrics
    httpRequestsTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total HTTP requests",
        },
        []string{"method", "route", "status"}
    )
    
    httpRequestDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request duration",
            Buckets: []float64{.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10},
        },
        []string{"method", "route"}
    )
    
    // Business metrics
    OrdersCreated = promauto.NewCounter(
        prometheus.CounterOpts{
            Name: "orders_created_total",
            Help: "Total orders created",
        }
    )
    
    PaymentsProcessed = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "payments_processed_total",
            Help: "Total payments processed",
        },
        []string{"provider", "status"}
    )
    
    // AI metrics
    ChatMessagesTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "chat_messages_total",
            Help: "Total chat messages",
        },
        []string{"agent", "intent"}
    )
    
    GuardrailsBlocked = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "guardrails_blocked_total",
            Help: "Total blocked by guardrails",
        },
        []string{"type"}
    )
)
```

### Python Metrics with prometheus_client

```python
from prometheus_client import Counter, Histogram, Gauge

# AI agent metrics
chat_request_latency = Histogram(
    "ai_chat_request_seconds",
    "AI chat request latency",
    ["agent", "status"],
    buckets=[0.1, 0.5, 1, 2, 5, 10, 30]
)

guardrails_validation_latency = Histogram(
    "guardrails_validation_seconds",
    "Guardrails validation latency",
    ["stage"],
    buckets=[0.001, 0.005, 0.01, 0.05, 0.1]
)

agent_responses_total = Counter(
    "agent_responses_total",
    "Total agent responses",
    ["agent", "escalated"]
)
```

## 13.4 Tracing with OpenTelemetry

### Go Instrumentation

```go
package main

import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/trace"
    "go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
)

func main() {
    // Setup trace exporter
    exporter, err := otlptracegrpc.New(context.Background())
    if err != nil {
        log.Fatal(err)
    }
    
    tp := trace.NewTracerProvider(
        trace.WithBatcher(exporter),
        trace.WithResource(resource.NewWithAttributes(
            semconv.ServiceName("order-service"),
            semconv.ServiceVersion("1.0.0"),
        )),
    )
    
    otel.SetTracerProvider(tp)
    
    // Gin middleware
    r := gin.Default()
    r.Use(otelgin.Middleware("order-service"))
}
```

### Python Instrumentation

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

def setup_tracing(service_name: str):
    exporter = OTLPSpanExporter(
        endpoint="http://tempo:4317",
        insecure=True
    )
    
    provider = TracerProvider()
    provider.add_span_processor(BatchSpanProcessor(exporter))
    
    trace.set_tracer_provider(provider)
    
    # Instrument CrewAI
    from crewai import Agent
    Agent = trace.get_tracer(__name__).tool(
        tracer=trace.get_tracer_provider().get_tracer("crewai")
    )
```

## 13.5 Grafana Dashboards

### Overview Dashboard

```json
{
  "dashboard": {
    "title": "Platform Overview",
    "panels": [
      {
        "title": "Service Health",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=~'.*-service'}",
            "legendFormat": "{{job}}"
          }
        ]
      },
      {
        "title": "Request Rate (RPM)",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total[5m])) by (service)",
            "legendFormat": "{{service}}"
          }
        ]
      },
      {
        "title": "P95 Latency",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))",
            "legendFormat": "{{service}}"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{status=~'5..'}[5m])) by (service) / sum(rate(http_requests_total[5m])) by (service)",
            "legendFormat": "{{service}}"
          }
        ]
      }
    ]
  }
}
```

### AI Operations Dashboard

```json
{
  "dashboard": {
    "title": "AI Operations",
    "panels": [
      {
        "title": "Chat Messages by Agent",
        "type": "piechart",
        "targets": [
          {
            "expr": "sum(chat_messages_total) by (agent)",
            "legendFormat": "{{agent}}"
          }
        ]
      },
      {
        "title": "Agent Response Time",
        "type": "heatmap",
        "targets": [
          {
            "expr": "ai_chat_request_seconds_bucket"
          }
        ]
      },
      {
        "title": "Guardrails Blocks",
        "type": "bargauge",
        "targets": [
          {
            "expr": "sum(guardrails_blocked_total) by (type)",
            "legendFormat": "{{type}}"
          }
        ]
      },
      {
        "title": "Escalation Rate",
        "type": "gauge",
        "targets": [
          {
            "expr": "sum(agent_responses_total{escalated='true'}) / sum(agent_responses_total)"
          }
        ]
      }
    ]
  }
}
```

## 13.6 Alerting Rules

```yaml
# alerts.yaml
groups:
  - name: service_alerts
    rules:
      - alert: HighErrorRate
        expr: sum(rate(http_requests_total{status=~'5..'}[5m])) / sum(rate(http_requests_total[5m])) > 0.01
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }}"
      
      - alert: HighLatency
        expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le)) > 0.5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High P95 latency"
          description: "P95 latency is {{ $value | humanizeDuration }}"
      
      - alert: ServiceDown
        expr: up{job=~'.*-service'} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service is down"
          description: "{{ $labels.job }} has been down for 1 minute"

  - name: ai_alerts
    rules:
      - alert: HighGuardrailBlockRate
        expr: sum(rate(guardrails_blocked_total[5m])) / sum(rate(chat_messages_total[5m])) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High guardrail block rate"
          description: "More than 10% of messages blocked by guardrails"
      
      - alert: AgentEscalationSpike
        expr: sum(rate(agent_responses_total{escalated='true'}[5m])) / sum(rate(agent_responses_total[5m])) > 0.2
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High escalation rate"
          description: "Agent escalation rate above 20%"
```

## 13.7 SLO Definitions

```yaml
# slo.yaml
slos:
  - name: api-availability
    target: 99.9
    window: 30d
    indicators:
      - http_requests_total{status!~'5..'}

  - name: api-latency-p95
    target: 99.0
    window: 30d
    indicators:
      - http_request_duration_seconds{le="0.2"}

  - name: ai-resolution-rate
    target: 80.0
    window: 7d
    indicators:
      - agent_responses_total{escalated='false'}

  - name: payment-processing
    target: 99.5
    window: 30d
    indicators:
      - payments_processed_total{status='success'}
```

## 13.8 Runbook Template

```markdown
# Runbook: [Alert Name]

## Severity
[CRITICAL/HIGH/MEDIUM/LOW]

## Description
[Brief description of what triggers this alert]

## Investigation Steps
1. Check service health: `kubectl get pods -n production -l app=<service>`
2. Check recent logs: `kubectl logs -l app=<service> --tail=100`
3. Check traces: [Link to Grafana]
4. Check metrics: [Link to Grafana dashboard]

## Possible Causes
- [Cause 1]
- [Cause 2]
- [Cause 3]

## Mitigation Steps
1. [Step 1]
2. [Step 2]
3. [Step 3]

## Escalation
If not resolved within [X] minutes, escalate to [Team/Person]

## Post-Incident
- [ ] Create incident report
- [ ] Identify root cause
- [ ] Create follow-up tickets for fixes