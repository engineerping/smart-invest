# =============================================================================
# KMS 模块 - 密钥管理服务
# =============================================================================
# AWS KMS (Key Management Service) 是加密密钥管理服务
# 所有 AWS 服务的加密都依赖 KMS 密钥
#
# 对称密钥 vs 非对称密钥：
#   对称密钥（CMK）：加密和解密使用同一密钥，大多数 AWS 服务使用此方式
#   非对称密钥：公钥加密，私钥解密（用于数字签名场景）
#
# 密钥策略：控制"谁可以管理这个密钥"和"谁可以用这个密钥加密/解密"

resource "aws_kms_key" "main" {
  description             = "Smart Invest 主加密密钥 - ${var.environment} 环境"
  deletion_window_in_days = 30  # 删除前等待 30 天（保护期，防止误删）
  enable_key_rotation     = true  # 每年自动轮换密钥（安全合规要求）
  multi_region            = false # 单区域密钥（如果要跨区域，设为 true）

  # 密钥策略：允许 CloudWatch 等 AWS 服务使用
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 规则1：允许当前账号完全控制（IAM 用户可以管理钥匙）
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # 规则2：允许 CloudWatch Logs 使用密钥加密日志
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
    ]
  })

  tags = var.common_tags
}

# KMS 别名（方便识别，类似"快捷方式"）
resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-${var.environment}-main"
  target_key_id = aws_kms_key.main.key_id
}

data "aws_caller_identity" "current" {}
