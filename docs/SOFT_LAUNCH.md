# Khair Platform - Phase 3: Soft Launch Guide

## 🚀 Quick Start

```bash
# 1. Copy environment template
cp .env.production.example .env

# 2. Configure environment variables
# Edit .env with your values

# 3. Run migrations and start services
docker-compose -f docker-compose.prod.yml --profile migrate up migrate
docker-compose -f docker-compose.prod.yml up -d

# 4. Verify health
curl http://localhost:8080/health
```

---

## 📋 Pre-Deployment Checklist

### Environment Configuration
- [ ] Copy `.env.production.example` to `.env`
- [ ] Set strong `DB_PASSWORD` (min 16 characters)
- [ ] Set strong `REDIS_PASSWORD`
- [ ] Generate `JWT_SECRET` with: `openssl rand -base64 32`
- [ ] Set `LAUNCH_COUNTRY` code (SA, AE, etc.)

### Database
- [ ] PostgreSQL accessible and healthy
- [ ] PostGIS extension available
- [ ] Sufficient disk space for data growth
- [ ] Backup strategy configured

### Infrastructure
- [ ] Docker and Docker Compose installed
- [ ] Ports 8080 (API) available
- [ ] SSL/TLS termination configured (nginx/traefik)
- [ ] DNS configured for domain

### Monitoring
- [ ] `/health` endpoint accessible
- [ ] `/metrics` endpoint accessible (internal only)
- [ ] Log aggregation configured
- [ ] Alerting configured for critical metrics

---

## 🔧 Configuration Reference

### Soft Launch Controls

Configure via Admin API or directly in Redis:

| Setting | Description | Default |
|---------|-------------|---------|
| `LAUNCH_COUNTRY_CODE` | ISO country code for restriction | `SA` |
| `country_restricted` | Enable country restriction | `true` |
| `max_organizers` | Maximum approved organizers | `100` |
| `organizer_limited` | Enable organizer limit | `true` |
| `invite_only_mode` | Require invitation codes | `false` |

### Feature Flags

| Flag | Description | Default |
|------|-------------|---------|
| `organizer_registration` | Allow new registrations | `true` |
| `event_publishing` | Allow event creation | `true` |
| `reporting_system` | Enable reports | `true` |
| `guest_event_view` | Public event viewing | `true` |
| `map_feature` | Enable map view | `true` |

### Admin API Endpoints

```bash
# Get launch config
GET /api/v1/admin/launch/config

# Update launch config
PUT /api/v1/admin/launch/config
{
  "max_organizers": 200,
  "invite_only_mode": true
}

# Create invitation code
POST /api/v1/admin/launch/invites
{
  "email": "organizer@example.com",
  "valid_days": 30
}

# List feature flags
GET /api/v1/admin/feature-flags

# Toggle feature flag
PUT /api/v1/admin/feature-flags/event_publishing
{
  "enabled": false
}
```

---

## 📊 Monitoring

### Health Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Basic health check |
| `GET /ready` | Readiness (includes DB check) |
| `GET /metrics` | Prometheus metrics |

### Key Metrics

| Metric | Description |
|--------|-------------|
| `http_requests_total` | Request count by endpoint |
| `http_errors_total` | Error count by endpoint |
| `db_connections_active` | Active DB connections |
| `db_slow_queries_total` | Queries >100ms |
| `cache_hits_total` | Cache hit count |
| `cache_misses_total` | Cache miss count |

### Log Format

Structured JSON logs:
```json
{
  "timestamp": "2026-02-06T06:00:00Z",
  "level": "INFO",
  "message": "Request completed",
  "request_id": "abc123",
  "method": "GET",
  "path": "/api/v1/events",
  "status_code": 200,
  "duration_ms": 45.2
}
```

---

## 🔐 Security Headers

All responses include:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Content-Security-Policy: default-src 'self'`

---

## ⚡ Performance

### Caching (Redis)

| Cache | TTL | Key Pattern |
|-------|-----|-------------|
| Event listings | 60s | `cache:events:list:*` |
| Event details | 300s | `cache:events:detail:{id}` |
| Geo search | 120s | `cache:events:geo:*` |
| Organizer profiles | 600s | `cache:organizer:{id}` |

### Database Indexes (Phase 3)

Run migration `003_performance_indexes`:
- Composite index for upcoming events
- City + status index
- Geo coordinates index
- Partial indexes for admin queues

---

## 🔄 Rollback Strategy

### Quick Rollback

```bash
# Stop services
docker-compose -f docker-compose.prod.yml down

# Rollback database migration
docker-compose -f docker-compose.prod.yml run migrate \
  -path=/migrations -database "..." down 1

# Redeploy previous version
git checkout v1.2.0
docker-compose -f docker-compose.prod.yml up -d --build
```

### Database Rollback

```bash
# List applied migrations
docker-compose run migrate version

# Rollback specific migration
docker-compose run migrate down 1
```

---

## 🆘 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| API returns 503 | Check database connectivity |
| Slow requests | Check slow query logs, verify indexes |
| Rate limit errors | Adjust limits in Redis config |
| Feature disabled | Check feature flags via Admin API |

### Useful Commands

```bash
# View API logs
docker logs khair-api -f

# Check database connections
docker exec khair-postgres psql -U khair -c "SELECT count(*) FROM pg_stat_activity;"

# Clear all caches
docker exec khair-redis redis-cli FLUSHALL

# Get cache stats
docker exec khair-redis redis-cli INFO stats
```

---

## 📞 Support

For issues during soft launch:
1. Check logs: `docker logs khair-api`
2. Verify health: `curl /health`
3. Check metrics: `curl /metrics`
