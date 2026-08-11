# =============================================================================
# notification-worker Dockerfile —— 多阶段构建
# =============================================================================
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build
COPY pom.xml .
COPY common/pom.xml common/pom.xml
COPY notification-worker/pom.xml notification-worker/pom.xml
# 为其他模块创建空外壳（父 POM 的 <modules> 需要）
RUN mkdir -p user-service api-gateway fund-service order-service
RUN mvn -q -pl notification-worker -am dependency:go-offline -B || true
COPY common common
COPY notification-worker notification-worker
RUN mvn -q -pl notification-worker -am package -DskipTests -B

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /build/notification-worker/target/notification-worker-*.jar app.jar
RUN addgroup -S app && adduser -S app -G app
USER app
EXPOSE 8084
ENTRYPOINT ["java", "-Xmx256m", "-jar", "app.jar"]
