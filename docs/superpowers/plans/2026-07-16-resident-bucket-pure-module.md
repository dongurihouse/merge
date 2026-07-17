# Resident Bucket Pure Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the global-resident-bucket logic (spec: `docs/superpowers/specs/2026-07-16-global-resident-bucket-design.md`) as a pure, dependency-free GDScript module with its own headless test suite — no game wiring, no changes to `habitat.gd` or any UI.

**Architecture:** One new static-func module, `engine/scripts/core/resident_bucket.gd`, that owns ALL bucket rules (hand, cells, placement, merging, per-line production, day ceilings, box rolls). It preloads nothing — no `Save`, `Game`, `Content`, or `BoardLogic`. State is a plain Dictionary passed into every call; time is an injected `now` (seconds) and randomness an injected `RandomNumberGenerator`. A later flip plan replaces `habitat.gd` with a thin adapter that persists this state in `Save` and feeds it real time/RNG.

**Tech Stack:** GDScript (Godot 4.6), headless SceneTree test suites run via `engine/tools/run_suites.py` (`make test-fast`).

## Global Constraints

- The module must not `preload`/`load` anything and must never read the clock or global RNG — `now` and `rng` are always parameters.
- All numeric dials are PROVISIONAL (sim-tuned later) and live in one `DEFAULTS` const; every production function accepts an optional `cfg` override so tests can pin dials.
- Spec invariant "merge always pays": for every line, each +1 to the line's Σtier must strictly increase production rate AND bank cap (tested by sweep).
- Day-ceiling lines (diamond) grant at most `day_cap` whole units per UTC day (day = `int(now / 86400.0)`), regardless of banked amount.
- Lines: `coin`, `water`, `boost`, `diamond`. `MAX_TIER = 12`. No spirits-produce-spirits line.
- Test suite must be registered in the ACTIVE `ENGINE_TESTS` list in `Makefile` (never a disabled list) and pass under `make test-fast`.
- Work happens in an out-of-tree worktree; seed its `.godot/` from the main tree (`rsync -a --delete /Users/xup/dh/merge/.godot/ <worktree>/.godot/`) before the first test run.

---

### Task 1: Module scaffold — state, constants, hand ops, suite registration

**Files:**
- Create: `engine/scripts/core/resident_bucket.gd`
- Create: `engine/tests/resident_bucket_tests.gd`
- Modify: `Makefile:13` (append `engine/tests/resident_bucket_tests` to `ENGINE_TESTS`)

**Interfaces:**
- Produces: `make_state(now: float = 0.0) -> Dictionary`, `hand_add(state, line: String, tier: int = 1) -> int` (new hand size; tier clamped to `[1, MAX_TIER]`; unknown line rejected → returns current size unchanged), `hand_merge(state, i: int, j: int) -> bool` (true iff hand[i]/hand[j] share line+tier below `MAX_TIER`; hand[i] tier +1, hand[j] removed), consts `MAX_TIER`, `SELL_PER_TIER`, `LINES` (the four line ids), `DEFAULTS`.

- [ ] **Step 1: Write the failing test suite skeleton with hand-op tests**

`engine/tests/resident_bucket_tests.gd`:

```gdscript
extends SceneTree

const Bucket = preload("res://engine/scripts/core/resident_bucket.gd")

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _test_hand_ops() -> void:
	var s := Bucket.make_state()
	ok(s.cells == 0 and s.hand.is_empty() and s.placed.is_empty(), "fresh state: 0 cells, empty hand + placed")
	ok(Bucket.hand_add(s, "coin") == 1, "hand_add appends and returns new size")
	ok(Bucket.hand_add(s, "coin", 99) == 2 and s.hand[1].tier == Bucket.MAX_TIER, "hand_add clamps tier to MAX_TIER")
	ok(Bucket.hand_add(s, "acorn") == 2, "hand_add rejects an unknown line")
	ok(not Bucket.hand_merge(s, 0, 1), "hand_merge refuses mismatched tiers")
	Bucket.hand_add(s, "coin")            # hand: t1 coin, t12 coin, t1 coin
	ok(Bucket.hand_merge(s, 0, 2), "hand_merge consumes a same line+tier pair")
	ok(s.hand.size() == 2 and s.hand[0].tier == 2, "merge result climbs one tier in place")
	Bucket.hand_add(s, "water", Bucket.MAX_TIER)
	Bucket.hand_add(s, "water", Bucket.MAX_TIER)
	ok(not Bucket.hand_merge(s, 2, 3), "hand_merge is a no-op at MAX_TIER")
	var t := Bucket.make_state()
	Bucket.hand_add(t, "coin")
	Bucket.hand_add(t, "water")
	ok(not Bucket.hand_merge(t, 0, 1), "hand_merge refuses cross-line pairs")
	ok(not Bucket.hand_merge(t, 0, 0), "hand_merge refuses i == j")
	ok(not Bucket.hand_merge(t, 0, 7), "hand_merge refuses an out-of-range index")

func _initialize() -> void:
	print("== resident bucket (pure module) ==")
	_test_hand_ops()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `make test-one SUITE=engine/tests/resident_bucket_tests`
Expected: FAIL / crash — `res://engine/scripts/core/resident_bucket.gd` does not exist.

- [ ] **Step 3: Write the minimal module**

`engine/scripts/core/resident_bucket.gd`:

```gdscript
extends RefCounted
## The global resident bucket — PURE logic, no game wiring.
## Spec: docs/superpowers/specs/2026-07-16-global-resident-bucket-design.md
## State is a plain Dictionary (make_state); time (seconds) and RNG are always injected.
## This module preloads NOTHING — a later adapter persists state in Save and feeds real time.

const MAX_TIER := 12
const SELL_PER_TIER := 5
const LINES := ["coin", "water", "boost", "diamond"]

# PROVISIONAL dials — sim-tuned later. rate is units/HOUR per point of the line's Σtier;
# bank(Σtier) = bank_base + bank_per_tier × Σtier; day_cap 0 = unbounded; weight = box roll odds.
const DEFAULTS := {
	"lines": {
		"coin":    {"rate_per_tier_h": 0.25, "bank_base": 4.0, "bank_per_tier": 1.0,   "day_cap": 0, "weight": 60},
		"water":   {"rate_per_tier_h": 0.05, "bank_base": 2.0, "bank_per_tier": 0.25,  "day_cap": 0, "weight": 25},
		"boost":   {"rate_per_tier_h": 0.02, "bank_base": 1.0, "bank_per_tier": 0.125, "day_cap": 0, "weight": 10},
		"diamond": {"rate_per_tier_h": 0.01, "bank_base": 1.0, "bank_per_tier": 0.125, "day_cap": 2, "weight": 5},
	},
	"tier_weights": [60, 25, 10, 5],   # box tier roll — t1-heavy, capped at t4
}

static func make_state(now: float = 0.0) -> Dictionary:
	return {
		"cells": 0,
		"hand": [],          # [{line, tier}] — unbounded
		"placed": [],        # [{line, tier}] — bounded by cells
		"banks": {},         # line -> float matured units awaiting collect
		"last": now,         # last settle timestamp (s)
		"day": {"stamp": -1, "granted": {}},   # per-day collect bookkeeping for day_cap lines
	}

static func hand_add(state: Dictionary, line: String, tier: int = 1) -> int:
	if line in LINES:
		state.hand.append({"line": line, "tier": clampi(tier, 1, MAX_TIER)})
	return state.hand.size()

static func hand_merge(state: Dictionary, i: int, j: int) -> bool:
	if i == j or not _pair_mergeable(state.hand, i, state.hand, j):
		return false
	state.hand[i].tier += 1
	state.hand.remove_at(j)
	return true

static func _pair_mergeable(list_a: Array, i: int, list_b: Array, j: int) -> bool:
	if i < 0 or j < 0 or i >= list_a.size() or j >= list_b.size():
		return false
	var a: Dictionary = list_a[i]
	var b: Dictionary = list_b[j]
	return a.line == b.line and int(a.tier) == int(b.tier) and int(a.tier) < MAX_TIER
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `make test-one SUITE=engine/tests/resident_bucket_tests`
Expected: all PASS, `quit 0`.

- [ ] **Step 5: Register the suite in the ACTIVE engine list**

In `Makefile`, append ` engine/tests/resident_bucket_tests` to the end of the `ENGINE_TESTS :=` line (line 13 — the active list, NOT `ENGINE_TESTS_DISABLED`).

- [ ] **Step 6: Run the inner loop**

Run: `make test-fast`
Expected: ALL SUITES PASSED, with `resident_bucket_tests` in the timing table.

- [ ] **Step 7: Commit**

```bash
git add engine/scripts/core/resident_bucket.gd engine/tests/resident_bucket_tests.gd Makefile
git commit -m "feat(bucket): pure resident-bucket module — state + hand ops"
```

---

### Task 2: Cells, placement, place-merge, unplace, sell

**Files:**
- Modify: `engine/scripts/core/resident_bucket.gd`
- Modify: `engine/tests/resident_bucket_tests.gd`

**Interfaces:**
- Consumes: Task 1's state shape, `_pair_mergeable`.
- Produces: `grant_cells(state, n: int) -> int` (new total; n ≤ 0 is a no-op), `place(state, hand_index: int, now: float, cfg := {}) -> bool`, `place_merge(state, hand_index: int, placed_index: int, now: float, cfg := {}) -> bool`, `unplace(state, placed_index: int, now: float, cfg := {}) -> bool`, `sell_hand(state, i: int) -> int` and `sell_placed(state, i: int, now: float, cfg := {}) -> int` (coins = `SELL_PER_TIER × tier`, 0 on bad index). All Σtier-changing calls take `now` because they must settle production first (Task 3 makes `_settle` real; this task ships it as a stub).

- [ ] **Step 1: Write the failing tests**

Append to `engine/tests/resident_bucket_tests.gd` (and call from `_initialize`):

```gdscript
func _test_cells_and_placement() -> void:
	var s := Bucket.make_state()
	Bucket.hand_add(s, "coin")
	ok(not Bucket.place(s, 0, 0.0), "place refuses with 0 cells")
	ok(Bucket.grant_cells(s, 2) == 2, "grant_cells raises the total")
	ok(Bucket.grant_cells(s, 0) == 2 and Bucket.grant_cells(s, -3) == 2, "grant_cells ignores n <= 0")
	ok(Bucket.place(s, 0, 0.0), "place moves hand -> cell")
	ok(s.hand.is_empty() and s.placed.size() == 1, "place consumed the hand entry")
	Bucket.hand_add(s, "coin")
	Bucket.hand_add(s, "water")
	ok(Bucket.place(s, 1, 0.0), "duplicate lines may fill multiple cells")
	Bucket.hand_add(s, "boost")
	ok(not Bucket.place(s, 1, 0.0), "place refuses when the bucket is full")
	ok(not Bucket.place(s, 9, 0.0), "place refuses a bad hand index")
	# place_merge: hand t1 coin onto placed t1 coin -> t2, no cell consumed
	ok(Bucket.place_merge(s, 0, 0, 0.0), "place_merge climbs the placed spirit")
	ok(s.placed[0].tier == 2 and s.placed.size() == 2 and s.hand.size() == 1, "place_merge freed no cell and ate the hand spirit")
	ok(not Bucket.place_merge(s, 0, 1, 0.0), "place_merge refuses cross-line pairs")
	# unplace: back to hand, frees the cell
	ok(Bucket.unplace(s, 1, 0.0), "unplace returns a placed spirit to hand")
	ok(s.placed.size() == 1 and s.hand.size() == 2, "unplace freed the cell")
	ok(not Bucket.unplace(s, 5, 0.0), "unplace refuses a bad index")

func _test_sell() -> void:
	var s := Bucket.make_state()
	Bucket.grant_cells(s, 1)
	Bucket.hand_add(s, "coin", 3)
	Bucket.hand_add(s, "water", 1)
	ok(Bucket.sell_hand(s, 0) == 3 * Bucket.SELL_PER_TIER, "sell_hand pays SELL_PER_TIER x tier")
	ok(s.hand.size() == 1, "sell_hand removed the spirit")
	ok(Bucket.sell_hand(s, 9) == 0, "sell_hand pays 0 on a bad index")
	Bucket.place(s, 0, 0.0)
	ok(Bucket.sell_placed(s, 0, 0.0) == Bucket.SELL_PER_TIER, "sell_placed pays the same rate")
	ok(s.placed.is_empty(), "sell_placed freed the cell")
```

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `make test-one SUITE=engine/tests/resident_bucket_tests`
Expected: crash/FAIL — `grant_cells` not defined.

- [ ] **Step 3: Implement**

Append to `engine/scripts/core/resident_bucket.gd`:

```gdscript
static func grant_cells(state: Dictionary, n: int) -> int:
	if n > 0:
		state.cells += n
	return state.cells

static func place(state: Dictionary, hand_index: int, now: float, cfg: Dictionary = {}) -> bool:
	if hand_index < 0 or hand_index >= state.hand.size() or state.placed.size() >= state.cells:
		return false
	_settle(state, now, cfg)
	state.placed.append(state.hand.pop_at(hand_index))
	return true

static func place_merge(state: Dictionary, hand_index: int, placed_index: int, now: float, cfg: Dictionary = {}) -> bool:
	if not _pair_mergeable(state.hand, hand_index, state.placed, placed_index):
		return false
	_settle(state, now, cfg)
	state.placed[placed_index].tier += 1
	state.hand.remove_at(hand_index)
	return true

static func unplace(state: Dictionary, placed_index: int, now: float, cfg: Dictionary = {}) -> bool:
	if placed_index < 0 or placed_index >= state.placed.size():
		return false
	_settle(state, now, cfg)
	state.hand.append(state.placed.pop_at(placed_index))
	return true

static func sell_hand(state: Dictionary, i: int) -> int:
	if i < 0 or i >= state.hand.size():
		return 0
	return SELL_PER_TIER * int(state.hand.pop_at(i).tier)

static func sell_placed(state: Dictionary, i: int, now: float, cfg: Dictionary = {}) -> int:
	if i < 0 or i >= state.placed.size():
		return 0
	_settle(state, now, cfg)
	return SELL_PER_TIER * int(state.placed.pop_at(i).tier)

static func _settle(state: Dictionary, now: float, cfg: Dictionary = {}) -> void:
	state.last = now   # Task 3 replaces this stub with real accrual
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `make test-one SUITE=engine/tests/resident_bucket_tests`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/core/resident_bucket.gd engine/tests/resident_bucket_tests.gd
git commit -m "feat(bucket): cells, placement, place-merge, unplace, sell"
```

---

### Task 3: Production math — Σtier, rate, bank cap, settle, pending

**Files:**
- Modify: `engine/scripts/core/resident_bucket.gd`
- Modify: `engine/tests/resident_bucket_tests.gd`

**Interfaces:**
- Consumes: Task 2's `_settle` stub (replaced here), state shape.
- Produces: `line_stier(state, line: String) -> int`, `line_cfg(line: String, cfg := {}) -> Dictionary` (per-line dial dict, `cfg["lines"][line]` if given else `DEFAULTS`), `rate(state, line, cfg := {}) -> float` (units/hour = `rate_per_tier_h × Σtier`), `bank_cap(state, line, cfg := {}) -> float` (`bank_base + bank_per_tier × Σtier`), `pending(state, line, now, cfg := {}) -> float` (bank the line would hold at `now`, no mutation), real `_settle(state, now, cfg)` (advances every line's bank to `now`, clamped at its cap; never destroys an over-cap bank; ignores `now < state.last`).

- [ ] **Step 1: Write the failing tests**

Append (and call from `_initialize`):

```gdscript
const HOUR := 3600.0

func _cfg(rate_h: float, base: float, per: float, day_cap: int = 0) -> Dictionary:
	# a pinned single-line dial override so tests never depend on provisional DEFAULTS
	var lines := {}
	for l in Bucket.LINES:
		lines[l] = {"rate_per_tier_h": rate_h, "bank_base": base, "bank_per_tier": per, "day_cap": day_cap, "weight": 1}
	return {"lines": lines, "tier_weights": [1]}

func _test_production() -> void:
	var cfg := _cfg(1.0, 2.0, 1.0)   # 1 unit/h per Σtier; bank = 2 + Σtier
	var s := Bucket.make_state(0.0)
	Bucket.grant_cells(s, 3)
	Bucket.hand_add(s, "coin", 2)
	Bucket.hand_add(s, "coin", 3)
	Bucket.place(s, 0, 0.0, cfg)
	Bucket.place(s, 0, 0.0, cfg)
	ok(Bucket.line_stier(s, "coin") == 5, "line_stier sums placed tiers of the line")
	ok(Bucket.line_stier(s, "water") == 0, "line_stier is 0 for an unplaced line")
	ok(is_equal_approx(Bucket.rate(s, "coin", cfg), 5.0), "rate = rate_per_tier_h x Stier")
	ok(is_equal_approx(Bucket.bank_cap(s, "coin", cfg), 7.0), "bank_cap = base + per_tier x Stier")
	ok(is_equal_approx(Bucket.pending(s, "coin", HOUR * 0.5, cfg), 2.5), "pending accrues rate x elapsed")
	ok(is_equal_approx(Bucket.pending(s, "coin", HOUR * 100.0, cfg), 7.0), "pending clamps at the bank cap")
	ok(is_equal_approx(Bucket.pending(s, "coin", -5.0, cfg), 0.0), "pending ignores time running backwards")
	ok(is_equal_approx(Bucket.pending(s, "water", HOUR, cfg), 0.0), "an unplaced line accrues nothing")
	# settling mid-way then raising Stier accounts the old rate up to the settle point
	Bucket.hand_add(s, "coin", 5)
	Bucket.place(s, 0, HOUR, cfg)              # settles at t=1h: bank 5.0; Stier now 10
	ok(is_equal_approx(s.banks["coin"], 5.0), "Stier-changing calls settle at the old rate first")
	ok(is_equal_approx(Bucket.pending(s, "coin", HOUR + HOUR * 0.1, cfg), 6.0), "post-change accrual uses the new rate")
	# selling below an already-banked amount never destroys the bank
	var over := Bucket.make_state(0.0)
	Bucket.grant_cells(over, 2)
	Bucket.hand_add(over, "coin", 10)
	Bucket.place(over, 0, 0.0, cfg)
	Bucket.sell_placed(over, 0, HOUR, cfg)      # banked 10.0 with cap 12 -> then Stier 0, cap 2
	ok(is_equal_approx(over.banks["coin"], 10.0), "an over-cap bank survives (no accrual, no destruction)")
	ok(is_equal_approx(Bucket.pending(over, "coin", HOUR * 9.0, cfg), 10.0), "over-cap bank stops accruing")

func _test_merge_always_pays() -> void:
	# the spec's hard invariant: every +1 Stier strictly raises rate AND bank cap on every line
	for line in Bucket.LINES:
		var all_pay := true
		for stier in range(1, Bucket.MAX_TIER * 8):
			var lo := _stier_state(line, stier)
			var hi := _stier_state(line, stier + 1)
			if Bucket.rate(hi, line) <= Bucket.rate(lo, line):
				all_pay = false
			if Bucket.bank_cap(hi, line) <= Bucket.bank_cap(lo, line):
				all_pay = false
		ok(all_pay, "merge always pays on '%s' (rate + bank strictly rise per Stier step, DEFAULTS)" % line)

func _stier_state(line: String, stier: int) -> Dictionary:
	var s := Bucket.make_state(0.0)
	Bucket.grant_cells(s, 8)
	var left := stier
	while left > 0:
		var t: int = mini(left, Bucket.MAX_TIER)
		Bucket.hand_add(s, line, t)
		Bucket.place(s, 0, 0.0)
		left -= t
	return s
```

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `make test-one SUITE=engine/tests/resident_bucket_tests`
Expected: crash/FAIL — `line_stier` not defined.

- [ ] **Step 3: Implement (replace the `_settle` stub)**

Append to the module, and DELETE the Task 2 stub `_settle`:

```gdscript
static func line_cfg(line: String, cfg: Dictionary = {}) -> Dictionary:
	var lines: Dictionary = cfg.get("lines", DEFAULTS["lines"])
	return lines.get(line, {})

static func line_stier(state: Dictionary, line: String) -> int:
	var total := 0
	for p in state.placed:
		if p.line == line:
			total += int(p.tier)
	return total

static func rate(state: Dictionary, line: String, cfg: Dictionary = {}) -> float:
	return float(line_cfg(line, cfg).get("rate_per_tier_h", 0.0)) * float(line_stier(state, line))

static func bank_cap(state: Dictionary, line: String, cfg: Dictionary = {}) -> float:
	var lc := line_cfg(line, cfg)
	return float(lc.get("bank_base", 0.0)) + float(lc.get("bank_per_tier", 0.0)) * float(line_stier(state, line))

static func pending(state: Dictionary, line: String, now: float, cfg: Dictionary = {}) -> float:
	var bank: float = state.banks.get(line, 0.0)
	var hours: float = maxf(0.0, now - float(state.last)) / 3600.0
	var cap := bank_cap(state, line, cfg)
	if bank >= cap:
		return bank   # an over-cap bank neither accrues nor decays
	return minf(bank + rate(state, line, cfg) * hours, cap)

static func _settle(state: Dictionary, now: float, cfg: Dictionary = {}) -> void:
	if now < float(state.last):
		return
	for line in LINES:
		state.banks[line] = pending(state, line, now, cfg)
	state.last = now
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `make test-one SUITE=engine/tests/resident_bucket_tests`
Expected: all PASS (including the merge-always-pays sweep over DEFAULTS).

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/core/resident_bucket.gd engine/tests/resident_bucket_tests.gd
git commit -m "feat(bucket): per-line production — Stier, rate, bank cap, settle, pending"
```

---

### Task 4: Collect with per-day ceilings

**Files:**
- Modify: `engine/scripts/core/resident_bucket.gd`
- Modify: `engine/tests/resident_bucket_tests.gd`

**Interfaces:**
- Consumes: Task 3's `_settle`, `pending`, `line_cfg`.
- Produces: `collect(state, now, cfg := {}) -> Dictionary` — settles, then for each line grants `floor(bank)` whole units (fraction stays banked); a line with `day_cap > 0` grants at most its remaining allowance for the day (`day = int(now / 86400.0)`; allowance resets when the day stamp changes, ungranted surplus stays banked). Returns only lines that granted > 0, e.g. `{"coin": 3, "diamond": 1}`.

- [ ] **Step 1: Write the failing tests**

Append (and call from `_initialize`):

```gdscript
const DAY := 86400.0

func _test_collect_and_day_cap() -> void:
	var cfg := _cfg(1.0, 50.0, 1.0, 2)   # every line: 1 unit/h per Stier, deep bank, day_cap 2
	var s := Bucket.make_state(0.0)
	Bucket.grant_cells(s, 2)
	Bucket.hand_add(s, "coin", 1)
	Bucket.hand_add(s, "diamond", 1)
	Bucket.place(s, 0, 0.0, cfg)
	Bucket.place(s, 0, 0.0, cfg)
	var got := Bucket.collect(s, HOUR * 3.5, cfg)
	ok(int(got.get("coin", 0)) == 2, "collect grants floor(bank) whole units (day-capped at 2 here)")
	ok(is_equal_approx(s.banks["coin"], 1.5), "the fraction AND the over-allowance stay banked")
	ok(int(got.get("diamond", 0)) == 2, "a day-capped line grants at most day_cap")
	ok(Bucket.collect(s, HOUR * 3.5, cfg).is_empty(), "same-day recollect grants nothing further")
	got = Bucket.collect(s, DAY + HOUR, cfg)
	ok(int(got.get("diamond", 0)) == 2, "the allowance resets on the next day and banked surplus pays out")
	# an uncapped line pays the whole banked amount
	var free_cfg := _cfg(1.0, 50.0, 1.0, 0)
	var u := Bucket.make_state(0.0)
	Bucket.grant_cells(u, 1)
	Bucket.hand_add(u, "coin", 2)
	Bucket.place(u, 0, 0.0, free_cfg)
	ok(int(Bucket.collect(u, HOUR * 5.0, free_cfg).get("coin", 0)) == 10, "day_cap 0 = unbounded collect")
	ok(Bucket.collect(u, HOUR * 5.0, free_cfg).is_empty(), "an empty bank returns an empty grant")
```

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `make test-one SUITE=engine/tests/resident_bucket_tests`
Expected: crash/FAIL — `collect` not defined.

- [ ] **Step 3: Implement**

Append to the module:

```gdscript
static func collect(state: Dictionary, now: float, cfg: Dictionary = {}) -> Dictionary:
	_settle(state, now, cfg)
	var day_stamp := int(now / 86400.0)
	if int(state.day.stamp) != day_stamp:
		state.day = {"stamp": day_stamp, "granted": {}}
	var out := {}
	for line in LINES:
		var whole := int(floor(float(state.banks.get(line, 0.0))))
		var day_cap := int(line_cfg(line, cfg).get("day_cap", 0))
		if day_cap > 0:
			whole = mini(whole, day_cap - int(state.day.granted.get(line, 0)))
		if whole <= 0:
			continue
		state.banks[line] = float(state.banks[line]) - float(whole)
		state.day.granted[line] = int(state.day.granted.get(line, 0)) + whole
		out[line] = whole
	return out
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `make test-one SUITE=engine/tests/resident_bucket_tests`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/scripts/core/resident_bucket.gd engine/tests/resident_bucket_tests.gd
git commit -m "feat(bucket): collect with per-day ceilings (diamond IAP guard)"
```

---

### Task 5: Box rolls (line by rarity weight, t1-heavy tier) + ceiling guard

**Files:**
- Modify: `engine/scripts/core/resident_bucket.gd`
- Modify: `engine/tests/resident_bucket_tests.gd`

**Interfaces:**
- Consumes: `hand_add`, `DEFAULTS`, `line_cfg`.
- Produces: `roll_line(rng: RandomNumberGenerator, cfg := {}) -> String` (weighted by each line's `weight`), `roll_tier(rng: RandomNumberGenerator, cfg := {}) -> int` (weighted by `tier_weights`, 1-indexed), `grant_box(state, count: int, rng: RandomNumberGenerator, cfg := {}) -> Array` (rolls `count` spirits into the hand, returns the new instances).

- [ ] **Step 1: Write the failing tests**

Append (and call from `_initialize`):

```gdscript
func _test_box_rolls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	# a rigged config: only water can drop, only tier 3 can roll
	var rig := _cfg(1.0, 1.0, 1.0)
	for l in rig.lines:
		rig.lines[l].weight = 1 if l == "water" else 0
	rig.tier_weights = [0, 0, 1]
	var s := Bucket.make_state()
	var got := Bucket.grant_box(s, 3, rng, rig)
	ok(got.size() == 3 and s.hand.size() == 3, "grant_box drops count spirits into the hand")
	var rigged_ok := true
	for inst in got:
		if inst.line != "water" or int(inst.tier) != 3:
			rigged_ok = false
	ok(rigged_ok, "rolls honor the line weights and tier weights")
	# under DEFAULTS, over many rolls: every line appears and diamond is the rarest
	var counts := {"coin": 0, "water": 0, "boost": 0, "diamond": 0}
	for i in range(4000):
		counts[Bucket.roll_line(rng)] += 1
	var all_present := true
	for l in Bucket.LINES:
		if int(counts[l]) == 0:
			all_present = false
	ok(all_present, "every line is reachable under DEFAULTS")
	ok(int(counts.diamond) < int(counts.coin) and int(counts.diamond) < int(counts.water) and int(counts.diamond) < int(counts.boost),
		"diamond is the rarest drop under DEFAULTS")
	var tiers_ok := true
	for i in range(500):
		var t := Bucket.roll_tier(rng)
		if t < 1 or t > 4:
			tiers_ok = false
	ok(tiers_ok, "DEFAULTS tier rolls stay in the t1..t4 band")

func _test_ceiling_guard() -> void:
	# the redesign's whole point: full-dedication ceilings are designed numbers, not emergent blowups
	var s := _stier_state("diamond", Bucket.MAX_TIER * 8)   # 8 cells, all t12 diamond
	var day_one := Bucket.collect(s, DAY * 30.0)             # a month idle, then collect
	var dcap := int(Bucket.line_cfg("diamond").get("day_cap", 0))
	ok(dcap > 0, "the diamond line ships day-capped in DEFAULTS")
	ok(int(day_one.get("diamond", 0)) <= dcap, "full 8-cell t12 diamond dedication still pays <= day_cap per day")
	var coin := _stier_state("coin", Bucket.MAX_TIER * 8)
	ok(Bucket.rate(coin, "coin") <= 30.0, "full coin dedication stays under 30 coins/h (provisional sanity bound)")
```

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `make test-one SUITE=engine/tests/resident_bucket_tests`
Expected: crash/FAIL — `grant_box` not defined.

- [ ] **Step 3: Implement**

Append to the module:

```gdscript
static func roll_line(rng: RandomNumberGenerator, cfg: Dictionary = {}) -> String:
	var lines: Dictionary = cfg.get("lines", DEFAULTS["lines"])
	var total := 0
	for line in LINES:
		total += int(lines.get(line, {}).get("weight", 0))
	if total <= 0:
		return LINES[0]
	var pick := rng.randi_range(1, total)
	for line in LINES:
		pick -= int(lines.get(line, {}).get("weight", 0))
		if pick <= 0:
			return line
	return LINES[0]

static func roll_tier(rng: RandomNumberGenerator, cfg: Dictionary = {}) -> int:
	var weights: Array = cfg.get("tier_weights", DEFAULTS["tier_weights"])
	var total := 0
	for w in weights:
		total += int(w)
	if total <= 0:
		return 1
	var pick := rng.randi_range(1, total)
	for i in range(weights.size()):
		pick -= int(weights[i])
		if pick <= 0:
			return i + 1
	return 1

static func grant_box(state: Dictionary, count: int, rng: RandomNumberGenerator, cfg: Dictionary = {}) -> Array:
	var out := []
	for i in range(count):
		var line := roll_line(rng, cfg)
		var tier := roll_tier(rng, cfg)
		hand_add(state, line, tier)
		out.append(state.hand.back())
	return out
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `make test-one SUITE=engine/tests/resident_bucket_tests`
Expected: all PASS.

- [ ] **Step 5: Full sweep before handing off**

Run: `make test-fast`, then `make test`
Expected: ALL SUITES PASSED on both.

- [ ] **Step 6: Commit**

```bash
git add engine/scripts/core/resident_bucket.gd engine/tests/resident_bucket_tests.gd
git commit -m "feat(bucket): box rolls (rarity-weighted lines) + ceiling guard tests"
```

---

## Out of scope (the later flip plan)

Replacing `habitat.gd` call sites, the `Save` adapter + save migration (placed → hand, pending settled), retiring the per-map `REWARD` table and map-card collect UI, the dock UI rework, and wiring `grant_box` into the Expedition trade screen.
