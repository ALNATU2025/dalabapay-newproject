#!/usr/bin/env bash
# Builds the website (the Flutter app for browsers) into build/web.
# Used by Render (render.yaml) and runnable locally.
#   API_URL               backend address (default: the Render backend)
#   FIREBASE_WEB_APP_ID   Firebase Web app id (sign-up SMS / email link in browsers)
#   FIREBASE_WEB_API_KEY  optional: the Web app's apiKey if it differs from Android's
set -euo pipefail

# Same Flutter as the app build and CI (a newer one can fail to build, and
# Render then keeps serving the old website without saying so).
FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.9}"
if ! command -v flutter >/dev/null 2>&1 || ! flutter --version 2>/dev/null | grep -q "Flutter $FLUTTER_VERSION "; then
  FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter-$FLUTTER_VERSION}"
  if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
    rm -rf "$FLUTTER_DIR"
    git clone --depth 1 -b "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
  fi
  export PATH="$FLUTTER_DIR/bin:$PATH"
fi

flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version
flutter pub get

DEFINES=(--dart-define=API_URL="${API_URL:-https://newproject-backend-bod8.onrender.com}")
if [ -n "${FIREBASE_WEB_APP_ID:-}" ]; then DEFINES+=(--dart-define=FIREBASE_WEB_APP_ID="$FIREBASE_WEB_APP_ID"); fi
if [ -n "${FIREBASE_WEB_API_KEY:-}" ]; then DEFINES+=(--dart-define=FIREBASE_API_KEY="$FIREBASE_WEB_API_KEY"); fi

# --csp: no eval in the compiled app, so the strict Content-Security-Policy
# in render.yaml works.
flutter build web --release --csp "${DEFINES[@]}"
echo "Website built in build/web"
