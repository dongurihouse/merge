#!/bin/bash
## Run godot WITHOUT stealing focus or showing a window — for screenshot/visual tools.
##   tools/quiet_godot.sh --path . -s res://tools/board_shot.gd -- tidy_01 /tmp/x.png
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
## owner's speakers. Testing sound specifically? WITH_AUDIO=1 tools/quiet_godot.sh …
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
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
if [ "${WITH_AUDIO:-0}" = "1" ]; then
  godot "$@" &
else
  godot --audio-driver Dummy "$@" &
fi
GPID=$!
rc=0
wait "$GPID" || rc=$?
exit "$rc"
