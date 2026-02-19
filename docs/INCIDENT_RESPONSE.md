# Khair Platform - Incident Response Runbook

## 🚨 Emergency Contacts

| Role | Contact |
|------|---------|
| On-Call Engineer | [INSERT] |
| Platform Lead | [INSERT] |
| Security Lead | [INSERT] |

---

## 🔴 Severity Levels

| Level | Description | Response Time |
|-------|-------------|---------------|
| **P1** | Full outage, data loss risk | Immediate |
| **P2** | Major feature down, high user impact | 15 minutes |
| **P3** | Degraded performance, moderate impact | 1 hour |
| **P4** | Minor issue, low impact | Next business day |

---

## 🛡️ Emergency Actions

### Full Lockdown (P1 Incidents)

**When to use:** Security breach, data corruption risk, uncontrolled failures

```bash
# API: Activate lockdown
curl -X POST https://api.khair.app/api/v1/admin/switches/lockdown \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"reason": "P1 Incident - [description]"}'
```

**Effect:** Blocks all public endpoints except health checks.

### Disable Event Publishing

**When to use:** Content moderation failure, spam attack

```bash
curl -X PUT https://api.khair.app/api/v1/admin/switches/event_publishing \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false, "reason": "[description]"}'
```

### Disable Organizer Registration

**When to use:** Abuse wave, verification system issue

```bash
curl -X PUT https://api.khair.app/api/v1/admin/switches/organizer_registration \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false, "reason": "[description]"}'
```

### Lift Lockdown

```bash
curl -X DELETE https://api.khair.app/api/v1/admin/switches/lockdown \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"reason": "Incident resolved - [details]"}'
```

---

## 📊 Diagnostic Commands

### Check Service Health

```bash
# Basic health
curl https://api.khair.app/health

# Full readiness (includes DB/Redis)
curl https://api.khair.app/ready
```

### View Logs

```bash
# API logs (last 100 lines)
docker logs khair-api --tail 100 -f

# Filter for errors
docker logs khair-api 2>&1 | grep -i error

# With timestamps
docker logs khair-api --timestamps --since 1h
```

### Check Database

```bash
# Connection count
docker exec khair-postgres psql -U khair -c \
  "SELECT count(*) as connections FROM pg_stat_activity;"

# Slow queries
docker exec khair-postgres psql -U khair -c \
  "SELECT query, calls, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"

# Active locks
docker exec khair-postgres psql -U khair -c \
  "SELECT * FROM pg_locks WHERE NOT granted;"
```

### Check Redis

```bash
# Memory usage
docker exec khair-redis redis-cli INFO memory | grep used_memory_human

# Connected clients
docker exec khair-redis redis-cli INFO clients

# Slow log
docker exec khair-redis redis-cli SLOWLOG GET 10
```

---

## 🔄 Rollback Procedures

### Quick Rollback (Image)

```bash
# Stop current containers
docker-compose -f docker-compose.prod.yml down

# Deploy previous version
docker-compose -f docker-compose.prod.yml up -d --no-build \
  -e API_IMAGE=khair-api:previous-version

# Verify
curl https://api.khair.app/health
```

### Database Migration Rollback

```bash
# Check current version
docker-compose run migrate version

# Rollback one migration
docker-compose run migrate down 1

# Verify
docker exec khair-postgres psql -U khair -c "\dt"
```

### Full Rollback Checklist

1. [ ] Notify team in incident channel
2. [ ] Identify rollback target version
3. [ ] Stop running containers
4. [ ] Rollback database if needed (test first!)
5. [ ] Deploy previous image version
6. [ ] Verify health endpoints
7. [ ] Test critical user flows
8. [ ] Update incident log

---

## 🔧 Common Issues

### High Error Rate (>5%)

**Check:**
1. Recent deployments
2. Database connectivity
3. Redis connectivity
4. External API dependencies

**Actions:**
```bash
# Check recent errors
docker logs khair-api 2>&1 | grep ERROR | tail -50

# Check DB connections
curl https://api.khair.app/ready | jq '.checks.database'
```

### High Latency (P99 >2s)

**Check:**
1. Database slow queries
2. Redis latency
3. Cache hit rate
4. Resource exhaustion

**Actions:**
```bash
# Check metrics
curl https://api.khair.app/metrics | grep latency

# Check slow queries in logs
docker logs khair-api 2>&1 | grep "Slow query"
```

### Database Connection Exhaustion

**Check:**
1. Connection leak in code
2. Long-running transactions
3. Pool misconfiguration

**Actions:**
```bash
# Kill idle connections
docker exec khair-postgres psql -U khair -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND query_start < NOW() - INTERVAL '5 minutes';"

# Increase pool temporarily (requires restart)
# Edit docker-compose.prod.yml API environment
```

### Redis Failure

**Check:**
1. Memory limits
2. Connection count
3. Persistence issues

**Actions:**
```bash
# Memory info
docker exec khair-redis redis-cli INFO memory

# Clear rate limit state (allows traffic through)
docker exec khair-redis redis-cli KEYS "rl:*" | xargs docker exec -i khair-redis redis-cli DEL

# Restart Redis (graceful)
docker-compose -f docker-compose.prod.yml restart redis
```

---

## 📝 Incident Log Template

```markdown
## Incident: [TITLE]

**Severity:** P1/P2/P3/P4
**Start Time:** YYYY-MM-DD HH:MM UTC
**End Time:** YYYY-MM-DD HH:MM UTC
**Duration:** X hours Y minutes

### Summary
[Brief description of what happened]

### Impact
- Users affected: [number/percentage]
- Features affected: [list]
- Data impact: [none/details]

### Timeline
- HH:MM - [Event]
- HH:MM - [Event]

### Root Cause
[What caused the incident]

### Resolution
[How it was fixed]

### Action Items
- [ ] [Preventive measure 1]
- [ ] [Preventive measure 2]
```

---

## ✅ Post-Incident Checklist

1. [ ] All services healthy (check /ready)
2. [ ] Error rate back to normal (<1%)
3. [ ] Latency back to normal (P99 <500ms)
4. [ ] No pending alerts
5. [ ] User-facing recovery confirmed
6. [ ] Incident log completed
7. [ ] Team notified of resolution
8. [ ] Post-mortem scheduled (for P1/P2)
