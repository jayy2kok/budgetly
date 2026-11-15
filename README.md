# Budgetly

Personal & Family Finance Manager featuring automated SMS parsing, shared budgets, and multi-currency support.

## Architecture

- **Backend (`budgetly_api/`)**: Java 25, Spring Boot 4.1.2 REST API, MongoDB with Change Streams, OpenAPI/Swagger code generation.
- **Frontend (`app/`)**: Flutter cross-platform mobile app (Android & iOS).

## Requirements

- **Java**: 25 (OpenJDK 25 / Eclipse Temurin 25)
- **Maven**: 3.9+ (or `./mvnw` inside `budgetly_api`)
- **Docker & Docker Compose**: For containerized database and backend runtime
- **Flutter**: 3.41+ (Dart 3.x) for the mobile app

## Quick Start

### Backend (Docker Compose)
```bash
docker compose up --build
```
The API starts on `http://localhost:8080`, with MongoDB replica set on port 27018.

### Backend (Local Maven)
```bash
cd budgetly_api
./mvnw clean verify
```

Refer to [budgetly_api/README.md](budgetly_api/README.md) for backend details and upgrade notes.
Refer to [doc/adr/0004-upgrade-to-java-25-and-spring-boot-4.md](doc/adr/0004-upgrade-to-java-25-and-spring-boot-4.md) for the upgrade ADR.
