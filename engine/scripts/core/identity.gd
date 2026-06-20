extends RefCounted
## PSEUDONYMOUS PLAYER IDENTITY — a stable id the server can target mail (and later anything else) by,
## or "" when there is no identity yet (→ broadcast, no targeting). Kept behind this thin provider so the
## rest of the game stays platform-agnostic and testable.
##
## Backed by Apple GAME CENTER on iOS, via the official GameCenter plugin's `GameCenter` SINGLETON
## (godot-sdk-integrations/godot-ios-plugins). That plugin is iOS-ONLY and async (results arrive on a
## pending-events queue), so EVERYTHING here is guarded by available() — off iOS / without the plugin the
## singleton is absent, boot() is a silent no-op, and player_id() stays "" (the mail sync then omits the
## id header and the server serves broadcast). See docs/design/game-center-setup.md for the native build,
## entitlements, App Store Connect config, and the SERVER-SIDE signature verification the id requires.
##
## API used (verified against the plugin's game_center.mm):
##   GameCenter.authenticate()                         → pushes {type:"authentication", result, player_id, ...}
##   GameCenter.request_identity_verification_signature() → pushes {type:"identity_verification_signature",
##       result, public_key_url, signature, salt, timestamp, player_id}   ← the SERVER verifies this
##   GameCenter.get_pending_event_count() / .pop_pending_event()          ← drain the async results

const Save = preload("res://engine/scripts/core/save.gd")

static var _gc: Object = null
static var _id := ""

## True only on an iOS build that actually bundles the Game Center plugin. The gate for every native call.
static func available() -> bool:
	return Engine.has_singleton("GameCenter")

## The verified Game Center player id, or "" when unknown (→ broadcast). Falls back to the last id cached
## in the save so the header is present immediately on relaunch, before re-auth completes.
static func player_id() -> String:
	if _id != "":
		return _id
	_id = String(Save.grove().get("gc_player_id", ""))
	return _id

## The signed payload the SERVER needs to PROVE the player id (Apple's identity-verification signature).
## {} until sign-in + the signature request complete. The server fetches public_key_url (apple domain),
## rebuilds playerID+bundleID+timestamp+salt, and verifies `signature` before trusting `player_id`.
static func verification() -> Dictionary:
	return Save.grove().get("gc_verify", {})

## Kick off Game Center sign-in and drain its async event queue (caching the id + the verification
## signature). `host` parents the transient poller. No-op off iOS / without the plugin, and once the id
## is already known. Idempotent — safe to call on every home open.
static func boot(host: Node) -> void:
	if not available() or _id != "" or String(Save.grove().get("gc_player_id", "")) != "":
		return
	if _gc == null:
		_gc = Engine.get_singleton("GameCenter")
	_gc.authenticate()                              # Apple's authenticateHandler → results onto the queue
	var poll := Timer.new()
	poll.wait_time = 0.5
	poll.autostart = true
	host.add_child(poll)
	poll.timeout.connect(func() -> void: _drain(poll))

# Drain the plugin's pending-events queue: cache the player id on a successful auth (and request the
# verification signature), cache that signature when it arrives, then stop polling once both are in hand.
static func _drain(poll: Timer) -> void:
	if _gc == null:
		return
	while int(_gc.get_pending_event_count()) > 0:
		var ev: Dictionary = _gc.pop_pending_event()
		match String(ev.get("type", "")):
			"authentication":
				if String(ev.get("result", "")) == "ok":
					_id = String(ev.get("player_id", ""))
					var g := Save.grove()
					g["gc_player_id"] = _id
					Save.grove_write()
					_gc.request_identity_verification_signature()   # for server-side verification
			"identity_verification_signature":
				if String(ev.get("result", "")) == "ok":
					var g := Save.grove()
					g["gc_verify"] = {
						"player_id": String(ev.get("player_id", "")),
						"public_key_url": String(ev.get("public_key_url", "")),
						"signature": String(ev.get("signature", "")),
						"salt": String(ev.get("salt", "")),
						"timestamp": int(ev.get("timestamp", 0)),
					}
					Save.grove_write()
	if _id != "" and not (Save.grove().get("gc_verify", {}) as Dictionary).is_empty():
		if is_instance_valid(poll):
			poll.queue_free()                       # id + signature in hand — stop draining
