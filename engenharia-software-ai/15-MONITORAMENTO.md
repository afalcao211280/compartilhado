# 15. Monitoramento e Dashboards

## 15.1 Overview

Sistema completo de visibilidade operacional com Grafana, alertas e KPIs.

## 15.2 Grafana Dashboards

### Dashboard: Platform Overview

```json
{
  "title": "Platform Overview",
  "uid": "platform-overview",
  "panels": [
    {
      "title": "Service Health",
      "type": "stat",
      "gridPos": {"x": 0, "y": 0, "w": 6, "h": 4},
      "targets": [
        {
          "expr": "count(up{job=~\".*-service\"} == 1)",
          "legendFormat": "Healthy"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "thresholds": {
            "steps": [
              {"color": "red", "value": null},
              {"color": "yellow", "value": 5},
              {"color": "green", "value": 8}
            ]
          }
        }
      }
    },
    {
      "title": "Request Rate (RPM)",
      "type": "timeseries",
      "gridPos": {"x": 6, "y": 0, "w": 12, "h": 4},
      "targets": [
        {
          "expr": "sum(rate(http_requests_total[5m])) by (service)",
          "legendFormat": "{{service}}"
        }
      ],
      "options": {
        "legend": {"displayMode": "table", "placement": "right"}
      }
    },
    {
      "title": "P95 Latency",
      "type": "timeseries",
      "gridPos": {"x": 0, "y": 4, "w": 12, "h": 4},
      "targets": [
        {
          "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))",
          "legendFormat": "{{service}}"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "s",
          "thresholds": {
            "steps": [
              {"color": "green", "value": null},
              {"color": "yellow", "value": 0.2},
              {"color": "red", "value": 0.5}
            ]
          }
        }
      }
    },
    {
      "title": "Error Rate",
      "type": "timeseries",
      "gridPos": {"x": 12, "y": 4, "w": 12, "h": 4},
      "targets": [
        {
          "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m])) by (service) / sum(rate(http_requests_total[5m])) by (service)",
          "legendFormat": "{{service}}"
        }
      ],
      "options": {
        "legend": {"displayMode": "table", "placement": "right"}
      }
    }
  ],
  "templating": {
    "variables": [
      {
        "name": "environment",
        "type": "query",
        "query": "label_values(up, environment)",
        "current": {"value": "production"}
      }
    ]
  }
}
```

### Dashboard: E-commerce KPIs

```json
{
  "title": "E-commerce KPIs",
  "uid": "ecommerce-kpis",
  "panels": [
    {
      "title": "Orders Today",
      "type": "stat",
      "targets": [{"expr": "sum(increase(orders_created_total[24h]))"}]
    },
    {
      "title": "Revenue Today",
      "type": "stat",
      "targets": [{"expr": "sum(increase(payments_processed_total{status=\"success\"}[24h])) * 100"}],
      "fieldConfig": {"defaults": {"unit": "currencyBRL"}}
    },
    {
      "title": "Conversion Rate",
      "type": "gauge",
      "targets": [
        {
          "expr": "sum(rate(cart_to_checkout_total[24h])) / sum(rate(product_views_total[24h]))"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "percentunit",
          "max": 1
        }
      }
    },
    {
      "title": "Average Order Value",
      "type": "stat",
      "targets": [{"expr": "sum(increase(orders_total[24h])) / sum(increase(order_count[24h]))"}],
      "fieldConfig": {"defaults": {"unit": "currencyBRL"}}
    },
    {
      "title": "Orders by Status",
      "type": "piechart",
      "targets": [
        {
          "expr": "sum(orders_created_total) by (status)"
        }
      ]
    },
    {
      "title": "Revenue Over Time",
      "type": "timeseries",
      "targets": [
        {
          "expr": "sum(increase(payments_processed_total{status=\"success\"}[1h])) * 100",
          "legendFormat": "Revenue (R$)"
        }
      ]
    }
  ]
}
```

### Dashboard: AI Operations

```json
{
  "title": "AI Operations",
  "uid": "ai-operations",
  "panels": [
    {
      "title": "Chat Messages by Agent",
      "type": "piechart",
      "targets": [
        {
          "expr": "sum(chat_messages_total) by (agent)"
        }
      ]
    },
    {
      "title": "Agent Response Time (P95)",
      "type": "timeseries",
      "targets": [
        {
          "expr": "histogram_quantile(0.95, sum(rate(ai_chat_request_seconds_bucket[5m])) by (le, agent))"
        }
      ],
      "fieldConfig": {"defaults": {"unit": "s"}}
    },
    {
      "title": "Guardrails Blocks",
      "type": "bargauge",
      "targets": [
        {
          "expr": "sum(guardrails_blocked_total) by (type)"
        }
      ]
    },
    {
      "title": "Escalation Rate",
      "type": "gauge",
      "targets": [
        {
          "expr": "sum(agent_responses_total{escalated=\"true\"}) / sum(agent_responses_total)"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "max": 1,
          "thresholds": {
            "steps": [
              {"color": "green", "value": null},
              {"color": "yellow", "value": 0.1},
              {"color": "red", "value": 0.2}
            ]
          }
        }
      }
    },
    {
      "title": "Resolution Rate",
      "type": "gauge",
      "targets": [
        {
          "expr": "1 - (sum(agent_responses_total{escalated=\"true\"}) / sum(agent_responses_total))"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "max": 1,
          "thresholds": {
            "steps": [
              {"color": "red", "value": null},
              {"color": "yellow", "value": 0.7},
              {"color": "green", "value": 0.8}
            ]
          }
        }
      }
    },
    {
      "title": "Guardrails Latency",
      "type": "heatmap",
      "targets": [
        {
          "expr": "sum(rate(guardrails_validation_seconds_bucket[5m])) by (le, stage)"
        }
      ]
    },
    {
      "title": "Token Usage",
      "type": "timeseries",
      "targets": [
        {
          "expr": "sum(rate(ai_tokens_used_total[1h])) by (agent)"
        }
      ]
    }
  ]
}
```

### Dashboard: Infrastructure

```json
{
  "title": "Kubernetes Infrastructure",
  "uid": "k8s-infrastructure",
  "panels": [
    {
      "title": "CPU Usage",
      "type": "timeseries",
      "targets": [
        {
          "expr": "sum(rate(container_cpu_usage_seconds_total{container!=\"POD\"}[5m])) by (namespace, pod)"
        }
      ],
      "options": {"legend": {"displayMode": "table", "placement": "right"}}
    },
    {
      "title": "Memory Usage",
      "type": "timeseries",
      "targets": [
        {
          "expr": "sum(container_memory_usage_bytes{container!=\"POD\"}) by (namespace, pod) / 1024 / 1024"
        }
      ],
      "fieldConfig": {"defaults": {"unit": "decibytes"}}
    },
    {
      "title": "Pod Status",
      "type": "table",
      "targets": [
        {
          "expr": "kube_pod_status_phase{namespace=~\"production|staging\"}"
        }
      ]
    },
    {
      "title": "HPA Status",
      "type": "table",
      "targets": [
        {
          "expr": "kube_horizontalpodautoscaler_status_desired_replicas"
        }
      ]
    },
    {
      "title": "Node Conditions",
      "type": "table",
      "targets": [
        {
          "expr": "kube_node_status_condition"
        }
      ]
    }
  ]
}
```

## 15.3 Alert Rules

```yaml
# prometheus/alerts.yaml
groups:
  - name: service_alerts
    rules:
      - alert: ServiceDown
        expr: up{job=~".*-service"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "{{ $labels.job }} has been down for 1 minute"
          runbook: "/runbooks/service-down"
      
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m])) by (service) 
          / sum(rate(http_requests_total[5m])) by (service) > 0.01
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate on {{ $labels.service }}"
          description: "Error rate is {{ $value | humanizePercentage }}"
      
      - alert: HighLatency
        expr: |
          histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service)) > 0.5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High P95 latency on {{ $labels.service }}"
          description: "P95 latency is {{ $value | humanizeDuration }}"

  - name: ai_alerts
    rules:
      - alert: HighGuardrailBlockRate
        expr: |
          sum(rate(guardrails_blocked_total[5m])) 
          / sum(rate(chat_messages_total[5m])) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High guardrail block rate"
          description: "{{ $value | humanizePercentage }} of messages blocked"
      
      - alert: AIEscalationSpike
        expr: |
          sum(rate(agent_responses_total{escalated="true"}[10m])) 
          / sum(rate(agent_responses_total[10m])) > 0.25
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "AI escalation rate spike"
          description: "Escalation rate above 25%"
      
      - alert: AILatencyHigh
        expr: |
          histogram_quantile(0.95, sum(rate(ai_chat_request_seconds_bucket[5m])) by (le)) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "AI response latency too high"
          description: "P95 AI latency is {{ $value | humanizeDuration }}"

  - name: business_alerts
    rules:
      - alert: NoOrders
        expr: increase(orders_created_total[15m]) == 0
        for: 15m
        labels:
          severity: critical
        annotations:
          summary: "No orders in 15 minutes"
          description: "Possible system issue or database problem"
      
      - alert: PaymentFailureRateHigh
        expr: |
          sum(rate(payments_processed_total{status="failed"}[15m])) 
          / sum(rate(payments_processed_total[15m])) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Payment failure rate above 10%"
          description: "Investigate payment gateway issues"

  - name: infrastructure_alerts
    rules:
      - alert: K8sNodeNotReady
        expr: kube_node_status_condition{condition="Ready",status="false"} == 1
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Kubernetes node not ready"
          description: "Node {{ $labels.node }} is not ready"
      
      - alert: PodOOMKilled
        expr: increase(kube_pod_container_status_restarts_total[5m]) > 0
        for: 0m
        labels:
          severity: warning
        annotations:
          summary: "Pod restarted"
          description: "Pod {{ $labels.pod }} in {{ $labels.namespace }} restarted"
```

## 15.4 AlertManager Configuration

```yaml
# alertmanager/config.yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@company.com'

route:
  receiver: 'default'
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  
  routes:
    - match:
        severity: critical
      receiver: 'critical-pager'
      group_wait: 10s
    
    - match:
        severity: warning
      receiver: 'warning-slack'
    
    - match:
        alertname: 'AI.*'
      receiver: 'ai-team-slack'

receivers:
  - name: 'default'
    email_configs:
      - to: 'oncall@company.com'
        send_resolved: true
  
  - name: 'critical-pager'
    pagerduty_configs:
      - service_key: PAGERDUTY_KEY
        severity: critical
        send_resolved: true
  
  - name: 'warning-slack'
    slack_configs:
      - api_url: SLACK_WEBHOOK_URL
        channel: '#alerts'
        send_resolved: true
        title: "{{ .GroupLabels.alertname }}"
        text: "{{ .Annotations.summary }}\n\n{{ .Annotations.description }}"
  
  - name: 'ai-team-slack'
    slack_configs:
      - api_url: SLACK_AI_WEBHOOK_URL
        channel: '#ai-alerts'
        send_resolved: true
```

## 15.5 SLO Monitoring

```yaml
# slo.yaml
slos:
  - name: api-availability
    goal: 99.9
    window: 30d
    indicator:
      type: ratio
      good:
        sum(rate(http_requests_total{status!~"5..",job=~"api.*-service"}[{{.window}}]))
      total:
        sum(rate(http_requests_total{job=~"api.*-service"}[{{.window}}]))

  - name: api-latency-p95
    goal: 99.0
    window: 30d
    indicator:
      type: latency
      threshold: 200ms
      total:
        sum(rate(http_request_duration_seconds_bucket{job=~"api.*-service"}[{{.window}}]))
      good:
        sum(rate(http_request_duration_seconds_bucket{job=~"api.*-service",le="0.2"}[{{.window}}]))

  - name: ai-resolution-rate
    goal: 80.0
    window: 7d
    indicator:
      type: ratio
      good:
        sum(agent_responses_total{escalated="false"}[{{.window}}])
      total:
        sum(agent_responses_total[{{.window}}])

  - name: payment-success-rate
    goal: 99.5
    window: 30d
    indicator:
      type: ratio
      good:
        sum(payments_processed_total{status="success"}[{{.window}}])
      total:
        sum(payments_processed_total[{{.window}}])

# Error Budget
error_budget:
  api-availability:
    budget: 0.1%  # 99.9% target = 0.1% budget
    burn_rate_alerts:
      - duration: 1h
        budget_used: 10%
      - duration: 6h
        budget_used: 25%
      - duration: 1d
        budget_used: 50%
```

## 15.6 Runbooks

```markdown
# Runbook: Service Down

## Severity: CRITICAL

## Symptoms
- Service health check failing
- User reports of application errors
- Alert: ServiceDown

## Investigation Steps

1. **Check pod status**
   ```bash
   kubectl get pods -n production -l app=SERVICE_NAME
   kubectl describe pod POD_NAME -n production
   kubectl logs POD_NAME -n production --previous
   ```

2. **Check resource usage**
   ```bash
   kubectl top pods -n production -l app=SERVICE_NAME
   kubectl top nodes
   ```

3. **Check events**
   ```bash
   kubectl get events -n production --sort-by=.lastTimestamp
   ```

4. **Check dependencies**
   - PostgreSQL connectivity
   - Redis connectivity
   - Other service health

## Possible Causes
- OOMKilled (increase memory limits)
- CrashLoopBackOff (check application logs)
- Pending due to resources (scale up nodes)
- Network policy blocking

## Mitigation Steps

1. **If OOMKilled:**
   ```bash
   kubectl patch deployment SERVICE_NAME -n production -p '{"spec":{"template":{"spec":{"containers":[{"name":"SERVICE_NAME","resources":{"limits":{"memory":"1Gi"}}}]}}}}'
   kubectl rollout restart deployment SERVICE_NAME -n production
   ```

2. **If CrashLoopBackOff:**
   - Check logs for error
   - Verify configmap/secrets
   - Rollback recent changes if needed

3. **If pending resources:**
   ```bash
   kubectl scale deployment SERVICE_NAME -n production --replicas=1
   kubectl rollout status deployment SERVICE_NAME -n production
   ```

## Escalation
If not resolved in 15 minutes, escalate to Platform team.

---

# Runbook: High AI Guardrail Block Rate

## Severity: WARNING

## Symptoms
- Guardrail block rate > 10%
- Users complaining messages not being answered

## Investigation Steps

1. **Check metrics**
   - Identify which guardrail type is blocking most
   - Check if specific patterns are triggering

2. **Check recent changes**
   - Any new patterns added?
   - Threshold changes?

3. **Check user feedback**
   - Review flagged conversations

## Possible Causes
- Threshold too aggressive
- Legitimate messages matching blocking patterns
- Prompt injection attack

## Mitigation Steps

1. **If legitimate content being blocked:**
   ```bash
   # Review and adjust patterns
   kubectl exec -it guardrails-configurator -- python update_patterns.py
   ```

2. **If threshold too aggressive:**
   - Temporarily raise threshold
   - Monitor closely

3. **If attack detected:**
   - Enable additional logging
   - Block source IPs
   - Notify security team

## Escalation
If block rate > 20% for more than 30 minutes, escalate to AI team lead.
```

## 15.7 On-Call Rotation

```yaml
# PagerDuty / On-Call Configuration
on_call:
  rotation:
    type: weekly
    handoff_day: monday
    handoff_time: "09:00"
  
  escalation:
    levels:
      - name: primary
        timeout: 15m
        contacts:
          - type: phone
            priority: high
          - type: slack
      - name: secondary
        timeout: 30m
        contacts:
          - type: slack
      - name: manager
        timeout: 1h
        contacts:
          - type: slack
          - type: email
      - name: vp_engineering
        timeout: 2h
        contacts:
          - type: email

  schedules:
    primary:
      - engineer1
      - engineer2
      - engineer3
      - engineer4
    secondary:
      - engineer5
      - engineer6
```