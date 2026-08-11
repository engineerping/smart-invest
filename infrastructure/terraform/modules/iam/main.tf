# ==============================================================================
# IAM 模块 —— EC2 的身份与权限
# ==============================================================================
#
# 一句话理解：
#   这 个 模 块 给 EC2 发 一 张 "身 份 证"（IAM Role），
#   有 了 身 份 证，EC2 上 的 应 用 就 能 用 AWS 各 种 服 务（S3/CloudWatch/...），
#   而 不 需 要 在 代 码 里 写 密 钥。
#
# ==============================================================================
# 核心概念：IAM Role vs IAM User
# ==============================================================================
# ┌───────────────┬──────────────────────────────┬──────────────────────┐
# │               │ IAM User                     │ IAM Role             │
# ├───────────────┼──────────────────────────────┼──────────────────────┤
# │ 谁用它        │ 人（开发者）或程序（CI/CD）    │ AWS 服务（EC2/Lambda）│
# │ 认证方式      │ Access Key + Secret Key       │ 自动获取临时凭证     │
# │ 凭证有效期    │ 永久（除非手动轮换）           │ 临时（自动轮换）     │
# │ 类比          │ 长期员工卡                   │ 临时访客卡           │
# │ 安全最佳实践  │ 尽量少用                     │ ★ 优先使用            │
# └───────────────┴──────────────────────────────┴──────────────────────┘
#
# 为什么 EC2 要用 IAM Role 而不是硬编码 Access Key:
#   1. 安全：临时凭证自动轮换，不会泄露
#   2. 方便：不用在代码/配置文件里管理密钥
#   3. 合规：密钥不会进 Git，审计通过
#
# ==============================================================================
# IAM 工作流：EC2 如何获得权限
# ==============================================================================
#   1. 创建 IAM Role（本文件）→ 定义"这个角色能做什么"
#   2. 创建 Instance Profile → 把 Role "打包"成可以挂到 EC2 的形式
#   3. EC2 启动时绑定 Instance Profile → EC2 上自动获得 Role 的权限
#   4. 应用用 AWS SDK 无需配置密钥 → SDK 自动从 EC2 元数据获取临时凭证
#
#   EC2 元数据服务（Metadata Service）：
#     curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
#     这个内部 IP 只有 EC2 自己可以访问，返回临时凭证。
# ==============================================================================

# ==============================================================================
# IAM Role —— EC2 的"身份证"
# ==============================================================================
# assume_role_policy（信任策略）：谁可以扮演这个角色？
#   这里写的是 ec2.amazonaws.com → 意思是"允许 EC2 服务使用这个角色"。
#   这是 AWS 的安全机制：不是你创建了 Role 就能用，还得看谁有权"扮演"它。
#
#   类比：你有一张公司门禁卡（Role），但公司规定只有 8 楼员工
#   （EC2 服务）能申请这张卡（assume role），其他人不行。
# ==============================================================================
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  # ─── 信任策略：谁可以扮演这个角色 ───
  # 格式是 AWS IAM Policy JSON（和 Terraform 无关的 AWS 标准格式）。
  # jsonencode() 是 Terraform 函数，把 HCL object 转成 JSON 字符串。
  assume_role_policy = jsonencode({
    Version = "2012-10-17" # IAM Policy 语言版本（AWS 固定值）
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com" # 允许 EC2 服务扮演此角色
        }
        Action = "sts:AssumeRole"       # AssumeRole = "扮演角色" 的 AWS API
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-ec2-role"
    Project = var.project_name
  }
}

# ==============================================================================
# IAM Policy Attachment —— 给角色绑定具体权限
# ==============================================================================
# 上面的 assume_role_policy 只是说"EC2 可以用这个角色"，
# 但还没有说"这个角色可以做什么"——那要靠 Policy Attachment。
#
# 这里使用 AWS 托管策略（AWS managed policy），也就是 AWS 官方预先定义好的权限集合。
# 托管策略 vs 内联策略：
#   - 托管策略：独立的 Policy 对象，可以复用到多个 Role
#   - 内联策略：写在 Role 定义里的，专属于这一个 Role，不支持复用
#   - 托管策略是推荐做法。
# ==============================================================================

# ─── CloudWatch Agent 权限 ───
# 允许 EC2 把系统指标（CPU、内存、磁盘）和自定义日志发送到 CloudWatch。
# CloudWatchServerFullAccess = 对 CloudWatch 的完全访问（读写）。
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  # ARN = Amazon Resource Name，AWS 中每个资源的全局唯一标识符。
  # 格式：arn:aws:iam::<账号ID>:policy/<策略名>
  # aws:policy/ 前缀表示这是 AWS 官方托管策略。
}

# ─── AWS Systems Manager (SSM) 权限 ───
# 允许通过 SSM Session Manager 登录 EC2（不用 SSH，更安全）。
# 好处：不需要开放 22 端口，不需要管理 SSH 密钥，
#       所有操作有审计日志（谁什么时候登录做了什么）。
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ==============================================================================
# Instance Profile —— 把 IAM Role "挂"到 EC2 上
# ==============================================================================
# Instance Profile 是 IAM Role 和 EC2 之间的"桥梁"。
# 一个 Instance Profile 只能绑定一个 IAM Role，但可以给多台 EC2 使用。
#
# 为什么不直接把 Role 传给 EC2？
#   历史原因。AWS 的 EC2 最初用 Instance Profile 来给角色授权，
#   后来虽然可以直接在控制台选 Role，但 API 层面 Instance Profile 依然存在。
#   你可以把这个理解为 AWS 的"遗留设计"。
# ==============================================================================
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-role"
  role = aws_iam_role.ec2_role.name
}
