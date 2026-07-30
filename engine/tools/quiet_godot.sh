#!/bin/bash
## Run godot WITHOUT stealing focus or showing a window — for screenshot/visual tools.
##   engine/tools/quiet_godot.sh --path . -s res://games/grove/tools/grove_shot.gd -- hud /tmp/x.png
##
## PREFER `make shot-batch PLAN=<file>`: many captures in ONE launch. A capture costs a fraction of
## a second on top of ~1.3 s of boot, and each launch is a separate interruption. See CLAUDE.md.
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
## The 1 pt^2 of corner fringe those numbers describe is now 0 as well: a process that is not a
## foreground application (see FOCUS below) has its off-screen window composited nowhere at all.
##
## FOCUS is a SEPARATE problem from visibility, and hiding the window never solved it. The capture
## also became the FRONTMOST APPLICATION — measured, 9,505 ms of a 21 s ten-capture session, worst
## single hold 1,571 ms — because Launch Services activates a freshly launched REGULAR application
## when it checks in. `window/size/no_focus` cannot veto that: it is a WINDOW flag and the theft is
## at the APPLICATION level. engine/tools/nofocus_shim.m, injected below, holds the process at
## activation policy Prohibited instead. AFTER, over the same ten captures: one ~15-25 ms activation
## per launch (178 ms total, NSWorkspace activate/deactivate notifications), and the frontmost
## application polled every 2 ms was never the capture. tools/test_quiet_window.py measures both.
##
## The shim answered that promotion by REACTING to the activation notification until 2026-07-30,
## which only works on the runs where macOS actually activates the capture — and it declines exactly
## when the owner is working in the front app. On those runs the capture stayed foreground-eligible
## for the rest of the launch (measured 606-878 ms) with nothing left to demote it. It now POLLS the
## policy back on the main run loop every 2 ms and answers the promotion whether or not an
## activation follows: 0 ms foreground-eligible over 21 runs, both cases.
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
# FOCUS: keep this run from ever becoming the frontmost application. The engine activates
# ITSELF (DisplayServerMacOS sets the activation policy to Regular and calls
# activateIgnoringOtherApps: ~1-1.5 s into boot), which no project setting can veto — measured,
# a single capture then held the owner's keyboard for the rest of the run. engine/tools/
# nofocus_shim.m is DYLD_INSERT_LIBRARIES'd in to pin the policy Prohibited instead. Built on
# demand, cached, and entirely optional: no clang, or a compile failure, and the run proceeds
# exactly as before (with a warning). TU_NOFOCUS=0 opts out.
# NB the export has to happen HERE, inside the script: bash is SIP-restricted and purges DYLD_*
# from its own inherited environment, so setting it on the caller's command line does nothing.
SHIM_SRC="$DIR/engine/tools/nofocus_shim.m"
SHIM_LIB="$DIR/engine/generated/tu_nofocus.dylib"
if [ "${TU_NOFOCUS:-1}" = "1" ] && [ -f "$SHIM_SRC" ]; then
  if [ ! -f "$SHIM_LIB" ] || [ "$SHIM_SRC" -nt "$SHIM_LIB" ]; then
    mkdir -p "$(dirname "$SHIM_LIB")"
    if command -v clang >/dev/null 2>&1; then
      clang -dynamiclib -O2 -fobjc-arc -framework AppKit -framework Foundation \
        -o "$SHIM_LIB" "$SHIM_SRC" 2>/dev/null || rm -f "$SHIM_LIB"
    fi
  fi
  if [ -f "$SHIM_LIB" ]; then
    export DYLD_INSERT_LIBRARIES="$SHIM_LIB"
  else
    echo "warn: no focus shim (clang missing or build failed) — this capture may steal focus" >&2
  fi
fi
if [ "${WITH_AUDIO:-0}" = "1" ]; then
  "$GODOT_BIN" "${FPS_ARGS[@]}" "$@" &
else
  "$GODOT_BIN" --audio-driver Dummy "${FPS_ARGS[@]}" "$@" &
fi
GPID=$!
rc=0
wait "$GPID" || rc=$?
exit "$rc"
