# Engineering Onboarding Guide

Welcome to the Khair engineering team! This guide will get you running the project locally.

## 1. Prerequisites

Make sure you have installed:
- **Git**
- **Go** (Version 1.24)
- **Flutter** (Version 3.24.x)
- **PostgreSQL** (Version 15+) with the **PostGIS** extension
- **Redis**
- **Docker & Docker Compose** (Optional, but recommended for running DB/Redis)

## 2. Clone the Repository

```bash
git clone https://github.com/hassanaalwaqedi/khair.git
cd khair
```

## 3. Environment Setup

Our backend relies on environment variables. We provide a template.

```bash
cd backend
cp .env.example .env
```

**Required Local Config in `.env`:**
*   **Database:** Ensure `DB_USER` and `DB_PASSWORD` match your local PostgreSQL setup.
*   **Gemini AI:** Obtain a Google Gemini API Key and set `GEMINI_API_KEY`. Without this, event description generation will fail.
*   **Auth (JWT):** Generate a random 32-character string and set `JWT_SECRET`.

*Note: For testing push notifications or email delivery, you will need the Resend API key and the `firebase-service-account.json`. Request these from the Team Lead if needed.*

## 4. Run the Backend

Start your local Postgres and Redis. If using Docker:
```bash
# In the backend directory
docker-compose up -d
```

Start the Go API:
```bash
go run cmd/api/main.go
```
The server will start on `http://localhost:8080`.

## 5. Run the Frontend

```bash
cd ../frontend/khair_app
flutter pub get
```

Run on an emulator or connected device:
```bash
flutter run
```

Run on web:
```bash
flutter run -d chrome
```

## 6. Project Overview

### Backend (`/backend`)
*   **`cmd/api/main.go`**: The entry point. Initializes DB, Redis, services, and the Gin router.
*   **`internal/`**: Contains the core business logic, divided by domain (e.g., `auth`, `event`, `organizer`). We loosely follow a Domain-Driven Design approach with Handlers (HTTP), Services (Business Logic), and Repositories (Database).
*   **`migrations/`**: We use sequential SQL migrations. They are automatically applied on server startup via `migrate`.
*   **`pkg/`**: Shared utilities like storage, middleware, and email.

### Frontend (`/frontend/khair_app`)
*   **`lib/core/`**: Configuration, DI (GetIt/Injectable), routing (GoRouter), theme.
*   **`lib/features/`**: Feature-based architecture. Each feature (e.g., `events`, `auth`) has its own `data`, `domain`, and `presentation` layers.
*   **State Management**: We use `flutter_bloc` extensively.

## 7. Common Workflows

*   **Authentication Flow**: Users register via Email/OTP. The backend verifies the OTP via Resend and issues a JWT. The frontend stores this JWT securely and attaches it to subsequent requests.
*   **Organizer Approval**: Standard users can apply to become organizers. The application submits to `internal/organizerapplication`. Admins review these applications.
*   **Event Creation Flow**: Organizers draft events. If AI generation is used, the frontend calls the backend, which proxies the request to the Gemini API and returns the result.

## 8. Need Help?

*   Check `docs/ARCHITECTURE.md` for topology details.
*   Check `CONTRIBUTING.md` for git workflows and PR expectations.
*   Ping the Team Lead or drop a message in the engineering channel.
