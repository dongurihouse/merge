#!/usr/bin/env bash
# Normalize code-signing in the exported iOS Xcode project for automatic signing.
#
# Godot writes CODE_SIGN_IDENTITY = "Apple Distribution" on the Release config while
# also setting CODE_SIGN_STYLE = Automatic. Xcode refuses that combination and reports
# it as "conflicting provisioning settings" or "Signing ... requires a development
# team". With automatic signing the identity must be "Apple Development" — Xcode still
# selects the distribution certificate by itself when you Archive. The development team
# comes from export_presets.cfg `application/app_store_team_id` (Godot emits it as
# DEVELOPMENT_TEAM); we verify it's present so a team-less export fails loudly instead
# of producing a project Xcode can't sign.
#
# Run automatically after `make ios`; safe to re-run (idempotent).
set -euo pipefail

PBX="${1:?usage: normalize_ios_signing.sh <path/to/project.pbxproj>}"

if [ ! -f "$PBX" ]; then
	echo "normalize_ios_signing: no project at $PBX" >&2
	exit 1
fi

# Automatic signing wants the development identity; Archive swaps in distribution itself.
/usr/bin/sed -i '' 's/CODE_SIGN_IDENTITY = "Apple Distribution";/CODE_SIGN_IDENTITY = "Apple Development";/g' "$PBX"

# The development team must be present (Godot derives it from app_store_team_id).
if ! grep -q 'DEVELOPMENT_TEAM = ' "$PBX"; then
	echo "normalize_ios_signing: no DEVELOPMENT_TEAM in $PBX — set application/app_store_team_id in export_presets.cfg" >&2
	exit 1
fi

# Verify the conflicting identity is gone.
if grep -q '"Apple Distribution"' "$PBX"; then
	echo "normalize_ios_signing: 'Apple Distribution' still present in $PBX" >&2
	exit 1
fi

echo "normalize_ios_signing: set Apple Development + automatic signing in $PBX"
