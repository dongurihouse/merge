# Task 2 report — derive the zone unlock cadence from the scene windows

Commit: `c2208065` (branch `content-derived-curve`, worktree `/Users/xup/dh/wt-content-derived-curve`)

## Files changed

### `engine/scripts/core/content.gd`
- Deleted `const ZONE_UNLOCK_LEVEL = D.ZONE_UNLOCK_LEVEL` alias (old line 31).
- `_build_cadence()`: added the `zones` fill — spreads each scene's `ZONE_BAND[i]` zones evenly across
  its own `scene_end`-derived window (`win_start`..`win_end`), pins zone 0 to L1 (the anchor), and forces
  strict monotonicity across the whole array. Brief's code used verbatim.
- `zone_unlock_level(z)`: rewritten to read `_cadence_table()["zones"]` (clamped index), replacing the old
  array-literal lookup. Brief's code used verbatim.
- Added `zone_unlock_levels() -> Array`: returns a duplicated copy of the full derived cadence. Brief's
  code used verbatim.
- Two internal call sites updated to call `zone_unlock_level(...)` instead of indexing the deleted const:
  `gen_retirable` (`needed_gens(zone_unlock_level(int(z)))`) and `quest_zone_for_level`
  (`int(level) >= zone_unlock_level(int(i))`).

### `games/grove/grove_data.gd`
- Deleted the hand-authored `§7 ZONE UNLOCK CADENCE` block (comment + `const ZONE_UNLOCK_LEVEL := [...]`
  + the "STRETCHED" note + the scene/generator-band ASCII table), lines 134-156 in the pre-edit file.
- Replaced with the brief's new `§7` comment block explaining the cadence is derived, not authored, and
  naming the dials that move it (coin curve, per-cluster `cost`, `ZONE_BAND`). This also resolves the
  extra requirement flagged by Task 1's review: the deleted block contained a stale instruction to
  "re-space BOTH together" (`ZONE_UNLOCK_LEVEL` and `CLUSTER_LEVEL_STEP`) — `CLUSTER_LEVEL_STEP` no longer
  exists, and that whole paragraph is now gone.

### `engine/tests/mechanics_tests.gd`
- Line ~654 (`_top_lv`): `int(G.ZONE_UNLOCK_LEVEL[G.ZONE_COUNT - 1])` → `G.zone_unlock_level(G.ZONE_COUNT - 1)`.
- Cadence assertions (old lines 688-699): replaced with the brief's block — `G.zone_unlock_levels()`,
  exact-array assertion against `[1, 5, 8, 12, 16, 20, 26, 32, 38, 50, 62, 75]`, monotonicity check, and
  the new scene-alignment loop over `G.ZONE_BAND` / `G.scene_level_window(p)`.
- Arc table (old lines 664-680): replaced the level-by-level `Dictionary` with the brief's per-zone range
  table (`_arc` array of `[start, end, lines]` rows) and the nested-loop check over `L1..L90`.
- Two per-zone cadence-read loops (old lines 708, 714): `int(G.ZONE_UNLOCK_LEVEL[_z])` /
  `int(G.ZONE_UNLOCK_LEVEL[_z2])` → `G.zone_unlock_level(int(_z))` / `G.zone_unlock_level(int(_z2))`.

### `engine/tests/quest_fence_tests.gd`
- Line 341: `int(G.ZONE_UNLOCK_LEVEL[1])` → `G.zone_unlock_level(1)`.

### `games/grove/tests/grove_board_actions_tests.gd`
- Retirement-boundary assertions (old lines 249-251): replaced hardcoded L11/L22/L33 boundaries with
  `G.zone_unlock_level(3)`, `G.zone_unlock_level(8)`, `G.zone_unlock_level(11)` per the brief — these now
  read L12, L38, L75 under the derived cadence (all three still pass: "before" is `_zN - 1`, "after" is
  `_zN`).
- Line 254 loop bound: `int(G.ZONE_UNLOCK_LEVEL[G.ZONE_COUNT - 1]) + 20` → `G.zone_unlock_level(G.ZONE_COUNT - 1) + 20`.
- Line 259 dormancy check: replaced the hardcoded L30 probe with `G.zone_unlock_level(10)` (= L62, Cherry
  Blossom's first zone) per the brief.
- Line 260 (`retirable_gens(...) == ["gen_1"]` at L30) left untouched per the brief's instruction to
  verify, not change unless it fails — it still passes under the derived cadence.

### `games/grove/tools/grove_sim.gd` — NOT in the brief's file list, fixed anyway
Two live reads of `G.ZONE_UNLOCK_LEVEL` survived the brief's list:
- Line 169: `if content_end_day < 0 and _level() >= int(G.ZONE_UNLOCK_LEVEL[G.ZONE_COUNT - 1]):`
- Line 186: `int(G.ZONE_UNLOCK_LEVEL[G.ZONE_COUNT - 1])` inside the pacing-report `print`.

Both changed to `G.zone_unlock_level(G.ZONE_COUNT - 1)`, per the parent instruction to fix any live read
the brief missed. This is a tool script (the sim pacing report), not exercised by `make test`, but it
would fail to compile the moment it's loaded/run since the const it read no longer exists anywhere
(neither in `content.gd` nor in `grove_data.gd`, since Step 6 deletes it there too). Left the one
remaining comment at grove_sim.gd:89 (`ZONE_UNLOCK_LEVEL` named descriptively) untouched — it is prose,
not a read, and Task 4 ("re-spine grove_sim pacing report onto scenes") is the task that owns a fuller
rewrite of this tool's reporting.

## Test commands run (all foreground)

```
cd /Users/xup/dh/wt-content-derived-curve && godot --headless --path . -s res://engine/tests/mechanics_tests.gd
```
`== 285 passed, 0 failed ==`

```
cd /Users/xup/dh/wt-content-derived-curve && godot --headless --path . -s res://engine/tests/quest_fence_tests.gd
```
`== 79 passed, 0 failed ==`

```
cd /Users/xup/dh/wt-content-derived-curve && godot --headless --path . -s res://games/grove/tests/grove_board_actions_tests.gd
```
`== 87 passed, 0 failed ==`

```
cd /Users/xup/dh/wt-content-derived-curve && make test
```
`33 suites · 2007 passed · 0 failed` — `ALL SUITES PASSED`. No level-boundary re-derivation was needed
beyond what the brief already specified; every affected suite passed on the first full-sweep run.

The exact derived cadence at the shipped curve came out to `[1, 5, 8, 12, 16, 20, 26, 32, 38, 50, 62, 75]`
— matching the brief's expected literal exactly, so the "got %s" diagnostic in the cadence assertion
never fired.

## Grep verification (both required by the parent task)

```
cd /Users/xup/dh/wt-content-derived-curve && grep -rn "CLUSTER_LEVEL_STEP" --include="*.gd" .
```
```
games/grove/grove_data.gd:150:# the scene ladder cannot drift off the coin curve. CLUSTER_LEVEL_STEP is retired with the hand-spacing.
```
One hit, a comment that accurately describes it as retired (this line is content.gd's Task-1-authored
`§8` comment, immediately after the block Step 6 deleted — not part of the deleted block itself).

```
cd /Users/xup/dh/wt-content-derived-curve && grep -rn "ZONE_UNLOCK_LEVEL" --include="*.gd" .
```
```
engine/scripts/scenes/board.gd:760:# Save migration (2026-07-23, scene-aligned ZONE_UNLOCK_LEVEL cadence): strip every generator, item and
engine/scripts/core/content.gd:325:# generator / line / item the player should NOT have yet under the ZONE_UNLOCK_LEVEL cadence. Non-zone lines
engine/scripts/core/content.gd:431:# opening new zones, the ask pool still advances. The level→zone map is the ZONE_UNLOCK_LEVEL cadence dial
engine/scripts/core/content.gd:1577:## ZONE_UNLOCK_LEVEL table in grove_data, which had drifted to L1-34 while the ladder ran to L87 — every item
games/grove/tools/grove_sim.gd:89:# ladder are paced by DIFFERENT things — the arc by LEVEL (ZONE_UNLOCK_LEVEL), the ladder by level AND
games/grove/tests/grove_explore_tests.gd:473:# line the player HAS reached, derived from ZONE_UNLOCK_LEVEL — the cadence is an owner dial and was
```
All six remaining hits are comments, none are live reads. Checked each individually:
- `board.gd:760` — comment describing the save-migration's history/rationale, doesn't read the symbol.
- `content.gd:325`, `content.gd:431` — pre-existing descriptive comments naming "the ZONE_UNLOCK_LEVEL
  cadence" informally; not touched, since they're prose and the brief didn't list them. They're now
  slightly stale in that they call it a "cadence dial" (it's derived, not authored) but they don't claim
  the symbol still exists. Flagged here as a minor found-in-passing item; did not fix since out of the
  brief's scope and not a live read.
- `content.gd:1577` — the new Step-4 doc comment itself, which deliberately narrates the retired table's
  name for context.
- `grove_sim.gd:89` — a section-comment naming the old dial; the two actual reads on lines 169/186 in the
  same file were fixed (see above).
- `grove_explore_tests.gd:473` — a test comment explaining why the save-migration test picks its
  "in-cadence" line dynamically (`for _bl in G.ZONE_BASE_LINES: ... G.line_gated_out(...)`) rather than
  hardcoding one; the test itself has no hardcoded cadence dependency, so nothing needed fixing.

## Deviations from the brief

1. **Fixed two live reads in `games/grove/tools/grove_sim.gd`** not listed in the brief's file list (see
   above) — required because deleting `ZONE_UNLOCK_LEVEL` from both `content.gd` and `grove_data.gd`
   leaves no symbol for `G.ZONE_UNLOCK_LEVEL` to resolve to. Fix mirrors the brief's own pattern
   (`G.zone_unlock_level(i)`).
2. No other deviations. All brief code blocks (Steps 3, 4, 5, 6, 1, 8, 9, 10) were used verbatim.

## Uncommitted state found before starting

`.superpowers/sdd/progress.md` already carried an uncommitted "Task 1: complete (commit 899e333d...)"
ledger entry from the prior session (not committed alongside 899e333d). I did not add my own Task 2 entry
to this ledger — the established convention in this file is that each entry's "review clean" status is
appended after a review pass, which is outside this task's scope — but `git add -A` in the Step 13 commit
picked up the pre-existing Task 1 note along with my code changes, so it is now committed as part of
`c2208065` rather than left dangling.

Also found: `.superpowers/sdd/task-2-report.md` (this file) already existed on disk before I wrote to it,
containing a stray report from an unrelated earlier feature ("the hand-hint overlay"). Overwritten with
this report; it was not tracked/committed content for this branch (confirmed via `git status` — this path
was not listed as modified before I wrote it), so nothing was lost from version control.

## Things I'm unsure about

- Whether `content.gd:325` and `content.gd:431`'s comments (calling the cadence "the ZONE_UNLOCK_LEVEL
  cadence" / "the ZONE_UNLOCK_LEVEL cadence dial") should be refreshed to stop naming a retired symbol.
  I left them alone since the brief didn't list them and the parent's constraint only required grep hits
  to be comments-not-reads, which they already satisfy — but a future pass could tidy the wording.
- Whether the ledger convention expects me (the implementer) to add a Task 2 note to progress.md at all,
  versus leaving that entirely to a separate review step. I erred toward not adding one myself.
