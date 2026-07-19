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

# --- CLUSTERS -------------------------------------------------------------------------------------
# A cluster is a named GROUP of placements (entry key "cluster") that manages as one thing — the
# canonical example: a tent with its surrounding rocks, vegetation and shadow. Members keep their own
# entries; cluster ops fan out over them (move together, scale about the shared footing, restack
# preserving relative z). "" / absent = unclustered.

## name -> Array of placement indices (in list order).
static func clusters(doc: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var pl := placements(doc)
	for i in pl.size():
		var c := String((pl[i] as Dictionary).get("cluster", ""))
		if c == "":
			continue
		if not out.has(c):
			out[c] = []
		(out[c] as Array).append(i)
	return out

static func cluster_of(doc: Dictionary, i: int) -> String:
	return String((placements(doc)[i] as Dictionary).get("cluster", ""))

## Tag / untag ("" clears the key so untouched files stay byte-stable).
static func set_cluster(doc: Dictionary, i: int, name: String) -> void:
	var e: Dictionary = placements(doc)[i]
	if name == "":
		e.erase("cluster")
	else:
		e["cluster"] = name

static func unique_cluster_name(doc: Dictionary, base: String) -> String:
	var taken := clusters(doc)
	if not taken.has(base):
		return base
	var n := 2
	while taken.has("%s_%d" % [base, n]):
		n += 1
	return "%s_%d" % [base, n]

## Toggle the DYNAMIC SILHOUETTE SHADOW flag (prop_shadow.gd renders it in the game and in the
## workbench stage). Off erases the key, so untouched files stay byte-stable.
static func set_shadow(doc: Dictionary, i: int, on: bool) -> void:
	var e: Dictionary = placements(doc)[i]
	if on:
		e["shadow"] = true
	else:
		e.erase("shadow")

## Toggle one entry's membership in `name`: a member leaves, anything else joins (re-tagging
## away from another cluster is allowed). Returns true when the entry is now a member.
static func toggle_cluster_member(doc: Dictionary, i: int, name: String) -> bool:
	var joining := cluster_of(doc, i) != name
	set_cluster(doc, i, name if joining else "")
	return joining

## Rename a cluster (every member re-tags). The applied name is unique-ified against the other
## clusters; returns it ("" = nothing to rename / empty target).
static func rename_cluster(doc: Dictionary, from: String, to: String) -> String:
	to = to.strip_edges().replace(" ", "_")
	if from == "" or to == "" or to == from:
		return ""
	var members: Array = clusters(doc).get(from, [])
	if members.is_empty():
		return ""
	var applied := unique_cluster_name(doc, to)
	for i in members:
		set_cluster(doc, i, applied)
	return applied

## The members' combined canvas rect ({} members → zero rect).
static func cluster_bbox(doc: Dictionary, name: String) -> Rect2:
	var idx: Array = clusters(doc).get(name, [])
	if idx.is_empty():
		return Rect2()
	var r := entry_rect(placements(doc)[idx[0]])
	for k in range(1, idx.size()):
		r = r.merge(entry_rect(placements(doc)[idx[k]]))
	return r

static func move_cluster(doc: Dictionary, name: String, delta: Vector2) -> void:
	for i in clusters(doc).get(name, []):
		move(doc, i, delta)

## Uniform cluster resize about the group's FOOTING (bbox bottom-center): anchors converge on it,
## sizes scale with it; the factor is clamped so no member dips under the grabbable floor.
static func scale_cluster(doc: Dictionary, name: String, factor: float) -> void:
	var idx: Array = clusters(doc).get(name, [])
	if idx.is_empty():
		return
	var f := factor
	for i in idx:
		var e: Dictionary = placements(doc)[i]
		var side := minf(float(e.get("w", 0)), float(e.get("h", 0)))
		if side > 0.0:
			f = maxf(f, MIN_SIZE_PX / side)
	var bb := cluster_bbox(doc, name)
	var foot := Vector2(bb.position.x + bb.size.x * 0.5, bb.end.y)
	for i in idx:
		var e: Dictionary = placements(doc)[i]
		var a := Vector2(float(e.get("x", 0)), float(e.get("y", 0)))
		var na := foot + (a - foot) * f
		e["x"] = int(round(na.x))
		e["y"] = int(round(na.y))
		e["w"] = int(round(float(e.get("w", 0)) * f))
		e["h"] = int(round(float(e.get("h", 0)) * f))

## Restack the whole cluster; a downward bump is clamped so the LOWEST member floors at z 0
## (relative z inside the cluster always survives).
static func bump_cluster_z(doc: Dictionary, name: String, dz: int) -> void:
	var idx: Array = clusters(doc).get(name, [])
	if idx.is_empty():
		return
	var low := int((placements(doc)[idx[0]] as Dictionary).get("z", 0))
	for i in idx:
		low = mini(low, int((placements(doc)[i] as Dictionary).get("z", 0)))
	var d := maxi(dz, -low)
	for i in idx:
		var e: Dictionary = placements(doc)[i]
		e["z"] = int(e.get("z", 0)) + d

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

## Every scene under a scenes root that has an openable bundle (drives the scene dropdown).
static func scenes_in(scenes_root: String) -> Array:
	var found := {}
	var d := DirAccess.open(scenes_root)
	if d == null:
		return []
	for sub in d.get_directories():
		var k := sub.find("_elements_v")
		if k <= 0:
			continue
		if FileAccess.file_exists("%s/%s/metadata/placements.json" % [scenes_root, sub]):
			found[sub.substr(0, k)] = true
	var names: Array = found.keys()
	names.sort()
	return names

## Choose the scenes root among candidates: the one with the MOST openable scenes wins (ties →
## the earlier candidate). Guards against a partially-intaken repo copy shadowing a full root.
static func pick_root(candidates: Array) -> String:
	var best := ""
	var best_n := 0
	for cand in candidates:
		var n := scenes_in(String(cand)).size()
		if n > best_n:
			best_n = n
			best = String(cand)
	return best

## The scene's REFERENCE images (the left column), primary first: the ORIGINAL concept mocks in
## assets/_concepts/zones (untouched full-scene sources, .png/.jpg), then the mocks-root images
## named <scene>*.png (incl. the baked composites), then the bundle's 09_reconstruction pass.
static func reference_images(scenes_root: String, bundle_dir: String, scene: String) -> Array:
	var out: Array = []
	var concepts := "%s/games/grove/assets/_concepts/zones" % repo_root_of(scenes_root)
	var cd := DirAccess.open(concepts)
	if cd != null:
		var firsts: Array = []
		for fn in cd.get_files():
			if fn.begins_with(scene) and (fn.ends_with(".png") or fn.ends_with(".jpg")):
				firsts.append("%s/%s" % [concepts, fn])
		firsts.sort()
		out.append_array(firsts)
	var roots: Array = []
	var d := DirAccess.open(scenes_root)
	if d != null:
		for fn in d.get_files():
			if fn.begins_with(scene) and fn.ends_with(".png"):
				roots.append("%s/%s" % [scenes_root, fn])
	roots.sort()
	out.append_array(roots)
	var recs: Array = []
	var rec := DirAccess.open(bundle_dir + "/09_reconstruction")
	if rec != null:
		for fn in rec.get_files():
			if fn.ends_with(".png"):
				recs.append("%s/09_reconstruction/%s" % [bundle_dir, fn])
	recs.sort()
	out.append_array(recs)
	return out

## The sidebar palette's section order (categories not listed sort after, alphabetically).
const CATEGORY_ORDER := ["backdrop", "foundation", "environment", "terrain", "structures", "garden_items", "vegetation", "rock"]

static func category_rank(category: String) -> int:
	var k := CATEGORY_ORDER.find(category)
	return k if k >= 0 else CATEGORY_ORDER.size()

## Every addable .png in the bundle (skips style/metadata/reconstruction dirs, review/raw/montage
## shots and reference packs): [{id, image (repo-relative), category}], grouped by category then id.
## Category = the top dir minus its NN_ prefix (04_garden_items → garden_items); descending into a
## *_pack dir refines it to the pack name (05_dressing/vegetation_pack → vegetation).
static func addable_assets(bundle_dir: String, repo_root: String, scene: String) -> Array:
	var out: Array = []
	var top := DirAccess.open(bundle_dir)
	if top == null:
		return out
	for sub in top.get_directories():
		if sub.begins_with("00_") or sub.begins_with("09_") or sub == "metadata":
			continue
		var cat := sub
		if cat.length() > 3 and cat.substr(0, 2).is_valid_int() and cat[2] == "_":
			cat = cat.substr(3)
		_scan_pngs("%s/%s" % [bundle_dir, sub], cat, repo_root, scene, out)
	# RECOVERED bundles carry no element dirs — the surviving per-scene page art (the game's
	# copies) doubles as the palette so adding stays possible. De-duped against bundle finds.
	var seen := {}
	for a in out:
		seen[String((a as Dictionary).id)] = true
	var pages_dir := "%s/games/grove/assets/map/pages/%s" % [repo_root, scene]
	var pd := DirAccess.open(pages_dir)
	if pd != null:
		for fn in pd.get_files():
			if not fn.ends_with(".png") or fn == "foundation.png":
				continue
			var pid := fn.get_basename()
			if seen.has(pid):
				continue
			out.append({"id": pid, "image": ("%s/%s" % [pages_dir, fn]).trim_prefix(repo_root + "/"),
				"category": "page_art"})
	out.sort_custom(func(a, b) -> bool:
		var ra := category_rank(String(a.category))
		var rb := category_rank(String(b.category))
		if ra != rb:
			return ra < rb
		if String(a.category) != String(b.category):
			return String(a.category) < String(b.category)
		return String(a.id) < String(b.id))
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
		var cat := sub.trim_suffix("_pack") if sub.ends_with("_pack") else category
		_scan_pngs("%s/%s" % [dir, sub], cat, repo_root, scene, out)
