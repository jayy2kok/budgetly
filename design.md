# Budgetly — System Design

> End-to-end design and component boundaries for the Budgetly family finance app.
> Companion documents: [requirements.md](requirements.md), [ERD.md](ERD.md), [TODO.md](TODO.md), and ADRs in [`doc/adr/`](doc/adr/).

## 1. Architecture Overview

```mermaid
flowchart TB
    subgraph Mobile["Flutter Mobile App (app/)"]
        UI[UI Screens<br/>go_router + Riverpod]
        PARSER[SmsInboxReader + SmsParserService<br/>literal-anchor match]
        CACHE[PatternCacheService]
        REMOTE[Dio remote services<br/>JWT interceptor]
        MOCK[Mock services<br/>dev/offline]
    end

    subgraph API["Spring Boot API (budgetly_api/)"]
        CTRL[REST Controllers<br/>implement OpenAPI-generated interfaces]
        SVC[Services<br/>Auth / Family / Category / Transaction / Message / Dashboard / Pattern]
        LISTENER[MessageChangeStreamListener<br/>async consumer]
        ANCHOR[AnchorParserService]
        LLM["LlmProvider<br/>OpenAiCompatible / Gemini"]
        SEC[JwtAuthFilter + GoogleTokenVerifier]
    end

    subgraph Data["Data Layer"]
        MONGO[(MongoDB 7<br/>replica set rs0)]
        STREAM[(Change Streams<br/>messages collection)]
    end

    subgraph Ext["External Services"]
        GOOGLE[Google OAuth 2.0]
        RATES[open.er-api.com<br/>FX rates]
        LLMAPI[OpenAI-compatible / Gemini API]
    end

    UI --> REMOTE
    UI -.-> MOCK
    PARSER --> CACHE
    CACHE --> REMOTE
    REMOTE -- "REST JSON /api/v1" --> CTRL
    CTRL --> SVC
    SVC --> MONGO
    LISTENER -- "watch insert (PENDING+BULK)" --> STREAM
    LISTENER --> ANCHOR
    LISTENER --> LLM
    LISTENER --> SVC
    SEC --> GOOGLE
    SVC --> RATES
    LLM --> LLMAPI
```

### Components

| Component | Technology | Responsibility |
|---|---|---|
| Flutter app (`app/`) | Dart 3.11, Riverpod 3, go_router, Dio, google_sign_in | UI + on-device SMS parsing + API client |
| REST API (`budgetly_api/`) | Java 25, Spring Boot 4.1.2, SpringDoc, JJWT | Auth, CRUD, budget aggregation, message/pattern APIs |
| MongoDB | MongoDB 7 (replica set) | Document store + change-stream ingestion pipeline |
| LLM layer | `LlmProvider` → `OpenAiCompatibleLlmProvider` / `GeminiLlmProvider` | Server-side SMS classification + template generation |
| Pattern engine | `AnchorParserService` (Java) / `SmsParserService` (Dart) | Literal-anchor template matching (parity algorithm) |

## 2. Backend Package Layout

```
budgetly_api/src/main/java/com/budgetly/api/
├── controller/       # REST controllers implementing generated interfaces
├── service/          # Business logic + AnchorParserService, TransactionDateParser,
│                     #   CurrencyConversionService, CategoryResolver
├── repository/       # Spring Data MongoDB repositories
├── document/         # @Document entities (see ERD.md)
├── llm/              # LlmProvider interface, OpenAI-compatible + Gemini impls, prompt
├── listener/         # MessageChangeStreamListener (change-stream consumer)
├── security/         # JwtTokenProvider, JwtAuthFilter, GoogleTokenVerifier,
│                     #   GoogleAuthConfigValidator
├── config/           # SecurityConfig, MongoConfig, CorsConfig, AsyncConfig
├── health/           # MessageProcessorHealthIndicator
└── exception/        # GlobalExceptionHandler + typed exceptions
```

Generated OpenAPI interfaces/models land in `com.budgetly.api.generated.controller` / `...generated.model` during `mvn compile`.

## 3. Key Flows

### 3.1 Authentication (Google → JWT)

```mermaid
sequenceDiagram
    participant App as Flutter app
    participant API as AuthController
    participant VER as GoogleTokenVerifier
    participant SVC as AuthService
    participant JWT as JwtTokenProvider

    App->>API: POST /api/v1/auth/google (idToken)
    API->>VER: verify(idToken)
    VER-->>API: Google payload (sub, email, name, picture)
    API->>SVC: googleSignIn(payload)
    SVC->>SVC: find-or-create UserDocument
    SVC->>JWT: generateAccessToken / refreshToken
    JWT-->>App: AuthResponse {accessToken, refreshToken, user}
    App->>API: subsequent calls with Authorization: Bearer <jwt>
    API->>JWT: validate via JwtAuthFilter
```

### 3.2 SMS Ingestion & Processing (bulk + change stream)

```mermaid
sequenceDiagram
    participant Device as Flutter SmsInboxReader
    participant Parser as SmsParserService
    participant API as MessageController
    participant DB as MongoDB (messages)
    participant CS as MessageChangeStreamListener
    participant Anchor as AnchorParserService
    participant LLM as LlmProvider

    Device->>Parser: parseMessage(sender, text)
    alt complete literal-anchor match
        Parser-->>Device: auto-post transaction (REGEX_LOCAL)
    else incomplete / unknown sender
        Device->>API: POST /api/v1/messages/bulk (≤500, source=BULK)
        API->>DB: insert PENDING docs (202 Accepted)
        CS->>DB: watch insert (status=PENDING & source=BULK)
        CS->>DB: atomic claim → IN_PROGRESS
        CS->>Anchor: try anchor fast-path
        alt anchor match (amount+merchant+timestamp)
            CS->>DB: create transaction (REGEX_LOCAL), status=PROCESSED
        else no match
            CS->>LLM: analyze (categories from CategoryResolver)
            LLM-->>CS: {isFinancial, parsedData, template, extractionMap}
            CS->>DB: transaction + new SmsPattern, status=PROCESSED
        end
        Device->>API: GET /patterns (post-batch refresh)
    end
```

- The legacy synchronous path (`POST /messages/process`) stamps `source=DIRECT` and is never claimed by the listener (duplicate-processing race resolved — ADR-0003).

## 4. Literal-Anchor Parsing (no regex)

The pattern engine stores sender templates as literal text with `{token}` placeholders and matches by **left/right literal anchors** using `indexOf` on both Java and Dart — guaranteeing identical behavior across platforms. See [`plans/token_template_sms_parsing.md`](plans/token_template_sms_parsing.md) and the parity tests `AnchorParserTest` (Java) / `sms_parser_service_test.dart` (Dart).

## 5. API Contract (Contract-First)

- Canonical spec: `budgetly_api/src/main/resources/api/budgetly-openapi.yml`.
- `openapi-generator-maven-plugin:7.27.0` generates Spring interfaces (tags → `Auth`, `FamilyGroups`, `Categories`, `Transactions`, `Messages`, `PatternRegistry`, `Dashboard`) and DTO models; controllers implement those interfaces.
- SpringDoc serves Swagger UI (`/swagger-ui.html`) and OpenAPI JSON (`/api-docs`).
- ⚠️ Known drift: the root-level `api/budgetly-openapi.yml` is an older copy and the `PATCH /patterns/{id}/category` controller endpoint is not yet in the spec — see [TODO.md](TODO.md).

## 6. Configuration & Observability

- Runtime config: `application.yml`, `application-docker.yml`, `application-test.yml`.
- Key env: `GOOGLE_CLIENT_ID` (required), `JWT_SECRET`, `LLM_PROVIDER` (`openai` default / `gemini`), `OPENAI_*`, `SPRING_MONGODB_URI`, `BUDGETLY_CHANGE_STREAM_ENABLED`.
- Actuator: `/actuator/health`, `/actuator/prometheus`, `/actuator/metrics`.

## 7. Testing Strategy

| Layer | Tool | Notes |
|---|---|---|
| Backend E2E | RestAssured `*E2ETest.java` | Full `@SpringBootTest` context against embedded Flapdoodle MongoDB 7.0.9 (no Docker required) |
| Backend unit | JUnit + Mockito + Awaitility | `AnchorParserTest`, `MessageChangeStreamListenerTest`, service tests |
| Flutter | `flutter test` (`app/test/`) | Widget + provider + service + model tests (`mocktail`) |
| Release gate | E2E smoke tests | Per CLAUDE.md — run on the Android emulator before completion |

## 8. Decision Log

Architecture decisions are recorded as ADRs in `doc/adr/`:
- `0003-bulk-insert-change-stream.md` — bulk ingestion + change-stream consumer.
- `0004-upgrade-to-java-25-and-spring-boot-4.md` — Java 25 / Spring Boot 4.1.2 migration.
