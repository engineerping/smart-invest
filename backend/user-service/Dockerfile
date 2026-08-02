# =============================================================================
# user-service Dockerfile —— 多阶段构建
# =============================================================================
# 阶段1 (builder): 用 Maven + JDK 21 编译打包（含父模块 common 依赖）
# 阶段2 (runtime): 只保留精简的 JRE + 生成的 jar，镜像小、更安全
#
# 注意：mvn 需要在 backend/ 目录下构建整个 reactor（因为依赖 common），
#       通过 -pl user-service -am 只构建目标模块及其依赖。
# =============================================================================

# ---- Stage 1: 构建 ----
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build
# 先拷贝 pom 文件，利用 Docker 层缓存（pom 没变就不用重新下载依赖）
COPY pom.xml .
COPY common/pom.xml common/pom.xml
COPY user-service/pom.xml user-service/pom.xml
# 下载依赖（-o 离线构建失败时能利用缓存）
RUN mvn -q -pl user-service -am dependency:go-offline -B || true
# 拷贝全部源码并打包
COPY common common
COPY user-service user-service
RUN mvn -q -pl user-service -am package -DskipTests -B

# ---- Stage 2: 运行时 ----
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
# 从构建阶段拷出可执行 jar
COPY --from=builder /build/user-service/target/user-service-*.jar app.jar
# 非 root 用户运行更安全（面试可讲：最小权限原则）
RUN addgroup -S app && adduser -S app -G app
USER app
EXPOSE 8081
ENTRYPOINT ["java", "-Xmx512m", "-jar", "app.jar"]
