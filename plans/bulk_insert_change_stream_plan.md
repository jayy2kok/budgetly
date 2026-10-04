# Work Breakdown Plan: Bulk Insert + Change Stream Consumer

## Goal
Implement a scalable message ingestion pipeline where:
1. The front‑end bulk‑inserts incoming messages into a MongoDB collection.
2. A change‑stream consumer listens for new inserts, atomically marks them as `IN_PROGRESS`, processes them (LLM or pattern‑registry), and updates the status to `PROCESSED` or `FAILED`.

This design decouples request latency from heavy LLM processing and eliminates thread‑pool exhaustion.

---

## Assumptions
- For development, we will configure a single‑node MongoDB replica set via Docker Compose; in production assume a properly configured replica set with change streams enabled.
- The existing `Message` repository/model can be extended with a `status` field.
- Duplicate processing due to multiple consumer instances is accepted for now (to be improved later).
- Security context is not needed in the background worker; any required tenant/app identifiers are stored in the message document at insert time.
- No prototype phase; we go straight to implementation.

---

## High‑Level Milestones
0. **Mongo Replica Set Setup** – Configure Docker Compose to run a single‑node replica set and initialize it.
1. **Data Model Update** – Add `status` and supporting fields.
2. **Bulk Insert API** – Adjust the message ingestion endpoint to accept a list and perform `insertMany`.
3. **Change‑Stream Consumer Service** – Implement a long‑running listener that:
   - Opens a change stream on the `messages` collection filtered for `status: "PENDING"`.
   - On each insert, atomically updates the document to `IN_PROGRESS`.
   - Delegates processing to the LLM or pattern‑registry service.
   - Updates the document to `PROCESSED` on success or `FAILED` on error, persisting the resume token.
4. **Resume Token Persistence** – Store the latest resume token in a dedicated singleton document (or a separate collection) after each successful processing cycle.
5. **Observability** – Add metrics, logging, and health‑check endpoints.
6. **Testing & Validation** – Unit tests, integration tests with an embedded MongoDB (or Testcontainers), and a load‑test script.
7. **Documentation** – Update ADR (Architecture Decision Record) and inline comments.

---

## Detailed Tasks
### 0. Mongo Replica Set Setup (Development)
| Sub‑task | Description | Files | Estimated Effort |
|----------|-------------|-------|------------------|
| 0.1 Add `docker-compose.yml` (or update existing) | Run MongoDB image with `--replSet rs0` and `--bind_ip_all`. Include a healthcheck that runs `rs.initiate` once. | `docker-compose.yml` | 30 min |
| 0.2 Verify replica set initialization | Provide a simple `docker exec` command or script to check `rs.status()`. Document in README. | `README.md` (dev‑setup section) | 15 min |
| 0.3 Update connection string in application config | Ensure the app uses the replica‑set aware URI (e.g., `mongodb://budgetly:***@localhost:27018/budgetly?authSource=admin&replicaSet=rs0`). | `src/main/resources/application.properties` or `application.yml` | 15 min |
| 0.4 Add note about production | Mention that in production you will run a full replica set (minimum 3 nodes) and that the same connection string pattern applies. | `README.md` | 15 min |

> **Why this works:** A single‑node replica set still provides an oplog, enabling change streams. It requires no extra infrastructure beyond Docker and lets you develop against the exact API you will use in production.

### 1. Data Model Update
| Sub‑task | Description | Files to Modify | Estimated Effort |
|----------|-------------|-----------------|------------------|
| 1.1 Add `status` enum (`PENDING`, `IN_PROGRESS`, `PROCESSED`, `FAILED`) | Extend Message entity with new field; add indexes on `status` and `createdAt`. | `src/main/java/com/budgetly/model/Message.java`<br>`src/main/resources/application.properties` (if needed for index creation) | 1h |
| 1.2 Add `messageId` (UUID) and `resumeToken` placeholder (optional) | Ensure each message has a unique identifier for idempotency. | Same as above | 30m |
| 1.3 Create migration script (if using Flyway/Liquibase) | Add column(s) and indexes to existing collection. | `src/main/resources/db/migration/VXXX__add_message_status.sql` | 30m |
| 1.4 Write unit tests for model validation | Verify enum constraints and default values. | `src/test/java/com/budgetly/model/MessageTest.java` | 1h |

### 2. Bulk Insert API
| Sub‑task | Description | Files to Modify | Estimated Effort |
|----------|-------------|-----------------|------------------|
| 2.1 Modify DTO to accept `List<MessageDTO>` | Change request wrapper from single to list. | `src/main/java/com/budgetly/web/dto/MessageRequestDTO.java` | 30m |
| 2.2 Update Service method to use `insertMany` | Validate list, set default `status = PENDING`, generate UUIDs, then bulk insert. | `src/main/java/com/budgetly/service/MessageService.java` | 1h |
| 2.3 Adjust Controller to call bulk method | Ensure proper HTTP status (202 Accepted) and response. | `src/main/java/com/budgetly/web/MessageController.java` | 30m |
| 2.4 Add validation (max batch size) | Prevent overly large payloads. | Same as above | 30m |
| 2.5 Write integration test (using @SpringBootTest with embedded Mongo) | Verify bulk insert creates correct number of docs with `PENDING` status. | `src/test/java/com/budgetly/service/MessageServiceBulkInsertIT.java` | 2h |

### 3. Change‑Stream Consumer Service
| Sub‑task | Description | Files to Modify | Estimated Effort |
|----------|-------------|-----------------|------------------|
| 3.1 Create `MessageChangeStreamListener` component | Implement `@Component` implementing `ApplicationListener<ContextRefreshedEvent>` or `@PostConstruct` to start listener. | `src/main/java/com/budgetly/listener/MessageChangeStreamListener.java` | 2h |
| 3.2 Open change stream with pipeline filter | Filter on `operationType = 'insert'` and `fullDocument.status = 'PENDING'`. | Same file | 1h |
| 3.3 Inside loop: atomic status transition | Use `findOneAndUpdate` with filter `{ _id: ..., status: 'PENDING' }` and update `{ $set: { status: 'IN_PROGRESS', processingStartedAt: new Date() } }`. Check if document was modified (non‑null). | Same file | 1h |
| 3.4 Delegate processing | Call existing `TransactionDerivationService` (LLM or pattern‑registry). Wrap in try/catch. | Same file | 1h |
| 3.5 On success: update to `PROCESSED` | Store derived transaction data, set `status: 'PROCESSED'`, `processedAt`, and persist resume token (see next milestone). | Same file | 1h |
| 3.6 On failure: update to `FAILED` | Store error message, increment retry count, set `status: 'FAILED'`. | Same file | 1h |
| 3.7 Graceful shutdown handling | Close change stream on application context close. | Same file | 30m |
| 3.8 Write unit tests with mocked MongoClient | Simulate change stream events and verify state transitions. | `src/test/java/com/budgetly/listener/MessageChangeStreamListenerTest.java` | 3h |
| 3.9 Write integration test using Embedded MongoDB (or Testcontainers) | Verify end‑to‑end flow from bulk insert to processed status. | `src/test/java/com/budgetly/listener/MessageChangeStreamListenerIT.java` | 4h |

### 4. Resume Token Persistence
| Sub‑task | Description | Files to Modify | Estimated Effort |
|----------|-------------|-----------------|------------------|
| 4.1 Create singleton document collection `change_stream_tokens` | Store `{ _id: "message-processor", token: <base64>, updatedAt: Date }`. | `src/main/java/com/budgetly/model/ChangeStreamToken.java`<br>`src/main/java/com/budgetly/repository/ChangeStreamTokenRepository.java` | 1h |
| 4.2 Helper to load token on startup | If exists, use it to resume change stream; otherwise start from beginning. | `MessageChangeStreamListener.java` (init) | 30m |
| 4.3 After each successful processing batch (or after N documents), update token document with latest resume token from change stream. | Same listener. | 30m |
| 4.4 Add index on `_id` for fast lookup. | Migration script. | 15m |
| 4.5 Unit tests for token repository | Verify save/load behavior. | `src/test/java/com/budgetly/repository/ChangeStreamTokenRepositoryTest.java` | 1h |

### 5. Observability
| Sub‑task | Description | Files to Modify | Estimated Effort |
|----------|-------------|-----------------|------------------|
| 5.1 Add Micrometer timers/counters | Track: messages pending, in progress, processed, failed; processing latency; change‑stream lag. | `MessageChangeStreamListener.java` | 1h |
| 5.2 Expose health endpoint | Indicate whether listener is active and change stream is open. | `src/main/java/com/budgetly/health/MessageProcessorHealthIndicator.java` | 30m |
| 5.3 Add structured logging (SLF4J with MDC) | Include `messageId`, `status`, `processingStep`. | Same listener | 30m |
| 5.4 Write test to verify metrics increment | Use `@AutoConfigureMockMeterRegistry`. | `src/test/java/com/budgetly/listener/MessageChangeStreamListenerMetricTest.java` | 1h |

### 6. Testing & Validation
| Sub‑task | Description | Files to Modify | Estimated Effort |
|----------|-------------|-----------------|------------------|
| 6.1 Load test script (JMeter or custom Java) | Simulate bulk inserts of 1k‑10k messages/sec, monitor consumer lag via JMX/Micrometer. | `src/loadtest/MessageLoadTest.java` | 3h |
| 6.2 Chaos test (kill consumer pod) | Verify resume token persistence prevents reprocessing of already‑processed messages. | Same load test (optional) | 2h |
| 6.3 SonarQube / Spotless check | Ensure code quality. | N/A (CI) | 1h |

### 7. Documentation
| Sub‑task | Description | Files to Modify | Estimated Effort |
|----------|-------------|-----------------|------------------|
| 7.1 Create ADR (Architecture Decision Record) | Document why bulk insert + change stream was chosen, trade‑offs, and open items (duplicate processing). | `doc/adr/0003-bulk-insert-change-stream.md` | 1h |
| 7.2 Update README / service overview | Explain how to start the consumer, monitor lag, etc. | `README.md` | 30m |
| 7.3 Inline code comments | Especially around atomic status update and token persistence. | Throughout | 1h |

---

## Estimated Total Effort
- **Data Model**: ~3h
- **Bulk Insert API**: ~3h
- **Change‑Stream Consumer**: ~11h
- **Resume Token Persistence**: ~3h
- **Observability**: ~2.5h
- **Testing & Validation**: ~6.5h
- **Documentation**: ~2.5h
- **Grand Total**: ~31.5h (~4 developer‑days)

---

## Acceptance Criteria
1. **Bulk Insert** – Sending a JSON array of messages results in all documents persisted with `status = PENDING`.
2. **Change‑Stream Listener** – Starts automatically on application startup, logs when it resumes from a token, and processes each new insert exactly once (as evidenced by status transition to `IN_PROGRESS` then `PROCESSED`/`FAILED`).
3. **Resume Token** – After a graceful shutdown and restart, the listener continues from the last processed change stream event (no reprocessing of already‑processed messages).
4. **Observability** – Metrics for pending/in‑progress/processed/failed messages are exposed via `/actuator/prometheus` and a health endpoint reports `UP` when the listener is active.
5. **Tests** – All unit and integration tests pass; load test shows stable lag under a sustained insert rate of 5k msgs/sec for 5 minutes.
6. **Documentation** – ADR exists and README reflects operational instructions.

---

## Next Steps (Immediate)
1. Create the `/plan` directory if not present and place this file.
2. Begin with the data model update (Task 1.1‑1.4) – this will unblock both the bulk insert and the listener.
3. Proceed in the order listed, committing after each major milestone for traceability.
