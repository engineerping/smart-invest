# ==============================================================================
# 根模块 —— 编排所有子模块
# ==============================================================================
# 这个文件是 Terraform 项目的"入口"（类比 Spring 的 DI 容器）。
# 它负责调用各个子模块，并把模块之间的依赖串起来。
#
# 模块调用语法：
#   module "<本地名称>" {
#     source = "<模块代码路径>"   # 相对路径 / Git URL / Registry 路径
#     ...参数...                  # 传给模块的变量
#   }
#
# 模块之间的依赖是隐式的——Terraform 通过引用关系自动推导：
#   module.cdn → 需要 module.compute.public_dns
#   → Terraform 会先创建 compute，再创建 cdn
#   → 这就是 Terraform 的 DAG（有向无环图）执行引擎
# ==============================================================================

# ==============================================================================
# Networking 模块 —— 网络基础设施
# ==============================================================================
# 创建安全组（防火墙规则）、查询已有 VPC 和子网。
# 这是最底层的模块，不依赖其他模块。
# ==============================================================================
module "networking" {
  source = "../../modules/networking"

  project_name = var.project_name
}

# ==============================================================================
# IAM 模块 —— EC2 的身份与权限
# ==============================================================================
# 创建 IAM Role 和 Instance Profile，让 EC2 能访问 CloudWatch 等服务。
# 这也是底层模块，不依赖其他模块。
# ==============================================================================
module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
}

# ==============================================================================
# Compute 模块 —— EC2 实例（K3S 运行节点）
# ==============================================================================
# 创建 EC2 实例 + 弹性 IP。
# 依赖 networking 模块（安全组 + 子网）和 iam 模块（Instance Profile）。
# ==============================================================================
module "compute" {
  source = "../../modules/compute"

  project_name          = var.project_name
  instance_type         = var.instance_type
  ebs_volume_size       = var.ebs_volume_size
  key_pair_name         = var.key_pair_name
  public_subnet_id      = module.networking.public_subnet_id      # 引用 networking 模块的输出
  security_group_id     = module.networking.security_group_id      # 引用安全组
  instance_profile_name = module.iam.instance_profile_name         # 引用 IAM 模块的输出
}

# ==============================================================================
# CDN 模块 —— CloudFront + S3 + WAF（前端托管 + CDN + 安全）
# ==============================================================================
# 创建 S3 存储桶、CloudFront 分发和 WAF Web ACL。
# 依赖 compute 模块（需要 EC2 的公网 DNS 作为回源地址）。
# ==============================================================================
module "cdn" {
  source = "../../modules/cdn"

  project_name    = var.project_name
  aws_region      = var.aws_region
  s3_bucket_name  = var.s3_bucket_name
  ec2_public_dns  = module.compute.public_dns # CloudFront 回源到 EC2 需要这个

  # ─── WAF 需要 us-east-1 provider ───
  # providers 元参数：指定这个模块使用哪个 provider instance。
  # cdn 模块里的 aws_wafv2_web_acl 需要 alias = "us_east_1" 的 provider。
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}
