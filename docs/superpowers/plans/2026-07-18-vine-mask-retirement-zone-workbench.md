# Vine Mask Retirement + Zone Workbench Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the retired vine-mask system (dead code, tool, shaders, bakes, old map art) and replace its authoring role with a Zone Workbench that draws polygon unlock zones on the five picture-book pages, saving `unlocks_<scene>.json` sibling files.

**Architecture:** A pure model script (`zone_workbench_model.gd`, mirroring `scene_workbench_model.gd`) owns load/save/mutation of the unlock-zone document and is gated by a headless suite. A thin UI tool (`games/tools/zone_workbench/`) reuses the vine tool's polygon editor and list panel (moved, stripped of stars/cost), and renders the real page via `HomeZoneView.build`. The vine sweep deletes the mutually-referential dead cluster all-at-once per the dead-method rule.

**Tech Stack:** Godot 4 GDScript, headless SceneTree test suites via `engine/tools/run_suites.py`, Make.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-18-vine-mask-retirement-zone-workbench-design.md`.
- Work in a fresh **out-of-tree** worktree (in-repo `.worktrees/` get wiped); seed its `.godot/` cache with `rsync -a --delete /Users/xup/dh/merge/.godot/ <worktree>/.godot/`.
- Run `make test-fast` after every change; full `make test` before merge.
- Unlock-zone file schema (sibling to the generated zone manifest, never overwritten by `build_page_manifests.py`): `{"version": 1, "scene": "<id>", "canvas": [1320, 2346], "zones": [{"name", "enabled", "points": [[x,y],...], "button": [x,y] (optional)}]}`. Points are integers in native canvas coordinates; list order = unlock order; `button` absent = centroid.
- Authoring only: no runtime code reads `unlocks_<scene>.json` in this plan.
- Decorative "vine"-named UI art stays: `icon_vine` (Play CTA restore face, `home_chrome.gd` `ICON_PLAY_RESTORE`), `divider_vine`, `tiers_vine_*`. `kit_bake_tests.gd`'s "vine" icon check stays.
- Raw originals under `assets/_originals/` are never deleted.
- Delete `.png.import` files together with their `.png`, and `.uid` files with their `.gd`.
- Dead-method rule: verify the call graph before deleting; a mutually-referential dead set goes all-at-once; delete func→next-func ranges without swallowing the comment block above the NEXT function.

---

### Task 1: Worktree setup

**Files:** none (environment only)

- [ ] **Step 1: Create the worktree and seed the import cache**

```bash
cd /Users/xup/dh/merge
git worktree add /Users/xup/dh/wt-vine-retire -b vine-retire
rsync -a --delete /Users/xup/dh/merge/.godot/ /Users/xup/dh/wt-vine-retire/.godot/
```

- [ ] **Step 2: Baseline the tests**

Run: `cd /Users/xup/dh/wt-vine-retire && make test-fast`
Expected: all engine suites PASS (record the baseline; any pre-existing failure is surfaced, not attributed to this work).

### Task 2: Zone workbench model (pure) + headless suite

**Files:**
- Create: `games/grove/tools/zone_workbench_model.gd`
- Test: `games/grove/tests/grove_zone_workbench_tests.gd`
- Modify: `Makefile` (add the suite to `GROVE_TESTS`)

**Interfaces:**
- Produces (all static, used by Task 3's UI):
  - `pages() -> Array` — `[{id, name, zone_manifest}]` for every `G.MAPS` row carrying a `zone_manifest`.
  - `unlocks_path(scene_id: String) -> String` — `res://games/grove/assets/map/pages/unlocks_<scene_id>.json`.
  - `blank(scene_id: String, canvas: Vector2) -> Dictionary` — an empty document.
  - `load_doc(scene_id: String, canvas: Vector2) -> Dictionary` — parse the saved file (points clamped to canvas, zones with <3 points dropped), else `blank()`.
  - `serialize(doc: Dictionary) -> String` — pretty JSON, int-rounded points, `button` only when present.
  - `add_zone(doc, points: Array) -> bool` — append `{name: "Zone N", enabled: true, points}` (≥3 `Vector2`s, clamped); `false` when rejected.
  - `delete_zone(doc, index: int)`, `reorder_zone(doc, from_index: int, to_index: int)`, `rename_zone(doc, index: int, name: String)`, `set_enabled(doc, index: int, on: bool)`, `set_button(doc, index: int, pos)` (`null` clears).
- In-memory zone shape: `{name: String, enabled: bool, points: Array[Vector2], button?: Vector2}`; document shape: `{version: int, scene: String, canvas: Vector2, zones: Array}`.

- [ ] **Step 1: Write the failing suite**

Create `games/grove/tests/grove_zone_workbench_tests.gd` following the house pattern (`extends SceneTree`, `ok()` counter, `_initialize()`), driving the model only — no UI:

```gdscript
extends SceneTree
## Gates games/grove/tools/zone_workbench_model.gd — the PURE half of the unlock-zone
## workbench (page listing, document load/save round-trip, zone ops, clamping).

const M = preload("res://games/grove/tools/zone_workbench_model.gd")
const G = preload("res://games/grove/grove_data.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

const CANVAS := Vector2(1320, 2346)
const TRI := [Vector2(100, 100), Vector2(300, 100), Vector2(200, 300)]

func _initialize() -> void:
	print("== Zone workbench model tests ==")

	# --- pages ----------------------------------------------------------------------
	var pages: Array = M.pages()
	ok(pages.size() == 5, "pages() lists the five picture-book pages")
	var ids: Array = []
	for p in pages:
		ids.append(String(p.id))
		ok(ResourceLoader.exists(String(p.zone_manifest)) or FileAccess.file_exists(String(p.zone_manifest)),
			"page %s names an existing zone manifest" % p.id)
	ok(ids.has("fairy_hollow"), "fairy_hollow is a page")
	ok(M.unlocks_path("fairy_hollow") == "res://games/grove/assets/map/pages/unlocks_fairy_hollow.json",
		"unlocks_path is the sibling-file convention")

	# --- document ops ---------------------------------------------------------------
	var d: Dictionary = M.blank("fairy_hollow", CANVAS)
	ok(int(d.version) == 1 and String(d.scene) == "fairy_hollow" and (d.zones as Array).is_empty(),
		"blank() shapes an empty v1 document")
	ok(not M.add_zone(d, [Vector2(0, 0), Vector2(1, 1)]), "add_zone rejects <3 points")
	ok(M.add_zone(d, TRI), "add_zone accepts a triangle")
	M.add_zone(d, [Vector2(400, 400), Vector2(600, 400), Vector2(9999, 9999)])
	var z1: Dictionary = (d.zones as Array)[1]
	ok((z1.points as Array)[2] == Vector2(CANVAS.x - 1, CANVAS.y - 1), "points clamp to the canvas")
	ok(String(z1.name) == "Zone 2", "zones auto-name by position")
	M.rename_zone(d, 1, "Gate")
	M.set_enabled(d, 1, false)
	M.set_button(d, 0, Vector2(150, 150))
	M.reorder_zone(d, 1, 0)
	ok(String((d.zones as Array)[0].name) == "Gate", "reorder moves the zone (order = unlock order)")

	# --- save / load round-trip -----------------------------------------------------
	var text: String = M.serialize(d)
	var parsed: Dictionary = JSON.parse_string(text)
	ok(int(parsed.version) == 1 and (parsed.zones as Array).size() == 2, "serialize emits v1 with both zones")
	ok((parsed.zones as Array)[1].has("button") and not (parsed.zones as Array)[0].has("button"),
		"button persists only when placed")
	ok((parsed.canvas as Array)[0] == 1320.0 and (parsed.canvas as Array)[1] == 2346.0,
		"canvas rides the document")
	var tmp := "user://test_unlocks_roundtrip.json"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var back: Dictionary = M.load_doc_from(tmp, "fairy_hollow", CANVAS)
	ok((back.zones as Array).size() == 2, "load_doc_from reads both zones back")
	ok(String((back.zones as Array)[0].name) == "Gate" and not bool((back.zones as Array)[0].enabled),
		"name + enabled round-trip")
	ok((back.zones as Array)[1].button is Vector2, "button round-trips as Vector2")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	ok(M.load_doc_from("user://does_not_exist.json", "fairy_hollow", CANVAS).zones.is_empty(),
		"a missing file loads as blank")

	print("passed %d failed %d" % [_pass, _fail])
	if _fail > 0:
		OS.exit_code = 1
	quit()
```

Note the seam: `load_doc(scene_id, canvas)` delegates to `load_doc_from(path, scene_id, canvas)` so the test never touches real asset files.

- [ ] **Step 2: Register the suite and verify it fails**

In `Makefile`, append ` games/grove/tests/grove_zone_workbench_tests` to `GROVE_TESTS` (line 17). Run:

`make test-one SUITE=games/grove/tests/grove_zone_workbench_tests`
Expected: FAIL/crash — `zone_workbench_model.gd` does not exist.

- [ ] **Step 3: Implement the model**

Create `games/grove/tools/zone_workbench_model.gd`:

```gdscript
extends Object
## The PURE half of the Zone Workbench (unlock-zone authoring for the picture-book pages).
## Owns the document: {version, scene, canvas: Vector2, zones: [{name, enabled, points: [Vector2],
## button?: Vector2}]}. Zone list order == unlock order. The saved file is a SIBLING of the generated
## zone manifest (unlocks_<scene>.json), so build_page_manifests.py regeneration never clobbers it.
## Authoring-only for now: the game does not read these files yet (runtime wiring is a follow-up).

const G = preload("res://games/grove/grove_data.gd")

# Every picture-book page: the G.MAPS rows that carry a zone_manifest.
static func pages() -> Array:
	var out: Array = []
	for m in G.MAPS:
		var manifest := String((m as Dictionary).get("zone_manifest", ""))
		if manifest != "":
			out.append({"id": String(m.id), "name": String(m.name), "zone_manifest": manifest})
	return out

static func unlocks_path(scene_id: String) -> String:
	return "res://games/grove/assets/map/pages/unlocks_%s.json" % scene_id

static func blank(scene_id: String, canvas: Vector2) -> Dictionary:
	return {"version": 1, "scene": scene_id, "canvas": canvas, "zones": []}

static func load_doc(scene_id: String, canvas: Vector2) -> Dictionary:
	return load_doc_from(unlocks_path(scene_id), scene_id, canvas)

# Parse a saved unlocks file (points clamped, degenerate zones dropped); a missing or bad file is a
# blank document — the tool opens ready to draw.
static func load_doc_from(path: String, scene_id: String, canvas: Vector2) -> Dictionary:
	var doc := blank(scene_id, canvas)
	if not FileAccess.file_exists(path):
		return doc
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return doc
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return doc
	for zv in ((parsed as Dictionary).get("zones", []) as Array):
		if not (zv is Dictionary):
			continue
		var pts: Array = []
		for p in ((zv as Dictionary).get("points", []) as Array):
			if p is Array and (p as Array).size() >= 2:
				pts.append(_clamp(Vector2(float(p[0]), float(p[1])), canvas))
		if pts.size() < 3:
			continue
		var zone := {
			"name": str((zv as Dictionary).get("name", "Zone %d" % [(doc.zones as Array).size() + 1])),
			"enabled": bool((zv as Dictionary).get("enabled", true)),
			"points": pts,
		}
		var b: Variant = (zv as Dictionary).get("button", null)
		if b is Array and (b as Array).size() >= 2:
			zone["button"] = _clamp(Vector2(float(b[0]), float(b[1])), canvas)
		(doc.zones as Array).append(zone)
	return doc

static func serialize(doc: Dictionary) -> String:
	var zones: Array = []
	for zv in (doc.zones as Array):
		var z: Dictionary = zv
		var pts: Array = []
		for p in (z.points as Array):
			pts.append([roundi((p as Vector2).x), roundi((p as Vector2).y)])
		var out := {"name": String(z.name), "enabled": bool(z.enabled), "points": pts}
		if z.has("button") and z.button is Vector2:
			out["button"] = [roundi((z.button as Vector2).x), roundi((z.button as Vector2).y)]
		zones.append(out)
	var canvas: Vector2 = doc.canvas
	return JSON.stringify({
		"version": 1,
		"scene": String(doc.scene),
		"canvas": [roundi(canvas.x), roundi(canvas.y)],
		"zones": zones,
	}, "  ")

# Append a hand-drawn polygon (>= 3 vertices; Vector2 or [x, y] points, clamped). False when rejected.
static func add_zone(doc: Dictionary, points: Array) -> bool:
	var canvas: Vector2 = doc.canvas
	var pts: Array = []
	for p in points:
		if p is Vector2:
			pts.append(_clamp(p, canvas))
		elif p is Array and (p as Array).size() >= 2:
			pts.append(_clamp(Vector2(float(p[0]), float(p[1])), canvas))
	if pts.size() < 3:
		return false
	(doc.zones as Array).append({
		"name": "Zone %d" % [(doc.zones as Array).size() + 1],
		"enabled": true,
		"points": pts,
	})
	return true

static func delete_zone(doc: Dictionary, index: int) -> void:
	if index >= 0 and index < (doc.zones as Array).size():
		(doc.zones as Array).remove_at(index)

# Move a zone to a new list position (order = unlock order); everything it carries travels with it.
static func reorder_zone(doc: Dictionary, from_index: int, to_index: int) -> void:
	var zones: Array = doc.zones
	if from_index < 0 or from_index >= zones.size():
		return
	var z: Dictionary = zones[from_index]
	zones.remove_at(from_index)
	zones.insert(clampi(to_index, 0, zones.size()), z)

static func rename_zone(doc: Dictionary, index: int, name: String) -> void:
	if index >= 0 and index < (doc.zones as Array).size():
		((doc.zones as Array)[index] as Dictionary)["name"] = name

static func set_enabled(doc: Dictionary, index: int, on: bool) -> void:
	if index >= 0 and index < (doc.zones as Array).size():
		((doc.zones as Array)[index] as Dictionary)["enabled"] = on

# Place a zone's unlock-disc anchor (null clears it back to auto/centroid).
static func set_button(doc: Dictionary, index: int, pos) -> void:
	if index < 0 or index >= (doc.zones as Array).size():
		return
	var z: Dictionary = (doc.zones as Array)[index]
	if pos is Vector2:
		z["button"] = _clamp(pos, doc.canvas as Vector2)
	else:
		z.erase("button")

static func _clamp(p: Vector2, canvas: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 0.0, canvas.x - 1.0), clampf(p.y, 0.0, canvas.y - 1.0))
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `make test-one SUITE=games/grove/tests/grove_zone_workbench_tests`
Expected: PASS, `failed 0`. Then `make test-fast` — engine suites still green.

- [ ] **Step 5: Commit**

```bash
git add games/grove/tools/zone_workbench_model.gd games/grove/tests/grove_zone_workbench_tests.gd Makefile
git commit -m "feat(tools): zone-workbench model — unlock-zone documents for the picture-book pages"
```

### Task 3: Zone Workbench UI tool (`make zones`)

**Files:**
- Create: `games/tools/zone_workbench/ZoneWorkbench.tscn`
- Create: `games/tools/zone_workbench/zone_workbench.gd`
- Create: `games/tools/zone_workbench/region_editor_overlay.gd` (moved from `games/tools/vine_mask_tool/scripts/`, verbatim — it is already vine-free)
- Create: `games/tools/zone_workbench/zone_list_panel.gd` (from `region_list_panel.gd`, stars/cost removed)
- Modify: `Makefile` (add the `zones` target; `.PHONY`)

**Interfaces:**
- Consumes: Task 2's model statics; `HomeZoneView.load_manifest(path)` / `HomeZoneView.build(parent, manifest, state_of, next_step_of, covering_frames)` from `engine/scripts/ui/home_zone_view.gd`; the overlay's signals `regions_changed(regions)`, `selection_changed(i)`, `region_drawn(points)` and methods `set_image_size/set_regions/set_selected_region/set_edit_enabled/set_draw_mode`.
- Produces: the on-disk `unlocks_<scene>.json` files (schema in Global Constraints).

- [ ] **Step 1: Move the overlay, adapt the list panel**

```bash
mkdir -p games/tools/zone_workbench
git mv games/tools/vine_mask_tool/scripts/region_editor_overlay.gd games/tools/zone_workbench/region_editor_overlay.gd
git mv games/tools/vine_mask_tool/scripts/region_editor_overlay.gd.uid games/tools/zone_workbench/region_editor_overlay.gd.uid
git mv games/tools/vine_mask_tool/scripts/region_list_panel.gd games/tools/zone_workbench/zone_list_panel.gd
git mv games/tools/vine_mask_tool/scripts/region_list_panel.gd.uid games/tools/zone_workbench/zone_list_panel.gd.uid
```

In `zone_list_panel.gd`: delete the `cost_changed` signal, `DEFAULT_STARS`/`MIN_STARS`/`MAX_STARS`, `_total_label` and `_update_total()` (and their call sites), the `stars_label`/`stars` SpinBox block in `_build_row`, and `RegionRow.stars_spin`. Update the header doc comment to "unlock-zone list … name / on / delete" and rename the draw button text to "＋ Draw Zone". In `region_editor_overlay.gd` change only the default `image_size` to `Vector2(1320.0, 2346.0)` and the header comment's "vine authoring tool" wording.

- [ ] **Step 2: Write the tool script**

Create `games/tools/zone_workbench/zone_workbench.gd`:

```gdscript
extends Control
## ZONE WORKBENCH (make zones): draw polygon UNLOCK ZONES over a real picture-book page.
## Replaces the retired vine mask tool's authoring role. The page renders through HomeZoneView
## (every building "built") so zones are drawn on exactly what the game shows; polygons are authored
## in NATIVE canvas coordinates (the stage is uniformly scaled to fit the window). Save writes
## unlocks_<scene>.json beside the page's zone manifest — see zone_workbench_model.gd for the schema.

const Model := preload("res://games/grove/tools/zone_workbench_model.gd")
const HomeZoneView := preload("res://engine/scripts/ui/home_zone_view.gd")
const RegionEditorOverlay := preload("res://games/tools/zone_workbench/region_editor_overlay.gd")
const ZoneListPanel := preload("res://games/tools/zone_workbench/zone_list_panel.gd")
const FS = preload("res://engine/scripts/core/tuning.gd").FontScale

const PANEL_W := 400.0
const VIEW_H := 1100.0                 # the scaled page height on screen (fits a laptop window)

var pages: Array = []
var page_index := 0
var doc: Dictionary = {}
var selected := 0
var stage_holder: Control              # scaled wrapper: page render + overlay live at NATIVE size inside
var overlay: Control
var zone_list: Control
var page_select: OptionButton
var save_status: Label

func _ready() -> void:
	pages = Model.pages()
	if pages.is_empty():
		push_error("Zone workbench: no G.MAPS rows carry a zone_manifest")
		return
	_build_panel()
	_open_page(0)

func _canvas() -> Vector2:
	return doc.canvas as Vector2 if doc.has("canvas") else Vector2(1320, 2346)

func _open_page(index: int) -> void:
	page_index = clampi(index, 0, pages.size() - 1)
	var page: Dictionary = pages[page_index]
	var manifest: Dictionary = HomeZoneView.load_manifest(String(page.zone_manifest))
	var cv: Dictionary = manifest.get("canvas", {})
	var canvas := Vector2(float(cv.get("width", 1320)), float(cv.get("height", 2346)))
	doc = Model.load_doc(String(page.id), canvas)
	selected = 0
	_rebuild_stage(manifest, canvas)
	_sync_all()

# The scaled page stage: HomeZoneView's tree + the polygon overlay, both at NATIVE canvas size,
# uniformly scaled to VIEW_H. Overlay input arrives in native coordinates (Godot applies the
# inverse canvas transform), so the model never sees screen space.
func _rebuild_stage(manifest: Dictionary, canvas: Vector2) -> void:
	if stage_holder != null:
		stage_holder.queue_free()
	stage_holder = Control.new()
	stage_holder.name = "Stage"
	var s := VIEW_H / canvas.y
	stage_holder.scale = Vector2.ONE * s
	stage_holder.position = Vector2.ZERO
	add_child(stage_holder)
	move_child(stage_holder, 0)
	custom_minimum_size = Vector2(canvas.x * s + PANEL_W + 48.0, VIEW_H)

	var page_holder := Control.new()
	page_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_holder.add_child(page_holder)
	# render every building as "built", no badges/coverings — the finished page is the tracing surface
	HomeZoneView.build(page_holder, manifest, func(_id: String) -> String: return "built",
		func(_id: String) -> Dictionary: return {}, [])

	overlay = RegionEditorOverlay.new()
	overlay.name = "ZoneEditor"
	overlay.call("set_image_size", canvas)
	overlay.call("set_edit_enabled", true)
	overlay.regions_changed.connect(_on_zones_changed)
	overlay.selection_changed.connect(_select_zone)
	overlay.region_drawn.connect(_on_zone_drawn)
	stage_holder.add_child(overlay)

func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "ZonePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.custom_minimum_size = Vector2(PANEL_W, 0.0)
	panel.position = Vector2(size.x - PANEL_W - 16.0, 16.0)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.03, 0.85)
	style.border_color = Color(0.4, 0.8, 0.45, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)
	var lbl := Label.new()
	lbl.text = "Page"
	row.add_child(lbl)
	page_select = OptionButton.new()
	page_select.name = "PageSelect"
	page_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(pages.size()):
		page_select.add_item(String(pages[i].name), i)
	page_select.item_selected.connect(_open_page)
	row.add_child(page_select)

	var title := Label.new()
	title.text = "Unlock zones (order = unlock order)"
	title.add_theme_font_size_override("font_size", FS.TINY)
	stack.add_child(title)

	zone_list = ZoneListPanel.new()
	zone_list.name = "ZoneList"
	zone_list.connect("draw_requested", _on_draw_requested)
	zone_list.connect("region_selected", _select_zone)
	zone_list.connect("reordered", _on_reordered)
	zone_list.connect("region_renamed", _on_renamed)
	zone_list.connect("enabled_changed", _on_enabled)
	zone_list.connect("deleted", _on_deleted)
	stack.add_child(zone_list)

	var save := Button.new()
	save.name = "SaveZones"
	save.text = "Save Zones"
	save.pressed.connect(_save)
	stack.add_child(save)

	save_status = Label.new()
	save_status.name = "SaveStatus"
	save_status.add_theme_font_size_override("font_size", FS.DEBUG)
	save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(save_status)
	add_child(panel)

# ── sync: the doc is the single source; overlay + list are projections ─────────

func _sync_all() -> void:
	if page_select != null:
		page_select.select(page_index)
	overlay.call("set_regions", doc.zones)
	overlay.call("set_selected_region", selected)
	if zone_list != null:
		zone_list.call("set_regions", doc.zones, selected)

func _select_zone(index: int) -> void:
	selected = clampi(index, 0, maxi((doc.zones as Array).size() - 1, 0))
	overlay.call("set_selected_region", selected)
	if zone_list.has_method("set_selected"):
		zone_list.call("set_selected", selected)

func _on_draw_requested() -> void:
	overlay.call("set_draw_mode", true)

func _on_zone_drawn(points: Array) -> void:
	if Model.add_zone(doc, points):
		selected = (doc.zones as Array).size() - 1
		_sync_all()

# Geometry/button edits from the overlay handles: merge by index (the overlay clone carries
# name/enabled/points/button only — exactly the zone shape, so adopt it wholesale).
func _on_zones_changed(next_zones: Array) -> void:
	var zones: Array = doc.zones
	for i in range(mini(zones.size(), next_zones.size())):
		zones[i] = next_zones[i]

func _on_reordered(from_index: int, to_index: int) -> void:
	Model.reorder_zone(doc, from_index, to_index)
	selected = clampi(to_index, 0, (doc.zones as Array).size() - 1)
	_sync_all()

func _on_renamed(index: int, name: String) -> void:
	Model.rename_zone(doc, index, name)

func _on_enabled(index: int, on: bool) -> void:
	Model.set_enabled(doc, index, on)

func _on_deleted(index: int) -> void:
	Model.delete_zone(doc, index)
	selected = clampi(index, 0, maxi((doc.zones as Array).size() - 1, 0))
	_sync_all()

func _save() -> void:
	var res_path: String = Model.unlocks_path(String(pages[page_index].id))
	var path := ProjectSettings.globalize_path(res_path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		save_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		save_status.text = "Save failed: could not write %s" % res_path.get_file()
		push_error("[zone_workbench] could not write %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	f.store_string(Model.serialize(doc))
	f.close()
	save_status.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
	save_status.text = "Saved ✓  %d zones → %s" % [(doc.zones as Array).size(), res_path.get_file()]
	print("[zone_workbench] saved %d zones to %s" % [(doc.zones as Array).size(), res_path])
```

- [ ] **Step 3: Create the scene**

`games/tools/zone_workbench/ZoneWorkbench.tscn` — a minimal one-node scene (mirror `VineMaskTool.tscn`'s shape): root `Control` named `ZoneWorkbench` with `script = zone_workbench.gd`, full-rect anchors. Author the .tscn by hand:

```
[gd_scene load_steps=2 format=3 uid="uid://zone_workbench_root"]

[ext_resource type="Script" path="res://games/tools/zone_workbench/zone_workbench.gd" id="1"]

[node name="ZoneWorkbench" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

(Godot rewrites the uid on first import; run `make import` after creating it.)

- [ ] **Step 4: Add the Make target**

In `Makefile`: add `zones` to `.PHONY` and this target next to the other tool launchers:

```make
zones: ## draw a page's unlock zones over the real scene (a real window):  make zones
	$(GODOT) --path $(PROJECT) res://games/tools/zone_workbench/ZoneWorkbench.tscn
```

- [ ] **Step 5: Verify — headless smoke + born-minimized screenshot**

Run `make import`, then `make test-fast` (green), then take the quiet screenshot via the override.cfg pattern (`tools/quiet_godot.sh` equivalent — this repo runs `$(QUIET)`; if no shot target exists for the tool, use the transient override.cfg recipe from the global notes) and LOOK at it: the page art renders, the right panel shows Page picker + Draw Zone + Save. Drawing itself is mouse-driven; the see-the-result gate here is "tool opens rendering the real page".

- [ ] **Step 6: Commit**

```bash
git add games/tools/zone_workbench Makefile
git commit -m "feat(tools): zone workbench — draw unlock zones on the picture-book pages (make zones)"
```

### Task 4: Vine dead-code sweep (map.gd + debug.gd + stale comments)

**Files:**
- Modify: `engine/scripts/scenes/map.gd`
- Modify: `engine/scripts/ui/debug.gd`
- Modify: `games/grove/home_chrome.gd` (one stale comment)

**Interfaces:** none produced; the deleted symbols must have zero remaining references.

- [ ] **Step 1: Verify the call graph**

For each symbol below, grep the whole repo (excluding `.godot`, `.worktrees`, docs) and confirm its only callers are inside the same dead set: `_build_vine_spot`, `_region_zone_hit`, `VINE_DEBUG_MODES`, `_vine_debug_mode_idx`, `debug_cycle_vine_fx`, `debug_vine_diag`, `_active_vine_view`, `_apply_vine_debug_mode`, `_vine_diag_enabled`, `_print_vine_diag`. Also confirm `_seat_spots` / `_build_map_base` / `_make_spot` / `_build_home_spot` liveness: if `_seat_spots` and `_build_map_base` have NO live callers (the header comment says the cluster is retired), they are part of the dead set too — but `_make_spot`-style helpers may have live callers (e.g. `_home_owned_item` used elsewhere); keep any function with a caller outside the dead set. Record the verified dead set before deleting.

- [ ] **Step 2: Delete the dead set from map.gd**

Delete func→next-func ranges only (never swallow the comment block above the NEXT live function). Remove: the verified dead functions from Step 1, the `is_vine` branches (if their containing function survives), the `VINE_DEBUG_MODES` const + `_vine_debug_mode_idx` var, and vine wording in surviving comments (file header lines 9–11, `_play_btn`'s "(vine → unlock)" note, `_seat_spots`-adjacent comments if the function survives).

- [ ] **Step 3: Delete the debug menu hooks**

In `engine/scripts/ui/debug.gd`: remove the `has_method("debug_cycle_vine_fx")` / `has_method("debug_vine_diag")` registration blocks and the `_act_vine_fx_mode` / `_act_vine_diag` statics.

- [ ] **Step 4: Fix the stale comment in home_chrome.gd**

Line 8 references `grove_vine_tests._test_boot_does_zero_live_work` (a deleted suite) — repoint the sentence at the current boot-work guard (grep `boot_does_zero_live_work` in `games/grove/tests/` for its new home; if none, drop the pointer). `ICON_PLAY_RESTORE := "vine"` STAYS (live icon).

- [ ] **Step 5: Smoke-test and commit**

Run: `make test-fast`, then `make test`.
Expected: all suites PASS (GDScript parse errors from a mis-cut range fail loudly here).

```bash
git add engine/scripts/scenes/map.gd engine/scripts/ui/debug.gd games/grove/home_chrome.gd
git commit -m "chore(map): delete the retired vine-mask dead code"
```

### Task 5: Delete the vine tool, bakes, and old map art

**Files:**
- Delete: `games/tools/vine_mask_tool/` (everything remaining after Task 3's moves)
- Delete: `games/tools/bake_vine_region_maps.gd` + `.uid`
- Delete: `games/grove/assets/baked/vine/`
- Delete: `games/grove/assets/map/map{1..5}.png`, `map{1..5}_mask.png` + their `.import` files
- Modify: `Makefile` (drop `vine` + `bake-vine` targets, fix `bake`, `.PHONY`)

- [ ] **Step 1: Verify nothing live references the deletions**

```bash
grep -rn "vine_mask_tool\|bake_vine\|baked/vine\|assets/map/map[0-9]" \
  --include="*.gd" --include="*.tscn" --include="*.json" --include="Makefile" \
  engine games Makefile | grep -v vine_mask_tool/ | grep -v bake_vine_region_maps
```

Expected: no hits outside the files being deleted (docs/ mentions are history, fine).

- [ ] **Step 2: Delete**

```bash
git rm -r games/tools/vine_mask_tool
git rm games/tools/bake_vine_region_maps.gd games/tools/bake_vine_region_maps.gd.uid
git rm -r games/grove/assets/baked/vine
git rm games/grove/assets/map/map1.png games/grove/assets/map/map1.png.import \
       games/grove/assets/map/map1_mask.png games/grove/assets/map/map1_mask.png.import \
       games/grove/assets/map/map2.png games/grove/assets/map/map2.png.import \
       games/grove/assets/map/map2_mask.png games/grove/assets/map/map2_mask.png.import \
       games/grove/assets/map/map3.png games/grove/assets/map/map3.png.import \
       games/grove/assets/map/map3_mask.png games/grove/assets/map/map3_mask.png.import \
       games/grove/assets/map/map4.png games/grove/assets/map/map4.png.import \
       games/grove/assets/map/map4_mask.png games/grove/assets/map/map4_mask.png.import \
       games/grove/assets/map/map5.png games/grove/assets/map/map5.png.import \
       games/grove/assets/map/map5_mask.png games/grove/assets/map/map5_mask.png.import
```

- [ ] **Step 3: Makefile cleanup**

Remove the `vine` and `bake-vine` targets; change `bake: bake-textures bake-vine` to `bake: bake-textures` (update its `##` help line — no more "vine region maps"); remove `vine` and `bake-vine` from `.PHONY`.

- [ ] **Step 4: Full verification and commit**

Run: `make import` (drops stale imports), `make test` .
Expected: every suite PASS.

```bash
git add -A
git commit -m "chore(assets): remove the vine mask tool, bakes, and the old map art"
```

### Task 6: Final verification + merge

- [ ] **Step 1: Full sweep in the worktree**

Run: `make test` — all suites PASS. `git status --short` — clean (no strays).

- [ ] **Step 2: See the result**

Re-take the zone-workbench screenshot (Task 3 Step 5 command) and deliver it to the Dev for the visual checkpoint. Confirm `grep -rn "games/grove/vine\|vine_mask_tool" engine games --include="*.gd"` returns nothing.

- [ ] **Step 3: Merge to main and clean up (from the primary tree)**

Per the standing workflow: check `git worktree list` + main's dirty files for a peer agent on the same files first; then:

```bash
cd /Users/xup/dh/merge
git merge vine-retire
make import && make test-fast
git worktree remove /Users/xup/dh/wt-vine-retire
git branch -d vine-retire
```
