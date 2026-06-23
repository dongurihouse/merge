extends RefCounted
## PSEUDONYMOUS PLAYER IDENTITY — a stable id the server can target mail (and later anything else) by,
## or "" when there is no identity yet (→ broadcast, no targeting). Thin provider so the rest of the game
## stays platform-agnostic and testable.
##
## Backed by Apple GAME CENTER on iOS via GodotApplePlugins' `GameCenterManager` (+ its `GKLocalPlayer`).
## Those classes exist ONLY in an iOS build that bundles the plugin, so we reach them through ClassDB
## (never a direct symbol — a bare `GameCenterManager` would fail to PARSE on desktop/headless). Off iOS /
## without the plugin, available() is false, boot() is a silent no-op, and player_id() stays "" → the mail
## sync omits the id header and the server serves broadcast. See docs/design/apple-services-setup.md for
## the native install, App Store Connect config, and the SERVER-SIDE signature verification the id needs.
##
## API used (GodotApplePlugins, verified against its GameCenter guide):
##   var gc = GameCenterManager.new(); gc.authenticate()
##     signal authentication_result(status: bool) · authentication_error(error: String)
##   gc.local_player : GKLocalPlayer { is_authenticated: bool, game_player_id: String }
##   gc.local_player.fetch_items_for_identity_verification_signature(func(values: Dictionary, error))

const Save = preload("res://engine/scripts/core/save.gd")
const GC_CLASS := "GameCenterManager"

static var _gc: Object = null                       # the live GameCenterManager (kept so signals survive)
static var _id := ""

## True only on an iOS build that actually bundles the plugin — the gate for every native touch. The
## plugin's macOS frameworks (bundled so its GDExtension loads cleanly in the desktop editor) register
## `GameCenterManager` on the dev Mac too; the `ios` feature check keeps this iPad-only game inert there.
static func available() -> bool:
	return ClassDB.class_exists(GC_CLASS) and OS.has_feature("ios")

## The verified Game Center player id, or "" when unknown (→ broadcast). Falls back to the id cached in
## the save, so the header is present immediately on relaunch, before re-auth completes.
static func player_id() -> String:
	if _id != "":
		return _id
	_id = String(Save.grove().get("gc_player_id", ""))
	return _id

## The signed payload the SERVER needs to PROVE the id (Apple's identity-verification signature): the
## values dict from fetch_items_for_identity_verification_signature. {} until sign-in completes.
static func verification() -> Dictionary:
	return Save.grove().get("gc_verify", {})

## Kick off Game Center sign-in (signal-driven; no polling). No-op off iOS / without the plugin, and once
## the id is already known. Idempotent — safe to call on every home open. `host` is unused (kept for the
## call site's convenience).
static func boot(_host: Node = null) -> void:
	if not available() or _gc != null or player_id() != "":
		return
	_gc = ClassDB.instantiate(GC_CLASS)
	if _gc == null:
		return
	_gc.connect("authentication_error", func(err: String) -> void:
		push_warning("Game Center auth error: %s" % err))
	_gc.connect("authentication_result", func(_status: bool) -> void:
		_on_auth())
	_gc.call("authenticate")

# Sign-in resolved: cache the player id, then fetch the server-verification signature.
static func _on_auth() -> void:
	if _gc == null:
		return
	var lp: Object = _gc.get("local_player")
	if lp == null or not bool(lp.get("is_authenticated")):
		return
	_id = String(lp.get("game_player_id"))
	var g := Save.grove()
	g["gc_player_id"] = _id
	Save.grove_write()
	lp.call("fetch_items_for_identity_verification_signature", func(values: Dictionary, error: Variant) -> void:
		if error == null and values != null and not values.is_empty():
			var gg := Save.grove()
			gg["gc_verify"] = values                # {public_key_url, signature, salt, timestamp, ...}
			Save.grove_write())
