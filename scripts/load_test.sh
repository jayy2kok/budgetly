#!/usr/bin/env bash
#
# WORK-302 — Bulk-ingestion load test.
#
# Fires concurrent POST /messages/bulk batches at a running Budgetly API and
# reports consumer completion vs the new change-stream lag gauge.
#
# Prereqs (compose stack):
#   docker compose up -d          # Mongo rs0 + budgetly-api (see docker-compose.yml)
#   * a sender pattern pre-seeded in pattern_registry so anchor matching (no LLM
#     key needed) finalizes most messages, and
#   * the load user added as a member of $BUDGETLY_FAMILY_ID so transaction
#     creation passes the membership check.
#
# Usage:
#   BUDGETLY_JWT_SECRET=<same as application.yml jwt.secret> \
#   BUDGETLY_FAMILY_ID=fam-<id> \
#   ./scripts/load_test.sh [--messages 20000] [--batch 500] [--concurrency 8] \
#                          [--api http://localhost:8080]
#
# Metrics read from /actuator/prometheus:
#   budgetly_message_processing_{started,success,failed}_total
#   budgetly_message_change_stream_lag_milliseconds   (WORK-301 gauge)
#
# Records a line of (sent, accepted, started, success, failed, lag_ms, wall_sec)
# every $POLL_INTERVAL seconds, then prints totals.

set -euo pipefail

API="${BUDGETLY_API:-http://localhost:8080}"
FAMILY_ID="${BUDGETLY_FAMILY_ID:?set BUDGETLY_FAMILY_ID (add the load user as a member)}"
SECRET="${BUDGETLY_JWT_SECRET:?set BUDGETLY_JWT_SECRET to match the running API}"
USER_ID="${BUDGETLY_LOAD_USER_ID:-load-test-user}"
SENDER="${BUDGETLY_SENDER:-HDFCBK}"
MESSAGES=20000
BATCH=500
CONCURRENCY=8
POLL_INTERVAL=2
LOAD_NS="load-$(date +%s)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) sed -n '2,40p' "$0"; exit 0 ;;
    --messages) MESSAGES="$2"; shift 2 ;;
    --batch) BATCH="$2"; shift 2 ;;
    --concurrency) CONCURRENCY="$2"; shift 2 ;;
    --api) API="$2"; shift 2 ;;
    --poll) POLL_INTERVAL="$2"; shift 2 ;;
    --sender) SENDER="$2"; shift 2 ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
done

[[ "$BATCH" -le 500 ]] || { echo "--batch <= 500 (backend maxBatchSize)"; exit 2; }

# ── Mint an HS256 access JWT (subject=userId, claim type=access) ─────
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
header=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url)
payload=$(printf '{"sub":"%s","type":"access","iat":%s,"exp":%s}' \
  "$USER_ID" "$(date +%s)" "$(($(date +%s) + 3600))" | b64url)
sig=$(printf '%s.%s' "$header" "$payload" \
  | openssl dgst -sha256 -hmac "$SECRET" -binary | b64url)
TOKEN="$header.$payload.$sig"
AUTH="Authorization: Bearer $TOKEN"

echo "== load test: messages=$MESSAGES batch=$BATCH workers=$CONCURRENCY sender=$SENDER"
echo "== api: $API  (curl latest: $(curl -sS -o /dev/null -w '%{http_code}' -H "$AUTH" "$API/actuator/prometheus" || true))"

# ── Fire the bulk batches (acceptedCount should equal the batch size) ──
start_epoch=$(date +%s)
seq 0 $(( (MESSAGES + BATCH - 1) / BATCH - 1 )) \
  | xargs -P "$CONCURRENCY" -I{} sh -c '
      start=$(( {} * '"$BATCH"' + 1 )); end=$(( start + '"$BATCH"' - 1 ));
      [ "$start" -gt '"$MESSAGES"' ] && exit 0
      [ "$end" -gt '"$MESSAGES"' ] && end='"$MESSAGES"'
      payload=$(printf "{\"familyGroupId\":\"%s\",\"messages\":[" '"$FAMILY_ID"' )
      for i in $(seq "$start" "$end"); do
        payload="${payload}{\"sender\":\"'"$SENDER"'\",\"rawText\":\"Loaded Rs ${i} at store on 01/10/2026\"},"
      done
      payload="${payload%,}]}"
      curl -sS -o /dev/null -w "%{http_code}\n" -X POST \
        -H "Authorization: Bearer '"$TOKEN"'" -H "Content-Type: application/json" \
        -d "$payload" '"$API"'/messages/bulk' \
  > /tmp/bulk_resp.$$.txt || true

# ── Poll consumer progress + lag ─────────────────────────────────────
sample() { curl -sS -H "$AUTH" "$API/actuator/prometheus" || true; }

echo "sent_total accepted_total started_total success_total failed_total lag_ms wall_sec"
accepted=0
while :; do
  wall=$(( $(date +%s) - start_epoch ))
  m=$(sample)
  started=$(grep -oE '^budgetly_message_processing_started_total [0-9.]+' <<<"$m" | awk '{print $2}' || echo 0)
  success=$(grep -oE '^budgetly_message_processing_success_total [0-9.]+' <<<"$m" | awk '{print $2}' || echo 0)
  failed=$(grep -oE '^budgetly_message_processing_failed_total [0-9.]+' <<<"$m" | awk '{print $2}' || echo 0)
  lag=$(grep -oE '^budgetly_message_change_stream_lag_milliseconds [0-9.eE+.-]+' <<<"$m" | awk '{print $2}' || echo 0)
  # accepted: count HTTP 202s from the response file
  accepted=$(grep -c '^202$' /tmp/bulk_resp.$$.txt || true)
  complete=$(( success + failed ))
  echo "$MESSAGES $accepted $started $success $failed $lag $wall"
  if [[ "$accepted" -eq "$MESSAGES" && "$started" -ge "$accepted" && "$complete" -ge "$accepted" ]]; then
    break
  fi
  sleep "$POLL_INTERVAL"
done

echo "== done in $wall s: accepted=$accepted success=$success failed=$failed final_lag_ms=$lag"