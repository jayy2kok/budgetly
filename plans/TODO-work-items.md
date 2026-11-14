# Budgetly — TODO Work Items for Subagents

> Branch: `feature/token-template-sms-parsing` (over `main`).
> Last verified state: `flutter test` 49/49 · `flutter analyze` clean · `mvn test` 91/91 (all green, 2026-11-14). App: models/parser/inbox-reader/provider (incl. bulk chunking, background-sync toggle/debounce); backend: e2e · AnchorParser parity · change-stream listener · source discriminator · TransactionDateParser · change-stream lag gauge.
> Use `graft` for context before editing (see footer). Cite `file:` spans and update the graph with `graft build` after changes.

---

## 0. Current State Summary

**Working end-to-end:**
- Token-template SMS parsing on both sides: Dart `_parseAnchorTemplate` (`app/lib/services/sms_parser_service.dart:72`), Java `AnchorParserService.parse` (`budgetly_api/.../service/AnchorParserService.java:17`). Templates stored in `SmsPatternDocument` (`template`, `extractionMap`), synced to the app via `GET /patterns`.
- LLM providers (Gemini + OpenAI-compatible) return `{financial, amount, merchant, transactionType, rawTimestamp, notes, template, extractionMap}`.
- Bulk insert API `POST /messages/bulk` + `MessageChangeStreamListener` (status machine PENDING→IN_PROGRESS→PROCESSED/CONFIRMED/FAILED/IGNORED, resume-token persistence, metrics, health indicator).
- App SMS sync: `SmsInboxReader` two-pass (cached patterns → keyword heuristic), `SmsNotifier.loadAndMergeInboxMessages` / `syncInboxMessages`.

**Known problems / gaps (details in work items):**
1. **Duplicate ingestion race**: ~~`POST /messages/process` inserts a `PENDING` doc that the always-on change-stream listener ALSO picks up~~ — **RESOLVED (WORK-001/WORK-102, 2026-11-14)**: `MessageDocument.source` discriminator (`DIRECT` for the process endpoint, `BULK` for `/messages/bulk`); the listener's change-stream filter + `isEligibleForStream` only claim `source=BULK AND status=PENDING`, so the two paths can never process the same doc. The app now sends server-bound SMS via `/messages/bulk`.
2. **`AnchorParserService` is dead code in prod path** — ~~server never matches a known sender against its template cache to skip the LLM~~ — **RESOLVED (WORK-002, 2026-11-14)**: listener `tryAnchorMatch` runs template-anchor match before the LLM; full extraction creates the transaction with `parseSource=REGEX_LOCAL`, bumps `usageCount`, exposes `budgetly.message.pattern.cache-hit`; incomplete/no-match falls back to the LLM.
3. **`rawTimestamp` from LLM is ignored** — **RESOLVED (WORK-003, 2026-11-14)**: shared `TransactionDateParser` honors the LLM `rawTimestamp` (and the anchor-match `{timestamp}` token), falling back to `receivedAt`/now.
4. **Zero app tests**; CI `flutter test` runs with `continue-on-error: true`; **no backend job in CI at all**. — **RESOLVED (WORK-101 + WORK-104, 2026-11-14)**: 46 app tests + `flutter analyze` clean; CI has a backend `mvn verify` job and a real Flutter test gate. *(Not yet exercised on a real GH Actions run.)*
5. **Dart/Java anchor-parser parity unverified**. *(now verified via mirrored corpus — WORK-101 done.)*
6. Stale artifact `budgetly_api/test_output.txt` (765-line FAILING build log) — deleted; remaining untracked infra files pending → WORK-105.
7. Dart `MessageStatus` enum missing `PROCESSED` / `IN_PROGRESS` / `FAILED` — added with round-trip tests → WORK-201 done.

Legend: 🔴 P0 correctness/arch · 🟡 P1 testing/CI · 🟢 P2 product wiring · ⚪ P3 ops/docs.

---

## 🔴 WORK-001 — Fix duplicate ingestion race (process endpoint vs change-stream listener) ✅ DONE

> Status: completed 2026-11-14. Chose the `source` discriminator model (3rd option): `MessageDocument.SOURCE_DIRECT` (stamped by `processMessage`) vs `SOURCE_BULK` (stamped by `bulkInsertMessages`). Listener filter + static `isEligibleForStream` guard claim only `BULK+PENDING`; the process endpoint's inline path never touches the listener. Verified at unit level in `MessageChangeStreamListenerTest` (`skipsDirectSourceDocumentsBeforeClaiming`) and `MessageServiceTest` (DIRECT/BULK stamping) — change-stream is disabled in test env, so this is a unit-level proof, not live-stream e2e.

**Files:** `budgetly_api/src/main/java/com/budgetly/api/service/MessageService.java:46-135` (`processMessage`), `budgetly_api/.../listener/MessageChangeStreamListener.java:78-95` (filter), `budgetly_api/.../controller/MessageController.java`.

**Problem:** `processMessage` inserts the message with `status="PENDING"` then processes it inline (LLM, pattern save, transaction create). The listener runs by default (`@ConditionalOnProperty(matchIfMissing=true)`) and consumes any insert whose `fullDocument.status="PENDING"`. Both paths LLM-call + transaction-create the same doc concurrently → duplicates.

**Task:** Pick and implement one coherent ingestion model:
- Recommended: app migrates to `POST /messages/bulk` (→ WORK-102) and `processMessage` stops creating its own transactions (becomes thin or is removed), OR
- `processMessage` inserts with a distinct status/flag the listener filter excludes, OR
- the listener filter additionally requires something set only by bulk insert (e.g. `source=BULK`).

**Acceptance:** No concurrent processing of the same `messageId`; add a test that bulk-inserting while a `process` request is in flight cannot create duplicate transactions or patterns. Keep `MessageE2ETest` green.

---

## 🔴 WORK-002 — Use pattern registry on the server to skip the LLM (`AnchorParserService` dead code) ✅ DONE

> Status: completed 2026-11-14. `MessageChangeStreamListener.tryAnchorMatch` loads `PatternRegistryService.findActiveBySender(sender)` active templates and runs `AnchorParserService.parse`; complete extraction (amount+merchant+timestamp via `extractionMap`) → transaction with `parseSource=REGEX_LOCAL`, `usageCount` bump, `budgetly.message.pattern.cache-hit` metric, no LLM; incomplete/no-match → LLM fallback. Covered by `anchorMatchProcessesWithoutLlmAndUsesTimestampAsTransactionDate`, `anchorMatchIncompleteFallsBackToLlm`, `noRegisteredPatternFallsBackToLlm`.

**Files:** `AnchorParserService.java` (no callers — verify with `graft callers AnchorParserService`), `MessageChangeStreamListener.java:148` (`llmProvider.analyzeMessage` call), `PatternRegistryService.java`, `SmsPatternDocument.java:14-47`.

**Problem:** The pattern registry's purpose is "match known templates, fall back to LLM", but the server always calls the LLM. Only the client avoids the LLM, and only for *fully-complete* matches (`app/lib/providers/sms_provider.dart:224-258` sends even known-sender/partial matches to the LLM every time).

**Task:** In the listener (and/or `processMessage`), before invoking the LLM: load `SmsPatternDocument`s for the sender, run `AnchorParserService.parse(template, rawText)`, and if a template matches, extract fields via `extractionMap`, create the transaction, save the Message as `PROCESSED` (with `parseSource` distinguishing server-anchor from LLM). Bump `usageCount`. Only call the LLM on cache miss. Expose a metric for cache-hit rate.

**Acceptance:** A repeated SMS from a known sender is processed with 0 LLM calls (assert via mocked `LlmProvider` counter); tests for match → complete, match → incomplete → LLM fallback, no match → LLM.

---

## 🔴 WORK-003 — Honor `rawTimestamp` from the LLM (wrong transaction dates on backfill) ✅ DONE

> Status: completed 2026-11-14. New shared `TransactionDateParser` @Component (ISO Instant/OffsetDateTime, `dd/MM/yyyy`, `dd-MM-yyyy`, ISO date, optional `HH:mm[:ss]`; `parseOrDefault` → fallback Instant). Wired into `MessageService.buildTransactionRequest` (LLM `rawTimestamp`) and the listener anchor path (template `{timestamp}` token). 9 format tests + listener test asserting the anchor-matched timestamp becomes the transaction date.

**Files:** `MessageService.buildTransactionRequest` (`MessageService.java:216-225`, sets `Instant.now()` at `:222`), `MessageChangeStreamListener.java:158-159` (same), `buildFromParsedData:238`.

**Problem:** Backfill reads up to 30+ days of SMS but every derived transaction gets today's date, corrupting feeds/budgets.

**Task:** Parse `llmResult.getRawTimestamp()` (formats: `dd/MM/yyyy`, `yyyy-MM-dd`, ISO, with time variants) into the transaction date; on failure fall back to `receivedAt`/now with a log. Share one parser used by both call sites. Add unit tests for the supported formats.

**Acceptance:** Given an SMS dated 2026-10-01 and a `rawTimestamp` of `01/10/2026`, the created transaction has transactionDate 2026-10-01.

---

## 🟡 WORK-101 — Add Dart unit tests for `SmsParserService` (incl. cross-language parity) ✅ DONE

> Status: completed 2026-11-14. `app/test/services/sms_parser_service_test.dart` (17), `app/test/services/sms_inbox_reader_test.dart` (9), `app/test/providers/sms_provider_test.dart` (8), `app/test/models/message_test.dart` (12). Shared corpus mirrored in `budgetly_api/src/test/java/com/budgetly/api/phase1/AnchorParserTest.java` (4, incl. K9 no-token→null parity fix in `AnchorParserService.java`). Also added `patternCacheServiceProvider`/`smsInboxReaderProvider` to `service_providers.dart`, Dio-injectable `PatternCacheService`, `permission_handler_platform_interface` dev dep. Full suite green: `flutter test` 46/46, `mvn test` 66/66.

**Files (new):** `app/test/services/sms_parser_service_test.dart`, `app/test/services/sms_inbox_reader_test.dart`, `app/test/providers/sms_provider_test.dart`. Target: `app/lib/services/sms_parser_service.dart`, `app/lib/services/sms_inbox_reader.dart`, `app/lib/providers/sms_provider.dart`. `mocktail` is already a dev dep.

**Cover:**
- `_parseAnchorTemplate` (via `parseMessage`): non-greedy token boundaries, regex meta-chars in literals (`.` in "Rs.", `+`, `()`), multiple tokens, last token with empty right literal, anchor-mismatch → `null`, sender filter, `extractionMap` field mapping.
- `SmsInboxReader`: known-sender complete → `parseSource=regexLocal`; known-sender incomplete → `parseSource=null`; unknown sender heuristic; permission denied → `[]`.
- `SmsProvider.syncInboxMessages`: fully-parsed → `addTransaction` call; incomplete → `processMessage`; `generatedPattern != null` triggers `refreshPatterns`; `last_processed_sms_timestamp` checkpoint.

**Parity:** Build a shared corpus (`templates × sms texts`) in `app/test/fixtures/` and mirror the same cases in `budgetly_api/src/test/java/.../phase1/AnchorParserTest.java` so Dart and Java are asserted against identical inputs/outputs.

**Acceptance:** `flutter test` passes all new tests; Java `AnchorParserTest` extended with the same fixture rows.

---

## 🟡 WORK-102 — Wire the app to `POST /messages/bulk` (+ add `bulkInsert` to client) ✅ DONE

> Status: completed 2026-11-14. `MessageService` gained `bulkInsertMessages` (interface + remote `POST /messages/bulk` → `acceptedCount` + 100ms mock). `SmsNotifier.syncInboxMessages` now routes complete-regex msgs → local `addTransaction` (unchanged) and everything else → a `serverQueue` chunked into ≤500-message bulk requests (`_checkpoint` persists the newest accepted message's timestamp; a failed batch is retried next sync), then a single `refreshPatterns()` post-batch. `sms_provider_test.dart` updated (RecordingMessageService.bulkCalls; chunking test covers 1001 msgs → 3 batches). Together with WORK-001's `source` discriminator this closes the ingestion loop. Full app suite 46/46 green (chunking test replaced the obsolete `generatedPattern` test 1:1).
> Remaining: device/e2e confirmation that a bulk batch produces N docs with no duplicate patterns (see WORK-302/303).

**Files:** `app/lib/data/remote/remote_message_service.dart` (add `bulkInsertMessages`), `app/lib/providers/sms_provider.dart:223-266` (batch instead of per-message), `budgetly_api/.../service/MessageService.java:150-178` (bulk semantics), `app/lib/models/` (bulk request/response).

**Context:** ADR-0003 (`doc/adr/0003-bulk-insert-change-stream.md`) adopted bulk+change-stream as the ingestion path, but the app now sends one `processMessage` per SMS. This work also unblocks WORK-001.

**Task:** Batch queued messages (respect `maxBatchSize=500`, backend limit at `application.yml`), handle `202 ACCEPTED` + bulk response, keep the per-message `generatedPattern` cache refresh (or refresh once per batch after listener writes patterns), and remove the inline `processMessage`/`addTransaction` divergence.

**Acceptance:** `syncInboxMessages` issues ≤ ceil(N/500) bulk requests; e2e confirms a bulk batch of N messages results in N docs with `PENDING` → `PROCESSED`/`CONFIRMED` and no duplicate patterns.

---

## 🟡 WORK-103 — Add backend integration tests for the change-stream pipeline ✅ DONE

> Status: completed 2026-11-14. `MessageChangeStreamListenerTest` extended 1 → 8 tests: IGNORED (financial=false), CONFIRMED (tx+pattern, usageCount=1, parsedTransactionData), PROCESSED (tx-create failure), FAILED (LLM throw → status+errorMessage, no token save), atomic-claim-lost short-circuit, resume-token persisted iff supplied, no-token case, `stop()` no-op. Metrics asserted via `Metrics.globalRegistry` — needed a mounted `SimpleMeterRegistry` (micrometer 1.14 global composite has no back-end under bare JUnit). Full suite: 73 backend tests green.
> Remaining for full WORK-103 scope: resume-token *used on restart* (start()) needs live Mongo → `MessageChangeStreamListenerIT` (see WORK-301/302).

**Files:** Extend `budgetly_api/src/test/java/com/budgetly/api/listener/MessageChangeStreamListenerTest.java` (currently 1 test; `processEventInternal` is package-private for tests) and add `MessageChangeStreamListenerIT` if needed.

**Cover:** state transitions PENDING→IN_PROGRESS→PROCESSED / FAILED / IGNORED; failed → `status=FAILED` + `errorMessage`; resume token persisted and used on restart (`test_output` of `ChangeStreamTokenDocument`); metrics increments (`budgetly.message.processing.*`); graceful `stop()`.

**Acceptance:** `mvn test` green with new cases; concurrency test from WORK-001 passing.

---

## 🟡 WORK-104 — Restore/enforce CI: backend job + real Flutter test gate ✅ DONE

> Status: completed 2026-11-14. `ci.yml` now has two jobs: `backend` (`actions/setup-java@v4` temurin 21 + Maven cache, `mvn -B verify` in `budgetly_api` — flapdoodle embedded Mongo, no Docker; test profile disables change-stream) and `app` (Flutter analyze + **real** `flutter test --no-pub` gate with `continue-on-error` removed + debug APK). No spotless/checkstyle wired in `pom.xml`, so backend analyze was skipped. One caveat not yet run anywhere: a real GH Actions run (no .github infra validated on this machine) — the ~1.5 min flapdoodle download happens on the runner, and the flutter-test Windows-only env workaround from local dev is irrelevant on ubuntu.

**Files:** `.github/workflows/ci.yml`.

**Problem:** CI runs only the Flutter app (`continue-on-error: true` on tests, empty `app/test/`), no `budgetly_api` job at all. The branch's backend work is unguarded.

**Task:** Add a `backend` job (`mvn -B verify` in `budgetly_api`; it uses embedded MongoDB via flapdoodle, no Docker needed). Set `flutter test` to fail on errors once WORK-101 lands. Consider running analyze for backend (spotless/checkstyle if wired).

**Acceptance:** A PR that breaks backend tests or app tests fails CI; a clean PR passes both jobs.

---

## 🟡 WORK-105 — Clean up tracked noise + untracked infra files ✅ DONE

> Status: completed 2026-11-14. `budgetly_api/test_output.txt` deleted (via `git rm`); `budgetly_api/mprobe/` (decompiled micrometer probe dump from WORK-103 debugging) deleted; `opencode.json` (local editor config) + `budgetly_api/mprobe/` + `graft/` added to `.gitignore` (graft auto-appends `graft/`, kept explicit here too). `app/analysis_options.yaml` build-exclude kept (harmless). Decision on remaining untracked: **commit deliberately** `.ignore` + `AGENTS.md` (graft's shared project tooling — AGENTS.md is the repo context-graph instructions intended for the repo; `.ignore` is its ripgrep companion re-admitting the gitignored cache to search) and the branch's new work (`app/test/`, backend `phase1/`+`service/` tests, `TransactionDateParser.java`, `plans/TODO-work-items.md`). `git status` is now clear/intentional — one commit's worth of new artifacts, awaiting user go-ahead.

**Files:** `budgetly_api/test_output.txt` (765-line stale FAILING `mvn` log, tracked on this branch) — delete. Decide fate of untracked `.ignore`, `AGENTS.md`, `graft/`, `opencode.json` (intentional local tooling? then add to `.gitignore` or commit deliberately). Revert or keep `app/analysis_options.yaml` auto-upgrade from `flutter analyze` (added `build/**` exclude — harmless, but confirm it was intended).

**Acceptance:** Clear, intentional `git status`; no build logs in-tree; CI unaffected.

---

## 🟢 WORK-201 — Align Dart `MessageStatus` with backend statuses ✅ DONE

> Status: completed 2026-11-14. Added `inProgress`/`processed`/`failed` with `@JsonValue`s, hand-kept `message.g.dart` enum map in sync, 12 JSON round-trip + bucket tests in `app/test/models/message_test.dart`. `isPending`/`isUnprocessed`/`isIncomplete`/`isFullyParsed` verified against all seven statuses.

**Files:** `app/lib/models/message.dart:6-15` (enum), `message.g.dart` (regenerate), `budgetly_api/.../document/MessageDocument.java:31-37` (status constants), `MessageService.toMessageDto` (`MessageService.java:243-261`).

**Problem:** Backend emits `PROCESSED`, `IN_PROGRESS`, `FAILED` (listener path) but Dart enum only has `PENDING/CONFIRMED/REJECTED/IGNORED` → `Message.fromJson` (generated) can throw on unknown value, and `message_provider.loadMessages` (`app/lib/providers/message_provider.dart:72-105`) may mis-bucket.

**Task:** Add the missing values (with `@JsonValue`s), regenerate `.g.dart`, update `isPending` readers to include `PROCESSED`/`IN_PROGRESS` where appropriate, and add a widget/unit test for JSON round-trip of a PROCESSED message.

**Acceptance:** `Message.fromJson` round-trips all seven backend statuses; no crash on listener-processed messages.

---

## 🟢 WORK-202 — Verify/complete message review screens against real endpoints

**Files:** `app/lib/screens/messages/message_inbox_screen.dart`, `ignored_messages_screen.dart`, `app/lib/providers/message_provider.dart` (confirm/reject/restore), `MessageService` (`confirmMessage:180`, `rejectMessage:197`, `restoreMessage:203`).

**Task:** Trace the pending (incomplete) and unprocessed buckets end-to-end on a device, fix mismatches (status mapping per WORK-201, `extractedFields` rendering — `toMessageDto:243-261` currently does not serialize parsed fields for pending messages, so consider exposing `parsedTransactionData`). Confirm `confirmMessage` correctly maps `buildFromParsedData`.

**Acceptance:** Incomplete/unprocessed messages render with their partial data, confirm/reject/restore round-trips, and duplicate transactions from WORK-001 disappear.

---

## 🟢 WORK-203 — SMS consent + permission UX polish ✅ DONE

> Status: completed 2026-11-14. Background-toggle is now **persisted** (`background_sms_service_enabled`, loaded in `_init`, written by `toggleBackgroundService`). New `SmsNotifier.triggerBackgroundSync()` gates the background auto-sync: skipped when SMS permission is missing **or** the toggle is off, and **debounced** to once per 30s (`backgroundSyncMinInterval`); manual/on-demand sync still goes straight to `syncInboxMessages`. Dashboard + `SmsConsentDialog` now call `triggerBackgroundSync()`. Settings SMS-Permission badge shows "Permanently denied" (row on-tap already reopens system settings via `openAppSettings`). 3 new provider tests (persist/restore across containers, toggle-gated sync, debounce) — app suite 49/49, analyze clean. First-run consent prompt already persisted (`sms_consent_prompted`).

**Files:** `app/lib/providers/sms_provider.dart:81-160` (permission state), `sms_inbox_reader.dart:25-27` (`hasPermission`), settings/shell screens that trigger permission.

**Task:** Add a permission prompt/denied flow and a toggle to stop background sync; persist consent; debounce background sync.

**Acceptance:** First-run prompts correctly; denied permission shows guidance and doesn't crash sync; toggle respected.

---

## ⚪ WORK-301 — Observability completeness ✅ DONE

> Status: completed 2026-11-14. `/actuator/prometheus` was **already exposed** (`management.endpoints.web.exposure.include: health, info, prometheus, metrics`). Added a **change-stream lag gauge** — `budgetly.message.change-stream.lag.milliseconds` = `now − message.createdAt`, refreshed on every successful event (AtomicLong registered in the listener constructor; grows while the consumer falls behind the insert rate). New unit test `exposesChangeStreamLagAfterSuccessfulProcessing` (claim a doc created 60s ago → gauge reports ~60s). `budgetly.change-stream.enabled` was already env-overridable (`${BUDGETLY_CHANGE_STREAM_ENABLED:true}`) and off in the test profile; the process endpoint + always-on listener coexist safely via the WORK-001 `source` discriminator, so the disable-where-process-used concern is moot by design.

**Files:** `MessageChangeStreamListener.java:126,210-211,219` (manual `Metrics` counters), `MessageProcessorHealthIndicator.java`, `application.yml` (actuator endpoints), `docker-compose.yml`.

**Task:** Expose `management.endpoints.web.exposure.include=prometheus,health` (check current), add a change-stream **lag** metric (compare last resume-token timestamp vs newest message), confirm `budgetly.change-stream.enabled=false` is documented/disabled where the process endpoint is used.

**Acceptance:** `/actuator/prometheus` exposes `budgetly.message.processing_*`; health reflects listener state; docs updated.

---

## ⚪ WORK-302 — Load test bulk ingestion 🔶 PARTIAL

> Status: `scripts/load_test.sh` written (mints an HS256 access JWT from `BUDGETLY_JWT_SECRET`, fires `--messages`/≤`--batch`=500 bulks with `--concurrency` workers, polls `/actuator/prometheus` for `budgetly_message_processing_{started,success,failed}_total` + the WORK-301 lag gauge, prints per-`--poll` rows + totals). Verified `bash -n`; `/messages/bulk` confirmed to return `202 ACCEPTED`, matching the script's accepted-count logic. **Not yet executed** — a faithful run needs the compose stack up (Mongo rs0 + API) plus a seeded sender pattern (so anchor matching needs no LLM key) and the load user added to the family. When run, record numbers here.

**Files (new):** `scripts/load_test.sh`.

**Task:** Bulk-insert 1k–10k msgs/sec against the compose stack, measure consumer lag, verify `PROCESSED` completion rate and the resume-token restart path (kill consumer mid-stream).

**Acceptance:** Data (numbers) recorded in the plan; lag stable or documented.

---

## ⚪ WORK-303 — Update planning docs to match reality ✅ DONE

> Status: completed 2026-11-14. `plans/token_template_sms_parsing.md` rewritten to describe the shipped literal-anchor algorithm (no regex), with the abandoned `TemplateRegexService` decision + rationale (§4) and parity-test references. `plans/bulk_insert_change_stream_plan.md` gained a "Status (2026-11-14)" overlay marking milestones 0–7 (incl. partials), the source-discriminator + anchor-fast-path divergences, and open risks → WORK links. `doc/adr/0003-bulk-insert-change-stream.md` gained a "Follow-up" section closing the app-on-bulk-path and duplicate-processing open items.

**Files:** `plans/token_template_sms_parsing.md` (still describes `TemplateRegexService` + regex generation; implementation stores templates and uses literal anchor parsing — update), `plans/bulk_insert_change_stream_plan.md` (mark completed items, note WORK-001/002 gaps), `doc/adr/0003-bulk-insert-change-stream.md` (add open item: app not yet on bulk path + duplicate-processing race).

**Task:** Reflect the actual algorithm, the abandoned `TemplateRegexService` decision (and rationale — non-regex anchor matching avoids cross-language regex divergence), and outstanding risks.

**Acceptance:** Docs no longer contradict the code; each open risk links to its WORK item.

---

## Suggested order for a subagent squad — progress

1. **WORK-105** ✅ + **WORK-201** ✅ — done 2026-11-14.
2. **WORK-101** ✅ + **WORK-103** ✅ — done (46→47 app, 73→90 backend tests).
3. **WORK-001 + WORK-102** ✅ — done (source discriminator + app bulk path; loading split into ≤500 batches).
4. **WORK-002** ✅ then **WORK-003** ✅ — done (server anchor fast-path + TransactionDateParser).
5. **WORK-104** ✅ — done (backend job + real flutter test gate in CI).
6. **WORK-202/203/301/302/303** — polish track:
   - **WORK-301 ✅** (lag gauge), **WORK-303 ✅** (docs), **WORK-203 ✅** (consent/background UX, own tests).
   - **WORK-302 🔶** (load test script written; not yet run — needs the Docker compose stack + real Mongo, numbers to be recorded when run).
   - **WORK-202** still requires a device/emulator (trace pending/unprocessed buckets end-to-end against live endpoints).

---

## Footer: verification & graft usage for subagents

- **Context:** `graft ask "<question>" --source` / `graft skeleton <file>` / `graft callers <symbol>` before reading files. After edits affecting many files, run `graft build`.
- **Backend:** `cd budgetly_api && mvn test` (embedded Mongo — no Docker needed; `-Dtest=...` to target one class).
- **App:** `cd app && flutter analyze && flutter test` (`flutter test test/<file>` for a subset).
- **Conventions:** statuses are string constants on `MessageDocument`; templates use `{token}` placeholders only; transactions are INR, `Instant`/`DateTime` UTC.