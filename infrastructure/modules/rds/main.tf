# =============================================================================
# RDS 模块 —— 托管 PostgreSQL 数据库
# =============================================================================
# RDS（Relational Database Service）是 AWS 的托管关系型数据库服务。
# "托管"的含义：AWS 帮你管理数据库的基础设施（备份/补丁/高可用/监控），
# 你只需要关心数据和 SQL。类似于把自建 MySQL 换成了阿里云 RDS。
#
# RDS 支持的数据库引擎：
#   - PostgreSQL（本项目使用）
#   - MySQL / MariaDB
#   - Oracle
#   - SQL Server
#   - Aurora（AWS 自研，兼容 MySQL/PostgreSQL，性能更强）
#
# RDS 自动化管理的内容：
#   - 自动备份（按配置的 retention_period 保留）
#   - 自动补丁（维护窗口内自动升级数据库引擎小版本）
#   - 自动故障切换（Multi-AZ 模式下）
#   - 自动存储扩展（Storage Auto Scaling 开启后）
# =============================================================================

# =============================================================================
# DB Subnet Group —— 数据库子网组
# =============================================================================
# RDS 要求至少指定 2 个不同可用区的子网（高可用需要）。
# 即使当前只用一个 AZ，AWS 也要求定义子网组。
#
# 为什么需要子网组：
#   - RDS 可能在未来切换可用区（故障切换）
#   - Multi-AZ 部署需要主备在不同子网
#   - 子网组告诉 RDS 它可以在哪些网络位置运行
#
# 本项目传入了公有子网和私有子网，但实际上应该只用私有子网。
# （这是简化实现，生产环境建议只传私有子网。）
# =============================================================================
# =============================================================================
# Terraform 语法速查：resource 的语法含义
# =============================================================================
# resource "<资源类型>" "<本地名称>" { ... }
#   - "资源类型"（如 aws_db_subnet_group）：由 Provider 定义，告诉 Terraform「我要创建什么」。
#     命名规范：<provider>_<资源名>
#   - "本地名称"（如 main）：你自己起的名字，只在当前模块内有效，
#     用于在代码中引用这个资源，如 aws_db_subnet_group.main.name
#   - 类比 Java：AwsDbSubnetGroup main = new AwsDbSubnetGroup();
#     资源类型 ≈ 类名，本地名称 ≈ 变量名
# =============================================================================
resource "aws_db_subnet_group" "main" {
  name       = "smart-invest-db-sng"
  subnet_ids = var.subnet_ids   # 子网 ID 列表（从 VPC 模块传入）
}

# =============================================================================
# RDS 实例 —— PostgreSQL 数据库
# =============================================================================
# 创建一个 PostgreSQL 数据库实例。
#
# 选型说明：
#   instance_class = db.t3.micro (2 vCPU, 1 GB RAM)
#     - 免费套餐内可用（12 个月，每月 750 小时）
#     - 适合学习和小型项目
#     - 生产环境建议 db.t3.small 起步
#
#   engine_version = 16.3
#     - PostgreSQL 16 当前最新稳定版
#     - 比 15 改进了性能、JSON 支持、逻辑复制
#
#   allocated_storage = 20 GB
#     - 免费套餐包含 20 GB 通用 SSD
#     - 对于投资组合管理应用来说足够
#
# 密码管理方式（manage_master_user_password = true）：
#   - AWS 自动生成复杂密码
#   - 密码自动存入 Secrets Manager
#   - 应用从 Secrets Manager 读取密码（比写在配置文件里安全）
#   - Secret 的 ARN 通过 db_secret_arn 输出
#   - 支持自动密码轮转（需要在 Secrets Manager 中配置）
#
# 成本优化（生产环境建议）：
#   - 购买 Reserved Instance（1 年/3 年承诺，折扣 30-60%）
#   - 启用 Storage Auto Scaling（按需增长，避免一次买太多）
#   - 使用 Instance Scheduler 在非工作时间关闭（开发环境）
# =============================================================================
resource "aws_db_instance" "postgres" {
  identifier = "smart-invest-db"         # 数据库实例的唯一标识

  # ---- 引擎配置 ----
  engine               = "postgres"      # PostgreSQL 引擎
  engine_version       = "16.3"          # 主版本.次版本
  instance_class       = "db.t3.micro"   # 实例规格（2 vCPU, 1 GB RAM）

  # ---- 存储配置 ----
  allocated_storage    = 20              # 初始分配存储（GB）
  storage_type         = "gp2"           # 通用 SSD（gp3 更便宜更快，但 gp2 兼容性更好）

  # ---- 数据库配置 ----
  db_name              = "smartinvest"   # 初始创建的数据库名
  username             = "smartadmin"    # 主用户（Master User）名称

  # ---- 密码管理（推荐方式） ----
  manage_master_user_password = true     # 让 AWS 管理密码（自动生成 + 存入 Secrets Manager）

  # ---- 网络配置 ----
  db_subnet_group_name   = aws_db_subnet_group.main.name   # 子网组
  vpc_security_group_ids = [var.rds_sg_id]                 # 安全组（只允许 EC2 访问 5432）

  # ---- 备份与高可用 ----
  backup_retention_period = 7            # 自动备份保留天数（7 天免费）
  multi_az               = false         # 多可用区部署（生产应改为 true，有 2 倍的容错但成本翻倍）

  # ---- 访问与删除保护 ----
  publicly_accessible     = false        # 不暴露公网（只允许 VPC 内部访问）
  deletion_protection     = false        # 学习阶段关闭删除保护（生产应改为 true！）

  # ---- 快照 ----
  skip_final_snapshot    = false         # 删除时创建最终快照
  final_snapshot_identifier = "smart-invest-final-snapshot"  # 最终快照名称
}
