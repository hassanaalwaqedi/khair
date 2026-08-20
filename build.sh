#!/bin/bash
if [ -z "$API_URL" ]; then
  echo 'API_URL must point to the Render API, including /api/v1'
  exit 1
fi
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"
cd frontend/khair_app
flutter pub get
flutter build web --release --base-href / --dart-define=API_URL="$API_URL" --dart-define=GOOGLE_WEB_CLIENT_ID="$GOOGLE_WEB_CLIENT_ID" --dart-define=GOOGLE_SERVER_CLIENT_ID="$GOOGLE_SERVER_CLIENT_ID"

# SPA routes are handled by `assets.not_found_handling` in wrangler.jsonc.
# Remove the obsolete Pages redirect file if a cached build directory contains
# one: `/ /index.html 200` is invalid for Workers Static Assets and loops.
rm -f build/web/_redirects
