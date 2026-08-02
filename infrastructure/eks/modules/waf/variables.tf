variable "project_name" { type = string }
variable "environment" { type = string }
variable "common_tags" { type = map(string) }

output "web_acl_arn" { value = aws_wafv2_web_acl.main.arn }
output "web_acl_id" { value = aws_wafv2_web_acl.main.id }
