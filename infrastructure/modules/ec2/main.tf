# =============================================================================
# EC2 模块 —— 应用服务器
# =============================================================================
# EC2（Elastic Compute Cloud）是 AWS 最核心的计算服务。
# 本质上就是在 AWS 数据中心里给你一台虚拟机，你可以完全控制它。
#
# 本模块创建以下资源：
#   1. EC2 实例（t3.small，Amazon Linux 2023）
#   2. 弹性 IP（EIP）—— 固定的公网 IP
#   3. UserData 脚本——启动时自动初始化环境
#
# EC2 实例类型选择（t3.small）：
#   T 系列 = 可突发性能（平时低负载，需要时可以 burst）
#   适用场景：Web 应用、微服务、开发环境
#   不适用：持续高 CPU 的任务（如视频转码、ML 训练）
#   CPU 积分机制：低负载时积累积分，高负载时消耗积分
#   t3.small = 2 vCPU + 2 GB RAM
#
# Amazon Linux 2023 vs Amazon Linux 2：
#   - AL2023 是最新版本，基于 Fedora
#   - 预装 AWS CLI、SSM Agent、cloud-init
#   - 安全更新支持到 2028 年
# =============================================================================

# =============================================================================
# AMI 数据源 —— 最新的 Amazon Linux 2023 镜像
# =============================================================================
# Data Source（数据源）不创建资源，而是查询已有信息。
# 这里的 data "aws_ami" 查询 AWS 上最新的 AL2023 AMI ID。
#
# 为什么用 data 而不是硬编码 AMI ID？
#   1. AMI ID 是区域相关的（us-east-1 和 ap-southeast-1 的 ID 不同）
#   2. AWS 会持续更新 AMI，硬编码的 ID 可能过期或包含已知漏洞
#   3. 用 data 查询总能获取最新最安全的镜像
#
# 筛选条件说明：
#   - name 模式: al2023-ami-*-x86_64 → 匹配所有 AL2023 x86_64 架构的 AMI
#   - owners: amazon → 只选 AWS 官方发布的 AMI（不是第三方或个人制作的）
#   - most_recent: true → 多个符合条件时取最新（按创建时间）
#   - virtualization-type: hvm → HVM 虚拟化（现代硬件辅助虚拟化，已是标准）
# =============================================================================
data "aws_ami" "al2023" {
  most_recent = true                    # 获取最新版本
  owners      = ["amazon"]             # AWS 官方发布的 AMI

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]   # Amazon Linux 2023, x86_64 架构
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]                    # 硬件辅助虚拟化（现代标准）
  }
}

# =============================================================================
# EC2 实例 —— 应用服务器
# =============================================================================
# EC2 实例是实际的虚拟机。每个参数都影响成本、性能和安全。
#
# 关键配置说明：
#   - ami: 操作系统镜像（决定安装了什么软件）
#   - instance_type: 硬件规格（CPU + RAM，决定性能上限）
#   - subnet_id: 网络位置（公有/私有子网）
#   - vpc_security_group_ids: 防火墙规则
#   - iam_instance_profile: IAM 角色（权限）
#   - key_name: SSH 密钥对（登录方式）
#   - user_data: 实例启动时自动执行的脚本
# =============================================================================
resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id        # Amazon Linux 2023 最新 AMI
  instance_type          = "t3.small"                    # 2 vCPU + 2 GB RAM
  subnet_id              = var.public_subnet_id          # 放在公有子网（需要公网 IP）
  vpc_security_group_ids = [var.ec2_sg_id]               # EC2 安全组（HTTPS + SSH）
  iam_instance_profile   = var.instance_profile_name     # IAM 实例配置文件（授予权限）
  key_name               = var.key_pair_name             # SSH 密钥对名称

  # -------------------------------------------------------------------
  # user_data: 实例启动时自动执行的初始化脚本
  #
  # UserData 是 cloud-init 脚本，在实例首次启动时执行一次。
  # 用 templatefile() 函数将变量注入到脚本模板中。
  #
  # templatefile("${path.module}/user_data.sh", {...}):
  #   - path.module: Terraform 内置变量，当前模块目录的绝对路径
  #   - 第二个参数: 传递给模板的变量映射（模板中用 ${key} 引用）
  #
  # UserData 脚本负责：
  #   1. 安装 Java 17（Spring Boot 运行时）
  #   2. 安装 AWS CLI（从 Secrets Manager 获取数据库密码）
  #   3. 从 S3 下载应用 JAR 包
  #   4. 获取数据库密码
  #   5. 启动 Spring Boot 应用
  #
  # 调试 UserData 脚本的日志：
  #   sudo cat /var/log/cloud-init-output.log
  # -------------------------------------------------------------------
  user_data = templatefile("${path.module}/user_data.sh", {
    db_secret_arn = var.db_secret_arn    # Secrets Manager 中数据库密码的 ARN
    aws_region    = var.region           # AWS 区域（用于 AWS CLI）
    app_jar_s3    = var.app_jar_s3_path  # S3 上 JAR 包的路径
  })

  # -------------------------------------------------------------------
  # root_block_device: 系统盘配置
  #
  # gp3 vs gp2:
  #   - gp3: 新一代通用 SSD，更便宜，默认 3000 IOPS 和 125 MB/s
  #   - gp2: 上代产品，IOPS 随容量线性增长（100 GB = 300 IOPS）
  #
  # volume_size = 20 GB:
  #   - 操作系统 + Java + 应用 JAR = 约 5-8 GB
  #   - 留了足够空间给日志和其他文件
  #   - 不够可以后续扩容（AWS 支持在线扩容，不需要重启）
  #
  # 注意：系统盘会在实例终止时默认删除（delete_on_termination = true 是默认值）
  # -------------------------------------------------------------------
  root_block_device {
    volume_type = "gp3"    # 新一代通用 SSD
    volume_size = 20       # 20 GB
  }

  tags = { Name = "smart-invest-app" }
}

# =============================================================================
# 弹性 IP（EIP）—— 固定的公网 IP
# =============================================================================
# 弹性 IP 是静态的 IPv4 地址，绑定到 EC2 实例上。
#
# 为什么需要 EIP：
#   1. EC2 默认公网 IP 在重启后会改变（停止→启动 = 新 IP）
#   2. EIP 绑定后保持不变，即使实例重启也不会变
#   3. 方便配置 DNS 记录指向服务器
#
# EIP 的计费：
#   - 绑定到运行中的实例：免费（每个账号 1 个）
#   - 未绑定（闲置）：按小时收费（防止囤积 IP）
#   - 绑定到已停止的实例：按小时收费
#
# EIP 限制：
#   - IPv4 地址是全球稀缺资源，每个 AWS 账号默认限制 5 个 EIP
#   - 如果不够用，可以申请配额提升
# =============================================================================
resource "aws_eip" "app" {
  instance = aws_instance.app.id   # 绑定到 EC2 实例
  domain   = "vpc"                 # VPC 类型的 EIP（新标准，替代 EC2-Classic）
}
