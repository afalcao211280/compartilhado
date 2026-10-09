# 14. Segurança, Backup e Proteção

## 14.1 Visão Geral

Implementação de segurança em múltiplas camadas (defense in depth).

## 14.2 Camadas de Segurança

```
┌─────────────────────────────────────────────────────────────────────┐
│                     SECURITY LAYERS                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────────────────────────────────��───────────────┐   │
│  │  EDGE LAYER                                                   │   │
│  │  WAF → DDoS Protection → Rate Limiting → SSL/TLS              │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              ↓                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  NETWORK LAYER                                               │   │
│  │  VPC → Subnets → Security Groups → Network Policies          │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              ↓                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  SERVICE LAYER                                              │   │
│  │  mTLS → Auth → RBAC → Rate Limiting → Input Validation       │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              ↓                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  DATA LAYER                                                  │   │
│  │  Encryption at Rest → Encryption in Transit → PII Protection  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## 14.3 WAF Configuration

```yaml
# Kong/WAF Rules
waf:
  rules:
    - name: "Block SQL Injection"
      type: "sql_injection"
      action: "block"
      priority: 1
    
    - name: "Block XSS"
      type: "xss"
      action: "block"
      priority: 2
    
    - name: "Block Local File Inclusion"
      type: "lfi"
      action: "block"
      priority: 3
    
    - name: "Block Remote File Inclusion"
      type: "rfi"
      action: "block"
      priority: 4
    
    - name: "Rate Limiting API"
      type: "rate_limit"
      threshold: 1000
      window: 60
      action: "throttle"
    
    - name: "Block Known Attackers"
      type: "ip_reputation"
      action: "block"
    
    - name: "Protocol Attack Protection"
      type: "http_protocol"
      action: "block"

# OWASP ModSecurity Rules
modsecurity:
  crs:
    enabled: true
    version: "4.0"
    rules:
      - "OWASP_CRS/base_rules/modsecurity_crs_41_sql_injection_attacks.conf"
      - "OWASP_CRS/base_rules/modsecurity_crs_41_xss_attacks.conf"
      - "OWASP_CRS/base_rules/modsecurity_crs_41_php_injection_attacks.conf"
```

## 14.4 Network Security

```yaml
# VPC Configuration
vpc:
  cidr: "10.0.0.0/16"
  
  subnets:
    public:
      - "10.0.1.0/24"  # us-east-1a
      - "10.0.2.0/24"  # us-east-1b
      # Load balancers, Bastion
    
    private_app:
      - "10.0.10.0/24" # us-east-1a
      - "10.0.11.0/24" # us-east-1b
      # Application services (Kubernetes nodes)
    
    private_data:
      - "10.0.20.0/24" # us-east-1a
      - "10.0.21.0/24" # us-east-1b
      # Databases, Redis, Elasticsearch

# Security Groups
security_groups:
  api_gateway:
    inbound:
      - port: 443
        source: "0.0.0.0/0"
      - port: 80
        source: "0.0.0.0/0"
    outbound:
      - to: "private_app"
        ports: [8080, 3000]

  kubernetes_nodes:
    inbound:
      - from: "api_gateway"
        ports: [8080]
      - from: "kubernetes_api"
        ports: [10250]
    outbound:
      - to: "private_data"
        ports: [5432, 6379, 9200]

# Kubernetes Network Policies
network_policies:
  default_deny:
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: default-deny
    spec:
      podSelector: {}
      policyTypes: ["Ingress", "Egress"]
```

## 14.5 Secrets Management (HashiCorp Vault)

```bash
# Vault Configuration
vault:
  auth:
    methods:
      - kubernetes  # K8s service account auth
      - ldap        # Team authentication
  
  secrets:
    databases:
      - name: "postgresql"
        plugin: "postgresql-database-plugin"
        config:
          host: postgres.internal
          port: 5432
    
    aws:
      - name: "aws"
        config:
          region: us-east-1
    
    pki:
      - name: "internal-ca"
        type: "pki"
        config:
          expiry: "87600h"  # 10 years

# Kubernetes Secret Injection
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
annotations:
  vault.hashicorp.com/role: "app-service"
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/agent-inject-secret-db-url: "secret/data/postgres"
data:
  # Values injected at runtime
```

```go
// Go: Reading secrets from Vault
import "github.com/hashicorp/vault/api"

func getSecret(path string) (string, error) {
    client, _ := api.NewClient(api.DefaultConfig())
    client.SetToken(os.Getenv("VAULT_TOKEN"))
    
    secret, err := client.Logical().Read(path)
    if err != nil {
        return "", err
    }
    
    return secret.Data["password"].(string), nil
}
```

## 14.6 Encryption

```yaml
# Encryption at Rest
encryption:
  database:
    postgresql:
      type: "aws-encryption-sdk"
      key_id: "alias/database-key"
    
    redis:
      type: "aws-encryption-sdk"
      key_id: "alias/redis-key"
    
    s3:
      default_encryption: "AES256"
      versioning: true

# TLS Configuration
tls:
  internal:
    min_version: "TLS1.2"
    cipher_suites:
      - "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
      - "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
  
  external:
    min_version: "TLS1.2"
    hsts:
      enabled: true
      max_age: 31536000
      include_subdomains: true

# Certificate Management (cert-manager)
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: "https://acme-v02.api.letsencrypt.org/directory"
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
```

## 14.7 Authentication & Authorization

```go
// JWT Validation Middleware (Go)
func AuthMiddleware(publicKeyPath string) gin.HandlerFunc {
    publicKey, _ := os.ReadFile(publicKeyPath)
    
    return func(c *gin.Context) {
        authHeader := c.GetHeader("Authorization")
        if authHeader == "" {
            c.JSON(401, gin.H{"error": "no authorization header"})
            c.Abort()
            return
        }
        
        tokenString := strings.TrimPrefix(authHeader, "Bearer ")
        
        token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
            if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
                return nil, fmt.Errorf("unexpected method: %v", token.Header["alg"])
            }
            return jwt.ParseRSAPublicKeyFromPEM(publicKey)
        })
        
        if err != nil || !token.Valid {
            c.JSON(401, gin.H{"error": "invalid token"})
            c.Abort()
            return
        }
        
        claims := token.Claims.(jwt.MapClaims)
        c.Set("user_id", claims["sub"])
        c.Set("roles", claims["roles"])
        
        c.Next()
    }
}

// RBAC Authorization
func Authorize(requiredPermission string) gin.HandlerFunc {
    return func(c *gin.Context) {
        userRoles := c.GetStringSlice("roles")
        
        for _, role := range userRoles {
            if hasPermission(role, requiredPermission) {
                c.Next()
                return
            }
        }
        
        c.JSON(403, gin.H{"error": "insufficient permissions"})
        c.Abort()
    }
}

func hasPermission(role, permission string) bool {
    permissions := map[string][]string{
        "admin": {"*"},
        "manager": {"products:*", "orders:*", "customers:read", "reports:read"},
        "customer": {"profile:*", "orders:create", "orders:read", "cart:*"},
        "agent": {"tickets:*", "orders:read", "customers:read", "chat:*"},
    }
    
    rolePerms := permissions[role]
    if contains(rolePerms, "*") {
        return true
    }
    return contains(rolePerms, permission)
}
```

## 14.8 PII Protection

```python
# Python: PII Detection and Masking
from presidio_analyzer import AnalyzerEngine
from presidio_anonymizer import AnonymizerEngine

class PIIProtection:
    def __init__(self):
        self.analyzer = AnalyzerEngine()
        self.anonymizer = AnonymizerEngine()
    
    def detect_and_mask(self, text: str) -> tuple[str, list]:
        """Detect and mask PII in text"""
        # Analyze text for PII
        analyzer_results = self.analyzer.analyze(
            text=text,
            language="pt"
        )
        
        # Anonymize
        anonymized, metadata = self.anonymizer.anonymize(
            text=text,
            analyzer_results=analyzer_results,
            parameters={
                "anonymize_phi": True
            }
        )
        
        return anonymized.text, metadata
    
    def detect_for_review(self, text: str) -> list:
        """Detect PII for manual review (no masking)"""
        return self.analyzer.analyze(
            text=text,
            language="pt",
            return_decision_process=True
        )

# Usage in AI Guardrails
def mask_pii_in_messages(messages: list) -> list:
    """Mask PII in conversation history before LLM"""
    pii_protection = PIIProtection()
    
    masked = []
    for msg in messages:
        if msg["role"] == "user":
            masked_text, _ = pii_protection.detect_and_mask(msg["content"])
            msg["content"] = masked_text
        masked.append(msg)
    
    return masked
```

## 14.9 Backup Configuration

```yaml
# Velero Backup Configuration
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"  # Daily at 2am UTC
  template:
    includedNamespaces:
      - production
      - staging
    excludedResources:
      - events
      - events.events.k8s.io
    storageLocation: default
    ttl: 720h  # 30 days
    defaultVolumesToRestic: true

---
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: default
  namespace: velero
spec:
  provider: aws
  config:
    region: us-east-1
    s3Url: ""
    s3ForcePathStyle: "false"
  objectStorage:
    bucket: my-backups-bucket
    prefix: velero

# PostgreSQL Backup
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: production
spec:
  schedule: "0 * * * *"  # Hourly
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: postgres:15
              env:
                - name: POSTGRES_HOST
                  value: postgres
                - name: S3_BUCKET
                  value: my-backups-bucket
              command:
                - /bin/bash
                - -c
                - |
                  pg_dump -h $POSTGRES_HOST -U postgres -d mydb | \
                  gzip | \
                  aws s3 cp - s3://$S3_BUCKET/postgres/$(date +%Y%m%d-%H%M).sql.gz
          restartPolicy: OnFailure
```

## 14.10 Disaster Recovery

```yaml
# DR Architecture
disaster_recovery:
  rto: 1h  # Recovery Time Objective
  rpo: 1h  # Recovery Point Objective
  
  primary_region: us-east-1
  secondary_region: us-west-2
  
  database_replication:
    postgresql:
      type: async_streaming_replication
      replication_user: replicator
      
    redis:
      type: redis_failover
      sentinel: true
      
    elasticsearch:
      type: cross_cluster_replication
      
  dns_failover:
    provider: route53
    health_check:
      interval: 30s
      failure_threshold: 3
      timeout: 5s
      
  failover_procedure:
    steps:
      - name: "Verify primary failure"
        check: "Health checks failing for 3 consecutive checks"
      - name: "Promote secondary"
        action: "update RDS read replica to primary"
      - name: "Update DNS"
        action: "Switch Route53 to secondary"
      - name: "Notify team"
        action: "Send Slack notification"
      - name: "Verify services"
        action: "Run smoke tests"

# DR Testing Schedule
dr_testing:
  schedule: "quarterly"
  scenarios:
    - name: "Database failover"
      duration: 2h
    - name: "Full region failover"
      duration: 4h
    - name: "Data recovery"
      duration: 3h
```

## 14.11 Security Monitoring

```yaml
# CloudTrail / Audit Logs
cloudtrail:
  enabled: true
  regions: [us-east-1, us-west-2]
  include_global_events: true
  s3_bucket: audit-logs-bucket
  
# GuardDuty
guardduty:
  enabled: true
  findings:
    critical:
      - email_alert: true
      - severity_threshold: 7
    high:
      - slack_alert: true
```

## 14.12 Compliance

```yaml
# Compliance Requirements
compliance:
  lgpd:
    requirements:
      - data_inventory: true
      - consent_management: true
      - data_subject_rights: true
      - breach_notification: 72h
      - privacy_by_design: true
    
  pci_dss:
    requirements:
      - encrypted_transmission: true
      - access_control: true
      - vulnerability_management: true
      - monitoring: true
      - network_security: true
```

## 14.13 Security Checklist

```markdown
## Security Checklist

### Authentication
- [x] OAuth2/OIDC implemented
- [x] JWT validation in all services
- [x] MFA enabled for admin
- [x] Password policy enforced
- [x] Session timeout configured
- [x] SSO providers configured

### Authorization
- [x] RBAC implemented
- [x] Resource ownership verified
- [x] Least privilege principle
- [x] API authorization middleware

### Data Protection
- [x] Encryption at rest
- [x] Encryption in transit
- [x] PII detection and masking
- [x] Secure key management
- [x] Data retention policies

### Infrastructure
- [x] WAF configured
- [x] Network policies
- [x] Security groups
- [x] DDoS protection
- [x] Regular patching

### Monitoring
- [x] Audit logging
- [x] SIEM integration
- [x] Alerting on security events
- [x] Regular security reviews

### Incident Response
- [x] Runbooks defined
- [x] Escalation paths
- [x] Communication plan
- [x] Post-mortem process
```