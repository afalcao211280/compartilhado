# AWS Expert — CloudFront / CDN

CDN global na borda: reduz latência, alta disponibilidade, DDoS protection (Shield) e WAF. Origin S3, ALB ou API Gateway. Padrão EVEO: **Terraform** (não console/CLI).

## Quando usar

- Assets estáticos e site estático (S3 origin privado).
- Aceleração de API e conteúdo dinâmico (cache TTL 0 + forward de headers).
- Streaming de vídeo/mídia, downloads grandes.
- Isolamento e proteção do origin (S3 nunca público).

## Regras EVEO

- **S3 privado + Origin Access Control (OAC)**, nunca OAI (legado) nem bucket público. OAC assina requisições SigV4 e é o padrão atual AWS.
- **HTTPS only para viewers** (`redirect-to-https` em assets, `https-only` em API).
- **WAF obrigatório** em distribuição pública (rate limit + managed rules).
- **Compressão** (gzip + brotli) habilitada.
- **Response headers de segurança** via response headers policy (HSTS, X-Frame-Options, nosniff, Referrer-Policy).
- **TTL apropriado**: assets longos, API com `default_ttl = 0`. Invalidação `/*` com parcimônia (custo + propagação).
- **CloudWatch alarms** em `4xxErrorRate`/`5xxErrorRate`.
- Nunca cachear dado sensível/autenticado sem `Cache-Control: private`.

## Terraform — Distribution com OAC, WAF e Security Headers

```hcl
# S3 origin privado
resource "aws_s3_bucket" "static" {
  bucket = "${var.app_name}-static-${data.aws_caller_identity.current.account_id}"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "static" {
  bucket = aws_s3_bucket.static.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket                  = aws_s3_bucket.static.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Origin Access Control (substitui OAI legado)
resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.app_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Bucket policy: só CloudFront desta distribuição lê
resource "aws_s3_bucket_policy" "static" {
  bucket = aws_s3_bucket.static.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontServicePrincipal"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.static.arn}/*"
      Condition = {
        StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.s3.arn }
      }
    }]
  })
}

# WAF (scope CLOUDFRONT exige provider em us-east-1)
resource "aws_wafv2_web_acl" "cloudfront" {
  provider = aws.us_east_1
  name     = "${var.app_name}-cf-waf"
  scope    = "CLOUDFRONT"
  default_action { allow {} }

  rule {
    name     = "RateLimit"
    priority = 1
    action { block {} }
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "CommonRuleSet"
    priority = 2
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.app_name}-cf-waf"
    sampled_requests_enabled   = true
  }
}

# Response headers de segurança (defesa em profundidade na borda)
resource "aws_cloudfront_response_headers_policy" "security" {
  name = "${var.app_name}-security-headers"
  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    content_type_options { override = true }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }
}

# Cache policy (assets estáticos)
resource "aws_cloudfront_cache_policy" "static" {
  name        = "${var.app_name}-static-cache"
  default_ttl = 86400
  max_ttl     = 31536000
  min_ttl     = 0
  parameters_in_cache_key_and_forwarded_to_origin {
    query_strings_config { query_string_behavior = "none" }
    headers_config { header_behavior = "none" }
    cookies_config { cookie_behavior = "none" }
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}

resource "aws_cloudfront_distribution" "s3" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  web_acl_id          = aws_wafv2_web_acl.cloudfront.arn
  tags                = var.tags

  origin {
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id                = "S3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  # Assets estáticos: cacheia, redireciona para HTTPS
  default_cache_behavior {
    target_origin_id           = "S3Origin"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    cache_policy_id            = aws_cloudfront_cache_policy.static.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # API: HTTPS only, sem cache (default_ttl = 0 via managed CachingDisabled)
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "S3Origin"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "https-only"
    cache_policy_id        = data.aws_cloudfront_cache_policy.disabled.id
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn # us-east-1, custom domain
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

resource "aws_cloudwatch_metric_alarm" "cf_4xx" {
  alarm_name          = "${var.app_name}-cf-4xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 5
  dimensions          = { DistributionId = aws_cloudfront_distribution.s3.id }
  alarm_actions       = [var.sns_alerts_arn]
}

data "aws_caller_identity" "current" {}
```

## Notas

- WAF `CLOUDFRONT` e ACM certificate da distribuição **devem estar em us-east-1** — use um provider alias (`aws.us_east_1`).
- `forwarded_values` (legado) substituído por `cache_policy_id` + `origin_request_policy_id` (recomendado atual).
- Invalidação não é recurso Terraform de produção — rode `aws cloudfront create-invalidation` no pipeline pós-deploy, com paths específicos (não `/*` rotineiro).

## Anti-padrões

- ❌ Bucket S3 público como origin → use OAC + bucket privado.
- ❌ HTTP em produção → `redirect-to-https` / `https-only`.
- ❌ Distribuição pública sem WAF → rate limit + managed rules.
- ❌ Cachear conteúdo autenticado sem `Cache-Control: private`.
- ❌ Invalidação `/*` em cada deploy → caro e lento; invalide paths específicos ou use versionamento de assets (hash no nome).
