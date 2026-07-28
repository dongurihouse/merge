# Per-generator boost Implementation Plan

> **Historical note (2026-07-27):** this plan predates the removal of generator merge tiers.
> Current generator boosts ride through `gen_boost` / `gen_bag_boost`; generator merge/sell,
> `gen_tiers`, and `gen_bag_tiers` steps below are no longer active implementation guidance.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the temporary generator boost apply to a single chosen generator (stackable across generators), instead of the whole board.

**Architecture:** Per-generator boost state moves out of the global `grove["boost_taps"]` counter into `BoardModel` as a per-cell dictionary (`gen_boost`) plus a parallel bag array (`gen_bag_boost`), riding through move/merge/sell/bag on the same seams that already carry `gen_tiers`. `board.gd` reads/arms/consumes that per-cell state for the selected/tapped generator; `content.gd` keeps only the boost constants; the map-3 free charge is spent on the board chip; the old global seam is removed last.

**Tech Stack:** Godot 4.6 / GDScript. Headless SceneTree test suites run via `make test-fast` (engine) and `make test-grove` / `make test` (grove). Asserts use `ok(cond, label)` from `games/grove/tests/grove_test_base.gd`.

## Global Constraints

- Run from the worktree root `/Users/xup/dh/wt-pergen-boost`.
- `make test-fast` after every change; `make test` before the final merge.
- Boost constants stay unchanged: `G.BOOST_COST`, `G.BOOST_TAPS`, `G.BOOST_BONUS` (re-exported from `D` in `content.gd:53-55`).
- The boosted generator is identified by its board cell (`Vector2i`). Generators are keyed by cell in `BoardModel.gens` / `gen_tiers`; the bag is parallel arrays `gen_bag` / `gen_bag_tiers` (invariant: equal sizes).
- Per-generator re-buy rule: refuse a boost on an already-boosted generator; allow it on any other.
- Merge combines taps; move carries; sell/spent clears; bag carries in and back out.
- No visible window in tests (headless). Reference: `CLAUDE.md` (testing), `docs/superpowers/specs/2026-06-29-per-generator-boost-design.md` (spec).

---

## File Structure

- `engine/scripts/core/board_model.gd` — **owns** per-cell + per-bag boost state and its mutation/serialization rules. New: `gen_boost`, `gen_bag_boost`, four boost methods, `_bag_boost_at`; edits to `move_gen`/`merge_gens`/`remove_gen`/`store_gen`/`place_gen_from_bag`/`bag_add`/`prune_bag`/`seed_gens`/`to_dict`/`from_dict`.
- `engine/scripts/scenes/board.gd` — orchestration: purchase chip, charged-tap consume, bonus-gen collect, on-board indicator, info-bar label, all retargeted from the global seam to the cell's own state.
- `engine/scripts/core/habitat.gd` — `spend_boost_charge()` (decrement only); `use_boost_charge()` removed.
- `engine/scripts/scenes/map.gd` — remove the map-screen "Use boost" button + `_on_use_boost()`.
- `engine/scripts/core/content.gd` — remove the global boost-state seam (keep the constants + `boost_cost`/`boost_bonus`).
- `games/grove/tests/grove_model_tests.gd` — BoardModel boost unit tests.
- `games/grove/tests/grove_economy_tests.gd` — rewrite the boost block (§11b/c/e) to per-generator; the seam sub-test (§11d) is removed in Task 4.
- `games/grove/tests/grove_residents_tests.gd` — rewrite the free-charge sub-test to the board-spent model.

---

## Task 1: BoardModel per-generator boost state, mutations, serialization

**Files:**
- Modify: `engine/scripts/core/board_model.gd`
- Test: `games/grove/tests/grove_model_tests.gd`

**Interfaces:**
- Produces (used by board.gd in later tasks):
  - State: `var gen_boost: Dictionary` (cell→taps), `var gen_bag_boost: Array` (parallel to `gen_bag`).
  - `gen_boost_at(cell: Vector2i) -> int`
  - `is_gen_boosted(cell: Vector2i) -> bool`
  - `arm_gen_boost(cell: Vector2i, taps: int) -> void` (no-op if the cell has no generator; `taps<=0` clears)
  - `consume_gen_boost(cell: Vector2i) -> void` (decrement; erase at 0; never underflows)
  - Mutation rules: `move_gen` carries, `merge_gens` sums, `remove_gen`/`store_gen` clear the on-board entry, `place_gen_from_bag` restores from the bag.
  - Serialization: each `gens` entry serializes as `[row, col, id, tier, boost]`; bag adds `"gen_bag_boost"`.

- [ ] **Step 1: Write the failing tests** — append to `games/grove/tests/grove_model_tests.gd`, just before its `finish(...)` call (find the existing `store_gen`/`place_gen_from_bag` block near the round-trip test and add after it):

```gdscript
	# --- §6 per-generator boost: per-cell state rides with the generator ---------------
	var bb := BoardModel.new()
	var c0 := bb.gens.keys()[0]                       # the anchor generator's cell
	ok(bb.gen_boost_at(c0) == 0 and not bb.is_gen_boosted(c0), "boost: a fresh generator is unboosted")
	bb.arm_gen_boost(c0, G.BOOST_TAPS)
	ok(bb.is_gen_boosted(c0) and bb.gen_boost_at(c0) == G.BOOST_TAPS, "boost: arm sets the cell's taps")
	bb.consume_gen_boost(c0)
	ok(bb.gen_boost_at(c0) == G.BOOST_TAPS - 1, "boost: consume decrements one tap")
	for _i in G.BOOST_TAPS:
		bb.consume_gen_boost(c0)
	ok(bb.gen_boost_at(c0) == 0 and not bb.is_gen_boosted(c0), "boost: decays to zero and never underflows")
	var empty_cell := bb.empty_ground_cells()[0]
	bb.arm_gen_boost(empty_cell, G.BOOST_TAPS)
	ok(bb.gen_boost_at(empty_cell) == 0, "boost: arming a cell with no generator is a no-op")

	# move carries the boost
	var mvb := BoardModel.new()
	var mfrom := mvb.gens.keys()[0]
	var mto := mvb.empty_ground_cells()[0]
	mvb.arm_gen_boost(mfrom, 3)
	ok(mvb.move_gen(mfrom, mto), "boost: move the boosted generator")
	ok(mvb.gen_boost_at(mto) == 3 and mvb.gen_boost_at(mfrom) == 0, "boost: move carries the taps to the new cell")

	# merge combines the taps
	var mgb := BoardModel.new()
	var a := mgb.gens.keys()[0]
	var gid_a := mgb.gen_id_at(a)
	var b := mgb.empty_ground_cells()[0]
	mgb.place_gen(gid_a, b, mgb.gen_tier_at(a))       # a same-line, same-tier twin to merge with
	mgb.arm_gen_boost(a, 2)
	mgb.arm_gen_boost(b, 5)
	ok(mgb.merge_gens(a, b), "boost: merge the two boosted generators")
	ok(mgb.gen_boost_at(b) == 7 and mgb.gen_boost_at(a) == 0, "boost: merge sums the survivor's and source's taps")

	# sell / spent clears the boost
	var rmb := BoardModel.new()
	var rc := rmb.gens.keys()[0]
	rmb.arm_gen_boost(rc, 4)
	ok(rmb.remove_gen(rc), "boost: remove the boosted generator")
	ok(rmb.gen_boost_at(rc) == 0, "boost: remove clears the boost")

	# bag carries the boost in and back out, arrays stay aligned
	var bgb := BoardModel.new()
	var sc := bgb.gens.keys()[0]
	var sgid := bgb.gen_id_at(sc)
	bgb.arm_gen_boost(sc, 6)
	ok(bgb.store_gen(sc), "boost: store the boosted generator into the bag")
	ok(bgb.gen_boost_at(sc) == 0, "boost: storing clears the on-board entry")
	ok(bgb.gen_bag_boost.size() == bgb.gen_bag.size(), "boost: bag arrays stay aligned after store")
	var oc := bgb.empty_ground_cells()[0]
	ok(bgb.place_gen_from_bag(sgid, oc), "boost: place the stored generator back")
	ok(bgb.gen_boost_at(oc) == 6, "boost: re-placing restores the carried taps")

	# serialization round-trips per-cell and per-bag boost
	var srb := BoardModel.new()
	var ssc := srb.gens.keys()[0]
	srb.arm_gen_boost(ssc, 5)
	srb.bag_add(srb.gen_id_at(ssc), 2, 3)             # a bagged generator with its own boost
	var srt := BoardModel.new(); srt.from_dict(srb.to_dict())
	ok(srt.gen_boost_at(ssc) == 5, "boost: per-cell taps survive to_dict/from_dict")
	ok(srt.gen_bag_boost.size() == srt.gen_bag.size() and srt.gen_bag_boost.back() == 3, "boost: bag taps survive the round-trip")

	# legacy saves (4-element gens entry, no gen_bag_boost) read as zero
	var legacy := {"terrain": Array(srb.terrain), "items": Array(srb.items),
		"gens": [[ssc.x, ssc.y, srb.gen_id_at(ssc), 1]], "gen_bag": [], "gen_bag_tiers": [], "collect_rewards": []}
	var lgb := BoardModel.new(); lgb.from_dict(legacy)
	ok(lgb.gen_boost_at(ssc) == 0 and lgb.gen_bag_boost.is_empty(), "boost: a legacy save reads no boost (default 0)")
```

- [ ] **Step 2: Run the tests, verify they fail**

Run: `make test-grove 2>&1 | tail -30` (or `godot --headless --path . -s res://games/grove/tests/grove_model_tests.gd`)
Expected: FAIL — `Invalid call. Nonexistent function 'gen_boost_at' in base 'RefCounted'` (and similar).

- [ ] **Step 3: Add the boost state + methods** to `board_model.gd`. After the `gen_bag_tiers` declaration (currently `board_model.gd:18`), add:

```gdscript
var gen_boost: Dictionary = {}            # cell -> remaining boost taps (§6 per-generator; absent/0 = none).
                                          # Rides with the generator: move carries, merge sums, sell/store clears.
var gen_bag_boost: Array = []             # PARALLEL to gen_bag: remaining boost taps of each stored generator.
                                          # Invariant: size() == gen_bag.size() (mutate via store_gen/bag_add/prune_bag).
```

After `gen_tier_at` (currently `board_model.gd:142-143`), add the four accessors:

```gdscript
# §6 per-generator boost — remaining taps at a cell (0 = unboosted). Read by the board's pop/collect/indicator.
func gen_boost_at(cell: Vector2i) -> int:
	return int(gen_boost.get(cell, 0))

func is_gen_boosted(cell: Vector2i) -> bool:
	return gen_boost_at(cell) > 0

# Arm a generator's boost to `taps`. No-op when the cell holds no generator; taps<=0 clears the entry.
func arm_gen_boost(cell: Vector2i, taps: int) -> void:
	if taps > 0 and gens.has(cell):
		gen_boost[cell] = taps
	else:
		gen_boost.erase(cell)

# Spend one boost tap off a cell — called once per charged/collect tap on that generator. Erases at 0; never underflows.
func consume_gen_boost(cell: Vector2i) -> void:
	var left := gen_boost_at(cell)
	if left <= 1:
		gen_boost.erase(cell)
	else:
		gen_boost[cell] = left - 1
```

Next to `_bag_tier_at` (currently `board_model.gd:115-116`), add:

```gdscript
# The boost taps of the bagged generator at index `i` (0 if out of range — tolerates a transient skew).
func _bag_boost_at(i: int) -> int:
	return int(gen_bag_boost[i]) if i >= 0 and i < gen_bag_boost.size() else 0
```

- [ ] **Step 4: Wire the boost into the generator mutation seams.**

In `seed_gens` (currently `board_model.gd:63`), right after `gens = {}`, add:

```gdscript
	gen_boost = {}
```

In `store_gen` (currently `board_model.gd:85-92`), append the boost into the bag and clear the on-board entry. Change the body from:

```gdscript
	gen_bag.append(String(gens[cell]))
	gen_bag_tiers.append(gen_tier_at(cell))   # the tier follows the generator into the bag
	gens.erase(cell)
	gen_tiers.erase(cell)                      # no stale tier left behind on the now-empty cell
	return true
```

to:

```gdscript
	gen_bag.append(String(gens[cell]))
	gen_bag_tiers.append(gen_tier_at(cell))   # the tier follows the generator into the bag
	gen_bag_boost.append(gen_boost_at(cell))  # §6: the boost travels with it too
	gens.erase(cell)
	gen_tiers.erase(cell)                      # no stale tier left behind on the now-empty cell
	gen_boost.erase(cell)
	return true
```

In `place_gen_from_bag` (currently `board_model.gd:95-106`), read + restore the bagged boost. Change from:

```gdscript
	var tier := _bag_tier_at(i)               # read the tier BEFORE removing the entry
	gen_bag.remove_at(i)
	if i < gen_bag_tiers.size():
		gen_bag_tiers.remove_at(i)
	gens[cell] = id
	gen_tiers[cell] = tier                     # restore the stored tier (not a silent reset to 1)
	return true
```

to:

```gdscript
	var tier := _bag_tier_at(i)               # read the tier BEFORE removing the entry
	var boost := _bag_boost_at(i)             # §6: and the carried boost
	gen_bag.remove_at(i)
	if i < gen_bag_tiers.size():
		gen_bag_tiers.remove_at(i)
	if i < gen_bag_boost.size():
		gen_bag_boost.remove_at(i)
	gens[cell] = id
	gen_tiers[cell] = tier                     # restore the stored tier (not a silent reset to 1)
	if boost > 0:
		gen_boost[cell] = boost                # restore the carried boost
	return true
```

In `bag_add` (currently `board_model.gd:110-112`), gain a boost param. Change from:

```gdscript
func bag_add(id: String, tier: int = 1) -> void:
	gen_bag.append(String(id))
	gen_bag_tiers.append(maxi(1, tier))
```

to:

```gdscript
func bag_add(id: String, tier: int = 1, boost: int = 0) -> void:
	gen_bag.append(String(id))
	gen_bag_tiers.append(maxi(1, tier))
	gen_bag_boost.append(maxi(0, boost))
```

In `prune_bag` (currently `board_model.gd:120-128`), rebuild the boost array alongside. Change from:

```gdscript
	var ids: Array = []
	var tiers: Array = []
	for i in gen_bag.size():
		if bool(should_keep.call(String(gen_bag[i]))):
			ids.append(gen_bag[i])
			tiers.append(_bag_tier_at(i))
	gen_bag = ids
	gen_bag_tiers = tiers
```

to:

```gdscript
	var ids: Array = []
	var tiers: Array = []
	var boosts: Array = []
	for i in gen_bag.size():
		if bool(should_keep.call(String(gen_bag[i]))):
			ids.append(gen_bag[i])
			tiers.append(_bag_tier_at(i))
			boosts.append(_bag_boost_at(i))
	gen_bag = ids
	gen_bag_tiers = tiers
	gen_bag_boost = boosts
```

In `move_gen` (currently `board_model.gd:132-139`), carry the boost. After the existing `gen_tiers.erase(from)` line (the last line before `return true`), insert:

```gdscript
	var moved_boost := gen_boost_at(from)
	if moved_boost > 0:
		gen_boost[to] = moved_boost
	gen_boost.erase(from)
```

In `merge_gens` (currently `board_model.gd:147-158`), combine the taps. After the existing `gen_tiers[to] = t + 1` line (before `return true`), insert:

```gdscript
	var combined := gen_boost_at(to) + gen_boost_at(from)
	gen_boost.erase(from)
	if combined > 0:
		gen_boost[to] = combined
```

In `remove_gen` (currently `board_model.gd:163-168`), clear the boost. After the existing `gen_tiers.erase(cell)` line (before `return true`), insert:

```gdscript
	gen_boost.erase(cell)
```

- [ ] **Step 5: Wire the boost into serialization.**

In `to_dict` (currently `board_model.gd:375-385`), serialize the boost as the 5th element and add the bag array. Change the gens-encoding line from:

```gdscript
		gl.append([c.x, c.y, gens[c], gen_tier_at(c)])   # [row, col, id, tier] — JSON-safe (no Vector2i keys)
```

to:

```gdscript
		gl.append([c.x, c.y, gens[c], gen_tier_at(c), gen_boost_at(c)])   # [row, col, id, tier, boost] — JSON-safe
```

and change the returned dict to add `gen_bag_boost`:

```gdscript
	return {"terrain": Array(terrain), "items": Array(items), "gens": gl, "gen_bag": gen_bag.duplicate(), "gen_bag_tiers": gen_bag_tiers.duplicate(), "gen_bag_boost": gen_bag_boost.duplicate(), "collect_rewards": cr}
```

In `from_dict` (currently `board_model.gd:387-433`), read both. Add `gen_boost = {}` next to the existing `gens = {}` / `gen_tiers = {}` resets (currently `board_model.gd:409-410`):

```gdscript
	gens = {}
	gen_tiers = {}
	gen_boost = {}
```

In the gens loop, after the existing `gen_tiers[gc] = int(e[3]) if (e as Array).size() > 3 else 1` line, add:

```gdscript
		if (e as Array).size() > 4 and int(e[4]) > 0:
			gen_boost[gc] = int(e[4])           # §6: per-cell boost (absent in 4-element legacy entries → none)
```

Read the parallel bag-boost array next to `bt`. After the existing `var bt: Array = Array(d.get("gen_bag_tiers", []))` line, add:

```gdscript
	var bb: Array = Array(d.get("gen_bag_boost", []))     # §6: parallel bag boosts (absent in old saves → all 0)
```

Reset `gen_bag_boost = []` next to the existing `gen_bag = []` / `gen_bag_tiers = []` resets, and append inside the loop next to the tier append. Change:

```gdscript
	gen_bag = []
	gen_bag_tiers = []
	for i in raw_gen_bag.size():
		var gid := String(raw_gen_bag[i])
		if not G.is_valid_generator_id(gid):
			changed = true
			continue
		gen_bag.append(gid)
		gen_bag_tiers.append(int(bt[i]) if i < bt.size() else 1)
```

to:

```gdscript
	gen_bag = []
	gen_bag_tiers = []
	gen_bag_boost = []
	for i in raw_gen_bag.size():
		var gid := String(raw_gen_bag[i])
		if not G.is_valid_generator_id(gid):
			changed = true
			continue
		gen_bag.append(gid)
		gen_bag_tiers.append(int(bt[i]) if i < bt.size() else 1)
		gen_bag_boost.append(int(bb[i]) if i < bb.size() else 0)
```

- [ ] **Step 6: Run the tests, verify they pass**

Run: `make test-grove 2>&1 | tail -30`
Expected: PASS for all the new `boost:` asserts; no regressions in the existing model/economy suites.

- [ ] **Step 7: Commit**

```bash
cd /Users/xup/dh/wt-pergen-boost
git add engine/scripts/core/board_model.gd games/grove/tests/grove_model_tests.gd
git commit -m "feat(board): per-generator boost state in BoardModel (carry/merge/bag/serialize)"
```

---

## Task 2: board.gd — boost the selected/tapped generator (coins purchase)

**Files:**
- Modify: `engine/scripts/scenes/board.gd`
- Test: `games/grove/tests/grove_economy_tests.gd`

**Interfaces:**
- Consumes: `BoardModel.is_gen_boosted(cell)`, `gen_boost_at(cell)`, `arm_gen_boost(cell, taps)`, `consume_gen_boost(cell)` (Task 1).
- Produces: `_gen_boost_bonus(cell: Vector2i) -> int`, `_activate_gen_boost(cell: Vector2i) -> bool` (coins path; free-charge branch added in Task 3), `_gen_info_text(gid: String, cell: Vector2i) -> String`.

- [ ] **Step 1: Rewrite the economy boost test block to per-generator.** In `games/grove/tests/grove_economy_tests.gd`, replace the body of §11b (currently lines ~115–166, from `fresh("burst")` through the `sbp2.queue_free()`) and §11c (the broke block, ~168–177) with the per-generator version below. Keep §11d (the seam block, ~179–198) for now — it still exercises the global seam that Task 4 removes.

```gdscript
	fresh("burst")
	var sbp = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sbp)
	if sbp.board == null:
		sbp._ready()
	Save.grove()["pops"] = 50                 # well past the FTUE — the energy meter is on
	var cell_a: Vector2i = sbp.board.gens.keys()[0]
	ok(not sbp.board.is_gen_boosted(cell_a), "no generator is boosted on a fresh save")
	ok(sbp._gen_boost_bonus(cell_a) == 0, "with no boost a generator gets no bonus items")
	Save.add_coins(10000)
	var bu_c0 := Save.coins()
	ok(sbp._activate_gen_boost(cell_a), "the boost activates on the chosen generator with coins")
	ok(Save.coins() == bu_c0 - G.BOOST_COST, "activating spends the boost cost (the coin sink)")
	ok(sbp.board.is_gen_boosted(cell_a) and sbp.board.gen_boost_at(cell_a) == G.BOOST_TAPS, "the boost arms BOOST_TAPS taps on that generator")
	ok(sbp._gen_boost_bonus(cell_a) == G.BOOST_BONUS, "while active that generator gets +BOOST_BONUS items")
	# a second buy on the SAME generator is refused — no extra taps, no double spend
	var bu_c1 := Save.coins()
	ok(not sbp._activate_gen_boost(cell_a), "a second boost on an already-boosted generator is refused")
	ok(sbp.board.gen_boost_at(cell_a) == G.BOOST_TAPS and Save.coins() == bu_c1, "...no extra taps, no double spend")
	# a DIFFERENT generator can still be boosted (stackable) — place a twin and boost it
	var cell_b: Vector2i = sbp.board.empty_ground_cells()[0]
	sbp.board.place_gen(sbp.board.gen_id_at(cell_a), cell_b, sbp.board.gen_tier_at(cell_a))
	ok(sbp._activate_gen_boost(cell_b), "a different generator can be boosted while the first is live (stackable)")
	ok(sbp.board.is_gen_boosted(cell_a) and sbp.board.is_gen_boosted(cell_b), "both generators are boosted at once")
	# the boosted generator's taps decay and ride the save across scenes
	var saved_taps: int = sbp.board.gen_boost_at(cell_a)
	sbp.board.consume_gen_boost(cell_a)
	ok(sbp.board.gen_boost_at(cell_a) == saved_taps - 1, "a charged tap spends one of that generator's boost taps")
	sbp._persist()
	var sbp2 = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sbp2)
	if sbp2.board == null:
		sbp2._ready()
	ok(sbp2.board.gen_boost_at(cell_a) == saved_taps - 1, "the per-generator boost rides the save across scenes")
	sbp.queue_free()
	sbp2.queue_free()

	# 11c. The boost refuses cleanly when broke — no taps armed, no coin debt.
	fresh("burst_broke")
	var sbc = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(sbc)
	if sbc.board == null:
		sbc._ready()
	var bc_cell: Vector2i = sbc.board.gens.keys()[0]
	ok(not sbc.board.is_gen_boosted(bc_cell) and Save.coins() == 0, "fresh: no boost, no coins")
	ok(not sbc._activate_gen_boost(bc_cell), "broke: the boost refuses — returns false")
	ok(not sbc.board.is_gen_boosted(bc_cell) and Save.coins() == 0, "broke refusal arms no taps and leaves no coin debt")
	sbc.queue_free()
```

- [ ] **Step 2: Run the rewritten test, verify it fails**

Run: `make test-grove 2>&1 | tail -30`
Expected: FAIL — `_activate_gen_boost` is still 0-arg / delegates to the global seam, and `_gen_boost_bonus` takes no cell, so calls error or asserts fail.

- [ ] **Step 3: Retarget `_gen_boost_bonus` and `_activate_gen_boost` to a cell.** In `board.gd`, change `_gen_boost_bonus` (currently `board.gd:2728-2729`) from:

```gdscript
func _gen_boost_bonus() -> int:
	return G.boost_bonus() if G.boost_active() else 0
```

to:

```gdscript
# A generator's per-tap bonus from ITS OWN live boost (§6): BOOST_BONUS while that cell is boosted, else 0.
func _gen_boost_bonus(cell: Vector2i) -> int:
	return G.boost_bonus() if board.is_gen_boosted(cell) else 0
```

Change `_activate_gen_boost` (currently `board.gd:2734-2735`) from:

```gdscript
func _activate_gen_boost() -> bool:
	return G.try_activate_boost()
```

to:

```gdscript
# Arm the temporary boost on ONE generator (§6/§10 coin sink). Refuses (no spend) when the cell holds no
# generator, that generator is already boosted, or the player is broke. Spends BOOST_COST, arms BOOST_TAPS,
# persists. Returns true on a real arm. (The free-charge branch is added in Task 3.)
func _activate_gen_boost(cell: Vector2i) -> bool:
	if not board.is_gen(cell) or board.is_gen_boosted(cell):
		return false
	if not Save.spend(G.BOOST_COST, "boost"):
		return false
	board.arm_gen_boost(cell, G.BOOST_TAPS)
	_persist()
	return true
```

- [ ] **Step 4: Retarget the purchase chip.** Change `_on_burst_chip` (currently `board.gd:1980-1990`, the guards + the activate call) from:

```gdscript
func _on_burst_chip() -> void:
	if G.boost_active():
		FX.wobble(_info_burst)                # a boost is already running — no re-buy while live
		Audio.play("invalid_soft", -4.0)
		return
	if Save.coins() < G.boost_cost():
		FX.wobble(_info_burst)
		Audio.play("invalid_soft", -4.0)
		FX.floating_text(self, _info_burst.get_global_rect().get_center() - Vector2(70, 78), Strings.t("board.info.burst_need"), CREAM, 24)
		return
	if _activate_gen_boost():                  # the shared seam: spend + arm + persist
```

to:

```gdscript
func _on_burst_chip() -> void:
	if _selected_cell.x < 0 or not board.is_gen(_selected_cell):
		return
	if board.is_gen_boosted(_selected_cell):
		FX.wobble(_info_burst)                # this generator is already boosted — no re-buy on it
		Audio.play("invalid_soft", -4.0)
		return
	if Save.coins() < G.boost_cost():
		FX.wobble(_info_burst)
		Audio.play("invalid_soft", -4.0)
		FX.floating_text(self, _info_burst.get_global_rect().get_center() - Vector2(70, 78), Strings.t("board.info.burst_need"), CREAM, 24)
		return
	if _activate_gen_boost(_selected_cell):    # spend + arm THIS generator + persist
```

(The success block below it — `_update_hud()`, `_refresh_boost_indicator()`, the `_selected_cell` FX, `_refresh_burst_chip()` — is unchanged; the `_info_label.text = _gen_info_text(...)` call inside it is updated in Step 7.)

- [ ] **Step 5: Retarget the chip's faded state.** Change `_refresh_burst_chip` (currently `board.gd:1963-1965`) from:

```gdscript
	var cost := G.boost_cost()
	var live := G.boost_active()
	var ready := Save.coins() >= cost and not live   # full-color only when arming one now would work
```

to:

```gdscript
	var cost := G.boost_cost()
	var live := _selected_cell.x >= 0 and board.is_gen_boosted(_selected_cell)   # THIS generator already boosted
	var ready := Save.coins() >= cost and not live   # full-color only when arming one now would work
```

- [ ] **Step 6: Retarget the on-board indicator to per-cell.** Change `_refresh_boost_indicator` (currently `board.gd:1369-1371` head) from:

```gdscript
func _refresh_boost_indicator() -> void:
	var live := G.boost_active()
	var taps := G.boost_taps_left()
	for cell in gen_nodes:
```

to:

```gdscript
func _refresh_boost_indicator() -> void:
	for cell in gen_nodes:
		var live := board.is_gen_boosted(cell)
		var taps := board.gen_boost_at(cell)
```

(The loop body keeps using the per-iteration `live`/`taps`. Verify the existing body — which already branches on `live` and prints `taps` — now sits under the loop with these per-cell locals; the `gn`/`owns_badge` lines stay as-is.)

- [ ] **Step 7: Retarget the info-bar label.** Change `_gen_info_text` (currently `board.gd:1877-1885`) signature + boost branch from:

```gdscript
func _gen_info_text(gid: String) -> String:
	var lbl := G.generator_display_name(gid)
	if G.is_treat_gen(gid):
		var clicks := int(Save.grove().get("treat_clicks", 0))
		if clicks > 0:
			lbl += " · %d taps" % clicks
	elif G.boost_active():
		lbl += " · " + (Strings.t("board.info.boost_detail") % G.boost_taps_left())
	return lbl
```

to:

```gdscript
func _gen_info_text(gid: String, cell: Vector2i) -> String:
	var lbl := G.generator_display_name(gid)
	if G.is_treat_gen(gid):
		var clicks := int(Save.grove().get("treat_clicks", 0))
		if clicks > 0:
			lbl += " · %d taps" % clicks
	elif board.is_gen_boosted(cell):
		lbl += " · " + (Strings.t("board.info.boost_detail") % board.gen_boost_at(cell))
	return lbl
```

Update its three callers to pass the cell:
- `board.gd:1856` `_info_label.text = _gen_info_text(gid)` → `_info_label.text = _gen_info_text(gid, _selected_cell)`
- `board.gd:2001` `_info_label.text = _gen_info_text(board.gen_id_at(_selected_cell))` → `_info_label.text = _gen_info_text(board.gen_id_at(_selected_cell), _selected_cell)`
- `board.gd:2634` `_info_label.text = _gen_info_text(board.gen_id_at(_selected_cell))` → `_info_label.text = _gen_info_text(board.gen_id_at(_selected_cell), _selected_cell)`

- [ ] **Step 8: Retarget the charged-tap burst + consume.** In `_pop_seed`, change the burst line (currently `board.gd:2565`) from:

```gdscript
		burst = G.burst_count(_quest_map(), _gen_boost_bonus(), rng) if G.boost_active() else G.gen_burst_count(board.gen_tier_at(cell), rng)
```

to:

```gdscript
		burst = G.burst_count(_quest_map(), _gen_boost_bonus(cell), rng) if board.is_gen_boosted(cell) else G.gen_burst_count(board.gen_tier_at(cell), rng)
```

and the consume (currently `board.gd:2630-2632`) from:

```gdscript
	if G.boost_active():
		G.consume_boost_tap()              # §6: each charged tap spends one boost tap, then it expires
		_refresh_boost_indicator()         # tick the on-board sparkle + count badge down (or clear it)
```

to:

```gdscript
	if board.is_gen_boosted(cell):
		board.consume_gen_boost(cell)      # §6: each charged tap spends one of THIS generator's boost taps
		_refresh_boost_indicator()         # tick the on-board sparkle + count badge down (or clear it)
```

- [ ] **Step 9: Retarget the bonus-generator collect.** In the bonus-gen collect path, change the boost read (currently `board.gd:3099-3101`) from:

```gdscript
	var boosted := G.boost_active()
	if boosted:
		mult = G.burst_count(_quest_map(), G.boost_bonus(), rng)
```

to:

```gdscript
	var boosted := board.is_gen_boosted(cell)
	if boosted:
		mult = G.burst_count(_quest_map(), G.boost_bonus(), rng)
```

and the consume (currently `board.gd:3114-3116`) from:

```gdscript
	if boosted:
		G.consume_boost_tap()              # §6: a boosted collect used the boost's burst, so — like a charged
		_refresh_boost_indicator()         # generator tap — it spends one boost tap and ticks the badge down
```

to:

```gdscript
	if boosted:
		board.consume_gen_boost(cell)      # §6: a boosted collect spends one of this generator's boost taps
		_refresh_boost_indicator()         # tick the on-board sparkle + count badge down
```

- [ ] **Step 10: Run the tests, verify they pass**

Run: `make test-grove 2>&1 | tail -30`
Expected: PASS for the rewritten §11b/§11c; §11d (seam) still passes (global seam intact); no regressions.

- [ ] **Step 11: Commit**

```bash
cd /Users/xup/dh/wt-pergen-boost
git add engine/scripts/scenes/board.gd games/grove/tests/grove_economy_tests.gd
git commit -m "feat(board): boost the selected/tapped generator instead of the whole board"
```

---

## Task 3: Free map-3 charge spent on the board chip

**Files:**
- Modify: `engine/scripts/core/habitat.gd`, `engine/scripts/scenes/map.gd`, `engine/scripts/scenes/board.gd`
- Test: `games/grove/tests/grove_residents_tests.gd`

**Interfaces:**
- Consumes: `Habitat.boost_charges()` (existing), `BoardModel.arm_gen_boost` (Task 1).
- Produces: `Habitat.spend_boost_charge() -> bool` (decrement one charge; no boost arming). `_activate_gen_boost` now spends a free charge when one is in stock instead of coins. `_refresh_burst_chip` shows "Free" when a charge is in stock.

- [ ] **Step 1: Rewrite the residents free-charge sub-test.** In `games/grove/tests/grove_residents_tests.gd`, replace the block that currently reads (around lines 409–413):

```gdscript
	var ch := Habitat.boost_charges()
	ok(Habitat.use_boost_charge(), "a stockpiled charge can be used")
	ok(Habitat.boost_charges() == ch - 1, "using a charge decrements the stock")
	ok(G.boost_active(), "using a charge arms the generator boost (free activation)")
	ok(not Habitat.use_boost_charge(), "a second charge is refused while a boost is already live")
```

with:

```gdscript
	var ch := Habitat.boost_charges()
	ok(Habitat.spend_boost_charge(), "a stockpiled charge can be spent")
	ok(Habitat.boost_charges() == ch - 1, "spending a charge decrements the stock")
	# the board chip arms a generator for FREE while a charge is in stock (spent on the board, not the map)
	var rbm = load("res://engine/scenes/Board.tscn").instantiate()
	get_root().add_child(rbm)
	if rbm.board == null:
		rbm._ready()
	var rcell: Vector2i = rbm.board.gens.keys()[0]
	var coins_before := Save.coins()
	var charges_before := Habitat.boost_charges()
	ok(rbm._activate_gen_boost(rcell), "the board chip arms a generator")
	ok(rbm.board.is_gen_boosted(rcell), "the generator is boosted")
	ok(Habitat.boost_charges() == charges_before - 1 and Save.coins() == coins_before, "a free charge was spent, not coins")
	rbm.queue_free()
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `make test-grove 2>&1 | tail -30`
Expected: FAIL — `Habitat.spend_boost_charge` does not exist; `_activate_gen_boost` still always spends coins.

- [ ] **Step 3: Add `Habitat.spend_boost_charge`, remove `use_boost_charge`.** In `engine/scripts/core/habitat.gd`, replace `use_boost_charge` (currently `habitat.gd:322-330`):

```gdscript
## Spend one stockpiled charge to arm the generator boost for free. Refuses (keeps the charge) when the
## stock is empty or a boost is already live (one boost at a time, mirroring content.try_activate_boost).
static func use_boost_charge() -> bool:
	if boost_charges() <= 0:
		return false
	if not Content.arm_boost_free():
		return false
	_set_boost_charges(boost_charges() - 1)
	return true
```

with:

```gdscript
## Spend one stockpiled generator-boost charge (map 3's reward). Returns false (keeps the stock) when empty.
## The board's boost chip calls this to arm the SELECTED generator for free (the arming lives on the board).
static func spend_boost_charge() -> bool:
	if boost_charges() <= 0:
		return false
	_set_boost_charges(boost_charges() - 1)
	return true
```

- [ ] **Step 4: Spend a free charge in `_activate_gen_boost`.** In `board.gd`, change the spend line in `_activate_gen_boost` (added in Task 2) from:

```gdscript
	if not board.is_gen(cell) or board.is_gen_boosted(cell):
		return false
	if not Save.spend(G.BOOST_COST, "boost"):
		return false
	board.arm_gen_boost(cell, G.BOOST_TAPS)
```

to:

```gdscript
	if not board.is_gen(cell) or board.is_gen_boosted(cell):
		return false
	if Habitat.boost_charges() > 0:
		Habitat.spend_boost_charge()       # §10: a free map-3 charge arms it for free (spent on the board)
	elif not Save.spend(G.BOOST_COST, "boost"):
		return false
	board.arm_gen_boost(cell, G.BOOST_TAPS)
```

(Confirm `Habitat` is already referenced in `board.gd`; it is — e.g. the existing `_on_use_boost`/reward code. If the const alias differs, use the same name the file already uses for habitat.)

- [ ] **Step 5: Show "Free" on the chip when a charge is in stock.** In `_refresh_burst_chip` (`board.gd`), after computing `cost`/`live`/`ready`, gate the label on a free charge. Change:

```gdscript
	var cost := G.boost_cost()
	var live := _selected_cell.x >= 0 and board.is_gen_boosted(_selected_cell)   # THIS generator already boosted
	var ready := Save.coins() >= cost and not live   # full-color only when arming one now would work
```

to:

```gdscript
	var cost := G.boost_cost()
	var free := Habitat.boost_charges() > 0           # §10: a stockpiled map-3 charge pays for the next boost
	var live := _selected_cell.x >= 0 and board.is_gen_boosted(_selected_cell)   # THIS generator already boosted
	var ready := (free or Save.coins() >= cost) and not live   # full-color when arming one now would work
```

and change the count label (currently `board.gd:1971` `_info_burst_count.text = "%d" % cost`) to:

```gdscript
	_info_burst_count.text = Strings.t("board.info.boost_free") if free else ("%d" % cost)
```

Add the string key. In `games/grove/strings.json`, add `"board.info.boost_free": "Free"` next to the existing `board.info.*` keys (verify the surrounding JSON comma syntax).

- [ ] **Step 6: Remove the map-screen Use-boost button.** In `engine/scripts/scenes/map.gd`, delete the affordance block (currently `map.gd:1285-1290`):

```gdscript
		# map 3: a "Use boost" affordance once charges are stockpiled (arms the generator boost for free)
		if cur == "boost" and Habitat.boost_charges() > 0:
			var useb: Button = Kit.pill_button("Use boost (%d)" % Habitat.boost_charges(), {"bg": "cream", "art": true, "font": 18, "enabled": not G.boost_active()})
			useb.position = Vector2(button_pos.x, maxf(shelf_pad_t, button_pos.y - button_size.y - 4.0))
			useb.pressed.connect(func() -> void: _on_use_boost())
			shelf.add_child(useb)
```

and delete the `_on_use_boost()` handler (currently `map.gd:1728-1736`, the whole function). Then grep `map.gd` for any remaining `_on_use_boost` reference and remove it.

- [ ] **Step 7: Run the tests, verify they pass**

Run: `make test-grove 2>&1 | tail -30`
Expected: PASS for the rewritten residents free-charge test; no regressions.

- [ ] **Step 8: Commit**

```bash
cd /Users/xup/dh/wt-pergen-boost
git add engine/scripts/core/habitat.gd engine/scripts/scenes/map.gd engine/scripts/scenes/board.gd games/grove/strings.json games/grove/tests/grove_residents_tests.gd
git commit -m "feat(boost): spend the map-3 free charge on the board chip; drop the map button"
```

---

## Task 4: Remove the global boost seam from content.gd

**Files:**
- Modify: `engine/scripts/core/content.gd`
- Test: `games/grove/tests/grove_economy_tests.gd`

**Interfaces:**
- Removes (now unused): `boost_taps_left`, `boost_active`, `try_activate_boost`, `arm_boost_free`, `consume_boost_tap`, and the `grove["boost_taps"]` key. Keeps `boost_cost`, `boost_bonus`, and the `BOOST_*` constants.

- [ ] **Step 1: Remove the §11d seam sub-test.** In `games/grove/tests/grove_economy_tests.gd`, delete the §11d block (currently ~lines 179–198, from the `# 11d. The SHARED boost seam...` comment through the last `ok(G.boost_taps_left() == 0, "seam: consuming past expiry never underflows")`). Keep §11e and the rest.

- [ ] **Step 2: Verify nothing else references the seam**

Run: `grep -rniI "boost_active\|boost_taps_left\|try_activate_boost\|arm_boost_free\|consume_boost_tap\|\"boost_taps\"" engine games --include="*.gd" | grep -v "engine/scripts/core/content.gd:"`
Expected: no output (every caller retargeted in Tasks 2–3).

- [ ] **Step 3: Remove the seam functions from content.gd.** Delete `boost_taps_left` (currently `content.gd:653-655`), `boost_active` (657-659), `try_activate_boost` (661-670), `arm_boost_free` (672-680), and `consume_boost_tap` (682-689), along with their doc-comments. Keep `boost_cost` (646-647) and `boost_bonus` (649-651). Update the §6/§10 header comment above `boost_cost` (currently `content.gd:643-645`) to note the state now lives per-generator in `BoardModel`:

```gdscript
## The temporary BOOST (§6/§10 coin sink). One activation arms BOOST_TAPS taps of +BOOST_BONUS items on ONE
## generator, then it expires. The per-generator tap counts live in BoardModel.gen_boost (cell-keyed); this
## module keeps only the constants. Replaces the old board-wide grove["boost_taps"] counter.
```

- [ ] **Step 4: Run the full grove + engine suites, verify they pass**

Run: `make test 2>&1 | tail -40`
Expected: every suite PASS; the per-suite timing table shows no FAIL/crash.

- [ ] **Step 5: Commit**

```bash
cd /Users/xup/dh/wt-pergen-boost
git add engine/scripts/core/content.gd games/grove/tests/grove_economy_tests.gd
git commit -m "refactor(content): drop the global boost seam (state now per-generator)"
```

---

## Final verification + merge

- [ ] **Run the full sweep:** `make test 2>&1 | tail -40` — all suites PASS.
- [ ] **Manual smoke (optional, see CLAUDE.md quiet-godot):** boost generator A; confirm only A sparkles, A's taps decay on A's pops, B is unaffected; boost B too (both live); merge A+B → taps combine; bag a boosted gen → re-place restores taps; with a map-3 charge in stock the chip reads "Free" and spends a charge.
- [ ] **Merge to main + clean up the worktree** (from the primary tree, per project workflow): fast-forward/merge `pergen-boost` into `main`, then `git worktree remove` + delete the branch. Run `make import` in the main tree if any baked art changed (none expected here).

## Self-review notes (author check)

- **Spec coverage:** decisions 1–7 + migration + tests all map to tasks (1: model+serialize+migration; 2: stackable/re-buy/tap/indicator/label; 3: free charge; 4: seam removal). ✓
- **Type consistency:** `arm_gen_boost(cell, taps)`, `consume_gen_boost(cell)`, `is_gen_boosted(cell)`, `gen_boost_at(cell)` used identically across Tasks 1–3; `_activate_gen_boost(cell)` and `_gen_boost_bonus(cell)` and `_gen_info_text(gid, cell)` consistent in board.gd; `Habitat.spend_boost_charge()` defined in Task 3 before use. ✓
- **No placeholders:** every code step shows full before/after. ✓
