# =============================================================================
# UAT 环境配置
# =============================================================================
# 使用方式：terraform apply -var-file="environments/uat.tfvars"

environment  = "uat"
eks_node_desired_size = 3
eks_node_max_size     = 6
eks_node_min_size     = 2

aurora_instance_count  = 2
aurora_instance_class  = "db.r6g.large"
elasticache_num_cache_nodes = 2
