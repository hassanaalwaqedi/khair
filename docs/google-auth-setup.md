# Google sign-in setup

Khair verifies Google ID tokens in the API. It does not trust names, emails, or
avatars sent from the Flutter app.

1. In Google Cloud Console, create an OAuth 2.0 **Web application** client. Add
   each production domain and local web origin to its authorized JavaScript
   origins. Copy its client ID.

## Fix `Error 400: origin_mismatch`

Google compares the **scheme, host, and port** in the browser URL with its
authorized JavaScript origins. They must match exactly; a random Flutter web
port will eventually fail.

For Khair local development, edit the Web OAuth client in Google Cloud Console
and add both of these under **Authorized JavaScript origins**:

```text
http://localhost
http://localhost:7357
```

Save the client, wait a few seconds for Google to apply the change, and run the
app only on that stable origin:

```powershell
flutter run -d chrome --web-hostname localhost --web-port 7357 --dart-define=API_URL=http://localhost:8081/api/v1
```

Do not use `127.0.0.1:61811` for Google sign-in. If it is still open, close it
and use `http://localhost:7357` instead. The local origin does not need an
authorized redirect URI because Khair uses Google's popup flow.
2. Set the API environment variable:

   ```env
   GOOGLE_OAUTH_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
   ```

3. Build or run Flutter web with the same client ID:

   ```powershell
   flutter run -d chrome --web-hostname localhost --web-port 7357 --dart-define=API_URL=http://localhost:8081/api/v1 --dart-define=GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com --dart-define=GOOGLE_SERVER_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
   ```

4. For Android, create an Android OAuth client in the same Google Cloud project,
   using the app package name and release/debug SHA-1 fingerprints. Keep the web
   client ID as `GOOGLE_SERVER_CLIENT_ID` so Android returns an ID token for the
   API to verify.
5. Apply the database migration `040_oauth_identities.up.sql` before enabling
   Google sign-in in an environment.

If the client IDs are absent, the button remains visible but Google sign-in will
fail safely; email registration is unaffected.
