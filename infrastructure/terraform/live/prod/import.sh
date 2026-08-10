#!/bin/bash
# ==============================================================================
# Terraform Import 脚本 —— 将已存在的 AWS 资源导入 Terraform 管理
# ==============================================================================
#
# 使用方式：
#   chmod +x import.sh
#   ./import.sh
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
#   - 按依赖顺序导入（先 VPC/子网 → EC2 → CloudFront → WAF）
#   - 每次导入后运行 terraform plan 验证
#   - 如果 import 报错"资源不存在"，检查 ID 是否正确
#   - 如果 plan 显示要重建资源，说明配置和实际不完全匹配——修正 .tf 配置
# ==============================================================================

set -e  # 任何命令失败就停止（安全机制）

echo "================================================"
echo "  Smart Invest — AWS 资源导入脚本"
echo "================================================"
echo ""
echo "导入顺序：安全组 → EC2 → WAF → S3 → CloudFront"
echo ""

# ─── 确认 AWS 身份 ───
echo ">>> 确认当前 AWS 身份..."
aws sts get-caller-identity
echo ""

read -p "以上是你的目标 AWS 账号吗？按 Enter 继续 / Ctrl+C 取消"

# ══════════════════════════════════════════════════════════════════════
# 1. 安全组 —— 最先导入（EC2 依赖它）
# ══════════════════════════════════════════════════════════════════════
# 替换 sg-xxxxxxxxxxxx 为你的实际安全组 ID
echo ">>> [1/4] 导入安全组..."
terraform import \
  aws_security_group.smart_invest \
  sg-xxxxxxxxxxxx  # ⚠️ 替换为你的安全组 ID

# ══════════════════════════════════════════════════════════════════════
# 2. EC2 实例 —— 核心资源
# ══════════════════════════════════════════════════════════════════════
# 替换 i-xxxxxxxxxxxx 为你的实际 EC2 实例 ID
echo ">>> [2/5] 导入 EC2 实例..."
terraform import \
  aws_instance.k3s_server \
  i-xxxxxxxxxxxx  # ⚠️ 替换为你的 EC2 实例 ID

# ─── EC2 弹性 IP ───
echo ">>> [3/5] 导入弹性 IP..."
terraform import \
  aws_eip.k3s \
  eipalloc-xxxxxxxxxxxx  # ⚠️ 替换为你的 EIP allocation ID

# ══════════════════════════════════════════════════════════════════════
# 3. WAF Web ACL —— 必须在 us-east-1（CloudFront 硬性要求）
# ══════════════════════════════════════════════════════════════════════
echo ">>> [4/5] 导入 WAF Web ACL..."
terraform import \
  aws_wafv2_web_acl.cloudfront_waf \
  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  # ⚠️ 替换为你的 WAF Web ACL ID

# ══════════════════════════════════════════════════════════════════════
# 4. S3 存储桶
# ══════════════════════════════════════════════════════════════════════
echo ">>> [5/5] 导入 S3 存储桶..."
terraform import \
  aws_s3_bucket.frontend \
  smart-invest-frontend-service-prod-bucket-name  # ⚠️ 替换为你的 S3 桶名

# ══════════════════════════════════════════════════════════════════════
# 5. CloudFront Distribution
# ══════════════════════════════════════════════════════════════════════
echo ">>> [6/6] 导入 CloudFront Distribution..."
terraform import \
  aws_cloudfront_distribution.main \
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
