#!/bin/bash
# ==============================================================================
# 对应的自动化版本是 /Users/gcsp/coding/claude_code_workspace/smart-invest/infrastructure/terraform/live/prod/import.py
# Terraform Import 脚本（手动版）—— 将已存在的 AWS 资源导入 Terraform 管理
# ==============================================================================
#
# 使用方式：
#   1. 先运行下面的 AWS CLI 命令获取各资源 ID
#   2. 将 ID 替换掉脚本中的占位符
#   3. chmod +x import_manual.sh && ./import_manual.sh
#
# 前置条件：
#   1. cp terraform.tfvars.example terraform.tfvars（已编辑好变量）
#   2. terraform init（已下载 Provider）
#   3. 确认当前的 AWS 凭证连接正确：aws sts get-caller-identity
#
# 工作原理：
#   terraform import <Terraform资源地址> <AWS资源ID>
#   - 不创建/修改 AWS 资源
#   - 只是把已有资源"登记"到 terraform.tfstate 中
#   - import 后运行 terraform plan，确认无差异后，再 terraform apply
#
# 为什么需要 import：
#   如果 AWS 上已经有手动创建的资源，Terraform 默认不知道它们的存在。
#   直接 terraform apply → Terraform 会尝试重新创建 → 资源名冲突报错。
#   先用 import 注册已有资源 → Terraform 知道它们存在 → plan 无差异 → 安全。
#
# ⚠️ 注意事项：
#   - 按依赖顺序导入（先 IAM/Role → SG/EC2 → S3 → CloudFront）
#   - 每次导入后运行 terraform plan 验证
#   - 如果 import 报错"资源不存在"，检查 ID 是否正确
#   - 如果 plan 显示要重建资源，说明配置和实际不完全匹配——修正 .tf 配置
# ==============================================================================

set -e  # 任何命令失败就停止（安全机制）

echo "================================================"
echo "  Smart Invest — AWS 资源导入脚本（手动版）"
echo "================================================"
echo ""
echo "导入顺序：安全组 → EC2 → S3 → CloudFront"
echo ""

# ─── 确认 AWS 身份 ───
echo ">>> 确认当前 AWS 身份..."
aws sts get-caller-identity
echo ""

read -p "以上是你的目标 AWS 账号吗？按 Enter 继续 / Ctrl+C 取消"

# ══════════════════════════════════════════════════════════════════════
# 1. IAM 角色 + Instance Profile + Policy Attachment
# ══════════════════════════════════════════════════════════════════════
echo ">>> [1/6] 导入 IAM 角色..."

# 查你的 IAM 角色名：
# aws iam get-role --role-name smart-invest-ec2-role --query "Role.RoleName" --output text

terraform import \
  module.iam.aws_iam_role.ec2_role \
  smart-invest-ec2-role  # ⚠️ 替换为你的 IAM 角色名

echo ">>> [1.1/6] 导入 Instance Profile..."

terraform import \
  module.iam.aws_iam_instance_profile.ec2_profile \
  smart-invest-ec2-role  # ⚠️ 替换为你的 Instance Profile 名

# ✅ 修正：只 import 实际绑定的 3 个策略（SES / ECR / SecretsManager）
echo ">>> [1.2/6] 导入 IAM Policy Attachment (SES)..."

terraform import \
  module.iam.aws_iam_role_policy_attachment.ses \
  "smart-invest-ec2-role/arn:aws:iam::aws:policy/AmazonSESFullAccess"  # ⚠️ 替换角色名

echo ">>> [1.3/6] 导入 IAM Policy Attachment (ECR)..."

terraform import \
  module.iam.aws_iam_role_policy_attachment.ecr \
  "smart-invest-ec2-role/arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"  # ⚠️ 替换角色名

echo ">>> [1.4/6] 导入 IAM Policy Attachment (Secrets Manager)..."

terraform import \
  module.iam.aws_iam_role_policy_attachment.secrets \
  "smart-invest-ec2-role/arn:aws:iam::aws:policy/SecretsManagerReadWrite"  # ⚠️ 替换角色名

# ══════════════════════════════════════════════════════════════════════
# 2. 安全组 —— 最先导入（EC2 依赖它）
# ══════════════════════════════════════════════════════════════════════
echo ">>> [2/6] 导入安全组..."

# 查你的安全组 ID：
# aws ec2 describe-security-groups --query "SecurityGroups[*].[GroupId,GroupName,Description]" --output table

terraform import \
  module.networking.aws_security_group.smart_invest \
  sg-xxxxxxxxxxxx  # ⚠️ 替换为你的安全组 ID

# ══════════════════════════════════════════════════════════════════════
# 3. EC2 实例 —— 核心资源
# ══════════════════════════════════════════════════════════════════════
echo ">>> [3/6] 导入 EC2 实例..."

# 查你的 EC2 实例 ID：
# aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,InstanceType,Tags[?Key=='Name'].Value|[0]]" --output table

terraform import \
  module.compute.aws_instance.k3s_server \
  i-xxxxxxxxxxxx  # ⚠️ 替换为你的 EC2 实例 ID

# ══════════════════════════════════════════════════════════════════════
# 4. 弹性 IP —— 依附于 EC2
# ══════════════════════════════════════════════════════════════════════
echo ">>> [4/6] 导入弹性 IP..."

# 查你的弹性 IP allocation ID：
# aws ec2 describe-addresses --query "Addresses[*].[AllocationId,PublicIp,InstanceId]" --output table

terraform import \
  module.compute.aws_eip.k3s \
  eipalloc-xxxxxxxxxxxx  # ⚠️ 替换为你的 EIP allocation ID

# ══════════════════════════════════════════════════════════════════════
# 5. S3 存储桶
# ══════════════════════════════════════════════════════════════════════
echo ">>> [5/6] 导入 S3 存储桶..."

# 查你的 S3 桶名列表：
# aws s3api list-buckets --query "Buckets[*].Name" --output table

terraform import \
  module.cdn.aws_s3_bucket.frontend \
  your-bucket-name-here  # ⚠️ 替换为你的 S3 桶名

# WAF 已改为 data source（由 CloudFront 自动创建），无需 import
# S3 versioning 实际未开启，无需 import

# ══════════════════════════════════════════════════════════════════════
# 6. CloudFront Distribution
# ══════════════════════════════════════════════════════════════════════
echo ">>> [6/6] 导入 CloudFront Distribution..."

# 查你的 CloudFront Distribution ID：
# aws cloudfront list-distributions --query "DistributionList.Items[*].[Id,DomainName,Comment]" --output table

terraform import \
  module.cdn.aws_cloudfront_distribution.main \
  EXXXXXXXXXXXX  # ⚠️ 替换为你的 CloudFront Distribution ID

# ══════════════════════════════════════════════════════════════════════
# 完成后验证
# ══════════════════════════════════════════════════════════════════════
echo ""
echo "================================================"
echo "  ✅ 导入完成！"
echo "================================================"
echo ""
echo "请立即运行以下命令验证："
echo ""
echo "  terraform plan"
echo ""
echo "期望看到：No changes. Your infrastructure matches the configuration."
echo "如果 plan 显示要修改/删除资源，说明 .tf 配置和实际资源有差异，"
echo "请修正 .tf 文件后再次 plan，直到看到 No changes。"
