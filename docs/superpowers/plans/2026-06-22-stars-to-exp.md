# Stars → EXP Progression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse the two star concepts (spendable balance + cumulative earned) into one ever-increasing `exp` total; gate every world unlock on *reaching* an exp threshold via a single sequential unlock button; demote level to a cosmetic badge + per-level reward.

**Architecture:** Refactor in three green-gated phases. **Phase 1 (add):** introduce the new exp pure-functions and the per-spot threshold ladder additively — old code untouched, suite stays green. **Phase 2 (flip):** switch the live data path (`grove.exp`), the quest-fence bank signal, the board/map UI, and all level-derived gates to exp in one coordinated push, updating every call site and its tests; suite green at the end. **Phase 3 (remove):** delete the dead spendable-stars API, the level-unit tables, the vine cost ladder, and all migration helpers; bump the save schema to delete-and-recreate; sweep tools; final grep clean.

**Tech Stack:** Godot 4.6 GDScript. Headless test suites via `make test-fast` (engine), `make test-grove` (grove slices), `make test` (full, before handoff). Run `make import` once in this worktree first (per-checkout texture cache).

**Reference spec:** `docs/design/exp_progression_spec.md`.

---

## File Structure

| File | Responsibility after this change |
| --- | --- |
| `games/grove/grove_data.gd` | Tuning tables: `LEVEL_EXP`(+tail), `MIN_EXP` (board-cell exp gates), `UNLOCK_BASE`/`UNLOCK_STEP` (per-map unlock increment), generator `appear_exp`. `LEVEL_STARS`/`MIN_LEVEL`/`STAR_CAP` removed. |
| `engine/scripts/core/content.gd` (`G`) | Exp math (`level_for_exp`, `exp_at_level`, `earn_exp`), the spot threshold ladder (`spot_unlock_exp`, `map_next_unlock`, `map_finish_exp`), exp-based gates (`cell_min_exp`, `generators_for_map` via `appear_exp`), `map_unlocked` exp-based, `quest_reward` exp field. |
| `engine/scripts/core/quests.gd` | Quest-fence signals keyed on `exp` + thresholds: `meter_target`, `gate_ready`, `fence_inert`, `purge_state`, `refill`, `exp_remaining`. |
| `engine/scripts/core/save.gd` | Single `grove.exp` int; no `currencies.stars`; schema bump → delete-and-recreate; migration helpers removed. |
| `engine/scripts/scenes/board.gd` | HUD exp total + level badge + progress bar; `earn_exp` on delivery; metering/gates read exp. |
| `engine/scripts/scenes/map.gd` | Single bottom **Unlock** button (greyed below threshold, shows next requirement); tap-to-claim the next spot; per-spot tap-to-buy removed; `map_unlocked` exp-based. |
| `engine/scripts/ui/hud.gd`, `level_popup.gd`, `piece_view.gd` | Exp labels/fraction; level badge + locked-cell gate from exp. |
| `games/grove/vine/vine_maps.gd` | `COST_LADDER`/`COST_TAIL` and per-spot `cost` removed (threshold computed centrally). |
| `games/grove/tools/*` | `grove_sim`, `click_spot`, `grove_shot`, `map_shot`, `inbox_shot` updated to the exp API. |

---

## Phase 1 — Add the exp model (additive, suite stays green)

### Task 1: Per-spot unlock-threshold ladder + exp level math (pure, additive)

**Files:**
- Modify: `games/grove/grove_data.gd` (add constants near `LEVEL_STARS`, line ~306)
- Modify: `engine/scripts/core/content.gd` (add functions near the progression block, line ~622)
- Test: `games/grove/tests/grove_economy_tests.gd`

- [ ] **Step 1: Add tuning constants** in `grove_data.gd` directly below the `LEVEL_STARS_TAIL` line (~307):

```gdscript
# §map-unlock — the per-spot exp threshold ladder. Spots across all maps form one global
# order (map order, then spot order); each spot's unlock threshold is the running sum of a
# per-spot increment that ESCALATES per map: inc(z) = UNLOCK_BASE + z*UNLOCK_STEP. The first
# spot overall sits at 0 (claimable on a fresh save). PROVISIONAL feel dials.
const UNLOCK_BASE := 3            # per-spot exp increment on the first map
const UNLOCK_STEP := 3            # extra increment added per later map
const LEVEL_EXP := [0, 6, 14, 24, 36, 50, 66, 84, 104, 126]   # exp to reach L2..L10 (L1 = 0)
const LEVEL_EXP_TAIL := 22        # exp per level past the table (flat, uncapped)
```

- [ ] **Step 2: Add the ladder + level fns** in `content.gd`. Place immediately after `level_for_stars`/`stars_at_level` (~line 640), keeping the old fns for now:

```gdscript
# --- exp level math (the renamed clock; reads the single cumulative `exp`) ----------
static func level_for_exp(earned: int) -> int:
	var lvl := 1
	for i in LEVEL_EXP.size():
		if earned >= int(LEVEL_EXP[i]):
			lvl = i + 1
	var top := int(LEVEL_EXP[LEVEL_EXP.size() - 1])
	if earned > top:
		lvl += int((earned - top) / float(LEVEL_EXP_TAIL))
	return lvl

static func exp_at_level(level: int) -> int:
	if level <= 1:
		return 0
	if level <= LEVEL_EXP.size():
		return int(LEVEL_EXP[level - 1])
	return int(LEVEL_EXP[LEVEL_EXP.size() - 1]) + LEVEL_EXP_TAIL * (level - LEVEL_EXP.size())

# --- the per-spot unlock-threshold ladder (§map-unlock) -----------------------------
# Per-spot increment for map z (escalates per map).
static func unlock_inc(z: int) -> int:
	return UNLOCK_BASE + z * UNLOCK_STEP

# Cumulative exp threshold at which spot k of map z becomes claimable. Running sum over the
# global spot order: every earlier map's spots at that map's increment, plus k of map z's.
static func spot_unlock_exp(z: int, k: int) -> int:
	var total := 0
	for zz in z:
		total += MAPS[zz].spots.size() * unlock_inc(zz)
	return total + k * unlock_inc(z)

# The next spot to claim in map z = the lowest-threshold UNCLAIMED spot. Returns
# {k, exp}; k == -1 when every spot of z is already claimed.
static func map_next_unlock(z: int, unlocks: Dictionary) -> Dictionary:
	var best := {"k": -1, "exp": -1}
	for k in MAPS[z].spots.size():
		if unlocks.has(String(MAPS[z].spots[k].id)):
			continue
		var e := spot_unlock_exp(z, k)
		if best.k == -1 or e < int(best.exp):
			best = {"k": k, "exp": e}
	return best

# The exp at which the WHOLE of map z is claimable = the highest unclaimed threshold.
# -1 when every spot is claimed. Drives fence_inert.
static func map_finish_exp(z: int, unlocks: Dictionary) -> int:
	var hi := -1
	for k in MAPS[z].spots.size():
		if unlocks.has(String(MAPS[z].spots[k].id)):
			continue
		hi = maxi(hi, spot_unlock_exp(z, k))
	return hi
```

- [ ] **Step 3: Write failing tests** — add a `13d` block in `grove_economy_tests.gd` after the existing level-clock block (~line 253):

```gdscript
	# 13d. exp level math parity + the per-spot unlock-threshold ladder
	ok(G.level_for_exp(0) == 1 and G.level_for_exp(6) == 2 and G.level_for_exp(126) == 10, \
		"level_for_exp matches the cumulative thresholds")
	ok(G.exp_at_level(1) == 0 and G.exp_at_level(2) == 6 and G.exp_at_level(11) == 126 + G.LEVEL_EXP_TAIL, \
		"exp_at_level inverts the curve")
	ok(G.spot_unlock_exp(0, 0) == 0, "the first spot overall is claimable at 0 exp")
	# strictly increasing in global order
	var inc_ok := true
	var prev := -1
	for z in G.MAPS.size():
		for k in G.MAPS[z].spots.size():
			var e := G.spot_unlock_exp(z, k)
			if e <= prev and not (z == 0 and k == 0):
				inc_ok = false
			prev = e
	ok(inc_ok, "spot_unlock_exp is strictly increasing across the global spot order")
	# escalates per map: a later map's per-spot increment is larger
	ok(G.unlock_inc(1) > G.unlock_inc(0) and G.unlock_inc(2) > G.unlock_inc(1), \
		"the unlock increment escalates per map")
	# next-unlock picks the lowest-threshold unclaimed spot
	var nu := G.map_next_unlock(0, {})
	ok(int(nu.k) == 0 and int(nu.exp) == 0, "map_next_unlock targets the lowest-threshold unclaimed spot")
	var owned0 := {String(G.MAPS[0].spots[0].id): true}
	ok(int(G.map_next_unlock(0, owned0).k) == 1, "claiming spot 0 advances the next-unlock to spot 1")
```

- [ ] **Step 4: Run the grove slice** — verify the new tests pass and nothing regressed:

Run: `make test-grove`
Expected: PASS (all grove suites green; the new `13d` assertions pass).

- [ ] **Step 5: Commit**

```bash
git add games/grove/grove_data.gd engine/scripts/core/content.gd games/grove/tests/grove_economy_tests.gd
git commit -m "feat(progression): add exp level math + per-spot unlock-threshold ladder

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Phase 2 — Flip the live path to exp (coordinated; suite green at end)

### Task 2: Switch progression, quest fence, gates, HUD, and the map unlock UI to exp

This is one coherent flip: `grove.exp` becomes the source of truth, the quest-fence bank signal becomes exp, level-derived gates become exp gates, and the map gains the single sequential unlock button. Every change below lands together because the bank signal cannot be half-migrated (a frozen bank breaks the fence). Work top-down (model → quests → board → map → ui), then run the full suite.

**Files:** `engine/scripts/core/content.gd`, `engine/scripts/core/quests.gd`, `engine/scripts/scenes/board.gd`, `engine/scripts/scenes/map.gd`, `engine/scripts/ui/hud.gd`, `engine/scripts/ui/level_popup.gd`, `engine/scripts/ui/piece_view.gd`, `games/grove/grove_data.gd`, `engine/scripts/core/save.gd`, `engine/scripts/ui/debug.gd`. Tests: `grove_economy_tests.gd`, `grove_model_tests.gd`, `grove_placement_tests.gd`, `grove_shop_ads_tests.gd`, `engine/tests/quest_fence_tests.gd`, `engine/tests/hint_tests.gd`, `engine/tests/anchor_tests.gd`.

- [ ] **Step 1: `save.gd` — add the exp accessor** (keep `stars()` for now; it is removed in Phase 3). Add near the grove block (~line 217):

```gdscript
# The single cumulative progression total (replaces stars_earned + the spendable balance).
static func exp_total() -> int:
	return int(grove().get("exp", 0))

static func add_exp(n: int) -> void:
	var g := grove()
	g["exp"] = int(g.get("exp", 0)) + maxi(0, n)
	grove_write()
```

- [ ] **Step 2: `content.gd` — `earn_exp`, exp gates, quest reward, map_unlocked.** Replace `earn_stars` body, repoint `cell_min_exp`, `generators_for_map`, `quest_reward`, `map_unlocked`:

```gdscript
# Earn exp — the sole way progression advances. Returns levels gained so the caller shows
# the Level dialog. The level-up gift stays deferred to the dialog's Collect (level_gift /
# grant_level_gift, unchanged). No spendable balance any more.
static func earn_exp(n: int) -> int:
	var before := level_for_exp(Save.exp_total())
	Save.add_exp(n)
	return level_for_exp(Save.exp_total()) - before
```

```gdscript
# §4 obstacle field — now a direct EXP gate (level is cosmetic). A cell unseals when total
# exp reaches MIN_EXP[cell], then opens on the next adjacent merge.
static func cell_min_exp(cell: Vector2i) -> int:
	return int(MIN_EXP[cell.x][cell.y])

static func open_at_start(cell: Vector2i) -> bool:
	return cell_min_exp(cell) == 0

static func bramble_terrain(cell: Vector2i) -> int:
	return cell_min_exp(cell)
```

Change `generators_for_map` to gate on exp (rename the param + field, default `APPEAR_ALL`):

```gdscript
static func generators_for_map(roster: Array, map: int, exp: int = APPEAR_ALL) -> Array:
	var out: Array = []
	for g in roster:
		if int(g.map) == map and int(g.get("appear_exp", 0)) <= exp:
			out.append(g)
	return out
```

(Apply the same `level` → `exp` param rename through `lines_for_map`, `askable_lines`, `live_gen_state` — they just forward it.)

Quest reward exp field + `map_unlocked` exp-based:

```gdscript
static func quest_reward(level: int) -> Dictionary:
	var r := {"exp": clampi(level, 1, EXP_PER_QUEST_CAP), "coins": maxi(0, level - EXP_PER_QUEST_CAP)}
	if level >= QUEST_PREMIUM_MIN_LEVEL:
		r["gems"] = QUEST_PREMIUM_GEMS
	return r
```

```gdscript
# A map is visitable once total exp reaches its first spot's threshold (ordering enforced
# by the ladder). The hub (z==0, first threshold 0) is always open.
static func map_unlocked(z: int, unlocks: Dictionary, gates: Array = []) -> bool:
	return Save.exp_total() >= spot_unlock_exp(z, 0)
```

Delete `map_cheapest_spot`, `map_stars_left`, `cheapest_spot_cost`, `is_cheapest_open` (replaced by `map_next_unlock`/`map_finish_exp`). `map_complete`/`map_spots_done`/`frontier_map` stay (frontier still = first unlocked, not-complete map).

- [ ] **Step 3: `grove_data.gd` — `MIN_EXP`, generator `appear_exp`, `EXP_PER_QUEST_CAP`.** Replace `MIN_LEVEL` with `MIN_EXP` (same diamond, each value mapped through the curve so pacing holds — `exp_at_level(old_level)`):

```gdscript
# §4 obstacle field — per-cell EXP gate (was MIN_LEVEL; each entry = exp_at_level(old level)
# so the existing pacing carries over). 0 = open at start. OWNER FEEL DIAL.
const MIN_EXP := [
#    c0   c1   c2   c3   c4   c5   c6
	[148,  66,  36,  36,  36,  66, 148],   # r0  (L11/L7/L5)
	[104,  36,  14,  14,  14,  36, 104],   # r1  (L9/L5/L3)
	[ 66,  36,   0,   0,   0,  36,  66],   # r2  (L7/L5/L1)
	[ 36,   6,   0,   0,   0,   6,  36],   # r3  (L5/L2)
	[ 14,   6,   0,   0,   0,   6,  14],   # r4  center 3×3 open
	[ 36,   6,   0,   0,   0,   6,  36],   # r5
	[ 66,  36,   0,   0,   0,  36,  66],   # r6
	[104,  36,  14,  14,  14,  36, 104],   # r7
	[148,  66,  36,  36,  36,  66, 148],   # r8
]
```

(Mapping, all from `exp_at_level`: L1→0 — the L1 frontier already opens at start since `level_for_exp(0)==1`, so its cells were never truly gated; L2→6, L3→14, L5→36, L7→66, L9→104, L11→`126 + 22 = 148` via the flat tail. Add a test in `grove_economy_tests.gd` asserting `MIN_EXP[x][y] == exp_at_level(old_level)` is unnecessary, but DO assert the center 3×3 stays `0` and a corner equals `exp_at_level(11)`.)

Rename `STAR_CAP` → `EXP_PER_QUEST_CAP` (value 3). Add `appear_exp` to any generator def that had `appear_level` (multiply through `exp_at_level`); generators with no stage default to 0.

- [ ] **Step 4: `quests.gd` — fence signals on exp + thresholds.** Rewrite the bank-based fns:

```gdscript
static func meter_target(z: int, exp: int, unlocks: Dictionary) -> int:
	return G.active_giver_count(exp, int(G.map_next_unlock(z, unlocks).exp))

static func gate_ready(z: int, exp: int, unlocks: Dictionary) -> bool:
	var nxt := int(G.map_next_unlock(z, unlocks).exp)
	return nxt >= 0 and exp >= nxt

static func fence_inert(z: int, exp: int, unlocks: Dictionary) -> bool:
	var fin := G.map_finish_exp(z, unlocks)
	return fin >= 0 and exp >= fin

static func purge_state(z: int, exp: int, unlocks: Dictionary, gates: Array) -> Dictionary:
	# `show` is unchanged (board.gd:818 reads `.show`); only the bank arg (stars→exp) and the
	# displayed-balance key (stars→exp) change.
	return {
		"show": not map_done(unlocks, gates),
		"ready": gate_ready(z, exp, unlocks),
		"exp": exp,
	}

# Exp the player still needs to claim the next spot of map z (0 once claimable).
static func exp_remaining(z: int, unlocks: Dictionary, exp: int) -> int:
	var nxt := int(G.map_next_unlock(z, unlocks).exp)
	return 0 if nxt < 0 else maxi(0, nxt - exp)
```

`active_giver_count(banked, next_cost)` already has the right shape — call it with `(exp, next_threshold)`. Update `refill`'s signature param `banked_stars` → `exp` and its internal `fence_inert`/`meter_target` calls; rename its `level` param to read level from exp at the call site (board passes `level_for_exp(exp)`).

- [ ] **Step 5: `board.gd` — exp everywhere.** Apply:
  - Add a helper `func _exp() -> int: return Save.exp_total()`.
  - `_quest_level()` (line ~461): `return G.level_for_exp(_exp())`.
  - `_meter_target` (465), `refill` (470), `gate_ready` (549), `purge_state` (818), `fence_inert` (2205): pass `_exp()` instead of `Save.stars()`. The purge card now reads `purge_state(...).exp` (was `.stars`) for its displayed balance — update that read.
  - `_quest_stars` → `_quest_exp` reading `q.exp`; the delivery block (~2243-2253): `var sp_exp := _quest_exp(q)`, `var levels_up := G.earn_exp(sp_exp)`, and the reward FX `FX.celebrate_reward(..., "star", sp_exp, ...)` keeps the star/xp glyph (it now represents exp).
  - Locked-cell gate (1604): `var unlockable := frontier and G.cell_min_exp(cell) <= _exp()`. `_refresh_locked_cells` / `openable_brambles(b, _quest_level())` callers (1125, 1930): pass `_exp()` to the generator/bramble exp gates (rename the `level` arg through `board_model.gd` + `piece_view.gd`).
  - HUD (847-854): `slbl.text = str(_exp())` — the cumulative total. Level badge from `G.level_for_exp(_exp())`.
  - `seed_gens(..., _quest_level())` (405) and `grow_gens(0, _quest_level())` (1125): pass `_exp()` (generators_for_map now takes exp).

- [ ] **Step 6: `hud.gd` + `level_popup.gd` + `piece_view.gd` — exp display.**
  - `hud.gd`: the exp number is the cumulative total; the progress fraction = `(exp - exp_at_level(level)) / float(max(1, exp_at_level(level+1) - exp_at_level(level)))`; on level-up the bar's bound is `exp_at_level(level+1)`.
  - `level_popup.gd`: show "`exp` / `exp_at_level(level+1)`" (renamed from stars).
  - `piece_view.gd`: the locked-cell badge reads `G.cell_min_exp(cell)`; show it as the exp needed (the cell's gate), not a level number.

- [ ] **Step 7: `map.gd` — single bottom Unlock button + tap-to-claim.**
  - Add a persistent **Unlock** button to the map's bottom chrome (`_build_hud` / the `_chrome_nodes` row, ~line 87/139). Build a helper `_refresh_unlock_button()`:

```gdscript
# The single sequential unlock button. Targets the next unclaimed spot of the open map;
# greyed below its exp threshold, enabled at/above it. Tapping claims that one spot (free).
func _refresh_unlock_button() -> void:
	var z := _map_idx
	var nxt := G.map_next_unlock(z, unlocks)
	if int(nxt.k) == -1:
		_unlock_btn.disabled = true
		_unlock_btn.text = tr("All restored ✿")
		return
	var need := int(nxt.exp)
	var have := Save.exp_total()
	_unlock_btn.disabled = have < need
	_unlock_btn.text = tr("Unlock — %d exp") % need if have < need else tr("Unlock ✦")

func _on_unlock_pressed() -> void:
	var z := _map_idx
	var nxt := G.map_next_unlock(z, unlocks)
	if int(nxt.k) == -1 or Save.exp_total() < int(nxt.exp):
		return
	_claim_spot(z, int(nxt.k))
```

  - Refactor `_on_spot_tap` into `_claim_spot(z, k)` — the existing body **minus the spend check** (delete the `Save.spend_stars(cost)` branch at 1025-1030). Keep the veil-shatter FX, `_persist`, `_update_hud`, the `map_spots_done` completion path (gates + `MAP_DIAMONDS`), and call `_refresh_unlock_button()` at the end. Tapping a spot directly on the map no longer unlocks (spots are inert to taps; the bottom button is the only unlock path) — keep `spot_hits` for rendering/feedback only.
  - The "N to restore" pill text (712) and any cost label: replace with the next-unlock exp requirement or drop (the bottom button now carries the read).
  - `_update_hud` / map open: call `_refresh_unlock_button()`.

- [ ] **Step 8: `debug.gd` — exp grant.** The debug panel's "add stars" control becomes "add exp" → `Save.add_exp(n)`.

- [ ] **Step 9: Update the affected tests to the exp model.** Key rewrites:
  - `grove_economy_tests.gd`:
    - Replace the spend test (304-317) with a **tap-to-claim** test: set `grove.exp` to the first spot's threshold, claim via the unlock button path (`h._on_unlock_pressed()` or `h._claim_spot(0,0)`), assert the spot is owned and `Save.exp_total()` is **unchanged**; below threshold the button is `disabled` and claiming is a no-op.
    - Completion chain (341-357): drive claims by raising `grove.exp` past each spot's `spot_unlock_exp`; assert the last claim appends `0` to `gates` and grants `MAP_DIAMONDS`, and `map_unlocked(1)` becomes true once `exp >= spot_unlock_exp(1, 0)`.
    - `map_cheapest_spot` block (399-407) → assert `map_next_unlock(z, {}).k == 0` and its `.exp == spot_unlock_exp(z, 0)` for each map.
    - Delete the Q-migration test (360-381) — migrations are gone in Phase 3 (or keep until Phase 3 then delete there).
    - Line 247's "costing 3-5 stars" assertion → drop the cost clause; assert spot count/uniqueness only.
    - The `earn` block (256-275): `earn_stars` → `earn_exp`; assert it writes `grove.exp` only (no spendable balance), gift still deferred.
  - `quest_fence_tests.gd`, `grove_model_tests.gd`, `grove_placement_tests.gd`, `grove_shop_ads_tests.gd`, `hint_tests.gd`, `anchor_tests.gd`: replace `Save.add_stars`/`Save.stars()`/`stars_earned`/`level_for_stars`/`cell_min_level`/`appear_level` with the exp equivalents (`Save.add_exp`/`Save.exp_total()`/`grove.exp`/`level_for_exp`/`cell_min_exp`/`appear_exp`). Where a test seeded the spendable bank to drive the fence, seed `grove.exp` to the relevant `spot_unlock_exp` threshold instead.

- [ ] **Step 10: Run the full suite** (after `make import` if not yet done in this worktree):

Run: `make import && make test`
Expected: ALL SUITES PASSED. If a suite fails, fix the call site / test it points to before committing (do not skip).

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "feat(progression): flip live path to exp — fence, gates, HUD, single unlock button

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Phase 3 — Remove the dead stars vocabulary (suite green)

### Task 3: Delete spendable stars, level-unit tables, vine cost ladder, migrations; bump schema

**Files:** `engine/scripts/core/save.gd`, `engine/scripts/core/content.gd`, `games/grove/grove_data.gd`, `games/grove/vine/vine_maps.gd`, `games/grove/tools/*`, `engine/tests/save_tests.gd`.

- [ ] **Step 1: `save.gd` — delete spendable stars + migrations; bump schema; delete-and-recreate.**
  - Remove `stars()`, `add_stars()`, `spend_stars()` (lines ~178-193).
  - Remove `_migrate_exp_to_stars`, `_migrate_spot_ids`, `_migrate_map_keys`, `_SPOT_ID_RENAMES`, `_MAP_KEY_RENAMES`, `_migrate_legacy`, `migrated_v2`, `COINS_PER_CLEAR_SEED`, the legacy `progress.cfg` path, and the `_migrate_*` calls in `grove()`/`load_now()`.
  - `const SCHEMA_VERSION := 3`.
  - In `load_now()`, after reading, discard a stale save instead of merging:

```gdscript
static func load_now() -> void:
	_loaded = true
	var loaded := _read(path)
	if loaded.is_empty():
		loaded = _read(bak)
	if int(loaded.get("schema_version", 0)) != SCHEMA_VERSION:
		loaded = {}                        # delete-and-recreate: no migration across versions
	data = _merge(_default(), loaded)
	save_now()
```

  - `_default()`: drop the `stars` currency (keep `coins`, `diamonds`).

- [ ] **Step 2: `content.gd` — delete the old aliases.** Remove `level_for_stars`, `stars_at_level`, `earn_stars`, `cell_min_level` (the `_level`-named originals). Grep must show zero references.

- [ ] **Step 3: `grove_data.gd` — remove dead tables.** Delete `LEVEL_STARS`, `LEVEL_STARS_TAIL`, `MIN_LEVEL`, `STAR_CAP` (now `EXP_PER_QUEST_CAP`), any `appear_level` fields.

- [ ] **Step 4: `vine_maps.gd` — remove the cost ladder.** Delete `COST_LADDER`, `COST_TAIL`, and the `cost` field from the dict in `spots_for` (lines 70-78). A spot is now `{id, name, pos}`; the threshold is computed by `G.spot_unlock_exp`.

- [ ] **Step 5: Tools sweep.** `games/grove/tools/grove_sim.gd`, `click_spot.gd`, `grove_shot.gd`, `map_shot.gd`, `inbox_shot.gd`: replace `Save.stars`/`spend_stars`/`add_stars`/`stars_earned`/`level_for_stars` with the exp API; a sim that "buys spots" now raises `grove.exp` and claims via `map_next_unlock`.

- [ ] **Step 6: `save_tests.gd` — exp + delete-and-recreate.**
  - Delete the spendable-stars tests.
  - Assert a fresh save has `Save.exp_total() == 0` and no `currencies.stars`.
  - Assert a save written with an older `schema_version` is wiped to defaults on load (delete-and-recreate), not merged.

- [ ] **Step 7: Final grep — must be clean:**

Run:
```bash
grep -rn "stars\|STAR\|level_for_stars\|stars_at_level\|cell_min_level\|MIN_LEVEL\|appear_level\|spend_stars\|add_stars\|map_cheapest_spot\|map_stars_left" engine/ games/grove/ \
  | grep -v "exp_progression_spec\|docs/" | grep -vi "restart\|starts\|starting"
```
Expected: no matches (every reference migrated/removed). Investigate any hit.

- [ ] **Step 8: Run the full suite + import**

Run: `make import && make test`
Expected: ALL SUITES PASSED.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor(progression): remove spendable stars, level-unit tables, migrations; bump save schema

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Manual verification (before handoff)

- [ ] Launch the app (per the `run` skill): fresh save lands on the hub with the bottom **Unlock** button enabled (first spot at 0 exp). Claim it → spot restores, exp unchanged.
- [ ] Deliver quests → exp total climbs, level badge advances, progress bar bound extends at level-up, the level-up gift (water + gems) pays on Collect.
- [ ] The Unlock button greys with "Unlock — N exp" until exp reaches the next threshold; later maps require visibly larger jumps (escalate-per-map).
- [ ] A board cell opens when exp crosses its `MIN_EXP` (not a level check).

---

## Self-Review Notes

- **Spec coverage:** §1 currency collapse → Task 1/2/3; §2 single sequential button + ladder → Task 1 (ladder) + Task 2 Step 7 (button); §3 level cosmetic + exp gates → Task 2 Steps 2/3/5/6; §4 exp display → Task 2 Step 6; §5 no migration / delete-and-recreate → Task 3 Step 1; §6 rename sweep → Tasks 2-3 + Task 3 Step 7 grep gate; testing → Task 2 Step 9 + Task 3 Step 6.
- **Type consistency:** `map_next_unlock` returns `{k, exp}`; `map_finish_exp` returns an int; both are consumed consistently in `quests.gd` and `map.gd`. `level_for_exp`/`exp_at_level` are pure (take/return ints); `Save.exp_total()`/`Save.add_exp()` own persistence. `earn_exp` is the only writer of `grove.exp` beyond `add_exp`.
- **Open tunables (defaults, adjust post-sim):** `UNLOCK_BASE=3`, `UNLOCK_STEP=3`, `MIN_EXP` (derived from old `MIN_LEVEL` via the curve), `EXP_PER_QUEST_CAP=3`.
