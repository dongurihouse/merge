# Home Build-and-Upgrade Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the mask-based multi-map restoration system with one evolving home world of coin-built, level-gated, customizable buildings rendered through the layered cut-paper pipeline (spec: `docs/superpowers/specs/2026-07-17-home-build-upgrade-map-design.md`).

**Architecture:** A pure `home_build.gd` module (state + rules, `resident_bucket.gd` pattern) drives per-building step progression; level becomes a curve over lifetime organic coin earnings (`Save.earn_coins`); the Home scene renders zone manifests (foundation + state-swapped props, the workbench prototype promoted); the board's 25-zone content arc decouples from map spots onto pure level thresholds; bucket cells re-derive from completed buildings. Big-bang on main (Approach C) — breakage between tasks accepted, each task still commits green where possible.

**Tech Stack:** Godot 4.6 GDScript, headless SceneTree test suites via `engine/tools/run_suites.py` (`make test-fast` / `make test`), JSON zone manifests from the cut-paper pipeline.

## Global Constraints

- Run `make test-fast` after every change; full `make test` before hand-off (CLAUDE.md).
- Never let a test run open a window — headless only; screenshots via `tools/quiet_godot.sh` pattern (override.cfg) or existing `make shot-*` targets.
- Save schema: bump `SCHEMA_VERSION` 4 → 5 exactly once (Task 7); no migrations (delete-and-recreate is the established rule, `save.gd:52`).
- Art is archived, never deleted (`games/grove/assets/_archive/`).
- Buildings never produce currency. Production stays in the resident bucket.
- Purchased coins (shop 5💎→150🪙) must NOT advance the level clock; every organic coin earn must.
- All costs/thresholds/cell counts are placeholder dials for the Dev tuning pass — mark them `PROVISIONAL` in comments.
- Float32 Control geometry: compare positions/sizes with `is_equal_approx` in tests, never `==`.

## File Structure

- Create: `engine/scripts/core/home_build.gd` — pure build-progression module (no Save/scene deps).
- Create: `engine/scripts/core/home.gd` — Save-backed adapter over home_build (bucket.gd pattern).
- Create: `engine/tests/home_build_tests.gd`, `engine/tests/home_adapter_tests.gd`.
- Create: `games/grove/assets/map/home/zone_farmhouse.json` — promoted prop manifest (art + placement, pipeline-owned).
- Modify: `games/grove/grove_data.gd` — `BUILDINGS` gameplay table (steps/costs/cells, owner-owned); delete `MAPS` 2–5 + mask `home` block; `ZONE_BAND` const replacing spot-derived banding.
- Modify: `engine/scripts/core/save.gd` — `coins_earned_lifetime` counter, `earn_coins()`; schema bump.
- Modify: `engine/scripts/core/content.gd` — level-from-coins clock; zone gating on pure level; retire exp + spot-unlock ladder.
- Modify: `engine/scripts/core/board_actions.gd`, `engine/scripts/scenes/board.gd` — quest rewards coins-only; earn path routes through `earn_coins`.
- Modify: `engine/scripts/core/bucket.gd` — `cells_total()` from completed buildings.
- Modify: `engine/scripts/scenes/map.gd` — carved down to the Home controller: select-view, mask reveal, vines, ★ claim flow deleted; layered zone renderer + build/customize dialogs in.
- Delete/retire: vine subsystem (`games/grove/vine`, `grove_vine_*_tests`), `map_shot.gd` → `home_shot.gd`, mask assets → `_archive`.
- Tests to update: `mechanics_tests` (zone guard), `quest_tests`, `level_badge_tests`, `map_canvas_tests`, `mapfx_tests`, `save_tests`, grove suites.

---

### Task 1: Coin clock — `Save.earn_coins` + level-from-coins

**Files:**
- Modify: `engine/scripts/core/save.gd` (after `add_coins`, `save.gd:111`)
- Modify: `engine/scripts/core/content.gd:1301-1375` (progression block)
- Test: `engine/tests/save_tests.gd`, `engine/tests/mechanics_tests.gd`

**Interfaces:**
- Produces: `Save.coins_earned_lifetime() -> int`; `Save.earn_coins(n: int) -> void` (adds to balance AND lifetime); `G.level() -> int` (level from lifetime coins); `G.earn_coins(n: int) -> int` (earn + report levels gained, replaces `earn_exp`); `G.level_at_coins(earned: int) -> int` and `G.coins_at_level(level: int) -> int` (renamed curve, same arithmetic shape, re-tuned dials `LEVEL_BASE_COINS`/`LEVEL_STEP_COINS` in grove_data — PROVISIONAL: 30/12).
- Consumes: existing `LEVEL_BASE_EXP`/`LEVEL_STEP_EXP` pattern (`grove_data.gd`), `level_gift`/`grant_level_gift` (unchanged).

- [ ] Step 1: Write failing tests — lifetime counter (earn bumps both, add_coins bumps balance only, spend never reduces lifetime, JSON round-trip), curve (level 1 at 0, thresholds monotone, purchased coins excluded from level).
- [ ] Step 2: Run the two suites; expect FAIL (missing methods).
- [ ] Step 3: Implement `save.gd` (`grove()["coins_earned"]` counter) and `content.gd` (`level()`, `earn_coins()` mirroring `earn_exp` semantics — returns levels gained for the Level dialog).
- [ ] Step 4: Suites pass. Keep `exp_total`/`add_exp`/`earn_exp` in place (Task 3 removes them).
- [ ] Step 5: Commit `feat(clock): level derives from lifetime organic coin earnings`.

### Task 2: Home build module + adapter

**Files:**
- Create: `engine/scripts/core/home_build.gd`, `engine/scripts/core/home.gd`
- Create: `games/grove/grove_data.gd` `BUILDINGS` table
- Test: `engine/tests/home_build_tests.gd` (new suite; register in `engine/tools/run_suites.py` list if explicit)

**Interfaces:**
- Produces (pure module, state = `{built: {id: steps_done}, custom: {id: variant_id}}`):
  - `HomeBuild.make_state() -> Dictionary`
  - `HomeBuild.steps_done(st, id) -> int`, `HomeBuild.is_built(st, def) -> bool`
  - `HomeBuild.next_step(st, def) -> Dictionary` (`{}` when built; else `{index, cost_coins, min_level, shows_state}`)
  - `HomeBuild.can_buy_step(st, def, level, coins) -> String` ("" ok | "level" | "coins" | "built")
  - `HomeBuild.buy_step(st, def) -> bool` (advance one step; no wallet knowledge)
  - `HomeBuild.state_id(st, def) -> String` (current art state: empty/site_N/built/variant)
  - `HomeBuild.cells_granted(st, defs) -> int` (sum over built buildings)
  - `HomeBuild.set_custom(st, def, variant_id) -> bool`
- Produces (adapter, persisted at `Save.grove()["home"]`): `Home.next_step(id)`, `Home.buy_step(id) -> Dictionary` outcome (`{ok, reason, built, levels_up:0}`) — spends via `Save.spend`, level via `G.level()`; `Home.state_id(id)`, `Home.cells_total()`, `Home.buy_custom(id, variant_id)` (coins or diamonds per def).
- `BUILDINGS` def shape (PROVISIONAL dials): `{id, cells, steps: [{cost, min_level, shows}], customizations: [{id, cost, currency}]}` — 7 rows matching the manifest ids (`fh_hearth`, `fh_larder`, `fh_boxes`, `fh_kitchen`, `fh_well`, `fh_lantern`, `fh_porch`).

- [ ] Step 1: Failing tests — step order, level gate, coin gate, built terminal, cells granted exactly once per building (idempotent re-read), customization only when built, save round-trip through adapter with `Save.configure_for_test`.
- [ ] Step 2: Run suite, expect FAIL. Step 3: implement module + adapter + BUILDINGS. Step 4: green. Step 5: Commit `feat(home): pure build-step module + save adapter`.

### Task 3: Retire exp; quests pay coins only

**Files:**
- Modify: `engine/scripts/core/board_actions.gd:32-37,63-64`, `engine/scripts/core/quests.gd` (exp calc → fold into coins), `engine/scripts/scenes/board.gd:1160` (debug), `engine/scripts/core/content.gd` (delete `earn_exp`, `exp_total` reads, `QUEST_EXP_LINE_SPREAD` usage → coin spread), `engine/scripts/core/save.gd` (delete `exp_total`/`add_exp`), special drop "exp" kind → coins.
- Test: `engine/tests/quest_tests.gd`, `grove_board_actions_tests.gd`, `engine/tests/level_badge_tests.gd` (badge reads `G.level()`).

**Interfaces:**
- `deliver_quest` outcome becomes `{code, coins, levels_up, cell}` — `levels_up` from `G.earn_coins(sp_coins)`; scenes' `outcome.exp` readers updated.
- Quest reward: former exp value folds into the coin formula via existing `QUEST_CLICKS_PER_COIN` path (dial PROVISIONAL; sim re-pass owns tuning).

- [ ] Step 1: Update tests to assert coins-only outcomes + level from coins. Step 2: FAIL. Step 3: rewire; delete exp accessors. Step 4: `make test-fast` green (grove suites may still be red — noted per-commit). Step 5: Commit `feat(clock): quests pay coins only; exp retired`.

### Task 4: Decouple the 25-zone content arc from map spots

**Files:**
- Modify: `engine/scripts/core/content.gd` — `zone_unlock_level(z) = 2 + z` (one zone per level, preserving the L2–L26 arc the MIN_LEVEL grid + sim assume); `zone_map`/`map_for_spots` → read new `const ZONE_BAND := [6, 4, 7, 4, 4]` (pure banding for `SELL_MAP_BAND`/`QUEST_CLICKS_PER_COIN`); delete `spot_unlock_level/exp`, `global_spot_index`, `map_next_unlock`, `map_finish_exp` (frontier/gate reads move to level or Home).
- Modify: `games/grove/grove_data.gd` — GENERATORS keep `zone`; their `map` field re-checked against ZONE_BAND by the mechanics guard.
- Test: `engine/tests/mechanics_tests.gd` (the zone↔map guard re-pinned to ZONE_BAND), `quest_tests`, `gendim_tests`.

- [ ] Steps: failing guard first, implement, green, commit `feat(zones): content arc gates on pure level; map-spot coupling cut`.

### Task 5: Home scene — carve map.gd, layered zone renderer

**Files:**
- Create: `games/grove/assets/map/home/zone_farmhouse.json` (copy `home_props.json`, add `"states"` per prop: `{empty: null, site: <shared site texture placeholder>, built: <current prop texture>}` — v1 site art may reuse the built texture at reduced modulate until pipeline delivers site sprites; flagged PROVISIONAL art).
- Modify: `engine/scripts/scenes/map.gd` — delete: select view (`_view == "select"`, cards, scroll), mask reveal (`_build_home_spot`, clean/broken plates), vines + shatter veil, ★ claim flow (`unlocks[...] = true` path, `map.gd:1893`), `decorate_map` multi-map static. Keep: chrome, HUD, resident dock/hand panel, single-input surface, login/vault/settings wiring. Replace `_build_map` internals with the layered renderer (foundation TextureRect + per-building prop from `Home.state_id`, center-bottom anchor, `sort_y` painter order — the workbench recipe, `home_layer_workbench.gd:44-60`). Build badge per unbuilt building: cost + level from `Home.next_step`; tap → confirm dialog → `Home.buy_step` → prop swap + level-up dialog on `levels_up`; built + customizations → variant list dialog (reuse the existing variant-list card).
- Modify: `engine/scripts/scenes/board.gd` — SceneWarm targets stay `Map.tscn` (scene file name kept; controller renamed internally to Home in doc comments).
- Test: `engine/tests/map_canvas_tests.gd` reworked → asserts: one prop node per building, painter order, state texture matches `Home.state_id`, single input surface; `mapfx_tests` trimmed of shatter/vine.

- [ ] Steps: write renderer asserts (FAIL), carve + implement, headless green, commit `feat(home): layered zone renderer replaces mask/select map`.

### Task 6: Bucket cells from buildings

**Files:**
- Modify: `engine/scripts/core/bucket.gd:29-40` — `cells_total()` = `Home.cells_total()`; delete `BUCKET_CELL_GRANTS` map-indexed read (const retires in grove_data; per-building `cells` replaces it).
- Test: `engine/tests/bucket_adapter_tests.gd`, `engine/tests/resident_bucket_tests.gd` (module untouched).

- [ ] Steps: failing adapter test (cells follow built buildings), implement, green, commit `feat(bucket): cells derive from completed buildings`.

### Task 7: Deletions, schema bump, debug grant

**Files:**
- Modify: `games/grove/grove_data.gd` — MAPS rows 2–5 and the `home` mask block deleted; `_build_maps`/VineMaps wiring removed; map-indexed dials re-keyed to ZONE_BAND.
- Modify: `engine/scripts/core/save.gd:15` — `SCHEMA_VERSION := 5` (wipe).
- Delete: `games/grove/vine/`, `grove_vine_tests.gd`, `grove_vine_tool_tests.gd`, `gate_unveil_tests` vine cases; `tools/map_shot.gd` → `tools/home_shot.gd` (same quiet pattern); mask art `assets/map/farm/` → `assets/_archive/map_farm_masks/`.
- Modify: `engine/scripts/ui/debug.gd` — debug grant: +coins, +lifetime coins (level), preset built buildings.
- Test: full `make test` sweep — every suite green or explicitly retired with its subsystem.

- [ ] Steps: delete, re-run, fix stragglers, commit `feat(home): retire maps 2-5, vines, masks; schema v5`.

### Task 8: Verification (blocking gate)

- [ ] `make test` fully green (paste the timing table into the hand-off note).
- [ ] `make home-layers`-style screenshot of the real Home scene default state (fresh save: all plots empty, badges priced) AND a debug-built state — through the quiet_godot path; deliver both PNGs for the Dev share-gate eyeball (never self-judged).
- [ ] Board→Home→Board navigation exercised headlessly (SceneWarm.go path smoke test).
- [ ] Commit + summary; economy sim re-pass parked as the explicit follow-up (spec §4 invariants).

## Self-Review

- Spec coverage: §1→Tasks 2/3/6, §2→Task 5, §3→Tasks 2/5, §4→Tasks 1/2/3, §5→Tasks 5/7, §6→Task 7, §7→Tasks 1-6 tests + Task 8, §8→out of scope (pipeline). Gap: none — sim re-pass intentionally parked (spec §4).
- Type consistency: `Home.buy_step` outcome mirrors `deliver_quest` outcome shape (`levels_up` int); `state_id` naming used in Tasks 2 and 5 consistently.
- Placeholders: art site-sprites and all dials are explicitly PROVISIONAL by design (spec: tuning owned by the Dev pass) — not plan gaps.
