# Khair Platform - Production Deployment Guide

## 📋 Pre-Deployment Checklist

### Infrastructure
- [ ] Production server/container host ready
- [ ] PostgreSQL 15+ with PostGIS installed
- [ ] Redis 7+ available
- [ ] Domain configured with SSL/TLS
- [ ] Firewall rules configured

### Configuration
- [ ] `.env` file created from `.env.production.example`
- [ ] Strong passwords set for DB, Redis, JWT
- [ ] CORS origins configured for production domain
- [ ] SSL certificates installed

### Code
- [ ] All migrations tested in staging
- [ ] No debug endpoints enabled
- [ ] Feature flags reviewed

---

## 🚀 Deployment Steps

### 1. Prepare Environment

```bash
# Clone repository
git clone https://github.com/your-org/khair.git
cd khair

# Create production environment file
cp .env.production.example .env

# Edit with production values
nano .env
```

### Required Environment Variables

```env
# Database
DB_USER=khair
DB_PASSWORD=<strong-password>
DB_NAME=khair

# Redis
REDIS_PASSWORD=<strong-password>

# JWT
JWT_SECRET=<generate-with-openssl-rand-base64-32>

# CORS (production domains)
CORS_ORIGINS=https://khair.app,https://www.khair.app

# Environment
ENV=production
```

### 2. Run Database Migrations

```bash
# Run migrations
docker-compose -f docker-compose.prod.yml --profile migrate up migrate

# Verify tables created
docker exec khair-postgres psql -U khair -c "\dt"
```

### 3. Build and Deploy Backend

```bash
# Build and start services
docker-compose -f docker-compose.prod.yml up -d --build

# Verify health
curl http://localhost:8080/health
curl http://localhost:8080/ready
```

### 4. Build Flutter Apps

#### Web

```bash
cd frontend/khair_app

# Build production web
flutter build web --release --dart-define=ENV=production

# Output in build/web/
```

#### Android

```bash
# Generate signing key (first time only)
keytool -genkey -v -keystore khair-release.keystore -alias khair -keyalg RSA -keysize 2048 -validity 10000

# Configure android/key.properties
echo "storePassword=<password>
keyPassword=<password>
keyAlias=khair
storeFile=../khair-release.keystore" > android/key.properties

# Build APK
flutter build apk --release --dart-define=ENV=production

# Build App Bundle (for Play Store)
flutter build appbundle --release --dart-define=ENV=production
```

#### iOS

```bash
# Open in Xcode for signing
open ios/Runner.xcworkspace

# Or build from command line
flutter build ios --release --dart-define=ENV=production

# Archive for App Store
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release archive
```

---

## 🔧 Post-Deployment Verification

### Health Checks

```bash
# Basic health
curl https://api.khair.app/health

# Full readiness
curl https://api.khair.app/ready

# Metrics endpoint (internal only)
curl https://api.khair.app/metrics
```

### Smoke Tests

1. [ ] Guest can view events (no login required)
2. [ ] User registration works
3. [ ] User login works
4. [ ] Event search works
5. [ ] Map view loads
6. [ ] Admin dashboard accessible

---

## 📊 Monitoring Setup

### Enable Alerts

The backend exposes Prometheus metrics at `/metrics`. Configure your monitoring system to scrape this endpoint.

**Alert Thresholds (Default):**

| Metric | Threshold | Severity |
|--------|-----------|----------|
| Error Rate | >5% | Critical |
| P99 Latency | >2000ms | Critical |
| DB Connections | >80% | Warning |
| Cache Hit Rate | <50% | Info |

### Log Configuration

Logs are structured JSON, suitable for:
- CloudWatch Logs
- Elasticsearch/Kibana
- Datadog
- Splunk

Example log entry:
```json
{
  "timestamp": "2026-02-06T07:00:00Z",
  "level": "INFO",
  "message": "Request completed",
  "request_id": "abc123",
  "method": "GET",
  "path": "/api/v1/events",
  "status_code": 200,
  "duration_ms": 45
}
```

---

## 🛡️ Security Hardening

### SSL/TLS

Ensure reverse proxy (nginx/traefik) terminates SSL:
- Use TLS 1.2+
- Enable HSTS
- Configure proper cipher suites

### Rate Limiting

Default limits:
- 60 requests/minute per IP (guests)
- 100 requests/minute per user

Adjust in Redis if needed.

### Security Headers

Automatically applied:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Content-Security-Policy: default-src 'self'`

---

## 👨‍💼 Admin Operations

### Feature Flags

```bash
# List all feature flags
curl -H "Authorization: Bearer $TOKEN" \
  https://api.khair.app/api/v1/admin/feature-flags

# Disable a feature
curl -X PUT -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}' \
  https://api.khair.app/api/v1/admin/feature-flags/event_publishing
```

### Emergency Switches

```bash
# View all switches
curl -H "Authorization: Bearer $TOKEN" \
  https://api.khair.app/api/v1/admin/switches

# Activate lockdown
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"reason": "Maintenance"}' \
  https://api.khair.app/api/v1/admin/switches/lockdown
```

### User Management

```bash
# View pending organizers
curl -H "Authorization: Bearer $TOKEN" \
  https://api.khair.app/api/v1/admin/organizers?status=pending

# Approve organizer
curl -X POST -H "Authorization: Bearer $TOKEN" \
  https://api.khair.app/api/v1/admin/organizers/{id}/approve
```

---

## 🔄 Rollback

See [INCIDENT_RESPONSE.md](./INCIDENT_RESPONSE.md) for detailed rollback procedures.

Quick rollback:
```bash
# Stop services
docker-compose -f docker-compose.prod.yml down

# Checkout previous version
git checkout v1.x.x

# Redeploy
docker-compose -f docker-compose.prod.yml up -d --build
```

---

## 📞 Support

For production issues:
1. Check [INCIDENT_RESPONSE.md](./INCIDENT_RESPONSE.md)
2. Review logs: `docker logs khair-api`
3. Check health: `curl /health`
4. Contact on-call engineer
