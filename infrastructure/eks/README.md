# =============================================================================
# Smart Invest - Flex-Invest 公募基金投资系统
# 基础设施即代码 (IaC) - 项目说明
# =============================================================================
#
# 技术栈: Terraform 1.x + AWS Provider
# 部署目标: Amazon EKS (Elastic Kubernetes Service)
#
# 项目背景:
#   这是一个小额投资系统，银行将诸多用户的小额资金汇集到一起，由专业基金经理
#   管理，购买全球优质基金。按架构图部署在 AWS EKS 上。
#
# 架构组件:
#   前端流量: Route53 -> CloudFront -> WAF -> Shield
#   VPC 网络: VPC / Public Subnet / Private Subnet / NAT Gateway
#   API 网关: Kong Gateway (4个实例) + NLB
#   微服务: User, Portfolio, Order, Fund, Notification
#   服务网格: Istio (熔断/重试/限流下沉到 infra 层)
#   数据库: Aurora PostgreSQL (Multi-AZ), ElastiCache Redis, DocumentDB
#   消息队列: Amazon MQ
#   存储: S3 (静态资源 + CI/CD 制品)
#   安全: AWS Secrets Manager, KMS, OAuth2 Center
#   监控: CloudWatch, Prometheus+Grafana, X-Ray, xMatters
#   配置: AWS AppConfig (动态配置刷新)
#   环境: DEV / UAT / PRD 三套环境
#   容灾: 两地三中心 (Two Regions, Three Centers)
#
# 目录结构:
#   ├── main.tf                 # 根模块，编排所有子模块
#   ├── providers.tf            # AWS Provider 配置
#   ├── variables.tf            # 输入变量定义
#   ├── locals.tf               # 本地变量和命名规则
#   ├── outputs.tf              # 输出变量
#   ├── terraform.tfvars.example # 变量值示例
#   ├── environments/           # 按环境区分的配置
#   │   ├── dev.tfvars
#   │   ├── uat.tfvars
#   │   └── prd.tfvars
#   └── modules/                # 子模块目录
#       ├── vpc/                # 网络基础设施
#       ├── security-groups/    # 安全组
#       ├── eks/                # Kubernetes 集群
#       ├── istio/              # 服务网格
#       ├── aurora/             # 关系型数据库
#       ├── elasticache/        # Redis 缓存
#       ├── documentdb/         # MongoDB 文档数据库
#       ├── mq/                 # 消息队列
#       ├── s3/                 # 对象存储
#       ├── cloudfront/         # CDN 加速
#       ├── waf/                # Web 应用防火墙
#       ├── secrets-manager/    # 密钥管理
#       ├── kms/                # 加密密钥
#       ├── monitoring/         # 监控告警
#       ├── iam/                # 权限管理
#       ├── appconfig/          # 应用配置
#       ├── route53/            # DNS 管理
#       └── acm/                # SSL 证书
#
# =============================================================================
