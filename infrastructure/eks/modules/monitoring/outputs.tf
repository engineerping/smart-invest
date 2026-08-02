output "grafana_url" { value = "https://grafana.smart-invest.example.com" }
output "sns_topic_arn" { value = aws_sns_topic.alerts.arn }
