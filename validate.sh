#!/usr/bin/env bash
# Validation loop: GUT unit tests + portrait/landscape screenshots.
# Usage: ./validate.sh
# Claude runs this after every implementation to self-validate.
set -euo pipefail

GODOT="/opt/homebrew/bin/godot"
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHOTS="$PROJECT/.validation/screenshots"
RC=0

mkdir -p "$SHOTS"

# ── Layer 1: GUT unit tests (headless, ~5–10 s) ──────────────────────────────
echo ""
echo "━━━ Layer 1: GUT unit tests ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

gut_out=$("$GODOT" --headless --path "$PROJECT" \
    res://addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit \
    -ginclude_subdirs \
    -gexit \
    -glog=1 2>&1) && gut_status=0 || gut_status=$?

echo "$gut_out"

if [[ $gut_status -eq 0 ]]; then
    echo "✓ GUT tests PASSED"
else
    echo "✗ GUT tests FAILED (exit $gut_status)"
    RC=1
fi

# ── Layer 2: UI screenshots (portrait + landscape) ────────────────────────────
echo ""
echo "━━━ Layer 2: UI screenshots ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

_shot() {
    local label="$1" w="$2" h="$3"
    echo "  Capturing $label (${w}×${h})..."

    local out
    out=$(perl -e 'alarm(30); exec @ARGV' -- "$GODOT" \
        --path "$PROJECT" \
        --resolution "${w}x${h}" \
        -- --validate-ui --output-dir "$SHOTS" 2>&1) && local status=0 || local status=$?

    echo "$out" | grep -E '^\[Val\]|ERROR|FATAL' || true

    if [[ $status -eq 0 ]]; then
        echo "  ✓ $label"
    elif [[ $status -eq 124 ]]; then
        echo "  ✗ $label TIMEOUT (Godot hung — check validation_manager.gd)"
        RC=1
    else
        echo "  ✗ $label exit=$status"
        RC=1
    fi
}

_shot "landscape" 1280 720
_shot "portrait"  720  1280

# ── Report ────────────────────────────────────────────────────────────────────
echo ""
echo "━━━ Screenshots saved ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ls -1 "$SHOTS/"*.png 2>/dev/null || echo "  (none — screenshot stage may have failed)"

echo ""
if [[ $RC -eq 0 ]]; then
    echo "✓ All validations PASSED"
else
    echo "✗ Validation FAILED — see output above"
fi
exit $RC
