# Fairy Hollow Market — Cluster Cover-up Unlocks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `fairy_hollow_market` scene the first picture-book page, with each of its 6 clusters hidden under a leaf cover-up that carries a padlock icon; when a cluster's gate is met the padlock reads "unlockable" and a tap clears its leaves to reveal the built art.

**Architecture:** Reuse the live HomeBuild build-step model. Each market cluster is one building with a single "unlock" step (cost + level gate); pre-unlock it renders as an empty plot under a leaf covering (already the engine's behaviour); buying the step reveals the covering (already `SceneCoverings.reveal`). The only new UI is a padlock badge (locked / ready states) replacing the plain cost badge for lock-mode pages, plus map.gd wiring for the strict bottom-up sequence.

**Tech Stack:** Godot 4.6 GDScript; Python 3 (manifest generator); headless SceneTree test suites run via `make test-fast` / `make test`.

## Global Constraints

- Work happens in the worktree `/Users/xup/dh/merge-wt-market-unlocks` (branch `market-cluster-unlocks`). Never edit the main tree.
- After every change run `make test-fast`; before handoff run `make test`. Both are headless and must show no FAIL/crash (the runner never trusts exit code alone).
- Godot logic tests run headless: `godot --headless --path . -s res://<suite>.gd`. The headless renderer's `get_image()` returns null — assert on the built node tree, never on pixels (`is_equal_approx` for Control geometry, which is float32).
- Page 1's map id stays `"fairy_hollow"` (load-bearing: hub flag, save keys, gates, map-select). Only its rendered content changes.
- After any change that regenerates/copies page art, run `make import` in the worktree so `.ctex` caches rebuild (they are gitignored / per-checkout).
- Deterministic-script rule: `build_page_manifests.py` moves pixels/files only; all judgement (which bundle, cluster order, costs) lives in data (`grove_data.gd`), not the script.

---

## File Structure

- `games/grove/tools/build_page_manifests.py` — add a `--only <scene>` flag so the market page can be generated without regenerating the other five.
- `games/grove/assets/map/pages/zone_fairy_hollow_market.json` — **generated** market manifest (+ copied PNGs under `pages/fairy_hollow_market/`).
- `games/grove/grove_data.gd` — repoint page 1 at the market manifest; replace `BUILDINGS` with the 6 market clusters; add the `lock_badges` page flag.
- `engine/scripts/ui/lock_badge.gd` — **new** small module: build a padlock badge with locked/ready states. One responsibility, headless-testable.
- `engine/scripts/ui/home_zone_view.gd` — add a `lock_mode` param that renders a `LockBadge` instead of the plain cost badge for empty plots.
- `engine/scripts/scenes/map.gd` — pass `lock_mode`; drive the strict bottom-up "next cluster ready" state; route lock taps through the existing build-tap path; keep the bottom pill as a clusters-left counter and hold `_play_btn` on plain PLAY in lock mode.
- Tests: `games/grove/tests/grove_page_manifest_tests.gd`, `games/grove/tests/grove_placement_tests.gd`, `games/grove/tests/grove_ui_tests.gd`.
- Reference updates for the renamed building ids: `games/grove/tools/map_shot.gd`, `games/grove/tools/click_spot.gd`, `games/grove/tests/grove_ui_tests.gd`, `games/grove/tests/grove_maps_page_tests.gd`.

---

### Task 1: Generate the market page manifest

**Files:**
- Modify: `games/grove/tools/build_page_manifests.py` (main(), ~line 128-137)
- Create (generated): `games/grove/assets/map/pages/zone_fairy_hollow_market.json` + `pages/fairy_hollow_market/*.png`
- Test: `games/grove/tests/grove_page_manifest_tests.gd`

**Interfaces:**
- Consumes: the bundle `assets/_concepts/zones/fairy_hollow_market_elements_v1/metadata/placements.json` (6 placements + a `foundation` base).
- Produces: `res://games/grove/assets/map/pages/zone_fairy_hollow_market.json` — schema `{version, id:"fairy_hollow_market", label, canvas:{width:1320,height:2346}, background, buildings:[{id, position:[x,y], display_size:[w,h], sort_y, cluster, states:{built}}]}`. The 6 building ids are exactly: `mushroom_hall`, `tea_stall`, `crystal_map_stall`, `stream_bridge`, `flower_crate`, `lantern_gate`.

- [ ] **Step 1: Add a `--only` flag to the generator**

In `games/grove/tools/build_page_manifests.py`, replace the body of `main()`:

```python
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=DEFAULT_ROOT)
    ap.add_argument("--only", default="", help="generate just this scene id (label defaults to a title-cased id)")
    args = ap.parse_args()
    if not os.path.isdir(args.root):
        raise SystemExit(f"scenes root not found: {args.root}")
    if args.only:
        label = dict(PAGES).get(args.only, args.only.replace("_", " ").title())
        build_page(args.root, args.only, label)
        return
    for scene, label in PAGES:
        build_page(args.root, scene, label)
```

- [ ] **Step 2: Generate the market manifest**

Run:

```bash
cd /Users/xup/dh/merge-wt-market-unlocks
python3 games/grove/tools/build_page_manifests.py --only fairy_hollow_market
```

Expected stdout: `wrote games/grove/assets/map/pages/zone_fairy_hollow_market.json  (6 props, canvas 1320x2346)`.

- [ ] **Step 3: Import the copied art**

Run:

```bash
make import
```

Expected: completes without error (rebuilds `.ctex` for the 7 copied PNGs).

- [ ] **Step 4: Write the failing manifest test**

Append to `games/grove/tests/grove_page_manifest_tests.gd` (follow the file's existing `_check`/assert helpers; if it uses a `run()`/`_expect` pattern, mirror it):

```gdscript
func test_market_manifest_has_six_clusters() -> void:
	var path := "res://games/grove/assets/map/pages/zone_fairy_hollow_market.json"
	assert_true(FileAccess.file_exists(path), "market manifest generated")
	var doc: Dictionary = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	assert_eq(int((doc.canvas as Dictionary).width), 1320, "canvas width")
	assert_eq(int((doc.canvas as Dictionary).height), 2346, "canvas height")
	var ids: Array = []
	for b in doc.buildings:
		ids.append(String((b as Dictionary).id))
	for want in ["mushroom_hall", "tea_stall", "crystal_map_stall", "stream_bridge", "flower_crate", "lantern_gate"]:
		assert_true(ids.has(want), "cluster present: %s" % want)
```

- [ ] **Step 5: Run the suite (expect PASS now the file exists)**

Run:

```bash
make test-grove SUITE=grove_page_manifest_tests
```

(If that make var is unsupported, run `godot --headless --path . -s res://games/grove/tests/grove_page_manifest_tests.gd`.)
Expected: PASS. If the assert helpers differ, adapt the calls to the suite's real API and re-run.

- [ ] **Step 6: Commit**

```bash
git add games/grove/tools/build_page_manifests.py games/grove/assets/map/pages/zone_fairy_hollow_market.json games/grove/assets/map/pages/fairy_hollow_market games/grove/tests/grove_page_manifest_tests.gd
git commit -m "feat(market): generate fairy_hollow_market page manifest"
```

---

### Task 2: Repoint page 1 and define the 6 cluster buildings

**Files:**
- Modify: `games/grove/grove_data.gd` — the page-1 `MAPS` row (~line 426-438) and the `BUILDINGS` const (~line 382-407)
- Modify (id references): `games/grove/tools/map_shot.gd:67,98,104`, `games/grove/tools/click_spot.gd:42,50,52`, `games/grove/tests/grove_ui_tests.gd:568-570`, `games/grove/tests/grove_maps_page_tests.gd:65`
- Test: `games/grove/tests/grove_placement_tests.gd`

**Interfaces:**
- Consumes: Task 1's manifest (building ids).
- Produces:
  - Page-1 `MAPS` row: `zone_manifest` → the market manifest; adds `"lock_badges": true`; `id` stays `"fairy_hollow"`.
  - `BUILDINGS` (aliased `Game.DATA.BUILDINGS`, read by `HomeBuild.defs()`): 6 entries, ids = the cluster ids, **listed bottom-up** (the strict unlock order). Each has exactly one step `{cost, min_level, shows:"built"}`.
  - Ladder consumed by map.gd (Task 5): the BUILDINGS order IS the unlock order.

- [ ] **Step 1: Repoint the page-1 MAPS row**

In `games/grove/grove_data.gd`, in `_build_maps()`, change the `fairy_hollow` row's `zone_manifest` and add the flag (keep `id`, `name`, `hub`, `spots`):

```gdscript
	{"id": "fairy_hollow", "name": "Fairy Hollow", "hub": true,
		"zone_manifest": "res://games/grove/assets/map/pages/zone_fairy_hollow_market.json",
		"covering_frames": _covering_frames("hollow_grass"),
		"lock_badges": true,
		"spots": [
```

(Leave the existing `spots: [...]` list untouched below this line — it stays for save-compat.)

- [ ] **Step 2: Replace BUILDINGS with the 6 clusters (bottom-up order)**

Replace the whole `const BUILDINGS := [ ... ]` block:

```gdscript
# The market page's 6 hero clusters, each a single UNLOCK step (cosmetic reveal — the art is always
# in the manifest as "built"; an unbought cluster renders as an empty plot under its leaf cover-up).
# Listed BOTTOM-UP: this order IS the strict unlock sequence map.gd walks (lantern first, hall last).
# Ids match zone_fairy_hollow_market.json. Numbers PROVISIONAL (economy-sim owns them, spec §4).
const BUILDINGS := [
	{"id": "lantern_gate", "name": "Lantern Gate", "steps": [
		{"cost": 10, "min_level": 1, "shows": "built"}], "customizations": []},
	{"id": "flower_crate", "name": "Flower Crate", "steps": [
		{"cost": 25, "min_level": 2, "shows": "built"}], "customizations": []},
	{"id": "stream_bridge", "name": "Stream Bridge", "steps": [
		{"cost": 45, "min_level": 3, "shows": "built"}], "customizations": []},
	{"id": "crystal_map_stall", "name": "Crystal Map Stall", "steps": [
		{"cost": 70, "min_level": 4, "shows": "built"}], "customizations": []},
	{"id": "tea_stall", "name": "Tea Stall", "steps": [
		{"cost": 110, "min_level": 5, "shows": "built"}], "customizations": []},
	{"id": "mushroom_hall", "name": "Mushroom Hall", "steps": [
		{"cost": 160, "min_level": 6, "shows": "built"}], "customizations": []},
]
```

- [ ] **Step 3: Update the dev-tool + test references to the renamed ids**

- `games/grove/tools/map_shot.gd:67` — change `["fh_hearth", "fh_boxes"]` → `["lantern_gate", "flower_crate"]`.
- `games/grove/tools/map_shot.gd:98` — change `["fh_hearth", "fh_boxes", "fh_kitchen", "fh_well"]` → `["lantern_gate", "flower_crate", "stream_bridge", "crystal_map_stall"]`.
- `games/grove/tools/map_shot.gd:103-104` — change the mid-build comment + `Home.def_of("fh_larder")` → `Home.def_of("tea_stall")`.
- `games/grove/tools/click_spot.gd:42,50,52` — change `"fh_hearth"` → `"lantern_gate"` (all three).
- `games/grove/tests/grove_ui_tests.gd:568,570` — change `{"fh_well": true}` → `{"stream_bridge": true}` (both lines).
- `games/grove/tests/grove_maps_page_tests.gd:65` — change `HomeBuild.def_of("fh_hearth")` → `HomeBuild.def_of("lantern_gate")`.

- [ ] **Step 4: Write the failing data test**

Append to `games/grove/tests/grove_placement_tests.gd` (mirror the suite's assert helpers):

```gdscript
func test_market_is_page_one_with_lock_badges() -> void:
	var G := load("res://games/grove/grove_data.gd")
	var page: Dictionary = G.MAPS[0]
	assert_eq(String(page.id), "fairy_hollow", "page-1 id stays fairy_hollow")
	assert_true(bool(page.get("lock_badges", false)), "page 1 is lock-badge mode")
	assert_true(String(page.zone_manifest).ends_with("zone_fairy_hollow_market.json"), "page 1 renders the market")

func test_cluster_buildings_are_ordered_bottom_up() -> void:
	var G := load("res://games/grove/grove_data.gd")
	var ids: Array = []
	for d in G.BUILDINGS:
		ids.append(String((d as Dictionary).id))
	assert_eq(ids, ["lantern_gate", "flower_crate", "stream_bridge", "crystal_map_stall", "tea_stall", "mushroom_hall"], "unlock order")
	for d in G.BUILDINGS:
		assert_eq((d.steps as Array).size(), 1, "one unlock step per cluster: %s" % d.id)
```

- [ ] **Step 5: Run the suite (expect PASS)**

Run:

```bash
godot --headless --path . -s res://games/grove/tests/grove_placement_tests.gd
```

Expected: PASS.

- [ ] **Step 6: Full fast sweep to catch renamed-id breakage**

Run:

```bash
make test-fast
```

Expected: no FAIL/crash. Fix any suite that still names an old `fh_*` id.

- [ ] **Step 7: Commit**

```bash
git add games/grove/grove_data.gd games/grove/tools/map_shot.gd games/grove/tools/click_spot.gd games/grove/tests
git commit -m "feat(market): make the market page 1 with 6 cluster unlock buildings"
```

---

### Task 3: The padlock lock-badge module

**Files:**
- Create: `engine/scripts/ui/lock_badge.gd`
- Test: `games/grove/tests/grove_ui_tests.gd`

**Interfaces:**
- Produces:
  - `LockBadge.make(id: String) -> Control` — a 120×120 Control named `lock_<id>`, `mouse_filter = IGNORE`, `set_meta("building_id", id)`, containing a padlock `TextureRect` child named `Pad` (texture `Game.art("ui/meadow_v2/icon_padlock.png")`, `EXPAND_IGNORE_SIZE` set BEFORE size — TextureRect min-size clamp gotcha). Starts in the LOCKED look (dim, no glow).
  - `LockBadge.set_ready(badge: Control, ready: bool) -> void` — READY brightens the pad (`modulate = Color(1,1,1,1)`) and shows a soft glow child named `Glow`; LOCKED dims it (`modulate = Color(1,1,1,0.55)`) and hides/removes the glow. Idempotent.

- [ ] **Step 1: Write the failing test**

Append to `games/grove/tests/grove_ui_tests.gd`:

```gdscript
func test_lock_badge_states() -> void:
	var LB := load("res://engine/scripts/ui/lock_badge.gd")
	var badge: Control = LB.make("tea_stall")
	assert_eq(badge.name, "lock_tea_stall", "named by id")
	assert_eq(String(badge.get_meta("building_id")), "tea_stall", "carries building id")
	var pad := badge.get_node("Pad") as TextureRect
	assert_true(pad != null, "has a padlock child")
	assert_true(pad.modulate.a < 0.9, "locked look is dimmed")
	LB.set_ready(badge, true)
	assert_true(pad.modulate.a >= 0.99, "ready look is bright")
	assert_true(badge.has_node("Glow"), "ready shows a glow")
	LB.set_ready(badge, false)
	assert_true(pad.modulate.a < 0.9, "back to locked dim")
	assert_false(badge.has_node("Glow"), "glow gone when re-locked")
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
godot --headless --path . -s res://games/grove/tests/grove_ui_tests.gd
```

Expected: FAIL (`lock_badge.gd` does not exist / node missing).

- [ ] **Step 3: Implement the module**

Create `engine/scripts/ui/lock_badge.gd`:

```gdscript
extends RefCounted
## The market cover-up PADLOCK badge (fairy_hollow_market cluster unlocks). A covered cluster wears
## one of these: LOCKED reads as a dim padlock (gate not yet the player's turn / unaffordable); READY
## brightens it and adds a soft glow so it reads as tappable. Tapping a READY badge routes through the
## existing build-tap path (map.gd) which buys the cluster's single unlock step and reveals its leaves.
## Render-only + stateless: map.gd owns which badge is ready.

const PAD_PX := 96.0
const BOX := 120.0

static func make(id: String) -> Control:
	var badge := Control.new()
	badge.name = "lock_%s" % id
	badge.custom_minimum_size = Vector2(BOX, BOX)
	badge.size = Vector2(BOX, BOX)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_meta("building_id", id)
	var pad := TextureRect.new()
	pad.name = "Pad"
	pad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE      # set BEFORE size (min-size cache clamp)
	pad.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pad.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.size = Vector2(PAD_PX, PAD_PX)
	pad.position = Vector2(BOX - PAD_PX, BOX - PAD_PX) * 0.5
	var pad_path := Game.art("ui/meadow_v2/icon_padlock.png")
	if ResourceLoader.exists(pad_path):
		pad.texture = load(pad_path) as Texture2D
	badge.add_child(pad)
	set_ready(badge, false)
	return badge

static func set_ready(badge: Control, ready: bool) -> void:
	if badge == null or not is_instance_valid(badge):
		return
	var pad := badge.get_node_or_null("Pad") as TextureRect
	if pad != null:
		pad.modulate = Color(1, 1, 1, 1.0) if ready else Color(1, 1, 1, 0.55)
	var glow := badge.get_node_or_null("Glow")
	if ready and glow == null:
		var g := TextureRect.new()
		g.name = "Glow"
		g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.size = Vector2(BOX, BOX) * 1.15
		g.position = -(g.size - Vector2(BOX, BOX)) * 0.5
		g.modulate = Color(1.0, 0.95, 0.6, 0.55)
		var halo := Game.art("ui/meadow_v2/glow_soft.png")
		if ResourceLoader.exists(halo):
			g.texture = load(halo) as Texture2D
		badge.add_child(g)
		badge.move_child(g, 0)                            # glow paints behind the pad
	elif not ready and glow != null:
		glow.queue_free()
```

If `ui/meadow_v2/glow_soft.png` does not exist, grep `engine engine/scripts/ui` for the halo/glow asset the codebase already uses (e.g. a `*halo*`/`*glow*` under `ui/`) and use that path; the glow is additive-halo, never a `modulate` brighten (a >1.0 modulate is invisible on bright art).

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
godot --headless --path . -s res://games/grove/tests/grove_ui_tests.gd
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/ui/lock_badge.gd games/grove/tests/grove_ui_tests.gd
git commit -m "feat(market): padlock lock-badge with locked/ready states"
```

---

### Task 4: Render lock badges in home_zone_view

**Files:**
- Modify: `engine/scripts/ui/home_zone_view.gd` — `build()` signature (~line 28) + the badge branch (~line 104-113)
- Test: `games/grove/tests/grove_ui_tests.gd`

**Interfaces:**
- Consumes: `LockBadge.make` (Task 3).
- Produces: `HomeZoneView.build(parent, manifest, state_of, next_step_of, covering_frames := [], lock_mode := false) -> Dictionary`. When `lock_mode` is true, each **empty** plot with a pending step gets a `LockBadge` (not the plain cost badge) mounted at the plot centre and returned in the `badges` map; coverings behave as before. When false, behaviour is unchanged.

- [ ] **Step 1: Write the failing test**

Append to `games/grove/tests/grove_ui_tests.gd`:

```gdscript
func test_lock_mode_mounts_padlock_badges() -> void:
	var HZV := load("res://engine/scripts/ui/home_zone_view.gd")
	var manifest := {
		"canvas": {"width": 100, "height": 100}, "background": "",
		"buildings": [{"id": "tea_stall", "position": [50, 50], "display_size": [40, 40], "states": {"built": ""}}],
	}
	var parent := Control.new()
	add_child(parent)
	var state_of := func(_id): return "empty"
	var next_of := func(_id): return {"cost": 110, "min_level": 5}
	var built: Dictionary = HZV.build(parent, manifest, state_of, next_of, [], true)
	var badge: Control = built.badges["tea_stall"]
	assert_eq(badge.name, "lock_tea_stall", "lock badge, not cost badge")
	parent.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
godot --headless --path . -s res://games/grove/tests/grove_ui_tests.gd
```

Expected: FAIL (`build()` takes no `lock_mode`; badge is `build_tea_stall`).

- [ ] **Step 3: Add the param and the preload**

In `engine/scripts/ui/home_zone_view.gd`, add near the other `const` preloads (top of file, beside `const Coverings`):

```gdscript
const LockBadge = preload("res://engine/scripts/ui/lock_badge.gd")
```

Change the signature:

```gdscript
static func build(parent: Control, manifest: Dictionary, state_of: Callable, next_step_of: Callable,
		covering_frames: Array = [], lock_mode: bool = false) -> Dictionary:
```

- [ ] **Step 4: Branch the badge creation**

Replace the pending-badge block (the `var step := next_step_of.call(id)` / `if not step.is_empty():` clause):

```gdscript
		var step: Dictionary = next_step_of.call(id)
		if not step.is_empty():
			var badge: Control = LockBadge.make(id) if lock_mode \
				else _build_badge(id, int(step.get("cost", 0)), int(step.get("min_level", 1)))
			badge.position = anchor - badge.size * 0.5
			pending_badges.append(badge)
			badges[id] = badge
```

- [ ] **Step 5: Run test to verify it passes**

Run:

```bash
godot --headless --path . -s res://games/grove/tests/grove_ui_tests.gd
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add engine/scripts/ui/home_zone_view.gd games/grove/tests/grove_ui_tests.gd
git commit -m "feat(market): home_zone_view lock_mode renders padlock badges"
```

---

### Task 5: Wire the strict sequence + tap-to-unlock in map.gd

**Files:**
- Modify: `engine/scripts/scenes/map.gd` — `_build_map` build call (~line 417-428), a new sequence helper, `_refresh_play_cta` (~line 1895-1913), and the bottom pill counter (~line 565-600)
- Test: `games/grove/tests/grove_placement_tests.gd`

**Interfaces:**
- Consumes: `HomeZoneView.build(..., lock_mode)` (Task 4); `LockBadge.set_ready` (Task 3); the page flag `G.MAPS[z].lock_badges`; `HomeBuild.state_id/next_step/defs`.
- Produces: on `_build_map`, in lock mode the next-in-sequence empty cluster's badge is set READY iff its step is buyable (`min_level <= level and cost <= coins`); all other empty clusters stay LOCKED. A READY badge registers into `spot_hits` so a tap routes `_map_tap → _on_build_tap` (unchanged buy + `SceneCoverings.reveal`). `_play_btn` holds plain PLAY in lock mode. The bottom pill shows clusters-left = count of empty cluster buildings.

- [ ] **Step 1: Write the failing sequence test**

Append to `games/grove/tests/grove_placement_tests.gd` (adapt to the suite base's scene-instantiation helper — `grove_test_base.gd`; mirror how a sibling test builds the map scene and sets level/coins/unlocks):

```gdscript
func test_only_next_cluster_is_ready() -> void:
	var scn = _open_map_scene(0)                      # page 1 (market); helper from grove_test_base
	Save.set_coins(9999)
	# level high enough that several clusters are affordable at once
	_set_level(scn, 6)
	scn._build_map(false)
	var ready_ids: Array = []
	for id in ["lantern_gate", "flower_crate", "stream_bridge", "crystal_map_stall", "tea_stall", "mushroom_hall"]:
		var b: Control = scn._zone_badges.get(id, null)
		if b != null and b.has_node("Glow"):
			ready_ids.append(id)
	assert_eq(ready_ids, ["lantern_gate"], "only the bottom-most locked cluster is ready")
```

(If `_zone_badges` is not already a member, this test also drives Step 3's requirement to store the badge map. If the base lacks `_open_map_scene`/`_set_level`, use whatever the sibling map tests use to reach a built page-1 scene and set level — grep `grove_placement_tests.gd`/`grove_test_base.gd` for the pattern and match it.)

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
godot --headless --path . -s res://games/grove/tests/grove_placement_tests.gd
```

Expected: FAIL (no lock-mode wiring yet; badges are cost badges or all-affordable).

- [ ] **Step 3: Pass lock_mode and keep the badge map**

In `engine/scripts/scenes/map.gd`, find the `_build_map` call to `HomeZoneView.build(...)` (~line 417). Add a member near the other zone members (beside `var _zone_coverings`):

```gdscript
var _zone_badges: Dictionary = {}     # building id -> its lock/cost badge node (this page)
```

Change the build call to pass lock mode and capture the badges:

```gdscript
	var _lock_mode := bool(G.MAPS[_map_idx].get("lock_badges", false))
	var built = HomeZoneView.build(holder, manifest, Callable(self, "_home_state_id"), \
		Callable(self, "_home_next_step"), G.MAPS[_map_idx].get("covering_frames", []), _lock_mode)
	_zone_coverings = built.coverings
	_zone_badges = built.badges
```

(Match the exact existing local names/formatting around line 417-419; only add the `_lock_mode` arg + `_zone_badges` capture.)

- [ ] **Step 4: Drive the sequence-ready state after the build**

Immediately after the block that fills `spot_hits` from `built.badges` (~line 428), add:

```gdscript
	if _lock_mode:
		_apply_lock_sequence()
```

Add the helper (near `_cheapest_buyable`):

```gdscript
# The market cover-up sequence: only the LOWEST-ORDER still-empty cluster may read READY, and only
# when its single unlock step is buyable now. Every other covered cluster stays plain-LOCKED. The
# ready one is the sole tappable badge (its spot_hits entry survives; the rest are made inert).
func _apply_lock_sequence() -> void:
	var LB: GDScript = load("res://engine/scripts/ui/lock_badge.gd")
	var next_id := ""
	for d in HomeBuild.defs():
		var id := String(d.id)
		if HomeBuild.state_id(id) == "empty":
			next_id = id
			break
	var lvl := G.level()
	var wallet := Save.coins()
	for id_v in _zone_badges.keys():
		var id := String(id_v)
		var badge: Control = _zone_badges[id]
		var ready := false
		if id == next_id:
			var step := HomeBuild.next_step(id)
			ready = not step.is_empty() and int(step.min_level) <= lvl and int(step.cost) <= wallet
		LB.set_ready(badge, ready)
	# only the ready cluster keeps a live tap target; drop the others from spot_hits
	var kept: Array = []
	for hit in spot_hits:
		var bid := String(hit.get("building", ""))
		if bid == "" or bid == next_id:
			kept.append(hit)
	spot_hits = kept
```

- [ ] **Step 5: Hold the CTA on plain PLAY in lock mode**

In `_refresh_play_cta()` (~line 1902), make `ready` false when the page is lock-mode (the on-map padlocks are the unlock affordance now):

```gdscript
	var ready := _unlock_ready() and not bool(G.MAPS[_map_idx].get("lock_badges", false))
```

- [ ] **Step 6: Point the bottom pill counter at clusters-left**

In the pill builder (~line 565-575), where `owned`/`left` are computed, branch for lock mode so the counter reads built vs total cluster buildings:

```gdscript
	var total: int = G.MAPS[z].spots.size()
	var owned := owned_count(z)
	if bool(G.MAPS[z].get("lock_badges", false)):
		total = HomeBuild.defs().size()
		owned = 0
		for d in HomeBuild.defs():
			if HomeBuild.state_id(String(d.id)) != "empty":
				owned += 1
	var left := total - owned
```

(Leave the rest of the pill body — `frac`, fill bar, label — as-is; they read `total`/`owned`/`left`.)

- [ ] **Step 7: Run the sequence test (expect PASS)**

Run:

```bash
godot --headless --path . -s res://games/grove/tests/grove_placement_tests.gd
```

Expected: PASS. If `_zone_badges`/helper names in the test don't match, reconcile the test to the members you added and re-run.

- [ ] **Step 8: Commit**

```bash
git add engine/scripts/scenes/map.gd games/grove/tests/grove_placement_tests.gd
git commit -m "feat(market): strict bottom-up lock sequence + tap-to-unlock wiring"
```

---

### Task 6: Full verification & visual proof

**Files:** none (verification only)

- [ ] **Step 1: Full sweep**

Run:

```bash
make test
```

Expected: the per-suite table shows no FAIL/crash. Fix any regression (most likely a suite still asserting an `fh_*` id or the old cost-badge name).

- [ ] **Step 2: Render the real page-1 scene**

Use the project's screenshot tool to capture page 1 at a low level (only `lantern_gate` ready) and after unlocking it. Follow `docs/design/art-style-guide.md` / the `make shot-*` targets — e.g.:

```bash
make map-shot OUT=/tmp/market_locked.png
```

(Grep the `Makefile` for the exact map/home screenshot target if `map-shot` differs.) Confirm in the image: all 6 clusters sit under leaf cover-ups, the bottom `lantern_gate` wears a bright/glowing padlock, the rest wear dim padlocks, and the bottom pill reads "6 to restore".

- [ ] **Step 3: Verify the reveal**

Drive one unlock in the shot script (buy `lantern_gate`'s step) and re-capture; confirm its leaves are gone, its art shows, and `flower_crate` is now the ready padlock. Attach both images to the handoff. (See-the-result gate: do not claim done on unit passes alone — look at the rendered frames.)

- [ ] **Step 4: Commit any fixes, then hand off**

```bash
git add -A && git commit -m "test(market): full sweep green + visual verification"
```

---

## Self-Review

**Spec coverage:**
- Replace first scene with `fairy_hollow_market` → Task 1 (generate) + Task 2 (repoint page 1, stable id). ✓
- A few clusters in the cover-up overlay, each = an unlock → Task 2 (6 cluster buildings) + existing per-plot covering. ✓
- On unlock the leaves move away → existing `SceneCoverings.reveal` fired by `_on_build_tap`, reached via the lock tap (Task 5). ✓
- Add a lock icon → Task 3 (`lock_badge.gd`) + Task 4 (render it in lock mode). ✓
- When ready show it unlockable → Task 5 `_apply_lock_sequence` sets READY on the next buyable cluster. ✓
- On click, unlock it → Task 5 keeps the ready badge in `spot_hits` → `_on_build_tap`. ✓
- Strict bottom-up sequence + keep bottom pill as counter → Task 2 order + Task 5 Steps 4/6. ✓

**Placeholder scan:** No TBD/TODO. The two "grep for the real asset/helper" notes (glow asset in Task 3, test-base helpers in Task 5) are explicit fallbacks with a named search, not deferred work — the primary path is fully specified.

**Type consistency:** `LockBadge.make`/`set_ready`, `_zone_badges`, `_apply_lock_sequence`, the `lock_mode` param, and the `lock_badges` page flag are named identically across Tasks 3-5. Building ids (`lantern_gate` … `mushroom_hall`) are identical in the manifest (Task 1), data (Task 2), and tests (Tasks 2, 5).
