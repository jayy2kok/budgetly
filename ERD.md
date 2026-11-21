# Budgetly — Database Schema (ERD)

> **Database:** MongoDB 7.x (document store, run as a replica set `rs0` locally so change streams work).
> **Source of truth:** `budgetly_api/src/main/java/com/budgetly/api/document/*.java` (Spring Data MongoDB `@Document` classes).
> This document is maintained alongside every entity migration — see CLAUDE.md.

## Collections Overview

| Collection | Document class | Purpose |
|---|---|---|
| `users` | `UserDocument` | Authenticated Google users |
| `family_groups` | `FamilyGroupDocument` | Household / budget group |
| `family_members` | `FamilyMemberDocument` | Membership + role between user and family |
| `categories` | `CategoryDocument` | Per-family transaction categories |
| `transactions` | `TransactionDocument` | Expense / income / subscription records |
| `messages` | `MessageDocument` | Ingested SMS messages awaiting parsing/triage |
| `pattern_registry` | `SmsPatternDocument` | Learned literal-anchor templates per sender |
| `rejected_patterns` | `RejectedPatternDocument` | Templates reported/auto-disabled |
| `change_stream_tokens` | `ChangeStreamTokenDocument` | Change-stream resume token (idempotent restarts) |

MongoDB does not enforce foreign keys; relationships below are **logical** (string references to `_id` values).

## Entity-Relationship Diagram

```mermaid
erDiagram
    users ||--o{ family_members : "userId"
    family_groups ||--o{ family_members : "familyGroupId"
    family_groups ||--o{ categories : "familyGroupId"
    family_groups ||--o{ transactions : "familyGroupId"
    users ||--o{ transactions : "createdByUserId"
    categories ||--o{ transactions : "categoryId"
    users ||--o{ messages : "userId"
    family_groups ||--o{ messages : "familyGroupId"
    messages |o--o| transactions : "linkedTransactionId"
    pattern_registry ||--o{ messages : "matchedPatternId"
    pattern_registry ||--o{ transactions : "matchedPatternId"
    pattern_registry |o--o| rejected_patterns : "patternId"
```

## Collections

### `users`

```mermaid
erDiagram
    users {
        string id PK "_id"
        string googleId UK "unique index"
        string displayName
        string email UK "unique index"
        string avatarUrl
        datetime createdAt
    }
```

### `family_groups`

```mermaid
erDiagram
    family_groups {
        string id PK "_id"
        string name
        string avatarInitial
        string defaultCurrency "INR"
        string regionFormat "IN"
        boolean expenseAlertsEnabled
        double monthlyBudgetLimit
        string createdByUserId FK "→ users"
        string inviteCode "indexed"
        datetime inviteCodeExpiresAt
        datetime createdAt
    }
```

### `family_members`

```mermaid
erDiagram
    family_members {
        string id PK "_id"
        string userId FK "→ users"
        string familyGroupId FK "→ family_groups"
        string role "ADMIN | MEMBER"
        string status "ACTIVE | INVITED | REMOVED"
        datetime joinedAt
    }
```

- Unique compound index `(userId, familyGroupId)` — a user can appear in a family only once.

### `categories`

```mermaid
erDiagram
    categories {
        string id PK "_id"
        string familyGroupId FK "indexed → family_groups"
        string name
        string icon
        double budgetLimit
        string color
        int sortOrder
    }
```

### `transactions`

```mermaid
erDiagram
    transactions {
        string id PK "_id"
        string familyGroupId FK "indexed → family_groups"
        string createdByUserId FK "→ users"
        string categoryId FK "indexed → categories"
        double amount
        string currency "INR"
        string merchant
        string description
        string type "EXPENSE | INCOME | SUBSCRIPTION"
        string splitMethod "PERSONAL | PERCENT | SHARE"
        map splitConfig "memberId → percent/share (Map string double)"
        string sourceType "MANUAL | REGEX_LOCAL | LLM_SERVER"
        string sourceRawText
        string matchedPatternId FK "→ pattern_registry"
        string notes
        datetime transactionDate "indexed"
        datetime createdAt
    }
```

### `messages`

```mermaid
erDiagram
    messages {
        string id PK "_id"
        string messageId UK "UUID, indexed"
        string userId FK "indexed → users"
        string familyGroupId FK "indexed → family_groups"
        string sender
        string rawText
        string source "BULK | DIRECT — indexed"
        string status "PENDING|IN_PROGRESS|PROCESSED|FAILED|CONFIRMED|REJECTED|IGNORED — indexed"
        string parseSource "REGEX_LOCAL | LLM_SERVER | MANUAL"
        string nonFinancialCategory "OTP|PROMO|PERSONAL|DELIVERY|UNKNOWN (nullable)"
        string matchedPatternId FK "→ pattern_registry"
        map parsedTransactionData "embedded map"
        string linkedTransactionId FK "→ transactions"
        datetime createdAt
        datetime receivedAt
        datetime processingStartedAt
        datetime processedAt
        int retryCount
        string errorMessage
        string resumeToken
    }
```

- Compound indexes: `(status, createdAt)`, `(userId, status)`, `(familyGroupId, status)`.
- `source` discriminates the two ingestion routes (see ADR-0003): `BULK` docs are consumed by the change-stream listener; `DIRECT` docs are processed synchronously by `POST /messages/process`.

### `pattern_registry`

```mermaid
erDiagram
    pattern_registry {
        string id PK "_id"
        string sender "indexed, e.g. HDFCBK"
        string template "literal-anchor template with {tokens}"
        map extractionMap "token → transaction field (Map string string)"
        string sampleMessage
        string categoryName "user-overridden category"
        long usageCount
        string scope "GLOBAL | FAMILY (default GLOBAL)"
        string ownerFamilyGroupId FK "→ family_groups; null when GLOBAL"
        string createdByUserId FK "author; null for LLM-seeded globals"
        string source "LLM | USER (default LLM)"
        boolean active
        int reportCount
        datetime createdAt
        datetime updatedAt
    }
```

- Compound index `sender_scope_owner_active_idx` = `(sender, scope, ownerFamilyGroupId, active)`, used by the family-aware registry lookup.
- `scope`/`ownerFamilyGroupId` partition the library: global patterns are readable by every family; `FAMILY` patterns are visible only to the owning family.
- Precedence when matching an incoming SMS (`findActiveBySender(sender, familyGroupId)`): **family-scoped patterns first** (newest `updatedAt`), then globals (newest `updatedAt`).
- Authored (`source = USER`) family patterns are validated against their `sampleMessage` before insert/update, may be promoted to `GLOBAL` by a family admin once `usageCount` reaches `pattern.promote-usage-threshold`, and stay read-only after promotion.

### `rejected_patterns`

```mermaid
erDiagram
    rejected_patterns {
        string id PK "_id"
        string patternId FK "indexed → pattern_registry"
        string template "snapshot of rejected template"
        string sampleMessage
        array reportedByUserIds "list of user ids"
        int reportCount
        datetime rejectedAt
    }
```

### `change_stream_tokens`

```mermaid
erDiagram
    change_stream_tokens {
        string id PK "_id = 'message-processor'"
        string token "base64 resume token"
        datetime updatedAt
    }
```

## Notes

- **No separate JPA/SQL schema** — entities are MongoDB documents. There is no redundant mapping layer; controllers consume the generated OpenAPI models and map to/from documents in the service layer.
- The OpenAPI domain models (`api/budgetly-openapi.yml` / `budgetly_api/src/main/resources/api/budgetly-openapi.yml`) mirror these documents; see [design.md](design.md) for the mapping flow.
