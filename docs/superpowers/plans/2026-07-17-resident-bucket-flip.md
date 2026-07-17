# Resident Bucket Flip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the pure `resident_bucket.gd` module into the game as the ONLY resident system and rip out the per-map habitat (`engine/scripts/core/habitat.gd`), per `docs/superpowers/specs/2026-07-16-global-resident-bucket-design.md`.

**Architecture:** A thin Save-backed adapter (`engine/scripts/core/bucket.gd`) is the single game-facing API: it persists the pure module's state dict under `Save.grove()["bucket"]`, injects real time/RNG, derives cells from map completion, credits collected lines into currencies, and migrates old habitat saves (placed+hand → hand, kinds → lines). UI/game callers (map select dock, expedition reward reveal, board boost chip, debug) switch from `Habitat` to `Bucket`; the per-map habitat card, home-map placement rules, and per-map collect all retire. `habitat.gd` is deleted.

**Tech Stack:** GDScript (Godot 4.6), headless suites via `make test-fast` / `make test`, real-renderer screenshot for the dock visual check.

## Global Constraints

- The pure module (`resident_bucket.gd`) is NOT modified.
- Line↔art mapping: `coin→sprout`, `water→dewdrop`, `boost→ember`, `diamond→starlight`; legacy `breeze` migrates to the coin line. Art paths stay `items/resident_<kind>/resident_<kind>_<tier>.png`.
- Cells come ONLY from fully-restored maps: grants `[2, 1, 2, 1, 2]` per map (8 total) — no coin capacity sink.
- Migration is non-destructive: every legacy spirit (hand + all per-map placed) lands in the new hand at its tier; last-settled banked accruals are credited as floor(acc) in the old map's currency; live un-settled accrual since the last old-model settle is forfeited (accepted, small).
- Selling credits coins inside the adapter (UI never touches Save for it).
- All suites in the ACTIVE lists must pass (`make test`); the reworked dock must be verified with a real rendered screenshot (no window focus steal — `override.cfg` with `no_focus` + minimized mode).

---

### Task 1: Line mappings (grove_data) + the Save adapter + adapter tests

**Files:**
- Modify: `games/grove/grove_data.gd` (near `RESIDENT_LINES`)
- Create: `engine/scripts/core/bucket.gd`
- Create: `engine/tests/bucket_adapter_tests.gd`
- Modify: `Makefile` (append `engine/tests/bucket_adapter_tests` to `ENGINE_TESTS`)

**Interfaces produced (later tasks rely on):** `Bucket.MAX_TIER`, `Bucket.SELL_PER_TIER`, `Bucket.LINES`, `state() -> Dictionary`, `cells_total() -> int`, `hand() -> Array` / `placed() -> Array` (entries `{line, tier}`), `hand_add(line, tier=1) -> int`, `hand_merge(i, j) -> bool`, `place(hand_index) -> bool`, `place_merge(hand_index, placed_index) -> bool`, `unplace(placed_index) -> bool`, `sell_hand(i) -> int` / `sell_placed(i) -> int` (credit coins, return amount), `pending_line(line) -> float`, `collect() -> Dictionary` (credits currencies + boost stockpile), `boost_charges() -> int` / `spend_boost_charge() -> bool`, `grant_box(count) -> Array` of `{line, kind, tier}`, `line_kind(line) -> String`, `kind_line(kind) -> String`.

Data consts in `grove_data.gd`:

```gdscript
# The global resident bucket (grove_spec §3): four resource LINES, each arted by one of the existing
# resident families. breeze (air) is retired — legacy breeze spirits migrate to the coin line.
const RESIDENT_LINE_KINDS := {"coin": "sprout", "water": "dewdrop", "boost": "ember", "diamond": "starlight"}
const RESIDENT_KIND_LINES := {"sprout": "coin", "dewdrop": "water", "ember": "boost", "starlight": "diamond", "breeze": "coin"}
# Cells granted per FULLY-restored map (index = map z). 8 total across the home grove — the only capacity source.
const BUCKET_CELL_GRANTS := [2, 1, 2, 1, 2]
```

Adapter core (full file in the implementation; key parts):

```gdscript
extends RefCounted
## Save-backed adapter over the PURE resident bucket (resident_bucket.gd). The ONLY game-facing
## resident API: real time + RNG live here, the module owns every rule.
const Save = preload("res://engine/scripts/core/save.gd")
const Game = preload("res://engine/scripts/core/game.gd")
const Content = preload("res://engine/scripts/core/content.gd")
const RB = preload("res://engine/scripts/core/resident_bucket.gd")
const D = Game.DATA
const MAX_TIER := RB.MAX_TIER
const SELL_PER_TIER := RB.SELL_PER_TIER
const LINES := RB.LINES

static func now() -> float:
	return Time.get_unix_time_from_system()

static func cells_total() -> int:
	var unlocks: Dictionary = Save.grove().get("unlocks", {})
	var total := 0
	for z in Content.MAPS.size():
		if z >= D.BUCKET_CELL_GRANTS.size():
			break
		if Content.map_spots_restored(z, unlocks) >= Content.MAPS[z].spots.size():
			total += int(D.BUCKET_CELL_GRANTS[z])
	return total

static func state() -> Dictionary:
	var g := Save.grove()
	if not g.has("bucket"):
		g["bucket"] = _migrated_state(g)
	var st: Dictionary = g["bucket"]
	st["cells"] = cells_total()          # cells are DERIVED, re-synced on every access
	return st

static func _migrated_state(g: Dictionary) -> Dictionary:
	var st := RB.make_state(now())
	for inst in g.get("hand", []):
		_migrate_spirit(st, inst)
	var hab: Dictionary = g.get("habitat", {})
	for mid in hab:
		for inst in hab[mid]:
			_migrate_spirit(st, inst)
	var old_cur := {"farmhouse": "coin", "barn": "water", "pond": "boost", "orchard": "diamond"}
	var prod: Dictionary = g.get("hab_prod", {})
	for mid in prod:
		var whole := int(floor(float(prod[mid].get("acc", 0.0))))
		if whole > 0 and old_cur.has(mid):
			_credit_line(String(old_cur[mid]), whole)
	for key in ["hand", "habitat", "hab_prod", "hab_cap"]:
		g.erase(key)
	return st

static func _migrate_spirit(st: Dictionary, inst: Dictionary) -> void:
	var line := String(D.RESIDENT_KIND_LINES.get(String(inst.get("kind", "")), ""))
	if line != "":
		RB.hand_add(st, line, int(inst.get("tier", 1)))

static func collect() -> Dictionary:
	var st := state()
	var got := RB.collect(st, now())
	for line in got:
		_credit_line(String(line), int(got[line]))
	Save.grove_write()
	return got

static func _credit_line(line: String, amount: int) -> void:
	match line:
		"coin":    Save.add_coins(amount)
		"water":   Save.add_water(amount)
		"diamond": Save.add_diamonds(amount)
		"boost":   Save.grove()["boost_charges"] = boost_charges() + amount
```

Every mutating wrapper (`hand_add`, `hand_merge`, `place`, `place_merge`, `unplace`, `sell_*`, `grant_box`) calls the module op on `state()` then `Save.grove_write()`. `sell_hand`/`sell_placed` also `Save.add_coins(got)`. `grant_box` uses a lazily-randomized static loot RNG (same pattern habitat used) and decorates each grant with `kind: line_kind(line)` for reveal art. `boost_charges`/`spend_boost_charge` keep the `boost_charges` save key verbatim.

- [ ] Steps: write `engine/tests/bucket_adapter_tests.gd` first (same harness as `resident_bucket_tests.gd`, but it must reset save state per test like grove suites do — use `Save` test helpers if available or set `Save.grove()` keys directly), covering: fresh state has 0 cells; restoring all of map 0's spots yields `cells_total() == 2` and all five maps yields 8; migration (old hand `ember` t3 + placed `breeze` t2 on farmhouse + `hab_prod` farmhouse acc 2.7 → new hand has boost t3 + coin t2, coins +2, old keys erased, `g.bucket` present); `sell_hand` credits coins; `collect` credits each line's currency (place coin+water+diamond spirits with a pinned high-rate cfg? the adapter has no cfg param — instead pre-seed `state().banks` directly and assert crediting + water clamping to `WATER_CAP` + `boost_charges` stockpile growth); `grant_box(3)` lands 3 spirits in hand with valid `{line, kind, tier}`; `spend_boost_charge` decrements and refuses at 0. Run failing → implement `grove_data` consts + `bucket.gd` → run passing → register in Makefile → `make test-fast` → commit `feat(bucket): save adapter — migration, cells-from-completion, collect crediting`.

---

### Task 2: Switch expedition rewards, board boost chip, and debug to the adapter

**Files:**
- Modify: `engine/scripts/ui/explore_reward.gd` (preload + `grant_chest` call at :47, art at :204 — grants now `{line, kind, tier}`, art keeps using `kind`)
- Modify: `engine/scripts/scenes/board.gd` (:15 preload → `bucket.gd`; :2021/:2803/:2804 `Habitat.` → `Bucket.`)
- Modify: `engine/scripts/scenes/map.gd` `debug_add_resident_to_hand`/`_debug_resident_kind` (:364-:395) — pick a random LINE id via `Bucket.hand_add`
- Modify: `games/grove/tests/grove_explore_tests.gd` (7 `Habitat.` refs → adapter equivalents)

- [ ] Steps: update the three call sites; grove_explore tests: grant/reveal assertions now check `line`+`kind` fields and hand growth via `Bucket.hand()`. Run `make test-fast` + `make test-one SUITE=games/grove/tests/grove_explore_tests` → commit `feat(bucket): expedition boxes, board boost, debug hand-add ride the adapter`.

---

### Task 3: The map-select dock becomes the bucket surface; habitat card + home-map rules retire

**Files:**
- Modify: `engine/scripts/scenes/map.gd`
- Modify: `games/grove/tests/grove_residents_tests.gd` (full rewrite — guards the adapter + the new dock)

The UI flip, all inside `map.gd`:

1. Preload swap: `const Bucket = preload("res://engine/scripts/core/bucket.gd")` replaces the `Habitat` preload; every remaining `Habitat.` becomes the adapter equivalent.
2. `_make_card`: DELETE the completed-map branch (`_habitat_card`) — every open map renders the standard vista card (`done` state already renders a done look). Delete `_habitat_card`, `_add_habitat_strip`, `_habitat_plate`, `_inset_fill` (if now unused), `_on_card_collect`, `_collect_fx` per-card wiring, `_collection_time_label`, `_reward_amount_ready`, `_reward_amount_cap`, `_reward_icon`/`_reward_label` (keep if the dock collect chip reuses them — it does, keep those two).
3. `_build_hand_panel` becomes the bucket board: title "Spirits"; a **cells section** on top — a `GridContainer` named `BucketCellsGrid` (4 columns) holding one `Kit.slot_cell` per cell: placed spirits as orbs (`_spirit_cell`), remaining capacity as empty cells; `_placed_orbs` entries become `{node, idx, line, kind, tier}` (no `map_id`/`z`). Below it a **collect chip** (`BucketCollectChip`, a Button row): per-line ready amounts `floor(Bucket.pending_line(l))` with `_reward_icon` glyphs, disabled when nothing is ready, pressed → `Bucket.collect()` → FX floaters per granted line → `_refresh_picker()`. Below that the existing "In hand" grid + info bar unchanged (info bar's Sell label uses `Bucket.SELL_PER_TIER`).
4. Drag/drop (`_resolve_drop`): hand→matching placed orb = `Bucket.place_merge(d.idx, o.idx)`; hand→cells-grid rect (any empty cell / the grid) = `Bucket.place(d.idx)` (refuse with "Full" floater when `placed().size() >= cells_total()`); hand→matching hand orb = `Bucket.hand_merge(o.idx, d.idx)` — NOTE the pure module keeps index `i` and removes `j`, so pass target first; placed→hand panel = `Bucket.unplace(d.idx)`. DELETE the map-card drop zone path, `_card_dropzone`, `can_place_on` checks, and the whole home-map hint system (`_selected_hand_home_z`, `_drag_hand_home_z`, `_card_hint_state`, `_apply_card_hint`, `_refresh_card_hints` calls).
5. Sell: `_on_focus_sell` → `Bucket.sell_placed(idx)` / `Bucket.sell_hand(idx)` (adapter credits coins; keep the existing coin FX using the returned amount).
6. Ambient: `_habitat_members(z)` returns the GLOBAL `Bucket.placed()` mapped to `{type: line_kind, tier}` for any COMPLETED map (the "roster wanders the map you're viewing" polish, free now); un-completed maps keep the simple count path.
7. `hand_add` at :368 (quest/gift path) → `Bucket.hand_add` with a line id.
8. `_orb_at`, `_on_orb_tap`, `_sel_orb`: drop `map_id`/`z` fields for placed orbs.

`grove_residents_tests.gd` rewrite — same base, new guards: adapter hand/merge/place/sell paths (through `Bucket`), cells ramp (0 cells → no placement; restore map 0 → 2 cells), place-merge via dock indexes, collect crediting (pre-seeded banks), migration smoke, and the dock scene test: build the select screen, assert `HandColumn/BucketCellsGrid` exists with `cells_total()` cells, `HandGrid` shows the hand, `BucketCollectChip` present, a drag-merge in hand still works (adapt the existing `_test_hand_drop_merge_targets_slot` to the two-index API), and NO `_habitat_card` nodes render for a completed map.

- [ ] Steps: rewrite tests first where they drive the adapter (they fail against the old UI), then flip `map.gd` section by section (2→8), keeping `make test-one SUITE=games/grove/tests/grove_residents_tests` as the loop; then `make test-fast`; commit `feat(bucket): map dock is the global bucket surface; habitat card + home-map rules retired`.

---

### Task 4: Delete habitat.gd, sweep stragglers, full verification

**Files:**
- Delete: `engine/scripts/core/habitat.gd` (+ `.uid`)
- Modify: `engine/scripts/core/content.gd` (:666-:684 comment + `resident_capacity` — retire the habitat references; keep `resident_art`, `resident_lines` for art/ambient)
- Modify: any remaining `habitat` references (`grep -rn "habitat\|Habitat" engine games --include="*.gd"` must return only historical comments or nothing)
- Modify: `games/grove/tools/residents_shot.gd` if it drives the old model (update to the bucket dock or retire it)

- [ ] Steps: delete + sweep → `make test` (full, all suites green) → real-renderer screenshot of the map-select dock (transient `override.cfg` with `[display] window/size/no_focus=true` + `window/size/mode=1`, run the shot tool, remove override; view the PNG) → commit `feat(bucket): rip out per-map habitat — the global bucket is the resident system`.

---

## Out of scope

Almanac/collection UI, rarity-frame art, the sim re-author (dials stay provisional), post-launch map grants beyond the five home-grove maps.
