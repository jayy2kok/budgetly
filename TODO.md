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
- [ ] Push notifications for expense alerts (plan §4.4).
- [ ] Full multi-currency UI: transaction currency is INR-first; `CurrencyConversionService` exists but end-to-end currency selection/display is incomplete.
- [x] Flutter `integration_test/` flows — boot, auth, expense and SMS E2E flows in `app/integration_test/` (run: `flutter test integration_test -d <emulator>`, see `app/integration_test/README.md`). Standard CI stays on analyze + widget tests; the emulator job is documented for a KVM-capable runner.

### Documentation
- [ ] Backfill ADRs `0001` and `0002` (only `0003` and `0004` are present in `doc/adr/`).

## Recently Completed
- ✅ Flutter `integration_test/` E2E flows (issue #55): `app/integration_test/` boots the real widget tree with mocked services and covers boot/deep-link, sign-in → dashboard, add-expense → feed (+ validation), and SMS parse → auto-post — all green on `Pixel_9a_jayraj` (`+6`). Fonts (Inter, IBM Plex Sans, JetBrains Mono) are now bundled in `app/assets/google_fonts/`, removing runtime font fetching for offline use and hermetic tests.
- ✅ Message inbox redesign + pattern edit/disable: two-tab device-inbox mirror (Recorded Transactions / Non-Transactions with multiset `sourceRawText` matching), single `Define pattern` action per non-transaction message, no incomplete/confirm/ignored workflows, registry Edit + Disable/Enable with global copy-on-write (`derivedFromPatternId` + `hidden_patterns`), consistent date-only timestamp resolution, removal of the server message-triage endpoints and their residual client code.
- ✅ Pattern builder category override + fixed values (Merchant / Account / Bank name / Notes) and `accountLast4` + `bankName` on transactions: `fixedValues` in the contract + docs, fixed-wins resolution in the listener and local parser, reusable category picker, "A/C •••• 1234" and bank row on transaction detail. Also fixed family-first precedence in the on-device parser and on-demand category resolution for `REGEX_LOCAL` posts.
- ✅ Cached pattern registry viewer + custom pattern builder (issue #57): `GET /messages/failed`, `POST`/`PUT`/`DELETE /patterns`, `POST /patterns/{id}/promote`, family-scoped match precedence, Flutter registry/builder screens, docs sync.
- ✅ Java 25 / Spring Boot 4.1.2 upgrade (ADR-0004).
- ✅ Bulk insert + change-stream message consumer (ADR-0003), duplicate-processing race resolved (WORK-001).
- ✅ Anchor fast-path before LLM (WORK-002) — literal-anchor parity between Java and Dart.
- ✅ App migrated to bulk ingestion path (WORK-102).
- ✅ Standard docs created: `requirements.md`, `design.md`, `ERD.md`.
