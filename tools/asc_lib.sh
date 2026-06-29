#!/usr/bin/env bash
# Shared App Store Connect API helpers. SOURCE this — it sources asc_credentials.sh.
#
# Provides:
#   asc_api <path-with-query>      curl the ASC API with a freshly-minted bearer token
#   asc_last_marketing_version     print the marketing version (X.Y.Z) of the most
#                                  recently uploaded build, or empty if none
# Mints an ES256 JWT with openssl (no Python crypto deps); the token is cached per run.
set -euo pipefail

_asclib_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/asc_credentials.sh
. "$_asclib_here/asc_credentials.sh"

ASC_BUNDLE_ID="${ASC_BUNDLE_ID:-com.dongurihouse.acornforest}"
ASC_API_BASE="https://api.appstoreconnect.apple.com/v1"

_asc_b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

asc_jwt() {
	local now exp header payload si der2raw sig
	now=$(date +%s); exp=$((now + 600))   # ASC requires exp <= 20 min after iat
	header=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$ASC_KEY_ID" | _asc_b64url)
	payload=$(printf '{"iss":"%s","iat":%s,"exp":%s,"aud":"appstoreconnect-v1"}' "$ASC_ISSUER_ID" "$now" "$exp" | _asc_b64url)
	si="$header.$payload"
	# ES256: openssl emits a DER ECDSA sig; a JWT needs raw R||S (two 32-byte ints).
	der2raw='import sys
d=sys.stdin.buffer.read()
i=2 if d[1]<0x80 else 2+(d[1]&0x7f)
def rd(b,i):
    assert b[i]==0x02; n=b[i+1]; i+=2
    return b[i:i+n].lstrip(b"\x00").rjust(32,b"\x00"), i+n
r,i=rd(d,i); s,_=rd(d,i)
sys.stdout.buffer.write(r+s)'
	sig=$(printf '%s' "$si" | openssl dgst -sha256 -sign "$ASC_KEY_PATH" -binary | python3 -c "$der2raw" | _asc_b64url)
	printf '%s.%s' "$si" "$sig"
}

_ASC_TOKEN=""
asc_token() { [ -n "$_ASC_TOKEN" ] || _ASC_TOKEN="$(asc_jwt)"; printf '%s' "$_ASC_TOKEN"; }

asc_api() {  # asc_api <path-with-query>
	curl -fsS "$ASC_API_BASE/$1" -H "Authorization: Bearer $(asc_token)"
}

asc_app_id() {  # print the app id for ASC_BUNDLE_ID, or empty
	asc_api "apps?filter%5BbundleId%5D=$ASC_BUNDLE_ID&fields%5Bapps%5D=name" \
		| jq -r '.data[0].id // empty'
}

asc_last_marketing_version() {
	# Print the marketing version (CFBundleShortVersionString train) of the most
	# recently uploaded build; fall back to the build number; empty if no builds.
	local app_id builds
	app_id=$(asc_app_id)
	[ -n "$app_id" ] || return 0
	builds=$(asc_api "builds?filter%5Bapp%5D=$app_id&sort=-uploadedDate&limit=1&include=preReleaseVersion&fields%5Bbuilds%5D=version&fields%5BpreReleaseVersions%5D=version")
	printf '%s' "$builds" | jq -r '
		((.included // []) | map(select(.type=="preReleaseVersions")) | .[0].attributes.version)
		// (.data[0].attributes.version)
		// empty'
}
