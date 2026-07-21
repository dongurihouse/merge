extends RefCounted
## Scene-placement workbench — the PURE model, no rendering, no window.
## A "doc" is the parsed placements.json Dictionary (schema v2, see the cherry v2 bundle):
##   {canvas:{width,height,anchorConvention:"center-bottom"}, base:{image,...}, placements:[entry]}
##   entry: {id, category, image (repo-relative), x, y, w, h, z, clusterZ, layer} — (x,y) is the
##   CENTER-BOTTOM anchor on the canvas; unknown keys on the doc and on entries are preserved.
## The view owns textures + input; every mutation goes through these ops so the tests can gate them.
##
## PAINT ORDER is a three-level nest, the same shape at every scale (item → cluster → layer → scene):
##   1. `layer`   — one of LAYERS below, a FIXED back→front band (sky … coverup). Cluster-wide.
##   2. `clusterZ`— the cluster's order WITHIN its layer, shared by every member of the cluster.
##   3. `z`       — the item's order WITHIN its cluster.
## Effective order = (layer_rank, clusterZ, z, list index). Both new keys degrade gracefully on
## legacy docs — a missing `layer` reads as DEFAULT_LAYER, a missing `clusterZ` falls back to `z` —
## so a scene authored before layers renders byte-identically until you actually reassign it.

const SCENES_SUFFIX := "games/grove/assets/map"
# Subdirs of the map root that are NOT scenes (shared library, generated pages). Per-scene art —
# the six layer folders plus reference/ — lives INSIDE its map/<scene>/ folder.
const NON_SCENE_DIRS := ["shared", "pages"]
const MIN_SIZE_PX := 8.0                  # scale floor — an entry can never shrink into unclickability

# The predefined layers, back (painted first) → front (painted last). A cluster lives in exactly one.
# This list is CLOSED: a scene can only ever place into one of these six — there is no op to add a
# layer, and set_layer/bump_layer reject any slug not here (an unknown/legacy value reads as DEFAULT).
const LAYERS := ["sky", "backdrop", "background", "primary", "foreground", "coverup"]
const LAYER_LABELS := {
	"sky": "Sky", "backdrop": "Backdrop", "background": "Background",
	"primary": "Primary", "foreground": "Foreground", "coverup": "Coverup"}
const DEFAULT_LAYER := "primary"           # where an unassigned (legacy) entry reads as / a new one lands

static func layer_rank(slug: String) -> int:
	var k := LAYERS.find(slug)
	return k if k >= 0 else LAYERS.find(DEFAULT_LAYER)

## An entry's layer, normalized — an absent or unknown value reads as DEFAULT_LAYER.
static func entry_layer(e: Dictionary) -> String:
	var l := String(e.get("layer", ""))
	return l if LAYERS.has(l) else DEFAULT_LAYER

## An entry's cluster order — legacy entries with no clusterZ fall back to their own item z, so a
## pre-layers doc (every entry its own singleton) keeps its exact global-z paint order.
static func entry_cluster_z(e: Dictionary) -> int:
	return int(e.get("clusterZ", e.get("z", 0)))

static func load_doc(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var doc: Dictionary = parsed
	if not doc.get("placements") is Array:
		doc["placements"] = []
	ensure_clusters(doc)                       # heal any clusterless legacy entry — see the invariant below
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

## Paint order: indices sorted by (layer_rank, clusterZ, z, list index) — stable, so an exact tie
## keeps authoring order. The three levels nest: a layer band, then clusters within it, then items.
static func sorted_order(doc: Dictionary) -> Array:
	var idx: Array = range(placements(doc).size())
	var pl := placements(doc)
	idx.sort_custom(func(a, b) -> bool:
		var ea := pl[a] as Dictionary
		var eb := pl[b] as Dictionary
		var ra := layer_rank(entry_layer(ea))
		var rb := layer_rank(entry_layer(eb))
		if ra != rb:
			return ra < rb
		var ca := entry_cluster_z(ea)
		var cb := entry_cluster_z(eb)
		if ca != cb:
			return ca < cb
		var za := int(ea.get("z", 0))
		var zb := int(eb.get("z", 0))
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

## Item order WITHIN its cluster (Z / X on a single selection). Floors at 0.
static func bump_z(doc: Dictionary, i: int, dz: int) -> void:
	var e: Dictionary = placements(doc)[i]
	e["z"] = maxi(0, int(e.get("z", 0)) + dz)

## Move an entry to `slug` (one of LAYERS) — applied CLUSTER-WIDE so a cluster never straddles two
## layers; an untagged entry moves alone. A no-op if `slug` is not a real layer.
static func set_layer(doc: Dictionary, i: int, slug: String) -> void:
	if not LAYERS.has(slug):
		return
	for m in _unit_of(doc, i):
		(placements(doc)[m] as Dictionary)["layer"] = slug

## Shift the selection's layer by `dir` (±1, clamped to the band ends). Returns the applied slug.
static func bump_layer(doc: Dictionary, i: int, dir: int) -> String:
	var cur := layer_rank(entry_layer(placements(doc)[i]))
	var slug: String = LAYERS[clampi(cur + dir, 0, LAYERS.size() - 1)]
	set_layer(doc, i, slug)
	return slug

## The member indices an entry op fans out over: its cluster, or just itself when untagged.
static func _unit_of(doc: Dictionary, i: int) -> Array:
	var name := cluster_of(doc, i)
	return clusters(doc).get(name, [i]) if name != "" else [i]

static func remove_at(doc: Dictionary, i: int) -> Dictionary:
	return placements(doc).pop_at(i)

## Append a new entry: id de-duplicated, z defaulted above everything so it lands visible. An entry
## with no cluster gets its own singleton (named after its id) — a placement is NEVER clusterless.
static func add_entry(doc: Dictionary, entry: Dictionary) -> int:
	var e := entry.duplicate()
	e["id"] = unique_id(doc, String(e.get("id", "item")))
	if not e.has("z"):
		e["z"] = max_z(doc) + 1
	if String(e.get("cluster", "")) == "":
		e["cluster"] = unique_cluster_name(doc, String(e["id"]))
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
# preserving relative z).
#
# INVARIANT: every placement belongs to exactly one cluster — a layer's only children are clusters,
# never bare items. A lone object is simply a cluster of one. Unclustering is DISABLED (set_cluster
# with "" is a no-op); ensure_clusters() heals any clusterless legacy entry on load. The only way to
# relocate an item is INTO another cluster.

## Every placement must belong to a cluster. Any clusterless entry (legacy / hand-authored) is healed
## into its own singleton cluster named after its id, so the layer→cluster→item nest always holds.
static func ensure_clusters(doc: Dictionary) -> void:
	for i in placements(doc).size():
		var e: Dictionary = placements(doc)[i]
		if String(e.get("cluster", "")) == "":
			e["cluster"] = unique_cluster_name(doc, String(e.get("id", "item")))

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

## Move entry `i` into cluster `name`. Empty `name` is a NO-OP — unclustering is disabled, so an item
## can only ever be re-tagged INTO another cluster, never orphaned.
static func set_cluster(doc: Dictionary, i: int, name: String) -> void:
	if name == "":
		return
	(placements(doc)[i] as Dictionary)["cluster"] = name

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

## Ensure entry `i` is a member of `name` (join it, or re-tag it away from another cluster). Leaving
## to nothing is disabled — a placement always belongs to exactly one cluster — so a call with a
## non-empty `name` always ends with the entry in `name`. Returns true (now a member); "" → false.
static func toggle_cluster_member(doc: Dictionary, i: int, name: String) -> bool:
	if name == "":
		return false
	set_cluster(doc, i, name)
	return true

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

## The cluster's shared order within its layer (the lowest member's clusterZ, in case a legacy doc
## left them out of sync). {} members → 0.
static func cluster_z(doc: Dictionary, name: String) -> int:
	var idx: Array = clusters(doc).get(name, [])
	if idx.is_empty():
		return 0
	var lo := entry_cluster_z(placements(doc)[idx[0]])
	for i in idx:
		lo = mini(lo, entry_cluster_z(placements(doc)[i]))
	return lo

## Restack the CLUSTER among its layer's clusters (Z / X on a cluster selection): every member gets
## the same new `clusterZ`, floored at 0. The members' own `z` (their order inside the cluster) is
## untouched, so the cluster moves as one block without disturbing its internal stacking.
static func bump_cluster_z(doc: Dictionary, name: String, dz: int) -> void:
	var idx: Array = clusters(doc).get(name, [])
	if idx.is_empty():
		return
	var nv := maxi(0, cluster_z(doc, name) + dz)
	for i in idx:
		(placements(doc)[i] as Dictionary)["clusterZ"] = nv

## Topmost hit at canvas point `p`: walk the paint order back to front; `opaque_at` refines a
## rect hit with an alpha test — opaque_at(entry_index, uv: Vector2) -> bool (uv in 0..1).
## `hidden_clusters` / `hidden_layers` are workbench-only view filters: an entry whose cluster or
## layer is hidden is not rendered, so it must not catch stage clicks either — the pick falls
## through to whatever sits behind it.
static func hit_at(doc: Dictionary, p: Vector2, opaque_at: Callable,
		hidden_clusters := {}, hidden_layers := {}) -> int:
	var order := sorted_order(doc)
	for k in range(order.size() - 1, -1, -1):
		var i: int = order[k]
		var e: Dictionary = placements(doc)[i]
		if not hidden_clusters.is_empty() and hidden_clusters.has(cluster_of(doc, i)):
			continue
		if not hidden_layers.is_empty() and hidden_layers.has(entry_layer(e)):
			continue
		var r := entry_rect(e)
		if not r.has_point(p):
			continue
		var uv := (p - r.position) / r.size
		if opaque_at.is_null() or bool(opaque_at.call(i, uv)):
			return i
	return -1

## The repo root a bundle's repo-relative image paths resolve against, derived from the
## scenes root itself (…/<repo>/games/grove/assets/_concepts/zones).
static func repo_root_of(scenes_root: String) -> String:
	var s := scenes_root.trim_suffix("/")
	if s.ends_with(SCENES_SUFFIX):
		var root := s.trim_suffix(SCENES_SUFFIX).trim_suffix("/")
		return root if root != "" else "."   # a relative root that IS the suffix → project root
	# ROOT= also accepts a scene root under an arbitrary repository asset folder, such as
	# games/grove/assets/_concepts/zones. Its placement documents still carry repo-relative
	# image paths, so derive the repository prefix instead of treating the scenes root as it.
	var games_at := s.find("/games/")
	if games_at >= 0:
		return s.substr(0, games_at)
	if s.begins_with("games/"):
		return "."
	return s

## The folder for a scene: map/<scene>/ when it carries placements.json (the consolidated layout —
## one folder per scene, art organized under its layer subdirs).
static func bundle_for(scenes_root: String, scene: String) -> String:
	var dir := "%s/%s" % [scenes_root, scene]
	return dir if FileAccess.file_exists("%s/placements.json" % dir) else ""

## The path to a scene's placements doc under the map root.
static func placements_path(scenes_root: String, scene: String) -> String:
	return "%s/%s/placements.json" % [scenes_root, scene]

## Every scene under the map root that has an openable placements.json (drives the scene dropdown);
## the shared library and generated-page dirs are skipped.
static func scenes_in(scenes_root: String) -> Array:
	var found := {}
	var d := DirAccess.open(scenes_root)
	if d == null:
		return []
	for sub in d.get_directories():
		if NON_SCENE_DIRS.has(sub):
			continue
		if FileAccess.file_exists("%s/%s/placements.json" % [scenes_root, sub]):
			found[sub] = true
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

## Prefer a candidate that actually contains the requested scene. This lets a newly-intaken
## one-off concept bundle open through plain `make sw SCENE=<name>` instead of requiring ROOT=.
## When no candidate has it, keep the established richest-root fallback for the existing scene set.
static func pick_root_for_scene(candidates: Array, scene: String) -> String:
	var matching: Array = []
	for cand in candidates:
		var root := String(cand)
		if bundle_for(root, scene) != "":
			matching.append(root)
	return pick_root(matching) if not matching.is_empty() else pick_root(candidates)

## The scene's REFERENCE images (the left column): everything under map/<scene>/reference/ — the
## original full-scene mocks, source pages, reconstruction QA passes and keyer intermediates that
## the consolidation preserved out of the layer bands. Export-excluded, so they never ship.
static func reference_images(bundle_dir: String) -> Array:
	var out: Array = []
	var rd := DirAccess.open(bundle_dir + "/reference")
	if rd != null:
		for fn in rd.get_files():
			if fn.ends_with(".png") or fn.ends_with(".jpg"):
				out.append("%s/reference/%s" % [bundle_dir, fn])
	out.sort()
	return out

## Palette grouping order = the layer band order (an unknown category sorts after, at DEFAULT rank).
static func category_rank(category: String) -> int:
	var k := LAYERS.find(category)
	return k if k >= 0 else LAYERS.size()

## Every addable .png for a scene: the element art under map/<scene>/<layer>/ plus the cross-scene
## map/shared/<layer>/ library, grouped by layer band then id. [{id, image (repo-relative), category}].
## reference/ is skipped — it holds mocks and intermediates, not placeable elements. Category = layer.
static func addable_assets(bundle_dir: String, repo_root: String, scene: String) -> Array:
	var out: Array = []
	for layer in LAYERS:
		_scan_pngs("%s/%s" % [bundle_dir, layer], layer, repo_root, scene, out)
	var shared := "%s/games/grove/assets/map/shared" % repo_root
	for layer in LAYERS:
		_scan_pngs("%s/%s" % [shared, layer], layer, repo_root, scene, out)
	out.sort_custom(func(a, b) -> bool:
		var ra := category_rank(String(a.category))
		var rb := category_rank(String(b.category))
		if ra != rb:
			return ra < rb
		return String(a.id) < String(b.id))
	return out

## Filter an addable-asset list (from addable_assets) down to a single layer band. The add
## palette is scoped to the selected cluster's own layer, so a cluster only ever pulls in
## art authored for that layer — this scene's <layer>/ folder plus shared/<layer>/ — and
## never, say, a coverup leaf into a backdrop cluster. `category` on each asset IS its layer.
static func assets_in_layer(assets: Array, layer: String) -> Array:
	var out: Array = []
	for a in assets:
		if String((a as Dictionary).get("category", "")) == layer:
			out.append(a)
	return out

static func _scan_pngs(dir: String, category: String, repo_root: String, scene: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	if dir.get_file() == "references" or dir.get_file() == "reference":
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
