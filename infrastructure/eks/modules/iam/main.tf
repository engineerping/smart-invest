# =============================================================================
# IAM 模块 - 权限与身份管理
# =============================================================================
# AWS IAM (Identity and Access Management) 是权限管理系统
# 核心概念：
#   - Role（角色）：一组权限的集合，可以被服务（如 EC2、EKS）临时获取
#   - Policy（策略）：定义具体的权限（允许/拒绝哪些 API 操作）
#   - Service Account（K8s）：通过 IRSA 映射到 IAM Role
#
# 在本模块中，我们创建：
#   1. CI/CD Pipeline Role（GitHub Actions 使用的角色）
#   2. App Service Account Role（微服务 Pod 使用的角色）
#   3. 各模块所需的 IAM Role

# ==============================
# 1. CI/CD GitHub Actions Role
# ==============================
# GitHub Actions 通过 OIDC 获取这个角色的权限
# 这样就不需要在 GitHub Secrets 中存储 AWS AccessKey 了
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-${var.environment}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project_name}-${var.environment}-github-actions-policy"
  role = aws_iam_role.github_actions.name

  # CI/CD 需要的权限
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",          # Docker 登录 ECR
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",                       # 推送镜像
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",                 # 获取 EKS 连接信息
          "eks:ListClusters",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",                        # 上传 CI 制品到 S3
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-artifacts-*",
          "arn:aws:s3:::${var.project_name}-${var.environment}-artifacts-*/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",       # 读取构建所需的密钥
        ]
        Resource = [
          "arn:aws:secretsmanager:*:*:secret:${var.project_name}-${var.environment}-*",
        ]
      },
    ]
  })
}

# ==============================
# 2. 微服务 Service Account IAM Role（通过 IRSA 映射）
# ==============================
resource "aws_iam_role" "app_service" {
  name = "${var.project_name}-${var.environment}-app-service-role"
  description = "微服务 Pod 使用的 IAM Role（通过 IRSA 映射到 K8s ServiceAccount）"

  # 信任 EKS OIDC Provider
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:default:smart-invest-sa"
          # 只有特定 ServiceAccount 的 Pod 才能获取这个角色
        }
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "app_service" {
  name = "${var.project_name}-${var.environment}-app-service-policy"
  role = aws_iam_role.app_service.name

  # 微服务需要的权限
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",           # 读取 S3 文件（如基金说明书 PDF）
          "s3:PutObject",           # 上传文件到 S3
        ]
        Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",  # 读取密钥
          "appconfig:GetConfiguration",     # 读取配置（AppConfig 动态配置）
          "ssm:GetParameter",               # 读取 SSM 参数
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",          # 写入 X-Ray 链路追踪数据
          "xray:PutTelemetryRecords",
        ]
        Resource = "*"
      },
    ]
  })
}

data "aws_caller_identity" "current" {}

# 注意：这个变量应该在调用模块时传入
variable "github_repo" {
  description = "GitHub 仓库名（格式 owner/repo）"
  type        = string
  default     = "engineerping/smart-invest"
}
