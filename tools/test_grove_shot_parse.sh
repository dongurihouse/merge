#!/usr/bin/env bash
## Guard for games/grove/tools/grove_shot.gd.
##
## Two tiers, because parse-only is not enough. Commit da3099b3 ("Retire generator tier state")
## left two INDENTATION regressions in the `cascade` branch — statements pulled into the loop
## above them. Both parse fine, and one of them (the post-_rebuild_all generator strip nested
## under `if is_instance_valid(n)`) renders a plausible board at exit code 0 with a stray
## generator on it. A `--check-only` run cannot see either.
##
## The same commit also left `place_gen("gen_2", cell, 3)` in the flyaway fixture. That one does not
## even parse-fail: the retired third argument raises at runtime, aborts the seeding, and the sweep
## then animates an empty board into three believable PNGs at err=0.
##
##   default          — parse check PLUS a real capture of the modes those regressions touched, each
##                      asserted on the state the tool PRINTS, not on the exit code.
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
# run_capture <label> <mode> [extra args...]
# One quiet capture. Asserts the run exits 0, prints no script error, writes a non-empty PNG and
# reports err=0. Leaves the log in $CAP_LOG and the SHOT line in $CAP_LINE for the caller's own
# state assertions — the exit code alone is exactly what this guard exists not to trust.
CAP_LOG=""; CAP_LINE=""
run_capture() {
  local label="$1"; shift
  local png="$TMPDIR_RUN/$label.png"
  CAP_LOG="$TMPDIR_RUN/$label.log"
  local mode="$1"; shift
  if ! "$QUIET" --path . -s "$TOOL" -- "$mode" "$png" "$@" >"$CAP_LOG" 2>&1; then
    cat "$CAP_LOG" >&2
    fail "$label: capture exited non-zero"
  fi
  if grep -qE 'SCRIPT ERROR|Parse Error|Invalid call|Invalid access' "$CAP_LOG"; then
    grep -nE 'SCRIPT ERROR|Parse Error|Invalid call|Invalid access' "$CAP_LOG" >&2
    fail "$label: runtime script error during capture"
  fi
  CAP_LINE="$(grep -m1 '^SHOT saved=' "$CAP_LOG" || true)"
  [ -n "$CAP_LINE" ] || { cat "$CAP_LOG" >&2; fail "$label: tool printed no SHOT line"; }
  case "$CAP_LINE" in
    *" err=0 "*) ;;
    *) fail "$label: capture reported a non-zero err — $CAP_LINE" ;;
  esac
  [ -s "$png" ] || fail "$label: no PNG written"
}

# field <name> <line> — the numeric value of `name=N` in a printed status line ("" when absent).
field() { printf '%s\n' "$2" | sed -n "s/.* $1=\([0-9]*\).*/\1/p"; }

# run_mode <label> <expected-gens> <expected-genbag> <mode> [extra args...]
# The generator counts the mode is defined by, read off the SHOT line.
run_mode() {
  local label="$1" want_gens="$2" want_bag="$3"; shift 3
  run_capture "$label" "$@"
  local got_gens got_bag
  got_gens="$(field gens "$CAP_LINE")"
  got_bag="$(field genbag "$CAP_LINE")"
  [ -n "$got_gens" ] && [ -n "$got_bag" ] || fail "$label: SHOT line carries no gens=/genbag= — $CAP_LINE"
  [ "$got_gens" = "$want_gens" ] || fail "$label: board carries $got_gens generator(s), expected $want_gens — $CAP_LINE"
  [ "$got_bag" = "$want_bag" ] || fail "$label: stored-generator bag holds $got_bag, expected $want_bag — $CAP_LINE"
  echo "  $label: ok (gens=$got_gens genbag=$got_bag)"
}

# run_flyaway <expected-pieces>
# flyaway is a SWEEP, and the sweep clears the line it flies away: gens= and genbag= both read 0
# afterwards whether the fixture seeded or not, so those two cannot tell a real capture from a bare
# field. Assert the FLYAWAY fixture line instead — the pre-sweep state the animation is made of.
# This is the mode that rotted for real: a retired third argument on a place_gen call aborted the
# seeding, the sweep then ran on an empty board, and three PNGs of nothing were saved at err=0.
run_flyaway() {
  local want_pieces="$1"
  run_capture flyaway flyaway
  local line got_pieces got_gens got_coins
  line="$(grep -m1 '^FLYAWAY fixture ' "$CAP_LOG" || true)"
  [ -n "$line" ] || { cat "$CAP_LOG" >&2; fail "flyaway: tool printed no FLYAWAY fixture line"; }
  got_gens="$(field gens "$line")"
  got_pieces="$(field pieces "$line")"
  got_coins="$(field coins "$line")"
  [ "$got_gens" = "1" ] || fail "flyaway: $got_gens keepsake generator(s) seeded, expected 1 — $line"
  [ "$got_pieces" = "$want_pieces" ] || fail "flyaway: $got_pieces piece(s) seeded, expected $want_pieces — $line"
  [ -n "$got_coins" ] && [ "$got_coins" -gt 0 ] || fail "flyaway: the sweep would pay $got_coins coins — $line"
  echo "  flyaway: ok (gens=$got_gens pieces=$got_pieces coins=$got_coins)"
}

# cascade STRIPS every generator after _rebuild_all() re-seeds them — gens MUST be 0. This is the
# assertion the nesting bug fails the moment _rebuild_all seeds no gen NODE.
run_mode cascade_run    0 0 cascade
run_mode cascade_runway 0 0 cascade phase=runway
run_mode cascade_guide  0 0 cascade phase=guide
CASCADE_GUIDE_LINE="$(grep -m1 '^CASCADE GUIDE ' "$CAP_LOG" || true)"
[ -n "$CASCADE_GUIDE_LINE" ] || { cat "$CAP_LOG" >&2; fail "cascade_guide: no semantic guide proof line"; }
[ "$(field level "$CASCADE_GUIDE_LINE")" = "7" ] \
  || fail "cascade_guide: capture is not at the L7 cascade gate — $CASCADE_GUIDE_LINE"
[ "$(field armed "$CASCADE_GUIDE_LINE")" = "1" ] \
  || fail "cascade_guide: cascade is not armed — $CASCADE_GUIDE_LINE"
[ "$(field pads "$CASCADE_GUIDE_LINE")" -gt 0 ] \
  || fail "cascade_guide: no illuminated drop pads are live — $CASCADE_GUIDE_LINE"
[ "$(field ladders "$CASCADE_GUIDE_LINE")" -gt 0 ] \
  || fail "cascade_guide: no illuminated ladder is live — $CASCADE_GUIDE_LINE"
echo "  cascade_guide contract: ok ($CASCADE_GUIDE_LINE)"
run_mode cascade_seedguide 0 0 cascade phase=seedguide
run_mode cascade_tagtarget 0 0 cascade phase=tagtarget
# Mastery reveal is not the old static info-row capture: it must be L10, reveal
# through a real still-tap, and freeze while the ring is strictly mid-sweep.
run_capture mastery_reveal mastery phase=reveal
MASTERY_REVEAL_LINE="$(grep -m1 '^MASTERY REVEAL ' "$CAP_LOG" || true)"
[ -n "$MASTERY_REVEAL_LINE" ] || { cat "$CAP_LOG" >&2; fail "mastery_reveal: no semantic reveal proof line"; }
[ "$(field level "$MASTERY_REVEAL_LINE")" = "10" ] \
  || fail "mastery_reveal: capture is not at the L10 mastery gate — $MASTERY_REVEAL_LINE"
[ "$(field armed "$MASTERY_REVEAL_LINE")" = "1" ] \
  || fail "mastery_reveal: mastery is not armed — $MASTERY_REVEAL_LINE"
[ "$(field revealed "$MASTERY_REVEAL_LINE")" = "1" ] \
  || fail "mastery_reveal: real tap did not bank the reveal — $MASTERY_REVEAL_LINE"
[ "$(field ring "$MASTERY_REVEAL_LINE")" = "1" ] \
  || fail "mastery_reveal: tapped generator has no ring — $MASTERY_REVEAL_LINE"
MASTERY_PROGRESS="$(field progress_milli "$MASTERY_REVEAL_LINE")"
[ -n "$MASTERY_PROGRESS" ] && [ "$MASTERY_PROGRESS" -gt 0 ] && [ "$MASTERY_PROGRESS" -lt 500 ] \
  || fail "mastery_reveal: ring is not visibly mid-sweep (0 < progress < 0.5) — $MASTERY_REVEAL_LINE"
echo "  mastery_reveal contract: ok ($MASTERY_REVEAL_LINE)"
# baggen SEEDS the stored-generator row via bag_add — genbag MUST be 2 (the pair the overlay's
# generator row exists to show). gens=1 is the fresh board's own starting generator, untouched.
run_mode baggen         1 2 baggen
# flyaway SEEDS a line and sweeps it — pieces MUST be the fixture's 6 and the payout non-zero.
run_flyaway 6

echo "test_grove_shot_parse: ok"
