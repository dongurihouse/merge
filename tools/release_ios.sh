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
TEAM_ID="${ASC_TEAM_ID:-7F5H5YC2UT}"

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
