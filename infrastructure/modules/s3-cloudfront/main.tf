# =============================================================================
# S3 + CloudFront 模块 —— 前端静态托管 + CDN 加速
# =============================================================================
# 这个模块为前端应用提供高性能、高可用的静态文件托管方案。
#
# 架构：
#   用户 ──▶ CloudFront (CDN) ──▶ S3 (静态文件存储)
#           边缘节点缓存         源站（Origin）
#
# 为什么不用直接用 S3 静态网站托管？
#   1. HTTPS: S3 静态托管不支持 HTTPS，CloudFront 自带 HTTPS 证书
#   2. CDN 加速: CloudFront 全球 400+ 边缘节点，就近返回内容（延迟从 200ms → 10ms）
#   3. 缓存优化: 可缓存静态资源（JS/CSS/图片），减少 S3 请求费用
#   4. 安全: OAC 确保 S3 只接受来自 CloudFront 的请求，S3 不直接暴露
#   5. 自定义域名: CloudFront 支持 CNAME + ACM SSL 证书
#   6. SPA 路由: CloudFront 可以配置 404 → /index.html（React/Vue SPA 需要）
#
# 费用分析：
#   - S3 存储: ~$0.023/GB/月（标准层）
#   - S3 请求: ~$0.005/1000 次 GET
#   - CloudFront 流量: ~$0.085/GB（美国），其他区域更贵
#   - 对于小项目，总费用通常 < $1/月
# =============================================================================

# =============================================================================
# S3 Bucket —— 前端静态文件存储
# =============================================================================
# S3（Simple Storage Service）是 AWS 的对象存储服务。
# "对象存储" = 不需要文件系统的存储，按 key 存/取数据。
#
# S3 的核心概念：
#   - Bucket（桶）: 顶层容器，名称全局唯一（所有 AWS 用户不能重名）
#   - Object（对象）: 文件，由 Key（路径）+ Value（文件内容）组成
#   - Key: 对象的唯一标识，如 index.html、static/js/main.js
#
# Bucket 命名规则：
#   - 3-63 个字符（小写字母、数字、点、连字符）
#   - 不能以 IP 地址格式命名
#   - 全局唯一（即使其他 AWS 账号用了也不能重名）
#   - 这里用 account_id 后缀确保唯一性
#
# 使用方式（前端部署）：
#   npm run build                              # 构建前端产物到 dist/
#   aws s3 sync dist/ s3://<bucket-name>/     # 同步到 S3
#   aws cloudfront create-invalidation ...     # 刷新 CDN 缓存
# =============================================================================
resource "aws_s3_bucket" "frontend" {
  bucket = "smart-invest-frontend-${var.account_id}"   # account_id 保证全局唯一
}

# =============================================================================
# S3 公共访问阻止 —— 安全加固
# =============================================================================
# 这是 AWS 2023 年新增的安全功能，全面阻止 S3 Bucket 的公开访问。
#
# 四项保护：
#   1. block_public_acls:       阻止创建公开的 ACL（访问控制列表）
#   2. block_public_policy:     阻止挂载公开的 Bucket Policy
#   3. ignore_public_acls:      忽略已有的公开 ACL（即使设置了也无效）
#   4. restrict_public_buckets: 限制公开 Bucket 只能被同账号内的认证用户访问
#
# 全部设为 true = 最严格的安全策略。
# 前端文件虽然"公开"给互联网访问，但通过 CloudFront OAC 控制，
# S3 本身不对公网开放 —— 这叫 "Private Bucket, Public CDN"。
#
# 为什么不用 Bucket Policy 公开 S3？
#   - 安全风险：配置错误可能导致数据泄露
#   - 审计要求：S3 公开访问会被 AWS Security Hub 标记为高风险
#   - 最佳实践：始终通过 CloudFront 分发，S3 作为私有源站
# =============================================================================
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true    # 阻止公开 ACL
  block_public_policy     = true    # 阻止公开 Bucket Policy
  ignore_public_acls      = true    # 忽略所有公开 ACL
  restrict_public_buckets = true    # 限制公开 Bucket 访问
}

# =============================================================================
# CloudFront Origin Access Control (OAC) —— 安全的源站访问
# =============================================================================
# OAC 是 CloudFront 访问 S3 的认证机制。
# 工作原理：
#   1. CloudFront 向 S3 发请求时，用 SigV4 签名认证
#   2. S3 验证签名，确认请求来自 CloudFront（不是匿名用户）
#   3. 不需要公开 S3 Bucket 或用 OAI（旧方案）
#
# OAC vs OAI（Origin Access Identity，旧方案）：
#   - OAC: 2022 年新方案，支持 SigV4 签名、更细粒度的权限控制
#   - OAI: 已过时，AWS 推荐迁移到 OAC
#   - 本项目使用 OAC（现代最佳实践）
#
# signing_behavior = "always": 所有请求都签名（包括 GET），最高安全级别
# signing_protocol = "sigv4":  AWS Signature Version 4（当前标准签名算法）
# =============================================================================
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "smart-invest-oac"
  origin_access_control_origin_type = "s3"       # 源类型：S3
  signing_behavior                  = "always"    # 始终签名（不放过任何未签名请求）
  signing_protocol                   = "sigv4"    # 使用 SigV4 签名协议
}

# =============================================================================
# CloudFront Distribution —— CDN 分发
# =============================================================================
# CloudFront 是 AWS 的 CDN（Content Delivery Network）服务。
#
# CDN 原理：
#   1. 用户请求 cloudfront.net 域名
#   2. DNS 解析到最近的边缘节点（Edge Location）
#   3. 如果节点有缓存 → 直接返回（缓存命中，Cache Hit）
#   4. 如果节点没缓存 → 回源 S3 获取 → 缓存 → 返回（缓存未命中，Cache Miss）
#   5. 后续同一区域的用户都走缓存（延迟大幅降低）
#
# CloudFront 全球网络：
#   全球 400+ 个边缘节点（Edge Location）和 13 个区域边缘缓存
#   中国没有节点，但可以通过 Route 53 延迟路由到最近的海外节点
#
# 价格等级（Price Class）说明：
#   - PriceClass_100: 仅北美+欧洲（最便宜，小项目够用）
#   - PriceClass_200: 北美+欧洲+亚洲+中东+非洲（中等）
#   - PriceClass_All: 全球所有节点（最贵，全球业务用）
#
# PriceClass_All 比 PriceClass_100 贵约 20-30%，但覆盖全球。
# =============================================================================
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true                     # 启用分发
  default_root_object = "index.html"             # 默认首页（访问 / 时返回 index.html）
  price_class         = "PriceClass_100"         # 仅北美+欧洲节点（节省成本）

  # -------------------------------------------------------------------
  # origin: 定义源站（S3）
  #
  # CloudFront 从这里获取原始内容。
  # bucket_regional_domain_name:
  #   S3 的区域域名，如 smart-invest-frontend-123.s3.us-east-1.amazonaws.com
  #   比 bucket 的全局域名性能更好（DNS 解析更快）
  # -------------------------------------------------------------------
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-smart-invest"              # 源的唯一标识（在 cache_behavior 中引用）
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id   # 用 OAC 签名认证
  }

  # -------------------------------------------------------------------
  # default_cache_behavior: 默认缓存行为
  #
  # 定义对源站请求的缓存和处理规则。
  # 这是所有路径的默认规则（除非有额外的 ordered_cache_behavior 覆盖）。
  #
  # 缓存策略说明：
  #   - allowed_methods: 允许的 HTTP 方法（GET + HEAD = 只读，安全）
  #   - cached_methods: 哪些方法的响应可以缓存
  #   - viewer_protocol_policy: 强制 HTTPS（HTTP → HTTPS 301 重定向）
  #   - compress: 自动压缩文本内容（gzip/brotli），减小传输体积
  #   - forwarded_values: 转发给源站的参数（不转发查询字符串和 Cookie）
  # -------------------------------------------------------------------
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]           # 允许的 HTTP 方法（只读操作）
    cached_methods         = ["GET", "HEAD"]           # 可以缓存的方法
    target_origin_id       = "S3-smart-invest"         # 指向上面定义的 S3 源
    viewer_protocol_policy = "redirect-to-https"       # 强制 HTTPS（HTTP 自动跳转到 HTTPS）
    compress               = true                       # 启用 Gzip/Brotli 自动压缩

    forwarded_values {
      query_string = false           # 不转发查询字符串（?key=value 部分）
      cookies { forward = "none" }   # 不转发 Cookie
    }
  }

  # -------------------------------------------------------------------
  # custom_error_response: 自定义错误响应
  #
  # SPA（Single Page Application）路由支持。
  # React/Vue/Angular 用前端路由（如 /users/123），这些路径在 S3 中不实际存在。
  # 访问 /users/123 时 S3 返回 404 → CloudFront 返回 /index.html (200) → 前端路由接管
  #
  # 原理：
  #   1. 用户访问 /dashboard
  #   2. S3 没有 /dashboard 这个文件，返回 404
  #   3. CloudFront 拦截 404，返回 /index.html 内容，状态码改为 200
  #   4. 浏览器收到 index.html
  #   5. React Router 读取 URL 的 /dashboard，渲染对应页面
  #
  # 如果没有这个配置，直接访问非根路径会显示 CloudFront 404 错误页。
  # -------------------------------------------------------------------
  custom_error_response {
    error_code         = 404              # 源站返回 404 时触发
    response_code      = 200              # 改为返回 200 状态码
    response_page_path = "/index.html"    # 返回 index.html 的内容
  }

  # -------------------------------------------------------------------
  # restrictions: 地理限制
  #
  # 可以按国家/地区限制或允许访问。
  # - none: 不限制（全球可访问）
  # - whitelist: 只允许列表中的国家
  # - blacklist: 禁止列表中的国家
  #
  # 合规场景下会用到（如金融应用限制某些国家访问）。
  # -------------------------------------------------------------------
  restrictions {
    geo_restriction {
      restriction_type = "none"     # 不限制全球访问
    }
  }

  # -------------------------------------------------------------------
  # viewer_certificate: HTTPS 证书配置
  #
  # cloudfront_default_certificate = true:
  #   使用 CloudFront 的默认证书（*.cloudfront.net）。
  #   免费、自动续期，但域名是 <random>.cloudfront.net。
  #
  # 如果要使用自定义域名（如 app.smartinvest.com），需要：
  #   1. 在 ACM（AWS Certificate Manager）中申请 SSL 证书
  #   2. 添加 aliases = ["app.smartinvest.com"]
  #   3. 设置 acm_certificate_arn = <证书 ARN>
  #   4. 在 DNS（Route 53）中添加 CNAME 记录指向 CloudFront 域名
  # -------------------------------------------------------------------
  viewer_certificate { cloudfront_default_certificate = true }
}
