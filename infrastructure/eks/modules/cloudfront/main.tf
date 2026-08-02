# =============================================================================
# CloudFront CDN 模块
# =============================================================================
# Amazon CloudFront 是 AWS 的 CDN（内容分发网络）
# 全球 450+ 边缘节点，用户从最近的节点获取内容，降低延迟
#
# 在本项目中的架构位置：
#   用户 → Route53 DNS → CloudFront → WAF(过滤攻击) → ALB/NLB → Kong → 微服务
#                                     ↓ (静态资源)
#                                   S3 桶
#
# 核心概念：
#   - Distribution：CDN 分配，每个域名一个
#   - Origin：源站（S3 / ALB / 自定义 HTTP 服务器）
#   - Behavior：缓存行为规则（哪些路径缓存、缓存多久、哪些头传递等）
#   - OAC (Origin Access Control)：CloudFront 访问 S3 的安全控制

resource "aws_cloudfront_distribution" "main" {
  comment = "${var.project_name}-${var.environment} CloudFront Distribution"

  # --- 动态内容源站：ALB（API 请求）---
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "ALB-${var.project_name}-${var.environment}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"   # 源站只接受 HTTPS
      origin_ssl_protocols   = ["TLSv1.2"]    # 只允许 TLS 1.2+
      origin_keepalive_timeout = 60
      origin_read_timeout      = 30
    }
  }

  # --- 静态内容源站：S3（前端 JS/CSS/HTML）---
  origin {
    domain_name = var.s3_bucket_domain
    origin_id   = "S3-${var.project_name}-${var.environment}"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  # --- 启用 CDN ---
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_All"  # 全球节点（可根据预算缩小到特定区域）

  # --- WAF 集成 ---
  web_acl_id = var.waf_web_acl_arn

  # --- 域名配置 ---
  aliases = [var.domain_name]

  # --- 默认缓存行为 ---
  # 默认指向 API（动态内容）
  default_cache_behavior {
    target_origin_id       = "ALB-${var.project_name}-${var.environment}"
    viewer_protocol_policy = "redirect-to-https"  # HTTP 自动跳转 HTTPS
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]

    # 缓存策略：动态 API 不缓存（CacheDisabled）
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # 源请求策略：传递所有必要的头部
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"

    # 转发到源站的头部
    forwarded_values {
      query_string = true
      headers      = [
        "Authorization",
        "Origin",
        "Accept",
        "Content-Type",
        "X-Forwarded-For",
        "X-Correlation-ID",  # 自定义链路追踪 ID
      ]
      cookies {
        forward = "all"
      }
    }
  }

  # --- 静态资源缓存行为（/static/* 和 /assets/*）---
  ordered_cache_behavior {
    path_pattern           = "/static/*"
    target_origin_id       = "S3-${var.project_name}-${var.environment}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]

    # 静态资源缓存策略（CachingOptimized）
    # 默认 TTL：86400 秒（1天），最大 31536000 秒（1年）
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88669e58f6"

    forwarded_values {
      query_string = false  # 静态资源不依赖查询参数，关闭以提升缓存命中率
      cookies {
        forward = "none"
      }
    }
  }

  ordered_cache_behavior {
    path_pattern           = "/assets/*"
    target_origin_id       = "S3-${var.project_name}-${var.environment}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88669e58f6"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # --- 查看器证书 ---
  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method        = "sni-only"
    minimum_protocol_version  = "TLSv1.2_2021"
  }

  # --- 地理限制（可选）---
  # 如果只对特定国家服务，可以开启
  # restrictions {
  #   geo_restriction {
  #     restriction_type = "whitelist"
  #     locations        = ["HK", "SG", "CN"]  # 香港、新加坡、中国
  #   }
  # }

  # --- 日志记录 ---
  logging_config {
    include_cookies = false
    bucket          = "${var.project_name}-${var.environment}-logs.s3.amazonaws.com"
    prefix          = "cloudfront/"
  }

  tags = var.common_tags
}

# Origin Access Control：安全访问 S3 源站
resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${var.project_name}-${var.environment}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
