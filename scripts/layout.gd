extends RefCounted
## Placement overrides — the owner's drag-to-place editor (home.gd place mode)
## WRITES here; the renderers READ positions through here. Every value is keyed
## by a STABLE id (zone id, spot id) so reordering grove_content never desyncs a
## saved position. An ABSENT file means pure grove_content defaults — i.e. zero
## behaviour change until something is actually placed.
##
## One file, committed with the repo: res://data/placements.json. A user:// mirror
## is the live-edit fallback for when res:// is read-only (exported builds); when
## both exist they are written in lockstep, so load order is moot.
##
## Why this exists (owner 2026-06-12): a building sprite is anchored by its CENTER
## to map_pos, but its visual BASE must sit on the painted clearing — the gap
## between the two depends on each sprite's transparent padding, so hand-tuning
## fractions is hopeless. The owner drags the real art onto the real ground; we
## store whatever lands it right.

const G = preload("res://scripts/grove_content.gd")

const RES_PATH := "res://data/placements.json"
const USER_PATH := "user://placements.json"

static var _data: Dictionary = {}      # {"zones": {id: {map_pos:[x,y]}}, "spots": {id: {pos:[x,y], fsize:f}}}
static var _loaded := false

# --- loading -----------------------------------------------------------------------

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_data = {"zones": {}, "spots": {}}
	var raw := ""
	# user:// first (the latest local edits), then the committed res:// baseline.
	for p in [USER_PATH, RES_PATH]:
		if FileAccess.file_exists(p):
			var f := FileAccess.open(p, FileAccess.READ)
			if f != null:
				raw = f.get_as_text()
				f.close()
				if raw.strip_edges() != "":
					break
	if raw.strip_edges() == "":
		return
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		_data.zones = (parsed as Dictionary).get("zones", {})
		_data.spots = (parsed as Dictionary).get("spots", {})

static func _arr_to_v2(a: Variant, fallback: Vector2) -> Vector2:
	if a is Array and (a as Array).size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return fallback

# --- read accessors (renderers call these instead of grove_content directly) -------

static func zone_map_pos(z: int) -> Vector2:
	_ensure()
	var dflt := Vector2(G.ZONES[z].map_pos)
	var o: Variant = _data.zones.get(String(G.ZONES[z].id), null)
	if o is Dictionary and (o as Dictionary).has("map_pos"):
		return _arr_to_v2((o as Dictionary).map_pos, dflt)
	return dflt

static func spot_pos(z: int, k: int) -> Vector2:
	_ensure()
	var dflt := Vector2(G.ZONES[z].spots[k].pos)
	var o: Variant = _data.spots.get(String(G.ZONES[z].spots[k].id), null)
	if o is Dictionary and (o as Dictionary).has("pos"):
		return _arr_to_v2((o as Dictionary).pos, dflt)
	return dflt

static func spot_fsize(z: int, k: int) -> float:
	_ensure()
	var dflt := float(G.ZONES[z].spots[k].get("fsize", 240.0))
	var o: Variant = _data.spots.get(String(G.ZONES[z].spots[k].id), null)
	if o is Dictionary and (o as Dictionary).has("fsize"):
		return float((o as Dictionary).fsize)
	return dflt

static func zone_overridden(z: int) -> bool:
	_ensure()
	return _data.zones.has(String(G.ZONES[z].id))

static func spot_overridden(z: int, k: int) -> bool:
	_ensure()
	return _data.spots.has(String(G.ZONES[z].spots[k].id))

# --- write (in-memory; flush with save()) ------------------------------------------

static func set_zone_map_pos(z: int, v: Vector2) -> void:
	_ensure()
	var id := String(G.ZONES[z].id)
	if not _data.zones.has(id):
		_data.zones[id] = {}
	_data.zones[id]["map_pos"] = [snappedf(clampf(v.x, 0.0, 1.0), 0.0001), snappedf(clampf(v.y, 0.0, 1.0), 0.0001)]

static func set_spot_pos(z: int, k: int, v: Vector2) -> void:
	_ensure()
	var id := String(G.ZONES[z].spots[k].id)
	if not _data.spots.has(id):
		_data.spots[id] = {}
	_data.spots[id]["pos"] = [snappedf(clampf(v.x, 0.0, 1.0), 0.0001), snappedf(clampf(v.y, 0.0, 1.0), 0.0001)]

static func set_spot_fsize(z: int, k: int, f: float) -> void:
	_ensure()
	var id := String(G.ZONES[z].spots[k].id)
	if not _data.spots.has(id):
		_data.spots[id] = {}
	_data.spots[id]["fsize"] = snappedf(clampf(f, 40.0, 700.0), 1.0)

static func reset_zone(z: int) -> void:
	_ensure()
	_data.zones.erase(String(G.ZONES[z].id))

static func reset_spot(z: int, k: int) -> void:
	_ensure()
	_data.spots.erase(String(G.ZONES[z].spots[k].id))

static func reset_all() -> void:
	_loaded = true
	_data = {"zones": {}, "spots": {}}

# --- persistence -------------------------------------------------------------------

static func _serialize() -> String:
	_ensure()
	return JSON.stringify(_data, "\t", true)

static func save_to(path: String) -> bool:
	var txt := _serialize()
	if path.begins_with("res://"):
		var dir := path.get_base_dir()
		if dir != "res://" and dir != "":
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(txt)
	f.close()
	return true

# Returns the path actually written (res:// preferred), or "" if nothing could be
# written. Always mirrors to user:// so a read-only res:// never loses the edit.
static func save() -> String:
	var ok_res := save_to(RES_PATH)
	var ok_usr := save_to(USER_PATH)
	if ok_res:
		return RES_PATH
	if ok_usr:
		return USER_PATH
	return ""

# --- test seam (lets headless suites drive the merge without touching real files) --

static func _ingest(d: Dictionary) -> void:
	_loaded = true
	_data = {"zones": d.get("zones", {}), "spots": d.get("spots", {})}

static func _force_reload() -> void:
	_loaded = false
	_data = {}
