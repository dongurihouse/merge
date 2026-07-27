#!/usr/bin/env bash
# Archive the exported iOS app and upload it to App Store Connect (TestFlight).
#
# Assumes `make ios <version>` has already run (the Makefile `release-ios` target does
# that first), so build/ios/AcornForest.xcodeproj is freshly exported and stamped at the
# target version. Signing + upload use the App Store Connect API key (automatic signing,
# distribution cert + profile fetched on the fly via -allowProvisioningUpdates).
set -euo pipefail

VERSION="${1:?usage: release_ios.sh <version>}"
if ! [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
	echo "release_ios: '$VERSION' is not a valid version (expected N, N.N, or N.N.N)" >&2
	exit 1
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
# shellcheck source=tools/asc_credentials.sh
. "$HERE/asc_credentials.sh"

PROJECT="$ROOT/build/ios/AcornForest.xcodeproj"
ARCHIVE="$ROOT/build/ios/AcornForest.xcarchive"
EXPORT_DIR="$ROOT/build/ios/export"
PLIST="$ROOT/build/ios/ExportOptions.plist"
SCHEME="AcornForest"

# The team id is READ from export_presets.cfg (application/app_store_team_id) — the id that
# actually signed the archive — never re-typed here. Two different ids in one build fail
# `xcodebuild -exportArchive` at UPLOAD time, after a full archive has already been made.
# Same awk parse as tools/stamp_build_info.sh; ASC_TEAM_ID still overrides for a one-off.
preset_value() {
	awk -F= -v key="$1" '
		$1 == key { value = $2; gsub(/^"/, "", value); gsub(/"$/, "", value); print value; exit }
	' "$ROOT/export_presets.cfg"
}
TEAM_ID="${ASC_TEAM_ID:-$(preset_value "application/app_store_team_id")}"
[ -n "$TEAM_ID" ] || { echo "release_ios: export_presets.cfg has no application/app_store_team_id" >&2; exit 1; }

[ -d "$PROJECT" ] || { echo "release_ios: $PROJECT missing — run 'make ios $VERSION' first" >&2; exit 1; }

echo "==> Archiving $SCHEME $VERSION"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
xcodebuild archive \
	-project "$PROJECT" \
	-scheme "$SCHEME" \
	-configuration Release \
	-destination 'generic/platform=iOS' \
	-archivePath "$ARCHIVE" \
	-allowProvisioningUpdates \
	-authenticationKeyPath "$ASC_KEY_PATH" \
	-authenticationKeyID "$ASC_KEY_ID" \
	-authenticationKeyIssuerID "$ASC_ISSUER_ID"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>destination</key><string>upload</string>
	<key>teamID</key><string>$TEAM_ID</string>
	<key>signingStyle</key><string>automatic</string>
	<key>uploadSymbols</key><true/>
</dict>
</plist>
PLIST

echo "==> Exporting + uploading to App Store Connect"
xcodebuild -exportArchive \
	-archivePath "$ARCHIVE" \
	-exportPath "$EXPORT_DIR" \
	-exportOptionsPlist "$PLIST" \
	-allowProvisioningUpdates \
	-authenticationKeyPath "$ASC_KEY_PATH" \
	-authenticationKeyID "$ASC_KEY_ID" \
	-authenticationKeyIssuerID "$ASC_ISSUER_ID"

echo "==> Uploaded $SCHEME $VERSION (build $VERSION) to App Store Connect."
echo "    It appears in TestFlight after processing — check with:  make get-ios"
