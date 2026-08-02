# =============================================================================
# EKS 模块 - Kubernetes 集群
# =============================================================================
# EKS (Elastic Kubernetes Service) 是 AWS 托管 的 Kubernetes 服务
# 你只需管理 Worker 节点，控制平面由 AWS 托管（免费升级、自动扩容）
#
# 架构组件：
#   1. EKS Cluster：K8s 控制平面（API Server、etcd、Scheduler、Controller Manager）
#   2. Node Group：Worker 节点组（运行 Pod 的 EC2 实例）
#   3. Fargate Profile（可选）：Serverless 容器（不需要管理节点）
#   4. Add-ons：EKS 插件（CoreDNS、kube-proxy、VPC CNI）
#
# 与自建 K8s 的对比：
#   - EKS 自动管理 etcd 集群备份、API Server 高可用
#   - 内置与 AWS IAM 集成（IRSA），安全性更高
#   - 支持 Fargate 无服务器模式

# ==============================
# 1. EKS 集群控制平面
# ==============================
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-${var.environment}"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

  # --- 网络配置 ---
  # EKS 控制平面需要知道你指定的子网，但它不直接运行在这些子网中
  # 它运行在 AWS 托管 的 VPC 中，通过 ENI（弹性网卡）连接到你的子网
  vpc_config {
    subnet_ids              = var.subnet_ids          # Worker 节点所在的子网
    endpoint_private_access = true                     # 启用私有端点（从 VPC 内部访问）
    endpoint_public_access  = true                     # 启用公有端点（从本地 kubectl 访问）
    # 安全组：控制哪些流量可以访问 EKS API Server
    security_group_ids = [var.cluster_sg_id]
  }

  # --- 日志记录 ---
  # 开启控制平面日志，用于审计和安全分析
  enabled_cluster_log_types = [
    "api",        # K8s API Server 日志
    "audit",      # 审计日志（谁在何时做了什么操作）
    "authenticator", # 认证日志
    "controllerManager",
    "scheduler",
  ]

  # --- 加密配置 ---
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn  # 用 KMS 密钥加密 K8s Secrets
    }
    resources = ["secrets"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-cluster"
  })

  # 确保 IAM 角色先创建（包括依赖的 OIDC Provider Policy）
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
  ]
}

# ==============================
# 2. EKS 加密密钥
# ==============================
resource "aws_kms_key" "eks" {
  description             = "EKS Secrets 加密密钥"
  deletion_window_in_days = 30
  enable_key_rotation     = true  # 自动轮换密钥

  tags = var.common_tags
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.project_name}-${var.environment}-eks-secrets"
  target_key_id = aws_kms_key.eks.key_id
}

# ==============================
# 3. EKS IAM Role（集群级别的权限）
# ==============================
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  # 信任策略：允许 EKS 服务使用这个角色
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

# 挂载 AWS 管理 的策略（由 AWS 维护和更新）
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster.name
}

# ==============================
# 4. EKS Node Group IAM Role
# ==============================
resource "aws_iam_role" "eks_node_group" {
  name = "${var.project_name}-${var.environment}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"  # EC2 实例需要这个角色
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

# Worker 节点需要的 AWS 管理策略
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

# ==============================
# 5. EKS Managed Node Group（托管节点组）
# ==============================
# 托管节点组的优势：
#   - AWS 自动管理节点生命周期（更新 AMI、打补丁、替换故障节点）
#   - 自动加入集群，无需手动 bootstrap
#   - 与 Cluster Autoscaler 集成（自动扩缩容）
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-${var.environment}-nodes"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = var.subnet_ids  # 注意：Worker 节点放在私有子网

  # --- 扩缩容配置 ---
  scaling_config {
    desired_size = var.node_desired_size  # 当前期望节点数
    max_size     = var.node_max_size      # Cluster Autoscaler 最大扩容数量
    min_size     = var.node_min_size      # 最小保持节点数
  }

  # --- 实例类型 ---
  # 使用混合实例类型可以提高可用性（当一个类型的 Spot 容量不足时自动切到另一个）
  instance_types = var.node_instance_types
  capacity_type  = "ON_DEMAND"  # ON_DEMAND(按需) 或 SPOT(竞价，更便宜但不稳定)

  # --- 磁盘配置 ---
  disk_size = 50  # 每个节点的系统盘大小（GB）

  # --- AMI 类型 ---
  # AL2_x86_64: Amazon Linux 2 (x86)
  # AL2_ARM_64: Amazon Linux 2 (ARM/Graviton)，更便宜
  ami_type = "AL2_x86_64"

  # --- 更新配置 ---
  # 控制节点组更新行为（增加 timeout 避免更新过程中的超时错误）
  update_config {
    max_unavailable_percentage = 33  # 同时最多 33% 节点不可用
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-node-group"
  })

  # 等待所有权限关联完成
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_readonly,
  ]
}

# ==============================
# 6. EKS Add-ons (核心插件)
# ==============================

# CoreDNS：集群内部的 DNS 服务，服务名 → IP 解析
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
  addon_version = "v1.11.1-eksbuild.4"  # 指定版本，保证可复现性
}

# kube-proxy：维护每个节点的网络规则（iptables）
resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "kube-proxy"
  addon_version = "v1.29.0-eksbuild.2"
}

# VPC CNI：Pod 网络插件（每个 Pod 获得一个 VPC 内的私有 IP）
resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "vpc-cni"
  addon_version = "v1.16.0-eksbuild.1"
}

# EBS CSI Driver：给 Pod 提供持久化存储（EBS 卷）
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = "v1.28.0-eksbuild.1"
}

# ==============================
# 7. OIDC Provider (用于 IRSA)
# ==============================
# IRSA = IAM Roles for Service Accounts
# 这个机制让 K8s 中的 Pod 可以安全地获取 AWS 权限
# 原理：
#   1. EKS 创建 OIDC Provider（OpenID Connect）
#   2. IAM Role 信任这个 OIDC Provider
#   3. K8s ServiceAccount 注解了这个 IAM Role 的 ARN
#   4. Pod 运行时自动获得临时 AWS 凭证（STS Token）
#
# 对比旧方案（把 AccessKey 写死）：
#   - 优点1：凭证是临时的，自动轮换，不需要管理静态密钥
#   - 优点2：权限精细化，每个 ServiceAccount 可以有不同的 IAM Role
#   - 优点3：审计日志完整，谁在什么时候获取了什么权限

# 从 EKS 集群获取 OIDC Provider 的 URL 和证书
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]  # 信任的服务
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.common_tags
}
