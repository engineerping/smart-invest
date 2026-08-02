# =============================================================================
# Terraform Provider 配置
# =============================================================================
# 说明：定义 Terraform 使用的云服务提供商及其版本约束
#       锁定 Provider 版本非常重要，可以保证 IaC 代码的可复现性
#       不会因为 Provider 自动升级而导致不可预期的变更

terraform {
  # --- Terraform 核心版本要求 ---
  # 使用 >= 1.0 版本，支持 module 的 for_each 和 count 等特性
  required_version = ">= 1.0"

  # --- 必选 Provider ---
  required_providers {
    # AWS 官方 Provider：用于创建所有 AWS 资源（EKS、RDS、VPC 等）
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # ~> 表示只允许 5.x 版本自动升级，不会跳到 6.x
    }

    # Kubernetes Provider：用于在 EKS 集群创建后，部署 K8s 原生资源
    # 例如：Namespace、ServiceAccount、ConfigMap、RBAC 等
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }

    # Helm Provider：用于通过 Helm Chart 部署应用
    # 例如：部署 Istio 服务网格、Kong Gateway、Prometheus + Grafana 等
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }

    # Kubectl Provider：用于执行 kubectl apply 命令
    # 适合部署一些不方便用 Helm 的资源（如自定义 CRD）
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }

  # --- 远程状态存储（Backend）---
  # 将 Terraform 状态文件存储在 S3 中，而不是本地磁盘
  # 这样做的好处：
  #   1. 多人协作时共享同一份状态，避免冲突
  #   2. S3 自动持久化，本地电脑坏了状态不会丢
  #   3. DynamoDB 提供状态锁，防止两个人同时修改
  backend "s3" {
    # 注意：bucket 名称和 region 需要在 terraform init 时通过 -backend-config 传入
    # 因为 terraform 块中不能使用变量
    bucket         = "smart-invest-terraform-state"  # S3 桶名
    key            = "eks/terraform.tfstate"          # 状态文件路径
    region         = "ap-southeast-1"                  # S3 桶所在区域
    encrypt        = true                              # 服务端加密
    dynamodb_table = "terraform-state-lock"            # DynamoDB 表用于锁定
  }
}

# =============================================================================
# AWS Provider 配置
# =============================================================================
# 主区域 Provider：所有核心资源都部署在这个区域
provider "aws" {
  region = var.aws_region  # 例如 ap-southeast-1（新加坡）
  # 使用默认的认证链：环境变量 -> ~/.aws/credentials -> IAM Role
}

# 备用区域 Provider（用于两地三中心容灾）
# 两地三中心 = 主区域(2个AZ) + 备用区域(1个AZ)
provider "aws" {
  alias  = "dr"            # 给这个 Provider 起个别名，使用时要写 provider = aws.dr
  region = var.dr_region   # 例如 ap-southeast-3（雅加达）
}
