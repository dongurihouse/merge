extends RefCounted
## Scene-placement workbench — the PURE model, no rendering, no window.
## A "doc" is the parsed placements.json Dictionary (schema v2, see the cherry v2 bundle):
##   {canvas:{width,height,anchorConvention:"center-bottom"}, base:{image,...}, placements:[entry]}
##   entry: {id, category, image (repo-relative), x, y, w, h, z, layer} — (x,y) is the CENTER-BOTTOM
##   anchor on the canvas; unknown keys on the doc and on entries are preserved through save.
## The view owns textures + input; every mutation goes through these ops so the tests can gate them.

const SCENES_SUFFIX := "games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1"
const MIN_SIZE_PX := 8.0                  # scale floor — an entry can never shrink into unclickability

static func load_doc(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var doc: Dictionary = parsed
	if not doc.get("placements") is Array:
		doc["placements"] = []
	return doc

## Save with a one-time sibling backup (placements.json.bak) so the pre-session state survives.
static func save_doc(path: String, doc: Dictionary) -> bool:
	if FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		var orig := FileAccess.get_file_as_string(path)
		var b := FileAccess.open(path + ".bak", FileAccess.WRITE)
		if b != null:
			b.store_string(orig)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(doc, " ") + "\n")
	return true

static func placements(doc: Dictionary) -> Array:
	return doc.get("placements", [])

static func canvas_size(doc: Dictionary) -> Vector2:
	var c: Dictionary = doc.get("canvas", {})
	return Vector2(float(c.get("width", 1320)), float(c.get("height", 2346)))

## Paint order: indices sorted by (z, list index) — stable, so equal z keeps authoring order.
static func sorted_order(doc: Dictionary) -> Array:
	var idx: Array = range(placements(doc).size())
	var pl := placements(doc)
	idx.sort_custom(func(a, b) -> bool:
		var za := int((pl[a] as Dictionary).get("z", 0))
		var zb := int((pl[b] as Dictionary).get("z", 0))
		return za < zb if za != zb else a < b)
	return idx

static func max_z(doc: Dictionary) -> int:
	var top := 0
	for e in placements(doc):
		top = maxi(top, int((e as Dictionary).get("z", 0)))
	return top

## The on-canvas rect of an entry — (x,y) anchors the CENTER-BOTTOM (the bundle convention).
static func entry_rect(e: Dictionary) -> Rect2:
	var w := float(e.get("w", 0))
	var h := float(e.get("h", 0))
	return Rect2(float(e.get("x", 0)) - w * 0.5, float(e.get("y", 0)) - h, w, h)

static func move(doc: Dictionary, i: int, delta: Vector2) -> void:
	var e: Dictionary = placements(doc)[i]
	e["x"] = int(round(float(e.get("x", 0)) + delta.x))
	e["y"] = int(round(float(e.get("y", 0)) + delta.y))

static func set_pos(doc: Dictionary, i: int, pos: Vector2) -> void:
	var e: Dictionary = placements(doc)[i]
	e["x"] = int(round(pos.x))
	e["y"] = int(round(pos.y))

## Uniform resize about the anchor: w/h scale together, floored so the entry stays grabbable.
static func scale_by(doc: Dictionary, i: int, factor: float) -> void:
	var e: Dictionary = placements(doc)[i]
	var w := float(e.get("w", 0))
	var h := float(e.get("h", 0))
	if w <= 0.0 or h <= 0.0:
		return
	var f := maxf(factor, MIN_SIZE_PX / minf(w, h))   # clamp the factor so neither side dips under the floor
	e["w"] = int(round(w * f))
	e["h"] = int(round(h * f))

static func bump_z(doc: Dictionary, i: int, dz: int) -> void:
	var e: Dictionary = placements(doc)[i]
	e["z"] = maxi(0, int(e.get("z", 0)) + dz)

static func remove_at(doc: Dictionary, i: int) -> Dictionary:
	return placements(doc).pop_at(i)

## Append a new entry: id de-duplicated, z defaulted above everything so it lands visible.
static func add_entry(doc: Dictionary, entry: Dictionary) -> int:
	var e := entry.duplicate()
	e["id"] = unique_id(doc, String(e.get("id", "item")))
	if not e.has("z"):
		e["z"] = max_z(doc) + 1
	placements(doc).append(e)
	return placements(doc).size() - 1

static func unique_id(doc: Dictionary, base: String) -> String:
	var taken := {}
	for e in placements(doc):
		taken[String((e as Dictionary).get("id", ""))] = true
	if not taken.has(base):
		return base
	var n := 2
	while taken.has("%s_%d" % [base, n]):
		n += 1
	return "%s_%d" % [base, n]

## Topmost hit at canvas point `p`: walk the paint order back to front; `opaque_at` refines a
## rect hit with an alpha test — opaque_at(entry_index, uv: Vector2) -> bool (uv in 0..1).
static func hit_at(doc: Dictionary, p: Vector2, opaque_at: Callable) -> int:
	var order := sorted_order(doc)
	for k in range(order.size() - 1, -1, -1):
		var i: int = order[k]
		var r := entry_rect(placements(doc)[i])
		if not r.has_point(p):
			continue
		var uv := (p - r.position) / r.size
		if opaque_at.is_null() or bool(opaque_at.call(i, uv)):
			return i
	return -1

## The repo root a bundle's repo-relative image paths resolve against, derived from the
## scenes root itself (…/<repo>/games/grove/assets/_new/…/picturebook_scene_mocks_v1).
static func repo_root_of(scenes_root: String) -> String:
	var s := scenes_root.trim_suffix("/")
	if s.ends_with(SCENES_SUFFIX):
		return s.trim_suffix(SCENES_SUFFIX).trim_suffix("/")
	return s

## Pick the bundle dir for a scene: the highest <scene>_elements_vN carrying metadata/placements.json.
static func bundle_for(scenes_root: String, scene: String) -> String:
	var best := ""
	var best_v := -1
	var d := DirAccess.open(scenes_root)
	if d == null:
		return ""
	for sub in d.get_directories():
		if not sub.begins_with(scene + "_elements_v"):
			continue
		var v := int(sub.trim_prefix(scene + "_elements_v"))
		if v > best_v and FileAccess.file_exists("%s/%s/metadata/placements.json" % [scenes_root, sub]):
			best_v = v
			best = "%s/%s" % [scenes_root, sub]
	return best

## Every addable .png in the bundle (skips style/metadata/reconstruction dirs, review/raw/montage
## shots and reference packs): [{id, image (repo-relative), category}].
static func addable_assets(bundle_dir: String, repo_root: String, scene: String) -> Array:
	var out: Array = []
	var top := DirAccess.open(bundle_dir)
	if top == null:
		return out
	for sub in top.get_directories():
		if sub.begins_with("00_") or sub.begins_with("09_") or sub == "metadata":
			continue
		_scan_pngs("%s/%s" % [bundle_dir, sub], sub.get_slice("_", 1), repo_root, scene, out)
	out.sort_custom(func(a, b) -> bool: return String(a.id) < String(b.id))
	return out

static func _scan_pngs(dir: String, category: String, repo_root: String, scene: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	if dir.get_file() == "references":
		return
	for fn in d.get_files():
		if not fn.ends_with(".png"):
			continue
		if fn.contains("_review") or fn.contains("_raw") or fn.contains("montage") or fn.contains("contact"):
			continue
		var id := fn.get_basename().trim_prefix(scene + "_")
		var tail := id.rfind("_v")                        # strip a trailing _v<N> version suffix
		if tail >= 0 and id.substr(tail + 2).is_valid_int():
			id = id.substr(0, tail)
		var abs := "%s/%s" % [dir, fn]
		out.append({"id": id, "image": abs.trim_prefix(repo_root + "/"), "category": category})
	for sub in d.get_directories():
		_scan_pngs("%s/%s" % [dir, sub], category, repo_root, scene, out)
