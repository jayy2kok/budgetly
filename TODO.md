# Budgetly — TODO / Pending Work

> Living task list. Update status immediately on milestone completion (CLAUDE.md).
> Supersedes the deleted `plans/TODO-work-items.md`.

## Open

### Observability & Reliability
- [ ] **WORK-301** — Add a change-stream lag metric (`messages` PENDING backlog / resume-token age) to `/actuator/prometheus`.
- [ ] **WORK-302** — Resume-token integration test against a live MongoDB replica set, plus a 1k–10k msg/s ingestion load test.

### API Contract Hygiene (Contract-First)
- [ ] Regenerate the Flutter/Dart client SDK from `budgetly_api/src/main/resources/api/budgetly-openapi.yml` and switch `app/lib/data/remote/` to the generated client (today the Dio calls are hand-written). The stale root-level `api/budgetly-openapi.yml` was deleted (2026-11-22); `budgetly_api/src/main/resources/api/budgetly-openapi.yml` is the single source of truth.

### Release Engineering
- [ ] **APK signing for release builds** (`SIGN.1`–`SIGN.5`): generate keystore, wire `key.properties` + `signingConfigs.release`, store secrets, and make `release.yml` emit a signed `--release` APK (today it builds a debug APK).

### Features (deferred from development plan)
- [ ] **Manual FCM verification** — real device delivery via the `fcm` provider is untested: no Firebase project / `google-services.json` is configured. Backend + client flows are verified with the `log` provider and mocked transports (`DeviceE2ETest`, `ExpenseAlertE2ETest`, Flutter push tests); switching to real delivery is `push.provider=fcm` + service-account credentials + a `firebase_messaging` adapter. Steps: (1) create a Firebase project, (2) add `google-services.json` to `app/android/app/`, (3) add `firebase_messaging` and implement `PushMessagingService`, (4) set `PUSH_PROVIDER=fcm`, `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_FILE`, (5) sign in on two devices, create an expense, confirm the other device receives the alert and the tap opens `/transaction/{id}`.
- [ ] Full multi-currency UI: transaction currency is INR-first; `CurrencyConversionService` exists but end-to-end currency selection/display is incomplete.
- [ ] Flutter `integration_test/` flows — the `app/integration_test/` directory does not exist yet; app E2E is currently manual (emulator) + widget tests.

## Recently Completed
- ✅ API contract hygiene (issue #51): `PATCH /patterns/{id}/category` documented in the canonical OpenAPI spec (request `UpdatePatternCategoryRequest`, `200`/`403`/`404` responses) and served by `PatternRegistryController`/`PatternRegistryService`, with backend E2E coverage for the happy path, non-admin `403`, and unknown pattern `404`. The stale root-level `api/budgetly-openapi.yml` was deleted (2026-11-22) so the generator `inputSpec` (`budgetly_api/pom.xml`) and docs point only at `budgetly_api/src/main/resources/api/budgetly-openapi.yml`.
- ✅ Backfilled ADRs `0001` and `0002` (issue #56): raw Google OAuth 2.0 + custom JWT, and contract-first OpenAPI generation; `design.md` §8 decision log now lists ADRs 0001–0005.
- ✅ Push notifications for expense alerts (issue #53, plan §4.4): `POST /devices` + `DELETE /devices/{token}` registration/cleanup, provider-agnostic `PushNotificationService` (Logging / FCM HTTP v1, no new Maven deps — ADR-0005), `ExpenseAlertNotifier` fan-out on `EXPENSE` creation gated by `expenseAlertsEnabled`, Flutter `PushController` lifecycle + tap routing to `/transaction/{id}`, Settings toggle mirrors the family setting.
- ✅ Configurable backend base URL (Settings → Developer → Backend URL): persisted override applied to the shared Dio client and token-refresh client, normalization + validation, sign-out on change.
- ✅ Message inbox redesign + pattern edit/disable: two-tab device-inbox mirror (Recorded Transactions / Non-Transactions with multiset `sourceRawText` matching), single `Define pattern` action per non-transaction message, no incomplete/confirm/ignored workflows, registry Edit + Disable/Enable with global copy-on-write (`derivedFromPatternId` + `hidden_patterns`), consistent date-only timestamp resolution, removal of the server message-triage endpoints and their residual client code.
- ✅ Pattern builder category override + fixed values (Merchant / Account / Bank name / Notes) and `accountLast4` + `bankName` on transactions: `fixedValues` in the contract + docs, fixed-wins resolution in the listener and local parser, reusable category picker, "A/C •••• 1234" and bank row on transaction detail. Also fixed family-first precedence in the on-device parser and on-demand category resolution for `REGEX_LOCAL` posts.
- ✅ Cached pattern registry viewer + custom pattern builder (issue #57): `GET /messages/failed`, `POST`/`PUT`/`DELETE /patterns`, `POST /patterns/{id}/promote`, family-scoped match precedence, Flutter registry/builder screens, docs sync.
- ✅ Java 25 / Spring Boot 4.1.2 upgrade (ADR-0004).
- ✅ Bulk insert + change-stream message consumer (ADR-0003), duplicate-processing race resolved (WORK-001).
- ✅ Anchor fast-path before LLM (WORK-002) — literal-anchor parity between Java and Dart.
- ✅ App migrated to bulk ingestion path (WORK-102).
- ✅ Standard docs created: `requirements.md`, `design.md`, `ERD.md`.
