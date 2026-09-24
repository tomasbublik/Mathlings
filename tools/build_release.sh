#!/usr/bin/env bash
# Builds the signed Google Play bundle: build/mathlings.aab
#
# Signing secrets never live in the repo. They are read from
# ~/.android/mathlings/credentials.env (override with MATHLINGS_CREDENTIALS):
#   MATHLINGS_KEYSTORE=/abs/path/to/mathlings-upload.jks
#   MATHLINGS_KEY_ALIAS=upload
#   MATHLINGS_KEYSTORE_PASSWORD=...
# and passed to Godot through its GODOT_ANDROID_KEYSTORE_RELEASE_* variables.
#
# Usage: tools/build_release.sh
set -euo pipefail

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
CREDS="${MATHLINGS_CREDENTIALS:-$HOME/.android/mathlings/credentials.env}"
OUT="$PROJECT/build/mathlings.aab"

if [[ ! -f "$CREDS" ]]; then
    echo "Missing signing credentials: $CREDS" >&2
    exit 1
fi
# shellcheck disable=SC1090
source "$CREDS"

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$MATHLINGS_KEYSTORE"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$MATHLINGS_KEY_ALIAS"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$MATHLINGS_KEYSTORE_PASSWORD"

mkdir -p "$PROJECT/build"
rm -f "$OUT"

# The Gradle build template (android/) is generated, not committed; install it
# on first run or after a Godot upgrade.
TEMPLATE_FLAG=()
if [[ ! -f "$PROJECT/android/.build_version" ]] ||
   [[ "$(cat "$PROJECT/android/.build_version")" != "$("$GODOT" --version | sed -E 's/\.official.*//')" ]]; then
    TEMPLATE_FLAG=(--install-android-build-template)
fi

"$GODOT" --headless --path "$PROJECT" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$PROJECT" "${TEMPLATE_FLAG[@]}" \
    --export-release "Android Play" "$OUT"

if [[ ! -f "$OUT" ]]; then
    echo "Export failed: $OUT not produced" >&2
    exit 1
fi

echo ""
echo "Built $OUT ($(du -h "$OUT" | cut -f1))"
jarsigner -verify "$OUT" >/dev/null && echo "Signature: OK" || { echo "Signature: FAILED" >&2; exit 1; }
