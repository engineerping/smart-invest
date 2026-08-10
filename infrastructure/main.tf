# =============================================================================
# 根模块 —— 编排所有子模块
# =============================================================================
# main.tf 是 Terraform 项目的入口文件（约定俗成），负责调用各个子模块并
# 在它们之间传递依赖关系。这类似于 Spring 的依赖注入容器 —— 声明组件（模块），
# 注入依赖（output → input）。
#
# 模块调用语法：module "<本地名称>" { source = "<模块路径>" ... }
#   - source: 模块代码位置，可以是本地路径（./modules/xxx）、Git 仓库、Terraform Registry
#   - 其他参数：传递给模块的 variables（对应模块内 variable 块的定义）
#
# 依赖关系图（隐式依赖，Terraform 自动推导）：
#   VPC → IAM（无依赖，并行创建）
#   RDS → VPC（需要 subnet_ids + rds_sg_id）
#   EC2 → VPC + IAM + RDS（需要子网、安全组、IAM 角色、数据库密码 ARN）
#   S3/CloudFront → 无依赖（并行创建）
#
# Terraform 会根据资源引用关系自动生成 DAG（有向无环图），并行创建无依赖的资源。
# =============================================================================

# =============================================================================
# VPC 模块 —— 网络基础设施
# =============================================================================
# VPC（Virtual Private Cloud）是 AWS 上最基础的网络隔离单元。
# 这个模块创建：
#   - 1 个 VPC（10.0.0.0/16，约 6.5 万个私有 IP）
#   - 1 个公有子网（10.0.1.0/24，带 Internet Gateway）
#   - 1 个私有子网（10.0.2.0/24，不直接暴露互联网）
#   - 安全组（EC2 安全组 + RDS 安全组）
#
# 公有子网 vs 私有子网：
#   公有子网 = 路由表有指向 Internet Gateway 的路由 → 可以直接访问互联网
#   私有子网 = 路由表没有指向 Internet Gateway 的路由 → 不能直接访问互联网
#   最佳实践：EC2 放公有子网（对外服务），RDS 放私有子网（只允许 EC2 访问）
# =============================================================================
# =============================================================================
# Terraform 语法速查：module 的语法含义
# =============================================================================
# module "<本地名称>" { source = "<模块路径>" ... }
#   - "本地名称"（如 vpc）：你自己起的名字，用于在代码中引用这个模块的输出，
#     如 module.vpc.public_subnet_id
#   - source: 模块代码位置，可以是本地路径（./modules/xxx）、Git 仓库、Terraform Registry
#   - 其他参数：传递给模块的 variables（对应模块内 variable 块的定义）
#   - 类比 Java：VpcModule vpc = new VpcModule(config);
#     模块 ≈ 类，source ≈ 类路径，参数 ≈ 构造函数参数
#
# resource / data / module 三者的区别：
#   - resource = 创建/管理资源（CRUD 的 CUD）→ terraform destroy 会删除
#   - data    = 查询已有资源（CRUD 的 R）  → terraform destroy 不涉及
#   - module  = 封装一组资源的可复用单元    → 内部有 resource/data/output
# =============================================================================
module "vpc" {
  source     = "./modules/vpc"
  region     = var.aws_region    # 用于拼接可用区名（如 us-east-1a）
  admin_cidr = var.admin_cidr    # 管理员 IP，用于 SSH 白名单
}

# =============================================================================
# IAM 模块 —— 权限与身份
# =============================================================================
# IAM（Identity and Access Management）是 AWS 的权限管理系统。
# 这个模块创建：
#   - IAM Role（角色）：EC2 可以 Assume 的身份
#   - IAM Policy Attachment（策略附加）：授予 Secrets Manager / SES / CloudWatch 权限
#   - Instance Profile（实例配置文件）：将角色绑定到 EC2
#
# EC2 通过 Instance Profile 获得 IAM Role 的权限，无需在代码里配置 AccessKey。
# 这是 AWS 安全最佳实践 —— 永远不给 EC2 配静态凭证，用 IAM Role 代替。
# =============================================================================
module "iam" {
  source = "./modules/iam"
}

# =============================================================================
# RDS 模块 —— 托管 PostgreSQL 数据库
# =============================================================================
# RDS（Relational Database Service）是 AWS 的托管数据库服务。
# 这个模块创建：
#   - 1 个 PostgreSQL 16.3 实例（db.t3.micro，20GB 存储）
#   - 自动生成的数据库主密码（存入 Secrets Manager）
#   - 子网组（跨越公有+私有子网）
#
# RDS 放在私有子网中，只允许 EC2 安全组访问 5432 端口，
# 数据库不直接暴露在互联网上，安全性更高。
# =============================================================================
module "rds" {
  source     = "./modules/rds"
  subnet_ids = [module.vpc.public_subnet_id, module.vpc.private_subnet_id]   # 子网组需要至少 2 个子网
  rds_sg_id  = module.vpc.rds_sg_id                                          # RDS 安全组（只允许 EC2 访问）
}

# =============================================================================
# EC2 模块 —— 应用服务器
# =============================================================================
# EC2（Elastic Compute Cloud）是 AWS 的虚拟机服务。
# 这个模块创建：
#   - 1 台 t3.small 实例（Amazon Linux 2023）
#   - 1 个弹性 IP（EIP，固定公网 IP）
#   - UserData 脚本：启动时自动安装 Java、下载 JAR 包、启动应用
#
# EC2 启动后会自动执行 UserData 脚本完成环境初始化，包括：
#   1. 安装 Java 运行时
#   2. 从 S3 下载应用 JAR 包
#   3. 从 Secrets Manager 获取数据库密码
#   4. 启动 Spring Boot 应用
# =============================================================================
module "ec2" {
  source                = "./modules/ec2"
  public_subnet_id      = module.vpc.public_subnet_id          # 放在公有子网，需要公网 IP
  ec2_sg_id             = module.vpc.ec2_sg_id                # EC2 安全组
  instance_profile_name  = module.iam.instance_profile_name    # IAM 实例配置文件（授予权限）
  key_pair_name         = var.key_pair_name                    # SSH 密钥对名称
  db_secret_arn         = module.rds.db_secret_arn             # 数据库密码在 Secrets Manager 中的 ARN
  region                = var.aws_region                       # AWS 区域
  app_jar_s3_path       = "s3://smart-invest-artifacts-${var.account_id}/smart-invest-app.jar"  # JAR 包位置
}

# =============================================================================
# S3 + CloudFront 模块 —— 前端静态托管 + CDN
# =============================================================================
# S3 用于存储前端静态文件（HTML/JS/CSS），CloudFront 作为 CDN 加速全球访问。
# 这个模块创建：
#   - 1 个 S3 Bucket（存储前端静态文件）
#   - 1 个 CloudFront Distribution（CDN 分发）
#   - OAC（Origin Access Control）—— CloudFront 访问 S3 的认证机制
#
# 为什么用 CloudFront + S3 而不是直接用 S3 静态托管？
#   1. HTTPS 支持：CloudFront 自带 HTTPS（S3 静态托管只支持 HTTP）
#   2. CDN 加速：全球边缘节点缓存，访问更快
#   3. 自定义域名：CloudFront 支持自定义域名 + SSL 证书
#   4. 安全：OAC 确保只有通过 CloudFront 才能访问 S3，S3 不直接暴露
# =============================================================================
module "s3_cloudfront" {
  source     = "./modules/s3-cloudfront"
  account_id = var.account_id    # 用于 S3 bucket 命名（保证全局唯一）
}
