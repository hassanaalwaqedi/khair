#!/bin/bash
set -e

echo "=== Khair Flutter Web Build ==="

# Install Flutter SDK
if [ ! -d "$HOME/flutter" ]; then
  echo ">>> Installing Flutter SDK..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
fi

export PATH="$PATH:$HOME/flutter/bin"

echo ">>> Flutter version:"
flutter --version

# Navigate to Flutter project
cd frontend/khair_app

echo ">>> Installing dependencies..."
flutter pub get

echo ">>> Building Flutter Web..."
flutter build web --release --base-href / \
  --dart-define=API_URL="${API_URL:-https://khair-evdzcxfucuh4g2c9.swedencentral-01.azurewebsites.net/api/v1}"

echo "=== Build complete ==="
