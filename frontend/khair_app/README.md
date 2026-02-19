# Khair App — Flutter Frontend

Cross-platform Flutter application for the Khair event discovery platform.

## Platforms

- ✅ **Web** (Chrome, Firefox, Edge)
- ✅ **Android** (debug APK)
- ✅ **iOS** (Xcode configured)

## Setup

```bash
flutter pub get
flutter run -d chrome
```

## Architecture

Clean architecture with BLoC pattern:

```
lib/
├── core/                  # Shared infrastructure
│   ├── di/                # Dependency injection (get_it)
│   ├── locale/            # Language management (LocaleBloc)
│   ├── network/           # Dio client + auth interceptor
│   ├── router/            # go_router (19 routes)
│   ├── theme/             # Design system & theming
│   └── widgets/           # Reusable widgets
├── features/              # Feature modules
│   ├── admin/             # Admin dashboard, reports, audit logs
│   ├── auth/              # Login & registration (BLoC)
│   ├── events/            # Event explorer, details, filtering
│   ├── landing/           # Marketing landing page
│   ├── map/               # Interactive OpenStreetMap view
│   ├── organizer/         # Dashboard, create event, apply
│   ├── profile/           # User profile page
│   └── static/            # About, privacy, terms, policies
└── l10n/                  # Localization
    ├── app_en.arb         # English (110+ strings)
    └── app_ar.arb         # Arabic (110+ strings)
```

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_bloc` | State management |
| `go_router` | Declarative routing |
| `dio` | HTTP client |
| `get_it` | Dependency injection |
| `flutter_map` | OpenStreetMap integration |
| `flutter_localizations` | i18n support |
| `shared_preferences` | Persistent settings |

## Build Commands

```bash
# Web
flutter build web

# Android debug APK
flutter build apk --debug

# iOS (requires Mac + Xcode)
flutter run -d ios

# Run analyzer
flutter analyze
```

## Localization

- Supported: **English** (en), **Arabic** (ar)
- ARB files in `lib/l10n/`
- Code generation via `flutter gen-l10n` (auto-runs on build)
- Switch language using the 🇬🇧/🇸🇦 flag icon on key pages
