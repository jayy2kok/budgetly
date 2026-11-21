# Literal Anchor Template SMS-Parsing Architecture

> **Goal** – Avoid regex generation entirely. Store sender templates as literal text
> with `{token}` placeholders and match them at runtime by **literal anchor** search –
> left literal before a token, right literal after it. No regex is ever compiled, so
> Java and Dart behave identically by construction, with no cross-language regex
> divergence.
>
> **Status (2026-11-14, re-verified 2026-11-21)** – Implemented. `AnchorParserService` (Java) +
> `_parseAnchorTemplate` (Dart) share the same literal-anchor algorithm, asserted against a
> mirrored corpus in `AnchorParserTest` and `sms_parser_service_test.dart`. The original
> `TemplateRegexService` plan below was **abandoned** — see §4 (Decision) for why. The data
> model has since grown a few fields (see §3); the algorithm and parity guarantees are unchanged.

---

## 1. High-Level Flow

| Phase | Implementation |
|-------|----------------|
| **Inbox read** (Flutter) | `SmsInboxReader` loads cached `SmsPattern`s → `SmsParserService.parseMessage(sender, text)` does literal anchor matching against the sender's templates. **Complete** match → `parseSource=regexLocal` + `extractedData`; **incomplete** (match but missing required fields) or **unknown** sender → queued for the server. |
| **Backend ingestion** (Spring) | App batch-inserts queued SMS via `POST /messages/bulk` (≤500/batch). The `MessageChangeStreamListener` consumes `BULK+PENDING` docs and, per message: **anchor fast-path** first — `PatternRegistryService.findActiveBySender(sender)` + `AnchorParserService.parse` → complete extraction creates the transaction with `parseSource=REGEX_LOCAL`, zero LLM calls; otherwise falls back to the LLM. |
| **LLM (first sighting)** | LLM returns `{financial, amount, merchant, transactionType, rawTimestamp, notes, template, extractionMap}`. The **template** (e.g. `"Spent Rs {amount} at {merchant} on {timestamp}"`) and `extractionMap` are stored as the new `SmsPattern`. |
| **Pattern cache sync** (Flutter) | `GET /patterns` sync → the app stores the same `{template, extractionMap, sampleMessage, usageCount}`. Matching is literal-anchor on both sides; no regex to keep in sync. |
| **Future SMS** | Any sender with a stored template is matched locally against literals; the server's anchor fast-path makes the same match self-sufficient (transaction created without the LLM). |

---

## 2. The Algorithm — Literal Anchor Matching

Both `AnchorParserService.parse(template, smsText)` and `_parseAnchorTemplate(template, text)`
implement the same steps:

1. Split the template into `literals` (text between `{token}`s) and `tokens` (placeholder names).
   A template with **no tokens** cannot extract anything → return `null` (non-match).
2. For each token `i`, with `left = literals[i]` and `right = literals[i+1]`:
   - `leftIndex = smsText.indexOf(left, currentIndex)` — **left anchor mismatch** → `null`.
   - `valueStart = leftIndex + left.length`.
   - If `right` is empty (last token): `valueEnd = smsText.length`.
     Else `valueEnd = smsText.indexOf(right, valueStart)` — **right anchor mismatch** → `null`.
   - `value = smsText.substring(valueStart, valueEnd).trim()`.
   - Advance `currentIndex = valueEnd`.

`extractionMap` (from the LLM at pattern-creation time) maps token names to the canonical
fields, e.g. `accountLast4 → accountLast4`, `merchant → merchant`, `amount → amount`,
`timestamp → timestamp`. Only tokens present in `extractionMap` are exposed as extracted fields.

**Parity guarantees:**
- Tokens are **non-greedy by construction** (matched up to the first occurrence of the right
  literal).
- Regex meta-characters in literals (`Rs.`, `()`, `+`) are matched **literally** via
  `indexOf` — no escaping, no `\Q…\E` quoting, nothing that can diverge between engines.
- Trimming: extracted values are `.trim()`ed on both sides.

---

## 3. Data Model

*   **`SmsPatternDocument`** (`pattern_registry` collection): `sender`, `template`,
    `extractionMap`, `sampleMessage` (the SMS that generated the pattern), `usageCount`
    (incremented per successful server-side anchor match), `active`, `createdAt` — plus
    `categoryName` (user-overridden category resolved per-family), `reportCount`, `updatedAt`.
*   **`MessageDocument`** (`messages` collection): `messageId` (UUID), `status`
    (`PENDING/IN_PROGRESS/PROCESSED/CONFIRMED/REJECTED/IGNORED/FAILED`), **`source`**
    (`BULK` from `/messages/bulk` vs `DIRECT` from the legacy synchronous
    `POST /messages/process`), `parseSource` (`REGEX_LOCAL` when matched server-side
    without the LLM, `LLM_SERVER` otherwise), `nonFinancialCategory`
    (`OTP/PROMO/PERSONAL/DELIVERY/UNKNOWN`), `parsedTransactionData`, `retryCount`,
    `errorMessage`, `processedAt`.
*   **`LlmAnalysisResult`**: `isFinancial`, `amount`, `merchant`, `transactionType`,
    `rawTimestamp`, `notes`, `template`, `extractionMap`.

`rawTimestamp` (LLM) and the `{timestamp}` token (anchor match) are parsed into the
transaction date by the shared `TransactionDateParser` (`dd/MM/yyyy`, `dd-MM-yyyy`,
ISO, with optional `HH:mm[:ss]`), falling back to `receivedAt`/now.

---

## 4. Decision: Why No Regex?

The original design (`TemplateRegexService`) generated a Java regex from the template —
`{amount}` → `(?<amount>\d+(?:\.\d+)?)` etc. — and mirrored the source to Dart. Problems that
killed it:

1. **Named-group syntax diverges** — Java `(?<name>…)` vs Dart/JS `(?<name>…)` differ
   historically; ECMAScript named groups are a moving target.
2. **Escaping/quoting divergence** — `Pattern.quote`, `\Q…\E` handling, and backslash-in-string
   semantics behave differently across engines, so the "guaranteed identical regex" claim
   broke in practice (observed in the K9 parity corpus case).
3. **Greedy/lazy mismatch** — Perl/`.+?` lazy matching agrees mostly, but possessive quantifiers,
   lookarounds, and `.` (line terminator riddles) all risk subtle divergence.
4. **Maintenance** — a regex string in the DB is opaque; a template is auditable.

**Chosen: literal anchor matching.** Anchors are **exact substrings**, matched with
`indexOf`/`String.indexOf` on both platforms — trivially identical semantics. Precision stays
100% because the anchors come from a real SMS the LLM observed, and recall degrades gracefully
to the LLM when the literal anchors don't line up (drift). Token values are bounded by the
nearest literal occurrences, so a malformed-but-anchored SMS still extracts something.

---

## 5. Where the Pattern Is Used

- **Server (listener)** — `MessageChangeStreamListener.tryAnchorMatch`: load active templates
  for the sender, run `AnchorParserService.parse` against each; on a complete match
  (amount+merchant+timestamp available via `extractionMap`) create the transaction with
  `parseSource=REGEX_LOCAL`, bump `usageCount`, record the `budgetly.message.pattern.cache-hit`
  metric, **no LLM call**. Incomplete match or no template → `analyzeWithLlm` fallback.
- **Client (sync)** — `SmsNotifier.syncInboxMessages`: complete local match → `addTransaction`
  immediately; everything else → batched `POST /messages/bulk` for the listener, then one
  `refreshPatterns()` so next-sync anchors are fresh.
- **User-authored patterns (proposed)** — the same template shape the LLM emits can be
  authored by users in the app (highlight spans → tag `{amount}`/`{merchant}`/`{timestamp}`/
  `{transactionType}`/`{accountLast4}`/`{notes}`), stored **family-scoped** and validated by
  the same `AnchorParserService`. See
  [`plans/pattern_registry_builder_workflow.md`](pattern_registry_builder_workflow.md).

---

## 6. Test Plan (landed)

1. **`AnchorParserTest`** (Java, `src/test/java/com/budgetly/api/phase1/`) — mirrored corpus of
   templates × SMS texts shared with Dart (incl. the no-token→`null` parity case).
2. **`sms_parser_service_test.dart`** (17 tests) — non-greedy token boundaries, regex
   meta-chars in literals, multiple tokens, last-token-empty-right-literal, anchor-mismatch
   → `null`, sender filter, `extractionMap` field mapping, multiple-pattern fallthrough.
3. **`MessageChangeStreamListenerTest`** — anchor fast-path (no LLM + timestamp→transaction
   date), incomplete→LLM fallback, no-registered-pattern→LLM fallback, source filter.
4. **Run** — `mvn -B verify` in `budgetly_api` (embedded Mongo) and `flutter test` in `app`.