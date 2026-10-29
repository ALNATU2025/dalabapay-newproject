#!/usr/bin/env bash
# Builds the website (the Flutter app for browsers) into build/web.
# Used by Render (render.yaml) and runnable locally.
#   API_URL               backend address (default: the Render backend)
#   FIREBASE_WEB_APP_ID   Firebase Web app id (sign-up SMS / email link in browsers)
#   FIREBASE_WEB_API_KEY  optional: the Web app's apiKey if it differs from Android's
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"
  if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
    git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
  fi
  export PATH="$FLUTTER_DIR/bin:$PATH"
fi

flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version
flutter pub get

DEFINES=(--dart-define=API_URL="${API_URL:-https://newproject-backend-bod8.onrender.com}")
if [ -n "${FIREBASE_WEB_APP_ID:-}" ]; then DEFINES+=(--dart-define=FIREBASE_WEB_APP_ID="$FIREBASE_WEB_APP_ID"); fi
if [ -n "${FIREBASE_WEB_API_KEY:-}" ]; then DEFINES+=(--dart-define=FIREBASE_API_KEY="$FIREBASE_WEB_API_KEY"); fi

flutter build web --release "${DEFINES[@]}"
echo "Website built in build/web"
