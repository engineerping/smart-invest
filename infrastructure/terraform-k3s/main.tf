# =============================================================================
# Terraform 管理 K3S —— 学习版（面试讲解用）
# =============================================================================
# 核心思想：Terraform 不只能管 AWS/Azure/GCP，任何有 API 的资源都能管。
# K3S 的 API 就是 Kubernetes API，所以用 Terraform 的 kubernetes + helm
# provider 就能把 K3S 上的所有资源（namespace/deployment/service/secret...）
# 声明式地管理起来。
#
# 对比你现有的 infrastructure/（AWS 版）：
#   相同点：都是 Terraform，都有 provider 声明、变量、模块化。
#   不同点：AWS 版用 aws provider 创建"云资源"（VPC/EKS/Aurora...）；
#           本版用 kubernetes/helm provider 创建"K8S 资源"。
#   这是一套心智：Infrastructure as Code，声明期望状态，Terraform 负责收敛。
#
# 实际部署我们走 Helm（更快、更 Kubernetes 原生），
# 这个目录是"学习资料"，帮你理解 Terraform 的能力边界。
# =============================================================================

# =============================================================================
# Terraform 配置块
# =============================================================================
# required_providers 声明本模块需要的 Provider。
# 和 AWS 版不同的是，这里不需要管理云资源，直接操作 K8S API。
#
# Provider 关系图：
#   ┌─────────────┐     ┌──────────────┐
#   │ Terraform    │────▶│ Kubernetes   │──▶ K8S API Server (kube-apiserver)
#   │ (IaC 引擎)   │     │ Provider     │    :6443
#   └─────────────┘     └──────────────┘
#         │
#         └────────────▶┌──────────────┐
#                        │ Helm         │──▶ Helm Release 管理
#                        │ Provider     │    (复用上面 K8S 连接)
#                        └──────────────┘
# =============================================================================
terraform {
  required_version = ">= 1.5"

  required_providers {
    # -------------------------------------------------------------------
    # Kubernetes Provider
    # 直接管理 Kubernetes API 资源（Pod/Deployment/Service/ConfigMap/Secret/...）
    # 相当于 kubectl apply 的声明式版本。
    #
    # 工作原理：
    #   1. 读取 kubeconfig 文件获取集群地址和认证信息
    #   2. 调用 K8S REST API 执行 CRUD 操作
    #   3. Terraform state 记录资源的期望状态
    #   4. plan 时对比期望 vs 实际，apply 时执行变更
    #
    # 常用资源类型：
    #   - kubernetes_namespace      → 命名空间
    #   - kubernetes_deployment     → 无状态应用部署
    #   - kubernetes_service        → 服务暴露（ClusterIP/NodePort/LoadBalancer）
    #   - kubernetes_config_map     → 非敏感配置
    #   - kubernetes_secret         → 敏感配置（Base64 编码）
    #   - kubernetes_ingress_v1     → HTTP 路由
    #   - kubernetes_persistent_volume_claim → 持久化存储
    # -------------------------------------------------------------------
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }

    # -------------------------------------------------------------------
    # Helm Provider
    # 管理 Helm Chart 的安装和升级（相当于 helm install/upgrade 的声明式版本）。
    #
    # Helm 是 K8S 的包管理器，Chart 是一组 K8S 资源的打包模板。
    # 比手动编写 kubernetes_* 资源更高效，因为：
    #   1. Chart 已经是现成的模板（如 Bitnami 的 PostgreSQL chart）
    #   2. 只需写 values.yaml 覆盖参数，不用手写每个资源
    #   3. 内置版本管理和回滚功能
    #
    # 本项目用的 Chart 在 ../../helm-charts/charts/ 下。
    # -------------------------------------------------------------------
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
  }
}

# =============================================================================
# Provider 配置
# =============================================================================
# K3S 的 kubeconfig 在服务器 /etc/rancher/k3s/k3s.yaml，
# 本地使用时通过环境变量 KUBECONFIG 或变量传入。
#
# kubeconfig 文件内容解释：
#   - clusters[].cluster.server: K8S API Server 地址（如 https://192.168.31.192:6443）
#   - users[].user.client-certificate-data: 客户端证书（Base64）
#   - users[].user.client-key-data: 客户端私钥（Base64）
#   - contexts[]: 集群+用户+命名空间的组合
#
# 连接流程：Terraform → 读取 kubeconfig → TLS 双向认证 → kube-apiserver:6443
# =============================================================================

provider "kubernetes" {
  # -------------------------------------------------------------------
  # config_path: kubeconfig 文件路径
  # 默认 ~/.kube/config（标准位置），可以用 KUBECONFIG 环境变量覆盖。
  #
  # 本地开发流程：
  #   1. 从 K3S 服务器复制 k3s.yaml 到本机
  #      scp user@server:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config
  #   2. 修改 server 地址为服务器 IP（k3s.yaml 默认写 127.0.0.1）
  #   3. export KUBECONFIG=~/.kube/k3s-config
  #   4. terraform plan / apply
  # -------------------------------------------------------------------
  config_path = var.kubeconfig_path
}

provider "helm" {
  # Helm Provider 需要在 K8S 集群上操作，所以复用了 kubernetes provider 的连接配置。
  # 这意味着 Helm Provider 会和 Kubernetes Provider 使用同一个 kubeconfig。
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

# =============================================================================
# Namespace —— K8S 逻辑隔离单元
# =============================================================================
# Namespace 是 K8S 中资源分组的机制，类似于：
#   - AWS 的 VPC（网络隔离，但更轻量）
#   - Java 的 package（命名空间隔离）
#   - Linux 的 namespace（进程隔离）
#
# 主要作用：
#   1. 资源隔离：不同 Namespace 的资源互不可见
#   2. 权限控制：RBAC 可以限制用户只访问特定 Namespace
#   3. 资源配额：ResourceQuota 可以限制每个 Namespace 的 CPU/内存使用
#   4. 环境隔离：同一个集群可以创建 dev/staging/prod 三个 Namespace
#
# 本项目的所有资源都在 smart-invest 命名空间下。
# =============================================================================
# =============================================================================
# Terraform 语法速查：resource 的语法含义
# =============================================================================
# resource "<资源类型>" "<本地名称>" { ... }
#   - "资源类型"（如 kubernetes_namespace）：由 Provider 定义，告诉 Terraform
#     「我要创建什么」。命名规范：<provider>_<资源名>
#   - "本地名称"（如 app）：你自己起的名字，只在当前模块内有效，
#     用于在代码中引用这个资源，如 kubernetes_namespace.app.metadata[0].name
#   - 类比 Java：KubernetesNamespace app = new KubernetesNamespace();
#     资源类型 ≈ 类名，本地名称 ≈ 变量名
# =============================================================================
resource "kubernetes_namespace" "app" {
  metadata {
    name = "smart-invest"
  }
}

# =============================================================================
# ConfigMap —— 非敏感配置数据
# =============================================================================
# ConfigMap 用于存储非敏感的配置键值对，解耦配置和镜像。
# 类比 Spring Boot 的 application.properties，但可以热更新（需要应用配合）。
#
# 与 Secret 的区别：
#   - ConfigMap: 明文存储，适合数据库 URL、端口号、功能开关等非敏感配置
#   - Secret:    Base64 编码存储（注意：只是编码不是加密！），适合密码、Token 等
#
# 使用方式（在 Pod 中引用）：
#   1. 环境变量注入：env[].valueFrom.configMapKeyRef（最常用）
#   2. 文件挂载：volumes[].configMap → 容器内生成配置文件
#   3. 命令行参数：通过环境变量间接传入
# =============================================================================
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "smart-invest-config"
    namespace = kubernetes_namespace.app.metadata[0].name   # 引用上面创建的 Namespace
  }

  data = {
    # -------------------------------------------------------------------
    # SPRING_DATASOURCE_URL: Spring Boot 数据库连接 URL
    # 这里连接宿主机 PostgreSQL（K3S 外的数据库实例）。
    # 在 K3S Pod 内访问宿主机：
    #   - 如果 K3S 跑在宿主机上：用宿主机 IP（如 192.168.31.192）
    #   - 如果 K3S 跑在 VM 里：用 VM 的桥接 IP
    #   - 如果数据库也在 K3S 里：用 Service 名（如 postgres-service）
    # -------------------------------------------------------------------
    "SPRING_DATASOURCE_URL"      = "jdbc:postgresql://${var.postgres_host}:5432/smartinvest"

    # -------------------------------------------------------------------
    # SPRING_DATASOURCE_USERNAME: 数据库用户名
    # 注意：密码不放这里，放 Secret 中（见下面 kubernetes_secret）
    # -------------------------------------------------------------------
    "SPRING_DATASOURCE_USERNAME" = "smartadmin"

    # -------------------------------------------------------------------
    # RABBITMQ_HOST: RabbitMQ 消息队列地址
    # "rabbitmq" 是 K8S Service 名称，K8S 内置 DNS 会自动解析为 Pod IP。
    # K8S DNS 格式：<service-name>.<namespace>.svc.cluster.local
    # 同 Namespace 下可以简写为 <service-name>
    # -------------------------------------------------------------------
    "RABBITMQ_HOST"              = "rabbitmq"
  }
}

# =============================================================================
# Secret —— 敏感配置数据
# =============================================================================
# Secret 用于存储密码、Token、证书等敏感信息。
# 注意：K8S Secret 默认只是 Base64 编码，不是加密！
# Base64 编码 ≠ 加密，任何人都可以解码。生产环境应该：
#   1. 启用 etcd 静态加密（encryption at rest）
#   2. 使用 RBAC 限制 Secret 的读取权限
#   3. 使用外部 Secret 管理工具（AWS Secrets Manager、HashiCorp Vault、Sealed Secrets）
#   4. 配合 External Secrets Operator 自动同步外部密钥
#
# data 块中的值必须是 Base64 编码的。Terraform 的 kubernetes_secret 资源
# 会自动处理编码，这里直接写原始值即可，Terraform 会在 API 调用时自动 Base64。
# =============================================================================
resource "kubernetes_secret" "app_secrets" {
  metadata {
    name      = "smart-invest-secrets"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    # -------------------------------------------------------------------
    # SPRING_DATASOURCE_PASSWORD: 数据库密码
    # 真实部署时从变量/外部 Secret 管理读取，这里用演示值。
    # Spring Boot 会自动将 SPRING_DATASOURCE_PASSWORD 环境变量映射为
    # spring.datasource.password 配置项。
    # -------------------------------------------------------------------
    "SPRING_DATASOURCE_PASSWORD" = var.db_password

    # -------------------------------------------------------------------
    # JWT_SECRET: JWT Token 签名密钥
    # 所有微服务共享同一个密钥来验证 JWT Token。
    # 生产环境要求：
    #   - 至少 256 位（32 字节）的随机字符串
    #   - 定期轮换（配合 JWT 过期时间）
    #   - 不同环境使用不同密钥
    # -------------------------------------------------------------------
    "JWT_SECRET"                 = var.jwt_secret
  }
}

# =============================================================================
# Deployment —— 无状态应用部署（以 user-service 为例）
# =============================================================================
# Deployment 是 K8S 最核心的工作负载资源，负责管理 Pod 的声明式更新。
#
# Deployment 的层级结构：
#   Deployment
#     └── ReplicaSet（版本管理，每次更新创建新 RS）
#           └── Pod（最小部署单元，包含 1 个或多个容器）
#                 └── Container（Docker 容器）
#
# Deployment 保证：
#   1. 指定数量的 Pod 副本始终在运行（自愈能力）
#   2. 滚动更新（逐个替换 Pod，不中断服务）
#   3. 回滚（kubectl rollout undo，恢复到上一个版本）
#
# 关键配置解析：
#   - replicas: Pod 副本数（高可用需要 ≥ 2）
#   - selector: 如何找到属于这个 Deployment 的 Pod（通过 labels 匹配）
#   - template: Pod 模板（定义 Pod 的内容：容器、端口、环境变量等）
# =============================================================================
resource "kubernetes_deployment" "user_service" {
  metadata {
    name      = "user-service"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "user-service"   # Deployment 自身的标签
    }
  }

  spec {
    # -------------------------------------------------------------------
    # replicas: Pod 副本数量
    # 生产环境建议 ≥ 2，保证单节点故障时服务不中断。
    # K8S 会自动将 Pod 分散到不同节点（通过 anti-affinity 规则）。
    # -------------------------------------------------------------------
    replicas = var.replicas

    # -------------------------------------------------------------------
    # selector: 标签选择器
    # 告诉 Deployment "哪些 Pod 归我管"。
    # match_labels 必须和 template.metadata.labels 完全匹配。
    # 如果不匹配，apply 时会报错：selector does not match template labels
    # -------------------------------------------------------------------
    selector {
      match_labels = {
        app = "user-service"
      }
    }

    # -------------------------------------------------------------------
    # template: Pod 模板
    # 定义每个 Pod 的内容。这是 Deployment 创建 Pod 的"蓝图"。
    # -------------------------------------------------------------------
    template {
      metadata {
        labels = {
          app = "user-service"   # 必须匹配 selector.match_labels
        }
      }

      spec {
        # -------------------------------------------------------------------
        # container: 容器定义
        # 一个 Pod 可以有多个容器（Sidecar 模式），但通常 1 Pod = 1 容器。
        # -------------------------------------------------------------------
        container {
          name  = "user-service"
          # image: Docker 镜像地址
          # 格式：<registry>/<repository>:<tag>
          # - gongchengship: Docker Hub 用户名
          # - smart-invest-user-service: 镜像仓库名
          # - image_tag: 版本标签（如 latest、v1.2.3、commit-hash）
          image = "gongchengship/smart-invest-user-service:${var.image_tag}"

          # -------------------------------------------------------------------
          # port: 容器暴露的端口
          # 注意：这只是声明性质的文档，不实际发布端口。
          # 真正让 Pod 可访问的是 Service 资源。
          # 8081 = user-service 的 Spring Boot 端口
          # -------------------------------------------------------------------
          port {
            container_port = 8081
          }

          # -------------------------------------------------------------------
          # env: 环境变量注入（从 ConfigMap 读取）
          # 这种方式叫 configMapKeyRef，只注入 ConfigMap 中的某个 key。
          # 也可以用 envFrom 注入整个 ConfigMap 的所有 key。
          #
          # Spring Boot 环境变量映射规则（Relaxed Binding）：
          #   环境变量 SPRING_DATASOURCE_URL
          #   → 转为小写 spring.datasource.url
          #   → 映射到 @Value("${spring.datasource.url}") 或自动配置
          # -------------------------------------------------------------------
          env {
            name  = "SPRING_DATASOURCE_URL"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "SPRING_DATASOURCE_URL"
              }
            }
          }
          # ... 其他 env 同理（可查 Kubernetes provider 文档）
          # 完整版还应包括：
          #   - SPRING_DATASOURCE_USERNAME（从 ConfigMap）
          #   - SPRING_DATASOURCE_PASSWORD（从 Secret）
          #   - JWT_SECRET（从 Secret）
          #   - RABBITMQ_HOST（从 ConfigMap）
        }
      }
    }
  }
}
