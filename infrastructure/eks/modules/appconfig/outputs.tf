# AppConfig 模块 - 输出变量

output "application_id" {
  description = "AppConfig 应用 ID"
  value       = aws_appconfig_application.main.id
}

output "configuration_profile_id" {
  description = "配置档案 ID"
  value       = aws_appconfig_configuration_profile.main.id
}

output "environment_id" {
  description = "AppConfig 环境 ID"
  value       = aws_appconfig_environment.main.id
}
