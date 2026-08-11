#!/usr/bin/env bash
# =============================================================================
# 部署监控栈到 K3S —— Prometheus + Grafana
# =============================================================================
# 对应架构图里的 CloudWatch + Prometheus/Grafana 监控板块。
# 用 kube-prometheus-stack（Prometheus Operator）一栈搞定采集+告警+Grafana。
# 微服务已暴露 /actuator/prometheus，Prometheus 通过 ServiceMonitor 采集。
# =============================================================================
set -euo pipefail

SERVER="george@192.168.31.192"
SSH_OPTS="-o StrictHostKeyChecking=no"

echo ">>> 部署 Prometheus + Grafana（kube-prometheus-stack）"
sshpass -p 'George0' ssh $SSH_OPTS "$SERVER" '
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  sudo helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
  sudo helm repo update >/dev/null

  # 精简安装（8GB 内存要省着用）：关掉部分非必要组件
  sudo helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace \
    --set grafana.enabled=true \
    --set grafana.service.type=ClusterIP \
    --set grafana.adminPassword=admin123 \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
    --set alertmanager.enabled=false \
    --set prometheus.prometheusSpec.resources.requests.memory=384Mi \
    --set prometheus.prometheusSpec.resources.limits.memory=768Mi \
    --set grafana.resources.requests.memory=128Mi \
    --set grafana.resources.limits.memory=256Mi \
    --wait --timeout 600s

  echo "=== 监控栈状态 ==="
  sudo kubectl -n monitoring get pods

  echo ""
  echo "Grafana 访问：kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80"
  echo "Grafana 账号: admin / admin123"
'
