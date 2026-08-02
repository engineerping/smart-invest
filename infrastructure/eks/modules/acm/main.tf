# =============================================================================
# ACM 模块 - SSL/TLS 证书管理
# =============================================================================
# AWS Certificate Manager (ACM) 用来申请、管理和自动续签 SSL/TLS 证书
# ACM 免费，且自动续签（前提是 DNS 验证或邮箱验证通过）
#
# 通信加密链：
#   Browser --[TLS/HTTPS]--> CloudFront --[TLS]--> ALB/NLB  --[mTLS/Istio]--> Pod
#            (ACM 证书)              (ACM 证书)       (Istio 自动 mTLS)
#
# DNS 验证 vs Email 验证：
#   DNS 验证：在 Route53 添加 CNAME 记录（推荐，支持自动续签）
#   Email 验证：发邮件给域名管理员确认

resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"  # DNS 验证，支持自动续签

  # SAN 证书：一个证书覆盖多个子域名
  subject_alternative_names = [
    "*.${var.domain_name}",           # 通配符：所有子域名（api.xxx, www.xxx）
    "www.${var.domain_name}",
    "api.${var.domain_name}",
    "admin.${var.domain_name}",
  ]

  # 金融系统建议使用 RSA 2048+
  key_algorithm = "RSA_2048"

  # 证书生命周期
  lifecycle {
    create_before_destroy = true  # 更新证书时先创建新的，再删除旧的
  }

  tags = merge(var.common_tags, {
    Name = "${var.domain_name}-cert"
  })
}

# DNS 验证记录（自动添加到 Route53）
# 如果 route53_zone_id 已指定，自动创建验证记录
resource "aws_route53_record" "acm_validation" {
  for_each = var.route53_zone_id != "" ? {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 300
}

# 证书验证（等待 DNS 验证完成后证书才能生效）
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}
