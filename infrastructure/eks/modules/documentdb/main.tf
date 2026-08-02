# =============================================================================
# DocumentDB 模块 - MongoDB 兼容文档数据库
# =============================================================================
# Amazon DocumentDB 是 AWS 托管 的 MongoDB 兼容数据库
# 与 MongoDB 3.6/4.0 API 兼容，但底层使用 Aurora 存储引擎
#
# 在本项目中的用途：
#   存储基金产品的非结构化数据（如基金的描述文档、条款说明等）
#   MongoDB 适合 JSON 文档格式，Schema 灵活

resource "aws_docdb_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-docdb-subnet"
  description = "DocumentDB 子网组"
  subnet_ids  = var.subnet_ids

  tags = var.common_tags
}

resource "aws_docdb_cluster_parameter_group" "main" {
  family      = "docdb5.0"
  name        = "${var.project_name}-${var.environment}-docdb-params"
  description = "Smart Invest DocumentDB 参数组"

  parameter {
    name  = "tls"
    value = "enabled"  # 强制 TLS 加密连接
  }

  tags = var.common_tags
}

resource "aws_docdb_cluster" "main" {
  cluster_identifier  = "${var.project_name}-${var.environment}-docdb"
  engine              = "docdb"
  engine_version      = "5.0.0"
  master_username     = "docdbadmin"
  master_password     = random_password.docdb_master.result

  db_subnet_group_name   = aws_docdb_subnet_group.main.name
  vpc_security_group_ids = var.allowed_security_group_ids

  # 安全配置
  storage_encrypted   = true
  kms_key_id          = var.kms_key_arn
  deletion_protection = var.environment == "prd"
  skip_final_snapshot = var.environment != "prd"
  backup_retention_period = var.environment == "prd" ? 14 : 7

  tags = var.common_tags
}

resource "aws_docdb_cluster_instance" "main" {
  count              = var.environment == "prd" ? 2 : 1
  identifier         = "${var.project_name}-${var.environment}-docdb-${count.index + 1}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.environment == "prd" ? "db.r6g.large" : "db.t4g.medium"

  tags = var.common_tags
}

resource "random_password" "docdb_master" {
  length  = 32
  special = true
}
