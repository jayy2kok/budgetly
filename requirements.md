# Budgetly — Requirements

> Family-oriented mobile budgeting app: track shared finances, auto-read and parse bank SMS (regex/literal-anchor first, server-side LLM fallback), plan monthly budgets by category, and manage family-group settings — backed by Gmail/Google sign-in.

## Actors & Roles

| Role | Capabilities |
|---|---|
| **Admin** (family creator) | Set budget, add/edit/delete categories, invite/remove members, leave/delete family |
| **Member** | View budget, add expenses, view own messages |

*(See `FamilyMemberDocument.role`: `ADMIN` | `MEMBER`; permissions enforced in `FamilyGroupService`.)*

## Functional Requirements

### FR1 — Authentication
- **FR1.1** Google sign-in: exchange Google ID token for an app JWT (`POST /auth/google`).
- **FR1.2** Refresh token rotation (`POST /auth/refresh`).
- **FR1.3** Current-user profile (`GET /auth/me`).
- **FR1.4** Startup validation: fail loudly if `GOOGLE_CLIENT_ID` is missing/placeholder (`GoogleAuthConfigValidator`).
- **FR1.5** All non-public endpoints require a valid JWT (`JwtAuthFilter`).

### FR2 — Family Groups
- **FR2.1** Create family (`POST /families`), get my family (`GET /families/my`), get/update/delete family.
- **FR2.2** Invite via code: generate invite (`POST /families/{id}/invite`), join by id (`POST /families/{id}/join`) or by code (`POST /families/join`).
- **FR2.3** Member management: list members, update role, remove member.
- **FR2.4** Non-members cannot access another family's data (cross-family isolation → `403`).

### FR3 — Categories
- **FR3.1** Per-family CRUD: list/create/update/delete categories (`/families/{fid}/categories`).
- **FR3.2** Category resolution for LLM parsing uses the family's configured categories, falling back to a built-in default list (`CategoryResolver`); unknown/`uncategorized` → "Uncategorized".

### FR4 — Transactions
- **FR4.1** CRUD with pagination + filters (`type`, date range, `categoryId`, `createdByUserId`, `page`, `size`, `sort`).
- **FR4.2** Types: `EXPENSE`, `INCOME`, `SUBSCRIPTION`.
- **FR4.3** Split methods: `PERSONAL`, `PERCENT`, `SHARE` (member→value map).
- **FR4.4** Source tracking: `MANUAL`, `REGEX_LOCAL`, `LLM_SERVER`.

### FR5 — SMS Parsing & Message Pipeline
- **FR5.1** On-device parsing: `SmsInboxReader` reads the inbox → `SmsParserService` literal-anchor matches cached `SmsPattern`s. Complete match auto-posts a transaction (`REGEX_LOCAL`); incomplete/unknown goes to the server.
- **FR5.2** Bulk ingestion: batched `POST /messages/bulk` (≤500/request, `202 Accepted`).
- **FR5.3** Async processing: `MessageChangeStreamListener` consumes `BULK + PENDING` inserts, atomically claims them (`IN_PROGRESS`), runs the anchor fast-path then LLM fallback, and transitions to `PROCESSED`/`FAILED`. Resume token persisted in `change_stream_tokens`.
- **FR5.4** Legacy `source=DIRECT` documents are historical only: they were completed when they were written and are never re-claimed by the listener. The synchronous `/messages/process` endpoint no longer exists.
- **FR5.5** Device-inbox mirror: the Flutter inbox reads **every** SMS from the phone (not a server message queue) and splits it into exactly two tabs — **Recorded Transactions** (an SMS whose body matches a recorded transaction) and **Non-Transactions** (everything else: OTP, promo, personal, and financial SMS not yet recorded). There is no incomplete, confirm/reject, or ignored workflow.
- **FR5.6** Non-financial classification: `OTP`, `PROMO`, `PERSONAL`, `DELIVERY`, `UNKNOWN`.
- **FR5.7** Timestamp completion: a body timestamp with a time wins outright; a date-only body keeps its date and borrows the SMS received time-of-day (falling back to `00:00:00`); a missing/unparseable body timestamp uses the received time; with neither, the current time. The date is the primary signal.

### FR6 — Pattern Registry
- **FR6.1** Full sync `GET /patterns` (with `?since=` delta sync) and sender list `GET /patterns/senders`.
- **FR6.2** Report a pattern (`POST /patterns/{id}/report`); auto-disable after `pattern.report-threshold` reports and move to `rejected_patterns`.
- **FR6.3** Stats `GET /patterns/stats`.
- **FR6.4** Override a pattern's resolved category (`PATCH /patterns/{id}/category`).
- **FR6.5** Browse the cached registry: active **global + caller-family** patterns (active and disabled) grouped by sender, showing template, sample, usage count, status (`Active` / `Disabled` / `Hidden for family`), scope (`GLOBAL`/`FAMILY`), and source (`LLM`/`USER`). Each row offers **Edit** and **Disable**/**Enable**; there is no "New pattern" button and no delete. Family scoping is enforced server-side, not just in the UI.
- **FR6.6** Author a pattern from any **non-transaction SMS** by highlighting spans and tagging them (Amount/Merchant/Date/Type/Account/Notes). The tagged spans derive the literal-anchor `template` and identity `extractionMap`; the token vocabulary is `{amount}` (required), `{merchant}`, `{timestamp}`, `{transactionType}`, `{accountLast4}`, `{notes}`. A client dry-run previews the match; the server re-validates the `(template, sampleMessage)` pair on save and rejects templates that extract no fields or no `amount`. Authored patterns are family-scoped. Family admins may promote a family pattern to `GLOBAL` once `usageCount` reaches `pattern.promote-usage-threshold`.
- **FR6.7** Match precedence: for a given sender, family-scoped active patterns are tried before global ones; within each scope the most recently updated pattern wins. Patterns the family has hidden are excluded.
- **FR6.8** Edit an existing pattern in place (`PUT /patterns/{id}`): family patterns update directly; editing a `GLOBAL` is copy-on-write — the server creates/updates a family-scoped copy (linked by `derivedFromPatternId`) and records a hide marker for the caller's family, leaving the global untouched for other families.
- **FR6.9** When authoring a pattern, optionally assign a **category** (persisted as `categoryName` and resolved per family at match time) and pin **fixed literal values** for Merchant, Account, Bank name, or Notes (persisted as `fixedValues`). A fixed value wins over the value extracted from the template; leaving the field empty uses the tagged/extracted value. `amount`, `timestamp`, and `type` cannot be pinned. Promotion to `GLOBAL` clears `fixedValues`.
- **FR6.10** Transactions record `accountLast4` and `bankName` end-to-end (creation request, document, API response, mobile model) and the detail screen shows "A/C •••• 1234" and the bank name.
- **FR6.11** Disable/enable without deletion: `POST /patterns/{id}/disable` upserts a hide marker for a `GLOBAL` (other families unaffected) or sets `active=false` for a `FAMILY` pattern; `POST /patterns/{id}/enable` reverses it. Re-enabling a family pattern that would collide with another active visible template is rejected (`409`).

### FR7 — Budget & Dashboard
- **FR7.1** Dashboard aggregation (`GET /families/{fid}/dashboard`).
- **FR7.2** Monthly budget summary with per-category breakdown (`GET /families/{fid}/budget/summary`).
- **FR7.3** Update monthly budget limit (`PUT /families/{fid}/budget`).

### FR8 — Mobile App (Flutter)
- **FR8.1** Bottom-nav shell with 4 tabs: Home (Dashboard), Feed, Budget, Settings.
- **FR8.2** Screens: Login, Dashboard, Transaction Feed, Add Expense, Transaction Detail, Message Inbox (Recorded Transactions / Non-Transactions), Pattern Registry, Pattern Builder (create from an SMS; edit an existing pattern), Monthly Budget, Settings, Link Family, Join Family, Family Settings, Profile.
- **FR8.3** SMS permission consent dialog + on-demand inbox sync (all device SMS mirrored into the two tabs) and pattern-cache sync UX.
- **FR8.4** Mock data layer (`data/mock`) for offline/dev and remote layer (`data/remote`, Dio) for the real API.

### FR9 — Push Notifications for Expense Alerts
- **FR9.1** Device-token registration: authenticated `POST /devices` upserts the caller's provider token (`token` + `platform`, optional `deviceId`); `DELETE /devices/{token}` removes it on sign-out (owner-only, idempotent). Tokens are stored per user in `device_tokens` and cleaned up on logout.
- **FR9.2** Provider-agnostic transport: `PushNotificationService` with a `log` provider (default — writes payloads to the log, used locally and in CI) and an `fcm` provider (Firebase Cloud Messaging HTTP v1). No new Maven dependency: the OAuth2 service-account JWT is minted and exchanged with the JDK HTTP client.
- **FR9.3** Trigger: creating an `EXPENSE` transaction fans an alert out to the **other active members'** registered devices when the family's `expenseAlertsEnabled` is `true` (manual `createTransaction` and the change-stream/listener path both notify). The actor is never notified, and delivery is best-effort — a failed send never fails transaction creation.
- **FR9.4** Payload: `title`/`body` for display plus a `data` payload (`type = EXPENSE_ALERT`, `transactionId`, `familyGroupId`) the client uses to route a tap to the transaction detail screen.
- **FR9.5** Client lifecycle: the app registers its push token after sign-in and removes it during sign-out (`PushController`); provider token rotation re-registers. Taps (background/terminated) navigate to `/transaction/{id}`; foreground messages surface as a snackbar. The no-op `PushMessagingService` ships by default; a real provider adapter plugs into the same interface.
- **FR9.6** Settings: the **Budget Alerts** toggle mirrors the family-wide `expenseAlertsEnabled` setting (admin-only server-side); the **Push Notifications** toggle stays a local preference.

## Non-Functional Requirements

| ID | Requirement |
|---|---|
| **NFR1** | **Stack**: Java 25, Spring Boot 4.1.2, Maven; Flutter 3.x / Dart 3.11; MongoDB 7. |
| **NFR2** | **Contract-first**: OpenAPI 3.0 spec (`budgetly_api/src/main/resources/api/budgetly-openapi.yml`) generates Spring interfaces + models at compile time; controllers implement them. |
| **NFR3** | **Async ingestion**: decoupled via MongoDB change streams (replica set), max batch size 500. |
| **NFR4** | **Security**: Google OAuth audience validation, JJWT (HMAC) access/refresh tokens, role checks, CORS config. |
| **NFR5** | **Observability**: Actuator (`health`, `info`, `metrics`, `prometheus`) + Prometheus registry. |
| **NFR6** | **Testing gate**: RestAssured E2E API tests + Flutter widget/provider/service tests must pass; E2E smoke tests are the release gate (see CLAUDE.md). |
| **NFR7** | **Currency**: INR default; multi-currency conversion via `CurrencyConversionService` (INR-base rates from `open.er-api.com`, 12h refresh). |
| **NFR8** | **Local verification**: Docker Compose (`mongo:7` replica set + API). |

## Out of Scope / Deferred
- Amount/category thresholds for alerts (alerts fire for every expense).
- In-app notification center / history.
- Release APK signing (see [TODO.md](TODO.md)).
- Full multi-currency UI (transaction currency remains INR-first).
- Change-stream lag metric + large-scale load testing.
