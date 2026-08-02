# =============================================================================
# 输入变量定义
# =============================================================================
# Terraform 最佳实践：把所有可能变化的参数定义为变量
# 这样做的好处：
#   1. 同一套代码可以部署 DEV/UAT/PRD 多套环境，只需换不同的 tfvars 文件
#   2. 敏感信息（密码等）通过变量传入，不会硬编码在代码中
#   3. 代码复用性高，可以在不同项目间共享

# ==============================
# AWS 区域配置
# ==============================

variable "aws_region" {
  description = "AWS 主区域，所有核心资源部署在该区域"
  type        = string
  default     = "ap-southeast-1"  # 新加坡，延迟低，对亚洲用户友好
}

variable "dr_region" {
  description = "容灾备用区域，两地三中心中的'另一地'"
  type        = string
  default     = "ap-southeast-3"  # 雅加达，与新加坡有一定地理隔离
}

variable "account_id" {
  description = "AWS 账号 ID（12位数字）"
  type        = string
}

# ==============================
# 环境标识
# ==============================

variable "environment" {
  description = "部署环境：dev / uat / prd"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "uat", "prd"], var.environment)
    error_message = "环境只能是 dev / uat / prd 之一"
  }
}

variable "project_name" {
  description = "项目名称，用作资源的命名前缀"
  type        = string
  default     = "smart-invest"
}

# ==============================
# 网络配置
# ==============================

variable "vpc_cidr" {
  description = "VPC 的 CIDR 地址块（定义 VPC 内可用的 IP 范围）"
  type        = string
  default     = "10.0.0.0/16"  # 10.0.0.0 ~ 10.0.255.255，共 65536 个 IP
}

variable "availability_zones" {
  description = "可用区列表（物理隔离的数据中心，一个 AZ 故障不影响另一个）"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}

# ==============================
# EKS 集群配置
# ==============================

variable "eks_cluster_version" {
  description = "Kubernetes 版本"
  type        = string
  default     = "1.29"  # 建议使用 EKS 支持的稳定版本
}

variable "eks_node_instance_types" {
  description = "Worker 节点的 EC2 实例类型"
  type        = list(string)
  default     = ["t3.medium", "t3.large"]  # t3 系列适合通用工作负载
}

variable "eks_node_desired_size" {
  description = "Worker 节点组的期望节点数"
  type        = number
  default     = 3  # 至少3个节点，分布在3个 AZ，保证高可用
}

variable "eks_node_max_size" {
  description = "Worker 节点组的最大节点数（用于 Cluster Autoscaler）"
  type        = number
  default     = 10
}

variable "eks_node_min_size" {
  description = "Worker 节点组的最小节点数"
  type        = number
  default     = 2
}

# ==============================
# 数据库配置
# ==============================

variable "aurora_instance_count" {
  description = "Aurora 集群实例数量（Multi-AZ 至少需要 2 个）"
  type        = number
  default     = 2
}

variable "aurora_instance_class" {
  description = "Aurora 数据库实例规格"
  type        = string
  default     = "db.r6g.large"  # Graviton2 处理器，性价比高
}

variable "aurora_database_name" {
  description = "数据库名称"
  type        = string
  default     = "smartinvest"
}

variable "aurora_master_username" {
  description = "数据库主用户名称（密码通过 Secrets Manager 管理）"
  type        = string
  default     = "dbadmin"
}

# ==============================
# Redis 缓存配置
# ==============================

variable "elasticache_instance_type" {
  description = "ElastiCache Redis 节点规格"
  type        = string
  default     = "cache.t3.medium"
}

variable "elasticache_num_cache_nodes" {
  description = "Redis 集群节点数（1个=单节点，2个以上=带副本）"
  type        = number
  default     = 2
}

# ==============================
# 域名配置
# ==============================

variable "domain_name" {
  description = "系统的主域名"
  type        = string
  default     = "smart-invest.example.com"
}

variable "route53_zone_id" {
  description = "Route53 托管区域的 ID（如果已有域名解析，填入已有 Zone ID）"
  type        = string
  default     = ""
}

# ==============================
# 管理员访问配置
# ==============================

variable "admin_cidr_blocks" {
  description = "允许访问管理端口的 IP 段（白名单），例如公司 VPN 出口 IP"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # 生产环境请改为公司 VPN 出口 IP
}

# ==============================
# 标签 (Tags)
# ==============================

variable "additional_tags" {
  description = "额外需要添加到所有资源上的标签"
  type        = map(string)
  default     = {}
}
