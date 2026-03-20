# Phase 4 — Integration & Polish: Implementation Plan

> **Goal:** Swap the Flutter mock data layer → real Dio HTTP client hitting the Spring Boot API.  
> Connect the full stack end-to-end: Flutter ↔ Spring Boot ↔ MongoDB.

---

## Overview

Phase 3 is complete: all 60 RestAssured E2E tests pass (Auth, Family, Category, Transaction, Message, Dashboard, Pattern, Security). The Flutter app runs with mock services. Phase 4 connects them.

---

## Tasks (Ordered by Dependency)

### 4.1 — API Client Foundation (Dio Setup)

| Item | Detail |
|------|--------|
| **File** | `lib/data/remote/api_client.dart` |
| **What** | Dio instance with base URL, JWT interceptor (adds `Authorization: Bearer` header), refresh-token retry interceptor, error mapping |
| **Config** | `lib/config/api_config.dart` — base URL (`http://10.0.2.2:8080/api/v1` for Android emulator, configurable) |
| **Dependencies** | `dio: ^5.x` already in pubspec or add it |

### 4.2 — Service Interface Abstraction

| Item | Detail |
|------|--------|
| **Files** | Create abstract service interfaces in `lib/data/` (e.g., `auth_service.dart`, `family_service.dart`, etc.) |
| **What** | Extract the method signatures from mock services into abstract classes. Mock and Remote implementations both implement the interface. |
| **Why** | Riverpod providers can swap between mock and remote by toggling a single flag |

### 4.3 — Remote Service Implementations

Create `lib/data/remote/` implementations for each service:

| # | File | Endpoints |
|---|------|-----------|
| 1 | `remote_auth_service.dart` | `POST /auth/google`, `POST /auth/refresh`, `GET /auth/me` |
| 2 | `remote_family_service.dart` | Family CRUD, invite, join, members |
| 3 | `remote_category_service.dart` | Category CRUD |
| 4 | `remote_transaction_service.dart` | Transaction CRUD, pagination, filters |
| 5 | `remote_message_service.dart` | Process, pending, ignored, confirm, reject, restore |
| 6 | `remote_budget_service.dart` | Dashboard, budget summary, update budget |
| 7 | `remote_pattern_service.dart` | Patterns sync, report, stats |

### 4.4 — Provider Wiring

| Item | Detail |
|------|--------|
| **What** | Update Riverpod providers to accept a service interface (injected). Add a `useRealApi` flag or environment-based toggle. |
| **Where** | `lib/providers/*.dart` |

### 4.5 — Auth Flow Integration

| Item | Detail |
|------|--------|
| **What** | Real Google Sign-In → send ID token to `POST /auth/google` → store JWT pair → use for all subsequent requests |
| **Where** | `lib/screens/auth/login_screen.dart`, `remote_auth_service.dart`, `auth_provider.dart` |
| **Package** | `google_sign_in` (already in pubspec) |

### 4.6 — UI Polish

| Item | Detail |
|------|--------|
| Loading states | Show shimmer/skeleton loaders while API calls are in-flight |
| Error states | Snackbar/dialog for network errors, 403, 404 |
| Empty states | "No transactions yet" / "No family members" illustrations |
| Animations | Hero transitions, page route animations, micro-interactions |
| Pull-to-refresh | On feed, dashboard, message screens |

### 4.7 — Docker Production Build

| Item | Detail |
|------|--------|
| **Dockerfile** | Multi-stage build: Maven build → slim JRE runtime |
| **docker-compose** | Already exists, verify it works end-to-end |
| **Health check** | `GET /actuator/health` |

### 4.8 — SMS Integration (Android)

| Item | Detail |
|------|--------|
| **What** | Real Android SMS permission request, background SMS reader, local regex cache sync via API |
| **Where** | `lib/services/sms_service.dart`, `sms_background_service.dart`, `regex_pattern_cache.dart` |

---

## Implementation Order

```
Step 1: api_client.dart (Dio setup + interceptors)
Step 2: Service interfaces (abstract classes)  
Step 3: Remote service implementations (one at a time)
Step 4: Provider wiring (swap mock → remote)
Step 5: Auth flow (Google Sign-In → JWT)
Step 6: Test each screen against real API
Step 7: UI polish (loading/error/empty states)
Step 8: Docker verification
Step 9: SMS integration
```

---

## Definition of Done

- [ ] All screens work against the real Spring Boot API (running in Docker)
- [ ] Google Sign-In → JWT flow works end-to-end
- [ ] `docker-compose up` → Flutter app connects and all flows work
- [ ] `mvn test` still passes (60 E2E tests green)
- [ ] `flutter test` passes
- [ ] Loading, error, and empty states implemented
