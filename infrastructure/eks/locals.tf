# =============================================================================
# 本地变量 (Locals)
# =============================================================================
# 本地变量是不可配置的，但可以在多个地方复用
# 作用类似于编程中的"常量"或"计算属性"

locals {
  # --- 命名前缀 ---
  # 例如：smart-invest-prd → 用于区分不同环境的资源
  name_prefix = "${var.project_name}-${var.environment}"

  # --- 通用标签 ---
  # 给所有 AWS 资源打上标签，方便成本核算、资源追踪和自动化运维
  common_tags = merge(
    var.additional_tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"           # 标记此资源由 Terraform 管理
      Team        = "Wealth-Personal-Banking"
      CostCenter  = "HSBC-WPB-${var.environment}"
    }
  )

  # --- 可用区数量 ---
  az_count = length(var.availability_zones)

  # --- EKS 集群相关 ---
  # K8s 服务账号与 IAM Role 的映射（IRSA - IAM Roles for Service Accounts）
  # 这个设计让 Pod 能安全地获得 AWS 权限，而不需要在代码里写 AccessKey
  # 工作原理：Pod 的 ServiceAccount 注解了 IAM Role ARN → EKS 自动注入临时凭证
  irsa_namespace = "default"  # IRSA 使用的 K8s 命名空间

  # --- 环境特定的配置 ---
  env_config = {
    dev = {
      aurora_instance_count  = 1             # 开发环境节省成本，只用1个实例
      aurora_instance_class  = "db.t4g.medium"
      elasticache_node_count = 1
      eks_min_size           = 1
      eks_desired_size       = 2
      eks_max_size           = 4
      enable_deletion_protection = false     # 开发环境允许删除
      backup_retention_days  = 7
    }
    uat = {
      aurora_instance_count  = 2
      aurora_instance_class  = "db.r6g.large"
      elasticache_node_count = 2
      eks_min_size           = 2
      eks_desired_size       = 3
      eks_max_size           = 6
      enable_deletion_protection = true      # UAT 类似生产，需保护
      backup_retention_days  = 14
    }
    prd = {
      aurora_instance_count  = 3             # 生产环境至少 3 个实例（两地三中心）
      aurora_instance_class  = "db.r6g.xlarge"
      elasticache_node_count = 3
      eks_min_size           = 3
      eks_desired_size       = 6
      eks_max_size           = 20            # 预留弹性扩容空间
      enable_deletion_protection = true
      backup_retention_days  = 35            # 金融系统备份保留至少 30 天
    }
  }

  # 从环境配置中读取当前环境的参数
  env = lookup(local.env_config, var.environment, local.env_config["dev"])

  # --- 端口定义 ---
  # 集中管理端口，方便在安全组中使用
  ports = {
    http         = 80
    https        = 443
    postgresql   = 5432
    redis        = 6379
    mongodb      = 27017
    activemq     = 5671    # Amazon MQ (AMQP over TLS)
    k8s_api      = 443     # EKS API Server
    kong_admin   = 8001    # Kong Admin API
    kong_proxy   = 8443    # Kong Proxy (TLS)
    app_http     = 8080    # 微服务应用端口
  }
}
