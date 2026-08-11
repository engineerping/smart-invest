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
  web_acl_id      = data.aws_wafv2_web_acl.cloudfront_waf.arn
  comment         = ""

  # ─── Origin 1：S3（前端静态资源）───
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "smart-invest-frontend-service-prod-bucket-name.s3.ap-southeast-1.amazonaws.com-mnroxtmimfk"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  # ─── Origin 2：EC2（后端 API）───
  origin {
    domain_name = "ec2-46-137-250-243.ap-southeast-1.compute.amazonaws.com"
    origin_id   = "smart-invest-ec2-backend"

    custom_origin_config {
      http_port                = 8080
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols = ["SSLv3", "TLSv1", "TLSv1.1", "TLSv1.2"]
      origin_read_timeout      = 30
      origin_keepalive_timeout = 5
    }
  }

  # ─── 默认缓存行为：S3 前端（匹配所有非 /api/* 的请求）───
  default_cache_behavior {
    target_origin_id       = "smart-invest-frontend-service-prod-bucket-name.s3.ap-southeast-1.amazonaws.com-mnroxtmimfk"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # ✅ 使用 cache_policy_id 替代 forwarded_values（两者互斥，与实际 CloudFront 配置一致）
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"  # CachingOptimized

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # ─── /api/* 路由行为：EC2 后端 ───
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "smart-invest-ec2-backend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # ✅ 使用 cache_policy_id + origin_request_policy_id 替代 forwarded_values（与实际 CloudFront 配置一致）
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"  # CachingDisabled
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"  # AllViewer

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
# WAF Web ACL —— Web 应用防火墙（只读引用）
# ==============================================================================
# WAF 由 CloudFront 自动创建，使用 data source 只读引用，不由 Terraform 管理。
# 这样 Terraform 不会尝试创建/修改/销毁这个 WAF，避免破坏 CloudFront 的配置。
# ==============================================================================
data "aws_wafv2_web_acl" "cloudfront_waf" {
  provider = aws.us_east_1

  name  = "CreatedByCloudFront-398257e2"
  scope = "CLOUDFRONT"
}
