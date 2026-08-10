# ==============================================================================
# CDN 模块 —— CloudFront + S3 + WAF（前端静态资源托管 + 全球加速 + 防火墙）
# ==============================================================================
#
# 一句话理解：
#   这 个 模 块 负 责 前 端 的 静 态 文 件 存 储（S3）、全 球 加 速（CloudFront）
#   和 Web 防 护（WAF）。
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
# CloudFront 核心概念速览
# ==============================================================================
# ┌──────────────────┬──────────────────────────────────────────────┐
# │ 概念             │ 说明                                        │
# ├──────────────────┼──────────────────────────────────────────────┤
# │ Distribution     │ CloudFront 分发实例（一个 CDN 资源）         │
# │ Origin           │ 源站（内容的实际来源：S3 或 EC2）            │
# │ Behavior         │ 缓存行为规则（定义不同路径怎么处理）          │
# │ OAC              │ Origin Access Control（CloudFront→S3 认证）  │
# │ Edge Location    │ 边缘节点（全球 400+ 个，就近服务用户）        │
# └──────────────────┴──────────────────────────────────────────────┘
#
# ==============================================================================
# WAF（Web Application Firewall）核心概念
# ==============================================================================
# WAF = Web 应用防火墙，站在 CloudFront 前面做安检。
#
# AWS 托管规则组（Managed Rule Groups）—— AWS 安全团队维护的规则，自动更新：
#   - AmazonIPReputationList：拦截已知恶意 IP（僵尸网络、垃圾邮件）
#   - CommonRuleSet (CRS)：防护 OWASP Top 10（SQL 注入、XSS 等）
#   - KnownBadInputsRuleSet：拦截已知攻击载荷模式
#
# WAF 必须部署在 us-east-1（AWS 硬性规定），所以需要单独的 provider。
# ==============================================================================

# ==============================================================================
# S3 Bucket —— 前端静态文件存储
# ==============================================================================
# S3（Simple Storage Service）= AWS 的对象存储服务。
# "对象存储"就是存文件的，但不能像文件系统一样随意修改文件中间的内容，
# 只能整体上传/下载/删除。非常适合存图片、视频、前端 HTML/JS/CSS 等静态文件。
# ==============================================================================

# ─── S3 存储桶 ───
resource "aws_s3_bucket" "frontend" {
  bucket = var.s3_bucket_name # 存储桶名称（必须是全局唯一的！）

  tags = {
    Name    = "${var.project_name}-frontend"
    Project = var.project_name
  }
}

# ─── 阻止所有公共访问 ───
# 这是安全必开项。S3 的"公共访问"如果开着，等于任何人有了你的桶名就能下载文件。
# 四个参数全部 block = true → 完全不允许公共访问。
# 前端文件通过 CloudFront（有 OAC 认证）访问，不是直接访问 S3。
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true # 阻止公共 ACL（访问控制列表）
  block_public_policy     = true # 阻止公共桶策略
  ignore_public_acls      = true # 忽略公共 ACL（即使有人设置了）
  restrict_public_buckets = true # 限制公共桶的访问
}

# ─── 版本控制 ───
# 启用后，每次覆盖文件都会保留旧版本，可以回滚。
# 对前端部署非常有用——万一新版本有 bug，可以秒级回滚到上个版本。
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ─── S3 存储桶策略 ───
# 这个策略规定：只有通过 CloudFront 才能访问 S3 中的文件。
# 防止用户绕过 CloudFront 直接访问 S3（绕过 CDN 加速和安全防护）。
resource "aws_s3_bucket_policy" "frontend" {
  bucket     = aws_s3_bucket.frontend.id
  depends_on = [aws_s3_bucket_public_access_block.frontend] # 确保先阻止公共访问，再授权 CloudFront

  # jsonencode() 把 Terraform 的 HCL 对象转成 JSON 字符串
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com" # 只允许 CloudFront 服务读取
        }
        Action   = "s3:GetObject" # 只允许读操作（获取文件）
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn # 限定只能从本 Distribution 访问
          }
        }
      }
    ]
  })
}

# ==============================================================================
# OAC（Origin Access Control）—— CloudFront 访问 S3 的凭证
# ==============================================================================
# OAC 是 CloudFront 访问 S3 时用的认证方式（替代了旧的 OAI）。
# 它让 CloudFront 用 SigV4 签名的方式请求 S3，S3 验证签名后才放行。
# 这样即使别人拿到了 S3 的直接 URL，没有正确的签名也访问不了。
# ==============================================================================
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${var.project_name}-s3-oac"
  origin_access_control_origin_type = "s3"        # 目标是 S3
  signing_behavior                  = "always"    # 始终对请求签名
  signing_protocol                  = "sigv4"     # AWS Signature Version 4
}

# ==============================================================================
# CloudFront Distribution —— CDN 分发
# ==============================================================================
# Distribution 是 CloudFront 的核心资源，定义了 CDN 的完整行为：
#   有哪些源站（S3 + EC2）、每个路径怎么缓存、用什么证书、有什么限制。
# ==============================================================================
resource "aws_cloudfront_distribution" "main" {
  enabled         = true            # 启用分发
  is_ipv6_enabled = true            # 支持 IPv6
  http_version    = "http2"         # HTTP/2 协议（多路复用，性能更好）
  web_acl_id      = aws_wafv2_web_acl.cloudfront_waf.arn # 绑定 WAF
  comment         = "${var.project_name} CDN 分发"

  # ══════════════════════════════════════════════════════════════════════
  # Origin 1：S3（前端静态资源）
  # ══════════════════════════════════════════════════════════════════════
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id # 通过 OAC 认证
  }

  # ══════════════════════════════════════════════════════════════════════
  # Origin 2：EC2（后端 API）
  # ══════════════════════════════════════════════════════════════════════
  origin {
    domain_name = var.ec2_public_dns # EC2 的公网 DNS 名称
    origin_id   = "ec2-backend"

    # custom_origin_config = 非 S3 的源站都需要这个配置
    custom_origin_config {
      http_port              = 8080                     # EC2 后端监听 8080
      https_port             = 443
      origin_protocol_policy = "http-only"              # 回源用 HTTP（CloudFront → EC2 走内网 HTTP）
      origin_ssl_protocols   = ["TLSv1.2"]             # 如果 HTTPS 回源，最低 TLS 1.2
    }
  }

  # ══════════════════════════════════════════════════════════════════════
  # 默认缓存行为：S3 前端（匹配所有非 /api/* 的请求）
  # ══════════════════════════════════════════════════════════════════════
  default_cache_behavior {
    target_origin_id       = "s3-frontend"              # 路由到 S3
    viewer_protocol_policy = "redirect-to-https"        # HTTP 自动重定向到 HTTPS
    allowed_methods        = ["GET", "HEAD"]            # 前端文件只读
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false # 不转发查询参数（前端静态文件不需要）
      cookies {
        forward = "none" # 不转发 Cookie（静态文件不需要）
      }
    }

    min_ttl     = 0       # 最小缓存时间 0 秒
    default_ttl = 3600    # 默认缓存 1 小时
    max_ttl     = 86400   # 最长缓存 24 小时
  }

  # ══════════════════════════════════════════════════════════════════════
  # /api/* 路由行为：EC2 后端
  # ══════════════════════════════════════════════════════════════════════
  ordered_cache_behavior {
    path_pattern           = "/api/*"                   # 匹配所有 /api/ 开头的请求
    target_origin_id       = "ec2-backend"              # 路由到 EC2
    viewer_protocol_policy = "https-only"               # API 必须 HTTPS
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]            # 只缓存 GET 和 HEAD

    forwarded_values {
      query_string = true                           # 转发查询参数（API 请求可能有 ?page=1&size=10）
      headers      = ["Authorization", "Content-Type"] # 转发这两个关键请求头
      cookies {
        forward = "all" # 转发所有 Cookie（API 可能需要 session）
      }
    }

    min_ttl     = 0 # API 响应不缓存（动态数据，每次都从后端取最新值）
    default_ttl = 0
    max_ttl     = 0
  }

  # ══════════════════════════════════════════════════════════════════════
  # SPA 路由支持：403/404 → index.html
  # ══════════════════════════════════════════════════════════════════════
  # SPA（Single Page Application）如 React/Vue/Angular，路由在前端处理。
  # 用户访问 /dashboard 时，S3 上没有 /dashboard 这个文件，
  # S3 返回 404 → CloudFront 不返回 404 页面，而是返回 /index.html (200 OK)
  # 前端的 JS Router 读取 URL 中 /dashboard 路径，渲染对应的组件。
  custom_error_response {
    error_code            = 403                     # 权限不足 → 返回 index.html
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10                      # 错误响应缓存 10 秒
  }

  custom_error_response {
    error_code            = 404                     # 文件不存在 → 返回 index.html
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  # ══════════════════════════════════════════════════════════════════════
  # 地理限制：none = 全球可访问
  # ══════════════════════════════════════════════════════════════════════
  restrictions {
    geo_restriction {
      restriction_type = "none" # 不限制。如需仅限中国，改为 whitelist + 添加 CN
    }
  }

  # ══════════════════════════════════════════════════════════════════════
  # SSL 证书：使用 CloudFront 默认证书
  # ══════════════════════════════════════════════════════════════════════
  # cloudfront_default_certificate = 免费的 *.cloudfront.net 证书。
  # 如果需要自定义域名（如 app.yourcompany.com），需要：
  #   1. 在 AWS Certificate Manager (ACM) 申请证书（必须在 us-east-1 区域）
  #   2. 设置 aliases 字段
  #   3. 设置 viewer_certificate.acm_certificate_arn
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name    = "${var.project_name}-cloudfront"
    Project = var.project_name
  }
}

# ==============================================================================
# WAF Web ACL —— Web 应用防火墙
# ==============================================================================
# Web ACL（Access Control List）是 WAF 的核心资源。
# 它包含一组规则，每条规则定义了"什么样的请求应该拦截"。
#
# 注意：这个资源必须在 us-east-1 创建（CloudFront 的硬性要求）。
# 所以在 main.tf 中要声明一个别名为 us_east_1 的 AWS provider 来管理它。
# ==============================================================================
resource "aws_wafv2_web_acl" "cloudfront_waf" {
  # ─── 使用 us-east-1 的 provider ───
  # provider = aws.us_east_1 必须在调用这个模块时通过 providers 元参数传入
  provider = aws.us_east_1

  name  = "${var.project_name}-waf"
  scope = "CLOUDFRONT" # CloudFront 模式（全球生效，必须 us-east-1）
  description = "WAF for ${var.project_name} CloudFront distribution"

  # ─── 默认动作：不匹配任何规则 → 放行 ───
  default_action {
    allow {}
  }

  # ─── 规则 1：Amazon IP 声誉列表 ───
  # 自动拦截已知的恶意 IP（由 AWS 威胁研究团队持续更新）。
  # 这是 AWS 自带的"黑名单"，不需要你手动维护。
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 0

    # override_action { none {} } = 不覆盖，执行规则组的默认动作（通常是 Block）
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
      sampled_requests_enabled   = true # 开启采样，可以在 WAF 控制台看被拦截的具体请求内容
    }
  }

  # ─── 规则 2：通用规则集（OWASP Top 10 防护）───
  # 防护：SQL 注入、跨站脚本（XSS）、HTTP 协议违规、本地文件包含等
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
  # 检测攻击载荷中的恶意模式（路径遍历攻击、特殊编码攻击等）
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
  # 定义 WAF 的总体指标和采样设置
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
