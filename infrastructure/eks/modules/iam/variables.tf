variable "project_name" { type = string }
variable "environment" { type = string }
variable "common_tags" { type = map(string) }
variable "oidc_provider_url" { type = string }
variable "oidc_provider_arn" { type = string }

output "github_actions_role_arn" { value = aws_iam_role.github_actions.arn }
output "app_service_role_arn" { value = aws_iam_role.app_service.arn }
