# =============================================================================
# RabbitMQ 部署到 K3S —— 使用官方 Helm chart
# =============================================================================
# 架构图里的 Amazon MQ 在本 K3S 版用自托管 RabbitMQ 替代。
# 使用 Bitnami/官方 chart，开启 prometheus 插件供 Grafana 采集队列指标。
# =============================================================================
#!/usr/bin/env bash
set -euo pipefail

SERVER="george@192.168.31.192"
SSH_OPTS="-o StrictHostKeyChecking=no"

echo ">>> 部署 RabbitMQ 到 K3S"
sshpass -p 'George0' ssh $SSH_OPTS "$SERVER" '
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  # 添加官方 repo（如未添加）
  sudo helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
  sudo helm repo update >/dev/null

  # 部署 RabbitMQ（带 management 插件 + prometheus 指标）
  sudo helm upgrade --install rabbitmq bitnami/rabbitmq \
    --namespace smart-invest \
    --set auth.username=smartmq \
    --set auth.password=localdev_only \
    --set service.port=5672 \
    --set service.managerPort=15672 \
    --set metrics.enabled=true \
    --set metrics.prometheus.pluginsEnabled=true \
    --set resources.requests.memory=256Mi \
    --set resources.limits.memory=512Mi \
    --wait --timeout 300s

  echo "=== RabbitMQ 状态 ==="
  sudo kubectl -n smart-invest get pods | grep rabbitmq
'
