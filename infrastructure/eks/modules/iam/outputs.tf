output "github_actions_role_arn" { value = aws_iam_role.github_actions.arn }
output "app_service_role_arn" { value = aws_iam_role.app_service.arn }
output "account_id" { value = data.aws_caller_identity.current.account_id }
