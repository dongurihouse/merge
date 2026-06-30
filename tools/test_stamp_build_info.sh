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

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/build_info.gd"

"$SCRIPT" "$OUT" 2.3.4
grep -q 'const MARKETING_VERSION := "2.3.4"' "$OUT" || fail "explicit version was not stamped"
grep -q 'const BUILD_NUMBER := "2.3.4"' "$OUT" || fail "explicit build was not stamped"

CI_BUILD_NUMBER=77 "$SCRIPT" "$OUT"
grep -q 'const MARKETING_VERSION := "1.1.9"' "$OUT" || fail "bare export did not use export preset marketing version"
grep -q 'const BUILD_NUMBER := "77"' "$OUT" || fail "bare CI export did not use CI build number"

"$SCRIPT" "$OUT"
grep -q 'const MARKETING_VERSION := "1.1.9"' "$OUT" || fail "bare local export did not use export preset marketing version"
grep -q 'const BUILD_NUMBER := "1.1.9"' "$OUT" || fail "bare local export did not use export preset build number"

echo "test_stamp_build_info: ok"
