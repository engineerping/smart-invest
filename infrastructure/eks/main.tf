# =============================================================================
# 根模块 - 编排所有子模块
# =============================================================================
# 这是 Terraform 的入口文件，负责调用各个子模块并传递参数
# 类比于 Java 中的 Main 类 —— 它不实现具体逻辑，只是组织调用

# =============================================================================
# 1. IAM - 权限管理
# 注意：IAM 模块依赖 EKS 的 OIDC Provider，但因为 Terraform 会自动推导依赖图
# 所以 IAM 虽然写在前面，实际创建顺序会在 EKS 之后
# 这在 Terraform 中是完全正确的——声明式代码不需要关心执行顺序
# =============================================================================
module "iam" {
  source = "./modules/iam"

  project_name        = var.project_name
  environment         = var.environment
  oidc_provider_url   = module.eks.oidc_provider_url  # 依赖 EKS 的 OIDC
  oidc_provider_arn   = module.eks.oidc_provider_arn
}

# =============================================================================
# 2. KMS - 加密密钥管理
# =============================================================================
module "kms" {
  source = "./modules/kms"

  project_name = var.project_name
  environment  = var.environment
  common_tags  = local.common_tags
}

# =============================================================================
# 3. VPC - 网络基础设施（所有资源的基础）
# =============================================================================
module "vpc" {
  source = "./modules/vpc"

  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  common_tags         = local.common_tags
  admin_cidr_blocks   = var.admin_cidr_blocks
}

# =============================================================================
# 4. 安全组 - 网络安全规则
# =============================================================================
module "security_groups" {
  source = "./modules/security-groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  common_tags  = local.common_tags
  ports        = local.ports
  admin_cidrs  = var.admin_cidr_blocks
}

# =============================================================================
# 5. Secrets Manager - 密钥存储（数据库密码等）
# =============================================================================
module "secrets_manager" {
  source = "./modules/secrets-manager"

  project_name = var.project_name
  environment  = var.environment
  kms_key_id   = module.kms.key_id
  common_tags  = local.common_tags
}

# =============================================================================
# 6. Aurora PostgreSQL - 关系型数据库
# =============================================================================
module "aurora" {
  source = "./modules/aurora"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.database_subnet_ids
  allowed_security_group_ids = [
    module.security_groups.eks_node_sg_id,   # EKS 工作节点访问数据库
    module.security_groups.bastion_sg_id,     # 堡垒机（管理用）
  ]
  instance_count        = local.env.aurora_instance_count
  instance_class        = local.env.aurora_instance_class
  database_name         = var.aurora_database_name
  master_username       = var.aurora_master_username
  kms_key_arn           = module.kms.key_arn
  backup_retention_days = local.env.backup_retention_days
  enable_deletion_protection = local.env.enable_deletion_protection
  common_tags           = local.common_tags
}

# =============================================================================
# 7. ElastiCache Redis - 缓存服务
# =============================================================================
module "elasticache" {
  source = "./modules/elasticache"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.database_subnet_ids
  allowed_security_group_ids = [
    module.security_groups.eks_node_sg_id,
  ]
  instance_type         = var.elasticache_instance_type
  num_cache_nodes       = local.env.elasticache_node_count
  kms_key_arn           = module.kms.key_arn
  common_tags           = local.common_tags
}

# =============================================================================
# 8. DocumentDB (MongoDB) - 文档数据库
# =============================================================================
module "documentdb" {
  source = "./modules/documentdb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.database_subnet_ids
  allowed_security_group_ids = [
    module.security_groups.eks_node_sg_id,
  ]
  kms_key_arn           = module.kms.key_arn
  common_tags           = local.common_tags
}

# =============================================================================
# 9. Amazon MQ - 消息队列（异步通信）
# =============================================================================
module "mq" {
  source = "./modules/mq"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.database_subnet_ids
  allowed_security_group_ids = [
    module.security_groups.eks_node_sg_id,
  ]
  kms_key_arn           = module.kms.key_arn
  common_tags           = local.common_tags
}

# =============================================================================
# 10. ACM (SSL 证书) - HTTPS 加密通信
# =============================================================================
module "acm" {
  source = "./modules/acm"

  domain_name     = var.domain_name
  route53_zone_id = var.route53_zone_id
  common_tags     = local.common_tags
}

# =============================================================================
# 11. S3 - 对象存储
# =============================================================================
module "s3" {
  source = "./modules/s3"

  project_name                  = var.project_name
  environment                   = var.environment
  kms_key_arn                   = module.kms.key_arn
  cloudfront_distribution_arn   = module.cloudfront.arn
  common_tags                   = local.common_tags
}

# =============================================================================
# 12. EKS - Kubernetes 集群
# =============================================================================
module "eks" {
  source = "./modules/eks"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids  # Worker 节点放在私有子网
  cluster_version       = var.eks_cluster_version
  node_instance_types   = var.eks_node_instance_types
  node_desired_size     = local.env.eks_desired_size
  node_max_size         = local.env.eks_max_size
  node_min_size         = local.env.eks_min_size
  eks_node_sg_id        = module.security_groups.eks_node_sg_id
  cluster_sg_id         = module.security_groups.eks_cluster_sg_id
  common_tags           = local.common_tags
}

# =============================================================================
# 13. Istio 服务网格 - 通过 Helm 部署到 EKS
# =============================================================================
module "istio" {
  source = "./modules/istio"

  depends_on = [module.eks]  # 必须等 EKS 集群创建完成后才能部署 Istio
  # depends_on 很关键：Terraform 默认并行创建，但部署 Helm 必须先有 K8s 集群

  eks_cluster_name     = module.eks.cluster_name
  eks_cluster_endpoint = module.eks.cluster_endpoint
  eks_cluster_ca_cert  = module.eks.cluster_ca_certificate
  eks_cluster_token    = module.eks.cluster_token
}

# =============================================================================
# 14. WAF - Web 应用防火墙
# =============================================================================
module "waf" {
  source = "./modules/waf"

  project_name = var.project_name
  environment  = var.environment
  common_tags  = local.common_tags
}

# =============================================================================
# 15. CloudFront - CDN 内容分发
# =============================================================================
module "cloudfront" {
  source = "./modules/cloudfront"

  project_name       = var.project_name
  environment        = var.environment
  domain_name        = var.domain_name
  acm_certificate_arn = module.acm.certificate_arn
  waf_web_acl_arn    = module.waf.web_acl_arn
  s3_bucket_domain   = module.s3.frontend_bucket_regional_domain
  alb_dns_name       = module.eks.alb_dns_name
  common_tags        = local.common_tags
}

# =============================================================================
# 16. Route53 - DNS 域名解析
# =============================================================================
module "route53" {
  source = "./modules/route53"

  domain_name              = var.domain_name
  route53_zone_id          = var.route53_zone_id
  cloudfront_domain_name   = module.cloudfront.domain_name
  cloudfront_hosted_zone_id = module.cloudfront.hosted_zone_id
}

# =============================================================================
# 17. AppConfig - 应用动态配置
# =============================================================================
module "appconfig" {
  source = "./modules/appconfig"

  project_name = var.project_name
  environment  = var.environment
  common_tags  = local.common_tags
}

# =============================================================================
# 18. 监控告警 - Prometheus + Grafana + CloudWatch + xMatters
# =============================================================================
module "monitoring" {
  source = "./modules/monitoring"

  depends_on = [module.eks, module.istio]

  project_name         = var.project_name
  environment          = var.environment
  eks_cluster_name     = module.eks.cluster_name
  eks_cluster_endpoint = module.eks.cluster_endpoint
  eks_cluster_ca_cert  = module.eks.cluster_ca_certificate
  eks_cluster_token    = module.eks.cluster_token
  aurora_cluster_id    = module.aurora.cluster_id
  elasticache_cluster_id = module.elasticache.cluster_id
  aws_region           = var.aws_region
  common_tags          = local.common_tags
}
