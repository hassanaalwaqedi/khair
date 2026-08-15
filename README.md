# Khair خير

**Community event discovery platform** connecting people with meaningful local events — religious gatherings, educational workshops, community meetups, and more.

## Architecture

| Layer | Technology |
|-------|-----------|
| **Mobile / Web** | Flutter (Dart) |
| **API** | Go / Gin |
| **Database** | PostgreSQL + PostGIS |
| **Cache / Realtime** | Redis |
| **Object Storage** | Cloudflare R2 |
| **Push Notifications** | Firebase Cloud Messaging (v1) |
| **Email** | Resend |
| **AI** | Google Gemini (backend-only) |
| **Error Tracking** | Sentry |
| **Deployment** | Docker / Render |

## Repository Structure

```
khair/
├── backend/                 # Go API server
│   ├── cmd/api/             # Entry point
│   ├── internal/            # Domain modules (auth, event, organizer, etc.)
│   ├── pkg/                 # Shared packages (config, middleware, storage, etc.)
│   ├── migrations/          # PostgreSQL migrations (sequential, numbered)
│   ├── templates/           # Email/HTML templates
│   ├── Dockerfile
│   └── .env.example         # Environment template (no secrets)
├── frontend/khair_app/      # Flutter application
│   ├── lib/
│   │   ├── core/            # Config, auth, DI, theme, routing
│   │   ├── features/        # Feature modules (auth, events, organizer, etc.)
│   │   └── l10n/            # Localizations (EN, AR, TR)
│   ├── android/
│   ├── ios/
│   └── web/
├── docs/                    # Engineering documentation
├── .github/                 # PR templates, CI workflows
└── render.yaml              # Deployment blueprint
```

## Local Setup

### Prerequisites

- **Go** ≥ 1.24
- **Flutter** ≥ 3.2
- **PostgreSQL** 15+ with PostGIS
- **Redis** 7+
- **Android Studio** (for Android builds)

### Backend

```bash
cd backend
cp .env.example .env           # Fill in your credentials
docker-compose up -d           # Start PostgreSQL + Redis
go run cmd/api/main.go         # Start API server on :8080
```

### Frontend

```bash
cd frontend/khair_app
flutter pub get
flutter run -d chrome          # Web
flutter run                    # Connected Android device
```

### Environment

Copy `backend/.env.example` to `backend/.env` and fill in required values. See [docs/ONBOARDING.md](docs/ONBOARDING.md) for detailed setup.

> **Never commit `.env`, `key.properties`, `*.jks`, or `firebase-service-account.json`.**

## Testing

```bash
# Backend
cd backend && go test ./...

# Frontend
cd frontend/khair_app && flutter analyze && flutter test
```

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Production-ready code. Protected. |
| `develop` | Integration branch for upcoming work. |
| `feature/*` | New features |
| `fix/*` | Bug fixes |
| `hotfix/*` | Urgent production fixes |
| `release/*` | Release preparation |

All changes reach `main` through reviewed Pull Requests. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Localization

Khair supports **English**, **Arabic**, and **Turkish**. Translation files live in `frontend/khair_app/lib/l10n/`.

## License

Proprietary. All rights reserved.
