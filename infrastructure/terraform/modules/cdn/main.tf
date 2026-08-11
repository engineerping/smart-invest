# ==============================================================================
# CDN 模块 —— CloudFront + S3 + WAF（前端静态资源托管 + 全球加速 + 防火墙）
# ==============================================================================
#
# 一句话理解：
#   这个模块负责前端的静态文件存储（S3）、全球加速（CloudFront）
#   和 Web 防护（WAF）。
#
# ==============================================================================
# 架构：前端请求的完整链路
# ==============================================================================
#
#   用户浏览器（全球任意位置）
#       │
#       ▼
#   CloudFront CDN（全球边缘节点，就近接入）
#       │
#       ├── 请求 /api/* → EC2 后端（8080 端口）← custom origin
#       │
#       └── 其他请求 → S3 存储桶（前端静态文件）← S3 origin + OAC
#                         ↑
#                    只有 CloudFront 能访问（OAC 加密认证），S3 不直接对外
#
#   完整链路：
#     用户 → CloudFront → WAF 检查 → 路由判断 → /api/*? → EC2 后端
#                                            → 其他   → S3 前端
#
# ==============================================================================

# ==============================================================================
# S3 Bucket —— 前端静态文件存储
# ==============================================================================
resource "aws_s3_bucket" "frontend" {
  bucket = var.s3_bucket_name
  force_destroy = false

  tags = {
    Name    = "${var.project_name}-frontend"
    Project = var.project_name
  }
}

# ─── 阻止所有公共访问 ───
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─── 版本控制 ───
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ─── S3 存储桶策略 ───
resource "aws_s3_bucket_policy" "frontend" {
  bucket     = aws_s3_bucket.frontend.id
  depends_on = [aws_s3_bucket_public_access_block.frontend]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}

# ==============================================================================
# OAC（Origin Access Control）—— CloudFront 访问 S3 的凭证
# ==============================================================================
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "oac-smart-invest-frontend-service-prod-bucket-name.s-mnrrknq65sb"
  description                        = "Created by CloudFront"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ==============================================================================
# CloudFront Distribution —— CDN 分发
# ==============================================================================
resource "aws_cloudfront_distribution" "main" {
  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2"
  web_acl_id      = aws_wafv2_web_acl.cloudfront_waf.arn
  comment         = ""

  # ─── Origin 1：S3（前端静态资源）───
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "${var.s3_bucket_name}.s3.${var.aws_region}.amazonaws.com-mnroxtmimfk"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  # ─── Origin 2：EC2（后端 API）───
  origin {
    domain_name = var.ec2_public_dns
    origin_id   = "smart-invest-ec2-backend"

    custom_origin_config {
      http_port                = 8080
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 30
      origin_keepalive_timeout = 5
    }
  }

  # ─── 默认缓存行为：S3 前端（匹配所有非 /api/* 的请求）───
  default_cache_behavior {
    target_origin_id       = "${var.s3_bucket_name}.s3.${var.aws_region}.amazonaws.com-mnroxtmimfk"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # ─── /api/* 路由行为：EC2 后端 ───
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "smart-invest-ec2-backend"
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type"]
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # ─── SPA 路由支持：403/404 → index.html ───
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 100
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 100
  }

  # ─── 地理限制：none = 全球可访问 ───
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # ─── SSL 证书：使用 CloudFront 默认证书 ───
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name    = "${var.project_name}-front-distribution"
    Project = var.project_name
  }
}

# ==============================================================================
# WAF Web ACL —— Web 应用防火墙
# ==============================================================================
resource "aws_wafv2_web_acl" "cloudfront_waf" {
  provider = aws.us_east_1

  name        = "CreatedByCloudFront-398257e2"
  scope       = "CLOUDFRONT"
  description = "WAF for ${var.project_name} CloudFront distribution"

  # ─── 默认动作：不匹配任何规则 → 放行 ───
  default_action {
    allow {}
  }

  # ─── 规则 1：Amazon IP 声誉列表 ───
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  # ─── 规则 2：通用规则集（OWASP Top 10 防护）───
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # ─── 规则 3：已知恶意输入规则集 ───
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # ─── 全局可见性配置 ───
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name    = "${var.project_name}-waf"
    Project = var.project_name
  }
}
