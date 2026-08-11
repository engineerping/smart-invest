# ==============================================================================
# CDN 模块 —— 变量定义
# ==============================================================================

variable "project_name" {
  description = "项目名称前缀（用于资源命名）"
  type        = string
  default     = "smart-invest"
}

variable "aws_region" {
  description = "AWS 主部署区域"
  type        = string
  default     = "ap-southeast-1"
}

variable "s3_bucket_name" {
  description = "S3 存储桶名称（必须全局唯一，建议包含账号 ID）。例如：smart-invest-frontend-501264525584"
  type        = string
}

variable "ec2_public_dns" {
  description = "EC2 公网 DNS 名称（CloudFront 回源到 EC2 时用）。示例：ec2-xx-xx-xx-xx.compute.amazonaws.com"
  type        = string
}
