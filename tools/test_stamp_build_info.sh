#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/tools/stamp_build_info.sh"

fail() {
	echo "test_stamp_build_info: $*" >&2
	exit 1
}

[ -f "$SCRIPT" ] || fail "missing $SCRIPT"
bash -n "$SCRIPT"

PRESETS="$ROOT/export_presets.cfg"
[ -f "$PRESETS" ] || fail "missing $PRESETS"

# The expected values are READ from export_presets.cfg — the file that actually ships the
# version — never re-typed here. Hardcoding them meant the next `make release-ios patch`
# turned this guard (wired into `make test` via test-config) red for no reason.
preset_value() {
	awk -F= -v key="$1" '
		$1 == key { value = $2; gsub(/^"/, "", value); gsub(/"$/, "", value); print value; exit }
	' "$PRESETS"
}

PRESET_MARKETING="$(preset_value "application/short_version")"
PRESET_BUILD="$(preset_value "application/version")"
[ -n "$PRESET_MARKETING" ] || fail "export_presets.cfg has no application/short_version"
[ -n "$PRESET_BUILD" ] || fail "export_presets.cfg has no application/version"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/build_info.gd"

"$SCRIPT" "$OUT" 2.3.4
grep -q 'const MARKETING_VERSION := "2.3.4"' "$OUT" || fail "explicit version was not stamped"
grep -q 'const BUILD_NUMBER := "2.3.4"' "$OUT" || fail "explicit build was not stamped"

CI_BUILD_NUMBER=77 "$SCRIPT" "$OUT"
grep -q "const MARKETING_VERSION := \"$PRESET_MARKETING\"" "$OUT" || fail "bare export did not use export preset marketing version ($PRESET_MARKETING)"
grep -q 'const BUILD_NUMBER := "77"' "$OUT" || fail "bare CI export did not use CI build number"

"$SCRIPT" "$OUT"
grep -q "const MARKETING_VERSION := \"$PRESET_MARKETING\"" "$OUT" || fail "bare local export did not use export preset marketing version ($PRESET_MARKETING)"
grep -q "const BUILD_NUMBER := \"$PRESET_BUILD\"" "$OUT" || fail "bare local export did not use export preset build number ($PRESET_BUILD)"

# The RUNTIME fallback must agree with the same file (engine/scripts/core/build_info.gd parses
# it instead of re-typing a version). A re-typed literal there is what shipped "Version 1.1.9"
# into the Settings dialog of every unstamped build long after the preset moved on.
if grep -qE 'const (MARKETING_VERSION|BUILD_NUMBER) := "[0-9]' "$ROOT/engine/scripts/core/build_info.gd"; then
	fail "engine/scripts/core/build_info.gd re-types a version literal — it must read export_presets.cfg"
fi

echo "test_stamp_build_info: ok"
