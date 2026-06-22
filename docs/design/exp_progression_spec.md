# EXP progression — collapse stars into a single experience total

Status: design approved 2026-06-22. Drives an implementation plan.

## Goal

Remove **stars as a separate spendable currency**. There is now **one progression
number, `exp`**, that only ever increases. All world unlocks gate on *reaching* an exp
total (never on spending). **Level** is demoted to a cosmetic role: a badge identity and
a per-level reward — it gates nothing. Coins, gems/diamonds, and water are untouched.

## Current system (what we are replacing)

- Two star concepts coexist:
  - *Spendable* balance `currencies.stars` — spent to restore map spots
    (`save.gd: stars()/add_stars()/spend_stars()`, `map.gd` spot tap).
  - *Cumulative* `grove.stars_earned` — never depletes, drives **Level**
    (`content.gd: level_for_stars()`, table `grove_data.gd: LEVEL_STARS` + flat tail).
- **Level** gates board cells (`grove_data.gd: MIN_LEVEL` 9×7 table, read by
  `content.gd: cell_min_level()`) and generator appearance
  (`content.gd: generators_for_map()` via `appear_level`).
- **Maps** unlock sequentially: each map's spots are *purchased* with spendable stars;
  buying the last spot of a map appends to `gates` and unlocks the next
  (`content.gd: map_unlocked()/map_complete()`, `map.gd` completion path). Per-spot star
  costs come from `vine_maps.gd` (default ladder `[3,3,3,4,4,4,5,5…]`).
- Quests reward stars (`content.gd: quest_reward()` → `min(level, 3)` + coins for excess);
  delivery calls `content.gd: earn_stars()` (`board.gd`).
- Fence metering sizes toward the next spot cost against the spendable balance
  (`board.gd` → `Quests.meter_target(..., Save.stars(), ...)`,
  `content.gd: map_cheapest_spot()`).

## New model

### 1. One currency: `exp`

- The single progression total is `grove.exp` (replaces `grove.stars_earned`).
- **Delete** the spendable balance entirely: remove `currencies.stars` and
  `save.gd: stars()/add_stars()/spend_stars()`.
- Quest delivery calls `earn_exp(n)` (renamed `earn_stars`); it adds to `grove.exp` only
  (there is no second balance to bump). It returns the number of levels gained, as before,
  so the level-up dialog still fires.
- Quest reward keeps its current numbers: `quest_reward()` returns an `exp` field
  (renamed from `stars`) using the same `min(level, 3)` + coins-for-excess logic.

### 2. Spot/map unlock — a single sequential unlock button

- Every spot, across every map, is placed in **one global order**: map order `z = 0..N`,
  then spot order within each map (the order `vine_maps.gd` already produces).
- Each spot has a cumulative exp threshold `unlock_exp`:
  - `threshold[first spot overall] = 0` (immediately claimable on a fresh save).
  - `threshold[i] = threshold[i-1] + inc(z)` where `z` is the map of spot `i`.
- **Escalate per map:** `inc(z) = UNLOCK_BASE + z * UNLOCK_STEP`, defaults
  `UNLOCK_BASE = 3`, `UNLOCK_STEP = 3` → Farmhouse +3/spot, Barn +6, Pond +9, Orchard +12,
  Meadow +15. Constants live in `grove_data.gd`, fully tunable. (These replace the old
  per-region cost ladder in `vine_maps.gd`; that cost ladder is removed.)
- **UI:** the map screen drops per-spot unlock tapping. Instead it shows **one unlock
  button at the bottom** that targets the **next unclaimed spot in order**:
  - Label shows that spot's exp requirement (e.g. "Unlock — 45 exp").
  - **Greyed/disabled while `exp < unlock_exp`**; enabled once `exp ≥ unlock_exp`.
  - Tapping restores that one spot (sets `unlocks[spot_id] = true`, grants the spot's
    existing reward). **`exp` does not change.**
  - When the frontier map has no unclaimed spots, the button advances to the next map's
    first spot (which is the next entry in the global order).
- Spots still render locked/unlocked on the map for feedback; they are no longer
  individually tappable to unlock.
- A map is **visitable** when `exp ≥` its first spot's threshold (replaces the
  previous-map-complete gate; ordering is enforced by the threshold ladder itself).
- `map_complete(z)` still means *all of map z's spots claimed*; it keeps appending to
  `gates` and granting the `MAP_DIAMONDS` completion reward + Vault skim.
- Metering: `map_cheapest_spot()` → `next_unclaimed_spot()` (the lowest-threshold
  unclaimed spot, i.e. the one the button targets); fences meter `exp` toward its
  `unlock_exp` (`board.gd` passes `Save … exp` instead of `Save.stars()`).

### 3. Level — cosmetic only

- `level_for_exp(exp)` / `exp_at_level(level)` (renamed from the `…_stars` forms) still
  exist, fed by `LEVEL_EXP` (renamed `LEVEL_STARS`) + the flat tail. They compute the
  badge level and the progress-bar bound — nothing else.
- Level grants **rewards on level-up**: the existing gift (water + gems per level crossed,
  `LEVEL_WATER_GIFT` / `LEVEL_DIAMONDS`, granted on the dialog's Collect). Unchanged.
- Level drives the **badge visual** using the level-badge art that already exists. No new
  art and no new badge work in this task.
- Level **gates nothing.** The two formerly level-based gates convert to direct exp
  thresholds:
  - Board cells: `MIN_LEVEL` table → `MIN_EXP` table; `cell_min_level()` →
    `cell_min_exp()`; the open test becomes `exp ≥ cell_min_exp(cell)`. Default `MIN_EXP`
    values are the current `MIN_LEVEL` values mapped through `exp_at_level()` so pacing is
    preserved; tunable afterward.
  - Generators: `appear_level` → `appear_exp`; `generators_for_map()` excludes generators
    whose `appear_exp > exp`. Defaults derived the same way.

### 4. Exp display — always the cumulative total

- Wherever exp shows, it is the **lifetime cumulative total** number (`grove.exp`).
- A progress bar sits under it; its **upper bound = `exp_at_level(level + 1)`**. On
  level-up the bound extends to the new next-level threshold — the total number keeps
  climbing, only the bar's target moves.
- HUD: remove the spendable-stars counter; show **exp total + level badge** (+ progress
  bar). The bottom unlock button separately shows the next-spot exp requirement.

### 5. Save — no migration, delete and recreate

- No migration code for this change. Bump `SCHEMA_VERSION` (2 → 3); on load, a save whose
  `schema_version` differs from current is **discarded and recreated from `_default()`**
  (delete-and-recreate) rather than merged.
- New schema: `grove.exp` (int, default 0); **no** `currencies.stars`, **no**
  `grove.stars_earned`.
- The schema bump wipes all prior saves, which makes the existing grove migration helpers
  unreachable dead code. Remove `_migrate_exp_to_stars`, `_migrate_spot_ids`,
  `_migrate_map_keys`, and the legacy `progress.cfg` path (`_migrate_legacy`,
  `migrated_v2`) as part of the rebuild.

### 6. Naming sweep (stars → exp)

Rename the cumulative-progression vocabulary across `engine/` and `games/grove/`:

| Old | New |
| --- | --- |
| `earn_stars` | `earn_exp` |
| `level_for_stars` | `level_for_exp` |
| `stars_at_level` | `exp_at_level` |
| `LEVEL_STARS` | `LEVEL_EXP` |
| `grove.stars_earned` | `grove.exp` |
| `cell_min_level` / `MIN_LEVEL` | `cell_min_exp` / `MIN_EXP` |
| generator `appear_level` | `appear_exp` |
| quest reward `stars` field | `exp` |
| `map_cheapest_spot` | `next_unclaimed_spot` |

Delete: `save.gd: stars()/add_stars()/spend_stars()`, the spendable-stars HUD,
`vine_maps.gd` cost ladder, per-spot unlock buttons.

## Affected files (map)

- `engine/scripts/core/save.gd` — delete spendable-stars accessors; schema bump +
  delete-and-recreate on mismatch; remove migration helpers; `grove.exp` default.
- `engine/scripts/core/content.gd` — `earn_exp`, `level_for_exp`, `exp_at_level`,
  `quest_reward` exp field, `cell_min_exp`, `generators_for_map` (appear_exp),
  `map_unlocked` (exp-based visitable), `next_unclaimed_spot`, spot `unlock_exp` computation
  (escalate-per-map ladder).
- `games/grove/grove_data.gd` — `LEVEL_EXP`, `MIN_EXP`, `UNLOCK_BASE`/`UNLOCK_STEP`,
  generator `appear_exp`; remove `MIN_LEVEL`/`LEVEL_STARS`.
- `games/grove/vine/vine_maps.gd` — remove cost ladder; spots carry order only (threshold
  computed centrally).
- `engine/scripts/scenes/map.gd` — single bottom unlock button (greyed/enabled, next-spot
  requirement); remove per-spot spend tap; claim → restore + reward; map-complete path
  unchanged except exp-based.
- `engine/scripts/scenes/board.gd` — `earn_exp` call; HUD exp total + progress bar (bound =
  `exp_at_level(level+1)`); remove stars counter; metering against `exp`.
- `engine/scripts/ui/piece_view.gd` — locked board-cell badge keyed on `cell_min_exp` /
  exp gate.

## Testing

- `games/grove/tests/grove_economy_tests.gd`:
  - Level math under the rename (`level_for_exp`, `exp_at_level`, `earn_exp`, deferred gift).
  - Replace the spend test with: a spot is **not claimable below its threshold** and
    **claimable at/above it without changing `exp`**.
  - Threshold ladder is **strictly increasing** and **escalates per map**
    (`inc(z+1) > inc(z)`); first spot threshold is 0.
  - `next_unclaimed_spot` returns the lowest-threshold unclaimed spot; map completion still
    appends `gates` and grants `MAP_DIAMONDS`.
  - Board-cell and generator exp gates open at/above their `MIN_EXP` / `appear_exp`.
- `engine/tests/save_tests.gd`:
  - Drop spendable-stars tests.
  - Fresh save has `grove.exp == 0`, no `currencies.stars`.
  - A save with an older `schema_version` is wiped and recreated (delete-and-recreate),
    not merged.
- Run `make test-grove` while iterating; `make test` before handoff.

## Tunable constants (defaults)

- `UNLOCK_BASE = 3`, `UNLOCK_STEP = 3` (per-map unlock increment).
- `LEVEL_EXP` table + flat tail: unchanged numbers (renamed from `LEVEL_STARS`).
- `MIN_EXP`, generator `appear_exp`: derived from current level values via `exp_at_level()`.
