variable "project_name" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "cluster_version" { type = string }
variable "node_instance_types" { type = list(string) }
variable "node_desired_size" { type = number }
variable "node_max_size" { type = number }
variable "node_min_size" { type = number }
variable "eks_node_sg_id" { type = string }
variable "cluster_sg_id" { type = string }
variable "common_tags" { type = map(string) }

# 允许外部传入 ALB DNS（因为 ALB 由 K8s Load Balancer Controller 动态创建）
variable "alb_dns_name_override" {
  description = "ALB DNS 名覆盖值，部署后从 K8s 获取并填入"
  type        = string
  default     = ""
}
