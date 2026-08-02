variable "project_name" { type = string }
variable "environment" { type = string }
variable "domain_name" { type = string }
variable "acm_certificate_arn" { type = string }
variable "waf_web_acl_arn" { type = string }
variable "s3_bucket_domain" { type = string }
variable "alb_dns_name" { type = string }
variable "common_tags" { type = map(string) }
