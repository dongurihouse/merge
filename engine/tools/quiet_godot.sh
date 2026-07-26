#!/bin/bash
## Run godot WITHOUT stealing focus or showing a window — for screenshot/visual tools.
##   engine/tools/quiet_godot.sh --path . -s res://games/grove/tools/grove_shot.gd -- hud /tmp/x.png
##
## How: drops a temporary override.cfg so the window is BORN minimized + no-focus
## (flags applied at window creation — setting them from script code is too late,
## the window has already flashed and grabbed focus by then). Verified: the app
## never becomes frontmost; captures render fine from the minimized window and
## come out at full project resolution (no screen clamping). Only trace: a brief
## Dock icon. Removes override.cfg when done.
##
## Cleanup is robust: INT/TERM/HUP are trapped (a timed-out/killed run still
## removes the file), and a leftover override.cfg from a SIGKILL'd run is
## RECLAIMED on the next invocation (recognized by our no_focus marker line) —
## it never survives past the next quiet run. An override.cfg with FOREIGN
## content refuses the run (exit 2) rather than running loud or clobbering it.
## Quiet runs are serial by law, so always-owning the file is safe.
##
## Caveat: if you launch the game normally WHILE a quiet run is in flight, your
## window starts minimized too — just click it in the Dock.
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
printf '[display]\nwindow/size/no_focus=true\nwindow/size/mode=1\n' > "$OVR"
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
if [ "${WITH_AUDIO:-0}" = "1" ]; then
  godot "${FPS_ARGS[@]}" "$@" &
else
  godot --audio-driver Dummy "${FPS_ARGS[@]}" "$@" &
fi
GPID=$!
rc=0
wait "$GPID" || rc=$?
exit "$rc"
