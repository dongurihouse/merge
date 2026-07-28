#!/usr/bin/env bash
## Guard for games/grove/tools/grove_shot.gd.
##
## Two tiers, because parse-only is not enough. Commit da3099b3 ("Retire generator tier state")
## left two INDENTATION regressions in the `cascade` branch — statements pulled into the loop
## above them. Both parse fine, and one of them (the post-_rebuild_all generator strip nested
## under `if is_instance_valid(n)`) renders a plausible board at exit code 0 with a stray
## generator on it. A `--check-only` run cannot see either.
##
##   default          — parse check PLUS a real capture of the modes that commit touched, each
##                      asserted on the SHOT line's own state fields, not on the exit code.
##   FAST=1           — parse check only. For a tight edit loop; NOT what `make test` runs.
##
## Each capture goes through engine/tools/quiet_godot.sh, so the window is born 1x1 off the
## corner of the screen, parked off-screen for the run, and never steals focus.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

QUIET="${QUIET:-engine/tools/quiet_godot.sh}"
TOOL="res://games/grove/tools/grove_shot.gd"

TMPDIR_RUN="$(mktemp -d -t grove_shot_guard.XXXXXX)"
trap 'rm -rf "$TMPDIR_RUN"' EXIT

fail() { echo "test_grove_shot_parse: FAIL — $*" >&2; exit 1; }

# --- tier 1: it parses --------------------------------------------------------------------
LOG="$TMPDIR_RUN/parse.log"
if ! "$QUIET" --headless --path . --check-only \
    -s "$TOOL" -- baggen "$TMPDIR_RUN/parse.png" >"$LOG" 2>&1; then
  cat "$LOG" >&2
  fail "grove_shot.gd does not parse"
fi
echo "  parse: ok"

if [ "${FAST:-0}" = "1" ]; then
  echo "test_grove_shot_parse: ok (FAST=1 — parse only, captures SKIPPED)"
  exit 0
fi

# --- tier 2: it renders what the mode intends ----------------------------------------------
# run_mode <label> <expected-gens> <expected-genbag> <mode> [extra args...]
# Asserts: the run exits 0, prints no script error, writes a non-empty PNG, reports err=0, and
# reports the generator counts the mode is defined by.
run_mode() {
  local label="$1" want_gens="$2" want_bag="$3"; shift 3
  local png="$TMPDIR_RUN/$label.png"
  local log="$TMPDIR_RUN/$label.log"
  local mode="$1"; shift
  if ! "$QUIET" --path . -s "$TOOL" -- "$mode" "$png" "$@" >"$log" 2>&1; then
    cat "$log" >&2
    fail "$label: capture exited non-zero"
  fi
  if grep -qE 'SCRIPT ERROR|Parse Error|Invalid call|Invalid access' "$log"; then
    grep -nE 'SCRIPT ERROR|Parse Error|Invalid call|Invalid access' "$log" >&2
    fail "$label: runtime script error during capture"
  fi
  local line
  line="$(grep -m1 '^SHOT saved=' "$log" || true)"
  [ -n "$line" ] || { cat "$log" >&2; fail "$label: tool printed no SHOT line"; }
  case "$line" in
    *" err=0 "*) ;;
    *) fail "$label: capture reported a non-zero err — $line" ;;
  esac
  [ -s "$png" ] || fail "$label: no PNG written"
  local got_gens got_bag
  got_gens="$(printf '%s\n' "$line" | sed -n 's/.* gens=\([0-9]*\).*/\1/p')"
  got_bag="$(printf '%s\n' "$line" | sed -n 's/.* genbag=\([0-9]*\).*/\1/p')"
  [ -n "$got_gens" ] && [ -n "$got_bag" ] || fail "$label: SHOT line carries no gens=/genbag= — $line"
  [ "$got_gens" = "$want_gens" ] || fail "$label: board carries $got_gens generator(s), expected $want_gens — $line"
  [ "$got_bag" = "$want_bag" ] || fail "$label: stored-generator bag holds $got_bag, expected $want_bag — $line"
  echo "  $label: ok (gens=$got_gens genbag=$got_bag)"
}

# cascade STRIPS every generator after _rebuild_all() re-seeds them — gens MUST be 0. This is the
# assertion the nesting bug fails the moment _rebuild_all seeds no gen NODE.
run_mode cascade_run    0 0 cascade
run_mode cascade_runway 0 0 cascade phase=runway
run_mode cascade_guide  0 0 cascade phase=guide
# baggen SEEDS the stored-generator row via bag_add — genbag MUST be 2 (the pair the overlay's
# generator row exists to show). gens=1 is the fresh board's own starting generator, untouched.
run_mode baggen         1 2 baggen

echo "test_grove_shot_parse: ok"
