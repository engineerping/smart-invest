variable "project_name" { type = string }
variable "environment" { type = string }
variable "kms_key_arn" { type = string }
variable "common_tags" { type = map(string) }

# CloudFront Distribution ARN（由 cloudfront 模块创建，用于 S3 桶策略）
variable "cloudfront_distribution_arn" {
  description = "CloudFront 分配的 ARN，S3 桶策略通过它限制只有 CloudFront 能读取"
  type        = string
  default     = ""
}
