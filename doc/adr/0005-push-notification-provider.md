# ADR 0005: Provider-Agnostic Push Notifications (Logging / FCM HTTP v1)

## Status
Accepted

## Context
Issue #53 (plan §4.4) requires push notifications when an expense is created, so other family members see an alert on their devices. Two constraints shape the choice:

- The project has **no Firebase project** (no `google-services.json`, no `firebase_messaging` wiring) and we did not want to require one to keep the rest of the backend + client tests green in CI and locally.
- CLAUDE.md mandates the smallest working change and no premature abstraction, while still delivering a real, usable mechanism (not just stubs).

The Flutter client also needs to receive and route notifications without being locked to a single vendor, and the backend must remain a plain Spring Boot service with no heavy push SDK on the critical path of transaction creation.

## Decision

1. **Provider-agnostic transport interface**
   - `PushNotificationService` (backend) with `send(List<String> tokens, PushMessage message)`.
   - Two implementations selected by `push.provider`:
     - `LoggingPushNotificationService` (`log`, **default**, `matchIfMissing`) — writes the payload to the log. Used locally and in CI; lets the full registration → alert → "delivery" flow be exercised end-to-end without external credentials.
     - `FcmPushNotificationService` (`fcm`) — Firebase Cloud Messaging **HTTP v1**.

2. **FCM over plain JDK (no new Maven dependency)**
   - The FCM adapter mints a service-account JWT (`SHA256withRSA`), exchanges it at the OAuth2 token endpoint, then `POST`s to `messages:send` using the JDK `HttpClient`.
   - This avoids adding `firebase-admin-sdk` / Google client libraries and keeps the dependency surface unchanged.

3. **Client-side abstraction**
   - `PushMessagingService` (Dart) exposes `getToken()`, `onTokenRefresh`, `onMessageOpened`, `onForegroundMessage`.
   - Default implementation is a **no-op** so the app runs without a Firebase project; a real adapter (e.g. `firebase_messaging`) plugs into the same interface.
   - `PushController` (Riverpod) registers the token on sign-in, removes it on sign-out, and re-registers on token rotation.

4. **Delivery is best-effort**
   - `ExpenseAlertNotifier.onTransactionCreated` fans out to **other active members'** devices when the family's `expenseAlertsEnabled` is `true` and the transaction is an `EXPENSE`.
   - Send failures are swallowed and logged; transaction creation never fails because a push failed.

## Consequences
- The feature ships and is testable end-to-end today with the `log` provider; switching to real delivery is a config change (`push.provider=fcm` + service-account credentials).
- No new backend dependencies; no Firebase requirement for local development or CI.
- Real FCM delivery and the manual-verification acceptance step remain **blocked** until a Firebase project + `google-services.json` (or a `firebase_messaging` adapter) is provided. This is tracked in `TODO.md`.
- The `data` payload (`type=EXPENSE_ALERT`, `transactionId`, `familyGroupId`) is the stable client contract for tap routing; the display `title`/`body` may change without breaking navigation.