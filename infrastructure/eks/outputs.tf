# =============================================================================
# 输出变量 (Outputs)
# =============================================================================
# 输出的值可以在部署后通过 `terraform output` 命令查看
# 也可以被其他 Terraform 项目通过 `terraform_remote_state` 引用

# --- 网络相关 ---
output "vpc_id" {
  description = "VPC ID，其他模块依赖 VPC 时使用"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "私有子网 ID 列表（应用 Pod 部署在这些子网中）"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "公有子网 ID 列表（NLB/Ingress 部署在这里）"
  value       = module.vpc.public_subnet_ids
}

# --- EKS 相关 ---
output "eks_cluster_name" {
  description = "EKS 集群名称"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API Server 端点地址"
  value       = module.eks.cluster_endpoint
  sensitive   = true  # 标记为敏感信息，不会在 plan/apply 日志中打印
}

output "eks_cluster_ca_certificate" {
  description = "EKS 集群的 CA 证书（用于 kubectl 连接）"
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
}

output "eks_oidc_provider_url" {
  description = "EKS 集群的 OIDC Provider URL（用于 IRSA 权限配置）"
  value       = module.eks.oidc_provider_url
}

# --- 数据库相关 ---
output "aurora_endpoint" {
  description = "Aurora 集群的写入端点"
  value       = module.aurora.cluster_endpoint
  sensitive   = true
}

output "aurora_reader_endpoint" {
  description = "Aurora 集群的只读端点（读写分离场景使用）"
  value       = module.aurora.reader_endpoint
  sensitive   = true
}

output "elasticache_endpoint" {
  description = "ElastiCache Redis 的主端点"
  value       = module.elasticache.primary_endpoint
  sensitive   = true
}

output "documentdb_endpoint" {
  description = "DocumentDB 集群端点"
  value       = module.documentdb.cluster_endpoint
  sensitive   = true
}

# --- 消息队列相关 ---
output "amazon_mq_endpoint" {
  description = "Amazon MQ Broker 端点（AMQP 协议）"
  value       = module.mq.broker_endpoint
  sensitive   = true
}

# --- CDN 相关 ---
output "cloudfront_domain_name" {
  description = "CloudFront 分配域名"
  value       = module.cloudfront.domain_name
}

# --- 监控相关 ---
output "grafana_url" {
  description = "Grafana 监控面板地址"
  value       = module.monitoring.grafana_url
}

# --- KMS 相关 ---
output "kms_key_arn" {
  description = "KMS 密钥 ARN（用于加密数据库、S3、Secrets 等）"
  value       = module.kms.key_arn
}
