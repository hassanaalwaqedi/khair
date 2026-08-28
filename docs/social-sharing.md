# Event social sharing

Khair shares event links from the public API rather than the Flutter `#/events/...`
route. The API serves Open Graph and Twitter Card metadata to social crawlers and
redirects people to the Flutter event screen.

Before deploying, set these Render environment variables:

```text
PUBLIC_BASE_URL=https://your-khair-api.onrender.com
FRONTEND_URL=https://khair.it.com
```

`PUBLIC_BASE_URL` must be the root of the Render API, with no `/api/v1` suffix.
For the Flutter web build, provide the matching public API endpoint:

```text
--dart-define=API_URL=https://your-khair-api.onrender.com/api/v1
```

The event cover image must also be publicly accessible by HTTPS. Link previews
cannot be generated from `localhost`, `127.0.0.1`, or a Flutter hash route.
