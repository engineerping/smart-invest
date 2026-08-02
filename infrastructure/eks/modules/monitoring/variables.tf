variable "project_name" { type = string }
variable "environment" { type = string }
variable "eks_cluster_name" { type = string }
variable "eks_cluster_endpoint" { type = string }
variable "eks_cluster_ca_cert" { type = string }
variable "eks_cluster_token" { type = string }
variable "aurora_cluster_id" { type = string }
variable "elasticache_cluster_id" { type = string }
variable "common_tags" { type = map(string) }

output "grafana_url" { value = "https://grafana.${var.external_domain}" }
output "sns_topic_arn" { value = aws_sns_topic.alerts.arn }

variable "external_domain" {
  type    = string
  default = "smart-invest.example.com"
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}
