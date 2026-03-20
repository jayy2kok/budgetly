FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw dependency:go-offline -q
COPY src ./src
RUN ./mvnw package -DskipTests -q

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN addgroup -S budgetly && adduser -S budgetly -G budgetly
COPY --from=build /app/target/*.jar app.jar
USER budgetly
EXPOSE 8080
ENTRYPOINT ["java", "-Dspring.profiles.active=docker", "-jar", "app.jar"]
