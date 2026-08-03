# =============================================================================
# 监控告警模块 - Prometheus + Grafana + CloudWatch + xMatters
# =============================================================================
# 根据架构图，本项目使用：
#   - CloudWatch (ELK)：日志收集和指标监控
#   - Prometheus & Grafana：K8s 集群和应用指标的可视化
#   - AWS X-Ray (Zipkin & Sleuth)：分布式链路追踪
#   - xMatters：告警通知
#
# 逐层监控策略：
#   L1 - 基础设施层：CloudWatch（EC2、RDS、ElastiCache 等基础设施指标）
#   L2 - K8s 层：Prometheus + Grafana（Pod 资源使用、集群健康）
#   L3 - 应用层：X-Ray（微服务间调用链路）
#   L4 - 业务层：自定义 Metrics + CloudWatch Dashboard
#   L5 - 告警层：CloudWatch Alarm → xMatters 通知

# ==============================
# 1. CloudWatch 日志组（集中日志管理）
# ==============================

# 应用日志
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/eks/${var.eks_cluster_name}/application"
  retention_in_days = var.environment == "prd" ? 90 : 30
  kms_key_id        = aws_kms_key.cloudwatch.arn
  tags              = var.common_tags
}

# Istio 日志
resource "aws_cloudwatch_log_group" "istio" {
  name              = "/aws/eks/${var.eks_cluster_name}/istio"
  retention_in_days = var.environment == "prd" ? 90 : 30
  tags              = var.common_tags
}

resource "aws_kms_key" "cloudwatch" {
  description = "CloudWatch Logs 加密密钥"
  enable_key_rotation = true
  tags = var.common_tags
}

# ==============================
# 2. CloudWatch 指标告警
# ==============================

# Aurora CPU 使用率告警
resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-aurora-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300  # 5 分钟平均
  statistic           = "Average"
  threshold           = 80   # CPU 超过 80% 告警
  alarm_description   = "Aurora CPU 使用率过高"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBClusterIdentifier = var.aurora_cluster_id
  }

  tags = var.common_tags
}

# Redis 内存使用率告警
resource "aws_cloudwatch_metric_alarm" "elasticache_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 75   # 内存超过 75% 告警
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    CacheClusterId = var.elasticache_cluster_id
  }

  tags = var.common_tags
}

# ==============================
# 3. SNS 告警主题（发送到 xMatters）
# ==============================
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"

  # xMatters 可以通过 HTTPS 订阅这个 SNS Topic
  # 当 CloudWatch Alarm 触发时，SNS 会推送到 xMatters 的 webhook URL

  tags = var.common_tags
}

# ==============================
# 4. Prometheus + Grafana（通过 Helm 部署到 EKS）
# ==============================
# 使用 kube-prometheus-stack Helm Chart，包含：
#   - Prometheus（指标采集 + 存储）
#   - Grafana（可视化面板）
#   - AlertManager（告警管理）
#   - Node Exporter（节点指标）
resource "helm_release" "prometheus_stack" {
  name       = "prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = "56.0.0"

  create_namespace = true

  # Grafana 配置
  set {
    name  = "grafana.adminPassword"
    value = random_password.grafana.result
  }

  set {
    name  = "grafana.service.type"
    value = "ClusterIP"  # 内部访问，外部通过 Istio Gateway 暴露
  }

  # Prometheus 配置
  set {
    name  = "prometheus.retention"
    value = "${var.environment == "prd" ? 30 : 7}d"  # 数据保留天数
  }

  # 存储配置（使用 EBS 卷持久化数据）
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.environment == "prd" ? "100Gi" : "20Gi"
  }

  # Service Monitor：自动发现和监控 Istio
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  # 注意：helm_release 的 depends_on 不能跨模块引用
  # Istio 的依赖关系在根模块 main.tf 中通过 module 级 depends_on 处理
  # 这里通过变量传入 istio 命名空间存在性，确保 Prometheus 在 Istio 之后部署
}

# Grafana 管理员密码
resource "random_password" "grafana" {
  length  = 16
  special = false
}

# ==============================
# 5. X-Ray 集成
# ==============================
# X-Ray 用于分布式追踪（类似 Zipkin + Sleuth）
# Spring Boot 应用通过 X-Ray SDK 自动发送 trace 数据
# Istio 的 Envoy proxy 也能自动上报 trace 数据到 X-Ray
# 注意：X-Ray 在 EKS 上通常通过 DaemonSet 方式运行

# ==============================
# 6. CloudWatch Dashboard（综合监控大盘）
# ==============================
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0; y = 0; width = 12; height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", { stat = "Average" }],
            ["AWS/ElastiCache", "DatabaseMemoryUsagePercentage", { stat = "Average" }],
          ]
          period = 300; stat = "Average"; region = var.aws_region
          title = "数据库与缓存资源使用率"
        }
      },
      {
        type   = "metric"
        x      = 12; y = 0; width = 12; height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", { stat = "Sum" }],
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average" }],
          ]
          period = 300; stat = "Average"; region = var.aws_region
          title = "API 请求量与响应时间"
        }
      },
    ]
  })
}
