# ==============================================================================
# Smart Invest — 基础设施（Infrastructure as Code + Helm Charts）
# ==============================================================================
#
# 这个目录包含本项目的所有基础设施即代码（IaC）资源配置：
#
# 📁 terraform/     → Terraform 代码（AWS 云资源：EC2、VPC、S3、CloudFront、WAF）
# 📁 helm/          → Helm Charts（K3S 上部署微服务全家桶）
# 📁 scripts/       → 运维脚本（部署、构建、监控等）
#
# ==============================================================================
# 目录结构
# ==============================================================================
#
# infrastructure/
# ├── terraform/                                    # Terraform IaC
# │   ├── live/                                     # 「环境实例」目录
# │   │   └── prod/                                 # 生产环境
# │   │       ├── main.tf                           # Terraform + Provider 配置
# │   │       ├── root.tf                           # 根模块（调用子模块）★ 入口
# │   │       ├── variables.tf                      # 变量声明
# │   │       ├── outputs.tf                        # 输出值（部署后打印的信息）
# │   │       ├── terraform.tfvars.example          # 示例变量文件（Git 跟踪）
# │   │       ├── terraform.tfvars                  # 真实变量文件（Git 忽略）
# │   │       ├── backend.tf                        # 远程状态后端（S3+DynamoDB）
# │   │       └── import.sh                         # 导入已有 AWS 资源的脚本
# │   └── modules/                                  # 可复用 Terraform 模块
# │       ├── networking/                           # VPC + 安全组
# │       │   ├── main.tf
# │       │   ├── variables.tf
# │       │   └── outputs.tf
# │       ├── compute/                              # EC2 实例
# │       │   ├── main.tf
# │       │   ├── variables.tf
# │       │   └── outputs.tf
# │       ├── iam/                                  # IAM 角色与权限
# │       │   ├── main.tf
# │       │   ├── variables.tf
# │       │   └── outputs.tf
# │       └── cdn/                                  # CloudFront + S3 + WAF
# │           ├── main.tf
# │           ├── variables.tf
# │           └── outputs.tf
# ├── helm/                                         # Helm Charts
# │   ├── charts/                                   # 各微服务子 Chart
# │   │   ├── api-gateway/
# │   │   ├── frontend/
# │   │   ├── fund-service/
# │   │   ├── notification-worker/
# │   │   ├── order-service/
# │   │   ├── user-service/
# │   │   └── rabbitmq/
# │   │       ├── Chart.yaml                        # Chart 身份文件
# │   │       ├── values.yaml                       # 默认配置
# │   │       └── templates/
# │   │           ├── _helpers.tpl                  # 模板函数（命名、标签）
# │   │           ├── deployment.yaml               # Deployment 定义
# │   │           ├── service.yaml                  # Service 定义
# │   │           └── pvc.yaml                      # 持久化存储（中间件用）
# │   └── umbrella/                                 # 聚合 Chart（一键部署全家桶）
# │       ├── Chart.yaml                            # 聚合 Chart 身份 + 依赖声明
# │       ├── Chart.lock                            # 依赖版本锁定文件
# │       ├── values.yaml                           # 默认配置（所有子 Chart）
# │       ├── values-prod.yaml                      # 生产环境覆盖配置
# │       └── templates/
# │           ├── ingress.yaml                      # Ingress 路由（Traefik）
# │           ├── secret.yaml                       # K8S Secret（敏感信息）
# │           └── rabbitmq-ready-hook.yaml          # Helm Hook（前置检查）
# ├── scripts/                                      # 运维脚本
# └── README.md                                     # 本文件
#
# ==============================================================================
# 快速开始
# ==============================================================================
#
# 完整部署流程（按顺序执行）：
#
# ═════════════════════════════════════════════════════════════════════════
# 第一步：准备 AWS EC2
# ═════════════════════════════════════════════════════════════════════════
# 1. 登录 AWS Console → EC2 → 调整实例类型到 t3.medium（4GB 内存）
# 2. 调整 EBS 磁盘到 20GB
# 3. 重启 EC2
# 4. SSH 到 EC2
#
# ═════════════════════════════════════════════════════════════════════════
# 第二步：安装 K3S（在 EC2 上）
# ═════════════════════════════════════════════════════════════════════════
# curl -sfL https://get.k3s.io | sh -
# sudo kubectl get nodes  # 确认 K3S 运行
# sudo cat /etc/rancher/k3s/k3s.yaml  # 查看 kubeconfig
#
# ═════════════════════════════════════════════════════════════════════════
# 第三步：用 Terraform 管理 AWS 资源
# ═════════════════════════════════════════════════════════════════════════
# cd infrastructure/terraform/live/prod
# cp terraform.tfvars.example terraform.tfvars
# # 编辑 terraform.tfvars，填入你的值
# terraform init
# terraform plan    # 预览变更
# terraform import <资源> <ID>  # 如果已有资源，先 import
# terraform apply   # 执行变更
#
# ═════════════════════════════════════════════════════════════════════════
# 第四步：用 Helm 部署微服务到 K3S
# ═════════════════════════════════════════════════════════════════════════
# # 构建所有服务的 Docker 镜像（在本地开发机）
# cd ../../..
# ./scripts/build-images.sh
#
# # 推送镜像到 Docker Hub
# docker push gongchengship/smart-invest-user-service:1.0.0
# # ... 其他服务同理
#
# # 在 EC2 上拉取镜像（或从快网机 crane pull → scp → ctr import）
# # 参考：k3s-image-import-workflow 文档
#
# # 部署
# cd infrastructure/helm/umbrella
# helm dependency update   # 下载子 Chart 依赖
# helm upgrade --install smart-invest . \
#   --namespace smart-invest --create-namespace \
#   --atomic --timeout 600s
#
# # 验证
# kubectl get all -n smart-invest
# helm list -n smart-invest
#
# ═════════════════════════════════════════════════════════════════════════
# 第五步：部署前端（S3 + CloudFront）
# ═════════════════════════════════════════════════════════════════════════
# # 构建前端
# cd ../../frontend
# npm run build
#
# # 上传到 S3
# aws s3 sync dist/ s3://<bucket-name>/ --delete
#
# # 刷新 CloudFront 缓存
# aws cloudfront create-invalidation --distribution-id <DISTRIBUTION_ID> --paths "/*"
#
# ═════════════════════════════════════════════════════════════════════════
# 第六步：验证
# ═════════════════════════════════════════════════════════════════════════
# terraform output        # 查看 AWS 资源信息
# terraform output website_url  # 获取网站 URL
# curl https://d123456.cloudfront.net/api/actuator/health  # 检查后端健康
#
# ==============================================================================
# DevOps 核心学习路径
# ==============================================================================
# 建议按以下顺序学习（每个主题都配套了详细注释的代码）：
#
# 1. Terraform 基础     → infrastructure/terraform/live/prod/main.tf
#                         （Provider、变量、输出、backend）
# 2. Terraform 模块化   → infrastructure/terraform/modules/
#                         （如何拆分可复用模块、模块间依赖）
# 3. Helm Chart 结构    → infrastructure/helm/charts/user-service/
#                         （Chart.yaml、values.yaml、templates/）
# 4. Helm Umbrella 模式 → infrastructure/helm/umbrella/
#                         （依赖管理、多环境覆盖、Hook、Ingress）
# 5. K3S 运维           → doc-K8S/ + scripts/
#                         （镜像管理、部署、监控）
#
# 额外学习资源：
#   - doc-manually/DevOps/Terraform_Complete_Guide.md
#   - doc-manually/DevOps/Helm_Complete_Guide.md
#   - doc-manually/DevOps/Kubernetes_Core_Principles_Guide.md
#   - doc-manually/DevOps/Most-Common-Kubernetes-Helm-AWS-Issues-Troubleshooting.md
# ==============================================================================
