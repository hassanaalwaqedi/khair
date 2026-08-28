# Khair production deployment

Khair uses four production services:

- **Supabase Postgres** for relational application data.
- **Cloudflare R2** for media, with separate public and private buckets.
- **Render** for the Go API.
- **Firebase Hosting or Cloudflare Workers/Pages** for the Flutter web build.

## 1. Supabase

Create one production Supabase project in the region closest to the first launch market. In **Connect**, copy the Session Pooler host, username, password, and database name into Render as `DB_HOST`, `DB_USER`, `DB_PASSWORD`, and `DB_NAME`. Set `DB_PORT=5432` and `DB_SSLMODE=require`.

Do not place the database password in Flutter, Git, or Cloudflare. The Render API is the only service that connects to Postgres.

## 2. Cloudflare R2

Create two buckets:

- `khair-public` for event covers, avatars, and other public images.
- `khair-private` for organizer application photos and verification documents.

Keep `khair-private` private. Connect a custom HTTPS domain such as `media.example.com` to `khair-public`; use that domain as `R2_PUBLIC_BASE_URL`. Create a scoped R2 API token that can read and write only these two buckets. Add the endpoint, token access key ID, and secret to Render using the `R2_*` variables in `backend/.env.production.example`.

The API uploads public assets to R2 and stores URLs under `R2_PUBLIC_BASE_URL`. Private organizer documents never receive a public URL; the API produces short-lived signed links only after access checks.

## 3. Redis-compatible service

Khair uses Redis for rate limits, real-time WebSocket fan-out, cache, and notifications. Configure a managed Redis-compatible service with TLS, then add `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`, and `REDIS_TLS=true` to Render. This is required for every real-time feature to work reliably across Render instances.

## 4. Render API

Create the service from the repository's `render.yaml`. During Blueprint setup, Render asks for every `sync: false` value. Use `https://<your-service>.onrender.com` for `PUBLIC_BASE_URL` initially, then replace it with the API custom domain after DNS is connected.

Render injects `PORT`; the API now honors it. It runs database migrations before accepting traffic and refuses to start in production if a migration fails. Set the health-check route to `/readyz`.

## 5. Flutter web hosting

Build the Flutter web app with the Render API URL:

```
flutter pub get
flutter build web --release --dart-define=API_URL=https://your-khair-api.onrender.com/api/v1
```

The Firebase project is configured in `frontend/khair_app/.firebaserc` and its
hosting rules are in `frontend/khair_app/firebase.json`:

```bash
firebase deploy --only hosting
```

Cloudflare Workers/Pages uses `wrangler.jsonc` and the same `build/web` output:

```bash
wrangler deploy
```

After choosing the public web hostname, update the Render values `FRONTEND_URL`,
`CORS_ALLOWED_ORIGINS`, and `CORS_ORIGINS` to that exact HTTPS origin, then
redeploy Render.

## 6. Google OAuth and sharing

In Google Cloud Console, add the exact public HTTPS web domain to **Authorized JavaScript origins**. Set the same web OAuth client ID as `GOOGLE_OAUTH_CLIENT_ID` in Render. Add the API custom domain to `PUBLIC_BASE_URL`; Khair's server-rendered event links then supply Open Graph metadata and event cover images to WhatsApp and other sharing clients.

## Release checks

1. `GET https://api.example.com/readyz` returns 200.
2. Create an event and confirm its cover is stored under `https://media.example.com/`.
3. Submit an organizer application and confirm documents cannot be opened without an API-issued signed URL.
4. Open a shared `https://api.example.com/events/<id>` link in a social preview inspector and confirm title, description, and cover image appear.
5. Sign in on the public web domain using Google and confirm no `origin_mismatch` error.
