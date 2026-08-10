# =============================================================================
# IAM 模块 —— AWS 权限和身份管理
# =============================================================================
# IAM（Identity and Access Management）是 AWS 的权限管理系统。
# 这个模块为 EC2 应用服务器创建运行所需的最小权限集。
#
# IAM 核心概念：
#   1. Role（角色）：可以被"扮演"的身份，不是属于某个人而是属于某个服务
#   2. Policy（策略）：定义"能做什么"的 JSON 文档（权限列表）
#   3. Instance Profile（实例配置文件）：让 EC2 能使用 Role 的桥梁
#   4. Trust Relationship（信任关系）：定义"谁可以扮演这个角色"
#
# 为什么用 IAM Role 而不是 Access Key？
#   1. 安全：Access Key 是静态凭证，泄露后长期有效；Role 的凭证自动轮转
#   2. 方便：不需要在代码里配置密钥，SDK 自动从 metadata 获取
#   3. 合规：符合 AWS 安全最佳实践和 Well-Architected Framework
#
# EC2 获取凭证的机制（AWS SDK 自动处理）：
#   EC2 启动
#     → Instance Metadata Service (169.254.169.254)
#     → 获取 Role 名称
#     → STS (Security Token Service) AssumeRole
#     → 获取临时凭证（AccessKey + SecretKey + SessionToken）
#     → 凭证约 1 小时后过期，SDK 自动续期
# =============================================================================

# =============================================================================
# IAM Role —— EC2 应用角色
# =============================================================================
# 这是一个给 EC2 使用的角色，EC2 服务可以"扮演"这个角色来获得权限。
#
# assume_role_policy（信任策略）：
#   定义"谁"可以扮演这个角色。
#   这里写的是 ec2.amazonaws.com，表示只有 EC2 服务可以扮演。
#   其他 AWS 服务也可以扮演：lambda.amazonaws.com、rds.amazonaws.com 等。
#
# Principal = 谁可以执行这个操作
#   - Service: ec2.amazonaws.com → EC2 服务本身
#   - AWS: arn:aws:iam::123456:user/xxx → 指定 IAM 用户
#   - Federated: 外部身份提供商（SAML/OIDC）
#
# 注意：
#   - assume_role_policy 和 permissions policy 是不同的概念
#   - assume_role_policy = 谁能成为这个角色（信任关系）
#   - permissions policy  = 这个角色能做什么（权限列表）
# =============================================================================
resource "aws_iam_role" "app_role" {
  name = "smart-invest-app-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"              # IAM Policy 语言版本（固定值）
    Statement = [{
      Action = "sts:AssumeRole"         # STS AssumeRole 操作
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }   # 只有 EC2 服务可以扮演此角色
    }]
  })
}

# =============================================================================
# IAM Policy Attachment —— 策略附加
# =============================================================================
# Policy Attachment 将 AWS 托管策略（或自定义策略）绑定到角色上。
# AWS 托管策略是 AWS 预定义好的权限集合，以 arn:aws:iam::aws:policy/ 开头。
#
# 最小权限原则（Least Privilege）：
#   只给应用真正需要的权限，不要给 AdminAccess 或 *:* 这种超级权限。
#   这里的权限都是应用确实需要的：
#     - Secrets Manager: 读取数据库密码（启动时）
#     - SES: 发送邮件（用户注册验证、通知等）
#     - CloudWatch Logs: 写日志（监控和排查问题）
# =============================================================================

# -------------------------------------------------------------------
# SecretsManagerReadWrite: 数据库密码管理
# 应用启动时从 Secrets Manager 获取 RDS 数据库的 master 密码。
# RDS 的 manage_master_user_password = true 会自动创建这个 Secret。
#
# Secret 的 ARN 通过 db_secret_arn 传递给 EC2 的 UserData 脚本。
# -------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "secretsmanager" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

# -------------------------------------------------------------------
# AmazonSESFullAccess: 邮件发送
# SES（Simple Email Service）是 AWS 的邮件服务，用于应用发送邮件。
# 典型场景：用户注册确认、密码重置、交易通知、告警通知。
#
# SES 需要先在 AWS Console 验证发件人邮箱或域名。
# 新账号默认在 sandbox 模式（只能发给已验证的邮箱），需要申请生产模式。
# -------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "ses" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}

# -------------------------------------------------------------------
# CloudWatchLogsFullAccess: 日志管理
# CloudWatch Logs 是 AWS 的集中日志服务，类似于 ELK 中的 Elasticsearch。
# 应用日志（Spring Boot logback）通过 CloudWatch Agent 推送到 CloudWatch。
#
# CloudWatch Logs 特点：
#   - 自动持久化（不需要自己维护 Elasticsearch）
#   - 支持按时间/关键词检索
#   - 可以设置告警（如错误日志超过阈值）
#   - 和 AWS 其他服务深度集成
# -------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# =============================================================================
# IAM Instance Profile —— EC2 使用 IAM 角色的桥梁
# =============================================================================
# Instance Profile 是将 IAM Role 绑定到 EC2 实例的中间层。
#
# 为什么需要 Instance Profile？
#   EC2 底层是虚拟机，不能直接使用 IAM 概念。
#   Instance Profile 是一个"包装器"，把 IAM Role 包一层，让 EC2 能用。
#   一个 Instance Profile 只能包含一个 Role。
#
# 使用方式：
#   1. 在 EC2 launch 时传递 iam_instance_profile 参数
#   2. 在 AWS Console 中修改实例的 IAM Role
#   3. Terraform 中通过 aws_instance 的 iam_instance_profile 属性
# =============================================================================
resource "aws_iam_instance_profile" "app_profile" {
  name = "smart-invest-app-profile"
  role = aws_iam_role.app_role.name   # 将角色绑定到实例配置文件
}
