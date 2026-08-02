# =============================================================================
# ElastiCache Redis 模块 - 缓存服务
# =============================================================================
# Amazon ElastiCache 是 AWS 托管 的 Redis/Memcached 缓存服务
#
# Redis 在本项目中的用途：
#   1. 会话缓存：存储用户登录状态（Session），支持分布式会话共享
#   2. 热点数据缓存：缓存基金净值、汇率等频繁读取的数据，减轻数据库压力
#   3. 分布式锁（Redisson）：用于处理并发场景下的资源竞争
#   4. 排行榜/ZSET：基金经理排名功能
#
# 配置要点：
#   - Multi-AZ 模式：主节点 + 至少 1 个只读副本
#   - 自动故障转移：主节点挂了自动切换到副本
#   - 加密传输 (TLS) 和静态加密：满足金融行业安全要求

# ==============================
# 1. ElastiCache 子网组
# ==============================
resource "aws_elasticache_subnet_group" "redis" {
  name        = "${var.project_name}-${var.environment}-redis-subnet"
  description = "Redis 缓存的子网组"
  subnet_ids  = var.subnet_ids  # 缓存实例部署在这些子网中

  tags = var.common_tags
}

# ==============================
# 2. ElastiCache 参数组
# ==============================
resource "aws_elasticache_parameter_group" "redis" {
  name        = "${var.project_name}-${var.environment}-redis-params"
  family      = "redis7"  # Redis 7.x 版本
  description = "Smart Invest Redis 参数组"

  # --- Redis 配置调优 ---
  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru"
    # 淘汰策略说明：
    #   volatile-lru：内存不足时，从设置了过期时间的 key 中淘汰最近最少使用的
    #   为什么选这个策略：基金数据有时效性，过期数据主动淘汰
  }

  parameter {
    name  = "timeout"
    value = "300"  # 客户端空闲连接超时 300 秒
  }

  parameter {
    name  = "tcp-keepalive"
    value = "60"  # TCP keepalive 60 秒
  }

  tags = var.common_tags
}

# ==============================
# 3. ElastiCache Redis 集群
# ==============================
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.project_name}-${var.environment}-redis"

  description          = "Smart Invest Redis 集群 - ${var.environment} 环境"

  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.instance_type           # 例如 cache.t3.medium
  num_cache_clusters   = var.num_cache_nodes         # 节点数量

  # --- 网络配置 ---
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = var.allowed_security_group_ids
  port                 = 6379

  # --- 安全配置 ---
  # 静态加密
  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn
  # 传输加密（TLS）
  transit_encryption_enabled = true
  auth_token_enabled         = true  # 需要密码认证（AUTH 命令）

  # --- 高可用配置 ---
  automatic_failover_enabled = var.num_cache_nodes > 1  # 多节点时启用自动故障转移
  multi_az_enabled           = var.num_cache_nodes > 1  # 多 AZ 部署

  # --- 维护配置 ---
  maintenance_window         = "sun:18:00-sun:20:00"    # 维护窗口
  snapshot_window            = "14:00-16:00"             # 备份窗口
  snapshot_retention_limit   = var.environment == "prd" ? 7 : 3  # 生产环境保留7天快照

  apply_immediately          = var.environment != "prd"  # dev/uat 立即生效，prd 在维护窗口生效

  tags = var.common_tags
}

# ==============================
# 4. 生成 Redis 密码
# ==============================
resource "random_password" "redis" {
  length  = 16
  special = false  # Redis AUTH 对特殊字符支持有限，只使用字母数字
}
