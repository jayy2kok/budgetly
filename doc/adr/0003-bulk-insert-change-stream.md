# ADR: Bulk Insert and Change Stream Consumer for Message Ingestion

## Status
Accepted

## Context
High volume of incoming SMS messages requires decoupling of ingestion and processing. Currently, the application processes messages synchronously, leading to potential latency and thread pool exhaustion during spikes.

## Decision
1. Introduce a bulk-insert API endpoint `/messages/bulk` to front-end ingestion.
2. Store raw messages with status `PENDING` in MongoDB.
3. Utilize MongoDB Change Streams on the `messages` collection to detect `PENDING` messages.
4. Implement an asynchronous consumer (`MessageChangeStreamListener`) that consumes these events, performs atomic status transitions to `IN_PROGRESS`, executes LLM analysis, and transitions to `PROCESSED` or `FAILED`.
5. Persistence of resume tokens in a dedicated collection `change_stream_tokens` ensures idempotent processing across service restarts.

## Trade-offs
- **Complexity**: Introduction of change stream brings operational overhead and complexity in monitoring.
- **Duplicate Processing**: With multiple consumer instances, there's a risk of duplicate processing; however, atomic `findAndModify` and status checks should mitigate this during startup.

## Consequences
- Improved ingestion latency.
- Better resilience under load.
- Enhanced scalability.
- Increased operational monitoring requirements (observability of change stream lag).

---

## Follow-up (2026-11-14)

Two open items in the original decision have been closed in subsequent work:

- **The app is now on the bulk path** (WORK-102). `SmsNotifier.syncInboxMessages` batch-submits
  server-bound SMS via `POST /messages/bulk` (≤500 per request, 202 ACCEPTED, one post-batch
  pattern refresh) instead of one synchronous `processMessage` per SMS. Complete local regex
  matches still short-circuit to `addTransaction` on the device.
- **The duplicate-processing race is resolved** (WORK-001), not just "mitigated":
  - `MessageDocument.source` discriminator: `BULK` (bulk endpoint) vs `DIRECT` (legacy
    synchronous `POST /messages/process`, which processes inline and stamps `DIRECT`).
  - The change-stream filter is `insert AND status=PENDING AND source=BULK`, and
    `isEligibleForStream()` guards the same predicate defensively before any processing.
  - A document therefore has a single owning path; the two ingestion routes can never process
    the same message concurrently. Proven at unit level (`MessageChangeStreamListenerTest`,
    `MessageServiceTest`); the CI/test profile runs with the change stream disabled.

Also on the server, the listener consults the pattern registry before calling the LLM
(WORK-002): literal-anchor matching against the sender's active templates creates the
transaction with `parseSource=REGEX_LOCAL` and zero LLM calls on cache hits, bumping
`usageCount`. This keeps `AnchorParserService` and the client `SmsParserService` in parity
(see `plans/token_template_sms_parsing.md`).

Still open: `/actuator/prometheus` exposure + change-stream lag metric (WORK-301); restart
resume-token IT against live Mongo and a 1k–10k/s load test (WORK-302).