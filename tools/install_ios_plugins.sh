#!/usr/bin/env bash
# Install the iOS Apple-services plugin (Game Center + StoreKit) into addons/.
#
# The plugin is GodotApplePlugins (github.com/migueldeicaza/GodotApplePlugins): a
# Godot-4 GDExtension shipping prebuilt binaries. Its xcframeworks are large and
# gitignored (.gitignore: *.xcframework/), so — like the baked .ctex caches — they
# are a REGENERABLE per-checkout artifact, fetched by this script rather than
# committed. Run it once per fresh checkout/worktree before `make ios`.
#
# We install IOS SLICES ONLY (the .xcframework dirs hold just ios-arm64 +
# ios-arm64_x86_64-simulator; the plugin's macOS .framework variants live OUTSIDE
# them and are intentionally NOT fetched). That keeps the host Mac inert: the
# native classes never register on desktop, so Store/Identity.available() stay
# false there and the headless test suites behave exactly as before.
#
# Usage:  tools/install_ios_plugins.sh [--force]
set -euo pipefail

# --- pinned release -----------------------------------------------------------
# NB: the git tag carries a "build-" prefix; the asset filename does NOT.
COMMIT="3781b9c19eaf69b2387eacecf4b6f88fc8d07e65"
TAG="build-${COMMIT}"
ASSET="GodotApplePlugins-addons-${COMMIT}.zip"
URL="https://github.com/migueldeicaza/GodotApplePlugins/releases/download/${TAG}/${ASSET}"
SHA256="f9128c17c2d0128c2d58168c5bb5c795d351cb1333364179fd7a26c39f95ce21"

# Only the modules this game uses. Each entry: "<ModuleDir>:<XCFrameworkName>".
# Runtime is the shared SwiftGodot dependency; GameCenter + StoreKit are the
# providers wired in engine/scripts/core/{identity,store}.gd.
MODULES=(
  "GodotApplePluginsRuntime:SwiftGodotRuntime"
  "GodotApplePluginsGameCenter:GodotApplePluginsGameCenter"
  "GodotApplePluginsStoreKit:GodotApplePluginsStoreKit"
)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADDONS="$ROOT/addons"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/godot-apple-plugins"
ZIP="$CACHE/$ASSET"
MARKER="$ADDONS/.installed-tag"

force=0
[ "${1:-}" = "--force" ] && force=1

if [ "$force" = 0 ] && [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "$TAG" ]; then
  echo "iOS plugins already installed ($TAG). Use --force to reinstall."
  exit 0
fi

# --- download (cached) + verify ----------------------------------------------
mkdir -p "$CACHE"
verify() { echo "$SHA256  $ZIP" | shasum -a 256 -c - >/dev/null 2>&1; }
if [ ! -f "$ZIP" ] || ! verify; then
  echo "Downloading $ASSET (~30 MB)…"
  curl -fSL --retry 3 -o "$ZIP" "$URL"
fi
if ! verify; then
  echo "ERROR: checksum mismatch for $ZIP — refusing to install." >&2
  echo "  expected $SHA256" >&2
  exit 1
fi

# --- extract iOS xcframeworks into addons/ -----------------------------------
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
PATTERNS=()
for entry in "${MODULES[@]}"; do
  dir="${entry%%:*}"; xc="${entry##*:}"
  PATTERNS+=("dist/addons/$dir/bin/$xc.xcframework/*")
done
echo "Extracting iOS slices…"
unzip -q -o "$ZIP" "${PATTERNS[@]}" -d "$STAGE"

for entry in "${MODULES[@]}"; do
  dir="${entry%%:*}"; xc="${entry##*:}"
  src="$STAGE/dist/addons/$dir/bin/$xc.xcframework"
  dst="$ADDONS/$dir/bin"
  if [ ! -d "$src" ]; then
    echo "ERROR: $xc.xcframework missing from the release zip." >&2
    exit 1
  fi
  rm -rf "$dst/$xc.xcframework"
  mkdir -p "$dst"
  cp -R "$src" "$dst/"
done

# --- iOS-only .gdextension files ---------------------------------------------
# Authored here (not copied) so they reference ONLY the ios library + ios
# dependency. The shipped files also list macos/linux/windows binaries we don't
# fetch; dropping those entries is what keeps the host Mac from registering the
# classes. Runtime has no .gdextension — it is a pure dependency.
write_gdext() {
  local dir="$1" sym="$2" xc="$3"
  cat > "$ADDONS/$dir/${4}" <<EOF
[configuration]

entry_symbol = "$sym"
compatibility_minimum = 4.2

[libraries]
ios = "res://addons/$dir/bin/$xc.xcframework"

[dependencies]
ios = { "res://addons/GodotApplePluginsRuntime/bin/SwiftGodotRuntime.xcframework": "" }
EOF
}
write_gdext GodotApplePluginsGameCenter godot_apple_plugins_game_center_start \
  GodotApplePluginsGameCenter godot_apple_plugins_game_center.gdextension
write_gdext GodotApplePluginsStoreKit godot_apple_plugins_storekit_start \
  GodotApplePluginsStoreKit godot_apple_plugins_storekit.gdextension

echo "$TAG" > "$MARKER"
echo "Installed iOS plugins → addons/ ($(du -sh "$ADDONS" | cut -f1))"
echo "  Game Center + StoreKit (iOS slices only). Run 'make ios' to export."
