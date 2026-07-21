# Fairy Hollow Market — Cluster Cover-up Unlocks Implementation Plan (REVISED)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `fairy_hollow_market` scene the first picture-book page and wire its **already-authored** per-cluster cover-up canopy layer into the game: each of the 6 clusters shows its canopy sprites on top of the fully-built scene with a lock icon; when a cluster's gate is met the lock reads "ready", and a tap **takes that cluster's canopy away** (reveal animation) to expose the art beneath.

**Architecture:** The scene already defines everything — the 6 built structures AND a frontmost `coverup` layer of canopy sprites tagged `unlock_region_<cluster>`. We author NOTHING new in the scene. The deterministic generator carries the existing `unlock_cover` placements through into the page manifest as a `coverups` list; the runtime renders the structures always-built, mounts each locked cluster's canopy group frontmost with a lock badge, and on unlock deducts the cost, records the cluster in the `unlocks` save dict, and reveals its canopy away. No HomeBuild build-steps, so the economy/cells/quest systems are untouched.

**Tech Stack:** Godot 4.6 GDScript; Python 3 (deterministic manifest generator); headless SceneTree test suites via `make test-fast` / `make test`.

## Global Constraints

- Work in the worktree `/Users/xup/dh/merge-wt-market-unlocks` (branch `market-cluster-unlocks`) only. Never edit the main tree `/Users/xup/dh/merge`.
- **Author no scene/coverup content.** The `coverup` layer, the canopy sprites, and their per-cluster grouping already exist in the bundle. Only carry the existing definitions through and wire runtime behaviour. Do not hand-edit placements, invent canopy art, or add cover sprites.
- After every change run `make test-fast`; before handoff run `make test`. Both are headless; the runner fails on any FAIL/crash and never trusts exit code alone.
- Godot logic tests are headless SceneTree scripts: `godot --headless --path . -s res://<suite>.gd`. `get_image()` returns null headless — assert on the built node tree, never pixels. Control geometry is float32: compare with `is_equal_approx`.
- Page 1's map id stays `"fairy_hollow"` (load-bearing: hub flag, save keys, gates, map-select). Only its rendered content changes.
- After regenerating/copying page art, run `make import` in the worktree so `.ctex` caches rebuild (gitignored / per-checkout).
- The 6 cluster ids are exactly, in strict **bottom-up unlock order**: `lantern_gate`, `flower_crate`, `stream_bridge`, `crystal_map_stall`, `tea_stall`, `mushroom_hall`.

---

## File Structure

- `games/grove/tools/build_page_manifests.py` — carry `unlock_cover` placements through into a `coverups` manifest list (currently they are dropped). Already has the `--only` flag from the prior task.
- `games/grove/assets/map/pages/zone_fairy_hollow_market.json` — regenerated: keeps 6 `buildings` (built structures) and gains a `coverups` list. Plus copied canopy PNGs under `pages/fairy_hollow_market/`.
- `games/grove/grove_data.gd` — point page 1 at the market manifest (id stays `fairy_hollow`), add `"coverup_mode": true` and a `clusters` order/gate table.
- `engine/scripts/ui/lock_badge.gd` — **new** padlock badge with locked/ready states (headless-testable).
- `engine/scripts/ui/home_zone_view.gd` — add coverup rendering: in coverup mode render every structure built, mount each locked cluster's canopy group + a lock badge, and return them keyed by cluster.
- `engine/scripts/core/content.gd` — small cluster-unlock helpers (order, next-locked, ready, claim).
- `engine/scripts/scenes/map.gd` — coverup-mode wiring: drive the strict sequence + ready state, route a lock tap to claim + reveal, keep the bottom pill as a clusters-left counter, hold `_play_btn` on plain PLAY.
- Tests: `games/grove/tests/grove_page_manifest_tests.gd`, `grove_placement_tests.gd`, `grove_ui_tests.gd`, `grove_economy_tests.gd`.

**Note on prior work:** the previous Task 1 already added `--only` and generated the manifest with 6 buildings but *dropped* the coverups (commit `e68245ea`). Task 1 below amends that.

---

### Task 1: Carry the authored coverup layer into the page manifest

**Files:**
- Modify: `games/grove/tools/build_page_manifests.py` — the placement loop (~line 89-110) and the `manifest` dict (~line 121)
- Regenerate: `games/grove/assets/map/pages/zone_fairy_hollow_market.json` + copied `pages/fairy_hollow_market/*.png`
- Test: `games/grove/tests/grove_page_manifest_tests.gd`

**Interfaces:**
- Consumes: the existing bundle `assets/_concepts/zones/fairy_hollow_market_elements_v3/metadata/placements.json` — 6 structure/garden_item placements + 11 `category:"unlock_cover"` placements whose `cluster` is `unlock_region_<clusterId>`.
- Produces: `zone_fairy_hollow_market.json` gains `"coverups": [ {id, cluster, position:[x,y], display_size:[w,h], sort_y, image} ]`, one entry per `unlock_cover` placement, `cluster` = the region with the `unlock_region_` prefix stripped, `image` = the copied `res://` path. `buildings` stays the 6 structures (unchanged).

- [ ] **Step 1: Replace the drop with a carry-through**

In `games/grove/tools/build_page_manifests.py`, before the `buildings = []` line add `coverups = []`, and change the placement loop so `unlock_cover` entries populate `coverups` instead of `continue`:

```python
    buildings = []
    coverups = []
    if placements:
        base_rel = str(doc.get("base", {}).get("image", ""))
        base_src = os.path.join(bundle_repo_root, base_rel)
        if not os.path.exists(base_src):
            raise SystemExit(f"{scene}: base image missing: {base_src}")
        background = copy_asset(base_src, scene, "foundation")
        canvas = doc.get("canvas", {})
        cw, ch = int(canvas.get("width", 1320)), int(canvas.get("height", 2346))
        for e in placements:
            src = os.path.join(bundle_repo_root, str(e.get("image", "")))
            if not os.path.exists(src):
                print(f"  ! {scene}: skipping {e.get('id')} — missing {src}")
                continue
            tex = copy_asset(src, scene, str(e["id"]))
            if str(e.get("category", "")) == "unlock_cover":
                # the sw-coverup "fixed" layer: per-cluster canopy sprites (cluster == unlock_region_<id>)
                # authored for the cover-up unlocks. Carried through as coverups (NOT page props); the
                # runtime mounts them frontmost per cluster and reveals them away on unlock.
                region = str(e.get("cluster", ""))
                cluster = region[len("unlock_region_"):] if region.startswith("unlock_region_") else region
                coverups.append({
                    "id": str(e["id"]), "cluster": cluster,
                    "position": [int(e["x"]), int(e["y"])],
                    "display_size": [int(e["w"]), int(e["h"])],
                    "sort_y": int(e.get("z", 0)),
                    "image": tex,
                })
                continue
            entry = {
                "id": str(e["id"]), "label": str(e["id"]).replace("_", " "),
                "position": [int(e["x"]), int(e["y"])],
                "display_size": [int(e["w"]), int(e["h"])],
                "sort_y": int(e.get("z", 0)),          # explicit scene z IS the paint order
                "cluster": str(e.get("cluster", "")),
                "states": {"built": tex},
            }
            if e.get("shadow"):
                entry["shadow"] = True
            buildings.append(entry)
```

- [ ] **Step 2: Emit coverups in the manifest dict**

Change the `manifest` assignment (~line 121) to include `coverups`:

```python
    manifest = {"version": 1, "id": scene, "label": label,
                "canvas": {"width": cw, "height": ch},
                "background": background, "buildings": buildings, "coverups": coverups}
```

Also update the final print to report coverups, e.g.:

```python
    print(f"  wrote {os.path.relpath(out, REPO)}  ({len(buildings)} props, {len(coverups)} coverups, canvas {cw}x{ch})")
```

- [ ] **Step 3: Regenerate + import**

Run:

```bash
cd /Users/xup/dh/merge-wt-market-unlocks
python3 games/grove/tools/build_page_manifests.py --only fairy_hollow_market
make import
```

Expected stdout: `... (6 props, 11 coverups, canvas 1320x2346)`. `make import` completes without error.

- [ ] **Step 4: Extend the manifest test**

In `games/grove/tests/grove_page_manifest_tests.gd`, add (mirror the file's actual assert API — open it first):

```gdscript
func test_market_manifest_carries_cluster_coverups() -> void:
	var path := "res://games/grove/assets/map/pages/zone_fairy_hollow_market.json"
	var doc: Dictionary = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	var coverups: Array = doc.get("coverups", [])
	assert_true(coverups.size() == 11, "11 canopy coverups carried through")
	var by_cluster := {}
	for c in coverups:
		var cl := String((c as Dictionary).cluster)
		by_cluster[cl] = int(by_cluster.get(cl, 0)) + 1
		assert_false(cl.begins_with("unlock_region_"), "cluster prefix stripped: %s" % cl)
		assert_true(ResourceLoader.exists(String((c as Dictionary).image)), "coverup art imported")
	for want in ["lantern_gate", "flower_crate", "stream_bridge", "crystal_map_stall", "tea_stall", "mushroom_hall"]:
		assert_true(by_cluster.has(want), "coverup group for %s" % want)
```

- [ ] **Step 5: Run the manifest suite**

Run:

```bash
godot --headless --path . -s res://games/grove/tests/grove_page_manifest_tests.gd
```

Expected: PASS (and the Task-1-prior `test_market_manifest_has_six_clusters` still passes). Adapt asserts to the suite's real helpers if names differ.

- [ ] **Step 6: Commit**

```bash
git add games/grove/tools/build_page_manifests.py games/grove/assets/map/pages/zone_fairy_hollow_market.json games/grove/assets/map/pages/fairy_hollow_market games/grove/tests/grove_page_manifest_tests.gd
git commit -m "feat(market): carry authored coverup canopy layer into the page manifest"
```

---

### Task 2: Point page 1 at the market + declare cluster order/gates

**Files:**
- Modify: `games/grove/grove_data.gd` — the page-1 `MAPS` row (~line 426-438)
- Test: `games/grove/tests/grove_placement_tests.gd`

**Interfaces:**
- Consumes: Task 1's manifest.
- Produces: page-1 `MAPS` row with `zone_manifest` → the market manifest, `id` stays `"fairy_hollow"`, new keys:
  - `"coverup_mode": true`
  - `"clusters": [ {"id", "cost", "min_level"} … ]` in strict bottom-up unlock order. Read by `content.gd` (Task 5) for the sequence + gate. Do NOT touch `BUILDINGS`, the `spots` list, or any `fh_*` id.

- [ ] **Step 1: Repoint page 1 and add the cluster table**

In `games/grove/grove_data.gd`, in `_build_maps()`, change the `fairy_hollow` row header (keep `id`, `name`, `hub`, and the existing `spots: [...]` list untouched below):

```gdscript
	{"id": "fairy_hollow", "name": "Fairy Hollow", "hub": true,
		"zone_manifest": "res://games/grove/assets/map/pages/zone_fairy_hollow_market.json",
		"covering_frames": [],
		"coverup_mode": true,
		"clusters": [
			{"id": "lantern_gate", "cost": 10, "min_level": 1},
			{"id": "flower_crate", "cost": 25, "min_level": 2},
			{"id": "stream_bridge", "cost": 45, "min_level": 3},
			{"id": "crystal_map_stall", "cost": 70, "min_level": 4},
			{"id": "tea_stall", "cost": 110, "min_level": 5},
			{"id": "mushroom_hall", "cost": 160, "min_level": 6},
		],
		"spots": [
```

(The `covering_frames: []` replaces the old `_covering_frames("hollow_grass")` — the coverup is the authored canopy now, not a scatter. Leave the `spots: [...]` list exactly as it is for save-compat.)

- [ ] **Step 2: Write the failing data test**

In `games/grove/tests/grove_placement_tests.gd` add (match the suite's assert API):

```gdscript
func test_market_is_page_one_coverup_mode() -> void:
	var G := load("res://games/grove/grove_data.gd")
	var page: Dictionary = G.MAPS[0]
	assert_eq(String(page.id), "fairy_hollow", "page-1 id stays fairy_hollow")
	assert_true(bool(page.get("coverup_mode", false)), "page 1 is coverup mode")
	assert_true(String(page.zone_manifest).ends_with("zone_fairy_hollow_market.json"), "renders the market")
	var ids: Array = []
	for c in page.get("clusters", []):
		ids.append(String((c as Dictionary).id))
	assert_eq(ids, ["lantern_gate", "flower_crate", "stream_bridge", "crystal_map_stall", "tea_stall", "mushroom_hall"], "bottom-up unlock order")
```

- [ ] **Step 3: Run + fast sweep**

Run:

```bash
godot --headless --path . -s res://games/grove/tests/grove_placement_tests.gd
make test-fast
```

Expected: the new test PASSES; `make test-fast` shows no FAIL/crash (no `fh_*` ids were touched, so nothing else should move).

- [ ] **Step 4: Commit**

```bash
git add games/grove/grove_data.gd games/grove/tests/grove_placement_tests.gd
git commit -m "feat(market): page 1 renders the market in coverup mode with a cluster gate table"
```

---

### Task 3: The padlock lock-badge module

**Files:**
- Create: `engine/scripts/ui/lock_badge.gd`
- Test: `games/grove/tests/grove_ui_tests.gd`

**Interfaces:**
- Produces:
  - `LockBadge.make(id: String) -> Control` — a 120×120 Control named `lock_<id>`, `mouse_filter = IGNORE`, `set_meta("building_id", id)`, with a padlock `TextureRect` child named `Pad` (texture `Game.art("ui/meadow_v2/icon_padlock.png")`, `expand_mode` set BEFORE size). Starts LOCKED (dim, no glow).
  - `LockBadge.set_ready(badge: Control, ready: bool) -> void` — READY brightens the pad and adds a child named `Glow`; LOCKED dims it and removes `Glow`. Idempotent.

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

- [ ] **Step 2: Run to verify it fails**

Run: `godot --headless --path . -s res://games/grove/tests/grove_ui_tests.gd`
Expected: FAIL (module missing).

- [ ] **Step 3: Implement the module**

Create `engine/scripts/ui/lock_badge.gd`:

```gdscript
extends RefCounted
## The market cover-up PADLOCK badge (fairy_hollow_market cluster unlocks). A covered cluster wears
## one of these: LOCKED reads as a dim padlock; READY brightens it and adds a soft glow so it reads
## as tappable. Tapping a READY badge routes through map.gd, which claims the cluster (deducts cost,
## records the unlock) and reveals its canopy away. Render-only + stateless: map.gd owns which is ready.

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

If `ui/meadow_v2/glow_soft.png` does not exist, grep `engine/scripts/ui` + `games/grove` for the halo/glow asset already used (a `*halo*`/`*glow*` under `ui/`) and use that path. The glow is an additive halo layer, never a `modulate` brighten (>1.0 modulate is invisible on bright art).

- [ ] **Step 4: Run to verify it passes**

Run: `godot --headless --path . -s res://games/grove/tests/grove_ui_tests.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/ui/lock_badge.gd games/grove/tests/grove_ui_tests.gd
git commit -m "feat(market): padlock lock-badge with locked/ready states"
```

---

### Task 4: Render the coverup layer + lock badges in home_zone_view

**Files:**
- Modify: `engine/scripts/ui/home_zone_view.gd` — `build()` signature (~line 28), the per-building loop, and the return dict (~line 122)
- Test: `games/grove/tests/grove_ui_tests.gd`

**Interfaces:**
- Consumes: `LockBadge.make` (Task 3); the manifest `coverups` list (Task 1).
- Produces: `HomeZoneView.build(parent, manifest, state_of, next_step_of, covering_frames := [], coverup_mode := false, cluster_locked := Callable()) -> Dictionary`.
  - When `coverup_mode` is true: every building renders its `built` texture unconditionally (no `state_of`/badge/scatter); then, for each cluster whose `cluster_locked.call(cluster_id)` is true, mount ONE Control named `cover_<cluster>` holding that cluster's canopy `TextureRect`s (positioned center-bottom like props, painted in `sort_y` order) frontmost, plus a `LockBadge` centred on the cluster's structure. Return `coverups` = {cluster_id → group Control} and `badges` = {cluster_id → lock badge}.
  - When false: behaviour unchanged from today.

- [ ] **Step 1: Write the failing test**

Append to `games/grove/tests/grove_ui_tests.gd`:

```gdscript
func test_coverup_mode_mounts_canopy_groups_and_lock_badges() -> void:
	var HZV := load("res://engine/scripts/ui/home_zone_view.gd")
	var manifest := {
		"canvas": {"width": 200, "height": 200}, "background": "",
		"buildings": [{"id": "tea_stall", "position": [100, 150], "display_size": [80, 80], "cluster": "tea_stall", "states": {"built": ""}}],
		"coverups": [
			{"id": "canopy_a", "cluster": "tea_stall", "position": [90, 140], "display_size": [60, 60], "sort_y": 0, "image": ""},
			{"id": "canopy_b", "cluster": "tea_stall", "position": [110, 150], "display_size": [60, 60], "sort_y": 1, "image": ""},
		],
	}
	var parent := Control.new()
	add_child(parent)
	var state_of := func(_id): return "built"
	var next_of := func(_id): return {}
	var locked := func(_cl): return true
	var built: Dictionary = HZV.build(parent, manifest, state_of, next_of, [], true, locked)
	assert_true(built.coverups.has("tea_stall"), "canopy group per cluster")
	assert_eq((built.coverups["tea_stall"] as Control).get_child_count(), 2, "both canopy sprites grouped")
	assert_true(built.badges.has("tea_stall"), "lock badge per locked cluster")
	assert_eq((built.badges["tea_stall"] as Control).name, "lock_tea_stall", "it is a lock badge")
	# an unlocked cluster gets neither
	var locked_none := func(_cl): return false
	var built2: Dictionary = HZV.build(parent, manifest, state_of, next_of, [], true, locked_none)
	assert_false(built2.coverups.has("tea_stall"), "no canopy when unlocked")
	assert_false(built2.badges.has("tea_stall"), "no lock when unlocked")
	parent.queue_free()
```

- [ ] **Step 2: Run to verify it fails**

Run: `godot --headless --path . -s res://games/grove/tests/grove_ui_tests.gd`
Expected: FAIL (`build()` takes no `coverup_mode`).

- [ ] **Step 3: Add the preload + signature**

In `engine/scripts/ui/home_zone_view.gd`, beside `const Coverings`:

```gdscript
const LockBadge = preload("res://engine/scripts/ui/lock_badge.gd")
```

Change the signature:

```gdscript
static func build(parent: Control, manifest: Dictionary, state_of: Callable, next_step_of: Callable,
		covering_frames: Array = [], coverup_mode: bool = false, cluster_locked: Callable = Callable()) -> Dictionary:
```

- [ ] **Step 4: Branch the per-building loop for coverup mode**

Inside the `for i in order:` loop, force the built texture and skip badges/scatter in coverup mode. Replace the `var state := String(state_of.call(id))` line with:

```gdscript
		var state := "built" if coverup_mode else String(state_of.call(id))
```

and guard the build-badge + scatter blocks so they only run when NOT in coverup mode. Wrap the existing `var step := next_step_of.call(id)` … badge block and the `if state == "empty" …` covering block in:

```gdscript
		if not coverup_mode:
			var step: Dictionary = next_step_of.call(id)
			if not step.is_empty():
				var badge := _build_badge(id, int(step.get("cost", 0)), int(step.get("min_level", 1)))
				badge.position = anchor - badge.size * 0.5
				pending_badges.append(badge)
				badges[id] = badge
			if state == "empty" and not step.is_empty():
				var cover := Coverings.scatter(b, covering_frames)
				if cover != null:
					stage.add_child(cover)
					coverings[id] = cover
```

- [ ] **Step 5: Mount the coverup groups + lock badges after the building loop**

After the `for badge_node in pending_badges: stage.add_child(badge_node)` line, add:

```gdscript
	if coverup_mode:
		# group the authored canopy sprites by cluster; mount each locked cluster's group frontmost.
		var anchor_of := {}          # cluster id -> its structure anchor (for the lock badge centre)
		for entry_v in manifest.get("buildings", []):
			var eb: Dictionary = entry_v
			anchor_of[String(eb.get("cluster", eb.get("id", "")))] = _vec(eb.get("position", [0, 0]))
		var groups := {}             # cluster id -> {group, sprites:[{sort_y, node}]}
		for cov_v in manifest.get("coverups", []):
			var cov: Dictionary = cov_v
			var cl := String(cov.get("cluster", ""))
			if not (cluster_locked.is_valid() and bool(cluster_locked.call(cl))):
				continue
			if not groups.has(cl):
				var grp := Control.new()
				grp.name = "cover_%s" % cl
				grp.mouse_filter = Control.MOUSE_FILTER_IGNORE
				groups[cl] = {"group": grp, "sprites": []}
			var ca := _vec(cov.get("position", [0, 0]))
			var cd := _vec(cov.get("display_size", [100, 100]))
			var spr := TextureRect.new()
			spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			spr.size = cd
			spr.position = ca - Vector2(cd.x * 0.5, cd.y)     # center-bottom anchor, like props
			spr.pivot_offset = cd * 0.5
			if String(cov.get("image", "")) != "" and ResourceLoader.exists(String(cov.image)):
				spr.texture = load(String(cov.image)) as Texture2D
			(groups[cl]["sprites"] as Array).append({"sort_y": int(cov.get("sort_y", 0)), "node": spr})
		for cl in groups.keys():
			var g: Dictionary = groups[cl]
			var sprites: Array = g.sprites
			sprites.sort_custom(func(a, b2): return int(a.sort_y) < int(b2.sort_y))
			for s in sprites:
				(g.group as Control).add_child(s.node)
			stage.add_child(g.group)                          # frontmost (added last)
			coverings[cl] = g.group
			var lb: Control = LockBadge.make(cl)
			var ap: Vector2 = anchor_of.get(cl, Vector2.ZERO)
			lb.position = ap - Vector2(0, 60) - lb.size * 0.5   # a touch above the plot's center-bottom
			stage.add_child(lb)
			badges[cl] = lb
```

(Keeps the existing `return {"stage": stage, "base": base, "props": props, "badges": badges, "coverings": coverings, "canvas": native}` — `coverings` now holds the per-cluster canopy groups in coverup mode, `badges` holds the lock badges.)

- [ ] **Step 6: Run to verify it passes**

Run: `godot --headless --path . -s res://games/grove/tests/grove_ui_tests.gd`
Expected: PASS. Also run `make test-fast` to confirm the non-coverup pages still render (the `coverup_mode=false` path is unchanged).

- [ ] **Step 7: Commit**

```bash
git add engine/scripts/ui/home_zone_view.gd games/grove/tests/grove_ui_tests.gd
git commit -m "feat(market): home_zone_view renders per-cluster coverup canopy + lock badges"
```

---

### Task 5: Cluster-unlock helpers + map.gd wiring

**Files:**
- Modify: `engine/scripts/core/content.gd` — add cluster helpers near the other map/unlock helpers (~line 685-945)
- Modify: `engine/scripts/scenes/map.gd` — `_build_map` build call (~line 417-428), a coverup-sequence helper, tap routing, `_refresh_play_cta` (~line 1902), the bottom pill counter (~line 565-575)
- Test: `games/grove/tests/grove_economy_tests.gd` (helpers, pure), `grove_placement_tests.gd` (sequence)

**Interfaces:**
- Produces in `content.gd` (`G` in map.gd):
  - `G.clusters(z) -> Array` — the page's `clusters` list (`[]` if none).
  - `G.cluster_locked(z, cluster_id, unlocks) -> bool` — true unless `unlocks` has the cluster id.
  - `G.next_locked_cluster(z, unlocks) -> String` — the first cluster in order not in `unlocks` (`""` if all unlocked).
  - `G.cluster_ready(z, cluster_id, unlocks, level, coins) -> bool` — true iff it is the next locked cluster AND `level >= min_level` AND `coins >= cost`.
  - `G.cluster_cost(z, cluster_id) -> int`.
- Produces in `map.gd`: coverup-mode build wiring; a lock tap on the ready cluster claims it (deduct `cluster_cost` coins, `unlocks[cluster]=true`, persist) then reveals its canopy group and rebuilds.

- [ ] **Step 1: Write the failing helper test**

In `games/grove/tests/grove_economy_tests.gd` add (match the suite's asserts):

```gdscript
func test_cluster_sequence_and_ready() -> void:
	var G := load("res://engine/scripts/core/content.gd")
	var unlocks := {}
	assert_eq(G.next_locked_cluster(0, unlocks), "lantern_gate", "bottom cluster first")
	assert_true(G.cluster_locked(0, "tea_stall", unlocks), "tea_stall starts locked")
	# not ready if under-leveled/too poor
	assert_false(G.cluster_ready(0, "lantern_gate", unlocks, 0, 0), "gate unmet -> not ready")
	assert_true(G.cluster_ready(0, "lantern_gate", unlocks, 1, 10), "gate met -> ready")
	# a later cluster is never ready while an earlier one is still locked
	assert_false(G.cluster_ready(0, "flower_crate", unlocks, 9, 9999), "strict sequence")
	unlocks["lantern_gate"] = true
	assert_eq(G.next_locked_cluster(0, unlocks), "flower_crate", "advances after unlock")
	assert_true(G.cluster_ready(0, "flower_crate", unlocks, 9, 9999), "next becomes ready")
```

- [ ] **Step 2: Run to verify it fails**

Run: `godot --headless --path . -s res://games/grove/tests/grove_economy_tests.gd`
Expected: FAIL (helpers missing).

- [ ] **Step 3: Implement the content.gd helpers**

Add to `engine/scripts/core/content.gd` (near `map_spots_done`/`owned_count`):

```gdscript
# --- market cover-up clusters (fairy_hollow_market): a strict bottom-up unlock sequence over the
# scene's authored coverup layer. State persists in `unlocks` keyed by cluster id (same dict the
# spot/gate system uses). Gate mirrors the old progression: a level floor + a coin cost per cluster.
static func clusters(z: int) -> Array:
	if z < 0 or z >= MAPS.size():
		return []
	return MAPS[z].get("clusters", [])

static func _cluster_def(z: int, cluster_id: String) -> Dictionary:
	for c in clusters(z):
		if String((c as Dictionary).id) == cluster_id:
			return c
	return {}

static func cluster_locked(z: int, cluster_id: String, unlocks: Dictionary) -> bool:
	return not unlocks.has(cluster_id)

static func next_locked_cluster(z: int, unlocks: Dictionary) -> String:
	for c in clusters(z):
		var id := String((c as Dictionary).id)
		if not unlocks.has(id):
			return id
	return ""

static func cluster_cost(z: int, cluster_id: String) -> int:
	return int(_cluster_def(z, cluster_id).get("cost", 0))

static func cluster_ready(z: int, cluster_id: String, unlocks: Dictionary, level: int, coins: int) -> bool:
	if cluster_id != next_locked_cluster(z, unlocks):
		return false
	var d := _cluster_def(z, cluster_id)
	if d.is_empty():
		return false
	return level >= int(d.get("min_level", 1)) and coins >= int(d.get("cost", 0))
```

- [ ] **Step 4: Run to verify the helper test passes**

Run: `godot --headless --path . -s res://games/grove/tests/grove_economy_tests.gd`
Expected: PASS.

- [ ] **Step 5: Wire the build call + sequence in map.gd**

In `engine/scripts/scenes/map.gd`, add a member beside `var _zone_coverings`:

```gdscript
var _zone_badges: Dictionary = {}     # cluster id -> its lock badge node (coverup pages)
```

Change the `HomeZoneView.build(...)` call in `_build_map` (~line 417) to pass coverup mode + a locked predicate, and capture the badges:

```gdscript
	var _coverup := bool(G.MAPS[_map_idx].get("coverup_mode", false))
	var _locked_cb := func(cl: String) -> bool: return G.cluster_locked(_map_idx, cl, unlocks)
	var built = HomeZoneView.build(holder, manifest, Callable(self, "_home_state_id"), \
		Callable(self, "_home_next_step"), G.MAPS[_map_idx].get("covering_frames", []), _coverup, _locked_cb)
	_zone_coverings = built.coverings
	_zone_badges = built.badges
```

Then, where `spot_hits` is filled from `built.badges` (~line 428), register the lock badges as tap targets too (they share the badge map). Confirm the existing loop appends `{"node": built.badges[id], "z": _map_idx, "k": -1, "building": String(id)}` for each key in `built.badges` — in coverup mode those keys are cluster ids, which is what we want. After that loop add:

```gdscript
	if _coverup:
		_apply_coverup_sequence()
```

Add the helper (near `_cheapest_buyable`):

```gdscript
# Coverup pages: only the next-in-order locked cluster may read READY (and only when its gate is met);
# every other locked cluster stays dim, and only the ready one keeps a live tap target.
func _apply_coverup_sequence() -> void:
	var LB: GDScript = load("res://engine/scripts/ui/lock_badge.gd")
	var next_id := G.next_locked_cluster(_map_idx, unlocks)
	var lvl := G.level()
	var wallet := Save.coins()
	for id_v in _zone_badges.keys():
		var id := String(id_v)
		LB.set_ready(_zone_badges[id], G.cluster_ready(_map_idx, id, unlocks, lvl, wallet))
	var kept: Array = []
	for hit in spot_hits:
		var bid := String(hit.get("building", ""))
		if bid == "" or bid == next_id:
			kept.append(hit)
	spot_hits = kept
```

- [ ] **Step 6: Route the lock tap to claim + reveal**

Find where a `spot_hits` entry with `k == -1` routes on tap (the build-tap path, ~line 1743 / `_map_tap`). In coverup mode the tap must claim the cluster instead of `_on_build_tap`. In the tap handler, before the existing build-tap dispatch, add a coverup branch:

```gdscript
	if bool(G.MAPS[_map_idx].get("coverup_mode", false)):
		_on_cluster_tap(String(hit.get("building", "")), hit.node, at)
		return
```

Add the claim method (model it on `_on_build_tap`'s FX + `SceneCoverings.reveal`):

```gdscript
func _on_cluster_tap(cluster_id: String, node: Control, at: Vector2) -> void:
	if cluster_id == "":
		return
	if not G.cluster_ready(_map_idx, cluster_id, unlocks, G.level(), Save.coins()):
		Audio.play("invalid_soft", -4.0)
		FX.wobble(node)
		var d := G._cluster_def(_map_idx, cluster_id) if false else {}   # (cost/level msg optional)
		return
	Save.add_coins(-G.cluster_cost(_map_idx, cluster_id))
	unlocks[cluster_id] = true
	FX.burst(self, at, STRAW, 18)
	Audio.play("level_complete", -6.0, 1.2)
	SceneCoverings.reveal(_zone_coverings.get(cluster_id), self)
	_zone_coverings.erase(cluster_id)
	_persist()
	_build_map(false)
	_refresh_play_cta()
	_update_hud()
```

(Use the real coin-mutation call this codebase uses — grep for how `_on_build_tap`/`HomeBuild.buy_step` deducts coins; if it is `Save.spend`/`Wallet.spend` rather than `Save.add_coins(-cost)`, use that. Drop the vestigial `d :=` line; it is a placeholder for an optional "needs level/coins" toast — either wire a real `FX.floating_text` message like `_on_build_tap` does, or omit it.)

- [ ] **Step 7: Hold PLAY + point the pill at clusters-left**

In `_refresh_play_cta()` (~line 1902) make `ready` false on coverup pages:

```gdscript
	var ready := _unlock_ready() and not bool(G.MAPS[_map_idx].get("coverup_mode", false))
```

In the pill builder (~line 565-575), branch the counter for coverup mode:

```gdscript
	var total: int = G.MAPS[z].spots.size()
	var owned := owned_count(z)
	if bool(G.MAPS[z].get("coverup_mode", false)):
		var cl: Array = G.clusters(z)
		total = cl.size()
		owned = 0
		for c in cl:
			if not unlocks.has(String((c as Dictionary).id)):
				continue
			owned += 1
	var left := total - owned
```

- [ ] **Step 8: Write the sequence integration test**

In `games/grove/tests/grove_placement_tests.gd` add (adapt to the suite base's scene helper — grep `grove_test_base.gd` for how sibling tests build a page-1 map scene and set level/coins/unlocks):

```gdscript
func test_only_next_cluster_ready_and_unlock_advances() -> void:
	var scn = _open_map_scene(0)                # page 1 helper from grove_test_base (match its real name)
	Save.set_coins(9999)
	_set_level(scn, 6)                          # several affordable at once
	scn._build_map(false)
	var ready := []
	for id in ["lantern_gate", "flower_crate", "stream_bridge", "crystal_map_stall", "tea_stall", "mushroom_hall"]:
		var b = scn._zone_badges.get(id, null)
		if b != null and b.has_node("Glow"):
			ready.append(id)
	assert_eq(ready, ["lantern_gate"], "only the bottom cluster is ready under strict sequence")
	# claim it
	scn._on_cluster_tap("lantern_gate", scn, Vector2.ZERO)
	assert_true(scn.unlocks.has("lantern_gate"), "claimed cluster recorded")
	assert_eq(G.next_locked_cluster(0, scn.unlocks), "flower_crate", "sequence advanced")
```

(If the base lacks `_open_map_scene`/`_set_level`, reuse whatever the sibling map/placement tests use — do not invent a harness.)

- [ ] **Step 9: Run the sequence test + fast sweep**

Run:

```bash
godot --headless --path . -s res://games/grove/tests/grove_placement_tests.gd
make test-fast
```

Expected: PASS; no FAIL/crash.

- [ ] **Step 10: Commit**

```bash
git add engine/scripts/core/content.gd engine/scripts/scenes/map.gd games/grove/tests
git commit -m "feat(market): strict bottom-up cluster unlock sequence, tap-to-reveal wiring"
```

---

### Task 6: Full verification & visual proof

**Files:** none (verification only)

- [ ] **Step 1: Full sweep**

Run: `make test`
Expected: the per-suite table shows no FAIL/crash. Fix any regression before proceeding.

- [ ] **Step 2: Render page 1 locked**

Use the project's map/home screenshot tool (grep the `Makefile` for the real target, e.g. `map-shot`/`grove-shot`) to capture page 1 at level 1 with no unlocks. Confirm in the image: the full market scene is built, all 6 clusters wear their canopy cover-up, the bottom `lantern_gate` shows a bright/glowing padlock, the others dim padlocks, and the bottom pill reads "6" to restore.

- [ ] **Step 3: Render after one unlock**

Drive one claim (`_on_cluster_tap("lantern_gate", …)`) in the shot script and re-capture. Confirm: `lantern_gate`'s canopy is gone (its built art shows), and `flower_crate` is now the ready padlock. Attach both frames to the handoff (see-the-result gate — do not claim done on unit passes alone).

- [ ] **Step 4: Commit any fixes**

```bash
git add -A && git commit -m "test(market): full sweep green + visual verification"
```

---

## Self-Review

**Spec coverage (revised):**
- Replace first scene with market, don't author content → Task 1 (carry existing coverup through) + Task 2 (repoint, id stays). ✓
- Clusters in the cover-up overlay, each = an unlock → Task 1 `coverups` grouped by cluster + Task 4 render per cluster. ✓
- On unlock the leaves move away → Task 5 `_on_cluster_tap` → `SceneCoverings.reveal` of the cluster group. ✓
- Add a lock icon; ready when unlockable; click to unlock → Task 3 badge + Task 4 mount + Task 5 sequence/ready/tap. ✓
- Strict bottom-up sequence + keep bottom pill counter → Task 2 order + Task 5 Steps 5/7. ✓
- Use existing definitions, no generation of content → Task 1 is pure transport; no scene/art authoring anywhere. ✓

**Placeholder scan:** The "grep for the real coin-spend call / glow asset / test-base helper" notes are explicit fallbacks with a named search and a specified primary path, not deferred work. The `d :=` line in Task 5 Step 6 is explicitly called out to drop.

**Type consistency:** `coverup_mode`/`cluster_locked`, `_zone_badges`, `_apply_coverup_sequence`, `_on_cluster_tap`, and the `G.cluster_*` helpers are named identically across Tasks 2, 4, 5. Cluster ids are identical in the manifest (Task 1), data (Task 2), and every test.
