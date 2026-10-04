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
