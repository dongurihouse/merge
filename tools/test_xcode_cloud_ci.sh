#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/ci_scripts/ci_post_clone.sh"

fail() {
	echo "test_xcode_cloud_ci: $*" >&2
	exit 1
}

[ -f "$SCRIPT" ] || fail "missing $SCRIPT"
[ -x "$SCRIPT" ] || fail "$SCRIPT is not executable"
bash -n "$SCRIPT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/repo/ci_scripts" "$TMP/bin"
cp "$SCRIPT" "$TMP/repo/ci_scripts/ci_post_clone.sh"

mkdir -p "$TMP/home/Library/Application Support/Godot/export_templates/4.6.2.stable"
touch "$TMP/home/Library/Application Support/Godot/export_templates/4.6.2.stable/ios.zip"

cat > "$TMP/bin/godot" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "--version" ]; then
	echo "4.6.2.stable.official.fake"
	exit 0
fi

echo "unexpected godot invocation: $*" >&2
exit 65
SH
chmod +x "$TMP/bin/godot"

cat > "$TMP/bin/make" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

[ "${1:-}" = "ios" ] || {
	echo "unexpected make target: $*" >&2
	exit 65
}
[ -n "${GODOT:-}" ] || {
	echo "GODOT env var was not exported" >&2
	exit 65
}

"$GODOT" --version >/dev/null
touch .make-ios-called
mkdir -p build/ios/AcornForest.xcodeproj
printf "fake pbxproj\n" > build/ios/AcornForest.xcodeproj/project.pbxproj
SH
chmod +x "$TMP/bin/make"

(
	cd "$TMP/repo"
	HOME="$TMP/home" PATH="$TMP/bin:$PATH" ci_scripts/ci_post_clone.sh
)

[ -f "$TMP/repo/.make-ios-called" ] || fail "ci_post_clone.sh did not run make ios"
[ -f "$TMP/repo/build/ios/AcornForest.xcodeproj/project.pbxproj" ] || {
	fail "ci_post_clone.sh did not leave the generated Xcode project in place"
}

echo "test_xcode_cloud_ci: ok"
