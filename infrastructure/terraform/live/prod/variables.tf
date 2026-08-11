# ==============================================================================
# 变量定义 —— 环境的"输入参数"
# ==============================================================================
# 变量是 Terraform 模块的"输入参数"，类比 Java 方法的形参。
#
# 变量值的优先级（从上到下依次覆盖）：
#   1. 命令行 -var / -var-file      → terraform apply -var="aws_region=us-west-2"
#   2. *.auto.tfvars                → 自动加载的变量文件
#   3. terraform.tfvars             → 默认变量文件
#   4. 环境变量 TF_VAR_<name>      → export TF_VAR_aws_region=ap-southeast-1
#   5. variable 定义中的 default    → 本文件中的 default 值（最低优先级）
#
# 最佳实践：
#   - 敏感信息（密码、密钥）不加 default，强制显式传入
#   - 非敏感信息给合理的 default，降低使用门槛
#   - 生产环境用 tfvars 文件而不是 default
# ==============================================================================

# -------------------------------------------------------------------
# AWS 认证配置
# -------------------------------------------------------------------
variable "aws_profile" {
  description = "AWS CLI profile 名称（对应 ~/.aws/credentials 中的 [profile]）"
  type        = string
  default     = "default"
}

variable "aws_region" {
  description = "AWS 主部署区域（EC2、S3、安全组等资源创建在此区域）"
  type        = string
  default     = "ap-southeast-1" # 新加坡区域，离国内延迟较低
}

# -------------------------------------------------------------------
# 项目基础配置
# -------------------------------------------------------------------
variable "project_name" {
  description = "项目名称前缀（所有资源用这个前缀命名，方便在控制台识别和计费统计）"
  type        = string
  default     = "smart-invest"
}

variable "environment" {
  description = "部署环境标识（prod / staging / dev），可配合 Terraform Workspace 使用"
  type        = string
  default     = "prod"
}

# -------------------------------------------------------------------
# EC2 配置
# -------------------------------------------------------------------
variable "instance_type" {
  description = "EC2 实例类型（决定 vCPU 和内存）。K3S 建议至少 t3.medium（2vCPU, 4GB 内存）"
  type        = string
  default     = "t3.medium"
}

variable "ebs_volume_size" {
  description = "EC2 系统盘大小（GB）。建议至少 20GB，给 Docker 镜像和 K3S 数据留足空间"
  type        = number
  default     = 20
}

variable "key_pair_name" {
  description = "EC2 SSH 密钥对名称（需先在 AWS Console → EC2 → Key Pairs 中创建）"
  type        = string
  default     = "smart-invest-ec2-keypair"
}

# -------------------------------------------------------------------
# S3 / CloudFront 配置
# -------------------------------------------------------------------
variable "s3_bucket_name" {
  description = "前端 S3 存储桶名称（必须是全局唯一的！建议加随机后缀或账号 ID）"
  type        = string
  default     = "smart-invest-frontend-service-prod-bucket-name"
}

# -------------------------------------------------------------------
# 管理员 IP（SSH 安全加固）—— 强烈建议配置！
# -------------------------------------------------------------------
variable "admin_cidr" {
  description = "管理员公网 IP 的 CIDR 格式（如 '203.0.113.5/32'）。用于 SSH 白名单，限制只有你的 IP 能登录"
  type        = string
  default     = "0.0.0.0/0" # ⚠️ 生产环境必须改为你的固定 IP！
  sensitive   = false        # 不是敏感信息，可以在 plan 输出中显示
}
