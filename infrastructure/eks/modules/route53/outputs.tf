# Route53 模块 - 输出变量

output "dns_record_fqdn" {
  description = "DNS 记录的完全限定域名"
  value       = var.route53_zone_id != "" ? aws_route53_record.main[0].fqdn : var.domain_name
}
