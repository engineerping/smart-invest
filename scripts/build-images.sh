#!/usr/bin/env bash
# =============================================================================
# 构建并推送所有微服务镜像到 Docker Hub
# =============================================================================
# 用法:
#   ./scripts/build-images.sh              # 构建所有镜像并打 latest tag
#   ./scripts/build-images.sh v1.0.0       # 构建并打上版本 tag
#   ./scripts/build-images.sh --push v1.0.0 # 构建 + 推送（含 latest）
#
# 说明: 先本地 mvn 打包（复用已下载的依赖，快），再用精简 Dockerfile
#       直接拷贝 jar 构建镜像（比在容器里重新 mvn 快得多）。
#       生产 CI 里用的是各服务目录下的多阶段 Dockerfile。
# =============================================================================
set -euo pipefail

REGISTRY="gongchengship"          # Docker Hub 账号
TAG="${1:-latest}"                # 默认打 latest
PUSH="${PUSH:-no}"                # PUSH=yes 或传入 --push 触发推送

# 本机 Docker 配了阿里云加速器但部分镜像 403，关闭 buildkit 直接复用本地基础镜像
export DOCKER_BUILDKIT=0

# 判断是否推送
if [[ "${1:-}" == "--push" ]]; then
  TAG="${2:-latest}"
  PUSH="yes"
fi

# 后端 jar 都提前构建好
echo ">>> 构建后端 jar (本地 mvn)..."
(cd backend && mvn -q -pl common,user-service,fund-service,order-service,notification-worker,api-gateway -am package -DskipTests)

# 前端构建
echo ">>> 构建前端静态文件..."
(cd frontend && npm run build)

# 精简 Dockerfile：直接拷 jar/静态文件（避免容器里重新下依赖）
cat > /tmp/Dockerfile.java <<'EOF'
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
ARG JAR
ARG PORT
COPY ${JAR} app.jar
RUN addgroup -S app && adduser -S app -G app
USER app
EXPOSE ${PORT}
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF

build_java() {
  local name="$1" jar="$2" port="$3"
  echo ">>> 构建镜像 ${REGISTRY}/smart-invest-${name}:${TAG}"
  docker build -t "${REGISTRY}/smart-invest-${name}:${TAG}" \
    -f /tmp/Dockerfile.java \
    --build-arg JAR="target/${jar}" \
    --build-arg PORT="${port}" \
    "backend/${name}"/
  # 同时打 latest 便于反复部署
  docker tag "${REGISTRY}/smart-invest-${name}:${TAG}" "${REGISTRY}/smart-invest-${name}:latest"
  if [[ "$PUSH" == "yes" ]]; then
    docker push "${REGISTRY}/smart-invest-${name}:${TAG}"
    docker push "${REGISTRY}/smart-invest-${name}:latest"
  fi
}

build_java user-service         "user-service-1.0.0-SNAPSHOT.jar"      8081
build_java fund-service         "fund-service-1.0.0-SNAPSHOT.jar"      8082
build_java order-service        "order-service-1.0.0-SNAPSHOT.jar"     8083
build_java notification-worker  "notification-worker-1.0.0-SNAPSHOT.jar" 8084
build_java api-gateway          "api-gateway-1.0.0-SNAPSHOT.jar"       8080

echo ">>> 构建前端镜像..."
docker build -t "${REGISTRY}/smart-invest-frontend:${TAG}" frontend/
docker tag "${REGISTRY}/smart-invest-frontend:${TAG}" "${REGISTRY}/smart-invest-frontend:latest"
if [[ "$PUSH" == "yes" ]]; then
  docker push "${REGISTRY}/smart-invest-frontend:${TAG}"
  docker push "${REGISTRY}/smart-invest-frontend:latest"
fi

echo ""
echo ">>> 完成。镜像列表:"
docker images | grep "${REGISTRY}/smart-invest" || true
if [[ "$PUSH" == "yes" ]]; then
  echo ">>> 已推送到 Docker Hub: ${REGISTRY}"
fi
