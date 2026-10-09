# 11. CI/CD Pipeline

## 11.1 Pipeline Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CI/CD PIPELINE                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐           │
│  │  CODE   │→   │  BUILD  │→   │  TEST   │→   │ SECURITY│           │
│  │ PUSH    │    │         │    │         │    │  SCAN   │           │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘           │
│       ↓              ↓             ↓              ↓                 │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐           │
│  │  LINT   │    │  IMAGE  │    │ COVERAGE│    │   SAST  │           │
│  │         │    │         │    │  CHECK  │    │         │           │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘           │
│                                                                      │
│                            ↓ (if all pass)                          │
│                     ┌─────────┐                                     │
│                     │ DEPLOY  │                                     │
│                     │ STAGING │                                     │
│                     └─────────┘                                     │
│                            ↓                                         │
│                     ┌─────────┐                                     │
│                     │INTEGRAT.│                                     │
│                     │  TESTS  │                                     │
│                     └─────────┘                                     │
│                            ↓                                         │
│                     ┌─────────┐                                     │
│                     │   E2E   │                                     │
│                     │  TESTS  │                                     │
│                     └─────────┘                                     │
│                            ↓ (if tagged)                            │
│                     ┌─────────┐                                     │
│                     │DEPLOY   │                                     │
│                     │ PROD    │                                     │
│                     └─────────┘                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 11.2 GitHub Actions Workflow

```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop, 'release/*']
  pull_request:
    branches: [main]
  release:
    types: [published]

env:
  REGISTRY: ghcr.io
  GO_VERSION: '1.22'
  NODE_VERSION: '20'
  PYTHON_VERSION: '3.11'
  MIN_COVERAGE: 80

jobs:
  # ═══════════════════════════════════════════════════════════════════
  # LINT & CODE QUALITY
  # ═══════════════════════════════════════════════════════════════════
  lint:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
          cache: true
      
      - name: Lint Go Code
        run: |
          go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
          golangci-lint run ./...
      
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      
      - name: Lint JS/TS Code
        run: |
          npm ci
          npm run lint
      
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}
      
      - name: Lint Python Code
        run: |
          pip install ruff
          ruff check ai-agents/ ai-orchestrator/ ai-guardrails/

  # ═════════════════════════════════════════��═════════════════════════
  # UNIT TESTS & COVERAGE
  # ═══════════════════════════════════════════════════════════════════
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    strategy:
      matrix:
        service:
          - auth-service
          - product-service
          - order-service
          - payment-service
          - shipping-service
          - bff-auth
          - bff-catalog
          - bff-chat
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
          cache: true
      
      - name: Run Go Tests
        run: |
          go test -v -race -coverprofile=coverage.out -covermode=atomic ./...
          go tool cover -func=coverage.out | grep total
      
      - name: Check Coverage
        run: |
          COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | cut -d'%' -f1)
          if (( $(echo "$COVERAGE < ${{ env.MIN_COVERAGE }}" | bc -l) )); then
            echo "Coverage $COVERAGE% is below minimum ${{ env.MIN_COVERAGE }}%"
            exit 1
          fi
          echo "Coverage: $COVERAGE%"
      
      - name: Upload Coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage-${{ matrix.service }}
          path: coverage.out

  # ═══════════════════════════════════════════════════════════════════
  # BUILD DOCKER IMAGES
  # ═══════════════════════════════════════════════════════════════════
  build:
    needs: [lint, test]
    runs-on: ubuntu-latest
    timeout-minutes: 20
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      image-digest: ${{ steps.build.outputs.digest }}
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Login to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ github.repository }}/${{ matrix.service }}
          tags: |
            type=ref,event=branch
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}
            type=ref,event=tag
      
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ${{ matrix.service }}
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          outputs: type=image,name=${{ env.REGISTRY }}/${{ github.repository }}/${{ matrix.service }},push-by-digest=true

  # ═══════════════════════════════════════════════════════════════════
  # SECURITY SCANNING
  # ═══════════════════════════════════════════════════════════════════
  security:
    needs: build
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ needs.build.outputs.image-tag }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'
      
      - name: Upload to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
      
      - name: Run Semgrep SAST
        uses: returntocorp/semgrep-action@v1
        with:
          config: p/security-audit p/secrets

  # ═══════════════════════════════════════════════════════════════════
  # DEPLOY TO STAGING
  # ═══════════════════════════════════════════════════════════════════
  deploy-staging:
    needs: [build, security]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: staging
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup kubectl
        uses: azure/k8s-set-context@v3
        with:
          kubeconfig: ${{ secrets.KUBE_CONFIG_STAGING }}
      
      - name: Deploy to staging
        run: |
          # Update image in deployment
          kubectl set image deployment/$SERVICE_NAME \
            $SERVICE_NAME=${{ needs.build.outputs.image-tag }} \
            -n staging --namespace=staging
          
          # Wait for rollout
          kubectl rollout status deployment/$SERVICE_NAME \
            -n staging \
            --timeout=5m
      
      - name: Health check
        run: |
          curl -f http://staging.$DOMAIN/healthz || exit 1

  # ═══════════════════════════════════════════════════════════════════
  # INTEGRATION TESTS
  # ═══════════════════════════════════════════════════════════════════
  integration-tests:
    needs: deploy-staging
    runs-on: ubuntu-latest
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      
      - name: Run integration tests
        run: |
          npm ci
          npm run test:integration -- --env=staging
      
      - name: Run E2E tests
        uses: cypress-io/github-action@v5
        with:
          browser: chrome
          component: true
          start: npm run dev
          wait-on: http://localhost:3000

  # ═══════════════════════════════════════════════════════════════════
  # PERFORMANCE TESTS
  # ═══════════════════════════════════════════════════════════════════
  performance:
    needs: deploy-staging
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      
      - name: Run k6 load tests
        uses: k6io/action@v1
        with:
          filename: k6/load-test.js
          ENV_VARS: 'STAGING_URL=${{ secrets.STAGING_URL }}'

  # ═══════════════════════════════════════════════════════════════════
  # DEPLOY TO PRODUCTION
  # ═══════════════════════════════════════════════════════════════════
  deploy-production:
    needs: [integration-tests, performance]
    if: startsWith(github.ref, 'refs/tags/')
    runs-on: ubuntu-latest
    environment: production
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy to production
        run: |
          az aks get-credentials --name $CLUSTER_NAME --resource-group $RG_NAME
          
          # Create namespace if not exists
          kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
          
          # Deploy with rollout
          kubectl set image deployment/$SERVICE_NAME \
            $SERVICE_NAME=${{ needs.build.outputs.image-tag }} \
            -n production
          
          kubectl rollout status deployment/$SERVICE_NAME \
            -n production \
            --timeout=10m
      
      - name: Notify
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Deployment to production completed",
              "blocks": [{
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "*Production Deployment*\nService: $SERVICE_NAME\nVersion: ${{ github.ref_name }}\nCommit: ${{ github.sha }}"
                }
              }]
            }
```

## 11.3 Quality Gates

| Gate | Tool | Threshold | Blocking |
|------|------|-----------|----------|
| **Linting** | golangci-lint | 0 errors | Yes |
| **Linting** | ESLint | 0 errors | Yes |
| **Linting** | Ruff | 0 errors | Yes |
| **Unit Tests** | Go test | 100% pass | Yes |
| **Coverage** | Go cover | >= 80% | Yes |
| **Coverage** | Jest/Vitest | >= 80% | Yes |
| **Coverage** | pytest | >= 80% | Yes |
| **Security** | Trivy | 0 CRITICAL | Yes |
| **Security** | Semgrep | 0 high | No (warning) |
| **Integration** | Test suite | 100% pass | Yes |
| **E2E** | Playwright | 100% pass | Yes |
| **Performance** | k6 | p95 < 200ms | No (warning) |

## 11.4 Test Coverage Requirements

```yaml
# Minimum coverage by service
coverage_requirements:
  auth-service:
    overall: 85
    handlers: 90
    services: 85
    repositories: 80
  
  product-service:
    overall: 85
    handlers: 90
    services: 85
    repositories: 80
  
  order-service:
    overall: 85
    handlers: 90
    services: 85
    repositories: 80
  
  payment-service:
    overall: 90
    handlers: 95
    services: 90
    repositories: 85
  
  ai-agents:
    overall: 80
    agents: 75
    tools: 85
    rag: 80
```

## 11.5 Merge Rules (Mergify)

```yaml
# .mergify.yml
queue_rules:
  - name: default
    conditions:
      - check-success=lint
      - check-success=test
      - check-success=build
      - check-success=security
      - check-success=integration-tests
      - check-success=performance
      - or:
        - and:
          - status-success=build
          - status-success=security
        - label=skip-e2e
      - and:
        - "#approved-reviews>=1"
        - approved-reviews-by!=@me
      - linear-history
      - commit-message!=*WIP*

pull_request_rules:
  - name: Auto-merge on approval
    conditions:
      - and:
        - check-success=lint
        - check-success=test
        - check-success=build
        - check-success=security
        - "#approved-reviews>=1"
    actions:
      queue:
        method: squash
        rebase: true

  - name: Request review from CODEOWNERS
    conditions:
      - files=auth-service/**
    actions:
      request_reviews:
        teams:
          - team-auth

  - name: Assign author on CI failure
    conditions:
      - check-failure
    actions:
      assign:
        add_users: "{{ author }}"
```

## 11.6 SonarQube Configuration

```yaml
# sonar-project.properties
sonar.projectKey=ecommerce-platform
sonar.organization=your-org

# Language settings
sonar.language=py,ts,go

# Source paths
sources=.
sonar.tests=.

# Coverage
sonar.go.coverage.reportPaths=**/coverage.out
sonar.python.coverage.reportPaths=coverage.xml
sonar.typescript.lcov.reportPaths=coverage/lcov.info

# Quality gates
sonar.qualitygate.wait=true
sonar.qualitygate.timeout=300

# Exclusions
sonar.exclusions=**/*.test.go,**/*.spec.ts,**/node_modules/**,**/vendor/**
```

## 11.7 Deployment Environments

```yaml
environments:
  development:
    short_name: dev
    url: dev.$DOMAIN
    auto_deploy: true
    branch: develop
    replicas: 1
    resources: small
    
  staging:
    short_name: staging
    url: staging.$DOMAIN
    auto_deploy: true
    branch: main
    replicas: 2
    resources: medium
    e2e_tests: true
    load_tests: true
    
  sandbox:
    short_name: sandbox
    url: sandbox.$DOMAIN
    auto_deploy: false
    manual_approve: true
    replicas: 2
    resources: medium
    
  production:
    short_name: prod
    url: $DOMAIN
    auto_deploy: false
    manual_approve: true
    requires_tag: true
    replicas: 3-10
    resources: large
    blue_green: true
    canary: true
```