#!/bin/bash
# ─── Khair Health Monitor ────────────────────────
# Checks API, database, and Redis health.
# Run via cron every 5 minutes: */5 * * * * /opt/khair/scripts/health-check.sh
#
# Sends alerts via webhook (Slack, Discord, etc.)

set -uo pipefail

# ─── Configuration ───────────────────────────────
API_URL="${API_URL:-http://localhost:8080}"
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"  # Slack/Discord webhook URL
LOG_FILE="${LOG_FILE:-/var/log/khair/health.log}"
FAILURES_FILE="/tmp/khair_health_failures"

# ─── Helper Functions ────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

send_alert() {
    local message="$1"
    if [ -n "$ALERT_WEBHOOK" ]; then
        curl -s -X POST "$ALERT_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"text\": \"🚨 Khair Health Alert: ${message}\"}" \
            >/dev/null 2>&1
    fi
    log "ALERT: $message"
}

send_recovery() {
    local message="$1"
    if [ -n "$ALERT_WEBHOOK" ]; then
        curl -s -X POST "$ALERT_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"text\": \"✅ Khair Recovery: ${message}\"}" \
            >/dev/null 2>&1
    fi
    log "RECOVERY: $message"
}

# ─── Health Checks ───────────────────────────────
mkdir -p "$(dirname "$LOG_FILE")"
FAILED=0

# 1. API liveness
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${API_URL}/healthz" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "200" ]; then
    send_alert "API liveness check failed (HTTP ${HTTP_CODE})"
    FAILED=1
fi

# 2. API readiness (DB + Redis)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${API_URL}/readyz" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "200" ]; then
    send_alert "API readiness check failed — DB or Redis may be down (HTTP ${HTTP_CODE})"
    FAILED=1
fi

# 3. Response time
RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" --max-time 10 "${API_URL}/health" 2>/dev/null || echo "999")
RESPONSE_MS=$(echo "$RESPONSE_TIME * 1000" | bc 2>/dev/null || echo "9999")
if (( $(echo "$RESPONSE_TIME > 2.0" | bc -l 2>/dev/null || echo 0) )); then
    send_alert "API response time is slow: ${RESPONSE_MS}ms (threshold: 2000ms)"
fi

# 4. Disk space
DISK_USAGE=$(df /opt/khair 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%' || echo "0")
if [ "$DISK_USAGE" -gt 85 ]; then
    send_alert "Disk usage at ${DISK_USAGE}% on /opt/khair"
    FAILED=1
fi

# 5. Docker containers running
for CONTAINER in khair-api khair-postgres khair-redis; do
    STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo "not_found")
    if [ "$STATUS" != "running" ]; then
        send_alert "Container ${CONTAINER} is ${STATUS}"
        FAILED=1
    fi
done

# ─── Track Failure State for Recovery Alerts ─────
PREV_FAILED=0
[ -f "$FAILURES_FILE" ] && PREV_FAILED=$(cat "$FAILURES_FILE")

if [ "$FAILED" -eq 0 ]; then
    if [ "$PREV_FAILED" -gt 0 ]; then
        send_recovery "All health checks passing again"
    fi
    log "OK: All checks passed (${RESPONSE_MS}ms response time)"
fi

echo "$FAILED" > "$FAILURES_FILE"
exit "$FAILED"
