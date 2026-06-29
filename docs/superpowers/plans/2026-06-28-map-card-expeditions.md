# Map-card Expeditions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Expedition into eligible map cards, bias expedition rewards toward the source map, and restrict resident placement to each resident line's home map with clear visual hints.

**Architecture:** Add home-map and weighted-reward rules to the pure content/habitat models first, then thread the source map through Explore and the reward overlay. The map picker remains the single resident management surface; map cards gain an intercepted Expedition button, full 8-cell resident rails, and card-level selection/drag hints. Workbench knobs live under the existing `map_card` block so the preview and game share one config path.

**Tech Stack:** Godot 4.6 GDScript, existing Grove test suites, `games/grove/tools/ui_workbench_kit.gd`, `engine/scripts/scenes/map.gd`, `engine/scripts/core/content.gd`, `engine/scripts/core/habitat.gd`.

## Global Constraints

- Work in `/Users/xup/dh/merge/.worktrees/map-card-expeditions` on branch `codex/map-card-expeditions`.
- Use TDD: write or update tests first, run them and confirm the expected failure, then change production code.
- Rewards enter the shared hand; no auto-placement.
- Each resident kind may be placed only on its home map from `G.resident_lines(z)`.
- Tap selection gives a calm valid-map preview; dragging makes valid/invalid card states stronger.
- Source-map expedition reward weight is `3`; every other unlocked resident line weight is `1`.
- Resident rails show exactly `G.RESIDENT_SLOTS_MAX` cells; cells above current `Habitat.cap(map_id)` are greyed and invalid.
- Initial fresh-worktree `make test-fast` failed before feature code because of existing asset/bake/null-texture failures; do not claim that suite is newly green unless those failures are fixed.

---

### Task 1: Home-map Resident Rules in Content and Habitat

**Files:**
- Modify: `engine/scripts/core/content.gd`
- Modify: `engine/scripts/core/habitat.gd`
- Modify: `games/grove/tests/grove_residents_tests.gd`

**Interfaces:**
- Produces: `G.resident_home_map(kind: String) -> int`
- Produces: `G.resident_home_map_id(kind: String) -> String`
- Produces: `Habitat.can_place_on(map_id: String, inst: Dictionary) -> bool`
- Updates: `Habitat.place`, `Habitat.place_merge`, and `Habitat.move` enforce home-map placement.

- [ ] **Step 1: Write the failing home-map model tests**

Add a helper and call to `games/grove/tests/grove_residents_tests.gd`:

```gdscript
func _initialize() -> void:
	begin("grove · residents habitat")
	_test_hand()
	_test_home_map_rules()
	await _test_hand_drop_merge_targets_slot()
	_test_place()
	_test_place_merge()
	_test_production()
	_test_rewards()
	await _test_residents_dock()
	finish()

func _resident_kind_for_map(z: int) -> String:
	var lines: Array = G.resident_lines(z)
	return String(lines[0].id) if not lines.is_empty() else ""

func _test_home_map_rules() -> void:
	fresh("resident_home_map_rules")
	ok(G.resident_home_map("ember") == 0, "ember belongs to the Farm")
	ok(G.resident_home_map_id("sprout") == String(G.MAPS[1].id), "sprout belongs to the Orchard/Barn slot")
	ok(G.resident_home_map("not_a_resident") == -1, "unknown resident kinds have no home map")
	ok(G.resident_home_map_id("not_a_resident") == "", "unknown resident kinds have no home map id")

	fresh("habitat_home_map_place")
	_open_spots(1)
	var farm_id := String(G.MAPS[0].id)
	var barn_id := String(G.MAPS[1].id)
	Habitat.hand_add("ember", 1)
	ok(Habitat.can_place_on(farm_id, Habitat.hand()[0]), "a resident can be placed on its home map")
	ok(not Habitat.can_place_on(barn_id, Habitat.hand()[0]), "a resident cannot be placed on a non-home map")
	ok(Habitat.place(farm_id, 0), "home-map placement succeeds")
	Habitat.hand_add("ember", 1)
	ok(not Habitat.place(barn_id, 0), "wrong-map placement is refused")
	ok(Habitat.hand().size() == 1 and Habitat.placed(barn_id).is_empty(), "a refused wrong-map resident stays in hand")

	fresh("habitat_home_map_merge_move")
	_open_spots(1)
	Habitat.hand_add("ember", 2)
	ok(Habitat.place(farm_id, 0), "setup places ember on Farm")
	Habitat.hand_add("ember", 2)
	ok(Habitat.place_merge(farm_id, 0, 0), "home-map place-merge still succeeds")
	ok(not Habitat.move(farm_id, 0, barn_id), "moving a resident away from its home map is refused")
	ok(Habitat.placed(farm_id).size() == 1 and Habitat.placed(barn_id).is_empty(), "wrong-map move leaves the resident in place")
```

Update old test fixtures in this file so general placement/production tests use real resident kinds for the target map:

```gdscript
var kind := _resident_kind_for_map(0) # for farmhouse
var kind := _resident_kind_for_map(1) # for barn
var kind := _resident_kind_for_map(2) # for pond
var kind := _resident_kind_for_map(3) # for orchard
var kind := _resident_kind_for_map(4) # for meadow
```

Use those values instead of arbitrary `moss`, `acorn`, `lantern`, or `fern` when the test is about placement, production, selling, or collecting rather than unknown-kind rejection.

- [ ] **Step 2: Run the resident suite and verify RED**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_residents_tests
```

Expected: FAIL because `resident_home_map`, `resident_home_map_id`, and `Habitat.can_place_on` do not exist yet.

- [ ] **Step 3: Implement content home-map lookup**

Add to `engine/scripts/core/content.gd` near `resident_lines`:

```gdscript
## The home map index for a resident kind, derived from the resident lines each map offers.
## Returns -1 for unknown kinds.
static func resident_home_map(kind: String) -> int:
	for z in MAPS.size():
		for td in resident_lines(z):
			if String(td.get("id", "")) == kind:
				return z
	return -1

## The home map id for a resident kind, or "" for unknown kinds.
static func resident_home_map_id(kind: String) -> String:
	var z := resident_home_map(kind)
	return String(MAPS[z].id) if z >= 0 else ""
```

- [ ] **Step 4: Implement habitat placement enforcement**

Add to `engine/scripts/core/habitat.gd` above `place`:

```gdscript
## True when `inst` belongs on `map_id`. Unknown resident kinds cannot be newly placed.
static func can_place_on(map_id: String, inst: Dictionary) -> bool:
	var kind := String(inst.get("kind", ""))
	if kind == "":
		return false
	return Content.resident_home_map_id(kind) == map_id
```

Update `place`:

```gdscript
static func place(map_id: String, index: int, now: float = -1.0) -> bool:
	var h := hand()
	if index < 0 or index >= h.size() or is_full(map_id):
		return false
	var inst: Dictionary = h[index]
	if not can_place_on(map_id, inst):
		return false
	_settle(map_id, now)
	h.remove_at(index)
	_set_hand(h)
	var p := placed(map_id)
	p.append({"kind": String(inst.kind), "tier": int(inst.tier)})
	_set_placed(map_id, p)
	return true
```

Update `move` after reading `inst`:

```gdscript
var inst: Dictionary = src[index]
if not can_place_on(to_id, inst):
	return false
```

Update `place_merge` after reading the hand spirit:

```gdscript
var a: Dictionary = h[h_index]
if not can_place_on(map_id, a):
	return false
```

- [ ] **Step 5: Run the resident suite and verify GREEN**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_residents_tests
```

Expected: PASS for the resident suite.

- [ ] **Step 6: Commit Task 1**

```bash
git add engine/scripts/core/content.gd engine/scripts/core/habitat.gd games/grove/tests/grove_residents_tests.gd
git commit -m "feat(residents): enforce resident home maps"
```

### Task 2: Source-map Expedition Rewards

**Files:**
- Modify: `engine/scripts/core/habitat.gd`
- Modify: `engine/scripts/core/explore.gd`
- Modify: `engine/scripts/ui/explore_reward.gd`
- Modify: `games/grove/tests/grove_residents_tests.gd`
- Modify: `games/grove/tests/grove_explore_tests.gd`

**Interfaces:**
- Produces: `Habitat.resident_reward_pool(source_map_id := "") -> Array`
- Produces: `Habitat.roll_reward_kind(source_map_id: String, rng: RandomNumberGenerator) -> String`
- Updates: `Habitat.grant_chest(count: int, source_map_id := "") -> Array`
- Produces: `Explore.source_map_id() -> String`
- Updates: `Explore.begin_run(equip: Dictionary, source_map_id := "")`

- [ ] **Step 1: Write failing reward-pool and run-source tests**

Add to `_test_rewards()` in `games/grove/tests/grove_residents_tests.gd`:

```gdscript
	fresh("reward_pool_source_weight")
	for z in G.MAPS.size():
		_open_spots(z)
	var source_id := String(G.MAPS[0].id)
	var pool := Habitat.resident_reward_pool(source_id)
	var weights := {}
	for entry in pool:
		weights[String(entry.kind)] = int(entry.weight)
	ok(weights.get("ember", 0) == 3, "source map resident has 3x expedition reward weight")
	ok(weights.get("sprout", 0) == 1 and weights.get("dewdrop", 0) == 1 \
		and weights.get("breeze", 0) == 1 and weights.get("starlight", 0) == 1, \
		"other unlocked resident lines remain in the reward pool at 1x")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var rolled := Habitat.roll_reward_kind(source_id, rng)
	ok(weights.has(rolled), "weighted rolling returns a kind from the weighted pool")
```

Update `games/grove/tests/grove_explore_tests.gd`:

```gdscript
func _test_run_state() -> void:
	Explore.begin_run({"drops": true}, "farmhouse")
	ok(Explore.score() == 0, "a fresh run starts at score 0")
	ok(bool(Explore.run().equip.get("drops", false)), "the run carries the chosen loadout")
	ok(Explore.source_map_id() == "farmhouse", "the run carries the source map id")
	Explore.add_score(250)
	ok(Explore.score() == 250, "add_score accrues the run score")
	Explore.begin_run({})
	ok(Explore.source_map_id() == "", "legacy begin_run callers keep an empty source map")
```

In `_test_screens()`, start the reward seam with a source:

```gdscript
Explore.begin_run({}, String(G.MAPS[z].id))
```

Add an assertion after `ExploreReward.open(...)`:

```gdscript
ok(Explore.source_map_id() == String(G.MAPS[z].id), "reward overlay keeps the source map on the run")
```

- [ ] **Step 2: Run focused suites and verify RED**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_residents_tests
make test-one SUITE=games/grove/tests/grove_explore_tests
```

Expected: FAIL because the new weighted pool and run-source APIs do not exist.

- [ ] **Step 3: Implement weighted resident rewards**

Replace `_resident_pool()` / `grant_chest()` usage in `engine/scripts/core/habitat.gd` with:

```gdscript
## Weighted resident reward entries for Rush and resident-producing map rewards.
static func resident_reward_pool(source_map_id: String = "") -> Array:
	var unlocks: Dictionary = Save.grove().get("unlocks", {})
	var out: Array = []
	for z in Content.MAPS.size():
		if Content.map_spots_restored(z, unlocks) < 1:
			continue
		var map_id := String(Content.MAPS[z].id)
		for ln in Content.resident_lines(z):
			var kind := String(ln.get("id", ""))
			if kind == "":
				continue
			out.append({"kind": kind, "map_id": map_id, "weight": 3 if map_id == source_map_id else 1})
	return out

static func roll_reward_kind(source_map_id: String, rng: RandomNumberGenerator) -> String:
	var pool := resident_reward_pool(source_map_id)
	var total := 0
	for entry in pool:
		total += maxi(0, int(entry.get("weight", 0)))
	if total <= 0:
		return ""
	var pick := rng.randi_range(1, total)
	var acc := 0
	for entry in pool:
		acc += maxi(0, int(entry.get("weight", 0)))
		if pick <= acc:
			return String(entry.get("kind", ""))
	return ""

static func grant_chest(count: int, source_map_id: String = "") -> Array:
	var rng := _rng()
	var out: Array = []
	for _i in maxi(0, count):
		var kind := roll_reward_kind(source_map_id, rng)
		if kind == "":
			return out
		var tier := BoardLogic.roll_tier(rng)
		hand_add(kind, tier)
		out.append({"kind": kind, "tier": tier})
	return out
```

Update `collect()` so resident-producing map rewards bias to the collecting map:

```gdscript
var granted := grant_chest(whole, map_id)
```

- [ ] **Step 4: Implement Explore run source and reward overlay handoff**

Update `engine/scripts/core/explore.gd`:

```gdscript
static func begin_run(equip: Dictionary, source_map_id: String = "") -> void:
	_run = {"equip": equip.duplicate(true), "score": 0, "pending": [], "source_map_id": source_map_id}

static func source_map_id() -> String:
	return String(_run.get("source_map_id", ""))
```

Update `engine/scripts/ui/explore_reward.gd`:

```gdscript
var granted: Array = Habitat.grant_chest(Explore.trade_count(Explore.score()), Explore.source_map_id())
```

- [ ] **Step 5: Run focused suites and verify GREEN**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_residents_tests
make test-one SUITE=games/grove/tests/grove_explore_tests
```

Expected: PASS for both suites.

- [ ] **Step 6: Commit Task 2**

```bash
git add engine/scripts/core/habitat.gd engine/scripts/core/explore.gd engine/scripts/ui/explore_reward.gd games/grove/tests/grove_residents_tests.gd games/grove/tests/grove_explore_tests.gd
git commit -m "feat(expedition): bias rewards by source map"
```

### Task 3: Map-card Expedition Button and Workbench Knobs

**Files:**
- Modify: `engine/scripts/scenes/map.gd`
- Modify: `games/grove/tools/ui_workbench_kit.gd`
- Modify: `games/grove/tools/ui_workbench_view.gd`
- Modify: `games/grove/tools/ui_workbench_settings.json`
- Modify: `games/grove/tests/grove_explore_tests.gd`
- Modify: `games/grove/tests/grove_workbench_tests.gd`

**Interfaces:**
- Updates: `_open_expedition(z := -1)` stores the selected map as Explore source.
- Produces: `_add_expedition_button(card, z, opts, shelf_rect, strip_w, inset)`
- Produces workbench opts: `expedition_button_px`, `expedition_button_x`, `expedition_button_y`, `expedition_button_icon_scale`

- [ ] **Step 1: Write failing map-card and workbench tests**

Replace `_test_home_expedition_rail_chrome()` in `games/grove/tests/grove_explore_tests.gd` with `_test_map_card_expedition_chrome()` and update `_initialize()` to call the new name:

```gdscript
func _test_map_card_expedition_chrome() -> void:
	fresh("map_card_expedition_chrome")
	var z := G.hub_map()
	var locked_g := Save.grove()
	locked_g["unlocks"] = {}
	locked_g["gates"] = []
	locked_g["last_map"] = String(G.MAPS[z].id)
	Save.grove_write()

	var locked = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(locked)
	if locked.content == null:
		locked._ready()
	locked.unlocks = {}
	locked._open_map(z)
	await create_timer(0.05).timeout
	ok(_home_chrome_button(locked, "Expedition") == null, "Expedition no longer lives in the side rail")
	locked._open_select()
	await create_timer(0.05).timeout
	ok(locked.content.find_child("MapCardExpeditionButton", true, false) == null, "locked/unpopulatable map cards do not show Expedition")
	locked.queue_free()

	var unl := {}
	for sp in G.MAPS[z].spots:
		unl[String(sp.id)] = true
	var g := Save.grove()
	g["unlocks"] = unl
	g["gates"] = [z]
	g["last_map"] = String(G.MAPS[z].id)
	Save.grove_write()

	var hx = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(hx)
	if hx.content == null:
		hx._ready()
	hx.unlocks = unl
	hx._open_map(z)
	await create_timer(0.05).timeout
	ok(_home_chrome_button(hx, "Expedition") == null, "populatable maps still keep Expedition out of the side rail")
	hx._open_select()
	await create_timer(0.05).timeout
	var exp := hx.content.find_child("MapCardExpeditionButton", true, false) as Button
	ok(exp != null, "eligible map cards expose an Expedition button")
	ok(exp != null and String(exp.get_meta("map_id", "")) == String(G.MAPS[z].id), "card Expedition button records its source map")
	ok(exp != null and String(exp.get_meta("icon_id", "")) == "expedition", "card Expedition uses the dedicated expedition icon")
	if exp != null:
		exp.pressed.emit()
		await process_frame
		ok(hx.get_node_or_null("ExpeditionOverlay") != null, "pressing the card Expedition button opens loadout")
	hx.queue_free()
```

In `games/grove/tests/grove_workbench_tests.gd` inside `_test_gold_badge_consumers(view)`, add:

```gdscript
var expedition_keys := ["expedition_button_px", "expedition_button_x", "expedition_button_y", "expedition_button_icon_scale"]
var expedition_knobs_saved := true
for k in expedition_keys:
	expedition_knobs_saved = expedition_knobs_saved and map_opts.has(k) and view._params["map_card"].has(k) and view._is_config("map_card", k)
ok(expedition_knobs_saved, "map_card opts carry saved Expedition button size and position knobs")
ok(_source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"expedition_button_px\"") \
	and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"expedition_button_x\"") \
	and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"expedition_button_y\"") \
	and _source_contains("res://games/grove/tools/ui_workbench_view.gd", "_slider_row([\"expedition_button_icon_scale\""), \
	"the Workbench map-card sidebar exposes Expedition button sliders")
```

After `done_card` is created:

```gdscript
ok(done_card.find_child("MapCardExpeditionButtonPreview", true, false) != null, \
	"the Workbench done/restored map-card preview shows the Expedition button")
```

Update loadout overlay tests to call:

```gdscript
map._open_expedition(0)
```

- [ ] **Step 2: Run focused suites and verify RED**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_explore_tests
make test-one SUITE=games/grove/tests/grove_workbench_tests
```

Expected: FAIL because the side rail still contains Expedition and map cards/workbench do not render the new button/knobs.

- [ ] **Step 3: Add workbench config and preview support**

In `games/grove/tools/ui_workbench_view.gd`, add defaults under `_params["map_card"]`:

```gdscript
"expedition_button_px": 82, "expedition_button_x": 0, "expedition_button_y": 0, "expedition_button_icon_scale": 64,
```

In the map-card sidebar after "Reward shelf" or before "Reward icon":

```gdscript
_section_header("Expedition button")
_sidebar_body.add_child(_slider_row(["expedition_button_px", 44, 148]))
_sidebar_body.add_child(_slider_row(["expedition_button_x", -160, 160]))
_sidebar_body.add_child(_slider_row(["expedition_button_y", -120, 120]))
_sidebar_body.add_child(_slider_row(["expedition_button_icon_scale", 35, 90]))
```

In `games/grove/tools/ui_workbench_settings.json`, add the same four keys in the `map_card` object.

In `games/grove/tools/ui_workbench_kit.gd::map_card_opts_from_config`, add:

```gdscript
"expedition_button_px": float(c.get("expedition_button_px", 82)),
"expedition_button_x": float(c.get("expedition_button_x", 0)),
"expedition_button_y": float(c.get("expedition_button_y", 0)),
"expedition_button_icon_scale": float(c.get("expedition_button_icon_scale", 64)) / 100.0,
```

Add preview helper:

```gdscript
static func _map_add_expedition_button_preview(card: Control, opts: Dictionary, card_w: float, card_h: float) -> void:
	var px := clampf(float(opts.get("expedition_button_px", 82.0)), 44.0, 148.0)
	var b := home_button({"icon": "expedition", "caption": "", "tooltip": "Expedition", "action": func() -> void: pass}, {
		"px": px,
		"shape": "rect",
		"icon_scale": clampf(float(opts.get("expedition_button_icon_scale", 0.64)), 0.35, 0.90),
		"fill_alpha": 100,
	})
	b.name = "MapCardExpeditionButtonPreview"
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.position = Vector2(card_w * 0.38 - px * 0.5, card_h * 0.50 - px * 0.5) \
		+ Vector2(float(opts.get("expedition_button_x", 0.0)), float(opts.get("expedition_button_y", 0.0)))
	card.add_child(b)
```

Call it from `map_card()` when `habitat_preview` is true.

- [ ] **Step 4: Add live map-card Expedition button**

Update `engine/scripts/scenes/map.gd`:

```gdscript
func _open_expedition(z: int = -1) -> void:
	if z < 0:
		z = _map_idx
	...
	var source_map_id := String(G.MAPS[clampi(z, 0, G.MAPS.size() - 1)].id)
	...
	Explore.begin_run(equip.v, source_map_id)
```

Remove the Expedition block from `_build_liveops_rail()` and stop using `_residents_btn` for it. Leave `_refresh_residents_btn()` harmless or remove its calls after confirming no references remain.

Add `_add_expedition_button()` near `_habitat_card()`:

```gdscript
func _add_expedition_button(card: Control, z: int, opts: Dictionary, shelf_rect: Rect2) -> void:
	var Kit: GDScript = load(KIT_PATH)
	var HC: GDScript = load(HOME_CHROME_PATH)
	if Kit == null or HC == null:
		return
	var px := clampf(float(opts.get("expedition_button_px", 82.0)), 44.0, 148.0)
	var b: Button = Kit.home_button({
		"icon": HC.ICON_EXPEDITION,
		"caption": "",
		"tooltip": "Expedition",
		"action": func() -> void:
			Audio.play("button_tap", -2.0)
			_open_expedition(z),
	}, {
		"px": px,
		"shape": "rect",
		"icon_scale": clampf(float(opts.get("expedition_button_icon_scale", 0.64)), 0.35, 0.90),
		"fill_alpha": 100,
	})
	b.name = "MapCardExpeditionButton"
	b.set_meta("map_id", String(G.MAPS[z].id))
	b.set_meta("icon_id", HC.ICON_EXPEDITION)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.position = shelf_rect.position + Vector2(shelf_rect.size.x - px, -px - 6.0) \
		+ Vector2(float(opts.get("expedition_button_x", 0.0)), float(opts.get("expedition_button_y", 0.0)))
	card.add_child(b)
```

Call it from `_habitat_card()` after the reward shelf is added:

```gdscript
_add_expedition_button(card, z, opts, shelf_rect)
```

- [ ] **Step 5: Run focused suites and verify GREEN**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_explore_tests
make test-one SUITE=games/grove/tests/grove_workbench_tests
```

Expected: PASS for both suites.

- [ ] **Step 6: Commit Task 3**

```bash
git add engine/scripts/scenes/map.gd games/grove/tools/ui_workbench_kit.gd games/grove/tools/ui_workbench_view.gd games/grove/tools/ui_workbench_settings.json games/grove/tests/grove_explore_tests.gd games/grove/tests/grove_workbench_tests.gd
git commit -m "feat(map): move expedition into map cards"
```

### Task 4: Locked Resident Cells and Placement Hints

**Files:**
- Modify: `engine/scripts/scenes/map.gd`
- Modify: `games/grove/tools/ui_workbench_kit.gd`
- Modify: `games/grove/tests/grove_residents_tests.gd`
- Modify: `games/grove/tests/grove_workbench_tests.gd`

**Interfaces:**
- Produces: card metadata `resident_hint_state` values: `none`, `valid_select`, `invalid_select`, `valid_drag`, `invalid_drag`
- Produces locked cell nodes named `MapResidentRailLockedCell_%02d`
- Produces preview locked-cell support in `Kit.map_card`

- [ ] **Step 1: Write failing resident rail and hint tests**

Add to `_test_residents_dock()` after the first `_open_select()`:

```gdscript
var locked_cells := hx.content.find_children("MapResidentRailLockedCell_*", "Control", true, false)
ok(locked_cells.size() == G.RESIDENT_SLOTS_MAX - Habitat.cap(mid), "resident rails show grey locked cells above current capacity")

_map_tap_at(hx, _hit_center(_hand_orb_of(hx, "ember", 1)))
await create_timer(0.06).timeout
var farm_card := _card_for_map(hx, 0)
var other_card := _card_for_map(hx, 1)
ok(farm_card != null and String(farm_card.get_meta("resident_hint_state", "")) == "valid_select", "tap-select softly marks the resident home map")
ok(other_card == null or String(other_card.get_meta("resident_hint_state", "")) in ["", "invalid_select"], "tap-select dims non-home maps")
```

Add helper:

```gdscript
func _card_for_map(hx, z: int) -> Control:
	for hit in hx.select_hits:
		if int(hit.z) == z:
			return hit.node
	return null
```

Add a wrong-map drag assertion after adding an off-map resident and opening both maps:

```gdscript
fresh("resident_wrong_map_drag_hint")
var g2 := Save.grove()
g2["unlocks"] = {}
for zz in [0, 1]:
	for sp in G.MAPS[zz].spots:
		g2["unlocks"][String(sp.id)] = true
Save.grove_write()
Habitat.hand_add("sprout", 1)
var hx2 = load("res://engine/scenes/Map.tscn").instantiate()
get_root().add_child(hx2)
hx2._login_shown_launch = true
await create_timer(0.1).timeout
hx2.unlocks = g2["unlocks"]
hx2._open_select()
await create_timer(0.08).timeout
var sprout := _hand_orb_of(hx2, "sprout", 1)
var farm := _card_for_map(hx2, 0)
var barn := _card_for_map(hx2, 1)
_drag_select(hx2, _hit_center(sprout), farm.get_global_rect().get_center())
ok(Habitat.hand().size() == 1 and Habitat.placed(String(G.MAPS[0].id)).is_empty(), "dropping a resident on the wrong map is refused")
ok(String(farm.get_meta("resident_hint_state", "")) == "invalid_drag" or Habitat.placed(String(G.MAPS[0].id)).is_empty(), "wrong map is marked invalid during drag")
_drag_select(hx2, _hit_center(_hand_orb_of(hx2, "sprout", 1)), barn.get_global_rect().get_center())
ok(Habitat.hand().is_empty() and Habitat.placed(String(G.MAPS[1].id)).size() == 1, "dropping on the home map places the resident")
hx2.queue_free()
```

In `games/grove/tests/grove_workbench_tests.gd`, extend the preview slot assertions:

```gdscript
var locked_preview := Kit.map_card({"open": true, "done": false, "art": "", "map_id": "", "resident_preview": true, "resident_cap": 3}, map_opts, 460.0, 230.0)
ok(locked_preview.find_children("MapResidentRailPreviewLockedSlot_*", "Control", true, false).size() == 5, \
	"the Workbench resident rail preview greys cells above the preview capacity")
```

- [ ] **Step 2: Run focused suites and verify RED**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_residents_tests
make test-one SUITE=games/grove/tests/grove_workbench_tests
```

Expected: FAIL because locked cells and hint metadata are not implemented.

- [ ] **Step 3: Implement locked resident cells**

In `engine/scripts/scenes/map.gd::_add_habitat_strip`, always render `G.RESIDENT_SLOTS_MAX` cells. Replace the empty-cell loop with:

```gdscript
for i in range(placed.size(), G.RESIDENT_SLOTS_MAX):
	if i < cap:
		grid.add_child(_empty_cell(Kit, bag_opts, orb_px))
	else:
		var locked := _locked_resident_cell(Kit, bag_opts, orb_px)
		locked.name = "MapResidentRailLockedCell_%02d" % i
		grid.add_child(locked)
```

Add helper:

```gdscript
func _locked_resident_cell(Kit: GDScript, bag_opts: Dictionary, px: float) -> Control:
	var cell := _empty_cell(Kit, bag_opts, px)
	cell.modulate = Color(0.55, 0.55, 0.55, 0.62)
	cell.set_meta("locked", true)
	var veil := ColorRect.new()
	veil.name = "MapResidentLockedVeil"
	veil.color = Color(DOCK_INK, 0.28)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(veil)
	return cell
```

Add matching preview support in `games/grove/tools/ui_workbench_kit.gd::_map_add_resident_preview`: read `d.get("resident_cap", 8)` and name locked preview cells `MapResidentRailPreviewLockedSlot_%02d`.

- [ ] **Step 4: Implement placement hint metadata and visuals**

Add helpers in `engine/scripts/scenes/map.gd`:

```gdscript
func _selected_hand_home_z() -> int:
	if String(_sel_orb.get("src", "")) != "hand":
		return -1
	return G.resident_home_map(String(_sel_orb.get("kind", "")))

func _drag_hand_home_z() -> int:
	if String(_drag.get("src", "")) != "hand":
		return -1
	return G.resident_home_map(String(_drag.get("kind", "")))

func _card_hint_state(z: int) -> String:
	var drag_home := _drag_hand_home_z()
	if drag_home >= 0:
		return "valid_drag" if z == drag_home else "invalid_drag"
	var sel_home := _selected_hand_home_z()
	if sel_home >= 0:
		return "valid_select" if z == sel_home else "invalid_select"
	return "none"

func _apply_card_hint(card: Control, z: int) -> void:
	var state := _card_hint_state(z)
	card.set_meta("resident_hint_state", state)
	match state:
		"valid_select":
			card.modulate = Color(1.0, 1.0, 1.0, 1.0)
		"invalid_select":
			card.modulate = Color(0.78, 0.78, 0.78, 0.78)
		"valid_drag":
			card.modulate = Color(1.08, 1.04, 0.92, 1.0)
		"invalid_drag":
			card.modulate = Color(0.55, 0.55, 0.55, 0.62)
		_:
			card.modulate = Color.WHITE
```

Call `_apply_card_hint(card, z)` in `_build_select()` right after `_make_card(...)`.

Add a lightweight refresh so drag hint states update without rebuilding the picker while the ghost is active:

```gdscript
func _refresh_card_hints() -> void:
	for hit in select_hits:
		_apply_card_hint(hit.node, int(hit.z))
```

When drag starts and ends, refresh hints:

```gdscript
func _begin_drag_ghost(gpos: Vector2) -> void:
	...
	_refresh_card_hints()

func _end_drag() -> void:
	...
	_drag = {}
	if _view == "select":
		_refresh_card_hints()
```

In `_resolve_drop`, when a map card drop is attempted, rely on `Habitat.place()` for the home-map guard and show "Not here" on wrong map:

```gdscript
elif not Habitat.can_place_on(mid, {"kind": String(d.kind), "tier": int(d.tier)}):
	_invalid_at(card)
	FX.floating_text(self, gpos - Vector2(120, 60), "Not here", Color(CREAM, 0.9), 26)
elif Habitat.is_full(mid):
	...
```

- [ ] **Step 5: Run focused suites and verify GREEN**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_residents_tests
make test-one SUITE=games/grove/tests/grove_workbench_tests
```

Expected: PASS for both suites.

- [ ] **Step 6: Commit Task 4**

```bash
git add engine/scripts/scenes/map.gd games/grove/tools/ui_workbench_kit.gd games/grove/tests/grove_residents_tests.gd games/grove/tests/grove_workbench_tests.gd
git commit -m "feat(residents): show home-map placement hints"
```

### Task 5: Integrated Verification and Cleanup

**Files:**
- Review all modified files.

**Interfaces:**
- Consumes all prior task outputs.
- Produces a verified branch ready to merge.

- [ ] **Step 1: Run focused Grove suites**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_residents_tests
make test-one SUITE=games/grove/tests/grove_explore_tests
make test-one SUITE=games/grove/tests/grove_workbench_tests
```

Expected: PASS for all three.

- [ ] **Step 2: Run full Grove suite**

Run:

```bash
make test-grove
```

Expected: PASS, or report any unrelated pre-existing failures with exact suite names.

- [ ] **Step 3: Run fast engine baseline**

Run:

```bash
make test-fast
```

Expected: This may still fail with the pre-existing baseline issues noted in the spec. If it fails, confirm no failures are in files touched by this feature and record the same suite names.

- [ ] **Step 4: Run full suite if fast baseline is repaired or intentionally accepted**

Run:

```bash
make test
```

Expected: PASS if baseline is repaired; otherwise report that full sweep is blocked by the same baseline failures.

- [ ] **Step 5: Inspect diffs**

Run:

```bash
git diff --stat main...HEAD
git diff --check
git status --short
```

Expected: no whitespace errors; only planned files changed.

- [ ] **Step 6: Commit any final cleanup**

If there are unstaged cleanup changes:

```bash
git add <changed files>
git commit -m "chore: clean up map-card expedition integration"
```

Expected: clean working tree.
