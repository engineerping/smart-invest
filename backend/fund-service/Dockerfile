# =============================================================================
# fund-service Dockerfile —— 多阶段构建
# =============================================================================
# 阶段1: Maven 构建（依赖 common + 自身源码）
# 阶段2: 精简 JRE 运行时
# =============================================================================
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build
COPY pom.xml .
COPY common/pom.xml common/pom.xml
COPY fund-service/pom.xml fund-service/pom.xml
# 为其他模块创建空外壳（父 POM 的 <modules> 需要）
RUN mkdir -p user-service api-gateway order-service notification-worker
RUN mvn -q -pl fund-service -am dependency:go-offline -B || true
COPY common common
COPY fund-service fund-service
RUN mvn -q -pl fund-service -am package -DskipTests -B

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /build/fund-service/target/fund-service-*.jar app.jar
RUN addgroup -S app && adduser -S app -G app
USER app
EXPOSE 8082
ENTRYPOINT ["java", "-Xmx512m", "-jar", "app.jar"]
