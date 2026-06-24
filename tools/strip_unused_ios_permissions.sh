#!/usr/bin/env bash
# Strip unused privacy usage-description keys from the exported iOS Info.plist.
#
# Godot 4.6's iOS export template HARDCODES NSCameraUsageDescription /
# NSPhotoLibraryUsageDescription / NSMicrophoneUsageDescription with $placeholder
# values (godot_apple_embedded-Info.plist). The game uses none of those APIs, so
# the placeholders resolve to EMPTY strings — and App Store review rejects an app
# that declares a privacy key with a blank purpose string. We don't use the
# features, so the correct fix is to remove the keys entirely (not invent text).
#
# Run automatically after `make ios`; safe to re-run (idempotent). Fails loudly if
# the target plist is missing or a key survives, so a renamed export can't silently
# ship the empty strings.
set -euo pipefail

PLIST="${1:?usage: strip_unused_ios_permissions.sh <path/to/App-Info.plist>}"

if [ ! -f "$PLIST" ]; then
	echo "strip_unused_ios_permissions: no plist at $PLIST" >&2
	exit 1
fi

KEYS=(NSCameraUsageDescription NSPhotoLibraryUsageDescription NSMicrophoneUsageDescription)

for k in "${KEYS[@]}"; do
	# Delete is a no-op-with-error when the key is already gone; tolerate that.
	/usr/libexec/PlistBuddy -c "Delete :$k" "$PLIST" 2>/dev/null || true
done

# Verify removal — if the plist format changed under us, fail rather than ship.
for k in "${KEYS[@]}"; do
	if /usr/libexec/PlistBuddy -c "Print :$k" "$PLIST" >/dev/null 2>&1; then
		echo "strip_unused_ios_permissions: $k still present in $PLIST" >&2
		exit 1
	fi
done

echo "strip_unused_ios_permissions: removed unused camera/photo/mic keys from $PLIST"
