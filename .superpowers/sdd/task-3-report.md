# Task 3 report — guard the derivation against dial drift

**RECONSTRUCTION NOTE (added during the final whole-branch review pass):** the original version of
this file was lost. It was written to this path after `.superpowers/` had already been gitignored
(commit `e22bbe65`), so it was never committed; a later `git revert --no-commit e22bbe65` (done to
restore the accidentally-untracked `.superpowers/sdd/progress.md` ledger) overwrote this working-tree
file with the stale pre-`e22bbe65` blob (a leftover FTUE hand-hint report from an earlier feature — see
the diff above this note in `git log`). What follows is rebuilt from the task brief
(`task-3-brief.md`), the actual commit (`c31646db`), and independent re-verification — not the
original prose, which could not be recovered.

Commit: `c31646db` (branch `content-derived-curve`, worktree `/Users/xup/dh/wt-content-derived-curve`)

## What this task did

Task 3's job was to prove the Task 1/2 derivation is a real guard, not just correct-by-luck at the
shipped dials: moving the coin curve (`LEVEL_BASE_COINS`/`LEVEL_STEP_COINS`) must provably move both
derived tables (the cluster floor ladder and the zone cadence) together, with scene alignment intact,
and restoring the dials must restore the tables.

### `engine/tests/tuning_tests.gd`

Added a block (per the brief, used verbatim) immediately before the existing "restore the live dials"
section:
- Asserts the shipped cadence is exactly `[1, 5, 8, 12, 16, 20, 26, 32, 38, 50, 62, 75]`.
- Halves `LEVEL_BASE_COINS`/`LEVEL_STEP_COINS` (30/12 → 15/6) and re-reads `zone_unlock_levels()`:
  asserts the cadence actually changed (proves the cache is keyed on the dials, not stale), still has
  one entry per zone, and is still strictly increasing.
- Asserts Fairy Hollow's last cluster floor (`cluster_min_level(0, "lantern_gate")`) moves to a HIGHER
  level under the cheaper curve than the shipped one.
- Re-checks scene alignment (every zone still lands inside its own scene's `scene_level_window`) under
  the moved curve.
- Re-checks every cluster floor still equals `level_at_coins(cumulative_cluster_cost(i))` under the
  moved curve.
- After the existing dial-restore block, adds one more assertion: `zone_unlock_levels()` is back to the
  shipped table once the dials are restored.

No production code changed — this task is test-only, per the brief's file list
(`engine/tests/tuning_tests.gd:28-85`).

## Deviations from the brief

None found during reconstruction — the added block matches the brief's code verbatim (confirmed
against `task-3-brief.md` and the `c31646db` diff).

## Verification (re-run during this review pass, since the original run's output could not be recovered)

```
cd /Users/xup/dh/wt-content-derived-curve && godot --headless --path . -s res://engine/tests/tuning_tests.gd
```
Result: **28 passed, 0 failed**, including:
- `PASS  at the shipped curve the cadence is [1, 5, 8, 12, 16, 20, 26, 32, 38, 50, 62, 75]`
- `PASS  halving the curve moves the zone cadence (no stale cache)`
- `PASS  the moved cadence still has one level per zone`
- `PASS  the moved cadence is still strictly increasing`
- `PASS  every cluster floor still equals level_at_coins(cumulative cost) at the moved curve`
- `PASS  the derived cadence is back to the shipped table after the suite restores the dials`

The brief's Step 2 also calls for confirming the guard actually bites (temporarily key
`_cadence_table()`'s cache on a constant, re-run, observe failure, then revert) — this could not be
independently re-verified during reconstruction without touching shipped code, so it is reported as
NOT re-confirmed here; the shipped `_cadence_table()` key (`"%d/%d/%d/%d" % [LEVEL_BASE_COINS,
LEVEL_STEP_COINS, n, total]`, `content.gd:1087`) does include both coin dials, which is consistent with
the guard being real.

## Things I'm unsure about

- The original report's exact wording and any MINOR/deviation notes it may have carried are lost. If
  the implementer noted anything beyond "no deviations," that detail did not survive.
