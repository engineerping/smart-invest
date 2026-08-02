#!/usr/bin/env bash
# =============================================================================
# 构建 amd64 镜像（用于 x86_64 服务器）—— 快速版
# =============================================================================
# 背景：本地是 Apple Silicon (arm64)，ASUS-Ubuntu 是 x86_64。
#       Java jar 是平台无关的，所以只需用 amd64 基础镜像 + 拷贝本地 jar。
# 用 buildx + --platform linux/amd64 构建，直接推送 Docker Hub。
# =============================================================================
set -euo pipefail

REGISTRY="gongchengship"
TAG="${1:-amd64}"   # 默认 tag amd64

# 后端 runtime 镜像（拷贝本地 jar）
cat > /tmp/Dockerfile.amd64.java <<'EOF'
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
ARG JAR
COPY ${JAR} app.jar
RUN addgroup -S app && adduser -S app -G app
USER app
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF

build_java() {
  local name="$1" jar="$2"
  echo ">>> 构建 ${REGISTRY}/smart-invest-${name}:${TAG} (amd64)"
  docker buildx build --platform linux/amd64 \
    -t "${REGISTRY}/smart-invest-${name}:${TAG}" \
    -t "${REGISTRY}/smart-invest-${name}:latest" \
    -f /tmp/Dockerfile.amd64.java \
    --build-arg JAR="target/${jar}" \
    --push "backend/${name}/"
  echo "    ✓ pushed"
}

build_java user-service        "user-service-1.0.0-SNAPSHOT.jar"
build_java fund-service        "fund-service-1.0.0-SNAPSHOT.jar"
build_java order-service       "order-service-1.0.0-SNAPSHOT.jar"
build_java notification-worker "notification-worker-1.0.0-SNAPSHOT.jar"
build_java api-gateway         "api-gateway-1.0.0-SNAPSHOT.jar"

# 前端 amd64（静态文件平台无关，但基础镜像要 amd64）
echo ">>> 构建 ${REGISTRY}/smart-invest-frontend:${TAG} (amd64)"
docker buildx build --platform linux/amd64 \
  -t "${REGISTRY}/smart-invest-frontend:${TAG}" \
  -t "${REGISTRY}/smart-invest-frontend:latest" \
  -f frontend/Dockerfile \
  --push frontend/
echo "    ✓ pushed"

echo ">>> 全部完成"
