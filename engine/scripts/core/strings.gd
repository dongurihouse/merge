extends RefCounted
## Strings — the screen-text catalog. ALL user-facing UI text lives in one structured JSON
## (res://games/<active>/strings.json), organised by screen → dialog → element, so the copy can be
## edited in one place (and localised later) without touching code. Replaces scattered inline tr("…").
##
## Usage: Strings.t("shop.info.welcome.title") → "Welcome". Format strings keep their %d/%s and the
## caller formats: Strings.t("shop.free.ready_in") % minutes. A MISSING path returns the path itself
## (e.g. "shop.info.welcome.title" shows on screen) so gaps are obvious, never a crash.

const Game = preload("res://engine/scripts/core/game.gd")

static var _data: Dictionary = {}
static var _loaded := false

# The active game's catalog path (mirrors Game.art/font resolution off games/active.gd).
static func _path() -> String:
	return "res://games/%s/strings.json" % Game.active()

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var p := _path()
	if not FileAccess.file_exists(p):
		push_warning("Strings: no catalog at %s — every key shows its path" % p)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if parsed is Dictionary:
		_data = parsed
	else:
		push_warning("Strings: %s is not a JSON object" % p)

# Resolve a dotted path to its string. Missing path / non-string leaf → the path itself (visible).
static func t(path: String) -> String:
	_ensure_loaded()
	var node: Variant = _data
	for part in path.split("."):
		if node is Dictionary and (node as Dictionary).has(part):
			node = (node as Dictionary)[part]
		else:
			return path
	return String(node) if node is String else path

# Test hook: drop the cache so a suite that rewrites the catalog re-reads it.
static func _reset() -> void:
	_loaded = false
	_data = {}

# Test hook: the loaded catalog (for the strings suite's "non-empty" check).
static func _data_for_test() -> Dictionary:
	_ensure_loaded()
	return _data
