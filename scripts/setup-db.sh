#!/usr/bin/env bash
# =============================================================================
# 在 ASUS-Ubuntu 上准备 PostgreSQL（宿主机 Docker）
# =============================================================================
# 数据库不进 K3S，跑在宿主机 Docker，K3S 里应用通过宿主机 IP 访问。
# 幂等：已存在容器则跳过。
# 用法: ./scripts/setup-db.sh
# =============================================================================
set -euo pipefail

SERVER="george@192.168.31.192"
SSH_OPTS="-o StrictHostKeyChecking=no"

echo ">>> 检查/安装 Docker 并启动 Postgres 16"
sshpass -p 'George0' ssh $SSH_OPTS "$SERVER" '
  if ! command -v docker >/dev/null; then
    echo "安装 Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
  fi

  if ! docker ps --format "{{.Names}}" | grep -q "^smart-invest-db$"; then
    echo "启动 Postgres 容器..."
    sudo docker run -d --name smart-invest-db \
      --restart unless-stopped \
      -p 5432:5432 \
      -e POSTGRES_DB=smartinvest \
      -e POSTGRES_USER=smartadmin \
      -e POSTGRES_PASSWORD=localdev_only \
      -v postgres_data:/var/lib/postgresql/data \
      postgres:16-alpine
    echo "等待数据库就绪..."
    sleep 10
  else
    echo "Postgres 容器已存在，跳过启动"
  fi

  echo "=== Postgres 状态 ==="
  sudo docker ps --filter name=smart-invest-db --format "{{.Names}} {{.Status}}"
'
