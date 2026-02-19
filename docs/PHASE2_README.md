# Khair Platform - Phase 2: Trust & Safety

A modular Trust & Safety layer for the Khair event discovery platform, ensuring platform integrity through content moderation, reporting, trust scoring, audit logging, and abuse prevention.

## 🏗️ Architecture

```
backend/
├── internal/
│   ├── trust/              # Trust & Safety module
│   │   ├── audit/          # Immutable audit logging
│   │   ├── moderation/     # Content moderation service
│   │   ├── reporting/      # Report handling
│   │   ├── score/          # Trust scoring engine
│   │   └── handler.go      # API endpoints
│   └── models/             # Domain models
│       ├── audit.go
│       ├── moderation.go
│       ├── report.go
│       └── trust.go
├── pkg/
│   ├── ratelimit/          # Redis-backed rate limiting
│   └── middleware/admin.go # Admin role middleware
└── migrations/
    └── 002_trust_safety.up.sql
```

## 🚀 Features

### Content Moderation
- Pre-publish keyword/pattern validation
- Configurable banned keywords by category
- Severity levels (low, medium, high, critical)
- AI integration hooks (prepared for future)

### Reporting System
- Reports from guests, users, or system
- Target: events or organizers
- Categories: political, hate speech, spam, etc.
- Admin resolution workflow

### Trust Engine
- Internal trust scoring (0-100)
- Metrics: approved/rejected events, reports, warnings
- State machine: `active → warning → suspended → banned`
- All transitions admin-controlled and logged

### Audit Logging (Immutable)
- Append-only log table
- Database triggers prevent UPDATE/DELETE
- Tracks: actor, action, target, reason, timestamp

### Rate Limiting (Redis-backed)
- Per-IP limits (guest actions)
- Per-account limits (authenticated users)
- Configurable per endpoint

## 📡 API Endpoints

### Public
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/reports` | Submit report |

### Admin Trust & Safety
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/admin/reports` | List reports |
| POST | `/api/v1/admin/reports/:id/resolve` | Resolve report |
| POST | `/api/v1/admin/organizers/:id/warn` | Issue warning |
| POST | `/api/v1/admin/organizers/:id/suspend` | Suspend |
| POST | `/api/v1/admin/organizers/:id/ban` | Ban |
| POST | `/api/v1/admin/organizers/:id/reinstate` | Reinstate |
| GET | `/api/v1/admin/organizers/:id/trust` | Trust score |
| GET | `/api/v1/admin/audit-logs` | Query logs |

## 🔧 Configuration

Add to `.env`:
```env
# Redis (for rate limiting)
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0
```

## 🗄️ Database

Run migrations:
```bash
cd backend
migrate -path migrations -database "postgres://user:pass@localhost/khair?sslmode=disable" up
```

### New Tables
- `reports` - User/system reports
- `organizer_trust_scores` - Trust metrics
- `moderation_flags` - Content flags
- `audit_logs` - Immutable action log
- `banned_keywords` - Moderation keywords

### Modified Tables
- `organizers` + `trust_state` column
- `events` + `moderation_status` column

## 📱 Flutter Admin UI

New admin pages:
- **Reports Page** (`/admin/reports`) - Manage reports
- **Audit Logs** (`/admin/audit-logs`) - View history
- **Organizer Trust** (`/admin/organizers/:id/trust`) - Trust profile

## 🧪 Testing

```bash
# Backend tests
cd backend
go test ./internal/trust/...

# Flutter tests
cd frontend/khair_app
flutter test
```

## 📋 Default Rate Limits

| Action | IP Limit | Account Limit |
|--------|----------|---------------|
| Event creation | 5/hour | 10/day |
| Event edit | 10/hour | 30/day |
| Report submission | 10/hour | 20/day |
