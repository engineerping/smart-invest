# =============================================================================
# terraform-k3s 变量定义
# =============================================================================
# 类比 Java：这里是方法签名，具体值在 terraform.tfvars 或命令行 -var 传入。
#
# Terraform 变量类型：
#   - string:   字符串（默认类型）
#   - number:   数字
#   - bool:     布尔值
#   - list():   列表（如 ["a", "b"]）
#   - map():    映射（如 {key = "value"}）
#   - object(): 结构化对象
#
# 敏感变量（sensitive = true）：
#   - terraform output 不会显示值
#   - terraform plan/apply 日志中会隐藏值
#   - 但 state 文件中仍然以明文存储！生产环境建议用远程 state + 加密
# =============================================================================

# -------------------------------------------------------------------
# kubeconfig_path: K3S 集群的 kubeconfig 文件路径
#
# K3S vs K8S 的 kubeconfig 差异：
#   - K3S 默认放在 /etc/rancher/k3s/k3s.yaml（非标准路径）
#   - 标准 K8S 默认放在 ~/.kube/config
#   - K3S 的 server 字段默认写 127.0.0.1，远程使用需要改成实际 IP
#
# 使用前需要：
#   1. scp 从服务器复制到本机
#   2. 修改 server 地址（如 https://192.168.31.192:6443）
#   3. 设置权限 chmod 600（kubeconfig 含证书私钥，必须限制权限）
# -------------------------------------------------------------------
variable "kubeconfig_path" {
  description = "K3S 集群 kubeconfig 路径"
  type        = string
  default     = "~/.kube/config"
}

# -------------------------------------------------------------------
# postgres_host: PostgreSQL 数据库地址
#
# 在 K3S 集群中访问外部数据库的几种方式：
#   1. 宿主机 IP（数据库和 K3S 在同一台机器上）：如 192.168.31.192
#   2. K8S ExternalName Service：创建一个 Service 指向外部地址
#   3. K8S EndpointSlice 手动定义：将外部 IP 注册为 Service 的 Endpoint
#
# 这里用第 1 种（最简单，适合开发和演示环境）。
# -------------------------------------------------------------------
variable "postgres_host" {
  description = "宿主机 PostgreSQL 地址（K3S 内访问宿主机的 IP）"
  type        = string
  default     = "192.168.31.192"
}

# -------------------------------------------------------------------
# db_password: 数据库密码（Base64 编码值）
#
# 注意：K8S Secret data 中的值在 API 传输时是 Base64 编码的，
# 但 Terraform 会自动处理编码，这里可以直接写明文，应用读取时也是自动解码的。
# 这里的 default 值是一个演示用的 base64 编码（对应 "localdev-only"），
# 生产环境必须从外部传入真实密码，不能硬编码在代码里。
# -------------------------------------------------------------------
variable "db_password" {
  description = "数据库密码（演示默认）"
  type        = string
  default     = "bG9jYWxkZXYtb25seQ=="  # base64(localdev_only)，生产应传真实值
  sensitive   = true                      # 标记为敏感，plan/apply 日志中不显示
}

# -------------------------------------------------------------------
# jwt_secret: JWT Token 签名密钥
#
# JWT（JSON Web Token）是微服务间认证的常用方案：
#   1. 用户登录时，认证服务生成 JWT（用此密钥签名）
#   2. 后续请求携带 JWT
#   3. 每个微服务用同一个密钥验证 JWT 签名
#
# 密钥要求：
#   - HS256 算法要求密钥 ≥ 256 位（32 字节）
#   - 推荐用随机生成：openssl rand -base64 32
#   - 所有微服务共享（或非对称密钥，用 RS256 算法）
# -------------------------------------------------------------------
variable "jwt_secret" {
  description = "JWT 签名密钥（所有服务共享）"
  type        = string
  default     = "c21hcnRpbnZlc3QtZGVtby1zZWNyZXQta2V5LWNoYW5nZS1tZS1wbGVhc2UtMzJieXRlcw=="
  sensitive   = true
}

# -------------------------------------------------------------------
# image_tag: Docker 镜像版本标签
#
# Docker 镜像标签最佳实践：
#   - latest: 最新版本（开发环境常用，生产不推荐——不确定具体版本）
#   - v1.2.3: 语义版本（Semantic Versioning）
#   - commit-hash: Git commit SHA（精确追溯源码版本）
#   - v1.2.3-abc1234: 语义版本 + commit hash 组合（推荐生产使用）
#
# 生产环境建议：永远不要用 latest，用具体的版本号或 commit hash。
# -------------------------------------------------------------------
variable "image_tag" {
  description = "镜像版本 tag"
  type        = string
  default     = "latest"
}

# -------------------------------------------------------------------
# replicas: 服务副本数量
#
# 副本数选择指南：
#   - 1: 开发和演示环境（省钱）
#   - 2: 最低高可用（单节点故障不影响服务）
#   - 3+: 生产环境（更好的负载分散和容错能力）
#
# K8S 会尽量将多个副本调度到不同节点（通过 PodAntiAffinity），
# 但这需要多个节点。K3S 单节点环境 replicas > 1 的 Pod 会在同一节点。
# -------------------------------------------------------------------
variable "replicas" {
  description = "服务副本数"
  type        = number
  default     = 1
}
