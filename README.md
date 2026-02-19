# Khair — Community Event Discovery Platform

A production-ready, cross-platform event discovery platform built with **Go** and **Flutter**. Khair connects communities through local events with features like map-based discovery, organizer onboarding, admin approval workflows, and multi-language support.

> **خير** (Khair) means "goodness" in Arabic — reflecting the platform's mission to bring communities together.

---

## ✨ Features

### 🌍 Event Discovery
- Browse and search approved community events
- Filter by category (Conference, Workshop, Seminar, Festival)
- Infinite scroll with pagination
- Event detail pages with full information

### 🗺️ Map-Based Discovery
- Interactive map view powered by OpenStreetMap
- Find events near your location with geospatial queries (PostGIS)
- Clustered event markers

### 👤 User Roles & Authentication
- JWT-based authentication (register, login, logout)
- Three-tier role system: Guest → Organizer → Admin
- Organizer application workflow with admin approval
- Secure password hashing with bcrypt

### 📋 Organizer Dashboard
- Create and manage events
- Submit events for admin review
- Track event approval status
- View organization profile

### 🛡️ Admin Panel
- Approve/reject organizer applications
- Moderate event submissions
- View audit logs and reports
- Trust scoring system for organizers
- Keyword-based content filtering

### 🌐 Localization (i18n)
- **English** and **Arabic** language support
- RTL layout support for Arabic
- Language switcher on all key pages
- Persistent language preference (SharedPreferences)
- 110+ translated strings per language

### 📱 Cross-Platform Support
- **Web** (Chrome, Firefox, Edge)
- **Android** (debug APK builds)
- **iOS** (Xcode project configured)
- Platform-aware API URLs (localhost vs 10.0.2.2 for Android emulator)

### 📄 Static Pages
- About Khair
- Privacy Policy
- Terms of Use
- Content Policy
- Verification Policy

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Backend** | Go (Gin framework) |
| **Database** | PostgreSQL 15 + PostGIS |
| **Cache** | Redis 7 |
| **Auth** | JWT (HS256) |
| **Frontend** | Flutter 3.10+ (Dart) |
| **State Management** | BLoC (flutter_bloc) |
| **Navigation** | go_router |
| **HTTP Client** | Dio |
| **Maps** | flutter_map + OpenStreetMap |
| **Localization** | flutter_localizations + ARB |
| **DI** | get_it + injectable |
| **Containerization** | Docker Compose |

---

## 📁 Project Structure

```
khair/
├── backend/
│   ├── cmd/api/              # Application entry point
│   ├── internal/             # Business logic (clean architecture)
│   │   ├── admin/            # Admin service (organizer/event moderation)
│   │   ├── auth/             # Authentication (register, login, JWT)
│   │   ├── event/            # Event CRUD & approval workflow
│   │   ├── launch/           # Launch configuration & feature flags
│   │   ├── mapservice/       # Geospatial queries (PostGIS)
│   │   ├── models/           # Domain models
│   │   ├── organizer/        # Organizer management & applications
│   │   └── trust/            # Trust & safety (content filtering, audit)
│   ├── migrations/           # SQL database migrations (4 versions)
│   └── pkg/                  # Shared packages
│       ├── config/           # Environment configuration
│       ├── database/         # DB connection pool
│       ├── middleware/       # Auth, CORS, security headers, rate limiting
│       ├── monitoring/       # Alerting & health checks
│       └── response/         # Standardized API responses
│
├── frontend/khair_app/
│   ├── android/              # Android platform config
│   ├── ios/                  # iOS platform config
│   ├── web/                  # Web platform config
│   └── lib/
│       ├── core/             # Core infrastructure
│       │   ├── di/           # Dependency injection (get_it)
│       │   ├── error/        # Error handling & failures
│       │   ├── locale/       # LocaleBloc for language management
│       │   ├── network/      # Dio API client, auth interceptor
│       │   ├── router/       # go_router configuration (19 routes)
│       │   ├── theme/        # App theme & design system
│       │   └── widgets/      # Shared widgets (language switcher, offline indicator)
│       ├── features/         # Feature modules
│       │   ├── admin/        # Admin dashboard, reports, audit logs
│       │   ├── auth/         # Login & registration
│       │   ├── events/       # Event explorer, details, cards
│       │   ├── landing/      # Marketing landing page
│       │   ├── map/          # Interactive map view
│       │   ├── organizer/    # Dashboard, create event, apply
│       │   ├── profile/      # User profile
│       │   └── static/       # About, privacy, terms pages
│       └── l10n/             # Localization (ARB files)
│           ├── app_en.arb    # English strings
│           └── app_ar.arb    # Arabic strings
│
└── docker-compose.yml        # PostgreSQL + Redis + Backend
```

---

## 🚀 Getting Started

### Prerequisites

- **Docker** & Docker Compose
- **Go** 1.21+
- **Flutter** 3.10+
- **PostgreSQL** 15+ with PostGIS (via Docker)

### Quick Start

#### 1. Clone and configure environment

```bash
git clone <repo-url>
cd khair
cp backend/.env.example backend/.env
# Edit backend/.env with your values
```

#### 2. Start database services

```bash
docker-compose up -d postgres redis
```

> ⚠️ Only start `postgres` and `redis` — no need to build the backend Docker image for local development.

#### 3. Run the backend

```bash
cd backend
go mod download
go run ./cmd/api
```

The API will start on `http://localhost:8080`.

#### 4. Run the frontend

```bash
cd frontend/khair_app
flutter pub get
flutter run -d chrome
```

### Building for Mobile

#### Android
```bash
cd frontend/khair_app
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

#### iOS
```bash
cd frontend/khair_app
flutter run -d ios
# Requires Xcode and iOS Simulator / device
```

---

## 🗺️ App Routes

| # | Page | URL | Auth Required |
|---|------|-----|:---:|
| 1 | Events Explorer | `/` | No |
| 2 | Landing Page | `/landing` | No |
| 3 | Event Detail | `/events/:id` | No |
| 4 | Map | `/map` | No |
| 5 | Login | `/login` | No |
| 6 | Register | `/register` | No |
| 7 | Profile | `/profile` | 🔑 |
| 8 | Organizer Apply | `/organizer/apply` | 🔑 |
| 9 | Organizer Dashboard | `/organizer` | 🔑 Organizer |
| 10 | Create Event | `/organizer/events/create` | 🔑 Organizer |
| 11 | Admin Dashboard | `/admin` | 🔑 Admin |
| 12 | Reports | `/admin/reports` | 🔑 Admin |
| 13 | Audit Logs | `/admin/audit-logs` | 🔑 Admin |
| 14 | Organizer Trust | `/admin/organizers/:id/trust` | 🔑 Admin |
| 15 | About | `/about` | No |
| 16 | Privacy Policy | `/privacy` | No |
| 17 | Terms of Use | `/terms` | No |
| 18 | Content Policy | `/content-policy` | No |
| 19 | Verification Policy | `/verification-policy` | No |

---

## 📡 API Endpoints

### Public
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/events` | List approved events (paginated) |
| `GET` | `/api/v1/events/:id` | Get event details |
| `GET` | `/api/v1/map/nearby` | Find nearby events (lat/lng/radius) |
| `GET` | `/api/v1/organizers/:id` | Get organizer public profile |

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/auth/register` | Register new account |
| `POST` | `/api/v1/auth/login` | Login (returns JWT) |

### Organizer (JWT Required)
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/my/events` | List my events |
| `POST` | `/api/v1/events` | Create event |
| `PUT` | `/api/v1/events/:id` | Update event |
| `POST` | `/api/v1/events/:id/submit` | Submit for review |

### Admin (JWT + Admin Role)
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/admin/organizers` | List all organizers |
| `POST` | `/api/v1/admin/organizers/:id/status` | Approve/reject organizer |
| `POST` | `/api/v1/admin/organizers/:id/ban` | Ban organizer |
| `POST` | `/api/v1/admin/organizers/:id/reinstate` | Reinstate organizer |
| `GET` | `/api/v1/admin/events` | List pending events |
| `POST` | `/api/v1/admin/events/:id/status` | Approve/reject event |
| `GET` | `/api/v1/admin/audit-logs` | View audit trail |
| `GET` | `/api/v1/admin/keywords` | List content filter keywords |
| `POST` | `/api/v1/admin/keywords` | Add filter keyword |
| `DELETE` | `/api/v1/admin/keywords/:id` | Remove filter keyword |
| `GET` | `/api/v1/admin/events/:id/flags` | Get event flags |
| `POST` | `/api/v1/admin/flags/:id/resolve` | Resolve content flag |

---

## 👥 User Roles

| Role | Capabilities |
|------|-------------|
| **Guest** | Browse events, view map, read static pages |
| **User** | All guest features + profile, apply to become organizer |
| **Organizer** | Create/manage events, submit for review (after approval) |
| **Admin** | Approve organizers/events, manage trust, view audit logs |

---

## 🌐 Localization

The app supports **English** and **Arabic** with RTL layout. Language can be switched via the flag icon (🇬🇧/🇸🇦) visible on:
- Events Explorer page
- Login page
- Register page
- Profile page
- Landing page

Language preference persists across sessions using `SharedPreferences`.

---

## ⚙️ Environment Variables

See `backend/.env.example` for all configuration options. Key variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_HOST` | PostgreSQL host | `localhost` |
| `DB_PORT` | PostgreSQL port | `5432` |
| `DB_USER` | Database user | `khair` |
| `DB_PASSWORD` | Database password | `khair_secret` |
| `DB_NAME` | Database name | `khair` |
| `REDIS_HOST` | Redis host | `localhost` |
| `REDIS_PORT` | Redis port | `6379` |
| `JWT_SECRET` | JWT signing secret | (required) |
| `SERVER_PORT` | API server port | `8080` |

---

## 📊 Database Migrations

The project includes 4 migration versions:

1. **001_init** — Core tables (users, organizers, events, categories)
2. **002_trust_safety** — Trust system, audit logs, content keywords
3. **003_performance_indexes** — Performance optimization indexes
4. **004_public_launch** — Launch configuration & feature flags

Migrations run automatically on backend startup.

---

## 📄 License

MIT
