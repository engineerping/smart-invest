FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY app/target/app-*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]