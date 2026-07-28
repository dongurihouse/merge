#!/bin/bash
## Run godot WITHOUT stealing focus or showing a window — for screenshot/visual tools.
##   engine/tools/quiet_godot.sh --path . -s res://games/grove/tools/grove_shot.gd -- hud /tmp/x.png
##
## How: drops a temporary override.cfg so the window is BORN 1x1, borderless, no-focus,
## and pinned to the far corner — geometry applied at window creation, because script
## code runs ~460 ms after the window is already composited. Godot CLAMPS a birth
## position into the screen's usable rect, so the corner is the furthest out a window
## can be born; at 1x1 borderless that clamp lands the window's CONTENT one point PAST the
## screen edge. shot_base.begin() then moves it to (-32000, -32000) (window_set_position is
## NOT clamped) and sizes it there. Removes override.cfg when done.
##
## MEASURED (CGWindowListCopyWindowInfo, .optionOnScreenOnly, 40 ms sampling, filtered to
## the capture pid, intersected with the real display rects):
##
##                          BEFORE                          AFTER
##   shot-grove/-map        ~880 ms of 1192x1051            240 ms of 3x3 at the corner
##   shot-widget            ~840 ms of 1193x1051            240 ms of 3x3 at the corner
##   shot-workbench        ~2520 ms of 1840x982             240 ms of 3x3 at the corner
##   shot-sw / -fx-wb   ~880 / ~1200 ms of ~1500x982        240 ms of 3x3 at the corner
##
## NOT zero, and the residue is the floor, not an oversight: macOS reports the 1x1 window's
## frame one point larger on every side, so a single corner POINT of it touches the screen
## for the ~240 ms of engine boot before begin() runs. 1 pt^2 against the old 1,239,000.
## A window cannot be born fully off-screen here — Godot's birth clamp sees to that.
##
## The old recipe's ~1000 ms was ~460 ms of engine boot plus ~560 ms of macOS's SYNCHRONOUS
## minimize animation. `window/size/mode=1` never worked: window_get_mode() read WINDOWED at
## script entry, so the old "quiet" was really the in-script minimize — and it was only ever
## verified against FOCUS (lsappinfo front), never against visibility.
## tools/test_quiet_window.py is the guard that keeps this honest (it re-measures on every
## `make test-config`, and it FAILS on the old recipe).
##
## Cleanup is robust: INT/TERM/HUP are trapped (a timed-out/killed run still
## removes the file), and a leftover override.cfg from a SIGKILL'd run is
## RECLAIMED on the next invocation (recognized by our no_focus marker line) —
## it never survives past the next quiet run. An override.cfg with FOREIGN
## content refuses the run (exit 2) rather than running loud or clobbering it.
## Quiet runs are serial by law, so always-owning the file is safe.
##
## Caveat: if you launch the game normally WHILE a quiet run is in flight, your
## window starts as a 1x1 borderless speck off the corner of the screen — the game
## self-heals it at boot (map.gd `_heal_capture_flags` + Design.fit_desktop_window).
##
## AUDIO: debug runs are SILENT (--audio-driver Dummy) — no taps/poofs through the
## owner's speakers. Testing sound specifically? WITH_AUDIO=1 engine/tools/quiet_godot.sh …
##
## TIME: runs use --fixed-fps, so every frame's delta is exactly 1/N second instead of however
## long the machine took. Without it a capture samples idle animations (a generator's breathe,
## a pulsing badge) at whatever phase wall-clock jitter left them in — two runs of identical
## code then differ, and a before/after pixel diff proves nothing. With it, the same tool +
## the same mode produce a byte-identical PNG. Override with TU_FIXED_FPS=<n>; TU_FIXED_FPS=0
## restores real-time pacing (only useful when investigating genuinely timing-dependent behaviour).
set -e
# Project root = where godot's --path points (override.cfg must land there). Walk up
# from this script to the dir holding project.godot, so the script's depth under the
# repo (it now lives at engine/tools/) doesn't matter.
DIR="$(cd "$(dirname "$0")" && pwd)"
while [ "$DIR" != "/" ] && [ ! -f "$DIR/project.godot" ]; do DIR="$(dirname "$DIR")"; done
OVR="$DIR/override.cfg"
if [ -f "$OVR" ] && ! grep -q 'window/size/no_focus=true' "$OVR"; then
  echo "REFUSED: $OVR exists with foreign content — won't clobber it or run loud." >&2
  exit 2
fi
# Create fresh — or reclaim a stale leftover from a killed run. Either way it's ours.
# no_focus doubles as the OWNERSHIP MARKER (grepped above, and by map.gd's boot self-heal),
# so it must stay on its own line and stay first.
printf '%s\n' \
  '[display]' \
  'window/size/no_focus=true' \
  'window/size/borderless=true' \
  'window/size/initial_position_type=0' \
  'window/size/initial_position=Vector2i(30000, 30000)' \
  'window/size/window_width_override=1' \
  'window/size/window_height_override=1' > "$OVR"
GPID=""
cleanup() { rm -f "$OVR"; }
on_sig() {
  # forward to godot so the run stops NOW (bash defers traps while waiting on a
  # foreground child — hence background + wait below), then clean up and exit
  [ -n "$GPID" ] && kill -TERM "$GPID" 2>/dev/null
  [ -n "$GPID" ] && wait "$GPID" 2>/dev/null
  exit "$1"
}
trap cleanup EXIT
trap 'on_sig 130' INT
trap 'on_sig 143' TERM
trap 'on_sig 129' HUP
# TU_QUIET marks this as a capture run: the game's boot self-heal (which would
# un-minimize a real launch born under our flags) must NOT touch these windows.
export TU_QUIET=1
FPS_ARGS=()
[ "${TU_FIXED_FPS:-60}" != "0" ] && FPS_ARGS=(--fixed-fps "${TU_FIXED_FPS:-60}")
# Honour the same $GODOT override the Makefile advertises and run_suites.py already
# respects — otherwise `make shot GODOT=/path/to/pinned-godot` silently captured with
# whatever `godot` happened to be on PATH (a different engine build), while `make test`
# with the same override used the pinned one.
GODOT_BIN="${GODOT:-godot}"
if [ "${WITH_AUDIO:-0}" = "1" ]; then
  "$GODOT_BIN" "${FPS_ARGS[@]}" "$@" &
else
  "$GODOT_BIN" --audio-driver Dummy "${FPS_ARGS[@]}" "$@" &
fi
GPID=$!
rc=0
wait "$GPID" || rc=$?
exit "$rc"
