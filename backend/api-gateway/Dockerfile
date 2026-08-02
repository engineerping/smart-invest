# =============================================================================
# api-gateway Dockerfile —— 多阶段构建
# =============================================================================
# gateway 不依赖 common（独立 Spring Cloud Gateway），单模块即可。
# =============================================================================
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build
COPY pom.xml .
COPY api-gateway/pom.xml api-gateway/pom.xml
RUN mvn -q -pl api-gateway dependency:go-offline -B || true
COPY api-gateway api-gateway
RUN mvn -q -pl api-gateway package -DskipTests -B

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /build/api-gateway/target/api-gateway-*.jar app.jar
RUN addgroup -S app && adduser -S app -G app
USER app
EXPOSE 8080
ENTRYPOINT ["java", "-Xmx256m", "-jar", "app.jar"]
