# Budgetly — TODO / Pending Work

> Living task list. Update status immediately on milestone completion (CLAUDE.md).
> Supersedes the deleted `plans/TODO-work-items.md`.

## Open

### Observability & Reliability
- [ ] **WORK-301** — Add a change-stream lag metric (`messages` PENDING backlog / resume-token age) to `/actuator/prometheus`.
- [ ] **WORK-302** — Resume-token integration test against a live MongoDB replica set, plus a 1k–10k msg/s ingestion load test.

### API Contract Hygiene (Contract-First)
- [ ] Add `PATCH /patterns/{id}/category` to the canonical OpenAPI spec — it is implemented in `PatternRegistryController` but missing from `budgetly_api/src/main/resources/api/budgetly-openapi.yml`.
- [ ] Reconcile the two OpenAPI files: root `api/budgetly-openapi.yml` (stale) vs `budgetly_api/src/main/resources/api/budgetly-openapi.yml` (canonical, used by the generator). Keep one source of truth.

### Release Engineering
- [ ] **APK signing for release builds** (`SIGN.1`–`SIGN.5`): generate keystore, wire `key.properties` + `signingConfigs.release`, store secrets, and make `release.yml` emit a signed `--release` APK (today it builds a debug APK).

### Features (deferred from development plan)
- [ ] Push notifications for expense alerts (plan §4.4).
- [ ] Full multi-currency UI: transaction currency is INR-first; `CurrencyConversionService` exists but end-to-end currency selection/display is incomplete.
- [ ] Flutter `integration_test/` flows — the `app/integration_test/` directory does not exist yet; app E2E is currently manual (emulator) + widget tests.

### Documentation
- [ ] Backfill ADRs `0001` and `0002` (only `0003` and `0004` are present in `doc/adr/`).

## Recently Completed
- ✅ Java 25 / Spring Boot 4.1.2 upgrade (ADR-0004).
- ✅ Bulk insert + change-stream message consumer (ADR-0003), duplicate-processing race resolved (WORK-001).
- ✅ Anchor fast-path before LLM (WORK-002) — literal-anchor parity between Java and Dart.
- ✅ App migrated to bulk ingestion path (WORK-102).
- ✅ Standard docs created: `requirements.md`, `design.md`, `ERD.md`.
