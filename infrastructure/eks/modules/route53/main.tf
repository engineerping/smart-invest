# =============================================================================
# Route53 DNS 模块
# =============================================================================
# Amazon Route53 是 AWS 的 DNS 服务
# 作用：把域名（smart-invest.example.com）解析到 CloudFront 的 IP

resource "aws_route53_record" "main" {
  count   = var.route53_zone_id != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = true  # CloudFront 不健康时自动切换
  }
}
