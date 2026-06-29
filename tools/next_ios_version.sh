#!/usr/bin/env bash
# Compute the next iOS version by bumping the last version UPLOADED to App Store Connect.
#
#   tools/next_ios_version.sh patch   1.1.1 -> 1.1.2
#   tools/next_ios_version.sh minor   1.1.1 -> 1.2.0
#   tools/next_ios_version.sh major   1.1.1 -> 2.0.0
#
# Basing the bump on the last UPLOADED version (not a local file) means the result can
# never collide with an existing build number. Prints just the new version to stdout.
set -euo pipefail

BUMP="${1:?usage: next_ios_version.sh <major|minor|patch>}"
case "$BUMP" in
	major|minor|patch) ;;
	*) echo "next_ios_version: expected major|minor|patch, got '$BUMP'" >&2; exit 1 ;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/asc_lib.sh
. "$HERE/asc_lib.sh"

base=$(asc_last_marketing_version)
base="${base:-0.0.0}"

IFS=. read -r MA MI PA _rest <<EOF
$base
EOF
MA="${MA:-0}"; MI="${MI:-0}"; PA="${PA:-0}"
for n in "$MA" "$MI" "$PA"; do
	[[ "$n" =~ ^[0-9]+$ ]] || { echo "next_ios_version: last uploaded version '$base' is not numeric X.Y.Z" >&2; exit 1; }
done

case "$BUMP" in
	major) MA=$((MA + 1)); MI=0; PA=0 ;;
	minor) MI=$((MI + 1)); PA=0 ;;
	patch) PA=$((PA + 1)) ;;
esac

printf '%s.%s.%s\n' "$MA" "$MI" "$PA"
