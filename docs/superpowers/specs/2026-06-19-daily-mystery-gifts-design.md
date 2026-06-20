# Mystery daily gifts + day fast-forward — design

Date: 2026-06-19
Branch / worktree: `daily-mystery` (`/Users/xup/dh/daily-mystery`)

## Problem

The daily-login calendar (`engine/scripts/core/login.gd`, `engine/scripts/ui/login.gd`)
pays a deterministic, repeating 7-day ladder. We want **slots 4 and 7 of every weekly
cycle** to become **mystery gift** days: a new dialog reveals several distinct rewards and
an auto-spin lands on the winner(s). We also need a **debug fast-forward** so a tester can
walk the whole ladder in one sitting.

## Current behavior (context)

- "Today's day" is `streak() + 1` — streak counts consecutive **claimed** days
  (`login.gd:40`, `today_day()`). Forgiving: a missed day soft-decays the streak by 1, never
  to 0 (resolved in `Save.daily()`).
- A new day is the real-world unix day. The calendar auto-pops once per launch if today is
  unclaimed and the player is past the FTUE (`scenes/map.gd`).
- `reward_for(day)` (`login.gd:47`): an absolute-day **milestone** (`LOGIN_MILESTONES`, keys
  7 and 30) overrides; otherwise the weekly slot `LOGIN_LADDER[(day-1) % 7]`.
- After day 7 the week ladder repeats forever; milestones (7, 30) fire once each.

## Decisions (locked)

1. **Auto-spin reveal** — the player watches the spin; they do not pick. (3 shown → lands on
   1 for day 4; 5 shown → lands on 2 for day 7.)
2. **Distinct pre-rolled rewards** — the shown cards are distinct rewards drawn from a pool;
   the winner(s) are chosen when the dialog opens. The spin is presentation.
3. **Every weekly cycle** — slots 4 and 7 are mystery, so days 4, 7, 11, 14, 18, 21, … are
   mystery picks.

## Design

### 1. Data — `games/grove/grove_data.gd` (owner-tunable)

Add `LOGIN_MYSTERY`, keyed by **weekly slot** (1-based, `((day-1) % 7) + 1`):

```gdscript
const LOGIN_MYSTERY := {
    4: {"show": 3, "win": 1, "pool": [
        {"coins": 120},
        {"water": 12},
        {"coins": 60, "water": 6},
        {"gems": 1},
        {"coins": 150},
    ]},
    7: {"show": 5, "win": 2, "pool": [
        {"coins": 200},
        {"gems": 2},
        {"coins": 100, "gems": 1},
        {"water": 14},
        {"coins": 300},
        {"gems": 3},
    ]},
}
```

- `show` = number of distinct cards revealed; `win` = how many the spin lands on.
- Day-7 pool is milestone-tier (richer). All `water` entries stay ≤ `LOGIN_WATER_SAFE_MAX`
  (15) so the §4/§10 faucet guard still holds.
- Remove `LOGIN_MILESTONES[7]` — slot 7 is now the mystery. Keep `LOGIN_MILESTONES[30]`.
  (Day 30 = slot 2, so no conflict with the mystery slots.)

### 2. Engine — `engine/scripts/core/login.gd` (pure, no UI)

- `slot_of(day) -> int` — `((day - 1) % 7) + 1`.
- `is_mystery(day) -> bool` — `LOGIN_MYSTERY.has(slot_of(day))`.
- `roll_mystery(day) -> Dictionary` — returns
  `{"show": N, "win": K, "options": [reward…], "winners": [idx…]}`:
  - Draw `show` **distinct** rewards from the slot's pool (without replacement; if the pool
    is smaller than `show`, cap to pool size).
  - Pick `win` winner indices uniformly without replacement from `[0, show)`.
  - Grants nothing — pure roll. Uses Godot RNG (`randi()` family).
- `won_rewards(roll) -> Array` — maps `roll.winners` → the reward dicts (small helper).
- `claim_mystery(won: Array) -> bool` — the single grant path: if already claimed return
  false; pay each reward dict via the existing `_grant`; set `claimed = true`; bump streak;
  persist. Returns true.
- `claim_today()` — for a mystery day, route through `claim_mystery(won_rewards(roll_mystery(today_day())))`
  so headless callers and tests still walk the ladder; otherwise unchanged.

`reward_for`, `today_reward`, `day_value`, milestone helpers stay; mystery is a parallel path.

### 3. UI — new dialog `engine/scripts/ui/login_mystery.gd`

- `open(host, day, on_done)` — z=100 overlay + veil, same frame as `ui/login.gd`.
- Calls `Login.roll_mystery(day)`; lays out `show` cards in one row using the existing
  `ui_workbench_kit.gd` card builder so it inherits parchment styling.
- Animation: a highlight cursor sweeps across the cards, decelerating, and **stops on a
  winner** — repeated `win` times (day 7 lands on 2 sequentially). Winner cards flip to
  their reward icon + a small celebrate; non-winners stay dimmed ("what you could've won").
- On finish: `Login.claim_mystery(Login.won_rewards(roll))`, close overlay, call `on_done`
  (the calendar rebuilds).

Calendar wiring (`engine/scripts/ui/login.gd`): when `Login.is_mystery(today_day())`, the
Claim/Collect button opens `login_mystery` instead of calling `claim_today` directly. After
the mystery dialog finishes, the calendar rebuilds in place (existing rebuild closure).

Calendar grid (`ui_workbench_kit.gd`): mystery slots render a **"?" gift icon** instead of a
concrete reward icon so they read as surprises (extend `_daily_reward`/card builder).

### 4. Debug fast-forward

- `Login.debug_advance_day() -> void` — claims today if unclaimed (bumps streak via the
  normal/mystery claim path), then reopens the claim for a fresh next day (set
  `claimed = false`, keep streak) and persists. Lets a tester immediately claim the next
  rung and walk the whole ladder, hitting mystery days repeatedly.
- A small **"⏭ Next day"** button at the bottom of the calendar dialog, shown only when
  `OS.is_debug_build() and Features.on("daily_debug")`. New flag `daily_debug` in
  `engine/scripts/core/features.gd` defaults `true` (never ships because of the
  `is_debug_build()` guard).

### 5. Tests — `engine/tests/save_tests.gd`, `engine/tests/login_tests.gd`

- `roll_mystery` returns exactly `win` distinct winner indices within `[0, show)`, `show`
  distinct options, and all rewards come from the slot's pool.
- `claim_mystery(won)` grants exactly the won rewards (coins/water/gems deltas), sets
  `claimed`, bumps streak by 1, and refuses a second claim the same day.
- `claim_today()` on a mystery day grants something and advances the streak (headless path).
- `debug_advance_day()` leaves today claimable again with the streak advanced.
- Repoint the existing day-7-milestone assertions in `save_tests.gd` T44 to the **day-30**
  milestone (day 7 is now a mystery, not a fixed milestone). Keep the escalation and
  water-guard assertions.

## Out of scope

- No change to the auto-popup gating, streak/decay math, or the real-clock day boundary.
- No new currency types; mystery pools use existing coins/water/gems.
- No persistence of "what you could've won" history.

## Verification

- `make test-fast` then `make test` (full sweep) headless, green.
- A screenshot of the mystery dialog (real renderer, via the project's quiet/minimized-window
  approach) to confirm the spinning reveal reads correctly — not eyeballed from a thumbnail;
  delivered as a file for human review.
