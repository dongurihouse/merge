# Task 6 report — re-tune SCENE_END_LEVEL to model the level-up water gift (content-derived-curve)

Worktree: `/Users/xup/dh/wt-content-derived-curve`, branch `content-derived-curve`.

## What this task did

Task 5's solve for `SCENE_END_LEVEL` didn't model `LEVEL_WATER_GIFT` (the water handed back on
every level-up) in the calculator's day-per-level walk, so the resulting 25-day calendar actually
played out in ~16 days once the gift was live in `grove_sim`. The owner's fix is to raise the
levels (not shrink the gift) so the calendar re-lands on 25 days with the gift now modelled.

### `games/grove/grove_data.gd`
- `const SCENE_END_LEVEL := [19, 29, 39, 48, 58]` → `[25, 36, 46, 58, 71]`.
- Comment rewritten to record: solved for target days 3/4/5/6/7 per scene (25 days, 3
  sessions/day) WITH `LEVEL_WATER_GIFT` modelled; the earlier table ran ~40% fast because the
  gift was unmodelled.
- Nothing else in the data changed: `LEVEL_BASE_COINS` (1), `LEVEL_STEP_COINS` (2),
  `LEVEL_WATER_GIFT` (40), `LEVEL_DIAMONDS` (3), `WATER_CAP` (100), `ZONE_BAND`, and every cluster
  `cost` are untouched.

### `games/grove/tools/pacing_calc.gd`
This file already had an uncommitted diff in the worktree when this task started (a
`_faucet_water()` helper existed and was already used by solve mode, but the report-mode
`day_at` walk at line ~126 hadn't been routed through it — the exact bug the brief describes).
The pending diff:
- Routes the report-mode `day_at` walk through `_faucet_water()` (`raw - LEVEL_WATER_GIFT`,
  floored at 0), so report mode now matches solve mode in modelling the gift.
- Adds `const WALK_MARGIN := 80` and walks `top_level + WALK_MARGIN` levels so the day-at-level
  lookup can answer for target days past where today's gates currently sit.
I left this diff in place (it is the calculator fix the brief's background section describes as
already applied — "The calculator, now modelling the gift, gives the new levels below") and folded
it into this task's commit since it's required to reproduce the new levels and to run the
calculator commands below.

### `engine/scripts/core/content.gd`
No changes. `_build_cadence()` is already fully generic over `SCENE_END_LEVEL` (from Task 5's
re-spine) — moving the constant alone reproduces the new tables.

### Tests
- `engine/tests/scene_cells_tests.gd` — cluster-floor ladder literal and all five
  `scene_level_window` literals updated.
- `engine/tests/mechanics_tests.gd` — cadence literal, the 12-row `_arc` table (level ranges
  moved, line lists unchanged), and two now-stale comments (arc-table upper-bound message,
  scene-window reference in the "scene-aligned cadence" comment) updated. The scene-alignment
  assertion logic itself was untouched and still passes.
- `engine/tests/tuning_tests.gd` — `shipped_cad` and the inline `shipped_floors` literal in the
  dial-drift guard updated. The guard's mutate/restore logic (shrinking `MAPS[0]`'s cluster list,
  then restoring it) was untouched; its final "back to the shipped table" assertion still passes.
- `engine/tests/quest_fence_tests.gd`, `games/grove/tests/grove_explore_tests.gd`,
  `games/grove/tests/grove_board_actions_tests.gd` — ran clean, 0 changes needed. All three derive
  their level boundaries from `G.zone_unlock_level(...)` / `G.cluster_min_level(...)` /
  `G.coins_at_level(...)` rather than pinning literals (per Task 5's fixes), so they followed the
  new cadence automatically.

### `games/grove/economy_tuning.json`
Checked, not changed — already holds `level_base_coins: 1` / `level_step_coins: 2`, matching the
shipped constants.

## Verification

### The exact tables (brief's "THE TABLES THIS MUST PRODUCE")
All match exactly (`scene_cells_tests.gd` / `mechanics_tests.gd` PASS output):
- scene bands: L1-25 · L26-36 · L37-46 · L47-58 · L59-71
- cluster floors: `[1, 6, 11, 15, 20, 25, 26, 29, 31, 34, 36, 37, 39, 42, 44, 46, 47, 50, 53, 55, 58, 59, 63, 67, 71]`
- zone unlocks: `[1, 14, 26, 30, 33, 37, 40, 44, 47, 53, 59, 66]`

### Individual suite runs (foreground)
```
engine/tests/scene_cells_tests.gd         22 passed, 0 failed
engine/tests/mechanics_tests.gd          285 passed, 0 failed
engine/tests/tuning_tests.gd              30 passed, 0 failed
engine/tests/quest_fence_tests.gd         78 passed, 0 failed  (no changes needed)
games/grove/tests/grove_explore_tests.gd 347 passed, 0 failed  (no changes needed)
games/grove/tests/grove_board_actions_tests.gd  87 passed, 0 failed  (no changes needed)
```

### Full sweep
```
make test
33 suites · 2013 passed · 0 failed
ALL SUITES PASSED
```

### Pacing calculator

`godot --headless --path . -s res://games/grove/tools/pacing_calc.gd -- 3 2 20`:
```
== DAYS TO FULLY UNLOCK EACH SCENE ==
  scene                    last cluster    level  cumul.days  days in scene what binds
  Fairy Hollow             lantern_gate    L25    3.1         3.1           LEVEL (cost 38 ≤ wallet ~1267)
  Snowy Village            entrance_arch   L36    7.5         4.4           LEVEL (cost 232 ≤ wallet ~2695)
  Desert Oasis             caravan         L46    13          5.1           LEVEL (cost 803 ≤ wallet ~4455)
  Coral Reef               clam            L58    20          7.3           LEVEL (cost 2180 ≤ wallet ~7148)
  Cherry-Blossom Garden    torii           L71    28          8.4           LEVEL (cost 4290 ≤ wallet ~10780)
  TOTAL: the book is finished on day 28
```
Per-scene cumulative days: 3.1 / 7.5 / 13 / 20 / 28 (target 3/7/12/18/25). The book lands on day
28, about 3 days (12%) past the 25-day target — this calculator report mode is a static per-level
model (no §6 merge bonuses, no sells, no chests), so it's expected to differ from the sim below,
which measures the real bot playing the full economy.

### Simulator

`godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- 40 1` (seed 1):
```
PACING  curve base/step 1/2 · L71 at day 40 · last content zone (L66): day 19 · half the book: day 7 · whole book: day 25
SCENES  (level window · zones inside it · day completed)
  scene 1 Fairy Hollow           L1-25  · zones ["L1", "L14"]    · done day 2
  scene 2 Snowy Village          L26-36  · zones ["L26", "L30", "L33"] · done day 5
  scene 3 Desert Oasis           L37-46  · zones ["L37", "L40", "L44"] · done day 10
  scene 4 Coral Reef             L47-58  · zones ["L47", "L53"]   · done day 17
  scene 5 Cherry-Blossom Garden  L59-71  · zones ["L59", "L66"]   · done day 25
PASS I1: zero jams
PASS no-strand: producible asks + a never-jammed board — the bot can always progress
WARN I2: early map 1 gifts 960💧 vs spend 1165💧 (ratio 0.82) — onboarding + burst front-loads spend; the <30% rule is steady-state (parked pacing pass)
WARN I2: early map 2 gifts 440💧 vs spend 1289💧 (ratio 0.34) — onboarding + burst front-loads spend; the <30% rule is steady-state (parked pacing pass)
PASS I2: every steady-state map (3+) keeps its water gift under 30% of spend (early maps 1-2 noted above)
WARN water self-sustain: gift+§6 water 3780💧 vs spend 10274💧 (37% ≥ 30%) — the §6 faucets erase the early water pinch; budget them against I2 in the tuning pass
PASS Y: the clock advanced on quest coins ALONE (4933🪙); 7917🪙 of sells/pickups/gifts stayed spendable-only
PASS P1: residents are a net coin SINK (-825🪙) — expeditions out-drain the habitat yield+sell.
WARN P2: at the first completion the bot held 1487🪙 — beyond the early sinks (780🪙); early coins pile (raise the expedition cost or open it sooner)
== sim PASS ==
```
Whole book finishes on day 25 — exactly the target. Per-scene done days: 2 / 5 / 10 / 17 / 25
(target 3/7/12/18/25) — front-loaded slightly early but the final day matches exactly.

`godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- 40 7` (seed 7):
```
PACING  curve base/step 1/2 · L72 at day 40 · last content zone (L66): day 17 · half the book: day 6 · whole book: day 28
SCENES  (level window · zones inside it · day completed)
  scene 1 Fairy Hollow           L1-25  · zones ["L1", "L14"]    · done day 2
  scene 2 Snowy Village          L26-36  · zones ["L26", "L30", "L33"] · done day 5
  scene 3 Desert Oasis           L37-46  · zones ["L37", "L40", "L44"] · done day 8
  scene 4 Coral Reef             L47-58  · zones ["L47", "L53"]   · done day 13
  scene 5 Cherry-Blossom Garden  L59-71  · zones ["L59", "L66"]   · done day 28
PASS I1: zero jams
PASS no-strand: producible asks + a never-jammed board — the bot can always progress
WARN I2: early map 1 gifts 960💧 vs spend 1160💧 (ratio 0.83) — onboarding + burst front-loads spend; the <30% rule is steady-state (parked pacing pass)
WARN I2: early map 2 gifts 440💧 vs spend 1262💧 (ratio 0.35) — onboarding + burst front-loads spend; the <30% rule is steady-state (parked pacing pass)
PASS I2: every steady-state map (3+) keeps its water gift under 30% of spend (early maps 1-2 noted above)
WARN water self-sustain: gift+§6 water 3896💧 vs spend 11198💧 (35% ≥ 30%) — the §6 faucets erase the early water pinch; budget them against I2 in the tuning pass
PASS Y: the clock advanced on quest coins ALONE (5116🪙); 8273🪙 of sells/pickups/gifts stayed spendable-only
PASS P1: residents are a net coin SINK (-816🪙) — expeditions out-drain the habitat yield+sell.
WARN P2: at the first completion the bot held 1336🪙 — beyond the early sinks (780🪙); early coins pile (raise the expedition cost or open it sooner)
== sim PASS ==
```
Whole book finishes on day 28 — 3 days (12%) past the 25-day target. Per-scene done days:
2 / 5 / 8 / 13 / 28 (target 3/7/12/18/25) — front-loaded early through scene 4, then scene 5 alone
absorbs the overshoot.

## Concerns — reported, not adjusted (per the brief's instruction)

1. **Book length varies by seed: day 25 (seed 1) vs day 28 (seed 7).** Both are a large
   improvement over Task 5's ~16-day result, and both `sim` runs report `PASS` overall (no I2
   FAIL this time, unlike Task 5's seed run). But the calendar isn't seed-stable to the day — one
   run lands exactly on the 25-day target, the other overshoots by ~12%.
2. **I2 still WARNs on the first two maps** (ratios 0.82-0.83 and 0.34-0.35 vs the 0.30
   steady-state threshold) in both seeds. These are explicitly downgraded to WARN (not FAIL) by
   the sim's own "onboarding + burst front-loads spend" carve-out for maps 1-2, and the overall
   `PASS I2` line confirms steady-state maps (3+) hold under 30%. Flagging in case the owner
   wants the onboarding carve-out itself revisited.
3. **`water self-sustain` WARN persists** (37% / 35%, both ≥ the 30% flag) — the §6 merge-bonus
   and level-gift faucets together still cover more than 30% of total water spend. This is the
   same interaction Task 5 flagged as "owner-aware, deferred"; still true here. Not fixed —
   `LEVEL_WATER_GIFT` and all generator/board dials were left untouched per the brief.
4. The calculator's static report-mode total (day 28, `-- 3 2 20`) doesn't match either sim run
   exactly, which is expected — the calculator ignores §6 merge-bonus coins/water, sells, and
   chests that the sim measures directly.

None of these were used as a reason to adjust `SCENE_END_LEVEL`, the coin curve, cluster costs,
or any generator/board dial — per the brief, the owner decides the next move.

## Commit

See `git log` on branch `content-derived-curve` for the commit SHA; commit message states plainly
that the sim's day-25/day-28 split and the two I2/water-self-sustain WARNs are measurements, not
gates, and were not used to adjust any dial.
