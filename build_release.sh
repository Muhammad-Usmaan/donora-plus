#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# Donora+ — Release build (release APK)
#
# USAGE:  ./build_release.sh
#
# This script guarantees that --dart-define-from-file=.env is
# always passed, so SUPABASE_URL and SUPABASE_ANON_KEY are baked
# into the release binary.  Running raw `flutter build apk --release`
# without this flag is the #1 cause of "No host specified in URI"
# crashes in release mode.
# ──────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo ""
  echo "ERROR: Missing .env file"
  echo ""
  echo "  Copy .env.example and fill in Supabase credentials:"
  echo "    cp .env.example .env"
  echo ""
  exit 1
fi

echo "Building release APK with --dart-define-from-file=.env ..."
flutter build apk --release --dart-define-from-file="$ENV_FILE"
echo ""
echo "Done → build/app/outputs/flutter-apk/app-release.apk"
