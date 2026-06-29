#!/usr/bin/env bash
# Load App Store Connect API credentials for the iOS release tooling
# (tools/release_ios.sh and tools/get_ios_version.sh). SOURCE this — don't execute.
#
# Credentials live OUTSIDE the repo (the dh/ parent dir, next to the .p8) so they are
# never committed — main auto-commits every turn. Override via env if you like:
#   ASC_ENV_FILE   path to the env file            (default <repo-parent>/asc_api.env)
#   ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH      set directly to skip the file
set -euo pipefail

_asc_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_asc_dh="$(dirname "$_asc_root")"
: "${ASC_ENV_FILE:=$_asc_dh/asc_api.env}"

if [ -f "$ASC_ENV_FILE" ]; then
	set -a
	# shellcheck disable=SC1090
	. "$ASC_ENV_FILE"
	set +a
fi

: "${ASC_KEY_PATH:=$_asc_dh/AuthKey_BZBV7L88M3.p8}"

_asc_fail() { echo "asc_credentials: $1" >&2; exit 1; }

[ -n "${ASC_KEY_ID:-}" ]    || _asc_fail "ASC_KEY_ID not set (add it to $ASC_ENV_FILE)"
[ -n "${ASC_ISSUER_ID:-}" ] || _asc_fail "ASC_ISSUER_ID not set — add it to $ASC_ENV_FILE (App Store Connect -> Users and Access -> Integrations -> Issuer ID)"
[ -f "$ASC_KEY_PATH" ]      || _asc_fail "key file not found: $ASC_KEY_PATH"

export ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH
