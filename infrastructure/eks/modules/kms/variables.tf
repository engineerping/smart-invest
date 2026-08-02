variable "project_name" { type = string }
variable "environment" { type = string }
variable "common_tags" { type = map(string) }

output "key_arn" { value = aws_kms_key.main.arn }
output "key_id" { value = aws_kms_key.main.key_id }
output "key_alias_arn" { value = aws_kms_alias.main.arn }
