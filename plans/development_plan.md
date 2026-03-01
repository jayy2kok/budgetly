# Budgetly — Family Harmony Budget App: Development Plan

> **App Concept:** A family-oriented mobile budgeting app that lets household members collaboratively track shared finances, parse bank SMS alerts via AI (server-side), plan monthly budgets by category, and manage family group settings — all backed by Gmail-based authentication.

---

## 1. High-Level Architecture

```mermaid
graph TB
    subgraph "Presentation Layer — Flutter Mobile App"
        A[Flutter App<br/>Dark-theme, Indigo/Slate UI<br/>Riverpod State Mgmt]
    end

    subgraph "Business Logic Layer — Spring Boot (Docker)"
        B[Spring Boot REST API<br/>Java 17+ / Swagger-Bootstrapped<br/>Raw Google OAuth 2.0 + JWT]
    end

    subgraph "Data Layer — MongoDB (Docker)"
        C[(MongoDB<br/>Document Store)]
    end

    A -- "REST API (JSON / HTTP)" --> B
    B -- "Spring Data MongoDB" --> C
```

| Layer | Technology | Hosting |
|---|---|---|
| **Presentation** | Flutter (Dart), Material 3, dark theme, Riverpod | Android / iOS device |
| **Business Logic** | Java 17+, Spring Boot 3.x, Swagger/OpenAPI 3 | Docker container |
| **Database** | MongoDB 7.x | Docker container |

---

## 2. Key Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **State Management** | **Riverpod** | Type-safe, testable, and makes swapping mock → real API trivial. Acts as "smart containers" that hold app data (logged-in user, transactions, budget) and automatically update all screens when data changes. |
| **Authentication** | **Raw Google OAuth 2.0** → custom JWT | Full control over token lifecycle; no Firebase dependency. Spring Boot validates Google ID token, issues app-specific JWT. |
| **SMS/AI Parsing** | **Server-side** (Spring Boot) | Centralized logic, easier to update parsing rules, no on-device model needed. Flutter sends raw SMS text → API returns parsed transaction. |
| **Family Model** | **Flexible N members** | Supports any household: couples, parents+kids, roommates. Each member has a role (Admin, Member). |
| **Split Methods** | **Percent or share-based ratio** | Split among N family members by percentage (e.g., 60/40) or share ratio (e.g., 2:1:1). |
| **Currency** | **Single currency (INR) first** | Default: INR (₹), Locale: India. Multi-currency support planned for a later release. |
| **HTTP Client** | **Dio** (Flutter) | Interceptors for JWT auth, retry, logging. |
| **Model Generation** | **openapi-generator-maven-plugin** | Compile-time contract enforcement between Swagger spec and Java code. |
| **Containerization** | **Docker Compose** | Single command to spin up API + DB for development. |
| **Automated Testing** | **Mandatory in every build — no exceptions** | `flutter test` and `mvn test` are gating steps. Builds fail if any test fails. Every screen, provider, service, controller, and repository has tests. |

---

## 3. Development Strategy

> **Frontend-first approach:** Build the Flutter app with mock data first, validate UI/UX against Stitch designs, then implement the real Spring Boot backend and swap in.

```mermaid
graph LR
    P1["Phase 1<br/>OpenAPI Spec +<br/>Swagger Design"] --> P2["Phase 2<br/>Flutter App +<br/>Mock APIs"]
    P2 --> P3["Phase 3<br/>Spring Boot +<br/>MongoDB (Docker)"]
    P3 --> P4["Phase 4<br/>Integration +<br/>Polish"]
```

### Phase 1 — API Contract & Project Setup (Week 1)

| # | Task | Layer |
|---|------|-------|
| 1.1 | Write the full OpenAPI 3.0 spec (`budgetly-openapi.yml`) | Spec |
| 1.2 | Set up Flutter project with dark theme, fonts (Inter, IBM Plex Sans), routing | Flutter |
| 1.3 | Configure Riverpod for state management | Flutter |
| 1.4 | Build reusable design system widgets (colors, typography, cards, nav bar) | Flutter |
| 1.5 | Create mock data layer that mirrors the API spec responses | Flutter |
| 1.6 | **Set up test infrastructure**: Flutter test framework, `flutter_test`, `mocktail`, test helpers | Flutter |
| 1.7 | **Validate OpenAPI spec** with `swagger-cli validate` (add to CI check) | Spec |

### Phase 2 — Flutter App with Mock APIs (Week 2–4)

> ⚠️ **Rule: Every screen and provider must have corresponding tests before the task is marked complete.**

| # | Task | Screen(s) |
|---|------|-----------|
| 2.1 | Google Sign-In UI + mock auth flow | Login |
| 2.2 | Bottom navigation shell with 4 tabs (Home, Feed, Budget, Settings) | All |
| 2.3 | Dashboard — budget ring chart, stat cards, activity list, FAB | Dashboard |
| 2.4 | Transaction Feed — date-grouped list, filter chips, search | Transaction Feed |
| 2.5 | Add Expense — amount input, N-member payer selector, category picker, split config | Add Expense |
| 2.6 | Transaction Detail — source analysis, split policy, category, notes | Transaction Detail |
| 2.7 | Message Inbox — swipeable triage cards, confirm/edit/reject | Message Inbox |
| 2.8 | Ignored Messages — tabs (AI Skipped / Deleted), undo restore | Ignored Messages |
| 2.9 | Monthly Budget Planning — overall progress, per-category bars, add category | Monthly Budget |
| 2.10 | Settings & Data — profile banner, budget slider, preferences | Settings |
| 2.11 | Link Family Members — Google linking, member list, invite (email/link/QR) | Link Family |
| 2.12 | Family Group Settings — currency, region, alerts, permissions | Family Settings |
| **2.T** | **Widget tests for every screen (2.1–2.12)** | **All** |
| **2.T2** | **Unit tests for all Riverpod providers** | **All** |
| **2.T3** | **Unit tests for all mock services** | **All** |
| **2.T4** | **Model serialization/deserialization tests** | **All** |
| **2.T5** | **Run `flutter test` — must pass 100% before proceeding to Phase 3** | **Gate** |

### Phase 3 — Spring Boot Backend + MongoDB (Week 5–7)

> ⚠️ **Rule: Every controller, service, and repository must have corresponding tests. `mvn verify` is the gateway — it must pass.**

| # | Task | Layer |
|---|------|-------|
| 3.1 | Set up Spring Boot project with Maven, Swagger UI, MongoDB | Backend |
| 3.2 | Configure `openapi-generator-maven-plugin` for compile-time model generation | Backend |
| 3.3 | Create `docker-compose.yml` for MongoDB + API | Infra |
| 3.4 | Implement Google OAuth 2.0 token verification → JWT issuance | Backend |
| 3.5 | Implement Family Group CRUD APIs | Backend |
| 3.6 | Implement Category CRUD APIs | Backend |
| 3.7 | Implement Transaction CRUD APIs (pagination, filters) | Backend |
| 3.8 | Implement Message triage APIs (submit, confirm, reject, restore) | Backend |
| 3.9 | Implement SMS text parsing service (server-side, regex → structured transaction) | Backend |
| 3.10 | Implement Dashboard aggregation + Budget summary APIs | Backend |
| 3.11 | Implement Family invite system (email, link) | Backend |
| 3.12 | Data export API (CSV/JSON) | Backend |
| **3.T** | **Unit tests for every controller** (MockMvc) | **Backend** |
| **3.T2** | **Unit tests for every service** (Mockito) | **Backend** |
| **3.T3** | **Integration tests for every repository** (Embedded MongoDB via Testcontainers) | **Backend** |
| **3.T4** | **SMS parsing service tests** (test various bank SMS formats) | **Backend** |
| **3.T5** | **Security tests** (JWT validation, unauthorized access, role checks) | **Backend** |
| **3.T6** | **OpenAPI contract validation** (`swagger-cli validate`) | **Backend** |
| **3.T7** | **Run `mvn verify` — must pass 100% before proceeding to Phase 4** | **Gate** |

### Phase 4 — Integration & Polish (Week 8–9)

> ⚠️ **Rule: Full integration test suite must pass. Both `flutter test` AND `mvn verify` run together as a final gate.**

| # | Task | Layer |
|---|------|-------|
| 4.1 | Swap Flutter mock data layer → real Dio HTTP client hitting Spring Boot | Flutter |
| 4.2 | End-to-end auth flow: Google Sign-In → API JWT → authenticated requests | Both |
| 4.3 | UI polish: animations, transitions, micro-interactions, loading/error/empty states | Flutter |
| 4.4 | Push notifications for expense alerts | Both |
| 4.5 | API security hardening: rate limiting, input validation | Backend |
| 4.6 | Docker production build optimization | Infra |
| **4.T** | **Flutter integration tests** (full user flow via `flutter test integration_test/`) | **Flutter** |
| **4.T2** | **API integration tests against live Docker containers** (Testcontainers) | **Backend** |
| **4.T3** | **End-to-end smoke tests**: Login → Create Family → Add Expense → Dashboard | **Both** |
| **4.T4** | **Final gate: `flutter test` + `mvn verify` must both pass** | **Gate** |

---

## 4. App Features (Derived from Stitch Screens)

### 4.1 Authentication
- **Gmail-based login** using raw Google OAuth 2.0
- Flutter uses `google_sign_in` package → sends ID token to Spring Boot
- Spring Boot verifies token with Google, creates/finds user, issues JWT
- JWT used for all subsequent API calls

### 4.2 Dashboard (Screen 01)
- Circular **budget usage ring** showing "Left to Spend" amount
- Summary cards: Daily Average, Projected Spend, Savings
- **Recent Activity** list (top 3 transactions with merchant, category, payer avatar, amount)
- Floating **"+"** button to add expense
- Bottom navigation: Home | Feed | Budget | Settings

### 4.3 Transaction Feed (Screen 02)
- Date-grouped transaction list (Today, Yesterday, etc.)
- Filter chips: All | Expenses | Income | Subscriptions
- Search and tune/filter actions
- Each entry shows: category icon, payer avatar + name, category tag, amount (green for income)

### 4.4 Add Expense (Screen 03)
- Large amount input (₹ currency)
- **N-member payer selector** (dynamically lists all family members)
- Merchant / Description text field
- Horizontally scrollable **category picker** (Groceries, Dining, Transport, Housing, Bills, etc.)
- Date picker
- **Split method config**: choose percent-based (e.g., 60/20/20) or share-based ratio (e.g., 3:2:1) among selected members
- "Add Expense" CTA button

### 4.5 Transaction Detail & Source View (Screen 04)
- Full detail view of a single transaction
- **Source Analysis** section showing raw SMS text parsed by server-side AI
- Splitting policy toggle (Personal vs Shared with configurable ratios)
- Category selector, Date field, Merchant field, Notes textarea
- Confirm & Update button, Delete/Share actions

### 4.6 Message Inbox — AI Triage (Screen 05)
- Swipeable card-based review of SMS-parsed transactions
- Progress bar ("Reviewing 1 of 3")
- Each card: merchant icon, name, amount, date, budget category, raw SMS text
- Actions per card: **Confirm** (large check button), **Edit**, **Reject**

### 4.7 Ignored Messages (Screen 06)
- Lists messages the AI auto-skipped (OTP codes, personal messages, delivery notifications)
- Two tabs: **AI Skipped** | **Deleted**
- Each item shows sender, timestamp, preview text, **Undo** button

### 4.8 Settings & Data (Screen 07)
- Family profile banner (all member avatars, plan type)
- Joint Budget monthly limit **slider** (₹10K → ₹2L)
- Preferences: Notifications, Shared Accounts, Currency (INR default)
- Data & Privacy: Export Data (CSV/JSON), Security & Privacy
- Log Out button, version info

### 4.9 Link Family Members (Screen 08)
- **Continue with Google** button (Google OAuth for linking)
- Household Members list (avatar, name, role — Administrator/Member)
- Add New Member: Invite via Email, Copy Link, Show QR
- Trust/permissions notice

### 4.10 Monthly Budget Planning (Screen 09)
- Overall spend vs limit progress bar (e.g., ₹24,500 / ₹30,000)
- Per-category budget cards with progress bars
- Over-budget categories highlighted in red
- **Add Category** button (dashed border)
- **Edit/Delete Category** (Admin only). Deleting a category reassigns its transactions to "Uncategorized".
- Edit mode toggle

### 4.11 Family Group Settings (Screen 10)
- Family avatar and name
- Localization: Default Currency (INR), Region/Date Format (India DD/MM/YYYY)
- Preferences: Expense Alerts toggle, Categories management, Member Permissions
- "Leave Family Group" destructive action

---

## 5. Domain Model

```mermaid
erDiagram
    USER {
        string id PK
        string googleId UK
        string displayName
        string email
        string avatarUrl
        datetime createdAt
    }

    FAMILY_GROUP {
        string id PK
        string name
        string avatarInitial
        string defaultCurrency "INR"
        string regionFormat "IN"
        boolean expenseAlertsEnabled
        double monthlyBudgetLimit
        string createdByUserId FK
        datetime createdAt
    }

    FAMILY_MEMBER {
        string id PK
        string userId FK
        string familyGroupId FK
        string role "ADMIN | MEMBER"
        string status "ACTIVE | INVITED | REMOVED"
        datetime joinedAt
    }

    CATEGORY {
        string id PK
        string familyGroupId FK
        string name
        string icon
        double budgetLimit
        string color
        int sortOrder
    }

    TRANSACTION {
        string id PK
        string familyGroupId FK
        string createdByUserId FK
        string categoryId FK
        double amount
        string currency "INR"
        string merchant
        string description
        string type "EXPENSE | INCOME | SUBSCRIPTION"
        string splitMethod "PERSONAL | PERCENT | SHARE"
        object splitConfig "map of memberId to percent or share"
        string sourceType "MANUAL | SMS | AI_PARSED"
        string sourceRawText
        boolean aiVerified
        string notes
        datetime transactionDate
        datetime createdAt
    }

    MESSAGE {
        string id PK
        string userId FK
        string familyGroupId FK
        string sender
        string rawText
        string status "PENDING | CONFIRMED | REJECTED | IGNORED"
        string triageResult "TRANSACTION | OTP | PROMO | PERSONAL | UNKNOWN"
        string linkedTransactionId FK
        datetime receivedAt
    }

    USER ||--o{ FAMILY_MEMBER : "belongs to"
    FAMILY_GROUP ||--o{ FAMILY_MEMBER : "has"
    FAMILY_GROUP ||--o{ CATEGORY : "defines"
    FAMILY_GROUP ||--o{ TRANSACTION : "contains"
    USER ||--o{ TRANSACTION : "creates"
    CATEGORY ||--o{ TRANSACTION : "categorizes"
    USER ||--o{ MESSAGE : "receives"
    MESSAGE |o--o| TRANSACTION : "links to"
```

### Role Permissions

| Feature | Admin | Member |
|---|---|---|
| View Budget | Yes | Yes |
| Add Expenses | Yes | Yes |
| View own ignored messages | Yes | Yes |
| Set Budget | Yes | No |
| Add Categories | Yes | No |
| Invite Members | Yes | No |

### Split Configuration Examples

**Percent-based** (3 members, 50/30/20):
```json
{
  "splitMethod": "PERCENT",
  "splitConfig": {
    "member_id_1": 50,
    "member_id_2": 30,
    "member_id_3": 20
  }
}
```

**Share-based** (2 members, ratio 3:1):
```json
{
  "splitMethod": "SHARE",
  "splitConfig": {
    "member_id_1": 3,
    "member_id_2": 1
  }
}
```

---

## 6. REST API Design (Swagger/OpenAPI)

All APIs documented and testable via Swagger UI (`/swagger-ui.html`). Domain models auto-generated at compile time from the OpenAPI spec using `openapi-generator-maven-plugin`.

### 6.1 Auth API

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/auth/google` | Exchange Google ID token for app JWT |
| `POST` | `/api/v1/auth/refresh` | Refresh JWT token |
| `GET`  | `/api/v1/auth/me` | Get current user profile |

### 6.2 Family Group API

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/families` | Create a new family group |
| `GET` | `/api/v1/families/{id}` | Get family group details |
| `PUT` | `/api/v1/families/{id}` | Update family settings (currency, alerts, name) |
| `DELETE` | `/api/v1/families/{id}` | Delete / leave family group |
| `POST` | `/api/v1/families/{id}/invite` | Generate invite link / send email invite |
| `POST` | `/api/v1/families/{id}/join` | Join family via invite code |
| `GET` | `/api/v1/families/{id}/members` | List family members |
| `PUT` | `/api/v1/families/{id}/members/{memberId}` | Update member role/permissions |
| `DELETE` | `/api/v1/families/{id}/members/{memberId}` | Remove member |

### 6.3 Category API

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/families/{fid}/categories` | List all categories |
| `POST` | `/api/v1/families/{fid}/categories` | Create a category |
| `PUT` | `/api/v1/families/{fid}/categories/{id}` | Update category (name, icon, budget) |
| `DELETE` | `/api/v1/families/{fid}/categories/{id}` | Delete category |

### 6.4 Transaction API

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/families/{fid}/transactions` | List transactions (paginated, filterable) |
| `POST` | `/api/v1/families/{fid}/transactions` | Create a transaction |
| `GET` | `/api/v1/families/{fid}/transactions/{id}` | Get transaction detail |
| `PUT` | `/api/v1/families/{fid}/transactions/{id}` | Update transaction |
| `DELETE` | `/api/v1/families/{fid}/transactions/{id}` | Delete transaction |

**Query Parameters:** `type`, `startDate`, `endDate`, `categoryId`, `createdByUserId`, `page`, `size`, `sort`

### 6.5 Message (AI Triage) API

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/messages/pending` | Get pending messages for triage |
| `GET` | `/api/v1/messages/ignored` | Get AI-skipped / deleted messages |
| `POST` | `/api/v1/messages` | Submit raw SMS text for server-side AI parsing |
| `POST` | `/api/v1/messages/{id}/confirm` | Confirm parsed transaction |
| `POST` | `/api/v1/messages/{id}/reject` | Reject / ignore message |
| `POST` | `/api/v1/messages/{id}/restore` | Restore an ignored message |

### 6.6 Budget / Dashboard API

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/families/{fid}/dashboard` | Aggregated dashboard data |
| `GET` | `/api/v1/families/{fid}/budget/summary` | Monthly budget summary with per-category breakdowns |
| `PUT` | `/api/v1/families/{fid}/budget` | Update overall monthly budget limit |

---

## 7. Project Structure

### 7.1 Flutter App (`/budgetly_app/`)

```
budgetly_app/
├── lib/
│   ├── main.dart
│   ├── app.dart                           # MaterialApp, theme, routes
│   ├── config/
│   │   ├── theme.dart                     # Dark theme (Slate 950, Indigo 500)
│   │   ├── routes.dart
│   │   └── api_config.dart                # Base URL config
│   ├── models/
│   │   ├── user.dart
│   │   ├── family_group.dart
│   │   ├── family_member.dart
│   │   ├── transaction.dart
│   │   ├── category.dart
│   │   ├── message.dart
│   │   └── split_config.dart
│   ├── data/
│   │   ├── mock/                          # ★ Phase 2: Mock data layer
│   │   │   ├── mock_auth_service.dart
│   │   │   ├── mock_family_service.dart
│   │   │   ├── mock_transaction_service.dart
│   │   │   ├── mock_category_service.dart
│   │   │   ├── mock_message_service.dart
│   │   │   ├── mock_budget_service.dart
│   │   │   └── sample_data.dart           # Seed data matching Stitch screens
│   │   └── remote/                        # ★ Phase 4: Real API layer (swap in)
│   │       ├── api_client.dart            # Dio setup, JWT interceptor
│   │       ├── auth_service.dart
│   │       ├── family_service.dart
│   │       ├── transaction_service.dart
│   │       ├── category_service.dart
│   │       ├── message_service.dart
│   │       └── budget_service.dart
│   ├── providers/                         # Riverpod providers
│   │   ├── auth_provider.dart
│   │   ├── family_provider.dart
│   │   ├── transaction_provider.dart
│   │   ├── budget_provider.dart
│   │   └── message_provider.dart
│   ├── screens/
│   │   ├── auth/
│   │   │   └── login_screen.dart
│   │   ├── dashboard/
│   │   │   └── dashboard_screen.dart
│   │   ├── feed/
│   │   │   └── transaction_feed_screen.dart
│   │   ├── expense/
│   │   │   ├── add_expense_screen.dart
│   │   │   └── transaction_detail_screen.dart
│   │   ├── messages/
│   │   │   ├── message_inbox_screen.dart
│   │   │   └── ignored_messages_screen.dart
│   │   ├── budget/
│   │   │   └── monthly_budget_screen.dart
│   │   ├── settings/
│   │   │   ├── settings_screen.dart
│   │   │   ├── link_family_screen.dart
│   │   │   └── family_group_settings_screen.dart
│   │   └── shell/
│   │       └── app_shell.dart             # Bottom nav + tab routing
│   └── widgets/
│       ├── budget_ring.dart
│       ├── transaction_tile.dart
│       ├── category_chip.dart
│       ├── stat_card.dart
│       ├── message_card.dart
│       ├── member_tile.dart
│       ├── split_config_widget.dart
│       └── payer_selector.dart
├── pubspec.yaml
├── test/                                  # ★ MANDATORY — mirrors lib/ structure
│   ├── models/
│   │   ├── user_test.dart
│   │   ├── transaction_test.dart
│   │   ├── split_config_test.dart
│   │   └── ...
│   ├── data/
│   │   └── mock/
│   │       ├── mock_auth_service_test.dart
│   │       ├── mock_transaction_service_test.dart
│   │       └── ...
│   ├── providers/
│   │   ├── auth_provider_test.dart
│   │   ├── transaction_provider_test.dart
│   │   ├── budget_provider_test.dart
│   │   └── ...
│   ├── screens/
│   │   ├── dashboard/
│   │   │   └── dashboard_screen_test.dart
│   │   ├── feed/
│   │   │   └── transaction_feed_screen_test.dart
│   │   ├── expense/
│   │   │   ├── add_expense_screen_test.dart
│   │   │   └── transaction_detail_screen_test.dart
│   │   ├── messages/
│   │   │   ├── message_inbox_screen_test.dart
│   │   │   └── ignored_messages_screen_test.dart
│   │   ├── budget/
│   │   │   └── monthly_budget_screen_test.dart
│   │   └── settings/
│   │       ├── settings_screen_test.dart
│   │       ├── link_family_screen_test.dart
│   │       └── family_group_settings_screen_test.dart
│   └── widgets/
│       ├── budget_ring_test.dart
│       ├── transaction_tile_test.dart
│       ├── split_config_widget_test.dart
│       └── ...
└── integration_test/                     # ★ Phase 4: Full user-flow tests
    ├── app_test.dart
    ├── auth_flow_test.dart
    └── expense_flow_test.dart
```

### 7.2 Spring Boot Backend (`/budgetly_api/`)

```
budgetly_api/
├── pom.xml                                # Maven + openapi-generator-maven-plugin
├── src/
│   ├── main/
│   │   ├── java/com/budgetly/api/
│   │   │   ├── BudgetlyApplication.java
│   │   │   ├── config/
│   │   │   │   ├── SecurityConfig.java        # JWT filter + Google OAuth validation
│   │   │   │   ├── SwaggerConfig.java
│   │   │   │   ├── MongoConfig.java
│   │   │   │   └── CorsConfig.java
│   │   │   ├── controller/                    # Implements generated interfaces
│   │   │   │   ├── AuthController.java
│   │   │   │   ├── FamilyGroupController.java
│   │   │   │   ├── CategoryController.java
│   │   │   │   ├── TransactionController.java
│   │   │   │   ├── MessageController.java
│   │   │   │   └── DashboardController.java
│   │   │   ├── service/
│   │   │   │   ├── AuthService.java
│   │   │   │   ├── FamilyGroupService.java
│   │   │   │   ├── CategoryService.java
│   │   │   │   ├── TransactionService.java
│   │   │   │   ├── MessageService.java
│   │   │   │   ├── DashboardService.java
│   │   │   │   └── SmsParsingService.java     # Server-side SMS → transaction parser
│   │   │   ├── repository/
│   │   │   │   ├── UserRepository.java
│   │   │   │   ├── FamilyGroupRepository.java
│   │   │   │   ├── CategoryRepository.java
│   │   │   │   ├── TransactionRepository.java
│   │   │   │   └── MessageRepository.java
│   │   │   ├── security/
│   │   │   │   ├── JwtTokenProvider.java
│   │   │   │   ├── JwtAuthFilter.java
│   │   │   │   └── GoogleTokenVerifier.java
│   │   │   ├── exception/
│   │   │   │   ├── GlobalExceptionHandler.java
│   │   │   │   └── ResourceNotFoundException.java
│   │   │   └── util/
│   │   │       └── DateUtils.java
│   │   └── resources/
│   │       ├── application.yml
│   │       ├── application-docker.yml
│   │       └── api/
│   │           └── budgetly-openapi.yml       # OpenAPI 3.0 spec (shared source of truth)
│   └── test/                              # ★ MANDATORY — mirrors main/ structure
│       └── java/com/budgetly/api/
│           ├── controller/
│           │   ├── AuthControllerTest.java
│           │   ├── FamilyGroupControllerTest.java
│           │   ├── CategoryControllerTest.java
│           │   ├── TransactionControllerTest.java
│           │   ├── MessageControllerTest.java
│           │   └── DashboardControllerTest.java
│           ├── service/
│           │   ├── AuthServiceTest.java
│           │   ├── FamilyGroupServiceTest.java
│           │   ├── TransactionServiceTest.java
│           │   ├── SmsParsingServiceTest.java
│           │   └── DashboardServiceTest.java
│           ├── repository/
│           │   ├── UserRepositoryIT.java       # Integration tests (Testcontainers)
│           │   ├── TransactionRepositoryIT.java
│           │   └── FamilyGroupRepositoryIT.java
│           └── security/
│               ├── JwtTokenProviderTest.java
│               └── GoogleTokenVerifierTest.java
├── Dockerfile
└── .dockerignore
```

### 7.3 Docker Compose (`/docker-compose.yml`)

```yaml
version: "3.9"
services:
  mongodb:
    image: mongo:7
    ports:
      - "27017:27017"
    volumes:
      - mongo_data:/data/db
    environment:
      MONGO_INITDB_ROOT_USERNAME: budgetly
      MONGO_INITDB_ROOT_PASSWORD: budgetly_secret
      MONGO_INITDB_DATABASE: budgetly

  budgetly-api:
    build: ./budgetly_api
    ports:
      - "8080:8080"
    depends_on:
      - mongodb
    environment:
      SPRING_DATA_MONGODB_URI: mongodb://budgetly:budgetly_secret@mongodb:27017/budgetly?authSource=admin
      GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID}
      JWT_SECRET: ${JWT_SECRET}

volumes:
  mongo_data:
```

---

## 8. Compile-Time Model Generation (Swagger / OpenAPI)

The `openapi-generator-maven-plugin` in `pom.xml` generates Java DTOs from the OpenAPI YAML spec during `mvn compile`:

```xml
<plugin>
    <groupId>org.openapitools</groupId>
    <artifactId>openapi-generator-maven-plugin</artifactId>
    <version>7.2.0</version>
    <executions>
        <execution>
            <goals><goal>generate</goal></goals>
            <configuration>
                <inputSpec>${project.basedir}/src/main/resources/api/budgetly-openapi.yml</inputSpec>
                <generatorName>spring</generatorName>
                <apiPackage>com.budgetly.api.generated.controller</apiPackage>
                <modelPackage>com.budgetly.api.generated.model</modelPackage>
                <configOptions>
                    <interfaceOnly>true</interfaceOnly>
                    <useSpringBoot3>true</useSpringBoot3>
                    <useTags>true</useTags>
                </configOptions>
            </configuration>
        </execution>
    </executions>
</plugin>
```

Controllers implement the generated interfaces, ensuring compile-time contract adherence.

---

## 9. Design System (Flutter Theme)

Based on the Stitch screen designs:

| Token | Value |
|-------|-------|
| **Background** | Slate 950 `#020617` / Slate 900 `#0f172a` |
| **Card Surface** | Slate 800 `#1e293b` |
| **Surface Highlight** | Slate 700 `#334155` |
| **Primary** | Indigo 500 `#6366f1` |
| **Primary Dark** | Indigo 600 `#4f46e5` |
| **Accent Mint** | Emerald 400 `#34d399` / `#10b981` |
| **Accent Coral** | Rose 400 `#fb7185` / `#f43f5e` |
| **Text Main** | Slate 50 `#f8fafc` |
| **Text Muted** | Slate 400 `#94a3b8` |
| **Font Display** | IBM Plex Sans (700) |
| **Font Body** | Inter (400–700) |
| **Font Mono** | JetBrains Mono / Space Mono |
| **Border Radius (Cards)** | 16–20px (`rounded-2xl`) |
| **Border Radius (Buttons)** | Full (`rounded-full`) for pills |
| **Border Subtle** | `rgba(255, 255, 255, 0.06)` |
| **Default Currency** | INR (₹) |
| **Default Locale** | India (DD/MM/YYYY) |

---

## 10. Automated Testing Strategy (Mandatory — No Exceptions)

> [!CAUTION]
> **Tests are NOT optional. Every build MUST run tests. Builds FAIL if tests fail. No code is merged or deployed without 100% test pass rate.**

### 10.1 Testing Philosophy

- **Tests are part of the Definition of Done**: A feature is not done until its tests are written and passing.
- **Tests run on every build**: `flutter test` and `mvn verify` are gating steps in the build pipeline.
- **Test structure mirrors source**: Every file in `lib/` or `src/main/` has a corresponding test file.
- **No manual testing as a substitute**: Manual QA is supplemental, never a replacement for automated tests.

### 10.2 Flutter Test Pyramid

```
        ┌──────────────────┐
        │  Integration     │  flutter test integration_test/
        │  (Full Flows)    │  Login → Expense → Dashboard
        ├──────────────────┤
        │  Widget Tests    │  flutter test test/screens/
        │  (Each Screen)   │  Renders, interactions, navigation
        ├──────────────────┤
        │  Unit Tests      │  flutter test test/providers/
        │  (Providers,     │  flutter test test/models/
        │   Models,        │  flutter test test/data/
        │   Services)      │
        └──────────────────┘
```

| Test Type | What It Covers | Run Command | When |
|-----------|---------------|-------------|------|
| **Unit Tests** | Models (serialization, split calc), Providers (state transitions), Mock services (response handling) | `flutter test test/models/ test/providers/ test/data/` | Every build |
| **Widget Tests** | Screen rendering, user interactions, navigation, form validation | `flutter test test/screens/ test/widgets/` | Every build |
| **Integration Tests** | Full user flows end-to-end on emulator/device | `flutter test integration_test/` | Before release |

**Build gate command (must pass):**
```bash
flutter test --coverage
```

### 10.3 Flutter Test Details

| Area | Test File | What It Verifies |
|------|-----------|-------------------|
| **Models** | `test/models/transaction_test.dart` | JSON serialization/deserialization, split calculation (percent & share), validation |
| **Models** | `test/models/split_config_test.dart` | Percent splits sum to 100, share ratios calculate correct amounts |
| **Providers** | `test/providers/auth_provider_test.dart` | Login state transitions (logged out → loading → logged in), token storage |
| **Providers** | `test/providers/transaction_provider_test.dart` | CRUD operations update state correctly, filter/sort logic |
| **Providers** | `test/providers/budget_provider_test.dart` | Budget calculations, over-budget detection, category breakdowns |
| **Mock Services** | `test/data/mock/mock_transaction_service_test.dart` | Returns correct mock data, simulates error states |
| **Screens** | `test/screens/dashboard/dashboard_screen_test.dart` | Budget ring renders, stat cards show correct values, activity list loads |
| **Screens** | `test/screens/feed/transaction_feed_screen_test.dart` | Date grouping works, filter chips toggle, transaction tiles render |
| **Screens** | `test/screens/expense/add_expense_screen_test.dart` | Amount input, payer selector with N members, category selection, split config |
| **Screens** | `test/screens/messages/message_inbox_screen_test.dart` | Card rendering, confirm/edit/reject actions, progress bar updates |
| **Screens** | `test/screens/budget/monthly_budget_screen_test.dart` | Progress bars, over-budget highlighting, add category |
| **Widgets** | `test/widgets/budget_ring_test.dart` | Renders correct percentage, color changes at thresholds |
| **Widgets** | `test/widgets/split_config_widget_test.dart` | Percent mode sums to 100, share mode displays ratios correctly |
| **Integration** | `integration_test/auth_flow_test.dart` | Google Sign-In → Dashboard navigation |
| **Integration** | `integration_test/expense_flow_test.dart` | Add Expense → Transaction appears in Feed → Dashboard updates |

### 10.4 Spring Boot Test Pyramid

```
        ┌──────────────────┐
        │  Integration     │  mvn verify -P integration
        │  (Testcontainers │  Real MongoDB, full stack
        │   + MockMvc)     │
        ├──────────────────┤
        │  Unit Tests      │  mvn test
        │  (Controllers,   │  JUnit 5 + Mockito
        │   Services,      │  MockMvc for HTTP layer
        │   Security)      │
        └──────────────────┘
```

| Test Type | What It Covers | Run Command | When |
|-----------|---------------|-------------|------|
| **Controller Unit Tests** | HTTP status codes, request/response mapping, validation errors | `mvn test -Dtest="*ControllerTest"` | Every build |
| **Service Unit Tests** | Business logic, split calculations, SMS parsing | `mvn test -Dtest="*ServiceTest"` | Every build |
| **Security Tests** | JWT validation, expired tokens, unauthorized access, role checks | `mvn test -Dtest="*SecurityTest"` | Every build |
| **Repository Integration Tests** | MongoDB queries, pagination, indexing | `mvn verify -Dtest="*IT"` (Testcontainers) | Every build |
| **Contract Tests** | OpenAPI spec is valid and matches controllers | `swagger-cli validate` | Every build |

**Build gate command (must pass):**
```bash
mvn verify
```

### 10.5 Spring Boot Test Details

| Area | Test File | What It Verifies |
|------|-----------|-------------------|
| **Auth** | `AuthControllerTest.java` | Google token exchange, JWT issuance, invalid tokens rejected |
| **Auth** | `JwtTokenProviderTest.java` | Token generation, validation, expiry, refresh |
| **Auth** | `GoogleTokenVerifierTest.java` | Valid/invalid Google ID tokens, mock Google endpoint |
| **Family** | `FamilyGroupControllerTest.java` | CRUD operations, invite generation, member management |
| **Family** | `FamilyGroupServiceTest.java` | Business rules: max members, role validation, permissions |
| **Family** | `FamilyGroupRepositoryIT.java` | MongoDB queries, member lookup, cascade behavior |
| **Transaction** | `TransactionControllerTest.java` | Create, read, update, delete + pagination + filters |
| **Transaction** | `TransactionServiceTest.java` | Split calculations (percent sums to 100, share ratio math), validation |
| **Transaction** | `TransactionRepositoryIT.java` | Date-range queries, category filters, aggregation pipelines |
| **Message** | `MessageControllerTest.java` | Submit, confirm, reject, restore flows |
| **SMS** | `SmsParsingServiceTest.java` | Parse HDFC, SBI, ICICI SMS formats → structured transactions |
| **Dashboard** | `DashboardControllerTest.java` | Aggregation returns correct totals, per-category breakdowns |
| **Security** | Security tests | Unauthenticated requests return 401, wrong-family access returns 403 |

### 10.6 Build Pipeline (CI)

Whether running locally or in CI, the following commands are the **mandatory gates**:

```bash
# ── Flutter (MUST pass before any deploy/release) ──
cd budgetly_app
flutter analyze                    # Static analysis — 0 issues
flutter test --coverage            # All unit + widget tests — 0 failures
flutter test integration_test/     # Integration tests — 0 failures (CI emulator)

# ── Spring Boot (MUST pass before any deploy/release) ──
cd budgetly_api
mvn clean verify                   # Compile + unit tests + integration tests — 0 failures
swagger-cli validate src/main/resources/api/budgetly-openapi.yml  # Contract valid

# ── Docker (Health check) ──
docker-compose up -d
docker-compose ps                  # All services healthy
curl http://localhost:8080/actuator/health  # API returns {"status":"UP"}
```

### 10.7 Test Coverage Expectations

| Layer | Minimum Coverage | Enforcement |
|-------|-----------------|-------------|
| **Flutter Models** | 95%+ | `flutter test --coverage` + `lcov` report |
| **Flutter Providers** | 90%+ | All state transitions tested |
| **Flutter Screens** | 80%+ (widget tests) | Every screen has at least one widget test |
| **Spring Boot Services** | 90%+ | JaCoCo report via `mvn verify` |
| **Spring Boot Controllers** | 85%+ | Every endpoint has at least one MockMvc test |
| **Spring Boot Repositories** | 80%+ | Integration tests with Testcontainers |

### 10.8 Test Dependencies

**Flutter (`pubspec.yaml` dev_dependencies):**
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0          # Mock generation for services
  flutter_riverpod: ^2.0.0   # Provider testing utilities
  integration_test:
    sdk: flutter
```

**Spring Boot (`pom.xml` test dependencies):**
```xml
<!-- JUnit 5 (included with spring-boot-starter-test) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>

<!-- Testcontainers for MongoDB integration tests -->
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>mongodb</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>junit-jupiter</artifactId>
    <scope>test</scope>
</dependency>
```

---

## 11. Manual Verification (Supplemental — NOT a Substitute)

These are **in addition to** the automated tests above:

1. **Visual comparison:** Open each Flutter screen side-by-side with corresponding Stitch screenshot in `stitch_screens/`
2. **Swagger UI walkthrough:** Open `http://localhost:8080/swagger-ui.html` and execute every endpoint manually
3. **Full user flow:** Login → Create Family → Add Member → Add Expense → View Dashboard → Set Budget → View Feed
4. **Split testing:** Add expense with 3 members, verify percent and share splits calculate correctly on both UI and API
5. **Docker sanity check:** `docker-compose up -d` → verify all containers start and connect
