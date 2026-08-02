# =============================================================================
# PRD 环境配置
# =============================================================================
# 使用方式：terraform apply -var-file="environments/prd.tfvars"

environment  = "prd"
eks_node_desired_size = 6
eks_node_max_size     = 20
eks_node_min_size     = 3

aurora_instance_count  = 3
aurora_instance_class  = "db.r6g.xlarge"
elasticache_num_cache_nodes = 3
