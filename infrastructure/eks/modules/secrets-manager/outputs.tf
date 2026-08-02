output "database_secret_arn" { value = aws_secretsmanager_secret.database.arn }
output "oauth2_secret_arn" { value = aws_secretsmanager_secret.oauth2.arn }
output "mq_secret_arn" { value = aws_secretsmanager_secret.mq.arn }
