#!/bin/bash
## App Store screenshot refresh — captures the release set (splash · restored home · played board)
## at the store's exact iPhone + iPad sizes and drops them into appstore_screenshots/.
##
##   games/grove/tools/release_screenshots.sh [OUT_DIR]
##
## OUT_DIR defaults to appstore_screenshots/ at the repo root. Run from any checkout; uses the
## quiet capture harness (born-minimized window — never steals focus). ~2-3 min total.
##
## Sizes (App Store Connect requirements):
##   iPhone 6.7"  1284x2778  → OUT_DIR/01_title_splash.png · 02_restored_world.png · 03_merge_board.png
##   iPad 12.9"   2048x2732  → OUT_DIR/ipad/00_title_splash.png · 01_homestead.png · 02_merge_board.png
##
## The states are staged by the shot tools themselves (deterministic seeds, own temp saves):
##   splash — boot.gd capture mode, `noload` hides the progress bar (clean key art)
##   home   — map_shot `owned` (every spot + cluster unlocked → fully restored scene)
##   board  — grove_shot `played` (merges done, seeds popped: items + generators + quests)
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT="${1:-$REPO/appstore_screenshots}"
QUIET="$REPO/engine/tools/quiet_godot.sh"
IPHONE=1284x2778
IPAD=2048x2732

mkdir -p "$OUT/ipad"
cd "$REPO"

echo "== iPhone ($IPHONE) =="
"$QUIET" --path . -s res://engine/tools/boot_splash_shot.gd -- "$OUT/01_title_splash.png" $IPHONE noload | grep -E "saved|REFUSED" || true
"$QUIET" --path . -s res://games/grove/tools/map_shot.gd -- owned "$OUT/02_restored_world.png" $IPHONE noftue=1 | grep -E "SHOT|REFUSED" || true
"$QUIET" --path . -s res://games/grove/tools/grove_shot.gd -- played "$OUT/03_merge_board.png" $IPHONE | grep -E "SHOT|REFUSED" || true

echo "== iPad ($IPAD) =="
"$QUIET" --path . -s res://engine/tools/boot_splash_shot.gd -- "$OUT/ipad/00_title_splash.png" $IPAD noload | grep -E "saved|REFUSED" || true
"$QUIET" --path . -s res://games/grove/tools/map_shot.gd -- owned "$OUT/ipad/01_homestead.png" $IPAD noftue=1 | grep -E "SHOT|REFUSED" || true
"$QUIET" --path . -s res://games/grove/tools/grove_shot.gd -- played "$OUT/ipad/02_merge_board.png" $IPAD | grep -E "SHOT|REFUSED" || true

echo "== verify sizes =="
fail=0
check() {  # check <file> <WxH>
	local wh
	wh=$(python3 -c 'import sys,struct; h=open(sys.argv[1],"rb").read(24); w,ht=struct.unpack(">II",h[16:24]); print(f"{w}x{ht}")' "$1")
	if [ "$wh" != "$2" ]; then echo "  BAD  $1 is $wh (want $2)"; fail=1; else echo "  ok   $1 ($wh)"; fi
}
for f in 01_title_splash 02_restored_world 03_merge_board; do check "$OUT/$f.png" $IPHONE; done
for f in 00_title_splash 01_homestead 02_merge_board; do check "$OUT/ipad/$f.png" $IPAD; done
[ "$fail" = 0 ] && echo "ALL SCREENSHOTS OK → $OUT" || { echo "SIZE MISMATCH — see above"; exit 1; }
