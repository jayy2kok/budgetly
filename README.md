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
cp .env.example .env          # then set GOOGLE_CLIENT_ID (required for Google sign-in)
docker compose up --build
```
The API starts on `http://localhost:8080`, with MongoDB replica set on port 27018.

### Configuration

| Variable | Required | Description |
| --- | --- | --- |
| `GOOGLE_CLIENT_ID` | **Yes** | Google OAuth **web** client ID (`<digits>-<hash>.apps.googleusercontent.com`) from <https://console.cloud.google.com/apis/credentials>. Used as the audience when verifying Google ID tokens. |
| `JWT_SECRET` | Dev only | HMAC secret for app JWTs. Override outside local development. |
| `OPENAI_API_KEY` | For SMS analysis | Key for the OpenAI-compatible LLM endpoint. |
| `OPENAI_BASE_URL` / `OPENAI_MODEL` | No | Defaults to `http://rpi.local:20129/v1` / `auto/best-free`. |
| `LLM_PROVIDER` | No | `openai` (default) or `gemini`. |

See [.env.example](.env.example) for a copy-paste template.

When `GOOGLE_CLIENT_ID` is missing or still a placeholder, the API logs an
unambiguous error at startup and refuses to start — so Google sign-in never fails
silently with a generic `400` on `POST /api/v1/auth/google`.

### Backend (Local Maven)
```bash
cd budgetly_api
./mvnw clean verify
```

Refer to [budgetly_api/README.md](budgetly_api/README.md) for backend details and upgrade notes.
Refer to [doc/adr/0004-upgrade-to-java-25-and-spring-boot-4.md](doc/adr/0004-upgrade-to-java-25-and-spring-boot-4.md) for the upgrade ADR.
