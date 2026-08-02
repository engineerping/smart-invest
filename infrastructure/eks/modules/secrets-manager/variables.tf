variable "project_name" { type = string }
variable "environment" { type = string }
variable "kms_key_id" { type = string }
variable "common_tags" { type = map(string) }

output "database_secret_arn" { value = aws_secretsmanager_secret.database.arn }
output "oauth2_secret_arn" { value = aws_secretsmanager_secret.oauth2.arn }
output "mq_secret_arn" { value = aws_secretsmanager_secret.mq.arn }
