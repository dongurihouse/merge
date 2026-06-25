#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT_VERSION="${GODOT_VERSION:-4.6.2}"
GODOT_FLAVOR="${GODOT_FLAVOR:-stable}"
GODOT_TAG="${GODOT_VERSION}-${GODOT_FLAVOR}"
GODOT_TEMPLATE_VERSION="${GODOT_VERSION}.${GODOT_FLAVOR}"
GODOT_RELEASE_BASE="https://github.com/godotengine/godot-builds/releases/download/${GODOT_TAG}"
GODOT_ZIP_NAME="Godot_v${GODOT_TAG}_macos.universal.zip"
GODOT_TEMPLATES_NAME="Godot_v${GODOT_TAG}_export_templates.tpz"
CACHE_ROOT="${GODOT_CI_CACHE_ROOT:-${XDG_CACHE_HOME:-$HOME/Library/Caches}/acorn-forest-xcode-cloud}"
GODOT_INSTALL_DIR="$CACHE_ROOT/Godot_v${GODOT_TAG}"
GODOT_APP="$GODOT_INSTALL_DIR/Godot.app"
GODOT_BIN="$GODOT_APP/Contents/MacOS/Godot"
TEMPLATE_DIR="$HOME/Library/Application Support/Godot/export_templates/$GODOT_TEMPLATE_VERSION"
XCODE_PROJECT="$ROOT/build/ios/AcornForest.xcodeproj"

log() {
	echo "ci_post_clone: $*"
}

download() {
	local url="$1"
	local out="$2"
	local label="$3"
	mkdir -p "$(dirname "$out")"
	if [ -f "$out" ]; then
		log "using cached $label at $out"
		return
	fi

	log "downloading $label"
	rm -f "$out.tmp"
	curl -fL --retry 3 --retry-delay 5 --connect-timeout 30 -o "$out.tmp" "$url"
	mv "$out.tmp" "$out"
}

godot_version_ok() {
	local bin="$1"
	"$bin" --version | grep -q "^${GODOT_TEMPLATE_VERSION}\\."
}

find_existing_godot() {
	if [ -n "${GODOT:-}" ] && command -v "$GODOT" >/dev/null 2>&1; then
		command -v "$GODOT"
		return
	fi

	if command -v godot >/dev/null 2>&1; then
		command -v godot
	fi
}

install_godot() {
	if [ -x "$GODOT_BIN" ] && godot_version_ok "$GODOT_BIN"; then
		log "using cached Godot at $GODOT_BIN"
		return
	fi

	local zip="$CACHE_ROOT/$GODOT_ZIP_NAME"
	local stage="$CACHE_ROOT/godot-unpack"
	download "$GODOT_RELEASE_BASE/$GODOT_ZIP_NAME" "$zip" "Godot $GODOT_TAG"

	rm -rf "$stage" "$GODOT_INSTALL_DIR"
	mkdir -p "$stage" "$GODOT_INSTALL_DIR"
	unzip -q "$zip" -d "$stage"

	local app
	app="$(find "$stage" -maxdepth 2 -type d -name 'Godot.app' -print -quit)"
	if [ -z "$app" ]; then
		echo "ci_post_clone: Godot.app missing after unpacking $zip" >&2
		exit 66
	fi

	mv "$app" "$GODOT_APP"
	if command -v xattr >/dev/null 2>&1; then
		xattr -dr com.apple.quarantine "$GODOT_APP" 2>/dev/null || true
	fi
	chmod +x "$GODOT_BIN"
}

ensure_godot() {
	local existing
	existing="$(find_existing_godot || true)"
	if [ -n "$existing" ] && godot_version_ok "$existing"; then
		GODOT_BIN="$existing"
		log "using Godot from PATH: $GODOT_BIN"
		return
	fi

	if [ -n "$existing" ]; then
		log "ignoring non-$GODOT_TEMPLATE_VERSION Godot at $existing"
	fi
	install_godot
}

install_export_templates() {
	if [ -f "$TEMPLATE_DIR/ios.zip" ]; then
		log "using export templates at $TEMPLATE_DIR"
		return
	fi

	local archive="$CACHE_ROOT/$GODOT_TEMPLATES_NAME"
	local stage="$CACHE_ROOT/templates-unpack"
	download "$GODOT_RELEASE_BASE/$GODOT_TEMPLATES_NAME" "$archive" "Godot $GODOT_TAG export templates"

	rm -rf "$stage" "$TEMPLATE_DIR"
	mkdir -p "$stage" "$TEMPLATE_DIR"
	unzip -q "$archive" -d "$stage"

	if [ -d "$stage/templates" ]; then
		cp -R "$stage/templates/." "$TEMPLATE_DIR/"
	else
		cp -R "$stage/." "$TEMPLATE_DIR/"
	fi

	if [ ! -f "$TEMPLATE_DIR/ios.zip" ]; then
		echo "ci_post_clone: iOS export template missing after installing $archive" >&2
		exit 66
	fi
}

log "preparing generated iOS project for Xcode Cloud"
ensure_godot
install_export_templates

export GODOT="$GODOT_BIN"
log "exporting build/ios/AcornForest.xcodeproj"
make ios

if [ ! -f "$XCODE_PROJECT/project.pbxproj" ]; then
	echo "ci_post_clone: expected generated project at $XCODE_PROJECT" >&2
	exit 66
fi

log "generated $XCODE_PROJECT"
