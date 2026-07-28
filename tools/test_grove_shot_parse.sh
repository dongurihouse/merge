#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="$(mktemp -t grove_shot_parse.XXXXXX).png"
LOG="$(mktemp -t grove_shot_parse.XXXXXX).log"
trap 'rm -f "$OUT" "$LOG"' EXIT

if ! "${QUIET:-engine/tools/quiet_godot.sh}" \
    --headless \
    --path . \
    --check-only \
    -s res://games/grove/tools/grove_shot.gd \
    -- baggen "$OUT" >"$LOG" 2>&1; then
  cat "$LOG"
  exit 1
fi

echo "test_grove_shot_parse: ok"
