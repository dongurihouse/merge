# Swipe to Change Scene — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On the home screen, let the player swipe horizontally to move between scene pages, with a finger-following slide that snaps to the next/previous scene, replacing the page-turn arrows.

**Architecture:** All changes live in `engine/scripts/scenes/map.gd` (the `"map"` view) plus tests in `games/grove/tests/grove_explore_tests.gd`. A scene page is rebuilt through a new `_build_page_node(z, parent, interactive)` helper so two scenes can render side-by-side and translate as units. A gesture state machine in the map input surface follows the finger during a horizontal drag, previews the adjacent scene, and on release either commits (rebuild the destination via `_open_map`) or springs back.

**Tech Stack:** Godot 4.6, GDScript. Headless SceneTree tests via `make test-fast` / `make test`.

## Global Constraints

- **Worktree only:** all edits happen in the worktree `/Users/xup/dh/wt-swipe-scene` (branch `swipe-scene`). The main tree blocks edits via a PreToolUse hook.
- **Test after every change:** `make test-fast` (engine suites, seconds) after each step; `make test` (full sweep incl. grove suites) before handoff. Both run headless in parallel and fail on any FAIL/crash.
- **Headless test rules:** logic/scene tests run as headless SceneTree scripts; never open a visible window. Drive input by calling `map._on_input(event)` directly with synthetic `InputEventScreenTouch` / `InputEventScreenDrag` / `InputEventMouseButton` (not `push_input`, which skips touch emulation).
- **Gating parity:** scene navigation respects `map_unlocked(z)` and never wraps past the first/last page — identical to the arrows being removed.
- **No changes** to the place-picker (`"select"`) or MAPS gallery (`"maps"`) views, and no new scene-unlock rules.
- Spec: `docs/superpowers/specs/2026-07-23-swipe-to-change-scene-design.md`.

---

### Task 1: Pure swipe-decision helpers

Two pure, unit-testable functions that encode direction and the commit threshold. Added first so the gesture (Task 3) and its tests can rely on tested logic.

**Files:**
- Modify: `engine/scripts/scenes/map.gd` (add two `static func`s + two consts)
- Test: `games/grove/tests/grove_explore_tests.gd`

**Interfaces:**
- Produces:
  - `static func _neighbor_z(map_idx: int, dx: float) -> int`
  - `static func _swipe_commit(dx: float, vel: float, view_w: float, has_neighbor: bool) -> bool`
  - `const SWIPE_COMMIT_FRAC := 0.33`, `const SWIPE_FLING := 700.0`

- [ ] **Step 1: Write the failing test**

In `games/grove/tests/grove_explore_tests.gd`, add this const to the top-of-file `const` block (after the existing `const Tune := ...` line):

```gdscript
const MapScript = preload("res://engine/scripts/scenes/map.gd")
```

Add the test function (place it after `_test_quest_unused_generator_fade`, near the other `_test_*` defs):

```gdscript
func _test_swipe_decision_helpers() -> void:
	# direction: dragging LEFT reveals the NEXT scene, RIGHT reveals the PREVIOUS
	ok(MapScript._neighbor_z(2, -30.0) == 3, "dragging left reveals the next scene")
	ok(MapScript._neighbor_z(2, 30.0) == 1, "dragging right reveals the previous scene")
	# distance threshold: on a 1000px viewport, commit at >= 330px
	ok(MapScript._swipe_commit(-400.0, 0.0, 1000.0, true), "a drag past a third of the width commits")
	ok(not MapScript._swipe_commit(-200.0, 0.0, 1000.0, true), "a drag under a third of the width does not commit")
	# fling: a fast flick in the SAME direction commits under the distance threshold
	ok(MapScript._swipe_commit(-80.0, -900.0, 1000.0, true), "a fast flick commits under the distance threshold")
	ok(not MapScript._swipe_commit(-80.0, 900.0, 1000.0, true), "a flick opposite the drag does not commit")
	# an edge (no neighbour) never commits, however hard you pull or flick
	ok(not MapScript._swipe_commit(-900.0, -900.0, 1000.0, false), "an edge swipe with no neighbour never commits")
```

Register it in `_initialize()` (add after the last existing test call):

```gdscript
	_test_swipe_decision_helpers()
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd /Users/xup/dh/wt-swipe-scene && make test-grove
```
Expected: FAIL — `Invalid call. Nonexistent function '_neighbor_z' in base 'GDScript'` (or the suite errors on the missing functions).

- [ ] **Step 3: Write minimal implementation**

In `engine/scripts/scenes/map.gd`, add this block. Put it just above the `# --- input: ONE surface, still-tap resolution` section (near `_on_input`):

```gdscript
# --- home page-swipe: pure decisions (unit-tested) --------------------------------------
const SWIPE_COMMIT_FRAC := 0.33   # commit once dragged past this fraction of the viewport width
const SWIPE_FLING := 700.0        # px/s horizontal flick that commits under the distance threshold

# The scene index a horizontal drag of `dx` px reveals: drag LEFT (dx < 0) -> the NEXT page,
# drag RIGHT (dx > 0) -> the PREVIOUS page. Callers still bounds-check the result against G.MAPS.
static func _neighbor_z(map_idx: int, dx: float) -> int:
	return map_idx + 1 if dx < 0.0 else map_idx - 1

# Should releasing a swipe of `dx` px (last horizontal velocity `vel` px/s, viewport `view_w` px
# wide) commit to the neighbour? Past a third of the width, OR a fast flick in the SAME direction.
# An edge drag (no neighbour in that direction) never commits.
static func _swipe_commit(dx: float, vel: float, view_w: float, has_neighbor: bool) -> bool:
	if not has_neighbor:
		return false
	if absf(dx) >= view_w * SWIPE_COMMIT_FRAC:
		return true
	return dx != 0.0 and absf(vel) >= SWIPE_FLING and signf(vel) == signf(dx)
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
cd /Users/xup/dh/wt-swipe-scene && make test-grove
```
Expected: PASS — the six new asserts pass; no other suite regresses.

- [ ] **Step 5: Commit**

```bash
cd /Users/xup/dh/wt-swipe-scene && git add engine/scripts/scenes/map.gd games/grove/tests/grove_explore_tests.gd && git commit -m "Swipe: pure neighbour-index + commit-threshold helpers

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Render restructure — one page node, arrows removed

Extract the scene render into `_build_page_node` so a page is a single translatable Control, route `_build_map` through it, and delete the page-turn arrows. Interactive hit-testing is unchanged for the live page; the new `interactive=false` path (used by Task 3's preview) renders visuals only.

**Files:**
- Modify: `engine/scripts/scenes/map.gd` (`_build_map`; add `_build_page_node`; delete `_add_page_arrows`; add `_page_cur` member)
- Modify: `docs/design/scene-workbench-guide.md` (chevrons → swipe, one line)
- Test: `games/grove/tests/grove_explore_tests.gd`

**Interfaces:**
- Consumes: `_page_manifest(z)`, `HomeZoneView.build`, `_home_state_id`, `_home_next_step`, `_habitat_members(z)`, `_apply_coverup_sequence()`, `_clamp_badges_above_nav(factor)`, members `_map_rect`, `spot_hits`, `_zone_coverings`, `_zone_badges`, `unlocks` (all already in `map.gd`).
- Produces:
  - `func _build_page_node(z: int, parent: Control, interactive: bool) -> Control`
  - `var _page_cur: Control` — the live scene page node under `content`

- [ ] **Step 1: Write the failing tests**

In `games/grove/tests/grove_explore_tests.gd`, add both tests (near the other `_test_*` defs):

```gdscript
func _test_home_has_no_page_arrows() -> void:
	fresh("home_no_arrows")
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_map(1)          # an open page with both neighbours
	await process_frame
	ok(map.content.find_child("PageArrowNext", true, false) == null, "the home page no longer shows a next-page arrow")
	ok(map.content.find_child("PageArrowPrev", true, false) == null, "the home page no longer shows a prev-page arrow")
	ok(map.content.get_child_count() == 1, "the home renders as a single scene page node")
	map.queue_free()
	await process_frame

func _test_home_tap_unlocks_cluster() -> void:
	fresh("home_tap_unlocks")
	Save.earn_coins(1000)     # LEVEL_BASE_COINS=30 -> well past L2; wallet affords the first cluster
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_map(0)          # fairy_hollow (coverup) — its first cluster is the ready one
	await process_frame
	var next_id := G.next_locked_cluster(0, map.unlocks)
	ok(next_id != "", "the home page has a next-in-order locked cluster")
	var badge: Control = map._zone_badges.get(next_id, null)
	ok(badge != null, "the ready cluster's lock badge exists")
	if badge != null:
		_map_tap_at(map, _hit_center(badge))
		await create_timer(0.1).timeout
		ok(map.unlocks.has(next_id), "a still-tap on the home page unlocks the ready cluster (refactor kept taps working)")
	map.queue_free()
	await process_frame
```

Register both in `_initialize()` (add after the Task 1 line):

```gdscript
	await _test_home_has_no_page_arrows()
	await _test_home_tap_unlocks_cluster()
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd /Users/xup/dh/wt-swipe-scene && make test-grove
```
Expected: FAIL — `_test_home_has_no_page_arrows` fails on "no longer shows a next-page arrow" (the arrows still exist) and on the single-child assertion (arrows are extra children).

- [ ] **Step 3: Add the `_page_cur` member**

In `engine/scripts/scenes/map.gd`, next to `var _press := Vector2.ZERO ...` (around line 114), add:

```gdscript
var _page_cur: Control = null    # the live scene page node under `content` (the swipe's cur)
```

- [ ] **Step 4: Replace `_build_map`'s body and add `_build_page_node`**

Replace the entire current `_build_map` function body with:

```gdscript
func _build_map(animate := true) -> void:
	for c in content.get_children():
		c.queue_free()
	spot_hits.clear()
	select_hits.clear()
	# the stable canvas is a centered, design-aspect rect that COVER-FILLS the viewport (see _map_image_rect).
	_map_rect = _map_image_rect()
	_page_cur = _build_page_node(_map_idx, content, true)
	if animate:
		FX.pop_in(content)        # a navigation pops in; a live resize re-fit does not (would flicker)

# Build ONE scene page's visuals (zone holder + wandering-residents layer), fitted into _map_rect,
# into a fresh page Control added to `parent`. `interactive` (the LIVE page, z == _map_idx) registers
# hit-testing — spot_hits + the coverup ready-sequence + the badge-above-nav clamp, over the _zone_*
# members. A swipe's neighbour PREVIEW passes false: it renders visuals only and touches NO member
# state, so previewing it can never corrupt the live page's taps. Returns the page node.
func _build_page_node(z: int, parent: Control, interactive: bool) -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(page)

	var manifest := _page_manifest(z)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(holder)
	var coverup := bool(G.MAPS[z].get("coverup_mode", false))
	var unl := unlocks
	var locked_cb := func(cl: String) -> bool: return G.cluster_locked(z, cl, unl)
	var built := HomeZoneView.build(holder, manifest, Callable(self, "_home_state_id"), Callable(self, "_home_next_step"), \
		G.MAPS[z].get("covering_frames", []), coverup, locked_cb)
	# fit the native canvas into the cover-filled map rect (uniform scale keeps the cut-paper aspect).
	var stage: Control = built.stage
	var native: Vector2 = built.canvas
	var factor := maxf(_map_rect.size.x / native.x, _map_rect.size.y / native.y)
	stage.scale = Vector2.ONE * factor
	stage.position = _map_rect.position + (_map_rect.size - native * factor) * 0.5

	if interactive:
		_zone_coverings = built.coverings   # id -> covering group, revealed away on unlock
		_zone_badges = built.badges         # coverup pages: cluster id -> its lock badge
		# register each build/lock badge as a tap hit (k = -1 sentinel; the id rides the meta).
		for id in built.badges:
			spot_hits.append({"node": built.badges[id], "z": z, "k": -1, "building": String(id)})
		if coverup:
			_apply_coverup_sequence()       # only the next-in-order cluster stays a live tap target
			_clamp_badges_above_nav(factor)
	elif coverup:
		# preview only: show the correct ready-visuals without touching spot_hits / _zone_* members.
		var LB: GDScript = load("res://engine/scripts/ui/lock_badge.gd")
		var lvl := G.level()
		var wallet := Save.coins()
		for id_v in built.badges.keys():
			LB.set_ready(built.badges[id_v], G.cluster_ready(z, String(id_v), unlocks, lvl, wallet))

	# ambient life — one wanderer per placed resident (empty until something is placed).
	var amb := Ambient.build_population_layer(_map_rect.size, _habitat_members(z))
	amb.position = _map_rect.position
	amb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(amb)
	return page
```

- [ ] **Step 5: Delete `_add_page_arrows`**

Delete the entire `_add_page_arrows` function (the block starting at the comment `# ── picture-book PAGE-TURN arrows (interim browsing; ...` and its `func _add_page_arrows() -> void:` body, through the final `content.add_child(b)` line). Its only call site was the `_add_page_arrows()` line already removed from `_build_map` in Step 4.

- [ ] **Step 6: Update the design-doc mention**

In `docs/design/scene-workbench-guide.md`, change the line:

```
`grove_data._build_maps()` names the five pages; `map.gd` renders the current page's manifest and
adds the page-turn chevrons.
```

to:

```
`grove_data._build_maps()` names the five pages; `map.gd` renders the current page's manifest; a
horizontal swipe turns to the adjacent page.
```

- [ ] **Step 7: Run tests to verify they pass**

Run:
```bash
cd /Users/xup/dh/wt-swipe-scene && make test-grove
```
Expected: PASS — both new tests pass; the arrows are gone, the home renders one page node, and a still-tap still unlocks the ready cluster. No other suite regresses.

- [ ] **Step 8: Run the fast sweep**

Run:
```bash
cd /Users/xup/dh/wt-swipe-scene && make test-fast
```
Expected: PASS (engine suites unaffected).

- [ ] **Step 9: Commit**

```bash
cd /Users/xup/dh/wt-swipe-scene && git add engine/scripts/scenes/map.gd games/grove/tests/grove_explore_tests.gd docs/design/scene-workbench-guide.md && git commit -m "Swipe: one page node per scene; remove page-turn arrows

Extract _build_page_node so a scene renders as a single translatable
Control; a preview (interactive=false) renders visuals only and never
touches hit-test state. Drop the interim chevrons.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: The finger-following gesture

Wire the horizontal-drag state machine: activate on a mostly-horizontal move, preview the adjacent scene, follow the finger, and on release commit (rebuild the destination) or spring back. Adds an `animate` flag to `_open_map`, and cancels an in-flight swipe on viewport resize.

**Files:**
- Modify: `engine/scripts/scenes/map.gd` (`_open_map` signature; `_on_input`; add `_on_map_input`, `_swipe_move`, `_swipe_begin`, `_swipe_release`; add consts + members; `_relayout_after_resize`)
- Test: `games/grove/tests/grove_explore_tests.gd`

**Interfaces:**
- Consumes (from Tasks 1–2): `_neighbor_z(map_idx, dx)`, `_swipe_commit(dx, vel, view_w, has_neighbor)`, `_build_page_node(z, parent, interactive)`, `_page_cur`, `SWIPE_COMMIT_FRAC`, `SWIPE_FLING`. Also existing: `_map_tap`, `map_unlocked(z)`, `content`, `_map_idx`, `_press`, `Audio`.
- Produces: `func _open_map(z: int, animate := true)`; the gesture handlers; `var _swipe: Dictionary`; `var _swipe_tween: Tween`; consts `SWIPE_ACTIVATE`, `SWIPE_EDGE_RESIST`, `SWIPE_SNAP`.

- [ ] **Step 1: Write the failing tests**

In `games/grove/tests/grove_explore_tests.gd`, add the two input helpers (place them next to `_push_tap`):

```gdscript
func _swipe_touch(map, gpos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.pressed = pressed
	t.position = gpos
	map._on_input(t)

func _swipe_drag(map, gpos: Vector2, rel: Vector2, vel: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.position = gpos
	d.relative = rel
	d.velocity = vel
	map._on_input(d)
```

Add the three swipe tests (near the other `_test_*` defs):

```gdscript
func _test_home_swipe_commits_to_next_scene() -> void:
	fresh("home_swipe_commit")
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_map(1)          # an open middle page — has both neighbours
	await process_frame
	var start := int(map._map_idx)
	var v := map.get_viewport_rect().size
	var cy := v.y * 0.5
	# drag LEFT ~0.6 of the width (well past a third) -> commit to the NEXT scene
	_swipe_touch(map, Vector2(v.x * 0.85, cy), true)
	_swipe_drag(map, Vector2(v.x * 0.55, cy), Vector2(-v.x * 0.30, 0), Vector2(-300, 0))
	_swipe_drag(map, Vector2(v.x * 0.25, cy), Vector2(-v.x * 0.30, 0), Vector2(-300, 0))
	_swipe_touch(map, Vector2(v.x * 0.25, cy), false)
	await create_timer(0.4).timeout
	ok(int(map._map_idx) == start + 1, "swiping left past the threshold commits to the next scene")
	ok(String(Save.grove().get("last_map", "")) == String(G.MAPS[start + 1].id), "the committed scene persists as last_map")
	ok(map._swipe.is_empty(), "the swipe state is cleared after committing")
	map.queue_free()
	await process_frame

func _test_home_short_swipe_springs_back() -> void:
	fresh("home_swipe_cancel")
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_map(1)
	await process_frame
	var start := int(map._map_idx)
	var v := map.get_viewport_rect().size
	var cy := v.y * 0.5
	var px := v.x * 0.6
	# 40px drag: past the 12px activation, well under a third of the width, slow -> cancel
	_swipe_touch(map, Vector2(px, cy), true)
	_swipe_drag(map, Vector2(px - 40.0, cy), Vector2(-40, 0), Vector2(-80, 0))
	_swipe_touch(map, Vector2(px - 40.0, cy), false)
	await create_timer(0.4).timeout
	ok(int(map._map_idx) == start, "a short, slow swipe springs back to the same scene")
	ok(map.content.get_child_count() == 1, "the neighbour preview is freed after springing back")
	ok(map._swipe.is_empty(), "the swipe state is cleared after cancelling")
	map.queue_free()
	await process_frame

func _test_home_swipe_at_first_page_is_noop() -> void:
	fresh("home_swipe_edge")
	var map = load("res://engine/scenes/Map.tscn").instantiate()
	get_root().add_child(map)
	await process_frame
	map._open_map(0)          # first page — no previous scene
	await process_frame
	var v := map.get_viewport_rect().size
	var cy := v.y * 0.5
	# drag RIGHT (toward the non-existent previous page), far past the threshold, with a hard flick
	_swipe_touch(map, Vector2(v.x * 0.2, cy), true)
	_swipe_drag(map, Vector2(v.x * 0.9, cy), Vector2(v.x * 0.7, 0), Vector2(900, 0))
	_swipe_touch(map, Vector2(v.x * 0.9, cy), false)
	await create_timer(0.4).timeout
	ok(int(map._map_idx) == 0, "swiping toward a non-existent previous scene on page 0 is a no-op")
	ok(map.content.get_child_count() == 1, "no neighbour is built at the first-page edge")
	map.queue_free()
	await process_frame
```

Register all three in `_initialize()` (after the Task 2 lines):

```gdscript
	await _test_home_swipe_commits_to_next_scene()
	await _test_home_short_swipe_springs_back()
	await _test_home_swipe_at_first_page_is_noop()
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd /Users/xup/dh/wt-swipe-scene && make test-grove
```
Expected: FAIL — `_test_home_swipe_commits_to_next_scene` fails on "commits to the next scene" (`map._map_idx` unchanged: horizontal drags do nothing yet). `map._swipe` also does not exist yet, so the suite errors on that reference.

- [ ] **Step 3: Add the swipe consts and members**

In `engine/scripts/scenes/map.gd`, next to `_page_cur` (added in Task 2), add:

```gdscript
var _swipe: Dictionary = {}      # the in-flight home page-swipe; {} when idle (see _on_map_input)
var _swipe_tween: Tween = null   # the active snap/spring tween (settle guard + resize-cancel)
```

Just below the Task 1 swipe consts (`SWIPE_COMMIT_FRAC` / `SWIPE_FLING`), add:

```gdscript
const SWIPE_ACTIVATE := 12.0      # px of horizontal travel before a drag becomes a page-swipe
const SWIPE_EDGE_RESIST := 0.35   # damping when dragging toward a missing neighbour (first/last page)
const SWIPE_SNAP := 0.22          # seconds for the snap (commit) / spring-back (cancel) tween
```

- [ ] **Step 4: Add the `animate` flag to `_open_map`**

In `engine/scripts/scenes/map.gd`, change the `_open_map` signature and its `_build_map()` call:

```gdscript
func _open_map(z: int, animate := true) -> void:
```

and further down in the same function:

```gdscript
	_build_map(animate)
```

(All existing callers use `_open_map(z)`, so the default keeps their behavior unchanged.)

- [ ] **Step 5: Route `_on_input`'s map branch to the gesture, and implement it**

Replace the map-branch tail of `_on_input` (everything from the `# a MAP: a still-tap ...` comment through the `_map_tap(content.get_global_transform() * event.position)` line) so the whole function reads:

```gdscript
func _on_input(event: InputEvent) -> void:
	if _view == "select":
		_on_select_input(event)
		return
	if _view == "maps":
		_on_maps_input(event)
		return
	_on_map_input(event)
```

Then add the gesture handlers immediately below `_on_input`:

```gdscript
# The HOME (map) input surface. A horizontal drag past SWIPE_ACTIVATE becomes a page-swipe: the
# current scene follows the finger and the adjacent scene slides in from the side; release past a
# third of the width (or a fast flick) commits, else it springs back. A press/release that never
# crosses the swipe threshold still resolves as a still-tap (spots / build+lock badges), unchanged.
func _on_map_input(event: InputEvent) -> void:
	if _swipe.get("settling", false):
		return   # ignore input while a snap / spring-back tween finishes
	var press: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	var release: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
		or (event is InputEventScreenTouch and not event.pressed)
	var moved: bool = event is InputEventScreenDrag \
		or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)
	if press:
		_press = event.position
		_swipe = {}
		return
	if moved:
		_swipe_move(event)
		return
	if release:
		if _swipe.get("active", false):
			_swipe_release()      # owns _swipe until its tween finishes
		else:
			# a still-tap: hit-test against GLOBAL rects (content is identity here, scaled in place mode).
			if event.position.distance_to(_press) <= 18.0:
				_map_tap(content.get_global_transform() * event.position)
			_swipe = {}

# A drag while a press is down: activate a swipe on the first mostly-horizontal move past the
# threshold, then translate the current + neighbour pages 1:1 with the finger.
func _swipe_move(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_swipe["vel"] = event.velocity.x    # touch carries velocity; mouse motion does not
	var dx := event.position.x - _press.x
	var dy := event.position.y - _press.y
	if not _swipe.get("active", false):
		if absf(dx) <= absf(dy) or absf(dx) < SWIPE_ACTIVATE:
			return                          # not (yet) a horizontal swipe — leave the tap path open
		_swipe_begin(dx)
	var view_w: float = get_viewport_rect().size.x
	var nb: Control = _swipe.get("neighbor", null)
	var eff := dx
	if nb == null:
		eff = dx * SWIPE_EDGE_RESIST        # first/last page: damp and always spring back
	else:
		eff = clampf(dx, -view_w if _swipe.dir < 0 else 0.0, 0.0 if _swipe.dir < 0 else view_w)
	_swipe["dx"] = dx
	var cur: Control = _swipe.get("cur", null)
	if cur != null and is_instance_valid(cur):
		cur.position.x = eff
	if nb != null and is_instance_valid(nb):
		nb.position.x = float(_swipe.neighbor_base_x) + eff

# Lock the swipe direction and build the neighbour preview (or none, at the first/last page).
func _swipe_begin(dx: float) -> void:
	var dir := -1 if dx < 0.0 else 1        # -1 = dragging left (reveal NEXT), +1 = right (reveal PREV)
	var nz := _neighbor_z(_map_idx, dx)
	var view_w: float = get_viewport_rect().size.x
	var neighbor: Control = null
	var base_x := 0.0
	if nz >= 0 and nz < G.MAPS.size() and map_unlocked(nz):
		base_x = -float(dir) * view_w       # NEXT enters from the right (+w), PREV from the left (-w)
		neighbor = _build_page_node(nz, content, false)
		neighbor.position.x = base_x
	_swipe = {
		"active": true, "dir": dir, "cur": _page_cur,
		"neighbor": neighbor, "neighbor_z": nz, "neighbor_base_x": base_x,
		"dx": 0.0, "vel": _swipe.get("vel", 0.0), "settling": false,
	}

# Release: commit to the neighbour or spring back, on a short ease-out tween.
func _swipe_release() -> void:
	var view_w: float = get_viewport_rect().size.x
	var dx := float(_swipe.get("dx", 0.0))
	var vel := float(_swipe.get("vel", 0.0))
	var cur: Control = _swipe.get("cur", null)
	var nb: Control = _swipe.get("neighbor", null)
	var dir: int = _swipe.get("dir", 0)
	var dest_z: int = _swipe.get("neighbor_z", _map_idx)
	var base_x := float(_swipe.get("neighbor_base_x", 0.0))
	var commit := _swipe_commit(dx, vel, view_w, nb != null and is_instance_valid(nb))
	_swipe["settling"] = true
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_swipe_tween = tw
	if commit:
		tw.tween_property(nb, "position:x", 0.0, SWIPE_SNAP)
		if cur != null and is_instance_valid(cur):
			tw.tween_property(cur, "position:x", float(dir) * view_w, SWIPE_SNAP)
		Audio.play("button_tap", -4.0)
		tw.finished.connect(func() -> void:
			_swipe = {}
			_swipe_tween = null
			_open_map(dest_z, false)          # rebuild the destination as the real interactive page
		, CONNECT_ONE_SHOT)
	else:
		if cur != null and is_instance_valid(cur):
			tw.tween_property(cur, "position:x", 0.0, SWIPE_SNAP)
		if nb != null and is_instance_valid(nb):
			tw.tween_property(nb, "position:x", base_x, SWIPE_SNAP)
		tw.finished.connect(func() -> void:
			if nb != null and is_instance_valid(nb):
				nb.queue_free()
			_swipe = {}
			_swipe_tween = null
		, CONNECT_ONE_SHOT)
```

- [ ] **Step 6: Cancel an in-flight swipe on viewport resize**

In `_relayout_after_resize`, after the `_last_view_size = sz` line and before the `if _view == "map":` block, add:

```gdscript
	# a viewport change mid-swipe invalidates the slide geometry — cancel it; the rebuild re-fits.
	if _swipe_tween != null and _swipe_tween.is_valid():
		_swipe_tween.kill()
	_swipe_tween = null
	_swipe = {}
```

- [ ] **Step 7: Run tests to verify they pass**

Run:
```bash
cd /Users/xup/dh/wt-swipe-scene && make test-grove
```
Expected: PASS — commit advances `_map_idx` and persists `last_map`; a short swipe springs back and frees the preview; a first-page edge swipe is a no-op; and `_test_home_tap_unlocks_cluster` (Task 2) stays green (the gesture did not eat taps).

- [ ] **Step 8: Run the full sweep**

Run:
```bash
cd /Users/xup/dh/wt-swipe-scene && make test
```
Expected: PASS — every suite (engine + grove) green in the per-suite timing table.

- [ ] **Step 9: Commit**

```bash
cd /Users/xup/dh/wt-swipe-scene && git add engine/scripts/scenes/map.gd games/grove/tests/grove_explore_tests.gd && git commit -m "Swipe: finger-following slide to change the home scene

Horizontal drag on the home view previews the adjacent scene, follows
the finger, and snaps to next/prev past a third of the width (or a
flick), else springs back. Edges resist; resize cancels. _open_map
gains an animate flag so a committed swipe rebuilds without a pop.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage:**
- Render restructure (`_build_page_node`, interactive vs preview) → Task 2. ✓
- Arrows removed → Task 2 (delete `_add_page_arrows` + call site + doc line). ✓
- Gesture: activation, direction, live follow, edge resistance → Task 3 (`_swipe_move` / `_swipe_begin`). ✓
- Commit/cancel with tween + rebuild via `_open_map(z, false)` → Task 3 (`_swipe_release`, `_open_map` flag). ✓
- Gating parity (`map_unlocked`, no wrap) → Task 3 (`_swipe_begin` bounds + `map_unlocked` check). ✓
- Fling assist + distance threshold → Task 1 (`_swipe_commit`), wired in Task 3. ✓
- Resize-cancel → Task 3 (`_relayout_after_resize`). ✓
- Isolation (only scene art slides; chrome/weather are siblings of `content`) → inherent; verified by "single page node" assertions. ✓
- Tests: pure logic, arrows-gone, commit, cancel, edge, tap-preserved → Tasks 1–3. ✓

**2. Placeholder scan:** No TBD/TODO; every code step shows complete code; every command has an expected result. ✓

**3. Type consistency:** `_neighbor_z`, `_swipe_commit`, `_build_page_node`, `_page_cur`, `_swipe`, `_swipe_tween`, `SWIPE_*` are named identically across the tasks that define and consume them. `_open_map(z, animate := true)` matches its Task 3 call `_open_map(dest_z, false)`. Test helpers `_swipe_touch` / `_swipe_drag` are defined once (Task 3) and used only there. ✓

## Risk notes (for the executor)

- **Headless tweens:** the commit/cancel tests wait `create_timer(0.4)` for the `SWIPE_SNAP` (0.22s) tween to finish and fire `finished`. Tweens on an in-tree node advance during that wait under the headless SceneTree. If a commit test ever shows `_map_idx` unchanged, first confirm the tween finished (lengthen the timer) before suspecting the handler.
- **Viewport width in tests:** thresholds are expressed as fractions of `get_viewport_rect().size.x`, so tests are width-agnostic. The one absolute value (the 40px cancel drag) only needs `12 < 40 < view_w/3`, true for any realistic viewport.
