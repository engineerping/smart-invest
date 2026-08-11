# =============================================================================
# order-service Dockerfile —— 多阶段构建
# =============================================================================
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build
COPY pom.xml .
COPY common/pom.xml common/pom.xml
COPY order-service/pom.xml order-service/pom.xml
RUN mvn -q -pl order-service -am dependency:go-offline -B || true
COPY common common
COPY order-service order-service
RUN mvn -q -pl order-service -am package -DskipTests -B

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /build/order-service/target/order-service-*.jar app.jar
RUN addgroup -S app && adduser -S app -G app
USER app
EXPOSE 8083
ENTRYPOINT ["java", "-Xmx512m", "-jar", "app.jar"]
