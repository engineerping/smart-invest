# ==============================================================================
# Backend 配置 —— Terraform 状态文件的远程存储
# ==============================================================================
#
# 为什么需要 Remote Backend：
#   默认情况，Terraform 的状态文件（terraform.tfstate）存在本地磁盘。
#   这会带来几个问题：
#     1. 团队协作：你 apply 后别人再次 plan 看不到最新状态
#     2. 并发冲突：两个人同时 apply → 状态文件被互相覆盖
#     3. 丢失风险：本地文件误删 → Terraform 状态丢失（灾难！）
#     4. CI/CD：Pipeline 运行在临时容器里，本地状态不能持久化
#
# S3 Backend 的好处：
#   - S3 存储状态文件（支持版本控制，方便回滚）
#   - DynamoDB 提供分布式锁（防止两人同时 apply）
#   - 自动加密（服务端加密 + 传输加密）
#   - CI/CD 友好（Pipeline 可以直接读取）
#
# 使用步骤（按顺序执行）：
#   1. 先在 AWS Console 手动创建 S3 Bucket（开启版本控制）和 DynamoDB Table
#      - S3 Bucket 名称：smart-invest-terraform-state（需全局唯一）
#      - DynamoDB Table：terraform-state-lock，主键 LockID (String)
#   2. 取消下面注释
#   3. terraform init -migrate-state（把本地 state 迁移到 S3）
#   4. 成功后可以删除本地 terraform.tfstate 和 terraform.tfstate.backup
#
# 手动创建的 DynamoDB 表的要求：
#   aws dynamodb create-table \
#     --table-name terraform-state-lock \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST
# ==============================================================================

# ⚠️ 使用时取消注释：
#
# terraform {
#   backend "s3" {
#     bucket         = "smart-invest-terraform-state"    # S3 存储桶名（需全局唯一）
#     key            = "prod/terraform.tfstate"           # 状态文件在桶中的路径
#     region         = "ap-southeast-1"                   # 桶所在区域
#     encrypt        = true                               # 服务端加密
#     dynamodb_table = "terraform-state-lock"             # DynamoDB 锁表名
#   }
# }
