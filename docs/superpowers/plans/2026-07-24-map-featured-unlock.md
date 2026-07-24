# Map Gallery Featured Unlock Target Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the MAPS gallery's large top card follow the map containing the player's globally next locked cover-up cluster.

**Architecture:** Add one pure progression query to `content.gd`, where the global cluster sequence already lives. Keep `map.gd` as a thin UI consumer: its featured-card selector delegates to the query and no longer reads browsing history or the retired spot/gate frontier.

**Tech Stack:** Godot 4.6, GDScript, the repository's `grove_explore_tests` harness, Make targets.

## Global Constraints

- The featured card follows cluster unlock state, not `last_map`, player level, or legacy spot completion.
- The first cover-up page with a locked cluster is the current unlock map.
- When every cover-up cluster is unlocked, the final cover-up page remains featured.
- Card layout, card progress presentation, taps, and navigation do not change.
- Keep the unrelated untracked `games/grove/tests/grove_rush_ftue_tests.gd.uid` out of every commit.

---

### Task 1: Select the featured map from global cluster progression

**Files:**
- Modify: `games/grove/tests/grove_explore_tests.gd:19-50,111`
- Modify: `engine/scripts/core/content.gd:1016-1060`
- Modify: `engine/scripts/scenes/map.gd:317-326`

**Interfaces:**
- Consumes: `G.coverup_pages() -> Array`, `G.next_locked_cluster(z: int, unlocks: Dictionary) -> String`, `G.frontier_map(unlocks: Dictionary, gates: Array = []) -> int`, and `G.hub_map() -> int`.
- Produces: `G.current_unlock_map(unlocks: Dictionary, gates: Array = []) -> int`; `map.gd._featured_map() -> int` delegates to it.

- [x] **Step 1: Write the failing regression test**

Register `_test_maps_gallery_featured_unlock_target()` in
`grove_explore_tests.gd._initialize()`, immediately after
`_test_swipe_decision_helpers()`, then add:

```gdscript
func _test_maps_gallery_featured_unlock_target() -> void:
	fresh("maps_featured_unlock_target")
	var g := Save.grove()
	g["last_map"] = String(G.MAPS[0].id)
	Save.grove_write()
	var map = MapScript.new()
	map.unlocks = {}
	ok(map._featured_map() == 0,
		"a fresh picture book features Fairy Hollow, which owns the next locked cluster")

	var progressed := {}
	for cluster in G.clusters(0):
		progressed[String((cluster as Dictionary).id)] = true
	map.unlocks = progressed
	ok(map._featured_map() == 1,
		"finishing Fairy Hollow advances the featured card to Snowy Village despite last_map")

	for z in G.coverup_pages():
		for cluster in G.clusters(int(z)):
			progressed[String((cluster as Dictionary).id)] = true
	map.unlocks = progressed
	ok(map._featured_map() == 4,
		"finishing every cluster leaves Cherry-Blossom Garden featured")
	map.free()
```

This test catches a selector that consults `last_map` or
`G.frontier_map()` instead of the live cluster sequence. Its expected map
indices are hand-checked literals from the five-page `G.MAPS` order.

- [x] **Step 2: Run the focused suite and verify RED**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_explore_tests
```

Expected: the fresh-state assertion passes, while the second and third
assertions fail because the current `_featured_map()` keeps returning map 0
from `last_map` and the legacy spot frontier.

- [x] **Step 3: Add the pure progression query**

Add this immediately after `coverup_pages()` in `content.gd`:

```gdscript
## The picture-book page the player is CURRENTLY unlocking: the first page in
## global play order that still owns a locked cluster. Browsing history and
## level do not move this target. Once the book is complete, keep its final page
## featured. The fallback preserves legacy non-coverup games.
static func current_unlock_map(unlocks: Dictionary, gates: Array = []) -> int:
	var pages := coverup_pages()
	if pages.is_empty():
		var frontier := frontier_map(unlocks, gates)
		return frontier if frontier >= 0 else hub_map()
	for z in pages:
		if next_locked_cluster(int(z), unlocks) != "":
			return int(z)
	return int(pages.back())
```

- [x] **Step 4: Wire the gallery selector to the progression query**

Replace `map.gd._featured_map()` and its legacy comment with:

```gdscript
# The map the player is CURRENTLY unlocking, for the gallery's featured card.
# The global cover-up sequence owns this choice; browsing another page does not.
func _featured_map() -> int:
	return G.current_unlock_map(unlocks, _gates())
```

- [x] **Step 5: Run the focused suite and verify GREEN**

Run:

```bash
make test-one SUITE=games/grove/tests/grove_explore_tests
```

Expected: `grove · explore acquire` finishes with zero failed assertions,
including all three featured-map assertions.

- [x] **Step 6: Run repository verification**

Run each command and require exit code 0:

```bash
make test-fast
make test
make smoke
git diff --check
```

Expected: all active suites pass, both `Map.tscn` and `Board.tscn` smoke
successfully, and the diff has no whitespace errors.

- [x] **Step 7: Review and commit the implementation**

Confirm `git diff --stat` names only the plan, test, `content.gd`, and
`map.gd`; confirm the unrelated UID is still untracked. Then commit:

```bash
git add docs/superpowers/plans/2026-07-24-map-featured-unlock.md \
	engine/scripts/core/content.gd \
	engine/scripts/scenes/map.gd \
	games/grove/tests/grove_explore_tests.gd
git commit -m "fix: feature the current map unlock target"
```
