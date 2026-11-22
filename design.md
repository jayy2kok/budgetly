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
├── config/           # SecurityConfig, MongoConfig, CorsConfig
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

- Legacy `source=DIRECT` documents were completed synchronously when they were written and are never claimed by the listener (duplicate-processing race resolved — ADR-0003). The message triage endpoints (`/messages/pending`, `/messages/ignored`, `/messages/failed`, `/messages/{id}/confirm|reject|restore`, `/messages/process`) have been removed; bulk ingestion + the change stream is the only server-side message path.

### 3.3 Device inbox → two tabs (Recorded / Non-Transactions)

The app's message inbox mirrors the phone's SMS store rather than the server's message triage queue. `InboxNotifier.refresh()` reads every device SMS (`SmsInboxReader.readAllInbox`), then classifies each one by asking whether a recorded transaction carries the same normalized body:

```mermaid
sequenceDiagram
    participant Screen as MessageInboxScreen
    participant Inbox as InboxNotifier
    participant Reader as SmsInboxReader
    participant Plugin as flutter_sms_inbox
    participant Tx as TransactionService

    Screen->>Inbox: refresh()
    Inbox->>Reader: readAllInbox(userId) (newest first, limit 300)
    Reader->>Plugin: querySms(kinds=[inbox], count=300)
    Plugin-->>Reader: every SMS (sender, body, received date)
    Reader-->>Inbox: Message list (empty sender/body skipped)
    alt family available
        Inbox->>Tx: getTransactions(familyId, page, size=200)
        Tx-->>Inbox: recent transactions
        Inbox->>Inbox: page until short page, oldest tx < oldest SMS − 1 day, or 5 pages
    end
    Inbox->>Inbox: multiset sourceRawText → transactions<br/>(SMS-sourced rows only, trim + collapse whitespace)
    Inbox->>Inbox: consume one transaction per matching SMS (newest SMS ↔ newest tx)
    Inbox-->>Screen: recordedMessages / nonTransactions
```

- `Recorded Transactions` = SMS with a consumed transaction; tapping one opens `AppRoutes.transactionDetail` for that transaction. The card hands the transaction to the route via `extra`, because the inbox window (300 SMS) can reach further back than the feed's first page (20 transactions); the detail screen falls back to the paged `transactionProvider` list when no transaction is handed over.
- `Non-Transactions` = every other SMS (OTP, promo, personal, and parseable bank SMS not yet recorded). Each card shows sender, date-led timestamp, and body, with a single `Define pattern` action.
- Manual rows (`sourceType=manual`) and legacy transaction rows created before `sourceRawText` existed can never match, so views created from them appear under Non-Transactions. This is acceptable: the inbox mirrors the device, and those messages can still produce a pattern.
- Matching is one-to-one per normalized body. Two identical SMS bodies need two distinct transactions to both show as recorded; otherwise one stays under Non-Transactions.

### 3.4 Timestamp resolution (date-only SMS)

```mermaid
flowchart TD
    A[Body timestamp token] --> B{parses with time?}
    B -- yes --> C[Use body date + body time]
    B -- no --> D{parses as date only?}
    D -- yes --> E[SMS received time-of-day]
    E --> F{received time available?}
    F -- yes --> G[body date + received hh:mm:ss]
    F -- no --> H[body date + 00:00:00]
    D -- no --> I{receivedAt present?}
    I -- yes --> J[receivedAt]
    I -- no --> K[Instant.now]
```

`TransactionDateResolver.resolve` (Dart) and `TransactionDateParser.resolveTransactionDate` (Java) implement the same rule: a body timestamp containing `\d{1,2}:\d{2}` wins completely; a date-only body keeps its date and borrows the received time-of-day; missing body or unparseable tokens fall back to the received time, then to now. The date is always the most important signal.

## 4. Literal-Anchor Parsing (no regex)

The pattern engine stores sender templates as literal text with `{token}` placeholders and matches by **left/right literal anchors** using `indexOf` on both Java and Dart — guaranteeing identical behavior across platforms. See [`plans/token_template_sms_parsing.md`](plans/token_template_sms_parsing.md) and the parity tests `AnchorParserTest` (Java) / `sms_parser_service_test.dart` (Dart).

### 4.1 Registry scope & match precedence

`pattern_registry` documents carry `scope` (`GLOBAL`/`FAMILY`), `ownerFamilyGroupId`, `createdByUserId`, and `source` (`LLM`/`USER`). LLM-seeded patterns are global; authoring through the builder creates a family-scoped `USER` pattern. Lookup for an incoming SMS resolves the owning family from the message and tries family patterns **before** globals, newest first within each scope:

```mermaid
flowchart TD
    SMS[Incoming SMS: sender + familyGroupId] --> Q[findActiveForSenderAndFamily]
    Q --> F{FAMILY patterns for<br/>this family?}
    F -- yes --> FF[Newest updatedAt wins]
    F -- no --> G{GLOBAL patterns<br/>for this sender?}
    G -- yes --> GG[Newest updatedAt wins]
    G -- no --> LLM[No literal-anchor match → LLM analysis]
    FF --> MATCH[AnchorParserService.parse]
    GG --> MATCH
```

- The on-device parser (`SmsParserService.parseMessage`) applies the same precedence — family first, newest `updatedAt` within a scope — before anchor-matching locally, so an authored family pattern and its fixed values are not shadowed by a newer global LLM pattern. It additionally filters to `matchablePatterns` (`active && !hiddenForFamily`), so a global hidden by the caller's family never parses on that device. When a matched pattern carries a `categoryName` override, the client loads the family's categories on demand to resolve it to a `categoryId` when it posts the transaction as `REGEX_LOCAL`.
- The registry viewer lists active globals minus the caller's hidden globals, plus every pattern owned by the caller's family (active and inactive). `GET /patterns` resolves the caller's family server-side, so another family's authored templates are never exposed.
- Any family member can act on a global: editing it creates a family copy and hides the global for that family only. Family patterns are edited/disabled by their author or a family admin. A family admin can promote a family pattern once `usageCount >= pattern.promote-usage-threshold`, after which it becomes `GLOBAL` and is shared by every family. There is no delete endpoint — patterns are disabled, and globals are hidden per family.

#### 4.1.1 Editing / disabling a GLOBAL: copy-on-write + hide marker

The family's registry row for a global is shared, so the server never mutates it. Editing first materializes a family copy, then hides the global for that family:

```mermaid
sequenceDiagram
    participant App as Pattern builder (edit mode)
    participant API as PatternRegistryController
    participant Svc as PatternRegistryService
    participant DB as MongoDB

    App->>API: PUT /patterns/{globalId} (merged fields)
    API->>Svc: updatePattern(globalId, ...)
    Svc->>DB: find visible pattern → GLOBAL
    Svc->>DB: find family copy by derivedFromPatternId<br/>(else same sender+template)
    alt family copy exists
        Svc->>DB: update copy in place (merged fields, active=true)
    else no copy
        Svc->>DB: insert FAMILY copy (source=USER, usageCount=0,<br/>ownerFamilyGroupId=caller, derivedFromPatternId=globalId)
    end
    Svc->>DB: upsert hidden_patterns(familyGroupId, globalId)
    Svc-->>App: 200 family copy
```

Ordering matters: the marker is written only after the copy exists, so a mid-flight failure can never leave the family with neither pattern. Repeating the edit updates the same copy. `POST /patterns/{id}/disable` follows the same split: `GLOBAL` → upsert marker; `FAMILY` → `active=false`. `POST /patterns/{id}/enable` reverses it; enabling a family pattern returns `409` when another active visible pattern shares its sender+template.

### 4.2 Highlight-and-tag pattern builder

Every non-transaction message carries a single `Define pattern` action that opens the builder prefilled with that SMS. The client derives the template, previews the match with the same anchor algorithm, and the server re-validates the effective `(template, sampleMessage)` pair before persisting:

```mermaid
flowchart LR
    A[Non-transaction SMS] --> B[Select span in raw SMS]
    B --> C[Tag span: Amount / Merchant / Date / Type / Account / Notes]
    C --> D[PatternDraftBuilder.fromSpans<br/>literals + tokens, identity extractionMap]
    D --> E{contains amount?}
    E -- no --> X[Block: amount required]
    E -- yes --> F[SmsParserService.dryRunTemplate]
    F -->|no match| X2[Block: template does not match]
    F -->|match| G[POST /patterns]
    G --> H[Server re-validates with AnchorParserService]
    H -->|400/409| X3[Error banner]
    H -->|201| I[FAMILY pattern, source=USER, active=true]
```

- Manual edits to the template bypass the client dry-run but are still validated server-side (400 when no fields or no `amount` extract). This is the known gap for OTP/promo/personal SMS: `Define pattern` is offered on every non-transaction message, but a body with no amount cannot be saved and the builder surfaces the validation message.
- On create, a successful save also calls `SmsNotifier.recordLocally(message)`: the sync checkpoint means this SMS is never re-read by the background pipeline, so the source message is parsed against the fresh cache and posted immediately when complete. On edit the source message is not re-recorded (the pattern only changes future matching).
- Edit mode (`?patternId=`) prefills sender, sample, template, fixed values, and category from the registry. Span tagging is hidden because spans cannot be reconstructed from a stored template. Editing a GLOBAL shows "Customize for family" and saves as the copy-on-write flow in 4.1.1.
- Overlapping tagged spans are rejected client-side; the derivation is pure logic (`pattern_draft_builder.dart`) unit-tested independently of the widget.
- The builder also offers an optional **category override** (resolved per family by name at match time) and **fixed values** for Merchant / Account / Bank name / Notes. A fixed value is stored in `pattern_registry.fixedValues` and wins over the template-extracted value; an empty input uses the extracted value. `amount`, `timestamp`, and `type` are rejected as fixed values (they drive parsing), and promotion to `GLOBAL` clears `fixedValues` so family-specific literals do not leak into the shared library.

### 4.3 Pattern resolution at transaction time

The listener resolves each field with fixed-value precedence, then persists the result (including `accountLast4`, `bankName`, and `notes`) on the transaction:

```mermaid
flowchart LR
    P[Matched pattern] --> A[amountOf parsed]
    P --> F{fixedValues has field?}
    F -- yes --> L[Use literal]
    F -- no --> E{extracted field?}
    E -- yes --> X[Use extracted value]
    E -- no --> N[null]
    L --> TX[CreateTransactionRequest<br/>amount/merchant/accountLast4/bankName/notes]
    X --> TX
    N --> TX
```

## 5. API Contract (Contract-First)

- Canonical spec: `budgetly_api/src/main/resources/api/budgetly-openapi.yml`.
- `openapi-generator-maven-plugin:7.27.0` generates Spring interfaces (tags → `Auth`, `FamilyGroups`, `Categories`, `Transactions`, `Messages`, `PatternRegistry`, `Dashboard`) and DTO models; controllers implement those interfaces.
- SpringDoc serves Swagger UI (`/swagger-ui.html`) and OpenAPI JSON (`/api-docs`).

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
- `0001-raw-google-oauth-and-custom-jwt.md` — raw Google OAuth 2.0 verification + custom JWT (no Firebase).
- `0002-contract-first-openapi-generation.md` — contract-first OpenAPI code generation (`openapi-generator-maven-plugin`).
- `0003-bulk-insert-change-stream.md` — bulk ingestion + change-stream consumer.
- `0004-upgrade-to-java-25-and-spring-boot-4.md` — Java 25 / Spring Boot 4.1.2 migration.
