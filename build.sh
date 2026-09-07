#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# Donora+ — Release build helper
# Ensures --dart-define-from-file=.env is always included so that
# SUPABASE_URL and SUPABASE_ANON_KEY are baked in.
# ──────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env file not found at $ENV_FILE"
  echo "Copy .env.example to .env and fill in real values."
  exit 1
fi

TARGET="${1:-apk}"  # Default to APK if no target specified

echo "Building Donora+ ($TARGET) with env from .env ..."

case "$TARGET" in
  apk)
    flutter build apk --release --dart-define-from-file="$ENV_FILE"
    echo "APK built: build/app/outputs/flutter-apk/app-release.apk"
    ;;
  appbundle)
    flutter build appbundle --release --dart-define-from-file="$ENV_FILE"
    echo "App bundle built: build/app/outputs/bundle/release/app-release.aab"
    ;;
  ios)
    flutter build ios --release --dart-define-from-file="$ENV_FILE"
    echo "iOS build complete. Open ios/Runner.xcworkspace to archive."
    ;;
  web)
    flutter build web --release --dart-define-from-file="$ENV_FILE"
    echo "Web build: build/web/"
    ;;
  *)
    echo "Unknown target: $TARGET"
    echo "Usage: ./build.sh [apk|appbundle|ios|web]"
    exit 1
    ;;
esac
