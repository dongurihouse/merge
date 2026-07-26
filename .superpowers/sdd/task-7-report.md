# Task 7 report — SCENE_END_LEVEL re-tune (front-load fix)

## The change

`games/grove/grove_data.gd`:

```
const SCENE_END_LEVEL := [25, 36, 46, 58, 71]   ->   const SCENE_END_LEVEL := [28, 41, 54, 64, 71]
```

The prior solve hit the 25-day total but front-loaded the split (measured 2/5/10/17/25
instead of the owner's target 3/4/5/6/7-day-per-scene, cumulative 3/7/12/18/25). The new
levels are what `grove_sim` actually reaches on days 3/7/12/18/25, averaged over seeds
1, 7, 42, at 3 sessions/day — measured off the running simulator, not re-derived
analytically from `pacing_calc.gd`'s model (that model is what produced the front-loaded
values in the first place, since it doesn't fully match the sim's live economy).

Comment above the const updated to record this. Nothing else in `grove_data.gd` changed:
`LEVEL_BASE_COINS` (1), `LEVEL_STEP_COINS` (2), `LEVEL_WATER_GIFT` (40), `LEVEL_DIAMONDS` (3),
`WATER_CAP` (100), `ZONE_BAND`, and every cluster `cost` are untouched.

## Derived tables produced (verified against the running code)

Scene bands: `L1-28 · L29-41 · L42-54 · L55-64 · L65-71`

Cluster floors (25, one per cluster):
`[1, 6, 12, 17, 23, 28, 29, 32, 35, 38, 41, 42, 45, 48, 51, 54, 55, 57, 60, 62, 64, 65, 67, 69, 71]`

Zone unlock cadence (12 zones):
`[1, 15, 29, 33, 38, 42, 46, 51, 55, 60, 65, 69]`

Both match exactly what the task spec called for — no spread-formula edits were needed in
`content.gd`'s `_build_cadence()`.

## Test literals updated

- `engine/tests/scene_cells_tests.gd` — the 25-entry cluster-floor ladder, and the five
  `scene_level_window` literals (`Vector2i(1,28)` … `Vector2i(65,71)`).
- `engine/tests/mechanics_tests.gd` — the 12-entry cadence literal, and the full per-zone
  arc range table (`z0 L1-14` … `z11 L69-85`), plus its holds-at-every-level comment
  (`L1-L85`, was `L1-L80`) and a scene-window comment mentioning the FH/SV/DO/CR/CB ranges.
- `engine/tests/tuning_tests.gd` — `shipped_cad` and `shipped_floors` in the "derived gates
  follow SCENE_END_LEVEL" guard block; the block's later mutate/restore assertions
  (moving `LEVEL_BASE_COINS`/`LEVEL_STEP_COINS`, shrinking Fairy Hollow's cluster count,
  restoring `MAPS`) were left as-is since they compare against the (now-updated)
  `shipped_cad`/`shipped_floors` variables rather than hardcoding a second copy — all still
  pass, including the final "back to the shipped table" assertion.

## Test literals that needed no edits, except one

`quest_fence_tests.gd` and `grove_explore_tests.gd` needed no changes — they derive their
boundaries from the cadence, as expected.

`grove_board_actions_tests.gd`'s `_test_retire_line()` DID need a fix: it computes
`_z3 := G.zone_unlock_level(3)` (correctly derived) for its early assertions, but then
re-used a **hardcoded literal `30`** (the old cadence's value for `zone_unlock_level(3)`)
in four later calls — `G.retirable_gens([...], 30)` and three `BoardActions.retire_line(...,
30)` calls. With the new cadence `zone_unlock_level(3) == 33`, testing retirement at level
30 no longer lands on the correct boundary, so 7 assertions failed. Fixed by replacing the
literal `30` with the already-in-scope `_z3` variable at all four call sites — deriving
rather than pinning, per the task's instruction. All 87 assertions in that suite now pass.

## Test results

Individual suites (foreground, explicit runs):

```
scene_cells_tests.gd         22 passed, 0 failed
mechanics_tests.gd          285 passed, 0 failed
tuning_tests.gd               30 passed, 0 failed
quest_fence_tests.gd          78 passed, 0 failed
grove_explore_tests.gd       347 passed, 0 failed
grove_board_actions_tests.gd  87 passed, 0 failed   (after the _z3 fix; 7 failed before it)
```

Full sweep: `make test` → **33 suites · 2013 passed · 0 failed · ALL SUITES PASSED**.

## grove_sim measurement — 3 seeds, 30 days, 3 sessions/day

### Seed 1

SCENES table (done day):
```
scene 1 Fairy Hollow           L1-28  · done day 2
scene 2 Snowy Village          L29-41 · done day 6
scene 3 Desert Oasis           L42-54 · done day 12
scene 4 Coral Reef             L55-64 · done day 17
scene 5 Cherry-Blossom Garden  L65-71 · done day 24
```
Implied days-in-scene: 2, 4, 6, 5, 7 (cumulative 2/6/12/17/24).
Clusters unlocked: 25/25. Pages completed: 5. Last content zone (L69): day 18. Whole book: day 24.
- I2: WARN early map 1 gifts 1080💧 vs spend 1399💧 (ratio 0.77); WARN early map 2 gifts 520💧 vs spend 1662💧 (ratio 0.31); PASS every steady-state map (3+) keeps its water gift under 30% of spend.
- Water self-sustain: WARN gift+§6 water 3826💧 vs spend 10197💧 (38% >= 30%).
- Final line: `== sim PASS ==`

### Seed 7

SCENES table (done day):
```
scene 1 Fairy Hollow           L1-28  · done day 3
scene 2 Snowy Village          L29-41 · done day 7
scene 3 Desert Oasis           L42-54 · done day 13
scene 4 Coral Reef             L55-64 · done day 19
scene 5 Cherry-Blossom Garden  L65-71 · done day 24
```
Implied days-in-scene: 3, 4, 6, 6, 5 (cumulative 3/7/13/19/24).
Clusters unlocked: 25/25. Pages completed: 5. Last content zone (L69): day 21. Whole book: day 24.
- I2: WARN early map 1 gifts 1080💧 vs spend 1455💧 (ratio 0.74); PASS every steady-state map (3+) keeps its water gift under 30% of spend.
- Water self-sustain: WARN gift+§6 water 3702💧 vs spend 9770💧 (38% >= 30%).
- Final line: `== sim PASS ==`

### Seed 42

SCENES table (done day):
```
scene 1 Fairy Hollow           L1-28  · done day 2
scene 2 Snowy Village          L29-41 · done day 7
scene 3 Desert Oasis           L42-54 · done day 12
scene 4 Coral Reef             L55-64 · done day 18
scene 5 Cherry-Blossom Garden  L65-71 · done day 23
```
Implied days-in-scene: 2, 5, 5, 6, 5 (cumulative 2/7/12/18/23).
Clusters unlocked: 25/25. Pages completed: 5. Last content zone (L69): day 21. Whole book: day 23.
- I2: WARN early map 1 gifts 1080💧 vs spend 1215💧 (ratio 0.89); PASS every steady-state map (3+) keeps its water gift under 30% of spend.
- Water self-sustain: WARN gift+§6 water 3840💧 vs spend 9404💧 (41% >= 30%).
- Final line: `== sim PASS ==`

## Reading the result against the target

Target: cumulative 3 / 7 / 12 / 18 / 25 (durations 3/4/5/6/7 days per scene).

Measured mean cumulative days across the 3 seeds: **2.33 / 6.67 / 12.33 / 18.0 / 23.67**.

Per-scene, the fit is close for scenes 2-4 (within ~1 day of target on every seed) but:

- Scene 1 (Fairy Hollow) still finishes a touch early (day 2-3 vs target 3) — the anchor
  zone is cheap and fast regardless of the gate level.
- The whole book finishes at day 23-24 on every seed, **short of** the 25-day target, not
  long of it. This is the opposite of what the task brief flagged as the likely direction
  (raising zone unlocks slows early coin income) — here the level rise happened to move
  enough of the SELL_MAP_BAND / QUEST_CLICKS_PER_COIN steps earlier in the run that
  per-session coin income at the higher gate levels outpaced the water-clock's slower
  climb, so the last cluster (Cherry-Blossom, L71) is reached about a day sooner than
  the day-25 target across all three seeds.
- Seed 42 additionally overshoots to L74 by day 23 (content finishes but the level clock
  keeps climbing past 71 within the 30-day sim window) — expected, since L71 is the
  content ceiling, not a level cap.

This is a measurement, not a further tuning pass — no dial was adjusted to force an
on-target result. If the owner wants the book to land closer to day 25, the next input is
either raising SCENE_END_LEVEL further (esp. scene 5, currently 71) or leaving scene 1's
anchor pacing alone and accepting a ~1-day-short arc as within seed-to-seed noise (the
3-seed spread on "whole book" is already 23-24, i.e. ~4%).

## Concerns / notes carried over unchanged

- Water self-sustain WARN (38-41% >= 30% threshold) and the two early-map I2 WARNs are
  pre-existing parked findings from the prior task's re-spine, not newly introduced by
  this level re-tune — the sim still reports `== sim PASS ==` on all three seeds because
  these are WARN-severity, not gating.
- `P2` note (early coin pile past first completion) also persists across all seeds,
  unrelated to this change.
