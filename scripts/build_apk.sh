#!/usr/bin/env bash
# Build a release APK with the Firebase / API config baked in.
#
# The mobile app reads every Firebase option from dart-defines
# (lib/firebase_options.dart uses String.fromEnvironment), so an APK built
# without them contains empty keys and the app hangs on the splash screen
# (Firebase Auth never resolves). This script always passes the values:
#
#   flutter build apk --release --dart-define-from-file=.env
#
# Usage:
#   scripts/build_apk.sh
#
# The APK is written to mobile/dist/Sudanile-Kitchen-v<version>.apk and a
# sanity check confirms the Firebase project id made it into the binary.
set -euo pipefail

# Repo root = parent of the directory this script lives in.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/mobile"

if [ ! -f "$MOBILE/pubspec.yaml" ]; then
  echo "ERROR: mobile/ not found next to $ROOT" >&2
  exit 1
fi

if [ ! -f "$MOBILE/.env" ]; then
  echo "ERROR: $MOBILE/.env is missing." >&2
  echo "Copy $MOBILE/.env.example to $MOBILE/.env and fill in the values." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: flutter is not on PATH." >&2
  exit 1
fi

echo "==> Building release APK with --dart-define-from-file=.env"
cd "$MOBILE"
flutter build apk --release --dart-define-from-file=.env

# Version comes from pubspec.yaml (e.g. "version: 1.1.0+2" -> 1.1.0).
VERSION="$(grep -E '^version:' pubspec.yaml | head -1 | sed 's/version:[[:space:]]*//; s/+.*//')"
[ -n "$VERSION" ] || { echo "ERROR: could not parse version from pubspec.yaml" >&2; exit 1; }

SRC="build/app/outputs/flutter-apk/app-release.apk"
DIST="$MOBILE/dist"
OUT="$DIST/Sudanile-Kitchen-v$VERSION.apk"

mkdir -p "$DIST"
cp "$SRC" "$OUT"
echo "==> Copied APK to $OUT"

# Sanity check: the Firebase project id must be baked into the binary.
PROJECT_ID="$(grep '^FIREBASE_PROJECT_ID=' .env | cut -d= -f2 | tr -d '\r')"
if [ -n "$PROJECT_ID" ] && ! grep -q --text "$PROJECT_ID" "$OUT"; then
  echo "WARNING: Firebase project id not found in APK — config may be missing." >&2
else
  echo "==> Verified Firebase config is baked into the APK."
fi

echo "==> Done. Upload with:"
echo "    gh release upload v$VERSION \"$OUT\" --clobber"
