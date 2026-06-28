#!/usr/bin/env bash
# Stamp the iOS app version into the generated Xcode project (run after the export).
#
#   make ios 1.2.3   ->  marketing version (CFBundleShortVersionString) AND build number
#                        (CFBundleVersion) become 1.2.3 — the number you pass IS the app version.
#                        Bump it every upload (App Store rejects a re-used version).
#   make ios         ->  keeps the marketing version from export_presets.cfg; on Xcode Cloud the build
#                        number is set to the monotonic $CI_BUILD_NUMBER so every CI upload is unique.
#
# Godot bakes both fields from export_presets.cfg; the generated pbxproj carries them as MARKETING_VERSION
# and CURRENT_PROJECT_VERSION (the Info.plist references both via $(...)). We rewrite the GENERATED pbxproj
# rather than export_presets.cfg, so the repo stays clean (no version churn) — matching
# strip_unused_ios_permissions.sh / normalize_ios_signing.sh. Idempotent; safe to re-run.
set -euo pipefail

PBX="${1:?usage: set_ios_version.sh <path/to/project.pbxproj> [version]}"
VERSION="${2:-}"

if [ ! -f "$PBX" ]; then
	echo "set_ios_version: no project at $PBX" >&2
	exit 1
fi

# A version is 1–3 dot-separated integers (valid for BOTH CFBundleShortVersionString and CFBundleVersion).
# Validate before it reaches sed — rejects typos and blocks any injection through the replacement.
if [ -n "$VERSION" ] && ! [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
	echo "set_ios_version: '$VERSION' is not a valid version (expected N, N.N, or N.N.N)" >&2
	exit 1
fi

# Marketing version (the user-facing "1.2.3") — only when a version was passed.
if [ -n "$VERSION" ]; then
	/usr/bin/sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $VERSION;/g" "$PBX"
	echo "set_ios_version: marketing version (CFBundleShortVersionString) = $VERSION"
fi

# Build number: the explicit version if given, else Xcode Cloud's monotonic $CI_BUILD_NUMBER (CI only).
BUILD="${VERSION:-${CI_BUILD_NUMBER:-}}"
if [ -n "$BUILD" ]; then
	/usr/bin/sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $BUILD;/g" "$PBX"
	echo "set_ios_version: build number (CFBundleVersion) = $BUILD"
fi
