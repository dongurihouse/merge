# Content-Derived Level Gates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Derive the cover-up cluster level floors and the zone unlock cadence from the cluster COST ladder through the coin curve, so the content arc and the restoration arc can no longer drift apart.

**Architecture:** `content.gd` gains one cached derivation — walk the 25 clusters in global order, accumulate their `cost`, and run each cumulative total through `level_at_coins()`. That yields (a) a level floor per cluster and (b) a completion level per scene. Each scene's completion level closes its **level window**; `ZONE_BAND [2,3,3,2,2]` spreads that scene's zones evenly inside its own window. The two hand-authored tables — `ZONE_UNLOCK_LEVEL` and `CLUSTER_LEVEL_STEP` — are deleted. The cache key is the dials it depends on, so a live `apply_tuning()` or a test poking `LEVEL_BASE_COINS` can never leave a stale table behind.

**Tech Stack:** Godot 4.6 / GDScript. Headless SceneTree test suites run by `engine/tools/run_suites.py` via `make test-fast` / `make test`.

## Global Constraints

- **Worktree:** all work happens in `/Users/xup/dh/wt-content-derived-curve` on branch `content-derived-curve`. Main-tree edits are blocked by a PreToolUse hook.
- **Spec:** `docs/superpowers/specs/2026-07-25-content-derived-level-gates-design.md`.
- **The clock stays quests-only.** Do not touch `_earn_coins`, `Save.earn_coins`, or any coin-income routing. grove_sim invariant Y must still pass.
- **Do not re-tune `LEVEL_BASE_COINS` (30) or `LEVEL_STEP_COINS` (12).** The curve's scale is out of scope; only the gates change.
- **Do not re-tune the per-cluster `cost` fields, `LEVEL_WATER_GIFT` (40), or `LEVEL_DIAMONDS` (3).** Measure and report only.
- **`CLUSTER_LEVEL_LEAD` ships at `1.0`** (floors non-binding by construction).
- After **every** change run `make test-fast` before anything else. Run the full `make test` before handoff.
- Run `make import` before committing any new `.gd` file so its `.uid` is generated (an untracked, later-regenerated `.uid` aborts the branch→main merge).
- Godot suites are headless: `godot --headless --path . -s res://<suite>.gd`. Run them in the FOREGROUND.

### The numbers this plan produces

These are the expected outputs at the shipped curve (30/12). They are asserted in Task 1–3 and reported in Task 4.

Cumulative cluster cost and the derived floor, in global order:

| scene | clusters | scene cost | cumulative | derived floors |
|---|---|---|---|---|
| Fairy Hollow | 6 | 420 | 420 | L1 L2 L3 L4 L5 L7 |
| Snowy Village | 5 | 2,100 | 2,520 | L9 L11 L14 L16 L19 |
| Desert Oasis | 5 | 6,220 | 8,740 | L22 L25 L29 L33 L37 |
| Coral Reef | 5 | 15,000 | 23,740 | L41 L46 L51 L56 L61 |
| Cherry Blossom | 4 | 23,000 | 46,740 | L67 L73 L80 L87 |

Scene level windows: `L1–7 · L8–19 · L20–37 · L38–61 · L62–87`

Derived cadence: `ZONE_UNLOCK_LEVEL = [1, 5, 8, 12, 16, 20, 26, 32, 38, 50, 62, 75]`
(was the hand-authored `[1, 5, 10, 12, 15, 17, 19, 22, 23, 27, 30, 34]`)

---

## File Structure

- `games/grove/grove_data.gd` — delete `ZONE_UNLOCK_LEVEL` and `CLUSTER_LEVEL_STEP`; add `CLUSTER_LEVEL_LEAD`. Stays the authored-data file: cluster costs and `ZONE_BAND` remain here.
- `engine/scripts/core/content.gd` — owns the derivation. New private cache (`_cadence`, `_cadence_key`, `_build_cadence`, `_cadence_table`), new public queries (`cumulative_cluster_cost`, `scene_level_window`, `zone_unlock_levels`), rewritten `cluster_min_level` and `zone_unlock_level`, and two internal call sites that indexed the deleted const.
- `engine/tests/scene_cells_tests.gd` — cluster-floor derivation tests (it already exercises `cluster_min_level`).
- `engine/tests/mechanics_tests.gd` — cadence tests; the level-by-level arc table becomes a per-zone range table.
- `engine/tests/tuning_tests.gd` — the dial-independence guard (it already owns dial overrides and their restore).
- `games/grove/tests/grove_board_actions_tests.gd` — generator-retirement levels, which derive from the cadence.
- `games/grove/tools/grove_sim.gd` — per-scene pacing report; two reads of the deleted const.

---

## The level-keyed reads, enumerated

The spec requires confirming that every level-keyed read is intentional under the new gates. This is the
complete set (`grep -rn "cluster_min_level\|zone_unlock_level\|quest_zone_for_level\|MIN_LEVEL"`), with the
verdict for each. No task changes these; the list exists so a reviewer can check the reasoning.

| read | what it gates | under the derived gates | verdict |
|---|---|---|---|
| `MIN_LEVEL` (`grove_data:81`, via `cell_min_level`) | board cells unseal at L1–L22 | unchanged in level terms, but L22 now falls at cluster 11 (Desert Oasis *opening*) instead of cluster 15 (Desert *finishing*) — the board fully opens a little earlier relative to the scenes | **intentional**; the board should be fully open well before the long back half. Report it, do not re-tune. |
| `quest_zone_for_level` (`content:435`) | which zones the fence asks from | reads the derived cadence | correct by construction |
| `line_gated_out` / `zone_line_locked` (`content:334`) | save migration strips out-of-cadence items | reads `zone_unlock_level` | correct by construction |
| `gen_retirable` (`content:417`) | when a generator can be retired | boundaries move with the cadence; Task 2 Step 10 re-derives its tests | correct by construction |
| `cluster_ready` (`content:1084`) | the padlock | level floor now non-binding at `CLUSTER_LEVEL_LEAD = 1.0` | **intentional** — this is the design |
| `map.gd:1843` (`need_lvl`) | the "reach L*n*" label on a locked cluster | shows a much higher number late, and nothing for cluster 0 (floor L1) | **intentional**; verify the label reads sensibly when the floor is already met |
| `debug.gd:291` | debug readout of coins needed for the next cluster | follows automatically | fine |

---

### Task 1: Derive the cluster level floors from the cost ladder

**Files:**
- Modify: `games/grove/grove_data.gd:163-166` (replace `CLUSTER_LEVEL_STEP` with `CLUSTER_LEVEL_LEAD`)
- Modify: `engine/scripts/core/content.gd:33` (the const alias)
- Modify: `engine/scripts/core/content.gd:1062-1068` (`cluster_min_level` + the new cache)
- Test: `engine/tests/scene_cells_tests.gd`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `Content.cumulative_cluster_cost(global_index: int) -> int`
  - `Content.scene_level_window(page_order_index: int) -> Vector2i` (`x` = first level, `y` = last level, inclusive)
  - `Content._cadence_table() -> Dictionary` with keys `floors: Array[int]` (per global cluster index), `scene_end: Array[int]` (per cover-up page, in `coverup_pages()` order), `zones: Array[int]` (filled in Task 2; `[]` here)
  - `Content.cluster_min_level(z: int, cluster_id: String) -> int` — unchanged signature, derived body

- [ ] **Step 1: Write the failing test**

Add this function to `engine/tests/scene_cells_tests.gd`, immediately above `func _initialize() -> void:`:

```gdscript
# The cluster level floors are DERIVED from the cost ladder: a cluster's floor is the level a
# player stands at once they have EARNED what the ladder has cost up to and including it. No
# hand-authored level table, so the floors can never drift off the costs.
func _test_derived_cluster_floors() -> void:
	var pages := Content.coverup_pages()
	ok(pages.size() == 5, "the book has 5 cover-up scenes")

	# cumulative cost walks the clusters in GLOBAL order
	ok(Content.cumulative_cluster_cost(0) == 10, "cumulative cost at cluster 0 is the first cluster's cost")
	ok(Content.cumulative_cluster_cost(5) == 420, "cumulative cost through Fairy Hollow is 420")
	ok(Content.cumulative_cluster_cost(24) == 46740, "the whole ladder costs 46740 coins")
	ok(Content.cumulative_cluster_cost(999) == 46740, "an out-of-range index clamps to the whole ladder")

	# every floor equals level_at_coins of its own cumulative cost
	var i := 0
	var derived_ok := true
	var floors: Array = []
	for z in pages:
		for c in Content.clusters(int(z)):
			var id := String((c as Dictionary).id)
			var want := Content.level_at_coins(Content.cumulative_cluster_cost(i))
			if Content.cluster_min_level(int(z), id) != want:
				derived_ok = false
			floors.append(Content.cluster_min_level(int(z), id))
			i += 1
	ok(i == 25, "the ladder has 25 clusters")
	ok(derived_ok, "every cluster floor == level_at_coins(its cumulative cost)")
	ok(floors == [1, 2, 3, 4, 5, 7, 9, 11, 14, 16, 19, 22, 25, 29, 33, 37, 41, 46, 51, 56, 61, 67, 73, 80, 87],
		"the derived floor ladder at the shipped curve (got %s)" % str(floors))

	# non-decreasing: a later cluster is never cheaper in level terms than an earlier one
	var mono := true
	for j in range(1, floors.size()):
		if int(floors[j]) < int(floors[j - 1]):
			mono = false
	ok(mono, "the floor ladder is non-decreasing")

	# scene windows close at each scene's completion level
	ok(Content.scene_level_window(0) == Vector2i(1, 7), "Fairy Hollow spans L1-7")
	ok(Content.scene_level_window(1) == Vector2i(8, 19), "Snowy Village spans L8-19")
	ok(Content.scene_level_window(2) == Vector2i(20, 37), "Desert Oasis spans L20-37")
	ok(Content.scene_level_window(3) == Vector2i(38, 61), "Coral Reef spans L38-61")
	ok(Content.scene_level_window(4) == Vector2i(62, 87), "Cherry Blossom spans L62-87")
```

And register it in `_initialize()`:

```gdscript
func _initialize() -> void:
	print("== scene-derived habitat cells (content queries) ==")
	_test_cells_from_scenes()
	_test_any_cluster_ready()
	_test_derived_cluster_floors()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/xup/dh/wt-content-derived-curve && godot --headless --path . -s res://engine/tests/scene_cells_tests.gd
```

Expected: parse error / FAIL — `cumulative_cluster_cost` and `scene_level_window` do not exist.

- [ ] **Step 3: Replace the grove dial**

In `games/grove/grove_data.gd`, replace lines 163-166 (the `CLUSTER_LEVEL_STEP` block) with:

```gdscript
# §8 the cover-up CLUSTER ladder's level floors are DERIVED, not spaced by a dial: a cluster's floor is
# level_at_coins(cumulative cost of the ladder through it), so the floor and the price arrive together and
# the scene ladder cannot drift off the coin curve. CLUSTER_LEVEL_STEP is retired with the hand-spacing.
# This dial biases the derivation: < 1.0 makes the padlock LEAD affordability (level first, then save for
# the coins), > 1.0 makes it LAG (coins held, level not yet reached). 1.0 = floors never bind.
const CLUSTER_LEVEL_LEAD := 1.0
```

- [ ] **Step 4: Re-alias it in content.gd**

In `engine/scripts/core/content.gd`, replace line 33:

```gdscript
const CLUSTER_LEVEL_STEP = D.CLUSTER_LEVEL_STEP   # §8 cluster-ladder level spacing (paired with ZONE_UNLOCK_LEVEL)
```

with:

```gdscript
const CLUSTER_LEVEL_LEAD = D.CLUSTER_LEVEL_LEAD   # §8 bias on the DERIVED cluster floors (1.0 = never binding)
```

- [ ] **Step 5: Write the derivation**

In `engine/scripts/core/content.gd`, replace the `cluster_min_level` block (lines 1062-1068 — the four comment lines starting `# The LEVEL at which a cluster unlocks` plus the function) with:

```gdscript
# --- THE DERIVED PACING SPINE (2026-07-25) ------------------------------------------------------------
# The cluster level floors and the zone unlock cadence are DERIVED from the cluster COST ladder through
# the coin curve — they are not authored in level-space. A cluster's floor is the level the player stands
# at once they have EARNED what the ladder has cost through it, so the floor and the price land together.
# Each scene's completion level closes its LEVEL WINDOW, and ZONE_BAND spreads that scene's zones inside
# it, which makes scene alignment arithmetic instead of a hand-maintained invariant.
#
# Cached against the dials it reads (the curve + the authored costs), so a live apply_tuning() — or a test
# assigning LEVEL_BASE_COINS directly — invalidates it automatically. There is no rebuild to remember.
static var _cadence: Dictionary = {}
static var _cadence_key: String = ""

static func _cadence_table() -> Dictionary:
	var total := 0
	var n := 0
	for z in coverup_pages():
		for c in clusters(int(z)):
			total += int((c as Dictionary).get("cost", 0))
			n += 1
	var key := "%d/%d/%d/%d" % [LEVEL_BASE_COINS, LEVEL_STEP_COINS, n, total]
	if key != _cadence_key or _cadence.is_empty():
		_cadence = _build_cadence()
		_cadence_key = key
	return _cadence

static func _build_cadence() -> Dictionary:
	var floors: Array = []
	var scene_end: Array = []
	var cum := 0
	for z in coverup_pages():
		for c in clusters(int(z)):
			cum += int((c as Dictionary).get("cost", 0))
			floors.append(level_at_coins(int(round(float(cum) * float(CLUSTER_LEVEL_LEAD)))))
		scene_end.append(level_at_coins(cum))
	return {"floors": floors, "scene_end": scene_end, "zones": []}

## The coins the cluster ladder has cost through global index `i`, inclusive. Clamps at both ends,
## so an out-of-range index reads the whole ladder's cost.
static func cumulative_cluster_cost(i: int) -> int:
	var cum := 0
	var idx := 0
	for z in coverup_pages():
		for c in clusters(int(z)):
			cum += int((c as Dictionary).get("cost", 0))
			if idx >= int(i):
				return cum
			idx += 1
	return cum

## The LEVEL WINDOW of the `p`-th cover-up scene (in coverup_pages() order): x = its first level,
## y = the level at which it completes. Scene 0 opens at L1; every later scene opens one level past
## the previous scene's completion.
static func scene_level_window(p: int) -> Vector2i:
	var ends: Array = _cadence_table()["scene_end"]
	if ends.is_empty():
		return Vector2i(1, 1)
	var i := clampi(int(p), 0, ends.size() - 1)
	var first := 1 if i == 0 else int(ends[i - 1]) + 1
	return Vector2i(first, int(ends[i]))

# The LEVEL at which a cluster unlocks — DERIVED (see above): level_at_coins of the ladder's cumulative
# cost through it, biased by CLUSTER_LEVEL_LEAD. At lead 1.0 the floor is non-binding by construction:
# the player reaches the level at about the moment they can afford the cluster.
static func cluster_min_level(z: int, cluster_id: String) -> int:
	var floors: Array = _cadence_table()["floors"]
	var i := global_cluster_index(z, cluster_id)
	if i < 0 or i >= floors.size():
		return 1
	return int(floors[i])
```

- [ ] **Step 6: Run the test to verify it passes**

```bash
cd /Users/xup/dh/wt-content-derived-curve && godot --headless --path . -s res://engine/tests/scene_cells_tests.gd
```

Expected: `== N passed, 0 failed ==`.

- [ ] **Step 7: Run the fast sweep**

```bash
cd /Users/xup/dh/wt-content-derived-curve && make test-fast
```

Expected: every engine suite passes. If `mechanics_tests` or `quest_fence_tests` fail here, they are failing on the *cadence*, not the floors — that is Task 2's fallout; note it and continue only if the failures name `ZONE_UNLOCK_LEVEL`. Any failure naming a cluster floor is Task 1's and must be fixed now.

- [ ] **Step 8: Commit**

```bash
cd /Users/xup/dh/wt-content-derived-curve && git add -A && git commit -m "feat(pacing): derive the cluster level floors from the cost ladder

cluster_min_level was 2 + round(global_index x CLUSTER_LEVEL_STEP) -- a
hand-spaced table that had drifted off the coins the ladder demands. The last
cluster's floor read L34 = 7,326 earned coins while the ladder costs 46,740.

It is now level_at_coins(cumulative cost through that cluster): the floor and
the price arrive together. CLUSTER_LEVEL_STEP is retired; CLUSTER_LEVEL_LEAD
(default 1.0) biases the derivation if the padlock should lead or lag.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Derive the zone unlock cadence from the scene windows

**Files:**
- Modify: `engine/scripts/core/content.gd:31` (delete the `ZONE_UNLOCK_LEVEL` const alias)
- Modify: `engine/scripts/core/content.gd` (`_build_cadence` fills `zones`; new `zone_unlock_levels()`; rewrite `zone_unlock_level`; two internal call sites at lines 419 and 438)
- Modify: `games/grove/grove_data.gd:136-158` (delete the authored `ZONE_UNLOCK_LEVEL` and its comment block)
- Modify: `engine/tests/mechanics_tests.gd:654, 664-720`
- Modify: `engine/tests/quest_fence_tests.gd:341`
- Modify: `games/grove/tests/grove_board_actions_tests.gd:249-251, 254, 259`

**Interfaces:**
- Consumes: `Content._cadence_table()`, `Content.scene_level_window(p)` from Task 1.
- Produces:
  - `Content.zone_unlock_levels() -> Array` (a copy of the 12-entry cadence)
  - `Content.zone_unlock_level(z: int) -> int` — unchanged signature, derived body

- [ ] **Step 1: Write the failing test**

In `engine/tests/mechanics_tests.gd`, replace the cadence assertions at lines 688-699 (from the comment `# the ZONE ladder rides the data-driven ZONE_UNLOCK_LEVEL cadence` through the `arc_finish_threshold` line) with:

```gdscript
	# THE ZONE CADENCE IS DERIVED (2026-07-25): each scene's LEVEL WINDOW comes from the cluster cost
	# ladder, and ZONE_BAND spreads that scene's zones evenly inside its own window. Scene alignment is
	# arithmetic now, not a hand-maintained invariant — these assertions are what hold it.
	var _cad := G.zone_unlock_levels()
	ok(_cad.size() == G.ZONE_COUNT, "the cadence has one level per zone")
	ok(_cad == [1, 5, 8, 12, 16, 20, 26, 32, 38, 50, 62, 75], "the derived cadence at the shipped curve (got %s)" % str(_cad))
	ok(G.zone_unlock_level(0) == int(_cad[0]) and G.zone_unlock_level(G.ZONE_COUNT - 1) == int(_cad[G.ZONE_COUNT - 1]), "zone_unlock_level reads the derived cadence")
	var _cad_ok := true
	for _z in range(1, G.ZONE_COUNT):
		if int(_cad[_z]) <= int(_cad[_z - 1]):
			_cad_ok = false
	ok(_cad_ok, "the cadence is strictly increasing (each zone unlocks after the last)")
	# SCENE ALIGNMENT: zone z's line must arrive while its OWN scene is the one being unlocked. ZONE_BAND
	# says how many zones belong to each scene; every one of them must land inside that scene's window.
	var _zi := 0
	var _aligned := true
	for _p in G.ZONE_BAND.size():
		var _win := G.scene_level_window(int(_p))
		for _j in int(G.ZONE_BAND[_p]):
			var _lv := int(_cad[_zi])
			# zone 0 is the anchor: pinned to L1, which is scene 0's window start anyway
			if _lv < int(_win.x) or _lv > int(_win.y):
				_aligned = false
			_zi += 1
	ok(_zi == G.ZONE_COUNT, "ZONE_BAND accounts for every zone")
	ok(_aligned, "every zone unlocks inside its OWN scene's level window (scene alignment)")
	ok(G.zone_threshold(0) == G.coins_at_level(int(_cad[0])), "zone 0's threshold is its unlock-level coin threshold")
	ok(G.arc_finish_threshold() == G.zone_threshold(G.ZONE_COUNT - 1), "the arc finishes at the last zone's threshold")
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/xup/dh/wt-content-derived-curve && godot --headless --path . -s res://engine/tests/mechanics_tests.gd
```

Expected: FAIL — `zone_unlock_levels` does not exist.

- [ ] **Step 3: Fill the cadence in the derivation**

In `engine/scripts/core/content.gd`, replace the `_build_cadence` body written in Task 1 with:

```gdscript
static func _build_cadence() -> Dictionary:
	var floors: Array = []
	var scene_end: Array = []
	var cum := 0
	for z in coverup_pages():
		for c in clusters(int(z)):
			cum += int((c as Dictionary).get("cost", 0))
			floors.append(level_at_coins(int(round(float(cum) * float(CLUSTER_LEVEL_LEAD)))))
		scene_end.append(level_at_coins(cum))
	# Each scene's ZONE_BAND zones spread evenly inside that scene's own LEVEL WINDOW, so a zone's line
	# always arrives while its themed scene is the one being unlocked.
	var zones: Array = []
	var win_start := 1
	for i in scene_end.size():
		var win_end := int(scene_end[i])
		var k := int(ZONE_BAND[i]) if i < ZONE_BAND.size() else 0
		var span := maxi(1, win_end + 1 - win_start)
		for j in k:
			zones.append(maxi(1, win_start + int(round(float(j) * float(span) / float(k)))))
		win_start = win_end + 1
	if not zones.is_empty():
		zones[0] = 1        # zone 0 is the anchor line — askable from the first tap
	for i2 in range(1, zones.size()):     # a degenerate window could repeat a level; the inverse must be monotonic
		if int(zones[i2]) <= int(zones[i2 - 1]):
			zones[i2] = int(zones[i2 - 1]) + 1
	return {"floors": floors, "scene_end": scene_end, "zones": zones}
```

- [ ] **Step 4: Rewrite the zone queries**

In `engine/scripts/core/content.gd`, replace `zone_unlock_level` (lines 1497-1502 — the comment block and the function) with:

```gdscript
## The LEVEL zone z's line + generator unlock — DERIVED from the scene windows (2026-07-25): each scene's
## window comes from the cluster cost ladder, and ZONE_BAND spreads its zones inside it. Was a hand-authored
## ZONE_UNLOCK_LEVEL table in grove_data, which had drifted to L1-34 while the ladder ran to L87 — every item
## line shipped by the middle of scene 3. Its coins_at_level(...) is the zone_threshold below.
static func zone_unlock_level(z: int) -> int:
	var zones: Array = _cadence_table()["zones"]
	if zones.is_empty():
		return 1
	return int(zones[clampi(z, 0, zones.size() - 1)])

## The whole derived cadence, one level per zone in play order (a copy — mutating it changes nothing).
static func zone_unlock_levels() -> Array:
	return (_cadence_table()["zones"] as Array).duplicate()
```

- [ ] **Step 5: Update the two internal call sites and delete the const**

In `engine/scripts/core/content.gd` line 419, replace:

```gdscript
		if needed_gens(int(ZONE_UNLOCK_LEVEL[z])).has(gid):
```

with:

```gdscript
		if needed_gens(zone_unlock_level(int(z))).has(gid):
```

In `engine/scripts/core/content.gd` line 438, replace:

```gdscript
		if int(level) >= int(ZONE_UNLOCK_LEVEL[i]):
```

with:

```gdscript
		if int(level) >= zone_unlock_level(int(i)):
```

Then delete line 31 entirely:

```gdscript
const ZONE_UNLOCK_LEVEL = D.ZONE_UNLOCK_LEVEL   # §7 per-zone unlock LEVEL — the progression cadence dial
```

- [ ] **Step 6: Delete the authored table from grove_data**

In `games/grove/grove_data.gd`, delete the whole block from the comment starting `# §7 ZONE UNLOCK CADENCE (2026-07-23, owner call)` through the line `#  generator (base zones): 1     2   3   4  (5*)  6   7  (8*) 16  (17*) 18 (19*)   * = crafted special, no gen` (lines 136-158, which includes `const ZONE_UNLOCK_LEVEL := [...]` and the STRETCHED note), and put this in its place:

```gdscript
# §7 ZONE UNLOCK CADENCE — DERIVED, not authored (2026-07-25). content.zone_unlock_level(z) computes it:
# each scene's LEVEL WINDOW falls out of the cluster COST ladder (level_at_coins of the cumulative cost),
# and ZONE_BAND spreads that scene's zones evenly inside its own window. So a generator still arrives as
# its themed scene comes into view, but the alignment is arithmetic and cannot drift.
# The dials that move this are the COIN CURVE (LEVEL_BASE_COINS / LEVEL_STEP_COINS), the per-cluster
# `cost` fields in MAPS, and ZONE_BAND. The old hand-authored table (last value [1,5,10,12,15,17,19,22,
# 23,27,30,34], stretched by hand on 2026-07-25) topped out at L34 = 7,326 earned coins while the ladder
# costs 46,740 — every item line shipped by the middle of scene 3, with 2.5 scenes left to restore.
```

- [ ] **Step 7: Run the cadence test to verify it passes**

```bash
cd /Users/xup/dh/wt-content-derived-curve && godot --headless --path . -s res://engine/tests/mechanics_tests.gd
```

Expected: the new cadence assertions PASS. The **arc table** assertions further up will still FAIL — they enumerate L1–L34 against the old cadence. Fix them in Step 8.

- [ ] **Step 8: Re-derive the arc table as a per-zone range table**

In `engine/tests/mechanics_tests.gd`, replace the whole `_arc` literal and its loop (lines 664-680 — from the comment `# THE SHIPPED ARC TABLE, level by level` through `ok(G.active_lines(0) == [1], ...)`) with:

```gdscript
	# THE SHIPPED ARC TABLE (the owner-facing view of the cadence × the window). One row per zone: the
	# LEVEL RANGE that zone owns, and the 3 lines the fence asks from across it. Re-tuning the coin curve
	# or the cluster costs SHOULD break this — update it here so the arc stays reviewable in one place.
	var _arc := [
		[ 1,  4, [1]],            # z0  Fairy Hollow — the anchor line alone
		[ 5,  7, [1, 2]],         # z1
		[ 8, 11, [1, 2, 3]],      # z2  Snowy Village opens
		[12, 15, [2, 3, 4]],      # z3
		[16, 19, [3, 4, 5]],      # z4  winter berries (special)
		[20, 25, [4, 5, 6]],      # z5  Desert Oasis opens
		[26, 31, [5, 6, 7]],      # z6
		[32, 37, [6, 7, 8]],      # z7  spices (special)
		[38, 49, [7, 8, 16]],     # z8  Coral Reef opens
		[50, 61, [8, 16, 17]],    # z9  corals (special)
		[62, 74, [16, 17, 18]],   # z10 Cherry Blossom opens
		[75, 90, [17, 18, 19]],   # z11 tea cups (special) — the final window, held forever
	]
	var _arc_ok := true
	var _arc_bad := ""
	for _row in _arc:
		for _lv in range(int(_row[0]), int(_row[1]) + 1):
			if G.active_lines(int(_lv)) != _row[2]:
				_arc_ok = false
				if _arc_bad == "":
					_arc_bad = "L%d asks %s, expected %s" % [_lv, str(G.active_lines(int(_lv))), str(_row[2])]
	ok(_arc_ok, "the arc table holds at every level L1-L90 (%s)" % ("ok" if _arc_ok else _arc_bad))
	ok(int(_arc[0][0]) == 1 and G.active_lines(0) == [1], "a below-first-threshold level clamps to the anchor line")
```

- [ ] **Step 9: Re-derive the two remaining const reads**

In `engine/tests/mechanics_tests.gd` line 654, replace:

```gdscript
	var _top_lv := int(G.ZONE_UNLOCK_LEVEL[G.ZONE_COUNT - 1])
```

with:

```gdscript
	var _top_lv := G.zone_unlock_level(G.ZONE_COUNT - 1)
```

Further down, in the two loops that read the cadence per zone (lines 708 and 714), replace:

```gdscript
		var _ul := int(G.ZONE_UNLOCK_LEVEL[_z])
```

with:

```gdscript
		var _ul := G.zone_unlock_level(int(_z))
```

and:

```gdscript
		var _ul2 := int(G.ZONE_UNLOCK_LEVEL[_z2])
```

with:

```gdscript
		var _ul2 := G.zone_unlock_level(int(_z2))
```

In `engine/tests/quest_fence_tests.gd` line 341, replace:

```gdscript
	var second_zone_level := int(G.ZONE_UNLOCK_LEVEL[1])
```

with:

```gdscript
	var second_zone_level := G.zone_unlock_level(1)
```

- [ ] **Step 10: Re-derive the generator-retirement levels**

A generator retires the level after the last window that still needs it. Under the derived cadence those levels move. In `games/grove/tests/grove_board_actions_tests.gd`, replace lines 249-251:

```gdscript
	ok(not G.gen_retirable("gen_1", 11) and G.gen_retirable("gen_1", 12), "the anchor line retires the level after it is last needed (L11 -> L12)")
	ok(not G.gen_retirable("gen_6", 22) and G.gen_retirable("gen_6", 23), "desert fruits retires past L22")
	ok(not G.gen_retirable("gen_16", 33) and G.gen_retirable("gen_16", 34), "shells retires past L33")
```

with (each boundary DERIVED from the cadence, so a re-tune moves them together):

```gdscript
	# Each retirement boundary is the level at which the generator's line leaves the window for good —
	# derived from the cadence so a curve or cost re-tune moves these with it, never stale.
	var _z3 := G.zone_unlock_level(3)     # zone 3 opens -> line 1 (zone 0) has left the 3-line window
	ok(not G.gen_retirable("gen_1", _z3 - 1) and G.gen_retirable("gen_1", _z3), "the anchor line retires the level after it is last needed (L%d -> L%d)" % [_z3 - 1, _z3])
	var _z8 := G.zone_unlock_level(8)     # zone 8 opens -> line 6 (zone 5) has left the window
	ok(not G.gen_retirable("gen_6", _z8 - 1) and G.gen_retirable("gen_6", _z8), "desert fruits retires past L%d" % (_z8 - 1))
	var _z11 := G.zone_unlock_level(11)   # zone 11 opens -> line 16 (zone 8) has left the window
	ok(not G.gen_retirable("gen_16", _z11 - 1) and G.gen_retirable("gen_16", _z11), "shells retires past L%d" % (_z11 - 1))
```

At line 254, replace:

```gdscript
		for _lv in range(1, int(G.ZONE_UNLOCK_LEVEL[G.ZONE_COUNT - 1]) + 20):
```

with:

```gdscript
		for _lv in range(1, G.zone_unlock_level(G.ZONE_COUNT - 1) + 20):
```

At line 259, replace the hardcoded L30 dormancy check:

```gdscript
	ok(not G.active_lines(30).has(4) and not G.gen_retirable("gen_4", 30), "woolens is out of the L30 window yet still NOT retirable — tea cups needs it at L34")
```

with:

```gdscript
	var _dormant := G.zone_unlock_level(10)   # Cherry Blossom's first zone: the window is [16,17,18], no woolens
	ok(not G.active_lines(_dormant).has(4) and not G.gen_retirable("gen_4", _dormant), "woolens is out of the L%d window yet still NOT retirable — tea cups needs it at L%d" % [_dormant, G.zone_unlock_level(11)])
```

Line 260 (`G.retirable_gens(["gen_1", "gen_4", "gen_18"], 30) == ["gen_1"]`) still holds at L30 — verify, do not change it unless it fails.

- [ ] **Step 11: Run the affected suites**

```bash
cd /Users/xup/dh/wt-content-derived-curve && godot --headless --path . -s res://engine/tests/mechanics_tests.gd && godot --headless --path . -s res://engine/tests/quest_fence_tests.gd && godot --headless --path . -s res://games/grove/tests/grove_board_actions_tests.gd
```

Expected: `0 failed` from each.

- [ ] **Step 12: Run the full sweep**

```bash
cd /Users/xup/dh/wt-content-derived-curve && make test
```

Expected: every suite passes. Any remaining failure will name a level that moved — re-derive that assertion from the cadence rather than re-pinning it to a new literal.

- [ ] **Step 13: Commit**

```bash
cd /Users/xup/dh/wt-content-derived-curve && git add -A && git commit -m "feat(pacing): derive the zone unlock cadence from the scene windows

ZONE_UNLOCK_LEVEL was hand-authored and topped out at L34 = 7,326 earned coins
while the cluster ladder costs 46,740 -- every item line in the game shipped by
the middle of Desert Oasis, with 2.5 scenes left to restore. The L1-34 stretch
moved that from scene 2 to scene 3; it could not fix it, because the table's
whole range covered 16% of the coin arc.

Each scene's LEVEL WINDOW now falls out of the cluster cost ladder and ZONE_BAND
spreads its zones inside it: [1,5,8,12,16,20,26,32,38,50,62,75]. The last item
line lands 74% through the ladder instead of 16%, and scene alignment -- which
the source comments warned MUST be re-spaced by hand -- is arithmetic.

Tests re-derive every level boundary from the cadence instead of pinning it, and
the level-by-level arc table becomes a per-zone range table.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Guard the derivation against dial drift

The point of this work is that the gates can never again be authored out of step with the curve. That only holds if changing the curve provably moves both tables. This task is that guard.

**Files:**
- Modify: `engine/tests/tuning_tests.gd:28-85`

**Interfaces:**
- Consumes: `Content.zone_unlock_levels()`, `Content.scene_level_window(p)`, `Content.cluster_min_level(z, id)`, `Content.cumulative_cluster_cost(i)`.
- Produces: nothing.

- [ ] **Step 1: Write the failing test**

In `engine/tests/tuning_tests.gd`, insert this block immediately before the `# restore the live dials and verify` comment (before the `G.LEVEL_BASE_EXP = b0` line):

```gdscript
	# --- THE DERIVED GATES FOLLOW THE CURVE (2026-07-25) ---------------------------------------------
	# The cluster floors and the zone cadence are derived from the cluster COST ladder through the coin
	# curve. This is the guard that stops them being hand-authored back out of step: move the curve, and
	# BOTH tables must move with it, with scene alignment intact. The cadence cache is keyed on these
	# dials, so no explicit rebuild call exists to forget.
	var shipped_cad: Array = [1, 5, 8, 12, 16, 20, 26, 32, 38, 50, 62, 75]
	G.LEVEL_BASE_COINS = cb0
	G.LEVEL_STEP_COINS = cs0
	ok(G.zone_unlock_levels() == shipped_cad, "at the shipped curve the cadence is %s" % str(shipped_cad))
	var shipped_top := G.cluster_min_level(0, "lantern_gate")

	# HALVE the curve: every threshold is cheaper, so every gate must arrive EARLIER.
	G.LEVEL_BASE_COINS = 15
	G.LEVEL_STEP_COINS = 6
	var cheap_cad: Array = G.zone_unlock_levels()
	var cheap_top := G.cluster_min_level(0, "lantern_gate")
	ok(cheap_cad != shipped_cad, "halving the curve moves the zone cadence (no stale cache)")
	ok(cheap_cad.size() == G.ZONE_COUNT, "the moved cadence still has one level per zone")
	var cheap_rising := true
	for i in range(1, cheap_cad.size()):
		if int(cheap_cad[i]) <= int(cheap_cad[i - 1]):
			cheap_rising = false
	ok(cheap_rising, "the moved cadence is still strictly increasing")
	ok(cheap_top > shipped_top, "a cheaper curve puts Fairy Hollow's last cluster at a HIGHER level (%d > %d)" % [cheap_top, shipped_top])

	# scene alignment survives the move — this is the property that used to be hand-maintained
	var zi := 0
	var aligned := true
	for p in G.ZONE_BAND.size():
		var win := G.scene_level_window(int(p))
		for _j in int(G.ZONE_BAND[p]):
			if int(cheap_cad[zi]) < int(win.x) or int(cheap_cad[zi]) > int(win.y):
				aligned = false
			zi += 1
	ok(aligned, "every zone still lands inside its own scene's window after the curve moves")

	# the floors track level_at_coins of the cumulative cost at the MOVED curve too
	var floors_track := true
	var fi := 0
	for z in G.coverup_pages():
		for c in G.clusters(int(z)):
			if G.cluster_min_level(int(z), String((c as Dictionary).id)) != G.level_at_coins(G.cumulative_cluster_cost(fi)):
				floors_track = false
			fi += 1
	ok(floors_track, "every cluster floor still equals level_at_coins(cumulative cost) at the moved curve")
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /Users/xup/dh/wt-content-derived-curve && godot --headless --path . -s res://engine/tests/tuning_tests.gd
```

Expected: FAIL on `cheap_top > shipped_top` only if the cache is stale, and PASS otherwise. If every assertion passes on the first run, that is the correct outcome — the implementation from Tasks 1-2 already satisfies it. **Do not weaken the test to make it fail first;** its job is to be a standing guard, and a passing first run is evidence the cache key works. Record which assertions passed.

To confirm the guard actually bites, temporarily change `_cadence_table()`'s key to the constant `"x"`, re-run, and observe the failure. Then revert that edit.

- [ ] **Step 3: Confirm the restore leaves the live dials clean**

The block above assigns `G.LEVEL_BASE_COINS` / `G.LEVEL_STEP_COINS` directly, and the existing restore below it sets them back to `cb0` / `cs0`. Verify the suite's final assertion still passes and add one more line immediately after the existing `ok(G.exp_at_level(3) == b0 * 2 + s0, ...)`:

```gdscript
	ok(G.zone_unlock_levels() == shipped_cad, "the derived cadence is back to the shipped table after the suite restores the dials")
```

- [ ] **Step 4: Run the suite to verify it passes**

```bash
cd /Users/xup/dh/wt-content-derived-curve && godot --headless --path . -s res://engine/tests/tuning_tests.gd
```

Expected: `0 failed`.

- [ ] **Step 5: Run the fast sweep**

```bash
cd /Users/xup/dh/wt-content-derived-curve && make test-fast
```

Expected: every engine suite passes.

- [ ] **Step 6: Commit**

```bash
cd /Users/xup/dh/wt-content-derived-curve && git add -A && git commit -m "test(pacing): guard that the derived gates follow the curve

Move LEVEL_BASE_COINS/LEVEL_STEP_COINS and assert BOTH derived tables move with
it -- cadence, cluster floors, and scene alignment intact -- and that restoring
the dials restores the tables. The cadence cache is keyed on the dials it reads,
so there is no rebuild call to forget; this test is what proves that.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Re-spine grove_sim's pacing report onto the scenes

The sim reports one global level/day line. With the gates derived per scene, the useful pacing signal is **per scene**: when each of the 5 scenes completed, and which zones landed inside it. This is also the evidence that the content arc and the restoration arc no longer sit 40 days apart.

**Files:**
- Modify: `games/grove/tools/grove_sim.gd:88-93` (milestone vars), `:169`, `:186`, `:669-673` (the stale cluster-ladder comment), and the results block at `:185-189`

**Interfaces:**
- Consumes: `G.zone_unlock_level(z)`, `G.scene_level_window(p)`, `G.zone_unlock_levels()`.
- Produces: nothing (a tool).

- [ ] **Step 1: Track the per-scene completion day**

In `games/grove/tools/grove_sim.gd`, add this declaration immediately after `var half_book_day := -1` (line 93):

```gdscript
var scene_done_day := {}       # cover-up page index -> the day that page's last cluster was unlocked
```

In the page-completion block in `_play_session()` (step 0, immediately after `gates_reached += 1`), add:

```gdscript
			if not scene_done_day.has(map):
				scene_done_day[map] = _cur_day + 1
```

- [ ] **Step 2: Replace the two deleted-const reads**

At line 169, replace:

```gdscript
			if content_end_day < 0 and _level() >= int(G.ZONE_UNLOCK_LEVEL[G.ZONE_COUNT - 1]):
```

with:

```gdscript
			if content_end_day < 0 and _level() >= G.zone_unlock_level(G.ZONE_COUNT - 1):
```

At line 186, replace:

```gdscript
			[G.LEVEL_BASE_COINS, G.LEVEL_STEP_COINS, _level(), days, int(G.ZONE_UNLOCK_LEVEL[G.ZONE_COUNT - 1]),
```

with:

```gdscript
			[G.LEVEL_BASE_COINS, G.LEVEL_STEP_COINS, _level(), days, G.zone_unlock_level(G.ZONE_COUNT - 1),
```

- [ ] **Step 3: Print the per-scene pacing table**

Immediately after the existing `print("  PACING  curve base/step ...")` call (ending at line 189), add:

```gdscript
	# THE SCENE LADDER, scene by scene — the pacing view that matters now the gates are derived: each
	# scene owns a LEVEL WINDOW (from its clusters' cumulative cost) and the zones that unlock inside it.
	# The health signal is that the last zone's day and the book's day are close, not 40 days apart.
	print("  SCENES  (level window · zones inside it · day completed)")
	var _zi := 0
	for _p in G.coverup_pages().size():
		var _win := G.scene_level_window(int(_p))
		var _zl: Array = []
		var _k := int(G.ZONE_BAND[_p]) if _p < G.ZONE_BAND.size() else 0
		for _j in _k:
			_zl.append("L%d" % G.zone_unlock_level(_zi))
			_zi += 1
		var _pg := int(G.coverup_pages()[_p])
		print("    scene %d %-22s L%d-%-3d · zones %-16s · %s" % [_p + 1, String(G.MAPS[_pg].get("name", "?")),
			int(_win.x), int(_win.y), str(_zl),
			("done day %d" % int(scene_done_day[_pg])) if scene_done_day.has(_pg) else "NOT COMPLETED"])
```

- [ ] **Step 4: Fix the stale comments**

At line 89, replace:

```gdscript
# ladder are paced by DIFFERENT things — the arc by LEVEL (ZONE_UNLOCK_LEVEL), the ladder by level AND
```

with:

```gdscript
# ladder now ride the SAME spine (2026-07-25): both derive from the cluster COST ladder through the coin
# curve, so 'when the last item line lands' and 'when the book is finished' can no longer drift apart —
```

At line 670, replace:

```gdscript
# gated by BOTH a level floor (cluster_min_level = 2 + its global index) AND a coin COST it actually pays
```

with:

```gdscript
# gated by BOTH a level floor (cluster_min_level, DERIVED from the ladder's cumulative cost) AND that cost
```

- [ ] **Step 5: Run the sim on one seed to check it runs**

```bash
cd /Users/xup/dh/wt-content-derived-curve && godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- 60 1
```

Expected: the run completes, prints the new `SCENES` table with 5 rows, and ends `== sim PASS ==`.

- [ ] **Step 6: Measure across three seeds**

```bash
cd /Users/xup/dh/wt-content-derived-curve && for s in 1 7 42; do godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- 60 $s | tail -40; done
```

Record, for each seed: sim PASS/FAIL, jams, clusters unlocked, pages completed, the day the last content zone lands, the day the book completes, and the I2 / water self-sustain / P1 / P2 lines.

The acceptance signal is **not** a fixed number of clusters — it is that the last-content-zone day and the book-completion day are close together instead of ~40 days apart, with zero jams and invariant Y passing. If clusters-completed drops sharply versus the pre-change baseline, report it rather than tuning it away; re-tuning the curve is out of scope for this plan.

- [ ] **Step 7: Capture the before/after baseline**

```bash
cd /Users/xup/dh/wt-content-derived-curve && git stash && for s in 1 7 42; do godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- 60 $s | grep -E "PACING|results|clusters unlocked|sim (PASS|FAIL)"; done > /tmp/before.txt; git stash pop && cat /tmp/before.txt
```

If `git stash` cannot run because everything is already committed, use `git worktree add /tmp/baseline-wt 77b95964` and run the sim there instead, then `git worktree remove /tmp/baseline-wt`.

- [ ] **Step 8: Run the full sweep**

```bash
cd /Users/xup/dh/wt-content-derived-curve && make test
```

Expected: every suite passes.

- [ ] **Step 9: Commit**

```bash
cd /Users/xup/dh/wt-content-derived-curve && git add -A && git commit -m "feat(sim): report pacing per scene, not per level

With the gates derived, the useful signal is per SCENE: each scene's level
window, the zones that unlock inside it, and the day it completed. The health
condition this change exists to satisfy -- the last item line and the finished
book landing close together instead of ~40 days apart -- is now readable off one
table.

Measured, 3 seeds x 60 days: <fill in from Step 6>.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

Replace `<fill in from Step 6>` with the actual measured numbers before committing. Do not commit the placeholder.

---

## Handoff checklist

- [ ] `make test` passes in full.
- [ ] `grep -rn "ZONE_UNLOCK_LEVEL\|CLUSTER_LEVEL_STEP" --include="*.gd" .` returns only comments describing the retired tables — no live reads.
- [ ] `make import` has run so any new `.uid` is tracked.
- [ ] The measured sim numbers (3 seeds × 60 days, before and after) are in the Task 4 commit message.
- [ ] Report to the owner: the first cluster's floor is now **L1** (its cost, 10 coins, is below L2's 30-coin threshold). This is the pure derivation and is consistent with "the floor never binds", but it changes the FTUE — the first cover-up region can be unlocked as soon as the player has 10 coins, where today it waits for L2. Flag it; do not pin it to L2 without the owner's call.
- [ ] Two other worktrees are live (`merge-wt-mail2` on the mail reskin, `wt-bigboard` on the board size). `wt-bigboard` may touch `grove_data.gd`. Check `git worktree list` and the diff before merging to main.
