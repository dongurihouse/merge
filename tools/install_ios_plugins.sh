#!/usr/bin/env bash
# Install the Apple-services plugin (Game Center + StoreKit) into addons/.
#
# The plugin is GodotApplePlugins (github.com/migueldeicaza/GodotApplePlugins): a
# Godot-4 GDExtension shipping prebuilt binaries. They are large and gitignored
# (.gitignore: /addons/), so — like the baked .ctex caches — they are a
# REGENERABLE per-checkout artifact, fetched by this script rather than committed.
# Run it once per fresh checkout/worktree before `make ios`.
#
# We install three modules (Runtime + GameCenter + StoreKit) with ALL their
# shipped slices: iOS (the export target) AND macOS (so the GDExtension also
# loads cleanly in the desktop editor/headless — no "no library for macos.arm64"
# spam), plus the no-op linux/windows stubs. The native classes therefore DO
# register on the dev Mac, but Store/Identity.available() additionally gate on
# OS.has_feature("ios"), so the iPad-only game stays inert on desktop (and the
# headless test suites keep passing). See docs/design/apple-services-setup.md.
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

# Only the modules this game uses. Runtime is the shared SwiftGodot dependency;
# GameCenter + StoreKit are the providers wired in core/{identity,store}.gd. The
# other shipped modules (ARKit, AVFoundation, …) are intentionally skipped.
MODULES=(
  "GodotApplePluginsRuntime"
  "GodotApplePluginsGameCenter"
  "GodotApplePluginsStoreKit"
)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADDONS="$ROOT/addons"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/godot-apple-plugins"
ZIP="$CACHE/$ASSET"
MARKER="$ADDONS/.installed-tag"

force=0
[ "${1:-}" = "--force" ] && force=1

if [ "$force" = 0 ] && [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "$TAG" ]; then
  echo "Apple-services plugin already installed ($TAG). Use --force to reinstall."
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

# --- extract the modules (whole dirs: shipped .gdextension + every slice) -----
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
PATTERNS=()
for m in "${MODULES[@]}"; do PATTERNS+=("dist/addons/$m/*"); done
echo "Extracting plugin modules…"
unzip -q -o "$ZIP" "${PATTERNS[@]}" -d "$STAGE"

for m in "${MODULES[@]}"; do
  src="$STAGE/dist/addons/$m"
  if [ ! -d "$src" ]; then
    echo "ERROR: module $m missing from the release zip." >&2
    exit 1
  fi
  rm -rf "${ADDONS:?}/$m"
  mkdir -p "$ADDONS"
  cp -R "$src" "$ADDONS/"
done

# Strip macOS quarantine so dyld will load the frameworks in the editor (curl
# downloads usually aren't quarantined, but be safe). No-op on non-macOS.
if command -v xattr >/dev/null 2>&1; then
  xattr -dr com.apple.quarantine "$ADDONS" 2>/dev/null || true
fi

echo "$TAG" > "$MARKER"
echo "Installed Apple-services plugin → addons/ ($(du -sh "$ADDONS" | cut -f1))"
echo "  Game Center + StoreKit (iOS + macOS slices). Run 'make ios' to export."
