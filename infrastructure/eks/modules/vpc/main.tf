# =============================================================================
# VPC 模块 - 网络基础设施
# =============================================================================
# VPC (Virtual Private Cloud) 是 AWS 上的虚拟私有网络
# 你可以把它理解为：你在 AWS 云上划出的一块"私有土地"
# 所有的服务器、数据库、缓存都部署在这个 VPC 里面
#
# 架构设计原则：
#   - 公有子网 (Public Subnet): 放 NLB、Kong Ingress Controller（需要直接接收互联网流量）
#   - 私有子网 (Private Subnet): 放 EKS Worker 节点（应用 Pod）、微服务（不暴露给互联网）
#   - 数据库子网 (Database Subnet): 放 Aurora、ElastiCache、DocumentDB（最内层，最安全）
#   - NAT Gateway: 让私有子网内的资源可以访问互联网（例如拉取 Docker 镜像），
#     但互联网不能主动访问私有子网

# ==============================
# VPC 主资源
# ==============================
resource "aws_vpc" "main" {
  # --- CIDR 地址块 ---
  # 10.0.0.0/16 意味着这个 VPC 有 65536 个私有 IP 可用
  cidr_block = var.vpc_cidr

  # --- DNS 支持 ---
  # 启用 DNS 主机名解析：让 EC2 实例自动获得公有 DNS 名
  enable_dns_hostnames = true
  # 启用 DNS 解析：让 VPC 内部的资源可以通过 DNS 互相发现
  enable_dns_support = true

  # --- 标签 ---
  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
      # 额外标记：用于 Kubernetes Cloud Controller Manager 自动发现
      "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
    }
  )
}

# ==============================
# 公有子网 (Public Subnet)
# ==============================
# 公网流量 → Route Table → Internet Gateway → Public Subnet → NLB/Kong Ingress
resource "aws_subnet" "public" {
  count = length(var.availability_zones)  # 在每个 AZ 创建一个子网

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  # cidrsubnet 函数说明：
  #   cidrsubnet("10.0.0.0/16", 4, 0) = "10.0.0.0/20" (前 4096 个 IP)
  #   cidrsubnet("10.0.0.0/16", 4, 1) = "10.0.16.0/20" (接下来 4096 个 IP)
  #   cidrsubnet("10.0.0.0/16", 4, 2) = "10.0.32.0/20"
  #   4 表示把 /16 再分成 2^4 = 16 个子网，每个 /20

  availability_zone    = var.availability_zones[count.index]
  # 创建后自动为 EC2 分配公有 IP
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
      Type = "public"
      # 标记给 K8s Load Balancer Controller 识别
      "kubernetes.io/role/elb" = "1"
    }
  )
}

# ==============================
# 应用子网 (Private Subnet - 给 EKS 用)
# ==============================
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + length(var.availability_zones))
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-${var.availability_zones[count.index]}"
      Type = "private"
      # 标记给 K8s Load Balancer Controller 识别（内网 LB）
      "kubernetes.io/role/internal-elb" = "1"
    }
  )
}

# ==============================
# 数据库子网 (最内层的私有子网)
# ==============================
resource "aws_subnet" "database" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + length(var.availability_zones) * 2)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-database-${var.availability_zones[count.index]}"
      Type = "database"
    }
  )
}

# ==============================
# Internet Gateway (IGW)
# ==============================
# IGW 是 VPC 与互联网之间的"大门"
# 只有通过 IGW，VPC 内的公有子网才能与互联网通信
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-igw"
  })
}

# ==============================
# NAT Gateway (让私有子网访问互联网)
# ==============================
# NAT Gateway 工作原理：
#   私有子网内的 EC2/Pod → Route Table → NAT Gateway → IGW → 互联网
#   但互联网 → IGW → NAT Gateway ✗ 拒绝（单向连接）
# 为什么需要 NAT Gateway：
#   1. EKS Worker 节点需要从 Docker Hub/ECR 拉取镜像
#   2. Pod 内的应用需要调用外部 API（例如第三方行情数据）
#   3. 操作系统需要下载安全补丁
#
# 注意：NAT Gateway 本身放在公有子网，需要有公网 IP
resource "aws_eip" "nat" {
  # 每个 AZ 分配一个弹性公网 IP（共 3 个）
  count = length(var.availability_zones)
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "main" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  # 注意：NAT Gateway 部署在公有子网中

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
  })
}

# ==============================
# 路由表 (Route Table)
# ==============================

# 公有子网路由表：流量走 Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"       # 匹配所有公网 IP
    gateway_id = aws_internet_gateway.main.id  # 下一跳是 IGW
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
  })
}

# 私有子网路由表：流量走 NAT Gateway
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
    # 每个 AZ 的私有子网走自己 AZ 的 NAT Gateway
    # 好处：一个 AZ 的 NAT Gateway 坏了不影响其他 AZ
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-rt-${count.index + 1}"
  })
}

# ==============================
# 路由表关联 (子网 <-> 路由表)
# ==============================

# 公有子网 → 公有路由表
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 私有子网 → 各自 AZ 的 NAT 路由表
resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ==============================
# VPC Flow Logs (网络日志)
# ==============================
# 记录 VPC 内所有网络流量，用于安全审计和故障排查
resource "aws_flow_log" "vpc" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"                          # 记录所有类型：ACCEPT + REJECT
  log_destination_type = "cloud-watch-logs"        # 存到 CloudWatch Logs

  log_destination = aws_cloudwatch_log_group.vpc_flow_log.arn

  iam_role_arn = aws_iam_role.vpc_flow_log_role.arn
}

resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  name              = "/aws/vpc/${var.project_name}-${var.environment}-flow-logs"
  retention_in_days = var.environment == "prd" ? 90 : 30  # 生产环境保留90天

  tags = var.common_tags
}

resource "aws_iam_role" "vpc_flow_log_role" {
  name = "${var.project_name}-${var.environment}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "vpc_flow_log_policy" {
  name = "${var.project_name}-${var.environment}-vpc-flow-log-policy"
  role = aws_iam_role.vpc_flow_log_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"   # 允许写入 CloudWatch Logs
      ]
      Resource = "${aws_cloudwatch_log_group.vpc_flow_log.arn}:*"
    }]
  })
}
