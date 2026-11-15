# Budgetly API (Backend)

Spring Boot REST API for Budgetly — Personal & Family Finance Manager.

## Runtime & Tech Stack Requirements

- **Java**: Java 25 (OpenJDK 25 / Eclipse Temurin 25)
- **Spring Boot**: 4.1.2 (Spring Framework 7.x)
- **Build Tool**: Apache Maven 3.9+ (or included `./mvnw`)
- **Database**: MongoDB 7.0+ (embedded via Flapdoodle during testing; Docker Compose for local/dev)
- **API Documentation**: SpringDoc OpenAPI 3.2.0 (`/swagger-ui.html`, `/api-docs`)

---

## Upgrade Notes (Java 25 & Spring Boot 4.x)

This service was upgraded from Java 21 and Spring Boot 3.4.3 to **Java 25** and **Spring Boot 4.1.2**. Key architectural updates include:

1. **Spring Boot 4 Modular Starters**:
   - `spring-boot-starter-webmvc` replaces `spring-boot-starter-web`.
   - Health indicators now import `org.springframework.boot.health.contributor.Health` and `org.springframework.boot.health.contributor.HealthIndicator` from `spring-boot-health`.
2. **MongoDB Property Renaming**:
   - Property namespace migrated from `spring.data.mongodb.*` to `spring.mongodb.*` (e.g., `spring.mongodb.uri`). Environment variable in containers and Compose is `SPRING_MONGODB_URI`.
3. **Jackson Compatibility**:
   - Spring Boot 4 defaults to Jackson 3 (`tools.jackson`). To preserve compatibility with `google-api-client` (JacksonFactory) and LLM providers using Jackson 2 (`com.fasterxml.jackson`), `spring-boot-jackson2` is included.
4. **OpenAPI Generator**:
   - Configured with `openapi-generator-maven-plugin:7.27.0` using `<useSpringBoot4>true</useSpringBoot4>`.
5. **Testing on JDK 25**:
   - Flapdoodle embedded MongoDB upgraded to `de.flapdoodle.embed.mongo.spring4x:4.33.0`.
   - RestAssured upgraded to `6.0.1` (Groovy 5) to eliminate JDK 25 reflection incompatibilities.
   - Mockito JVM argument `-XX:+EnableDynamicAgentLoading` configured in Surefire.
6. **Container & CI Workflows**:
   - Dockerfile uses `eclipse-temurin:25-jdk-jammy` and `eclipse-temurin:25-jre-jammy`.
   - GitHub Actions CI workflow configures `temurin` Java `25`.

---

## Building & Testing

### Prerequisites
Ensure `JAVA_HOME` points to a JDK 25 installation:
```bash
export JAVA_HOME="/path/to/jdk-25"
export PATH="$JAVA_HOME/bin:$PATH"
java -version
```

### Build and Package
```bash
./mvnw clean package -DskipTests
```
The repackaged executable JAR will be located at `target/budgetly-api-1.0.0-SNAPSHOT.jar`.

### Run Automated Tests
```bash
# Run all unit and E2E tests (uses embedded Flapdoodle MongoDB 7.0.9)
./mvnw test

# Full build and verification
./mvnw verify
```

---

## Running Locally

### With Docker Compose
From the repository root:
```bash
docker compose up --build
```
This starts MongoDB (replica set `rs0` on port 27018) and `budgetly-api` on port 8080.

### Standalone (Local MongoDB)
```bash
java -Dspring.profiles.active=local -jar target/budgetly-api-1.0.0-SNAPSHOT.jar
```
Or via Maven:
```bash
./mvnw spring-boot:run
```

---

## API & Actuator Endpoints

- Swagger UI: `http://localhost:8080/swagger-ui.html`
- OpenAPI JSON: `http://localhost:8080/api-docs`
- Health: `http://localhost:8080/actuator/health`
- Prometheus Metrics: `http://localhost:8080/actuator/prometheus`
