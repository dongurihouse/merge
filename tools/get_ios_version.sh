#!/usr/bin/env bash
# Print the last build/version uploaded to App Store Connect for this app. Read-only.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/asc_lib.sh
. "$HERE/asc_lib.sh"

if ! app_json=$(asc_api "apps?filter%5BbundleId%5D=$ASC_BUNDLE_ID&fields%5Bapps%5D=name" 2>/dev/null); then
	echo "get-ios: App Store Connect request failed — check ASC_ISSUER_ID / the API key." >&2
	exit 1
fi
app_id=$(printf '%s' "$app_json" | jq -r '.data[0].id // empty')
if [ -z "$app_id" ]; then
	echo "get-ios: no app found for bundle id $ASC_BUNDLE_ID" >&2
	printf '%s' "$app_json" | jq -r '.errors[]?.detail' 2>/dev/null || true
	exit 1
fi
app_name=$(printf '%s' "$app_json" | jq -r '.data[0].attributes.name // "?"')

# Most recently uploaded build, with its TestFlight (CFBundleShortVersion) train.
builds=$(asc_api "builds?filter%5Bapp%5D=$app_id&sort=-uploadedDate&limit=1&include=preReleaseVersion&fields%5Bbuilds%5D=version,uploadedDate,processingState,expired&fields%5BpreReleaseVersions%5D=version")
printf '%s' "$builds" | jq -r --arg app "$app_name" '
  (.data[0]) as $b
  | ((.included // []) | map(select(.type=="preReleaseVersions")) | .[0].attributes.version) as $mkt
  | if $b == null then "No builds have been uploaded yet for \($app)."
    else
      "App: \($app)\n" +
      "Last upload:\n" +
      "  marketing version : \($mkt // "?")\n" +
      "  build number      : \($b.attributes.version)\n" +
      "  uploaded          : \($b.attributes.uploadedDate)\n" +
      "  processing state  : \($b.attributes.processingState)" +
      (if $b.attributes.expired then "  (expired)" else "" end)
    end'
