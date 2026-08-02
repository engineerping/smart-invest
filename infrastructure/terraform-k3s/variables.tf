# =============================================================================
# terraform-k3s 变量定义
# =============================================================================
# 类比 Java：这里是方法签名，具体值在 terraform.tfvars 或命令行 -var 传入。
# =============================================================================

variable "kubeconfig_path" {
  description = "K3S 集群 kubeconfig 路径"
  type        = string
  default     = "~/.kube/config"
}

variable "postgres_host" {
  description = "宿主机 PostgreSQL 地址（K3S 内访问宿主机的 IP）"
  type        = string
  default     = "192.168.31.192"
}

variable "db_password" {
  description = "数据库密码（演示默认）"
  type        = string
  default     = "bG9jYWxkZXYtb25seQ=="  # base64(localdev_only)，生产应传真实值
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT 签名密钥（所有服务共享）"
  type        = string
  default     = "c21hcnRpbnZlc3QtZGVtby1zZWNyZXQta2V5LWNoYW5nZS1tZS1wbGVhc2UtMzJieXRlcw=="
  sensitive   = true
}

variable "image_tag" {
  description = "镜像版本 tag"
  type        = string
  default     = "latest"
}

variable "replicas" {
  description = "服务副本数"
  type        = number
  default     = 1
}
