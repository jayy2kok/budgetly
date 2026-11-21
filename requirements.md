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
- **FR5.4** Synchronous legacy path: `POST /messages/process` (stamps `DIRECT`), never claimed by the listener.
- **FR5.5** Message triage: pending list, ignored list, confirm/reject/restore.
- **FR5.6** Non-financial classification: `OTP`, `PROMO`, `PERSONAL`, `DELIVERY`, `UNKNOWN`.

### FR6 — Pattern Registry
- **FR6.1** Full sync `GET /patterns` (with `?since=` delta sync) and sender list `GET /patterns/senders`.
- **FR6.2** Report a pattern (`POST /patterns/{id}/report`); auto-disable after `pattern.report-threshold` reports and move to `rejected_patterns`.
- **FR6.3** Stats `GET /patterns/stats`.
- **FR6.4** Override a pattern's resolved category (`PATCH /patterns/{id}/category`).
- **FR6.5** Browse the cached registry: active **global + caller-family** patterns grouped by sender, showing template, sample, usage count, active state, scope (`GLOBAL`/`FAMILY`), and source (`LLM`/`USER`). Family scoping is enforced server-side, not just in the UI.
- **FR6.6** Author a pattern from a failed or ignored SMS by **highlighting spans and tagging** them (Amount/Merchant/Date/Type/Account/Notes). The tagged spans derive the literal-anchor `template` and identity `extractionMap`; the token vocabulary is `{amount}` (required), `{merchant}`, `{timestamp}`, `{transactionType}`, `{accountLast4}`, `{notes}`. A client dry-run previews the match; the server re-validates the `(template, sampleMessage)` pair on save and rejects templates that extract no fields or no `amount`. Authored patterns are family-scoped and editable/deletable only by their author. Family admins may promote a family pattern to `GLOBAL` once `usageCount` reaches `pattern.promote-usage-threshold`.
- **FR6.7** Match precedence: for a given sender, family-scoped active patterns are tried before global ones; within each scope the most recently updated pattern wins.
- **FR6.8** Failed-message listing (`GET /messages/failed`, paginated) exposing FAILED messages with their `errorMessage` so they can be recovered via the builder.

### FR7 — Budget & Dashboard
- **FR7.1** Dashboard aggregation (`GET /families/{fid}/dashboard`).
- **FR7.2** Monthly budget summary with per-category breakdown (`GET /families/{fid}/budget/summary`).
- **FR7.3** Update monthly budget limit (`PUT /families/{fid}/budget`).

### FR8 — Mobile App (Flutter)
- **FR8.1** Bottom-nav shell with 4 tabs: Home (Dashboard), Feed, Budget, Settings.
- **FR8.2** Screens: Login, Dashboard, Transaction Feed, Add Expense, Transaction Detail, Message Inbox (Incomplete/Unprocessed/Failed), Ignored Messages, Pattern Registry, Pattern Builder, Monthly Budget, Settings, Link Family, Join Family, Family Settings, Profile.
- **FR8.3** SMS permission consent dialog + on-demand inbox sync and pattern-cache sync UX.
- **FR8.4** Mock data layer (`data/mock`) for offline/dev and remote layer (`data/remote`, Dio) for the real API.

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
- Push notifications for expense alerts.
- Release APK signing (see [TODO.md](TODO.md)).
- Full multi-currency UI (transaction currency remains INR-first).
- Change-stream lag metric + large-scale load testing.
