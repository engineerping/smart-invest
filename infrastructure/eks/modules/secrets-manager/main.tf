# =============================================================================
# Secrets Manager 模块 - 密钥存储管理
# =============================================================================
# AWS Secrets Manager 专门用于存储和管理敏感信息（密码、API Key 等）
# 与手动管理密码相比：
#   1. 自动轮换：可以设置定期自动更新密码（如每30天更换数据库密码）
#   2. 加密存储：使用 KMS 加密，并且支持访问审计
#   3. 统一管理：不用在多个环境变量中散落密码
#   4. 应用侧自动获取：Pod 通过 IRSA + SDK 自动获取最新密码

resource "aws_secretsmanager_secret" "database" {
  name        = "${var.project_name}-${var.environment}-database-credentials"
  description = "Aurora、Redis、DocumentDB 数据库连接信息"
  kms_key_id  = var.kms_key_id

  # 密码轮换配置（可选，本例考虑生产环境影响暂且不自动轮换）
  # rotation_rules {
  #   automatically_after_days = 30  # 每 30 天自动轮换密码
  # }

  tags = var.common_tags
}

resource "aws_secretsmanager_secret" "oauth2" {
  name        = "${var.project_name}-${var.environment}-oauth2-credentials"
  description = "OAuth2 认证中心的客户端密钥"
  kms_key_id  = var.kms_key_id

  tags = var.common_tags
}

resource "aws_secretsmanager_secret" "mq" {
  name        = "${var.project_name}-${var.environment}-mq-credentials"
  description = "Amazon MQ 连接凭证"
  kms_key_id  = var.kms_key_id

  tags = var.common_tags
}
