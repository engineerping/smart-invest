# =============================================================================
# 安全组模块 - 网络安全规则
# =============================================================================
# 安全组 (Security Group) 相当于一个"虚拟防火墙"
# 它定义了什么流量可以进入（inbound）和离开（outbound）资源
# 类比：安全组就是每个服务的"门禁系统"
#
# 默认规则：所有出站流量允许，所有入站流量拒绝
# 你需要"白名单"模式：只开放必要的端口

# ==============================
# 1. EKS 集群安全组
# ==============================
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-${var.environment}-eks-cluster-sg"
  description = "EKS 集群控制平面的安全组"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-cluster-sg"
  })
}

# EKS 集群之间互相通信（HTTPS）
resource "aws_vpc_security_group_ingress_rule" "eks_cluster_self" {
  security_group_id = aws_security_group.eks_cluster.id

  description                  = "EKS 集群自引用（控制平面内部通信）"
  referenced_security_group_id = aws_security_group.eks_cluster.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# 允许管理员从公司网络访问 EKS API
resource "aws_vpc_security_group_ingress_rule" "eks_cluster_admin" {
  count = length(var.admin_cidrs)

  security_group_id = aws_security_group.eks_cluster.id

  description = "管理员访问 EKS API Server"
  cidr_ipv4   = var.admin_cidrs[count.index]
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

# ==============================
# 2. EKS 工作节点安全组
# ==============================
resource "aws_security_group" "eks_node" {
  name        = "${var.project_name}-${var.environment}-eks-node-sg"
  description = "EKS Worker 节点的安全组"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-node-sg"
  })
}

# 允许节点组内通信（Pods 跨节点通信走 VPC CNI）
resource "aws_vpc_security_group_ingress_rule" "eks_node_self" {
  security_group_id = aws_security_group.eks_node.id

  description                  = "Worker 节点之间互相通信"
  referenced_security_group_id = aws_security_group.eks_node.id
  from_port                    = 0
  to_port                      = 65535  # 开放所有端口用于 Pod 通信
  ip_protocol                  = "tcp"
}

# 允许 EKS 控制平面访问 Worker 节点的 Kubelet（默认 10250 端口）
resource "aws_vpc_security_group_ingress_rule" "eks_node_from_cluster" {
  security_group_id = aws_security_group.eks_node.id

  description                  = "EKS 控制平面访问 Kubelet"
  referenced_security_group_id = aws_security_group.eks_cluster.id
  from_port                    = 1025
  to_port                      = 65535
  ip_protocol                  = "tcp"
}

# ==============================
# 3. 堡垒机安全组（管理员 SSH 入口）
# ==============================
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "堡垒机安全组 - 管理员 SSH 入口"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
  })
}

# 只允许从管理员 IP 段 SSH 登录
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  count = length(var.admin_cidrs)

  security_group_id = aws_security_group.bastion.id

  description = "SSH from admin IP"
  cidr_ipv4   = var.admin_cidrs[count.index]
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

# ==============================
# 4. Aurora 数据库安全组
# ==============================
resource "aws_security_group" "aurora" {
  name        = "${var.project_name}-${var.environment}-aurora-sg"
  description = "Aurora PostgreSQL 安全组"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-aurora-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "aurora_from_eks" {
  security_group_id = aws_security_group.aurora.id

  description                  = "EKS Worker 节点访问 Aurora"
  referenced_security_group_id = aws_security_group.eks_node.id
  from_port                    = var.ports.postgresql  # 5432
  to_port                      = var.ports.postgresql
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "aurora_from_bastion" {
  security_group_id = aws_security_group.aurora.id

  description                  = "堡垒机访问 Aurora（DBA 管理用）"
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = var.ports.postgresql
  to_port                      = var.ports.postgresql
  ip_protocol                  = "tcp"
}

# ==============================
# 5. ElastiCache Redis 安全组
# ==============================
resource "aws_security_group" "elasticache" {
  name        = "${var.project_name}-${var.environment}-elasticache-sg"
  description = "ElastiCache Redis 安全组"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-elasticache-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_eks" {
  security_group_id = aws_security_group.elasticache.id

  description                  = "EKS Worker 节点访问 Redis"
  referenced_security_group_id = aws_security_group.eks_node.id
  from_port                    = var.ports.redis  # 6379
  to_port                      = var.ports.redis
  ip_protocol                  = "tcp"
}

# ==============================
# 6. DocumentDB 安全组
# ==============================
resource "aws_security_group" "documentdb" {
  name        = "${var.project_name}-${var.environment}-documentdb-sg"
  description = "DocumentDB (MongoDB) 安全组"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-documentdb-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "mongodb_from_eks" {
  security_group_id = aws_security_group.documentdb.id

  description                  = "EKS Worker 节点访问 DocumentDB"
  referenced_security_group_id = aws_security_group.eks_node.id
  from_port                    = var.ports.mongodb  # 27017
  to_port                      = var.ports.mongodb
  ip_protocol                  = "tcp"
}

# ==============================
# 7. Amazon MQ 安全组
# ==============================
resource "aws_security_group" "mq" {
  name        = "${var.project_name}-${var.environment}-mq-sg"
  description = "Amazon MQ 消息队列安全组"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-mq-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "mq_from_eks" {
  security_group_id = aws_security_group.mq.id

  description                  = "EKS Worker 节点访问 Amazon MQ (AMQP)"
  referenced_security_group_id = aws_security_group.eks_node.id
  from_port                    = var.ports.activemq  # 5671 (AMQP over TLS)
  to_port                      = var.ports.activemq
  ip_protocol                  = "tcp"
}

# ==============================
# 8. ALB/NLB 安全组（Web 流量入口）
# ==============================
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Application Load Balancer 安全组"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  })
}

# 允许来自互联网的 HTTP 和 HTTPS 流量
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id

  description = "HTTP from Internet"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = var.ports.http
  to_port     = var.ports.http
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id

  description = "HTTPS from Internet"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = var.ports.https
  to_port     = var.ports.https
  ip_protocol = "tcp"
}
