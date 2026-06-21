# Vine-driven home map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the game's home map (and future maps) from the vine mask tool's output — an animated vine overlay over the clean base — with unlockable regions tracking the tool's detected region count, and `mapN` in the tool driving the N-th game map slot automatically.

**Architecture:** Extract the tool's rendering core into a shared `VineMapView` Control used by both the game and the tool. A `VineMaps` helper reads the tool's `maps.json` + per-map regions JSON. `grove_data.MAPS` overlays vine entries onto existing map slots *by index* — each slot keeps its `id`/`name`/`hub`, but its rendering becomes vine-driven and its `spots` are derived one-per-region (cost from a ladder + optional override file). `map.gd` grows a vine render branch; the existing star-buy/`unlocks` flow toggles each region's vines on rebuild.

**Tech Stack:** Godot 4.6 / GDScript. Headless SceneTree test suites (`make test-fast`, `make test-grove`). Real-renderer capture via `engine/tools/quiet_godot.sh` for visual verification.

---

## Conventions for this plan

- All paths are relative to the worktree root `/Users/xup/dh/merge/.claude/worktrees/vine-home-map`.
- Run logic tests headless: `make test-one SUITE=games/grove/tests/<suite>` or the grouped `make test-grove` / `make test-fast`.
- The runner fails on any `FAIL`/crash and prints a timing table — never trust exit code alone.
- Commit after each task. Branch is `worktree-vine-home-map`; never merge to main here (the parent tree owns merges).
- **Decision baked in (from the spec, refined to cut churn):** vine maps overlay existing slots *positionally*, preserving each slot's `id`/`name`. Spot ids are `<slot_id>_r<index>` (e.g. `farmhouse_r0`). This keeps `last_map`/`map_for_id("farmhouse")`/card progression working unchanged.
- **Decision baked in (risk reduction):** the vine **shaders stay where they are** (`res://games/tools/vine_mask_tool/shaders/`); `VineMapView` references them by that path. Both the game and the tool use the same shader files, so the "shared" guarantee holds without a risky resource move. (Moving them under `games/grove/vine/shaders/` is optional future cleanup.)

---

## File structure

| File | Status | Responsibility |
|---|---|---|
| `games/grove/vine/vine_map_view.gd` | create | Shared renderer: base + mask + region-index map + per-region overlay layers; `set_region_enabled`/`region_count`/`set_calm`. No editing UI, no save IO. |
| `games/grove/vine/vine_maps.gd` | create | Read the tool's `maps.json` + per-map regions JSON; expose entries/regions/count + spot derivation (cost ladder + override file + centroid). |
| `games/grove/vine/<map_id>_spots.json` | create (optional fixtures) | Per-map region→`{name,cost}` overrides. |
| `games/grove/grove_data.gd` | modify | `_build_maps()` overlays vine entries onto slots by index. |
| `engine/scripts/scenes/map.gd` | modify | Vine render branch in `_build_map_base`; vine badge seating; region-enabled wiring on rebuild. |
| `games/tools/vine_mask_tool/maps/maps.json` | modify | Add `map2` placeholder entry. |
| `games/tools/vine_mask_tool/maps/map2_placeholder_regions.json` | create | Copy of map1 regions for the placeholder. |
| `games/tools/vine_mask_tool/scripts/vine_mask_tool.gd` | modify | Render through a `VineMapView` instance; keep all editing UI. |
| `games/grove/tests/grove_vine_tests.gd` | create | New suite: VineMaps + grove_data vine overlay + VineMapView headless. |
| `engine/tools/run_suites.py` caller / `Makefile` `GROVE_TESTS` | modify | Register the new suite. |
| `games/grove/tests/grove_ui_tests.gd`, `grove_placement_tool_tests.gd` | modify | Re-point farmhouse-id / farm_home assertions to the vine home. |

---

## Task 1: `VineMaps` registry + spot derivation (pure data, no rendering)

Start with the data layer — it has no Godot-node dependencies and is fully headless-testable.

**Files:**
- Create: `games/grove/vine/vine_maps.gd`
- Test: `games/grove/tests/grove_vine_tests.gd`
- Modify: `Makefile` (add the suite to `GROVE_TESTS`)

- [ ] **Step 1: Register the new suite in the Makefile**

Find the `GROVE_TESTS` variable in `Makefile` (grep `GROVE_TESTS`). Append the new suite path to it, matching the existing style, e.g.:

```make
GROVE_TESTS := games/grove/tests/grove_model_tests games/grove/tests/grove_economy_tests \
	games/grove/tests/grove_ui_tests games/grove/tests/grove_placement_tests \
	games/grove/tests/grove_shop_ads_tests games/grove/tests/grove_placement_tool_tests \
	games/grove/tests/grove_vine_tests
```

(Use the exact existing list + append `games/grove/tests/grove_vine_tests`. Do not drop any existing entry.)

- [ ] **Step 2: Write the failing test suite**

Create `games/grove/tests/grove_vine_tests.gd`:

```gdscript
extends "res://games/grove/tests/grove_test_base.gd"
## grove · vine — VineMaps registry + spot derivation + VineMapView headless instantiation.

const VineMaps = preload("res://games/grove/vine/vine_maps.gd")

func _initialize() -> void:
	begin("grove · vine")
	_test_registry()
	_test_spot_derivation()
	finish()

func _test_registry() -> void:
	var entries := VineMaps.entries()
	ok(entries.size() >= 1, "maps.json yields at least one vine map entry")
	var e0: Dictionary = entries[0]
	ok(String(e0.get("id", "")) == "map1_farm", "first vine entry is map1_farm")
	var regions := VineMaps.regions_for(e0)
	ok(regions.size() == 8, "map1_farm regions JSON has 8 regions (matches region_count)")
	ok(regions[0].has("points") and regions[0].has("tuning"), "a region carries points + tuning")

func _test_spot_derivation() -> void:
	var e0: Dictionary = VineMaps.entries()[0]
	var spots := VineMaps.spots_for("farmhouse", e0)
	ok(spots.size() == 8, "8 regions -> 8 derived spots")
	ok(String(spots[0].id) == "farmhouse_r0" and String(spots[7].id) == "farmhouse_r7", "spot ids are <slot>_r<index>")
	ok(int(spots[0].cost) == 3 and int(spots[3].cost) == 4 and int(spots[7].cost) == 5, "cost ladder 3,3,3,4,4,4,5,5")
	var p0: Vector2 = spots[0].pos
	ok(p0.x > 0.0 and p0.x < 1.0 and p0.y > 0.0 and p0.y < 1.0, "centroid pos is normalized into (0,1)")
	# override file wins when present
	var ov := VineMaps.spots_for("ovtest", {"id": "ovtest", "regions_path": "res://games/grove/tests/fixtures/ov_regions.json"}, "res://games/grove/tests/fixtures/ov_spots.json")
	ok(ov.size() == 2 and String(ov[0].name) == "Cottage" and int(ov[0].cost) == 9, "override file sets name + cost")
```

- [ ] **Step 3: Add the test fixtures**

Create `games/grove/tests/fixtures/ov_regions.json`:

```json
{ "image_size": [100, 100], "regions": [
  {"name": "Region 1", "enabled": true, "points": [[10,10],[30,10],[30,30],[10,30]], "tuning": {}},
  {"name": "Region 2", "enabled": true, "points": [[50,50],[70,50],[70,70],[50,70]], "tuning": {}}
] }
```

Create `games/grove/tests/fixtures/ov_spots.json`:

```json
{ "0": {"name": "Cottage", "cost": 9} }
```

- [ ] **Step 4: Run the test, verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_vine_tests`
Expected: FAIL/parse error — `vine_maps.gd` does not exist yet.

- [ ] **Step 5: Implement `vine_maps.gd`**

Create `games/grove/vine/vine_maps.gd`:

```gdscript
extends RefCounted
## Reads the vine mask tool's output (maps.json + per-map regions JSON) and derives game spots.
## This is the single seam that makes the home "auto-update" when the tool saves: the game reads
## these files at map-build time, so a tool save shows up on the next home open.

const MAPS_JSON := "res://games/tools/vine_mask_tool/maps/maps.json"
# Star cost per region, indexed by region order; past the table, the tail value repeats.
const COST_LADDER := [3, 3, 3, 4, 4, 4, 5, 5]
const COST_TAIL := 5

# The maps[] array from maps.json, in file order. [] if the file is missing/unparseable.
static func entries() -> Array:
	if not FileAccess.file_exists(MAPS_JSON):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAPS_JSON))
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var out: Array = []
	for e in (parsed as Dictionary).get("maps", []):
		if e is Dictionary and String(e.get("id", "")) != "":
			out.append(e)
	return out

static func count() -> int:
	return entries().size()

# The regions array for one entry (parsed from its regions_path). [] on any failure.
static func regions_for(entry: Dictionary) -> Array:
	var path := String(entry.get("regions_path", ""))
	if path == "" or not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("regions"):
		return []
	var regions: Variant = (parsed as Dictionary)["regions"]
	return regions if regions is Array else []

# The image_size [w,h] for an entry's regions file (for normalizing centroids). Defaults to [1,1].
static func image_size_for(entry: Dictionary) -> Vector2:
	var path := String(entry.get("regions_path", ""))
	if path != "" and FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("image_size"):
			var s: Array = (parsed as Dictionary)["image_size"]
			if s.size() == 2 and float(s[0]) > 0.0 and float(s[1]) > 0.0:
				return Vector2(float(s[0]), float(s[1]))
	return Vector2.ONE

# One spot per region for slot `slot_id`. id=<slot>_r<i>; name/cost from override file else defaults;
# pos = polygon centroid normalized to image_size. `override_path` defaults to the per-slot file.
static func spots_for(slot_id: String, entry: Dictionary, override_path: String = "") -> Array:
	var regions := regions_for(entry)
	var isize := image_size_for(entry)
	if override_path == "":
		override_path = "res://games/grove/vine/%s_spots.json" % slot_id
	var overrides := {}
	if FileAccess.file_exists(override_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(override_path))
		if typeof(parsed) == TYPE_DICTIONARY:
			overrides = parsed
	var spots: Array = []
	for i in range(regions.size()):
		var region: Dictionary = regions[i]
		var ov: Dictionary = overrides.get(str(i), {})
		spots.append({
			"id": "%s_r%d" % [slot_id, i],
			"name": String(ov.get("name", region.get("name", "Region %d" % (i + 1)))),
			"cost": int(ov.get("cost", COST_LADDER[i] if i < COST_LADDER.size() else COST_TAIL)),
			"pos": _centroid(region.get("points", []), isize),
		})
	return spots

static func _centroid(points: Array, isize: Vector2) -> Vector2:
	if points.is_empty():
		return Vector2(0.5, 0.5)
	var sum := Vector2.ZERO
	for p in points:
		sum += Vector2(float(p[0]), float(p[1]))
	var c: Vector2 = sum / float(points.size())
	return Vector2(clampf(c.x / isize.x, 0.0, 1.0), clampf(c.y / isize.y, 0.0, 1.0))
```

- [ ] **Step 6: Run the test, verify it passes**

Run: `make test-one SUITE=games/grove/tests/grove_vine_tests`
Expected: PASS — all `_test_registry` + `_test_spot_derivation` asserts pass.

- [ ] **Step 7: Commit**

```bash
git add games/grove/vine/vine_maps.gd games/grove/tests/grove_vine_tests.gd games/grove/tests/fixtures Makefile
git commit -m "feat(vine): VineMaps registry + region->spot derivation"
```

---

## Task 2: `grove_data.MAPS` overlays vine maps onto slots by index

**Files:**
- Modify: `games/grove/grove_data.gd` (`_build_maps()` at ~line 229–287)
- Test: `games/grove/tests/grove_vine_tests.gd`

- [ ] **Step 1: Add the failing test for the overlay**

Append to `grove_vine_tests.gd` `_initialize()` (before `finish()`): `_test_maps_overlay()`. Add the method:

```gdscript
func _test_maps_overlay() -> void:
	# slot 0 keeps its id/name but is now vine-driven with region-derived spots
	ok(String(G.MAPS[0].id) == "farmhouse", "slot 0 keeps id 'farmhouse'")
	ok(G.MAPS[0].has("vine"), "slot 0 is vine-driven (carries the maps.json entry)")
	ok(G.MAPS[0].spots.size() == 8, "slot 0 has 8 region spots")
	ok(String(G.MAPS[0].spots[0].id) == "farmhouse_r0", "slot 0 spot ids are farmhouse_r*")
	ok(bool(G.MAPS[0].get("hub", false)), "slot 0 stays the hub")
	# legacy slots without a vine entry are untouched
	ok(not G.MAPS[G.MAPS.size() - 1].has("vine"), "the last legacy slot is not vine-driven")
```

- [ ] **Step 2: Run, verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_vine_tests`
Expected: FAIL — `G.MAPS[0]` has no `vine` key, spots are still the 7 `fh_*`.

- [ ] **Step 3: Implement the overlay in `grove_data.gd`**

At the top of `grove_data.gd` (with the other consts), add the preload:

```gdscript
const VineMaps = preload("res://games/grove/vine/vine_maps.gd")
```

In `_build_maps()`, replace the final `return maps` with a call through the overlay:

```gdscript
	]
	return _apply_vine_maps(maps)
```

Add the new function directly after `_build_maps()`:

```gdscript
# Overlay the vine mask tool's maps onto the hardcoded slots, positionally: slot i becomes vine-driven
# from the i-th maps.json entry when present. The slot KEEPS its id/name/hub (so saves + progression +
# map_for_id stay stable); only its rendering (`vine`) and `spots` (one per region) change. Slots with
# no matching tool entry are left exactly as-is. Any missing/unparseable tool file => no overlay (the
# game falls back to the legacy maps), so this can never break the build.
static func _apply_vine_maps(maps: Array) -> Array:
	var entries := VineMaps.entries()
	for i in range(mini(entries.size(), maps.size())):
		var entry: Dictionary = entries[i]
		var spots := VineMaps.spots_for(String(maps[i].id), entry)
		if spots.is_empty():
			continue   # a tool entry with no readable regions: leave the legacy slot intact
		maps[i]["vine"] = entry
		maps[i].erase("home")   # vine rendering supersedes the §16 mask-reveal home for this slot
		maps[i]["spots"] = spots
	return maps
```

- [ ] **Step 4: Run, verify it passes**

Run: `make test-one SUITE=games/grove/tests/grove_vine_tests`
Expected: PASS — overlay asserts pass.

- [ ] **Step 5: Run the broader grove suites to see expected churn**

Run: `make test-grove`
Expected: `grove_vine_tests` PASS; some `grove_ui_tests` / `grove_economy_tests` / `grove_placement_tool_tests` asserts FAIL where they hardcode `fh_*` ids or farm_home positions. Note exactly which — they are fixed in Task 6. (Do not fix them yet.)

- [ ] **Step 6: Commit**

```bash
git add games/grove/grove_data.gd games/grove/tests/grove_vine_tests.gd
git commit -m "feat(vine): grove_data overlays vine maps onto slots by index"
```

---

## Task 3: `VineMapView` shared renderer (extract from the tool)

This extracts the tool's rendering core into a standalone Control. The methods are **moved verbatim** from `vine_mask_tool.gd` (the tool delegates to it in Task 5), so the game and tool share one renderer.

**Files:**
- Create: `games/grove/vine/vine_map_view.gd`
- Reference (read-only, source of moved code): `games/tools/vine_mask_tool/scripts/vine_mask_tool.gd`
- Test: `games/grove/tests/grove_vine_tests.gd`

- [ ] **Step 1: Write the failing headless test**

Append `_test_view_headless()` to `grove_vine_tests.gd` `_initialize()` and add:

```gdscript
const VineMapView = preload("res://games/grove/vine/vine_map_view.gd")

func _test_view_headless() -> void:
	var e0: Dictionary = VineMaps.entries()[0]
	var view: Control = VineMapView.new()
	get_root().add_child(view)
	view.load_map(e0, VineMaps.regions_for(e0))
	ok(view.region_count() == 8, "VineMapView reports 8 regions for map1_farm")
	view.set_region_enabled(0, false)   # must not error headless
	view.set_region_enabled(0, true)
	ok(view.get_node_or_null("RegionOverlays") != null, "VineMapView builds the per-region overlay tree")
	view.queue_free()
```

(The headless dummy renderer cannot rasterize, but it CAN create nodes, build `Image`/`ImageTexture` on the CPU, and run `Geometry2D` — so this exercises the real build path. Pixel correctness is verified by the real-renderer capture in Task 7.)

- [ ] **Step 2: Run, verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_vine_tests`
Expected: FAIL — `vine_map_view.gd` does not exist.

- [ ] **Step 3: Create `vine_map_view.gd` by moving the tool's render core**

Create `games/grove/vine/vine_map_view.gd`. It is a `Control` that owns ONLY rendering. Move the following members + methods **verbatim** from `vine_mask_tool.gd` (current line refs in parentheses) into it, then add the public API below. Methods to move unchanged:

- The `CONTROLS` table (`controls` source of truth, ~lines 16–40) — the tuning knob→shader-param map.
- `_build_mask_image` (187), `_bake_alpha_from_luminance` (207), `_build_purple_difference_mask` (218), `_combine_mask_images` (241), `_load_image` (259), `_fallback_mask_image` (264), `_mask_pixel_size` (291).
- `_rebuild_region_map` (570), `_polygon_bounds` (593), `_points_to_packed` (helper used by `_rebuild_region_map`), `_apply_region_map_to_materials` (687).
- `_create_region_overlays` (608), `_create_region_texture_rect` (642), `_create_effect_texture_rect` (665), `_create_effect_template_materials` (269), `_update_template_shader_masks` (281).
- `_apply_all_region_tuning` (702), `_apply_region_tuning` (706), the `_write_shader_value` / `_material_for_target` helpers it calls, and `_set_region_enabled` (the toggle the tool already has).

The shader/material templates: in the tool these come from the `.tscn` (`glow_template`, `vines_template` TextureRects + their ShaderMaterials). In `VineMapView`, build them in code so it has no scene dependency. Add at the top:

```gdscript
extends Control
class_name VineMapView
## Shared vine renderer: clean base + animated vine overlay (per-region shadow/glow/vines/embers),
## driven by a maps.json entry + its regions array. Used by BOTH the game (engine/scripts/scenes/map.gd)
## and the authoring tool (vine_mask_tool.gd). No editing UI, no save IO — pure rendering.

const VINE_SHADER := "res://games/tools/vine_mask_tool/shaders/ominous_vines.gdshader"
const SHADOW_SHADER := "res://games/tools/vine_mask_tool/shaders/vine_shadow.gdshader"
const EMBER_SHADER := "res://games/tools/vine_mask_tool/shaders/vine_embers.gdshader"

var image_size := Vector2i(1, 1)
var mask_offset := Vector2.ZERO
var mask_image: Image
var mask_texture: ImageTexture
var region_map_texture: ImageTexture
var regions: Array = []
var region_count := 1
var region_overlays: Array[Dictionary] = []
var glow_template_material: ShaderMaterial
var vines_template_material: ShaderMaterial
var shadow_template_material: ShaderMaterial
var ember_template_material: ShaderMaterial
var _calm := false
```

Build the glow/vines template materials in code from the values currently in `VineMaskTool.tscn`
(`ShaderMaterial_glow` and `ShaderMaterial_vines`, lines 7–37 of the `.tscn`). Add:

```gdscript
func _make_vine_material(opacity: float, glow_radius: float, glow_strength: float, pulse: float, flow: float, edge: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(VINE_SHADER)
	m.set_shader_parameter("opacity", opacity)
	m.set_shader_parameter("glow_radius", glow_radius)
	m.set_shader_parameter("glow_strength", glow_strength)
	m.set_shader_parameter("pulse_speed", pulse)
	m.set_shader_parameter("flow_speed", flow)
	m.set_shader_parameter("edge_power", edge)
	return m

func _build_templates() -> void:
	# values mirror VineMaskTool.tscn ShaderMaterial_glow / ShaderMaterial_vines
	glow_template_material = _make_vine_material(0.28, 0.012, 1.15, 1.35, 0.65, 1.15)
	vines_template_material = _make_vine_material(0.48, 0.004, 0.42, 2.4, 1.35, 2.8)
	# shadow + ember templates: mirror _create_effect_template_materials (moved from the tool)
	_create_effect_template_materials()
```

> Note: `_create_region_texture_rect` in the tool reads `glow_template`/`vines_template` (TextureRect nodes). In `VineMapView`, change those two reads to `glow_template_material`/`vines_template_material` (the code-built materials) and use `mask_texture` directly for `rect.texture`/`stretch_mode` (`TextureRect.STRETCH_KEEP`). This is the only edit to the moved overlay code.

Public API:

```gdscript
func load_map(entry: Dictionary, region_list: Array) -> void:
	regions = region_list.duplicate(true)
	_load_art(entry)
	_build_templates()
	_rebuild_region_map()
	_create_region_overlays(true)
	_apply_all_region_tuning()

func region_count() -> int:
	return region_count

func set_region_enabled(index: int, on: bool) -> void:
	_set_region_enabled(index, on)   # the moved toggle

func set_calm(on: bool) -> void:
	# reduced-motion: damp the time-driven shader terms (pulse/flow) toward 0 across all overlays.
	_calm = on
	for entry in region_overlays:
		for key in ["shadow", "glow", "vines", "embers"]:
			var rect := entry[key] as TextureRect
			if rect == null: continue
			var m := rect.material as ShaderMaterial
			if on:
				m.set_shader_parameter("pulse_speed", 0.0)
				m.set_shader_parameter("flow_speed", 0.0)

func _load_art(entry: Dictionary) -> void:
	# region geometry + mask come from the mask image (CPU-loaded, no import needed); the base texture
	# is the caller's concern (the game seats map1.png as a separate base layer behind this view).
	mask_image = _build_mask_image(entry)
	if mask_image == null or mask_image.is_empty():
		var s := VineMaps_image_size(entry)
		image_size = Vector2i(int(s.x), int(s.y))
		mask_image = _fallback_mask_image()
	mask_image.convert(Image.FORMAT_RGBA8)
	image_size = Vector2i(mask_image.get_width(), mask_image.get_height())
	mask_texture = ImageTexture.create_from_image(mask_image)
	custom_minimum_size = Vector2(image_size)
	size = Vector2(image_size)

func VineMaps_image_size(entry: Dictionary) -> Vector2:
	return preload("res://games/grove/vine/vine_maps.gd").image_size_for(entry)
```

> `_build_mask_image` already reads `entry["mask"]` + `entry["mask_mode"]` exactly as the tool's `maps.json` describes (luminance for map1) — moved unchanged.

- [ ] **Step 4: Run, verify it passes**

Run: `make test-one SUITE=games/grove/tests/grove_vine_tests`
Expected: PASS — `region_count() == 8`, overlay tree built, toggles don't error.

- [ ] **Step 5: Commit**

```bash
git add games/grove/vine/vine_map_view.gd games/grove/tests/grove_vine_tests.gd
git commit -m "feat(vine): VineMapView shared renderer (extracted render core)"
```

---

## Task 4: `map.gd` renders vine maps + wires unlock → region_enabled

**Files:**
- Modify: `engine/scripts/scenes/map.gd` (`_build_map` ~287, `_build_map_base` ~364, `_seat_spots` ~342, `_card_art_path` ~873)
- Test: `games/grove/tests/grove_economy_tests.gd` (the home-buy section ~286–311)

- [ ] **Step 1: Write the failing test (vine home seats + buys regions)**

In `grove_economy_tests.gd`, the existing home section already asserts `h.spot_hits.size() == G.MAPS[h._map_idx].spots.size()` (now 8) and buys `G.MAPS[0].spots[0]` by index — those keep working. Add an assert right after the buy (after `h._build_map()` re-runs) that the bought region's vines are off. Find the home VineMapView and check its overlay enabled flag. Add this helper at the bottom of the suite:

```gdscript
func _vine_view(h) -> Control:
	return h.content.find_child("VineMapView", true, false)
```

And in the home-buy assert block, after the first spot is bought and the map rebuilt, add:

```gdscript
	var vv = _vine_view(h)
	ok(vv != null, "the hub renders through a VineMapView")
	ok(not bool(vv.region_overlays[0].get("enabled", true)), "buying region 0 turns its vines off")
```

- [ ] **Step 2: Run, verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_economy_tests`
Expected: FAIL — no `VineMapView` node in the hub yet (and likely earlier asserts about the home base).

- [ ] **Step 3: Add the vine branch to `_build_map_base`**

In `map.gd`, near the top of `_build_map_base(z, home)` (line ~364), before the `broken`/`bg` handling, add a vine branch:

```gdscript
	var vine = G.MAPS[z].get("vine", null)
	if typeof(vine) == TYPE_DICTIONARY:
		var frame := _clip_frame()
		_add_cover_layer(frame, String(vine.get("base", "")))      # clean map1.png base
		var VineView := load("res://games/grove/vine/vine_map_view.gd")
		var view: Control = VineView.new()
		view.name = "VineMapView"
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var Grove := load("res://games/grove/vine/vine_maps.gd")
		view.load_map(vine, Grove.regions_for(vine))
		view.set_calm(FX.calm())
		# owned regions show clean (vines off); unowned show vines.
		for i in range(view.region_count()):
			var sid := "%s_r%d" % [String(G.MAPS[z].id), i]
			view.set_region_enabled(i, not spot_owned(sid))
		frame.add_child(view)
		return frame
```

The `VineMapView` is full-rect inside the clip frame, so its UV [0,1] aligns with the base layer (both `STRETCH_SCALE`/cover-fit the same frame). It returns `frame` like the other branches, so `_seat_spots` seats the badges into `content` over it.

- [ ] **Step 4: Seat vine badges (unowned = cost disc at centroid; owned = inert marker)**

In `_seat_spots` (line ~342), the `has_home` path calls `_build_home_spot`. Generalize the per-spot builder so a vine map seats badges by spot `pos` (the region centroid set in `grove_data`). Change `_seat_spots` to detect vine maps:

```gdscript
func _seat_spots(z: int, home: Dictionary, frame: Control) -> void:
	var has_home := not home.is_empty()
	var is_vine := typeof(G.MAPS[z].get("vine", null)) == TYPE_DICTIONARY
	var by_id := _home_buildings(home) if has_home else {}
	for k in G.MAPS[z].spots.size():
		var hit: Control
		if is_vine:
			hit = _build_vine_spot(z, k)
		elif has_home:
			hit = _build_home_spot(z, k, home, frame, by_id)
		else:
			hit = _make_spot(z, k, _map_rect)
		content.add_child(hit)
		spot_hits.append({"node": hit, "z": z, "k": k})
```

Add `_build_vine_spot`, reusing the existing badge builders (they already read `pos` from a building dict — pass a synthetic dict carrying the spot's `pos`):

```gdscript
# A vine map's per-region affordance: unowned -> the ✿cost disc at the region centroid (carries the
# place_spot meta + routes the buy via spot_hits); owned -> an inert marker (keeps spot_hits index-aligned).
func _build_vine_spot(z: int, k: int) -> Control:
	var spot: Dictionary = G.MAPS[z].spots[k]
	var b := {"pos": [float(spot.pos.x), float(spot.pos.y)]}
	if not spot_owned(String(spot.id)):
		return _home_badge(z, k, b)        # existing kit cost disc; reads b.pos, sets place_spot meta
	return _home_owned_item(z, k, b)        # existing inert marker at b.pos
```

`_home_badge` already centers on `b.pos` and tags `place_spot`; no change needed there.

- [ ] **Step 5: Map-select card art for vine maps**

In `_card_art_path(z)` (line ~873), add the vine base as a thumbnail source before the `home`/meadow fallbacks:

```gdscript
	var vine = map_data.get("vine", null)
	if typeof(vine) == TYPE_DICTIONARY:
		var base := String(vine.get("base", ""))
		if base != "" and ResourceLoader.exists(base):
			return base
```

(Place this right after the `map_<id>.png` thumb check, before the `home` clean-art check.)

- [ ] **Step 6: Run, verify it passes**

Run: `make test-one SUITE=games/grove/tests/grove_economy_tests`
Expected: the new vine asserts PASS (hub has a `VineMapView`; buying region 0 disables its vines). Some unrelated `fh_*`-hardcoded asserts may still fail — fixed in Task 6.

- [ ] **Step 7: Commit**

```bash
git add engine/scripts/scenes/map.gd games/grove/tests/grove_economy_tests.gd
git commit -m "feat(vine): map.gd renders vine maps + wires unlock to region_enabled"
```

---

## Task 5: `map2` placeholder (prove mapN → slot N end-to-end)

**Files:**
- Modify: `games/tools/vine_mask_tool/maps/maps.json`
- Create: `games/tools/vine_mask_tool/maps/map2_placeholder_regions.json` (copy of map1's regions)
- Test: `games/grove/tests/grove_vine_tests.gd`

- [ ] **Step 1: Write the failing multi-map test**

Append `_test_multimap()` to `grove_vine_tests.gd` `_initialize()`:

```gdscript
func _test_multimap() -> void:
	ok(VineMaps.count() >= 2, "maps.json holds at least 2 vine maps (map1 + placeholder)")
	ok(G.MAPS[1].has("vine"), "slot 1 is vine-driven from the 2nd tool entry")
	ok(G.MAPS[1].spots.size() == VineMaps.regions_for(VineMaps.entries()[1]).size(), "slot 1 spot count == its regions")
	ok(String(G.MAPS[1].spots[0].id) == "%s_r0" % String(G.MAPS[1].id), "slot 1 spot ids use slot 1's id")
```

- [ ] **Step 2: Run, verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_vine_tests`
Expected: FAIL — only one vine map today.

- [ ] **Step 3: Copy map1's regions to the placeholder**

```bash
cp games/tools/vine_mask_tool/maps/map1_farm_regions.json \
   games/tools/vine_mask_tool/maps/map2_placeholder_regions.json
```

Then edit `map2_placeholder_regions.json` and change its `"map_id"` value to `"map2_placeholder"` (leave regions identical).

- [ ] **Step 4: Add the map2 entry to `maps.json`**

Edit `games/tools/vine_mask_tool/maps/maps.json` to add a second entry (reusing map1's art):

```json
{
  "maps": [
    {
      "id": "map1_farm",
      "name": "Map 1 - Farm",
      "base": "res://games/grove/assets/map/map1.png",
      "mask": "res://games/grove/assets/map/map1_mask.png",
      "mask_mode": "luminance",
      "region_count": 8,
      "regions_path": "res://games/tools/vine_mask_tool/maps/map1_farm_regions.json"
    },
    {
      "id": "map2_placeholder",
      "name": "Map 2 - Placeholder",
      "base": "res://games/grove/assets/map/map1.png",
      "mask": "res://games/grove/assets/map/map1_mask.png",
      "mask_mode": "luminance",
      "region_count": 8,
      "regions_path": "res://games/tools/vine_mask_tool/maps/map2_placeholder_regions.json"
    }
  ]
}
```

- [ ] **Step 5: Run, verify it passes**

Run: `make test-one SUITE=games/grove/tests/grove_vine_tests`
Expected: PASS — `count() >= 2`, slot 1 vine-driven, spot ids `barn_r*` (slot 1's id is still `barn`).

- [ ] **Step 6: Commit**

```bash
git add games/tools/vine_mask_tool/maps/maps.json games/tools/vine_mask_tool/maps/map2_placeholder_regions.json games/grove/tests/grove_vine_tests.gd
git commit -m "feat(vine): add map2 placeholder, proving mapN -> slot N"
```

---

## Task 6: Re-point farmhouse-coupled tests to the vine home

Fix the asserts that Task 2/4 flagged. These assert *mechanism* — re-point fixtures from `fh_*`/farm_home to the vine home.

**Files:**
- Modify: `games/grove/tests/grove_ui_tests.gd` (~line 382 `fh_well`)
- Modify: `games/grove/tests/grove_placement_tool_tests.gd` (`_test_home_badges` ~174)
- Modify: any other `fh_*` literal surfaced by `make test-grove`

- [ ] **Step 1: Re-run the full grove suite and record every failing assert**

Run: `make test-grove`
Note each FAIL line (file:assert text). Expected offenders: `grove_ui_tests` hardcoding `"fh_well"`; `grove_placement_tool_tests._test_home_badges` checking farm_home.json positions.

- [ ] **Step 2: Fix `grove_ui_tests` hardcoded spot id**

In `grove_ui_tests.gd` around line 382–384, replace the literal `"fh_well"` with the home's first region spot id, resolved from data so it never goes stale:

```gdscript
	var hub_spot := String(G.MAPS[0].spots[0].id)
	Save.grove()["unlocks"] = {hub_spot: true}     # past the cold-FTUE gate (a rewarding beat happened)
	# ... and the matching line:
	hm.unlocks = {hub_spot: true}
```

(Find both `"fh_well"` occurrences in that test and route them through `hub_spot`.)

- [ ] **Step 3: Re-point `_test_home_badges` to region centroids**

In `grove_placement_tool_tests.gd`, `_test_home_badges` asserts a badge sits at its `farm_home.json` pos. The hub is now vine-driven, so positions come from region centroids. Replace the `_farm_home_pos()` basis with the vine spots' `pos`:

```gdscript
func _test_home_badges() -> void:
	fresh("place_home")
	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	if hx.content == null:
		hx._ready()
	await create_timer(0.05).timeout
	hx._open_map(G.hub_map())
	await create_timer(0.1).timeout

	# the vine hub seats one cost disc per UNOWNED region, tagged with its spot id at the region centroid.
	var by_spot := {}
	for sp in G.MAPS[G.hub_map()].spots:
		by_spot[String(sp.id)] = sp.pos
	var badges := _find_meta(hx.content, "place_spot", [])
	ok(badges.size() >= 1, "the vine hub seats unlock badges tagged with their spot id")
	var rect: Rect2 = hx._map_rect
	var matched := 0
	for b in badges:
		var sid := String(b.get_meta("place_spot"))
		if not by_spot.has(sid):
			continue
		var ctr: Vector2 = (b as Control).get_global_rect().get_center()
		var nrm := (ctr - rect.position) / rect.size
		var want: Vector2 = by_spot[sid]
		if (nrm - want).length() < 0.02:
			matched += 1
	ok(matched >= 1, "a tagged badge sits at its region centroid (the vine pos basis holds)")
	hx.queue_free()
```

`_test_farm_home_roundtrip` and `_test_board_*`/`_test_overlay_drag` stay unchanged — they test the writer/board independent of the hub, and the home overlay-drag only needs ≥1 badge that moves (still true). If `_test_overlay_drag`'s home portion fails because the placement tool writes vine spot ids into farm_home.json, guard `ui_placement.gd`'s `home` save to skip ids absent from farm_home.json (see Step 4).

- [ ] **Step 4: Guard the placement tool's home save for vine maps (only if Step 3 left a failure)**

If `make test-grove` shows the home overlay-drag failing, open `games/grove/tools/ui_placement.gd`, find where `home` mode writes farm_home.json on drag-release, and skip spots whose id is not already a `buildings[].spot` in farm_home.json (vine regions are positioned in the vine tool, not here). Add a guard like:

```gdscript
	if not _farm_home_has_spot(sid):
		return   # vine-region badge: position is owned by the vine tool's regions JSON, not farm_home.json
```

(Implement `_farm_home_has_spot` by parsing FARM_HOME once.) Only add this if a test actually fails — otherwise leave the tool untouched.

- [ ] **Step 5: Run the full grove suite, verify green**

Run: `make test-grove`
Expected: all grove suites PASS.

- [ ] **Step 6: Commit**

```bash
git add games/grove/tests engine/scripts games/grove/tools
git commit -m "test(vine): re-point farmhouse-coupled asserts to the vine home"
```

---

## Task 7: Refactor `vine_mask_tool.gd` onto `VineMapView`

The game now works. Refactor the tool to render through the same component, deleting its duplicated render core. The editing UI (sliders, region editor overlay, save) stays.

**Files:**
- Modify: `games/tools/vine_mask_tool/scripts/vine_mask_tool.gd`
- Possibly modify: `games/tools/vine_mask_tool/VineMaskTool.tscn`
- Verify: `games/tools/vine_mask_tool/verify_vine_mask_tool.gd`

- [ ] **Step 1: Baseline the tool before touching it**

Run the tool's own verifier and capture a reference frame:

```bash
make test-one SUITE=games/tools/vine_mask_tool/verify_vine_mask_tool
engine/tools/quiet_godot.sh --path . res://games/tools/vine_mask_tool/VineMaskTool.tscn   # if it supports capture; else note it opens
```

Record PASS counts. This is the parity bar.

- [ ] **Step 2: Replace the tool's render core with a `VineMapView` instance**

In `vine_mask_tool.gd`: hold `var view: VineMapView` as a child of `artwork_frame`. In `_apply_current_map()`, replace the inline `_load_art_for_current_map()` / `_rebuild_region_map()` / `_create_region_overlays()` / `_apply_all_region_tuning()` calls with `view.load_map(current_map, regions)` (after `regions` is loaded/detected). Delete the now-moved methods from the tool (they live in `VineMapView`). Keep: `_load_maps`, `_detect_regions_from_mask` + its helpers, `_load_saved_regions`/`_save_regions_to_file`, the slider/region-editor UI, and the `mask_offset` nudge. Where the editor needs to re-render after an edit (region moved, tuning changed, enabled toggled), route through the view: `view.set_region_enabled(i, on)`, and for tuning/geometry edits call a small `view.refresh(regions)` that re-runs `_rebuild_region_map()` + `_apply_all_region_tuning()` (add `refresh` to `VineMapView`).

Add to `VineMapView`:

```gdscript
func refresh(region_list: Array) -> void:
	regions = region_list.duplicate(true)
	_rebuild_region_map()
	_create_region_overlays(true)
	_apply_all_region_tuning()
```

- [ ] **Step 3: Run the tool verifier, verify parity**

Run: `make test-one SUITE=games/tools/vine_mask_tool/verify_vine_mask_tool`
Expected: PASS count matches the Step 1 baseline.

- [ ] **Step 4: Visual parity check (real renderer)**

Launch `make vine` and confirm the map1 vines look identical to the pre-refactor reference (animation, glow, per-region tuning). Compare against the Step 1 capture.

- [ ] **Step 5: Commit**

```bash
git add games/tools/vine_mask_tool games/grove/vine/vine_map_view.gd
git commit -m "refactor(vine): tool renders through the shared VineMapView"
```

---

## Task 8: Full sweep + visual verification of the game home

**Files:** none (verification only)

- [ ] **Step 1: Import assets (map1 + map2 entry + any moved resources)**

Run: `make import`
Expected: completes without import errors.

- [ ] **Step 2: Full test sweep**

Run: `make test`
Expected: ALL SUITES PASS (engine + grove, including `grove_vine_tests`).

- [ ] **Step 3: Capture the game home map (real renderer, no focus steal)**

Use the quiet-godot capture path to screenshot the home map. If a capture harness scene/script exists (grep `tools/map_shot.gd` / `grove_shot.gd`), drive it; otherwise add a tiny capture script under `games/grove/tools/` that loads `Map.tscn`, opens the hub, waits a frame, and saves a PNG to an ignored scratch dir. Capture two frames: fresh save (all regions overgrown) and after buying region 0 (one region cleared).

- [ ] **Step 4: Deliver the captures for human review**

Send both PNGs to the user (the home with vines vs. one region cleared) and compare against `make vine` for map1. Do not eyeball-judge quality from a thumbnail — deliver the files and state what to look for (animation can't show in a still; confirm vine coverage + that the bought region reads as clean).

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore(vine): import + verification captures"
```

---

## Self-review

**Spec coverage:**
- "Home renders the tool's vine output" → Tasks 3 (VineMapView), 4 (map.gd vine branch). ✓
- "Unlockable count == detected regions" → Task 1 (`spots_for` = one per region), Task 2 (overlay), Task 4 (`spot_hits` seats per spot). ✓
- "Tool update → home updates automatically" → Task 1 (`VineMaps` reads the tool files at build time), Task 2 (overlay reads them in `_build_maps`). ✓
- "mapN → slot N automatically" → Task 2 (positional overlay), Task 5 (map2 placeholder proves it). ✓
- "Add map2 placeholder if multi-map missing" → Task 5. (The tool already supports multi-map; the placeholder still proves the game pipeline.) ✓
- "Shared component, refactor tool onto it" → Task 3 (extract), Task 7 (tool delegates). ✓
- "Cost defaults + override file" → Task 1 (`COST_LADDER` + `<slot>_spots.json`). ✓
- "Tests stay green; expected churn re-pointed" → Tasks 2/6. ✓
- "Visual verification, not eyeballed" → Task 8 (deliver files). ✓

**Placeholder scan:** No TBD/TODO. The one conditional task (Task 6 Step 4) is explicitly gated on an observed failure, with concrete code shown. Moved methods in Task 3 are named with line refs, not "etc."

**Type consistency:** `VineMaps.entries()/regions_for()/spots_for()/image_size_for()` used consistently across Tasks 1–5. `VineMapView.load_map()/region_count()/set_region_enabled()/set_calm()/refresh()` consistent across Tasks 3, 4, 7. Spot dict shape `{id,name,cost,pos}` consistent (`grove_data`, `map.gd`, tests). Slot ids preserved (`farmhouse`/`barn`); spot ids `<slot>_r<i>`.

**Open risk flagged in spec (positional replacement displaces the legacy Barn slot):** carried as the chosen default; the `map2` placeholder occupies slot 1 (`barn`). Revisit only if the user prefers append.
