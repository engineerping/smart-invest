# =============================================================================
# Terraform 管理 K3S —— 学习版（面试讲解用）
# =============================================================================
# 核心思想：Terraform 不只能管 AWS/Azure/GCP，任何有 API 的资源都能管。
# K3S 的 API 就是 Kubernetes API，所以用 Terraform 的 kubernetes + helm
# provider 就能把 K3S 上的所有资源（namespace/deployment/service/secret...）
# 声明式地管理起来。
#
# 对比你现有的 infrastructure/eks（AWS EKS 版）：
#   相同点：都是 Terraform，都有 provider 声明、变量、模块化。
#   不同点：AWS 版用 aws provider 创建"云资源"（VPC/EKS/Aurora...）；
#           本版用 kubernetes/helm provider 创建"K8S 资源"。
#   这是一套心智：Infrastructure as Code，声明期望状态，Terraform 负责收敛。
#
# 实际部署我们走 Helm（更快、更 Kubernetes 原生），
# 这个目录是"学习资料"，帮你理解 Terraform 的能力边界。
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    # 直接管理 Kubernetes API（相当于 kubectl apply 的声明式版本）
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    # 管理 Helm release（相当于 helm install/upgrade 的声明式版本）
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
# 连接 K3S 集群 = 拿着 kubeconfig 访问 6443 端口的 kube-apiserver。
# =============================================================================
provider "kubernetes" {
  # 这里配置 kubeconfig 路径。默认用 ~/.kube/config，
  # 可用 KUBECONFIG 环境变量覆盖为服务器的 k3s.yaml。
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

# =============================================================================
# Namespace —— 逻辑隔离
# =============================================================================
resource "kubernetes_namespace" "app" {
  metadata {
    name = "smart-invest"
  }
}

# =============================================================================
# ConfigMap —— 非敏感配置
# =============================================================================
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "smart-invest-config"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    # 数据库连接（宿主机 Postgres；在 K3S 里用宿主机 IP）
    "SPRING_DATASOURCE_URL"      = "jdbc:postgresql://${var.postgres_host}:5432/smartinvest"
    "SPRING_DATASOURCE_USERNAME" = "smartadmin"
    "RABBITMQ_HOST"              = "rabbitmq"
  }
}

# =============================================================================
# Secret —— 敏感配置
# =============================================================================
resource "kubernetes_secret" "app_secrets" {
  metadata {
    name      = "smart-invest-secrets"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    # 真实部署时从变量/外部 Secret 管理读取，这里用演示值
    "SPRING_DATASOURCE_PASSWORD" = var.db_password
    "JWT_SECRET"                 = var.jwt_secret
  }
}

# =============================================================================
# Deployment —— 以 user-service 为例
# =============================================================================
resource "kubernetes_deployment" "user_service" {
  metadata {
    name      = "user-service"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "user-service"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "user-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "user-service"
        }
      }

      spec {
        container {
          name  = "user-service"
          image = "gongchengship/smart-invest-user-service:${var.image_tag}"

          port {
            container_port = 8081
          }

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
        }
      }
    }
  }
}
