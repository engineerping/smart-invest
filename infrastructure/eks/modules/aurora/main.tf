# =============================================================================
# Aurora PostgreSQL 数据库模块
# =============================================================================
# Amazon Aurora 是 AWS 自研的关系型数据库，兼容 MySQL 和 PostgreSQL
# Aurora 的优势（相比普通 RDS）：
#   1. 性能：5倍于标准 MySQL，3倍于标准 PostgreSQL
#   2. 高可用：跨 3 个 AZ 自动复制，故障转移通常 < 30 秒
#   3. 存储：自动扩展，最大 128TB，不需要预先规划
#   4. 安全：自动备份到 S3，支持 Point-in-Time Recovery（时刻点恢复）
#   5. Multi-AZ：写入节点 + 最多 15 个只读副本，读写分离
#
# 在这里我们使用 Aurora PostgreSQL Serverless v2：
#   - 按使用量计费（ACU），空闲时自动缩减，节省成本
#   - 无服务器，不需管理容量

# ==============================
# 1. Aurora 子网组
# ==============================
resource "aws_db_subnet_group" "aurora" {
  name        = "${var.project_name}-${var.environment}-aurora-subnet"
  description = "Aurora 数据库的子网组"

  # 数据库部署在哪些子网中（至少需要 2 个 AZ）
  subnet_ids = var.subnet_ids

  tags = var.common_tags
}

# ==============================
# 2. Aurora 集群参数组
# ==============================
# 参数组 = 数据库的"配置文件"，控制 PostgreSQL 的行为
resource "aws_rds_cluster_parameter_group" "aurora" {
  name        = "${var.project_name}-${var.environment}-aurora-pg14-params"
  family      = "aurora-postgresql14"  # Aurora PostgreSQL 14
  description = "Smart Invest Aurora 集群参数组"

  # --- 重要参数调优 ---
  parameter {
    name  = "statement_timeout"
    value = "60000"  # SQL 语句超时 60 秒（毫秒），防止慢查询占用资源
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "5000"  # 超过 5 秒的查询记录到慢日志（金融系统需要完整审计）
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"  # 加载统计扩展
    apply_method = "pending-reboot"
  }

  tags = var.common_tags
}

# ==============================
# 3. Aurora 集群
# ==============================
resource "aws_rds_cluster" "aurora" {
  cluster_identifier   = "${var.project_name}-${var.environment}-aurora-cluster"
  engine              = "aurora-postgresql"           # 使用 Aurora PostgreSQL 引擎
  engine_version      = "14.10"
  database_name       = var.database_name            # 初始数据库名
  master_username     = var.master_username
  master_password     = random_password.aurora_master.result  # 随机生成密码

  # --- 网络配置 ---
  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = var.allowed_security_group_ids
  # 注意：数据库在 database_subnet 中（由 subnet_ids 变量控制）

  # --- 高可用配置 ---
  # Multi-AZ 部署：至少 2 个实例分布在 2 个不同的 AZ
  # 如果主节点故障，自动故障转移到副本（Failover）

  # --- 安全配置 ---
  storage_encrypted       = true                       # 启用存储加密
  kms_key_id              = var.kms_key_arn           # 使用 KMS 管理加密密钥
  deletion_protection     = var.enable_deletion_protection  # 防误删
  skip_final_snapshot     = false                     # 删除时自动创建最终快照
  final_snapshot_identifier = "${var.project_name}-${var.environment}-aurora-final-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
  backup_retention_period = var.backup_retention_days # 自动备份保留天数
  preferred_backup_window = "15:00-16:00"              # 备份窗口（UTC时间，对应凌晨）
  preferred_maintenance_window = "sun:16:00-sun:18:00" # 维护窗口（周日）

  # --- 日志 ---
  enabled_cloudwatch_logs_exports = ["postgresql"]     # 将 PG 日志导出到 CloudWatch

  # --- 性能洞察 ---
  # 实时分析数据库负载，发现性能瓶颈
  performance_insights_enabled          = true
  performance_insights_retention_period = 7  # 性能数据保留7天

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name

  tags = var.common_tags
}

# ==============================
# 4. Aurora 实例（集群中的节点）
# ==============================
resource "aws_rds_cluster_instance" "aurora" {
  count = var.instance_count  # 创建多个实例

  identifier         = "${var.project_name}-${var.environment}-aurora-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  # 散布到不同 AZ
  availability_zone = element(["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"], count.index)

  # 公开可访问性：false（数据库只允许 VPC 内访问）
  publicly_accessible = false

  # 性能洞察
  performance_insights_enabled = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-aurora-node-${count.index + 1}"
  })
}

# ==============================
# 5. 随机密码生成
# ==============================
resource "random_password" "aurora_master" {
  length  = 32          # 32 位密码
  special = true         # 包含特殊字符
  # 排除容易混淆的字符
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
