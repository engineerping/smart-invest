# =============================================================================
# DEV 环境配置
# =============================================================================
# 使用方式：terraform apply -var-file="environments/dev.tfvars"

environment  = "dev"
eks_node_desired_size = 2
eks_node_max_size     = 4
eks_node_min_size     = 1

aurora_instance_count  = 1
aurora_instance_class  = "db.t4g.medium"
elasticache_num_cache_nodes = 1
