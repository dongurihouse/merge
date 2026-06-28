#!/usr/bin/env bash
# Export the iOS Xcode project, tolerating a known post-export shutdown crash.
#
# The Apple-services plugins (GodotApplePlugins, built on SwiftGodot) are loaded
# into the headless macOS exporter so Godot can introspect their classes. On the
# Xcode Cloud build image, SwiftGodot's runtime segfaults during Godot's OWN
# shutdown — Main::cleanup() -> CallQueue::flush() -> SwiftGodot
# releasePendingObjects() — AFTER the export has fully completed and written the
# Xcode project ("[ DONE ] export" prints first). The crash does not corrupt the
# output; it only makes Godot abort with a non-zero status, which fails the build.
#
# The bug is in the prebuilt upstream framework (we don't build it), and it does
# not reproduce on local Apple-Silicon dev machines — it is specific to the CI
# image's Swift runtime/timing. So: run the export and treat it as successful
# IFF it produced a complete project.pbxproj, surfacing the shutdown crash as a
# warning instead of a hard failure. An export that fails BEFORE producing the
# project still fails the build — the caller wipes build/ios beforehand, so a
# stale project cannot mask a real failure.
set -uo pipefail

PROJECT="${1:?usage: export_ios.sh <project-dir> <xcodeproj-out>}"
OUT="${2:?usage: export_ios.sh <project-dir> <xcodeproj-out>}"
GODOT="${GODOT:-godot}"
PBXPROJ="$OUT/project.pbxproj"

rc=0
"$GODOT" --headless --path "$PROJECT" --export-debug "iOS" "$OUT" || rc=$?

# A real, complete export always writes a project.pbxproj containing a PBXProject
# object. If that is missing, the export genuinely failed — fail the build.
if [ ! -s "$PBXPROJ" ] || ! grep -q 'PBXProject' "$PBXPROJ"; then
	echo "export_ios: export did not produce a valid $PBXPROJ (godot exit $rc)" >&2
	[ "$rc" -ne 0 ] && exit "$rc"
	exit 1
fi

if [ "$rc" -ne 0 ]; then
	echo "export_ios: WARNING — Godot exited $rc AFTER a complete export." >&2
	echo "export_ios: Known SwiftGodot teardown crash on the CI image" >&2
	echo "export_ios: (Main::cleanup -> CallQueue::flush -> releasePendingObjects)." >&2
	echo "export_ios: The Xcode project is fully written; continuing." >&2
fi

echo "export_ios: exported $OUT (godot exit $rc)"
