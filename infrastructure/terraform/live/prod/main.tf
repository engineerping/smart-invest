# ==============================================================================
# Terraform + Provider 配置
# ==============================================================================
# 这是 Terraform 项目的"根文件"，声明：
#   1. Terraform 核心版本要求
#   2. 需要哪些 Provider（AWS、Kubernetes、Helm）
#   3. Provider 如何连接
#
# ==============================================================================
# Terraform 三个核心概念（面试必问）
# ==============================================================================
# 1. Provider —— "驱动层"
#    Terraform 本身不知道怎么操作 AWS/K8S/GCP，Provider 提供具体的 API 实现。
#    类比：数据库的 JDBC 驱动（Terraform = JDBC 接口，AWS Provider = MySQL 驱动）
#
# 2. Resource —— "你要什么"
#    声明式描述目标状态。你告诉 Terraform「我要一个 EC2 实例」，
#    它负责算出并执行「需要调用哪些 API」。
#
# 3. State（状态文件）—— "现在有什么"
#    terraform.tfstate 记录了「实际世界」和「配置定义」的映射。
#    它是 Terraform 的"记忆"——没有它，Terraform 不知道哪些资源是自己管的、
#    哪些是手动建的、哪些被改过了。
#
# 工作流：
#   Write → terraform init  → 下载 Provider
#        → terraform plan  → 对比期望 vs 实际，生成变更计划
#        → terraform apply → 执行变更，更新状态
# ==============================================================================

terraform {
  # ─── Terraform 核心版本要求 ───
  # >= 1.9 表示至少需要 1.9.x 版本
  # 为什么限制版本？因为不同版本可能有语法差异和新特性，
  # 锁定版本范围确保团队所有人用同样的环境。
  required_version = ">= 1.9"

  # ─── required_providers：声明依赖哪些 Provider ───
  # 类比 Maven 的 <dependencies>、npm 的 dependencies
  required_providers {
    # ─── AWS Provider ───
    # 管理所有 AWS 资源：EC2、S3、CloudFront、IAM、WAF...
    aws = {
      source  = "hashicorp/aws"    # Provider 来源（HashiCorp 官方 Registry）
      version = "~> 5.0"           # 悲观约束：>= 5.0 且 < 6.0
    }
  }

  # ══════════════════════════════════════════════════════════════════════
  # Backend 配置 —— 状态文件存哪里
  # ══════════════════════════════════════════════════════════════════════
  # 默认：状态文件存本地（terraform.tfstate），但这样不能多人协作。
  #
  # 远程 Backend（S3 + DynamoDB） 的好处：
  #   1. 团队共享：所有人都能看到最新状态
  #   2. 状态锁：DynamoDB 作为锁，防止两个人同时 apply（写冲突）
  #   3. 版本历史：S3 开启版本控制后，每次状态变更都能回滚
  #   4. 不存本地：CI/CD Pipeline 也能用
  #
  # 使用时取消注释并填入你的 bucket 名称：
  #
  # backend "s3" {
  #   bucket         = "smart-invest-terraform-state"   # S3 存储桶名
  #   key            = "prod/terraform.tfstate"          # 桶中的文件路径
  #   region         = "ap-southeast-1"                  # 桶所在的区域
  #   encrypt        = true                              # 加密存储（安全）
  #   dynamodb_table = "terraform-state-lock"            # DynamoDB 锁表
  # }
  # ══════════════════════════════════════════════════════════════════════
}

# ==============================================================================
# AWS Provider —— 默认 region：ap-southeast-1（新加坡）
# ==============================================================================
# 新加坡区域的优势：
#   - 离国内近，延迟较低
#   - 和 us-east-1 价格相差不大
#   - 是亚太区功能比较全的区域
# ==============================================================================
provider "aws" {
  # ─── profile：使用 ~/.aws/credentials 中哪个 profile ───
  # 默认值 "default"，即对应 [default] section。
  # 如果你有多个 AWS 账号，建议改成具体的 profile 名。
  profile = var.aws_profile

  # ─── region：资源创建在哪个地理区域 ───
  region = var.aws_region
}

# ==============================================================================
# AWS Provider —— us-east-1（弗吉尼亚）
# ==============================================================================
# WAF Web ACL 如果 scope = "CLOUDFRONT"（挂在 CloudFront 上），
# 必须部署在 us-east-1！这是 AWS 的硬性规定。
#
# alias = "us_east_1"：给这个 Provider 起个别名。
# 在 CDN 模块中通过 providers = { aws.us_east_1 = aws.us_east_1 } 传入。
# ==============================================================================
provider "aws" {
  profile = var.aws_profile
  alias   = "us_east_1"
  region  = "us-east-1"
}
