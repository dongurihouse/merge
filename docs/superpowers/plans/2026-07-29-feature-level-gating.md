# Feature Level Gating Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gate five shipped features (weather, cascade, mastery, soil/magnet improvements, rush) behind level thresholds, and give each a wordless reveal taught by the board itself.

**Architecture:** One data table (`FEATURE_LEVEL` in game data) drives a new `core/feature_gate.gd`, which answers `armed` (rules live) and `revealed` (player has been shown it) as two separate states. A new `ui/teach_registry.gd` replaces board.gd's hand-maintained pair of teach lists with one ordered spec array, so the eligibility check and the "all taught" check can no longer drift apart.

**Tech Stack:** Godot 4.6, GDScript. Headless SceneTree test suites via `python3 engine/tools/run_suites.py`.

**Spec:** `docs/superpowers/specs/2026-07-29-feature-level-gating-design.md`

## Global Constraints

- **Never edit the main worktree.** A PreToolUse hook blocks it. All work happens in the worktree this plan was dispatched into.
- **Run every test and capture in the FOREGROUND.** Backgrounding a test run hangs a subagent — it never receives the completion notification.
- **Layering:** `core/` imports `core/` only. `ui/` imports `core/` and `ui/`, never `scenes/`. `scenes/` may import both.
- **After every change run `make test-fast` first** (engine suites, a few seconds). Run the full `make test` only before handing the task back.
- **New `.gd` files need `make import` before commit** — a headless `-s` run generates no `.uid`, and an untracked `.uid` aborts the branch→main merge.
- **A new test suite must be named in three places or `engine/tests/suite_registry_tests.gd` fails:** `GROVE_TESTS` in `Makefile`, the suite list in `README.md:38`, and the suite list in `CLAUDE.md`.
- **Level in a test is set by the coin clock:** `coins_at_level(L) = (L-1)²` with the live dials, so `Save.earn_coins(G.coins_at_level(L))` on a fresh save lands exactly on level `L`.
- **RNG-consuming edits shift the whole stream.** Any assertion about drop contents compares distributions across a seed sweep, never a single seed's before/after.

---

## File Structure

**Created:**
- `engine/scripts/core/feature_gate.gd` — `armed` / `revealed` / `mark_revealed`. The only place a level threshold is compared.
- `engine/scripts/ui/teach_registry.gd` — `eligible(specs)` / `complete(specs)` over one spec array. No board knowledge; scenes supply the specs.
- `games/grove/tests/grove_gating_tests.gd` — the new cross-cutting machinery's suite.

**Modified:**
- `games/grove/grove_data.gd` — `FEATURE_LEVEL`, `MAGNET_STAGE_MERGES`
- `engine/scripts/core/content.gd` — re-export both
- `engine/scripts/core/sky.gd` — `gate_open()` delegates
- `engine/scripts/core/mastery.gd` — `rank()` reveal clamp
- `engine/scripts/core/save.gd` — drop the two rush-intro accessors
- `engine/scripts/core/save_migrate.gd` — drop the orphan `rush_intro_seen` key
- `engine/scripts/core/explore.gd` — drop `RUSH_INTRO_SHOWS` / `rush_intro_should_show`
- `engine/scripts/scenes/board.gd` — gate read sites, teach specs, mastery reveal beat
- `engine/scripts/scenes/map.gd` — rush gate + rush teach spec
- `engine/scripts/scenes/explore_rush.gd` — drop the tutorial-image modal
- `engine/scripts/ui/residents.gd` — rush gate on the Expedition pill
- `engine/scripts/ui/debug.gd` — the feature-gate panel
- `Makefile`, `README.md`, `CLAUDE.md` — the new suite
- `games/grove/tools/rush_shot.gd`, `games/grove/tests/grove_explore_tests.gd`, `games/grove/tests/grove_rush_ftue_tests.gd` — rush-intro fallout

---

### Task 1: The gate table and `feature_gate.gd`

Pure addition. Nothing reads the gate yet, so no behavior changes and the full sweep must stay green.

**Files:**
- Create: `engine/scripts/core/feature_gate.gd`
- Create: `games/grove/tests/grove_gating_tests.gd`
- Modify: `games/grove/grove_data.gd`, `engine/scripts/core/content.gd`, `Makefile:16`, `README.md:38`, `CLAUDE.md`

**Interfaces:**
- Produces: `FeatureGate.armed(id: String) -> bool`, `FeatureGate.revealed(id: String) -> bool`, `FeatureGate.mark_revealed(id: String) -> void`, `FeatureGate.IDS: Array`. `G.FEATURE_LEVEL: Dictionary`. Every later task consumes these.

- [ ] **Step 1: Add the table to game data**

In `games/grove/grove_data.gd`, directly after the `SCENE_END_LEVEL` const (line ~176):

```gdscript
# --- FEATURE UNLOCK LEVELS (spec 2026-07-29) ---------------------------------------------
# The level at which each gated feature's RULES go live. Revealing it to the player is a
# separate state (FeatureGate.revealed) driven by the board, not by this table.
# The first four land on MIN_LEVEL board-growth beats so a new verb arrives with a new ring
# of cells; L16 is the last beat, so magnet and rush are spaced by input cost alone.
const FEATURE_LEVEL := {
	"weather":  4,
	"cascade":  7,
	"mastery": 10,
	"soil":    13,
	"magnet":  18,
	"rush":    22,
}

# Merges after the magnet gate ARMS before the teach gives up on the drop table and grants a
# seed outright. The drop path is meant to be the common one — the seed should read as loot.
const MAGNET_STAGE_MERGES := 40
```

- [ ] **Step 2: Re-export from content.gd**

In `engine/scripts/core/content.gd`, beside the other `D.` re-exports (near line 116):

```gdscript
const FEATURE_LEVEL = D.FEATURE_LEVEL
const MAGNET_STAGE_MERGES = D.MAGNET_STAGE_MERGES
```

- [ ] **Step 3: Write the failing suite**

Create `games/grove/tests/grove_gating_tests.gd`:

```gdscript
extends "res://games/grove/tests/grove_test_base.gd"
## Feature level gating: the unlock table, FeatureGate's two states, the teach
## registry, and the mastery reveal clamp. Spec: docs/superpowers/specs/2026-07-29-feature-level-gating-design.md

const FeatureGate = preload("res://engine/scripts/core/feature_gate.gd")

func _initialize() -> void:
	begin("grove · feature gating")
	await process_frame
	_test_table_thresholds()
	_test_unknown_id_fails_closed()
	_test_revealed_is_separate_from_armed()
	finish()

## Set the coin clock so G.level() reads exactly `lvl`.
func _set_level(lvl: int) -> void:
	Save.earn_coins(G.coins_at_level(lvl) - Save.coins_earned_lifetime())

func _test_table_thresholds() -> void:
	for id in G.FEATURE_LEVEL:
		var want := int(G.FEATURE_LEVEL[id])
		fresh("gate_" + String(id))
		_set_level(want - 1)
		ok(not FeatureGate.armed(String(id)),
			"%s is dormant at L%d (one below its gate)" % [id, want - 1])
		fresh("gate_on_" + String(id))
		_set_level(want)
		ok(FeatureGate.armed(String(id)) == _extra_met(String(id)),
			"%s arms at L%d once its extra condition is met" % [id, want])

## The AND terms that are NOT the level. A fresh save meets none of them, so this documents
## which ids can arm on level alone.
func _extra_met(id: String) -> bool:
	return id == "cascade" or id == "mastery" or id == "magnet"

func _test_unknown_id_fails_closed() -> void:
	fresh("gate_unknown")
	ok(not FeatureGate.armed("no_such_feature"),
		"an unknown gate id fails CLOSED (never leaks an ungated feature)")

func _test_revealed_is_separate_from_armed() -> void:
	fresh("gate_reveal")
	_set_level(G.FEATURE_LEVEL["cascade"])
	ok(FeatureGate.armed("cascade"), "cascade arms at its level")
	ok(not FeatureGate.revealed("cascade"), "arming does NOT reveal")
	FeatureGate.mark_revealed("cascade")
	ok(FeatureGate.revealed("cascade"), "mark_revealed persists to the ftue ledger")
```

- [ ] **Step 4: Wire the suite into the three lists**

`Makefile:16` — append to `GROVE_TESTS`:
```
games/grove/tests/grove_gating_tests
```

`README.md:38` — append `` `grove_gating_tests` `` to the backticked suite list.

`CLAUDE.md` — append `grove_gating_tests` to the parenthesised suite list in the Testing section.

- [ ] **Step 5: Run the suite to verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_gating_tests`
Expected: FAIL — `Could not resolve script res://engine/scripts/core/feature_gate.gd` (the preload has no file yet).

- [ ] **Step 6: Write `feature_gate.gd`**

Create `engine/scripts/core/feature_gate.gd`:

```gdscript
extends RefCounted
## FEATURE GATES — the level at which a feature's RULES go live, and whether the player has
## been SHOWN it. Two independent states; see docs/superpowers/specs/2026-07-29-feature-level-gating-design.md
##
## armed(id)    the level threshold has passed and every extra condition is met
## revealed(id) the teach has completed (persisted in the ftue ledger as "unlock_<id>")
##
## A feature sits ARMED but unrevealed until the board offers the situation its teach needs.
##
## Unknown id → push_warning + FALSE. This is the INVERSE of Features.on(), deliberately: an
## unknown flag must not silently kill a shipped feature, but an unknown GATE must not silently
## leak an ungated one. Fail closed.
##
## core/ layer: imports core/ only.

const G = preload("res://engine/scripts/core/content.gd")
const Save = preload("res://engine/scripts/core/save.gd")
const Features = preload("res://engine/scripts/core/features.gd")
const Bucket = preload("res://engine/scripts/core/bucket.gd")

const LEDGER_PREFIX := "unlock_"

## The features.gd flag each gate rides on. An id absent here has no flag (rush).
const GATE_FLAG := {
	"weather": "weather_hours",
	"cascade": "cascade",
	"mastery": "mastery",
	"soil": "improvements",
	"magnet": "improvements",
}

static func ids() -> Array:
	return G.FEATURE_LEVEL.keys()

static func level_for(id: String) -> int:
	return int(G.FEATURE_LEVEL.get(id, 0))

static func armed(id: String) -> bool:
	if not G.FEATURE_LEVEL.has(id):
		push_warning("FeatureGate.armed(\"%s\"): unknown gate — failing CLOSED" % id)
		return false
	if GATE_FLAG.has(id) and not Features.on(String(GATE_FLAG[id])):
		return false
	if G.level() < level_for(id):
		return false
	return _extra(id)

## The per-feature AND terms — every condition shipping before this spec, preserved.
static func _extra(id: String) -> bool:
	match id:
		"weather":
			return Save.ftue_seen("merge") and Save.ftue_seen("gen_tap")
		"soil":
			return Save.board_tutorial_seen()
		"rush":
			return Bucket.cells_total() > 0
	return true

static func revealed(id: String) -> bool:
	return Save.ftue_seen(LEDGER_PREFIX + id)

static func mark_revealed(id: String) -> void:
	Save.mark_ftue_seen(LEDGER_PREFIX + id)
```

- [ ] **Step 7: Run the suite to verify it passes**

Run: `make test-one SUITE=games/grove/tests/grove_gating_tests`
Expected: PASS — `== N passed, 0 failed ==`, exit 0, zero `SCRIPT ERROR`.

- [ ] **Step 8: Verify nothing else broke and the registry guard is satisfied**

Run: `make test`
Expected: every suite passes. `suite_registry_tests` in particular must pass — it is the guard that the Makefile, README and CLAUDE.md now name the same set.

- [ ] **Step 9: Generate the .uid files and commit**

```bash
make import
git add engine/scripts/core/feature_gate.gd engine/scripts/core/feature_gate.gd.uid \
        games/grove/tests/grove_gating_tests.gd games/grove/tests/grove_gating_tests.gd.uid \
        games/grove/grove_data.gd engine/scripts/core/content.gd Makefile README.md CLAUDE.md
git commit -m "feat(gating): the feature unlock table and FeatureGate's two states"
```

---

### Task 2: Wire the five gate read sites

The table starts controlling the game. Soil moves 6 → 13 here; magnet leaves the drop table below L18.

**Files:**
- Modify: `engine/scripts/core/sky.gd:86`, `engine/scripts/scenes/board.gd` (`_prepare_chain`, `_maybe_soil_ftue`, `_blocked_seed_drop_lines`), `engine/scripts/scenes/map.gd:1166`, `engine/scripts/ui/residents.gd:307`
- Test: `games/grove/tests/grove_gating_tests.gd`

**Interfaces:**
- Consumes: `FeatureGate.armed(id)` from Task 1.
- Produces: no new symbols. Later tasks rely on these sites being the *only* level comparisons.

- [ ] **Step 1: Write the failing tests**

Append to `games/grove/tests/grove_gating_tests.gd`, and add the three `await` lines to `_initialize()` before `finish()`:

```gdscript
const Improvements = preload("res://engine/scripts/core/improvements.gd")
const SkyLogic = preload("res://engine/scripts/core/sky.gd")

func _test_weather_gate_needs_the_level() -> void:
	fresh("gate_weather_level")
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	_set_level(G.FEATURE_LEVEL["weather"] - 1)
	ok(not SkyLogic.gate_open(),
		"both FTUE verbs seen is no longer enough — the weather gate also needs L%d" % int(G.FEATURE_LEVEL["weather"]))
	_set_level(G.FEATURE_LEVEL["weather"])
	ok(SkyLogic.gate_open(), "weather opens at its level with both verbs seen")

func _test_magnet_seed_cannot_drop_before_its_level() -> void:
	fresh("gate_magnet_drop")
	_set_level(G.FEATURE_LEVEL["magnet"] - 1)
	var magnet_line := Improvements.seed_line_for_kind(Improvements.KIND_MAGNET)
	var seen_below := 0
	# A SEED SWEEP, not one seed: a single stream proves nothing about a weighted table.
	for s in range(1, 60):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		for _i in range(40):
			if int(G.pick_special_drop(rng, [magnet_line]) / 100.0) == magnet_line:
				seen_below += 1
	ok(seen_below == 0,
		"the magnet seed line never drops while the gate is unarmed (%d hits over 59 seeds)" % seen_below)

func _test_soil_ftue_level_comes_from_the_table() -> void:
	ok(int(G.FEATURE_LEVEL["soil"]) == 13,
		"the soil teach's level is the table's 13, not the retired literal 6")
```

- [ ] **Step 2: Run to verify they fail**

Run: `make test-one SUITE=games/grove/tests/grove_gating_tests`
Expected: FAIL — the weather assertion fails, because `gate_open()` still ignores the level.

- [ ] **Step 3: Delegate the weather gate**

In `engine/scripts/core/sky.gd`, add the preload beside the existing ones and replace `gate_open()` (line 86):

```gdscript
const FeatureGate = preload("res://engine/scripts/core/feature_gate.gd")

# The gift gate now reads ONE place. The merge + gen_tap FTUE terms did not go away — they
# are FeatureGate._extra("weather"), joined by the L4 threshold.
static func gate_open() -> bool:
	return FeatureGate.armed("weather")
```

- [ ] **Step 4: Gate the cascade**

In `engine/scripts/scenes/board.gd`, add the preload beside the other core preloads, then in `_prepare_chain()` replace the flag check:

```gdscript
const FeatureGate = preload("res://engine/scripts/core/feature_gate.gd")
```

```gdscript
	if not FeatureGate.armed("cascade"):
		_refresh_chain_board_visibility()
		return
```

And in the second cascade site (the guide-path check, `if not Features.on("cascade") or board == null or board.is_gen(from):`):

```gdscript
	if not FeatureGate.armed("cascade") or board == null or board.is_gen(from):
```

And the third (`_show_cascade_drag_guides`'s opening `if not Features.on("cascade") or board_area == null ...`):

```gdscript
	if not FeatureGate.armed("cascade") or board_area == null or not is_instance_valid(board_area):
```

- [ ] **Step 5: Move the soil level onto the table**

In `board.gd::_maybe_soil_ftue()`, delete the hardcoded level check and fold the condition into the gate:

```gdscript
func _maybe_soil_ftue() -> void:
	if Save.ftue_seen("soil") or not FeatureGate.armed("soil"):
		return
```

The two lines this replaces are `if not _improvements_enabled() or Save.ftue_seen("soil") or not Save.board_tutorial_seen():` / `return` and `if G.level() < 6:` / `return`. Both conditions survive inside `FeatureGate.armed("soil")` — the `improvements` flag as its `GATE_FLAG` entry, `board_tutorial_seen()` as its `_extra`.

- [ ] **Step 6: Gate the magnet seed out of the drop table**

Replace `board.gd::_blocked_seed_drop_lines()`:

```gdscript
func _blocked_seed_drop_lines() -> Array:
	var blocked: Array = []
	if not FeatureGate.armed("soil"):
		blocked.append(Improvements.seed_line_for_kind(Improvements.KIND_SOIL))
	if not FeatureGate.armed("magnet"):
		blocked.append(Improvements.seed_line_for_kind(Improvements.KIND_MAGNET))
	if blocked.is_empty():
		return Improvements.blocked_seed_drop_lines(board, bag)
	# An unarmed kind is blocked OUTRIGHT; an armed one still respects the held-unplaced filter.
	for line in Improvements.blocked_seed_drop_lines(board, bag):
		if not blocked.has(int(line)):
			blocked.append(int(line))
	return blocked
```

- [ ] **Step 7: Gate the Expedition entry**

In `engine/scripts/scenes/map.gd`, add the preload, then replace the bucket-dock condition (`var exped_open := cells_total > 0`):

```gdscript
	var exped_open := FeatureGate.armed("rush")
```

In `engine/scripts/ui/residents.gd:307`, replace the pill's condition:

```gdscript
	if on_expedition.is_valid() and FeatureGate.armed("rush"):
```

with the preload added at the top of the file. `Bucket.cells_total() > 0` is not lost — it is `FeatureGate._extra("rush")`.

- [ ] **Step 8: Run the gating suite**

Run: `make test-one SUITE=games/grove/tests/grove_gating_tests`
Expected: PASS.

- [ ] **Step 9: Run the full sweep and read the failures**

Run: `make test`

Expected: **failures in `grove_sky_tests`, `grove_improvements_tests`, `grove_explore_tests` and `grove_cascade_tests`.** These are real and expected — those suites set up boards at level 1 and assert on features that now require L4–L22. Fix each by raising the fixture's level with `Save.earn_coins(G.coins_at_level(<gate>))` in the suite's own setup, **not** by weakening the gate. `grove_sky_tests:282-288` in particular asserts the old two-verb gate directly; update it to also set L4.

Do not proceed until `make test` is fully green. Report the count of tests you had to re-fixture.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat(gating): the five gate read sites read the table"
```

---

### Task 3: The mastery reveal clamp

**Files:**
- Modify: `engine/scripts/core/mastery.gd`
- Test: `games/grove/tests/grove_gating_tests.gd`

**Interfaces:**
- Consumes: `FeatureGate.revealed("mastery")`.
- Produces: `Mastery.rank(line)` now returns `min(true_rank, 1)` until revealed. `Mastery.true_rank(line)` exposes the unclamped value for the reveal beat in Task 7.

- [ ] **Step 1: Write the failing test**

Append to `grove_gating_tests.gd` and add its `await`-free call to `_initialize()`:

```gdscript
const Mastery = preload("res://engine/scripts/core/mastery.gd")
const ShopUI = preload("res://engine/scripts/ui/shop.gd")

func _test_mastery_rank_is_clamped_until_revealed() -> void:
	fresh("gate_mastery_clamp")
	_set_level(G.FEATURE_LEVEL["mastery"])
	var line := int(G.ZONE_BASE_LINES[0])
	# Bank a meter well past threshold 2 — the case that would otherwise dump scissors
	# in the same beat as the mastery reveal.
	Save.grove()["mastery"] = {str(line): int(G.MASTERY_THRESHOLDS[2])}
	ok(Mastery.true_rank(line) >= 3, "the banked meter really is past rank 2")
	ok(Mastery.rank(line) == 1, "rank reads 1 while mastery is unrevealed")
	ok(not ShopUI.scissors_available(),
		"scissors CANNOT unlock in the same beat as the mastery reveal")
	FeatureGate.mark_revealed("mastery")
	ok(Mastery.rank(line) == Mastery.true_rank(line), "the clamp lifts on reveal")
	ok(ShopUI.scissors_available(), "scissors becomes available once mastery is revealed")
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_gating_tests`
Expected: FAIL — `Invalid call. Nonexistent function 'true_rank'`.

- [ ] **Step 3: Add the clamp**

In `engine/scripts/core/mastery.gd`, add the preload and replace `rank()`:

```gdscript
const FeatureGate = preload("res://engine/scripts/core/feature_gate.gd")

## The rank the meter has actually earned. Pure read — no reveal clamp. The mastery reveal
## beat (board.gd) and the rank-up queue use this; everything else uses rank().
static func true_rank(line: int) -> int:
	return rank_for_meter(meter(line))

## The DISPLAYED rank. Clamped to 1 until the mastery feature has been revealed, so a player
## arriving at the L10 gate with a deep meter does not also unlock scissors
## (ui/shop.gd::scissors_available reads any_rank_at_least(2)) in the same moment. The banked
## overflow is not lost — it carries, and rank 2 arrives shortly after on its own.
static func rank(line: int) -> int:
	var r := true_rank(line)
	if not FeatureGate.revealed("mastery"):
		return mini(r, 1)
	return r
```

`rank_for_meter()` is untouched — the clamp is on the save-reading accessor only, so pure-rule callers keep their arithmetic.

- [ ] **Step 4: Run to verify it passes**

Run: `make test-one SUITE=games/grove/tests/grove_gating_tests`
Expected: PASS.

- [ ] **Step 5: Run the full sweep**

Run: `make test`
Expected: green. If a mastery suite asserts a rank ≥ 2 on an unrevealed save, mark it revealed in that fixture's setup — the suite is testing rank arithmetic, not the reveal.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(gating): clamp the displayed mastery rank until its reveal"
```

---

### Task 4: `teach_registry.gd`, with the existing three teaches moved onto it

**Behavior-preserving refactor.** No new teaches. This is deliberate: the registry gets proved against known-good behavior before it carries anything new.

**Files:**
- Create: `engine/scripts/ui/teach_registry.gd`
- Modify: `engine/scripts/scenes/board.gd` (`_maybe_hand_hint`, `_hand_hint_eligible`, `_hand_hint_ledger_complete`, `_hand_hint_rects`)
- Test: `games/grove/tests/grove_gating_tests.gd`

**Interfaces:**
- Produces: `TeachRegistry.eligible(specs: Array) -> String`, `TeachRegistry.complete(specs: Array) -> bool`. A spec is `{"id": String, "ledger": String, "gate": Callable, "ready": Callable, "rects": Callable, "gesture": String}`. `board.gd::_teach_specs() -> Array`.

- [ ] **Step 1: Write the failing test**

Append to `grove_gating_tests.gd`:

```gdscript
const TeachRegistry = preload("res://engine/scripts/ui/teach_registry.gd")

func _spec(id: String, ledger: String, gate: bool, ready: bool) -> Dictionary:
	return {
		"id": id, "ledger": ledger,
		"gate": func() -> bool: return gate,
		"ready": func() -> bool: return ready,
		"rects": func() -> Array: return [Rect2(), Rect2()],
		"gesture": "tap",
	}

func _test_registry_picks_the_first_unseen_armed_ready_spec() -> void:
	fresh("registry_pick")
	var specs := [
		_spec("a", "t_a", true, false),   # armed but the board is not ready
		_spec("b", "t_b", false, true),   # ready but unarmed
		_spec("c", "t_c", true, true),    # the first that qualifies
	]
	ok(TeachRegistry.eligible(specs) == "c", "eligible() skips not-ready and unarmed specs")
	Save.mark_ftue_seen("t_c")
	ok(TeachRegistry.eligible(specs) == "", "a taught spec is not offered again")

## THE assertion the old two-list design could not carry: complete() is derived from the SAME
## array eligible() reads, so a teach added to one can no longer be missing from the other.
func _test_registry_complete_is_derived_from_the_same_array() -> void:
	fresh("registry_complete")
	var specs := [_spec("a", "t_a", true, true), _spec("b", "t_b", true, true)]
	ok(not TeachRegistry.complete(specs), "complete() is false while any ledger key is unseen")
	Save.mark_ftue_seen("t_a")
	ok(not TeachRegistry.complete(specs), "still false with one of two seen")
	Save.mark_ftue_seen("t_b")
	ok(TeachRegistry.complete(specs), "true only when EVERY spec's ledger key is seen")

## complete() must never touch the board: board.gd calls it on every mutation BEFORE the
## frame await, so a board scan there would cost a scan per merge.
func _test_registry_complete_does_not_call_ready() -> void:
	fresh("registry_cheap")
	var called := [false]
	var spec := _spec("a", "t_a", true, true)
	spec["ready"] = func() -> bool:
		called[0] = true
		return true
	TeachRegistry.complete([spec])
	ok(not called[0], "complete() is ledger-only — it never invokes ready()")
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_gating_tests`
Expected: FAIL — `Could not resolve script res://engine/scripts/ui/teach_registry.gd`.

- [ ] **Step 3: Write the registry**

Create `engine/scripts/ui/teach_registry.gd`:

```gdscript
extends RefCounted
## THE TEACH REGISTRY — one ordered spec array, two derived readers.
##
## This replaces board.gd's hand-maintained pair (_hand_hint_eligible / _hand_hint_ledger_complete),
## whose own comment warned: "a new teach added there and forgotten here is short-circuited before
## eligibility ever runs — it silently never appears, with no error and no failing test."
## Both readers now derive from the SAME array, so they cannot disagree.
##
## A spec:
##   id      the teach's name, and the hand-hint id the scene tracks
##   ledger  the Save.ftue_seen key; several ids may share one (soil_seed covers soil_place)
##   gate    Callable() -> bool — is the feature armed? (FeatureGate.armed, usually)
##   ready   Callable() -> bool — does the board offer this teach's situation RIGHT NOW?
##   rects   Callable() -> Array — [source_rect, target_rect], or [] when a node is missing
##   gesture HandHint.GESTURE_DRAG or GESTURE_TAP
##
## ui/ layer: imports core/ and ui/ only, never scenes/. The specs come FROM the scene.

const Save = preload("res://engine/scripts/core/save.gd")

## The first spec that is unseen AND armed AND ready. "" when none can fire.
static func eligible(specs: Array) -> String:
	for s in specs:
		if not (s is Dictionary):
			continue
		var spec: Dictionary = s
		if Save.ftue_seen(String(spec.get("ledger", ""))):
			continue
		var gate: Callable = spec.get("gate", Callable())
		if gate.is_valid() and not bool(gate.call()):
			continue
		var ready: Callable = spec.get("ready", Callable())
		if ready.is_valid() and not bool(ready.call()):
			continue
		return String(spec.get("id", ""))
	return ""

## Every spec's ledger key is seen — "no teach can possibly be live".
## LEDGER-ONLY BY CONTRACT: board.gd calls this on every board mutation before its frame await,
## so this must never invoke ready() or otherwise scan the board.
static func complete(specs: Array) -> bool:
	for s in specs:
		if not (s is Dictionary):
			continue
		if not Save.ftue_seen(String((s as Dictionary).get("ledger", ""))):
			return false
	return true

## The spec with this id, or {} — the scene's lookup for gesture + rects once eligible() has chosen.
static func spec_for(specs: Array, id: String) -> Dictionary:
	for s in specs:
		if s is Dictionary and String((s as Dictionary).get("id", "")) == id:
			return s
	return {}
```

- [ ] **Step 4: Run to verify it passes**

Run: `make test-one SUITE=games/grove/tests/grove_gating_tests`
Expected: PASS.

- [ ] **Step 5: Move board.gd's three existing teaches onto the registry**

Add `const TeachRegistry = preload("res://engine/scripts/ui/teach_registry.gd")` to board.gd's preloads, then replace `_hand_hint_eligible()` and `_hand_hint_ledger_complete()` with one spec builder plus two delegating readers. The `merge` / `gen_tap` / `soil_seed` / `soil_place` behavior must be **identical** — including that `soil_place` shares the `soil_seed` ledger key, and that soil's two beats take priority over merge and gen_tap once `Save.ftue_seen("soil")` is set:

```gdscript
# THE TEACH SPEC ARRAY — the single ordered list both readers derive from (ui/teach_registry.gd).
# Order IS priority. The soil beats come first because the seed is already on the board and a
# merge/gen teach behind it would point away from it.
func _teach_specs() -> Array:
	return [
		{
			"id": "soil_place", "ledger": "soil_seed",
			"gate": func() -> bool: return Save.ftue_seen("soil"),
			"ready": _soil_place_hint_ready,
			"rects": func() -> Array:
				if not _soil_place_hint_ready():
					return []
				return [_cell_local_rect(_selected_cell), _local_rect(_info_seed_place)],
			"gesture": HandHint.GESTURE_TAP,
		},
		{
			"id": "soil_seed", "ledger": "soil_seed",
			"gate": func() -> bool: return Save.ftue_seen("soil"),
			"ready": func() -> bool: return not _soil_seed_hint_cell().is_empty(),
			"rects": func() -> Array:
				var seed_cell := _soil_seed_hint_cell()
				if seed_cell.is_empty():
					return []
				return [Rect2(), _cell_local_rect(seed_cell[0])],
			"gesture": HandHint.GESTURE_TAP,
		},
		{
			"id": "merge", "ledger": "merge",
			"gate": func() -> bool: return true,
			"ready": func() -> bool: return not BoardLogic.find_mergeable_pair(board).is_empty(),
			"rects": _merge_teach_rects,
			"gesture": HandHint.GESTURE_DRAG,
		},
		{
			"id": "gen_tap", "ledger": "gen_tap",
			"gate": func() -> bool: return Save.ftue_seen("merge"),
			"ready": func() -> bool: return not _hand_hint_gen_cell().is_empty(),
			"rects": _gen_tap_teach_rects,
			"gesture": HandHint.GESTURE_TAP,
		},
	]

func _merge_teach_rects() -> Array:
	var pair := BoardLogic.find_mergeable_pair(board)
	if pair.size() < 2:
		return []
	var a: Control = piece_nodes.get(pair[0])
	var b: Control = piece_nodes.get(pair[1])
	if a == null or not is_instance_valid(a) or b == null or not is_instance_valid(b):
		return []
	return [_local_rect(a), _local_rect(b)]

func _gen_tap_teach_rects() -> Array:
	var gen_cell := _hand_hint_gen_cell()
	if gen_cell.is_empty():
		return []
	var gn: Control = gen_nodes.get(gen_cell[0])
	if gn == null or not is_instance_valid(gn):
		return []
	return [Rect2(), _local_rect(gn)]

func _hand_hint_eligible() -> String:
	return TeachRegistry.eligible(_teach_specs())

func _hand_hint_ledger_complete() -> bool:
	return TeachRegistry.complete(_teach_specs())
```

Then update `_maybe_hand_hint()` to take its gesture and rects from the chosen spec rather than from its own branches, and drop the now-unused `gen_cell` parameter threading:

```gdscript
	var want := _hand_hint_eligible()
	if want == "":
		_dismiss_hand_hint()
		return
	var spec := TeachRegistry.spec_for(_teach_specs(), want)
	var rects: Array = (spec.get("rects", Callable()) as Callable).call()
	if rects.size() < 2:
		_dismiss_hand_hint()
		return
	if _hand_hint != null and is_instance_valid(_hand_hint) and _hand_hint_id == want:
		_hand_hint.retarget(rects[0], rects[1])
		return
	_dismiss_hand_hint()
	_hand_hint = HandHint.present(self, String(spec.get("gesture", HandHint.GESTURE_TAP)), rects[0], rects[1])
	_hand_hint_id = want if _hand_hint != null else ""
```

Delete `_hand_hint_rects()` entirely — every branch now lives in a spec's `rects`. `HandHint.next_hint_id()` loses its only caller; leave the function in place for now (Task 5 removes it once no spec needs it).

- [ ] **Step 6: Prove the refactor changed no behavior**

Run: `make test-one SUITE=games/grove/tests/grove_ftue_tests`
Expected: PASS with the **same** assertion count as before the refactor. Record the count from `git stash`-ing your changes and running it first if you need the baseline — a changed count means behavior moved, which this task forbids.

Run: `make test`
Expected: fully green.

- [ ] **Step 7: Commit**

```bash
make import
git add -A
git commit -m "refactor(ftue): one teach spec array replaces the two hand-synced lists"
```

---

### Task 5: The weather and cascade teach specs

**Files:**
- Modify: `engine/scripts/scenes/board.gd`, `engine/scripts/ui/hand_hint.gd`
- Test: `games/grove/tests/grove_gating_tests.gd`

**Interfaces:**
- Consumes: `_teach_specs()` from Task 4, `FeatureGate.armed`/`revealed` from Task 1.
- Produces: ledger keys `unlock_weather`, `unlock_cascade`.

- [ ] **Step 1: Write the failing tests**

```gdscript
const BoardLogicRef = preload("res://engine/scripts/core/board_logic.gd")

func _test_cascade_teach_waits_for_a_real_chain() -> void:
	fresh("teach_cascade")
	_set_level(G.FEATURE_LEVEL["cascade"])
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	Save.mark_board_tutorial_seen()
	var h = board_host()
	await process_frame
	# With no 3+ chain on the board the cascade spec is armed but NOT ready, so it offers nothing.
	ok(h._hand_hint_eligible() != "cascade",
		"the cascade teach stays silent until the board actually offers a chain")
	h.queue_free()

func _test_cascade_teach_is_unarmed_below_its_level() -> void:
	fresh("teach_cascade_low")
	_set_level(G.FEATURE_LEVEL["cascade"] - 1)
	# The spec's own gate, read directly — independent of what the board happens to hold.
	ok(not FeatureGate.armed("cascade"),
		"the cascade teach cannot fire at L%d" % int(G.FEATURE_LEVEL["cascade"] - 1))

func _test_weather_teach_requires_a_pair_inside_the_patch() -> void:
	fresh("teach_weather")
	_set_level(G.FEATURE_LEVEL["weather"])
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	ok(FeatureGate.armed("weather"), "weather is armed at its level with both verbs seen")
	ok(not FeatureGate.revealed("weather"), "armed is not revealed")
```

- [ ] **Step 2: Run to verify they fail**

Run: `make test-one SUITE=games/grove/tests/grove_gating_tests`
Expected: FAIL — `_hand_hint_eligible` currently knows nothing about a "cascade" id, so the first assertion passes vacuously while the third fails on the missing ledger key. Confirm which assertions fail before implementing; a vacuous pass here means the test is not driving the real path.

- [ ] **Step 3: Add the two specs**

Insert into `_teach_specs()`, after `gen_tap` and before the soil beats (table order: weather L4, cascade L7, soil L13):

```gdscript
		{
			"id": "weather", "ledger": "unlock_weather",
			"gate": func() -> bool: return FeatureGate.armed("weather"),
			"ready": func() -> bool: return not _weather_teach_pair().is_empty(),
			"rects": _weather_teach_rects,
			"gesture": HandHint.GESTURE_DRAG,
		},
		{
			"id": "cascade", "ledger": "unlock_cascade",
			"gate": func() -> bool: return FeatureGate.armed("cascade"),
			"ready": func() -> bool: return not _cascade_teach_pair().is_empty(),
			"rects": _cascade_teach_rects,
			"gesture": HandHint.GESTURE_DRAG,
		},
```

With the four helpers:

```gdscript
# The mergeable pair the weather teach points at: one sitting INSIDE the live sky patch, so the
# taught gesture is "merge in the glow" rather than a merge that happens to be anywhere.
func _weather_teach_pair() -> Array:
	if _sky_state.is_empty() or not SkyLogic.gate_open():
		return []
	var pair := BoardLogic.find_mergeable_pair(board)
	if pair.size() < 2:
		return []
	if not SkyLogic.in_patch(_sky_state, pair[0]) and not SkyLogic.in_patch(_sky_state, pair[1]):
		return []
	return pair

func _weather_teach_rects() -> Array:
	var pair := _weather_teach_pair()
	if pair.size() < 2:
		return []
	var a: Control = piece_nodes.get(pair[0])
	var b: Control = piece_nodes.get(pair[1])
	if a == null or not is_instance_valid(a) or b == null or not is_instance_valid(b):
		return []
	return [_local_rect(a), _local_rect(b)]

# The pair whose merge would TIP a real cascade — the same predicate _prepare_chain computes,
# so the teach can never point at a drag that turns out to be an ordinary merge.
func _cascade_teach_pair() -> Array:
	var pair := BoardLogic.find_mergeable_pair(board)
	if pair.size() < 2:
		return []
	if 1 + BoardLogic.chain_path(board, pair[0], pair[1]).size() < CHAIN_MIN_N:
		return []
	return pair

func _cascade_teach_rects() -> Array:
	var pair := _cascade_teach_pair()
	if pair.size() < 2:
		return []
	var a: Control = piece_nodes.get(pair[0])
	var b: Control = piece_nodes.get(pair[1])
	if a == null or not is_instance_valid(a) or b == null or not is_instance_valid(b):
		return []
	return [_local_rect(a), _local_rect(b)]
```

- [ ] **Step 4: Bank the two reveals at their real completion points**

In the merge-completion path that already calls `_end_hand_hint("merge")`, add — after the merge has landed and its drops have rolled:

```gdscript
	if _hand_hint_id == "weather" and SkyLogic.gate_open() and SkyLogic.in_patch(_sky_state, b):
		_end_hand_hint("weather")
```

In `_finish_chain()`, where a completed cascade run is banked:

```gdscript
	if _hand_hint_id == "cascade" and _chain_n >= CHAIN_MIN_N:
		_end_hand_hint("cascade")
```

`_end_hand_hint(id)` writes `Save.mark_ftue_seen(id)` — for these two the id IS the ledger key (`unlock_weather` / `unlock_cascade`), so pass the ledger key, not the spec id:

```gdscript
	_end_hand_hint("unlock_weather")
	_end_hand_hint("unlock_cascade")
```

and widen `_end_hand_hint`'s id-match to compare against the live spec's ledger:

```gdscript
func _end_hand_hint(ledger: String) -> void:
	if not Features.on("ftue_hand_hint"):
		_dismiss_hand_hint()
		return
	var live := TeachRegistry.spec_for(_teach_specs(), _hand_hint_id)
	if String(live.get("ledger", "")) == ledger:
		_dismiss_hand_hint()
	if Save.ftue_seen(ledger):
		return
	Save.mark_ftue_seen(ledger)
	_maybe_hand_hint()
```

This subsumes the special case `(id == "soil_seed" and _hand_hint_id == "soil_place")` — both specs already declare `"ledger": "soil_seen"`, so the lookup handles it. Update the existing `_end_hand_hint("merge")` / `_end_hand_hint("gen_tap")` / `_end_hand_hint("soil_seed")` call sites: their ids and ledger keys are identical, so they need no change.

- [ ] **Step 5: Retire the superseded helper**

`HandHint.next_hint_id()` now has no callers. Delete the function from `engine/scripts/ui/hand_hint.gd`, and delete `engine/tests/ftue_hand_hint_tests.gd`'s assertions on it. Delete func→next-func ranges only, never the comment block above a surviving function — a GDScript self-call to a deleted method is a parse error, not a runtime one.

- [ ] **Step 6: Run the tests**

Run: `make test-one SUITE=games/grove/tests/grove_gating_tests`
Run: `make test-one SUITE=games/grove/tests/grove_ftue_tests`
Run: `make test`
Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(gating): weather and cascade teach themselves off the board"
```

---

### Task 6: The magnet teach and its staging dial

**Files:**
- Modify: `engine/scripts/scenes/board.gd`, `engine/scripts/core/save.gd`
- Test: `games/grove/tests/grove_gating_tests.gd`

**Interfaces:**
- Consumes: `G.MAGNET_STAGE_MERGES` from Task 1, `_teach_specs()` from Task 4.
- Produces: ledger key `unlock_magnet`; save keys `magnet_armed_merges` (int).

- [ ] **Step 1: Write the failing test**

```gdscript
func _test_magnet_staging_waits_before_granting() -> void:
	fresh("teach_magnet_stage")
	_set_level(G.FEATURE_LEVEL["magnet"])
	ok(FeatureGate.armed("magnet"), "magnet arms at its level")
	ok(not Save.magnet_stage_due(),
		"the staging grant does NOT fire the moment the gate arms — the drop path gets its window")
	for _i in range(int(G.MAGNET_STAGE_MERGES)):
		Save.bump_magnet_armed_merges()
	ok(Save.magnet_stage_due(),
		"after %d armed merges with no seed held, the teach grants one outright" % int(G.MAGNET_STAGE_MERGES))
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_gating_tests`
Expected: FAIL — `Invalid call. Nonexistent function 'magnet_stage_due'`.

- [ ] **Step 3: Add the counter to save.gd**

```gdscript
# --- magnet teach staging (spec 2026-07-29 §5) -------------------------------------------
# Merges counted since the magnet gate armed. The teach prefers the seed to arrive as a DROP;
# this counter is how long it waits before giving up and granting one.
static func magnet_armed_merges() -> int:
	return int(grove().get("magnet_armed_merges", 0))

static func bump_magnet_armed_merges() -> void:
	grove()["magnet_armed_merges"] = magnet_armed_merges() + 1
	save_now()

static func magnet_stage_due() -> bool:
	return magnet_armed_merges() >= int(_G().MAGNET_STAGE_MERGES)
```

`save.gd` cannot preload `content.gd` (content imports save — a cycle). Use the deferred accessor the file already uses for this, or if none exists, take the threshold as a parameter instead:

```gdscript
static func magnet_stage_due(threshold: int) -> bool:
	return magnet_armed_merges() >= threshold
```

and have board.gd pass `G.MAGNET_STAGE_MERGES`. **Check which pattern `save.gd` already uses before choosing** — do not introduce a cycle. Update the test's call to match whichever you pick.

- [ ] **Step 4: Add the spec and the staging grant**

In `_teach_specs()`, after the soil beats:

```gdscript
		{
			"id": "magnet_place", "ledger": "unlock_magnet",
			"gate": func() -> bool: return FeatureGate.armed("magnet"),
			"ready": _magnet_place_hint_ready,
			"rects": func() -> Array:
				if not _magnet_place_hint_ready():
					return []
				return [_cell_local_rect(_selected_cell), _local_rect(_info_seed_place)],
			"gesture": HandHint.GESTURE_TAP,
		},
		{
			"id": "magnet_seed", "ledger": "unlock_magnet",
			"gate": func() -> bool: return FeatureGate.armed("magnet"),
			"ready": func() -> bool: return not _magnet_seed_hint_cell().is_empty(),
			"rects": func() -> Array:
				var seed_cell := _magnet_seed_hint_cell()
				if seed_cell.is_empty():
					return []
				return [Rect2(), _cell_local_rect(seed_cell[0])],
			"gesture": HandHint.GESTURE_TAP,
		},
```

The two helpers mirror soil's exactly, against `Improvements.KIND_MAGNET`:

```gdscript
func _magnet_seed_hint_cell() -> Array:
	var code := Improvements.seed_code_for_kind(Improvements.KIND_MAGNET)
	for cell in piece_nodes.keys():
		if board.item_at(cell) == code:
			var n: Control = piece_nodes.get(cell)
			if n != null and is_instance_valid(n):
				return [cell]
	return []

func _magnet_place_hint_ready() -> bool:
	if _selected_cell.x < 0:
		return false
	if board.item_at(_selected_cell) != Improvements.seed_code_for_kind(Improvements.KIND_MAGNET):
		return false
	return _info_seed_place != null and is_instance_valid(_info_seed_place) and _info_seed_place.visible
```

And the staging beat, called from the same place `_maybe_soil_ftue()` is called:

```gdscript
# The magnet teach prefers the seed to ARRIVE — armed, it is back in the drop table, so a merge
# eventually shakes one loose and it reads as loot. This is the giving-up path: after
# G.MAGNET_STAGE_MERGES armed merges with no seed ever held, grant one so the teach is not
# hostage to the RNG.
func _maybe_magnet_stage() -> void:
	if Save.ftue_seen("unlock_magnet") or not FeatureGate.armed("magnet"):
		return
	if _has_unplaced_seed(Improvements.KIND_MAGNET) \
		or board.improvement_count(Improvements.KIND_MAGNET) > 0:
		return
	Save.bump_magnet_armed_merges()
	if not Save.magnet_stage_due(int(G.MAGNET_STAGE_MERGES)):
		return
	var code := Improvements.seed_code_for_kind(Improvements.KIND_MAGNET)
	for c in board.empty_ground_cells():
		if board.can_build_improvement(c):
			board.place(c, code)
			_rebuild_all()
			_after_board_change()
			return
	if bag.size() < _bag_capacity():
		_bag_append(code)
```

- [ ] **Step 5: Run the tests**

Run: `make test-one SUITE=games/grove/tests/grove_gating_tests`
Run: `make test-one SUITE=games/grove/tests/grove_improvements_tests`
Run: `make test`
Expected: green.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(gating): the magnet teach, with the drop path given its window first"
```

---

### Task 7: The mastery reveal beat

The one reveal with no gesture. A fill-sweep, not a hand hint.

**Files:**
- Modify: `engine/scripts/scenes/board.gd`, `engine/scripts/ui/mastery_ring.gd`
- Test: `games/grove/tests/grove_gating_tests.gd`

**Interfaces:**
- Consumes: `Mastery.true_rank` from Task 3, `FeatureGate.revealed` from Task 1.
- Produces: `MasteryRing.sweep_to(frac: float, secs: float) -> void`.

- [ ] **Step 1: Write the failing test**

```gdscript
func _test_mastery_ring_hidden_until_revealed() -> void:
	fresh("reveal_mastery")
	_set_level(G.FEATURE_LEVEL["mastery"])
	Save.mark_ftue_seen("merge")
	Save.mark_ftue_seen("gen_tap")
	Save.mark_board_tutorial_seen()
	var line := int(G.ZONE_BASE_LINES[0])
	Save.grove()["mastery"] = {str(line): int(G.MASTERY_THRESHOLDS[0])}
	var h = board_host()
	await process_frame
	var rings_before := _count_nodes_named(h, "MasteryRing")
	ok(rings_before == 0, "no mastery ring is attached while the feature is unrevealed")
	FeatureGate.mark_revealed("mastery")
	h._refresh_mastery_chrome()
	await process_frame
	ok(_count_nodes_named(h, "MasteryRing") > 0, "the ring attaches once revealed")
	h.queue_free()

func _count_nodes_named(n: Node, want: String) -> int:
	var c := 0
	if n.name == want:
		c += 1
	for ch in n.get_children():
		c += _count_nodes_named(ch, want)
	return c
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_gating_tests`
Expected: FAIL on the first assertion — `_attach_mastery_chrome` currently attaches whenever `meter(line) > 0`, with no reveal condition.

- [ ] **Step 3: Gate the chrome on the reveal**

In `board.gd::_attach_mastery_chrome()`, add the condition after the flag check:

```gdscript
	if not FeatureGate.revealed("mastery"):
		return
```

and the same in `_refresh_mastery_chrome()`'s opening guard, so a ring already attached is torn down if the reveal is reset by the debug panel.

- [ ] **Step 4: Add the sweep to the ring**

In `engine/scripts/ui/mastery_ring.gd`:

```gdscript
## The REVEAL sweep: fill from empty up to the meter's banked value. Used once, on the first
## generator tap after the mastery gate arms — the ring has been filling invisibly since L1, and
## this is the beat that says so.
func sweep_to(frac: float, secs: float) -> void:
	progress = 0.0
	queue_redraw()
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		progress = v
		queue_redraw(), 0.0, clampf(frac, 0.0, 1.0), secs)
```

- [ ] **Step 5: Fire it on the first generator tap after arming**

In board.gd's generator-tap handler, before the existing tap behavior:

```gdscript
# THE MASTERY REVEAL — no gesture to teach (the player already taps generators), so this is a
# reward beat: the ring sweeps up to the value the meter has quietly held since L1, and the
# rank clamp lifts behind it.
func _maybe_mastery_reveal(cell: Vector2i) -> void:
	if not FeatureGate.armed("mastery") or FeatureGate.revealed("mastery"):
		return
	var line := _gen_line(board.gen_id_at(cell))
	if line <= 0 or Mastery.meter(line) <= 0:
		return
	FeatureGate.mark_revealed("mastery")
	_refresh_mastery_chrome()
	var gn: Control = gen_nodes.get(cell)
	if gn == null or not is_instance_valid(gn):
		return
	var ring := gn.get_node_or_null("MasteryRing") as MasteryRing
	if ring != null:
		ring.sweep_to(Mastery.rank_progress(line), 0.9)
	if Features.on("big_moment_shake"):
		FX.celebrate_at(self, _cell_local_rect(cell).get_center())
```

- [ ] **Step 6: Run the tests**

Run: `make test-one SUITE=games/grove/tests/grove_gating_tests`
Run: `make test`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(gating): the mastery reveal is a fill-sweep, not a hand hint"
```

---

### Task 8: The rush teach spec on the map

**Files:**
- Modify: `engine/scripts/scenes/map.gd`
- Test: `games/grove/tests/grove_gating_tests.gd`

**Interfaces:**
- Consumes: `TeachRegistry` from Task 4, `FeatureGate.armed("rush")` from Task 2.
- Produces: ledger key `unlock_rush`; `map.gd::_teach_specs() -> Array`.

- [ ] **Step 1: Write the failing test**

```gdscript
func _test_rush_teach_needs_level_and_a_bucket_cell() -> void:
	fresh("teach_rush")
	_set_level(G.FEATURE_LEVEL["rush"])
	ok(not FeatureGate.armed("rush"),
		"L%d alone does not arm rush — a completed building (bucket cell) is still required" % int(G.FEATURE_LEVEL["rush"]))
	complete_scene(0)
	ok(FeatureGate.armed("rush"), "rush arms with both the level and a bucket cell")
	ok(not FeatureGate.revealed("rush"), "armed is not revealed")
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test-one SUITE=games/grove/tests/grove_gating_tests`
Expected: FAIL if `complete_scene(0)` does not produce a bucket cell. Read `grove_test_base.gd:220 complete_scene()` and use whatever it actually grants; if it does not grant a cell, seed one directly via `Save.grove()` and say so in a comment.

- [ ] **Step 3: Add map.gd's one-entry registry**

```gdscript
const TeachRegistry = preload("res://engine/scripts/ui/teach_registry.gd")
const HandHint = preload("res://engine/scripts/ui/hand_hint.gd")

# The map's teach list. One entry today; the array shape is the point — a second map teach
# added here is automatically covered by complete(), which is what board.gd's old two-list
# design could not promise.
func _teach_specs() -> Array:
	return [
		{
			"id": "rush", "ledger": "unlock_rush",
			"gate": func() -> bool: return FeatureGate.armed("rush"),
			"ready": func() -> bool: return _expedition_button() != null,
			"rects": func() -> Array:
				var b := _expedition_button()
				if b == null:
					return []
				return [Rect2(), _local_rect(b)],
			"gesture": HandHint.GESTURE_TAP,
		},
	]

func _expedition_button() -> Control:
	var b := find_child("BucketExpeditionButton", true, false) as Control
	if b != null and is_instance_valid(b) and b.visible:
		return b
	return find_child("ResidentsExpeditionButton", true, false) as Control
```

- [ ] **Step 4: Present the hint and bank it**

Call a `_maybe_map_hand_hint()` — modelled on board.gd's `_maybe_hand_hint()` but reading map's own `_teach_specs()` — after the bucket dock rebuilds. Bank it where `_open_expedition()` runs:

```gdscript
	if not Save.ftue_seen("unlock_rush"):
		Save.mark_ftue_seen("unlock_rush")
		_dismiss_map_hand_hint()
```

- [ ] **Step 5: Run the tests**

Run: `make test-one SUITE=games/grove/tests/grove_gating_tests`
Run: `make test`
Expected: green.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(gating): the Expedition chip teaches its own first tap"
```

---

### Task 9: Retire the Rush intro image

**Files:**
- Modify: `engine/scripts/scenes/explore_rush.gd`, `engine/scripts/core/explore.gd`, `engine/scripts/core/save.gd`, `engine/scripts/core/save_migrate.gd`, `games/grove/tools/rush_shot.gd`, `games/grove/tests/grove_explore_tests.gd`, `games/grove/tests/grove_rush_ftue_tests.gd`
- Delete: `games/grove/assets/ui/kit/tutorial/how_to_play_rush.png` (and its `.import`)

**Interfaces:**
- Removes: `Explore.rush_intro_should_show()`, `Explore.RUSH_INTRO_SHOWS`, `Save.rush_intro_seen()`, `Save.mark_rush_intro_seen()`. No task after this may reference them.

- [ ] **Step 1: Confirm the asset has exactly one consumer before deleting it**

Run: `grep -rn "how_to_play_rush" --include="*.gd" --include="*.tscn" --include="*.json" .`
Expected: hits only in `engine/scripts/scenes/explore_rush.gd`. A hit anywhere else means the asset is still loaded at runtime and must not be deleted — report it and stop.

`ui/tutorial_image.gd` and `tutorial/how_to_play_board.png` **stay** — `board.gd:4687` still opens the L1 how-to-play through them.

- [ ] **Step 2: Delete the call site and its helpers**

From `engine/scripts/scenes/explore_rush.gd`, remove `RUSH_TUTORIAL_OVERLAY` (line 41), `RUSH_TUTORIAL_IMAGE` (line 42), the `TutorialImage` preload (line 32) **if nothing else in the file uses it**, `_open_rush_tutorial()` and its sibling accessor around line 595-598, and the call at 619-620. Delete func→next-func ranges as one edit — a self-call to a half-deleted method is a parse error.

From `engine/scripts/core/explore.gd`, remove `RUSH_INTRO_SHOWS` (line 41) and `rush_intro_should_show()` (lines 43-45) with its doc comment.

From `engine/scripts/core/save.gd`, remove `rush_intro_seen()` and `mark_rush_intro_seen()` (lines 490-495) with the comment block above them.

- [ ] **Step 3: Drop the orphan save key**

In `engine/scripts/core/save_migrate.gd`, follow the file's existing key-removal pattern to erase `rush_intro_seen` from the grove dictionary.

- [ ] **Step 4: Remove the fallout**

`games/grove/tools/rush_shot.gd` — delete the `Save.mark_rush_intro_seen()` call (line 30) and the `Save.rush_intro_seen()` term in the print at line 63.

`games/grove/tests/grove_explore_tests.gd` — delete `_test_rush_intro_hint()` (line 1964+) and its `_test_rush_intro_hint()` dispatch line at 35.

`games/grove/tests/grove_rush_ftue_tests.gd:23` — delete the `Save.mark_rush_intro_seen()` setup line and its comment. The two in-scene hand hints now have nothing covering them.

- [ ] **Step 5: Verify the parse and the whole sweep**

Run: `godot --check-only --script engine/scripts/scenes/explore_rush.gd`
Expected: no output, exit 0.

Run: `grep -rn "rush_intro\|RUSH_INTRO\|RUSH_TUTORIAL" --include="*.gd" .`
Expected: **zero hits.**

Run: `make test`
Expected: green — `grove_rush_ftue_tests` in particular must still pass, now that no popup covers the hints.

- [ ] **Step 6: Delete the asset and commit**

```bash
git rm games/grove/assets/ui/kit/tutorial/how_to_play_rush.png \
       games/grove/assets/ui/kit/tutorial/how_to_play_rush.png.import
make test
git add -A
git commit -m "refactor(rush): the two in-scene hand hints replace the full-screen intro image"
```

---

### Task 10: The debug panel, and the one batched capture

**Files:**
- Modify: `engine/scripts/ui/debug.gd`
- Test: `games/grove/tests/grove_gating_tests.gd`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Add the gate panel**

In `engine/scripts/ui/debug.gd`, beside the existing state-jump actions (`_act_unlock_map` at line 341 is the pattern to follow), add a per-gate arm and reveal action plus one reset:

```gdscript
# FEATURE GATES — reaching L18 by play is not a test procedure.
static func _act_arm_feature(host: Control, id: String) -> void:
	var need := FeatureGate.level_for(id)
	var have := G.coins_at_level(need) - Save.coins_earned_lifetime()
	if have > 0:
		Save.earn_coins(have)          # lift the coin clock to the gate's level
	if host.has_method("_rebuild_all"):
		host._rebuild_all()

static func _act_reveal_feature(_host: Control, id: String) -> void:
	FeatureGate.mark_revealed(id)

static func _act_reset_gates(_host: Control) -> void:
	var seen: Dictionary = Save.data.get("ftue_seen", {})
	for id in FeatureGate.ids():
		seen.erase(FeatureGate.LEDGER_PREFIX + String(id))
	Save.save_now()
```

Wire one menu row per `FeatureGate.ids()` entry, plus the reset. Guard the whole panel behind `OS.is_debug_build()` as `daily_debug` already is — none of this may be reachable in a release build.

- [ ] **Step 2: Assert the debug reset actually clears the ledger**

```gdscript
func _test_debug_reset_clears_every_unlock_key() -> void:
	fresh("gate_debug_reset")
	for id in FeatureGate.ids():
		FeatureGate.mark_revealed(String(id))
	for id in FeatureGate.ids():
		ok(FeatureGate.revealed(String(id)), "%s revealed before the reset" % id)
	Debug._act_reset_gates(null)
	for id in FeatureGate.ids():
		ok(not FeatureGate.revealed(String(id)), "%s cleared by the debug reset" % id)
```

- [ ] **Step 3: Guard against a decorative table entry**

```gdscript
## A FEATURE_LEVEL entry with no gate consumer is dead data that reads as coverage.
## Every id must be named by a live FeatureGate.armed()/revealed() call somewhere in the tree.
func _test_every_table_id_has_a_read_site() -> void:
	var sources := _gd_files_under("res://engine/scripts/")
	for id in G.FEATURE_LEVEL:
		var found := false
		for path in sources:
			var f := FileAccess.open(path, FileAccess.READ)
			if f == null:
				continue
			var text := f.get_as_text()
			if text.contains("\"%s\"" % id) and (text.contains("armed(") or text.contains("revealed(")):
				found = true
				break
		ok(found, "FEATURE_LEVEL[\"%s\"] has a live gate read site" % id)
```

Use `grove_test_base`'s existing coverage helper for `_gd_files_under` — `engine/tests/test_base.gd` already defines the shared "every .gd file under dir" function that `const_ssot_tests` uses. Do not write a second one.

- [ ] **Step 4: Run the whole sweep**

Run: `make test`
Expected: fully green, every suite.

- [ ] **Step 5: The one batched capture**

Two reveals cannot be judged by a passing suite — the cascade guide lighting the ladder, and the mastery fill-sweep. Take both in ONE launch, in the FOREGROUND:

```bash
printf '%s\n' 'grove hud /tmp/gate_cascade.png' 'grove played /tmp/gate_mastery.png' > /tmp/gate_plan.txt
make shot-batch PLAN=/tmp/gate_plan.txt
```

Then **look at both PNGs** and report what you see. Do not report this task complete on a passing suite alone — the spec (§8) requires the owner's eye on these two, so hand them over with your own read of each.

- [ ] **Step 6: Commit**

```bash
make import
git add -A
git commit -m "feat(gating): the debug gate panel, and the guard against decorative table entries"
```

---

## Self-Review

**Spec coverage:** §1 two states → Task 1. §2 table → Task 1. §3 `feature_gate.gd` + the six read sites → Tasks 1–2; mastery clamp → Task 3. §4 teach registry → Task 4. §5 reveals: cascade + weather → Task 5, mastery → Task 7, soil → Task 2 (level move only, mechanism already shipping), magnet → Task 6, rush → Task 8. §6 rush intro retirement → Task 9. §7 debug → Task 10. §8 verification: table thresholds (T1), no decorative entries (T10), fail closed (T1), registry sync (T4), registry order (T4/T5), mastery clamp (T3), magnet drop sweep (T2), rush retirement (T9), batched capture (T10). §9 out of scope → not implemented, correctly.

**Known gaps the implementer must close, flagged inline rather than papered over:**
- Task 6 Step 3 — `save.gd` cannot preload `content.gd` (cycle). The step gives both resolutions and instructs the implementer to check which pattern the file already uses. This is a real fork I could not resolve without reading `save.gd`'s full import strategy.
- Task 8 Step 2 — whether `complete_scene(0)` grants a bucket cell is unverified; the step says to read the helper and seed directly if not.

**Type consistency:** `FeatureGate.armed/revealed/mark_revealed/ids/level_for/LEDGER_PREFIX` are used identically in Tasks 1–10. `TeachRegistry.eligible/complete/spec_for` consistent across Tasks 4, 5, 6, 8. `Mastery.true_rank` defined in Task 3, consumed in Task 7. `MasteryRing.sweep_to(frac, secs)` defined and consumed in Task 7. Spec-id vs ledger-key is the one genuine trap — `soil_place`/`soil_seed` share ledger `soil_seed`, and `magnet_place`/`magnet_seed` share `unlock_magnet`; Task 5 Step 4 rewrites `_end_hand_hint` to key off the ledger for exactly this reason.
