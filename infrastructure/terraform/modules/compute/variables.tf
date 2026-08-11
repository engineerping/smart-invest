# ==============================================================================
# Compute 模块 —— 变量定义
# ==============================================================================

variable "project_name" {
  description = "项目名称前缀（用于资源命名和标签）"
  type        = string
  default     = "smart-invest"
}

variable "instance_type" {
  description = "EC2 实例类型（决定 vCPU 和内存）。K3S 建议至少 t3.medium（2vCPU, 4GB）"
  type        = string
  default     = "t3.medium" # 原 t3.micro 不够跑 K3S，建议先扩容到 t3.medium
}

variable "ami_id_override" {
  description = "手动指定 AMI ID（不填则自动使用最新的 Amazon Linux 2023）"
  type        = string
  default     = "" # 空 = 自动查最新的
}

variable "ebs_volume_size" {
  description = "EC2 系统盘大小（GB）。建议至少 20GB，给 K3S + Docker 镜像留足空间"
  type        = number
  default     = 30
}

variable "key_pair_name" {
  description = "EC2 SSH 密钥对名称（需先在 AWS Console → EC2 → Key Pairs 中创建）"
  type        = string
  default     = "smart-invest-ec2-keypair"
}

variable "public_subnet_id" {
  description = "公有子网 ID（从 networking 模块传入）"
  type        = string
}

variable "security_group_id" {
  description = "安全组 ID（从 networking 模块传入）"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM Instance Profile 名称（从 iam 模块传入，给 EC2 访问 AWS 服务的权限）"
  type        = string
}
