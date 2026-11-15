# ADR 0004: Upgrade Backend to Java 25 and Spring Boot 4.x

## Status
Accepted

## Context
The Budgetly backend was running on Java 21 and Spring Boot 3.4.3. Issue #4 requires upgrading the backend runtime to Java 25 and updating Spring Boot to the latest available 4.x version, along with updating all build, container, CI workflows, and resolving compatibility issues across dependencies and automated tests.

## Decision

1. **Runtime & Framework Baseline**:
   - Upgrade Java from 21 to **Java 25** (`<java.version>25</java.version>`).
   - Upgrade Spring Boot from 3.4.3 to **Spring Boot 4.1.2** (the latest stable 4.x release).

2. **Spring Boot 4 Modularization & Starters**:
   - Web starter changed from `spring-boot-starter-web` to `spring-boot-starter-webmvc`.
   - Actuator Health package reorganized in Spring Boot 4: `Health` and `HealthIndicator` relocated from `org.springframework.boot.actuate.health.*` to `org.springframework.boot.health.contributor.*` (provided via `spring-boot-health` module).
   - MongoDB configuration properties migrated from `spring.data.mongodb.*` to `spring.mongodb.*` (e.g. `spring.mongodb.uri`), and environment variable in Docker Compose aligned to `SPRING_MONGODB_URI`.

3. **Jackson 2 Compatibility Mode**:
   - Spring Boot 4 defaults to Jackson 3 (`tools.jackson.*`). However, `google-api-client` (2.9.2) and existing LLM providers use Jackson 2 (`com.fasterxml.jackson.*`).
   - Included `org.springframework.boot:spring-boot-jackson2` (4.1.2) to maintain Jackson 2 compatibility across existing serialization and client integrations without breaking changes.

4. **OpenAPI Generator**:
   - Updated `openapi-generator-maven-plugin` to `7.27.0`.
   - Configured `useSpringBoot4=true` (replacing `useSpringBoot3=true`) for code generation of API controllers and model DTOs.

5. **Test Framework & JVM Compatibility**:
   - RestAssured updated to `6.0.1` (providing Groovy 5 compatibility to resolve JDK 25 reflection issues with `Class.isAssignableFrom`).
   - Flapdoodle Embedded MongoDB updated to `de.flapdoodle.embed:de.flapdoodle.embed.mongo.spring4x:4.33.0`.
   - Surefire JVM argument retains `-XX:+EnableDynamicAgentLoading` for Mockito agent attachment under Java 25.

6. **Container & CI**:
   - `budgetly_api/Dockerfile` updated to use `eclipse-temurin:25-jdk-jammy` (build stage) and `eclipse-temurin:25-jre-jammy` (runtime stage).
   - GitHub Actions CI workflow (`.github/workflows/ci.yml`) updated to set up JDK 25 via `actions/setup-java@v4`.

## Consequences
- Full compatibility with Java 25 and Spring Boot 4.x.
- All 100 automated unit, integration, and RestAssured E2E tests pass cleanly on JDK 25.
- Zero deprecation warnings in compiler plugin configuration; build artifacts repackaged cleanly into executable Spring Boot 4 fat jar.
