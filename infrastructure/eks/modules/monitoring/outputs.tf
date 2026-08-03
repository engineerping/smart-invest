output "grafana_url" {
  description = "Grafana 监控面板 URL"
  value       = "https://grafana.smart-invest.example.com"
}
output "sns_topic_arn" { value = aws_sns_topic.alerts.arn }
