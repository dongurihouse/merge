# Task 1 report: derive the cluster level floors from the cost ladder

## Status: DONE

## Commit
`899e333d` — feat(pacing): derive the cluster level floors from the cost ladder

## Files changed

### `games/grove/grove_data.gd` (lines ~163-166, in the `§8` comment block)
Replaced the `CLUSTER_LEVEL_STEP := 1.34` dial (hand-spaced level floor: `2 + round(global_index × step)`)
with `CLUSTER_LEVEL_LEAD := 1.0`, a bias-only dial on the new derivation. Comment rewritten to explain
the new dial's meaning (< 1.0 = padlock leads affordability, > 1.0 = lags, 1.0 = never binding).
Used the brief's code verbatim.

Note: an older comment block at line ~148 (several lines above the edited block) still mentions
`CLUSTER_LEVEL_STEP below` in a historical/context sentence about the two dials moving together. This
is prose in an unrelated, non-edited comment block (not code, not part of the brief's specified edit
range), so I left it untouched per "use its code verbatim; do not improvise."  It's slightly stale but
harmless — flagging it here rather than freelancing a fix outside the brief's scope.

### `engine/scripts/core/content.gd`
- Line 33: replaced the const alias `CLUSTER_LEVEL_STEP = D.CLUSTER_LEVEL_STEP` with
  `CLUSTER_LEVEL_LEAD = D.CLUSTER_LEVEL_LEAD`.
- Lines ~1063-1068: replaced the old `cluster_min_level` (four comment lines + one-line formula body)
  with the full derived pacing spine block from the brief:
  - `static var _cadence`, `_cadence_key` (cache keyed on `LEVEL_BASE_COINS/LEVEL_STEP_COINS/n/total`)
  - `_cadence_table()` — rebuilds cache on dial drift
  - `_build_cadence()` — walks `coverup_pages()` × `clusters(z)` in global order, accumulates cost,
    computes `floors` (per global cluster index) and `scene_end` (per cover-up page) via `level_at_coins`
  - `cumulative_cluster_cost(i: int) -> int` — clamped cumulative cost through global index `i`
  - `scene_level_window(p: int) -> Vector2i` — level window `(first, last)` for the `p`-th scene
  - `cluster_min_level(z, cluster_id) -> int` — now reads the cached `floors` array (same signature,
    derived body)

Used the brief's code verbatim, no deviation.

### `engine/tests/scene_cells_tests.gd`
Added `_test_derived_cluster_floors()` immediately above `_initialize()`, and registered it inside
`_initialize()` (between `_test_any_cluster_ready()` and the summary print), exactly as specified in
the brief's Step 1. Verbatim from the brief.

## Test commands run (all in the foreground)

**Step 2 — verify the test fails before the implementation exists:**
```
cd /Users/xup/dh/wt-content-derived-curve && godot --headless --path . -s res://engine/tests/scene_cells_tests.gd
```
Result: parse errors, as expected —
```
SCRIPT ERROR: Parse Error: Static function "cumulative_cluster_cost()" not found in base "res://engine/scripts/core/content.gd".
SCRIPT ERROR: Parse Error: Static function "scene_level_window()" not found in base "res://engine/scripts/core/content.gd".
ERROR: Failed to load script "res://engine/tests/scene_cells_tests.gd" with error "Parse error".
```

**Step 6 — verify the test passes after the implementation:**
```
cd /Users/xup/dh/wt-content-derived-curve && godot --headless --path . -s res://engine/tests/scene_cells_tests.gd
```
Result:
```
== 25 passed, 0 failed ==
```
All 25 assertions passed, including the exact-value checks (`cumulative_cluster_cost(0)==10`,
`cumulative_cluster_cost(5)==420`, `cumulative_cluster_cost(24)==46740`, the full 25-element floor
ladder `[1, 2, 3, 4, 5, 7, 9, 11, 14, 16, 19, 22, 25, 29, 33, 37, 41, 46, 51, 56, 61, 67, 73, 80, 87]`,
and the 5 scene-level-window checks).

**Step 7 — full fast sweep:**
```
cd /Users/xup/dh/wt-content-derived-curve && make test-fast
```
Result:
```
25 suites · 1045 passed · 0 failed
ALL SUITES PASSED
```
`mechanics_tests` (315 passed) and `quest_fence_tests` (79 passed) both passed cleanly with no
failures — no `ZONE_UNLOCK_LEVEL`-named fallout to note for Task 2, and nothing named a cluster floor
failure needing a Task-1 fix.

## Deviations from the brief
None. All code (test, grove_data.gd dial, content.gd alias + derivation) was used verbatim as given
in the brief.

## Concerns / things I'm unsure about
- The stale `CLUSTER_LEVEL_STEP` mention left in the comment prose at `games/grove/grove_data.gd:148`
  (outside the edited block) is now slightly inaccurate since the dial was renamed/repurposed. It's
  cosmetic (a comment, not code) and outside the brief's specified line range, so I left it for the
  brief's author/Task 2 to decide whether it's worth a follow-up touch.
- Everything else matches the brief's expectations exactly; no other concerns.
