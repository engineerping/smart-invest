variable "domain_name" { type = string }
variable "route53_zone_id" { type = string }
variable "common_tags" { type = map(string) }

output "certificate_arn" { value = aws_acm_certificate_validation.main.certificate_arn }
