#!/usr/bin/env bash
# =============================================================================
# 一键部署到 ASUS-Ubuntu K3S
# =============================================================================
# 作用：SSH 到服务器，把本地的 Helm charts 上传并执行 helm install/upgrade。
# 前提：
#   1. 镜像已推送到 Docker Hub（见 build-images.sh --push）
#   2. 服务器已装好 k3s（单条命令即可），helm 已安装
#   3. 服务器上 Postgres 已就绪（见 setup-db.sh）
# 用法:
#   ./scripts/deploy-k3s.sh [tag]   # 默认 latest
# =============================================================================
set -euo pipefail

SERVER="george@192.168.31.192"
SSH_OPTS="-o StrictHostKeyChecking=no"
TAG="${1:-latest}"
REMOTE_DIR="/home/george/smart-invest-k3s"

echo ">>> 1. 检查服务器连接"
sshpass -p 'George0' ssh $SSH_OPTS "$SERVER" "hostname" || {
  echo "错误：无法连接服务器 $SERVER，请检查网络/内网穿透是否可用"
  exit 1
}

echo ">>> 2. 检查服务器工具（k3s / helm / docker）"
sshpass -p 'George0' ssh $SSH_OPTS "$SERVER" '
  command -v k3s >/dev/null || sudo ln -s /usr/local/bin/k3s /usr/bin/k3s 2>/dev/null || true
  if ! command -v helm >/dev/null; then
    echo "安装 helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
  fi
  echo "k3s: $(k3s version 2>/dev/null | head -1)"
  echo "helm: $(helm version --short 2>/dev/null)"
'

echo ">>> 3. 上传 Helm charts 到服务器"
# 打包 umbrella（含子 chart）
cd "$(dirname "$0")/../infrastructure/helm-charts/umbrella"
helm dependency build . >/dev/null 2>&1
cd - >/dev/null

sshpass -p 'George0' ssh $SSH_OPTS "$SERVER" "mkdir -p $REMOTE_DIR"
sshpass -p 'George0' scp $SSH_OPTS -r \
  "$(cd "$(dirname "$0")/../infrastructure/helm-charts" && pwd)"/* \
  "$SERVER:$REMOTE_DIR/"

echo ">>> 4. 服务器上执行 helm install（ns: smart-invest）"
sshpass -p 'George0' ssh $SSH_OPTS "$SERVER" "
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  cd $REMOTE_DIR/umbrella
  sudo helm upgrade --install smart-invest . \
    --namespace smart-invest --create-namespace \
    --set secrets.dbPassword='bG9jYWxkZXYtb25seQ==' \
    --set secrets.rabbitmqPassword='bG9jYWxkZXYtb25seQ==' \
    --set user-service.image.tag=$TAG \
    --set fund-service.image.tag=$TAG \
    --set order-service.image.tag=$TAG \
    --set notification-worker.image.tag=$TAG \
    --set api-gateway.image.tag=$TAG \
    --set frontend.image.tag=$TAG \
    --wait --timeout 300s
"

echo ">>> 5. 健康检查：等待 Pod 就绪"
sshpass -p 'George0' ssh $SSH_OPTS "$SERVER" "
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  echo '=== Pods ==='
  sudo kubectl -n smart-invest get pods -o wide
  echo '=== Services ==='
  sudo kubectl -n smart-invest get svc
  echo '=== Ingress ==='
  sudo kubectl -n smart-invest get ingress
"

echo ""
echo ">>> 部署完成！"
echo "    访问方式：http://<内网穿透公网域名>/  （前端）"
echo "    API 入口：/api/** （经 Traefik → api-gateway → 微服务）"
