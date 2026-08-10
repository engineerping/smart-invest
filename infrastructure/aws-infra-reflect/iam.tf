# ============================================================================
# IAM(Identity and Access Management 身份与访问权限管理) 概念说明 及 AWS IAM 与 K8s 概念对照
# ============================================================================
#
# 问：这个 IAM 是不是就是 K8s 中的 Service Account？
#
# 答：正确，概念非常相似。
#
#    ┌──────────────────────┬───────────────────────────────────┐
#    │   AWS IAM Role       │   K8s ServiceAccount              │
#    ├──────────────────────┼───────────────────────────────────┤
#    │ 给 EC2/Lambda 等用   │ 给 Pod 用                         │
#    │ 不靠 Access Key      │ 不靠密码，靠 Token                 │
#    │ 通过 IAM Policy 绑定 │ 通过 Role/ClusterRole 绑定         │
#    │ EC2 挂载后自动获取   │ Pod 挂载后自动注入 Token            │
#    └──────────────────────┴───────────────────────────────────┘
#
# 工作流对比：
#
#   AWS 侧                                K8s 侧
#   ─────                                 ─────
#   创建 IAM Role                          创建 ServiceAccount
#       ↓                                      ↓
#   绑定 IAM Policy                        绑定 Role/ClusterRole
#       ↓                                      ↓
#   挂到 EC2 (instance_profile)            挂到 Pod (serviceAccountName)
#       ↓                                      ↓
#   App 用 AWS SDK 无需写密钥              App 用 K8s API 无需写 kubeconfig
#
# ============================================================================
#
# 问：本来 AWS 中什么东西相当于 K8s 中的 ServiceAccount？
#    还是 AWS 中既有 IAM，又有 ServiceAccount？
#    在 K8s 中，什么相当于 AWS 中的 IAM？
#
# 答：概念对照：
#
#   AWS 世界观                         K8s 世界观
#   ──────────                         ──────────
#   IAM User                           User / Group
#     （人或程序的永久身份）               （人或外部系统的身份）
#
#   IAM Policy                          Role / ClusterRole
#     （权限规则集："允许做什么"）          （权限规则集："允许做什么"）
#
#   IAM Role                            ServiceAccount
#     （给 AWS 服务的临时身份）            （给 Pod 的临时身份）
#     ↑ 这个是"SA"                       ↑ 这个是"SA"
#
#   关键结论：
#   - AWS 中的 IAM Role ≈ K8s 中的 ServiceAccount（都是给"服务"用的身份）
#   - AWS 中的 IAM Policy ≈ K8s 中的 Role（都是权限规则）
#   - AWS 没有单独叫 "ServiceAccount" 的东西，它的 "ServiceAccount" 就是 IAM Role
#
#   为什么会有混淆：
#   AWS 后来在 EKS 中引入了 IRSA（IAM Roles for Service Accounts），
#   把两个世界的概念对接起来：
#
#     K8s ServiceAccount
#            │
#     通过 IRSA 关联
#            │
#       AWS IAM Role
#
#   Pod 通过 SA → 映射到 → AWS IAM Role → 获得访问 AWS 资源的权限
#
# ============================================================================
#
# 本项目中的关系：
#
#   AWS 账号 501264525584
#   │
#   ├── Root 用户（登录 AWS Console 用）
#   │   邮箱 + 密码，拥有所有权限
#   │   不由此 Terraform 管理
#   │
#   ├── IAM User: smart-invest-deploy-user（awscli 的身份）
#   │   通过 Access Key 调用 AWS API
#   │   aws sts get-caller-identity 看到的就是它
#   │   不由此 Terraform 管理
#   │
#   └── IAM Role: smart-invest-ec2-role  ← 这才是本文件定义的！
#       不是"用户"，而是给 EC2 实例"扮演"的角色
#       挂到 EC2 后，App 无需写 Access Key 就能访问 S3 等服务
#
# ============================================================================

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name    = "${var.project_name}-ec2-role"
    Project = var.project_name
  }
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-role"
  role = aws_iam_role.ec2_role.name
}
