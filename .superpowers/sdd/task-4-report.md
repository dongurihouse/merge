# Task 4 report — re-spine grove_sim's pacing report onto the scenes

**RECONSTRUCTION NOTE (added during the final whole-branch review pass):** the original version of
this file was lost. It was written to this path after `.superpowers/` had already been gitignored
(commit `e22bbe65`), so it was never committed; a later `git revert --no-commit e22bbe65` (done to
restore the accidentally-untracked `.superpowers/sdd/progress.md` ledger) overwrote this working-tree
file with a stale pre-`e22bbe65` blob (a leftover Meadow-UI-integration report from an earlier
feature). What follows is rebuilt from the task brief (`task-4-brief.md`), the actual commit
(`778167e7`, whose message already carries the key measured numbers), and a fresh independent
re-measurement — not the original report's exact prose, which could not be recovered. Fragments of the
original text were visible in this session's terminal scrollback before the overwrite (a per-seed
table and a "content-zone day moved ... roughly 4.2×" sentence); those fragments are consistent with
the fresh numbers below and are folded in where they add detail the commit message doesn't.

Commit: `778167e7` (branch `content-derived-curve`, worktree `/Users/xup/dh/wt-content-derived-curve`)

## What this task did

With the cluster floors and zone cadence now derived per scene (Tasks 1-2), the sim's old
level-by-level pacing report no longer showed the signal that matters: whether the content arc (last
item line seen) and the restoration arc (book fully unlocked) land close together, or drift apart.

### `games/grove/tools/grove_sim.gd`

- Added `var scene_done_day := {}` (cover-up page index → day its last cluster unlocked), tracked in
  `_play_session()`'s page-completion block right after `gates_reached += 1`.
- Replaced the two remaining reads of the deleted `G.ZONE_UNLOCK_LEVEL` constant with
  `G.zone_unlock_level(G.ZONE_COUNT - 1)` (the `content_end_day` trigger and the results-line print).
- Added a new `SCENES` table to the results output: one row per cover-up scene, printing its level
  window (`G.scene_level_window(p)`), the zones that unlock inside it (`G.zone_unlock_level(zi)` per
  zone in `G.ZONE_BAND[p]`), and the day it completed (`scene_done_day` or `NOT COMPLETED`).
- Fixed two stale comments: the pacing-milestone header (previously said the content arc and
  restoration ladder were paced by "DIFFERENT things"; now says they ride the same derived spine) and
  the cluster-ladder comment at the old line 670 (previously said `cluster_min_level = 2 + its global
  index`; now says the floor is derived from the ladder's cumulative cost).

No other files changed — this task is a `grove_sim.gd`-only reporting change, per the brief.

## Deviations from the brief

None found during reconstruction — the diff matches the brief's code verbatim (confirmed against
`task-4-brief.md` and the `778167e7` diff).

## Measured (re-run during this review pass; the original run's own per-seed table could not be recovered byte-for-byte, but these numbers are freshly independently measured, not copied)

3 seeds × 300 days (the acceptance signal needs the long tail — a 60-day window never reaches either
milestone post-fix):

| seed | last content zone (L75) day | whole book day | jams | sim result |
|---|---|---|---|---|
| 1  | 155 | 268 | 0 | PASS |
| 7  | 151 | 259 | 0 | PASS |
| 42 | 154 | 258 | 0 | PASS |

At 60 days (one seed, sanity-checked): `clusters unlocked: 17/25`, `page 4/5`, neither the content
zone nor the book reached — consistent with the commit message's "clusters at day 60 drop from 21/25
to 17/25" (pre- vs post-derivation) and confirms the extended-duration runs were necessary to see
convergence, exactly as the brief anticipated.

Per the `778167e7` commit message (authoritative, git-recorded, unaffected by the data loss): before
commit `7dbc3654` (the old hand-authored `ZONE_UNLOCK_LEVEL`/`CLUSTER_LEVEL_STEP` tables) the
last-content-zone day was ~32-37 and the whole-book day was ~120-127 — an absolute gap of ~83-95 days.
After this branch's derivation, the gap widens in absolute terms (~104-113 days, per the fresh
measurements above: 268-155=113, 259-151=108, 258-154=104) because the whole arc roughly doubled in
length, but as a FRACTION of total playtime the content reveal moves from ~26-31% through the arc to
~58-60% through it — the "restoring with nothing new to see" tail shrinks from ~70-75% of playtime to
~40-42%.

Zero jams and `PASS I1`/no-strand held on every seed at every duration tested (60d and 300d).

## make test

Re-run during this review pass: 33 suites, 2015 passed, 0 failed (see the parent task's own test run
for the authoritative record — this reconstruction re-ran the four suites plus the full sweep
independently and got the same result).

## Things I'm unsure about

- The original report's exact per-seed numbers at whatever intermediate durations (90d/150d/etc.) the
  implementer actually used are lost; the table above is a fresh 300-day measurement, not a copy of the
  original run.
- Whether the original report flagged anything beyond what's in the commit message (e.g. additional
  MINOR notes) could not be recovered.

## Final review fix pass

Final whole-branch review of `content-derived-curve` (base `7dbc3654`) found accuracy-only findings —
stale comments, two dial-hardcoding test assertions, an incomplete audit table, and one commit to
undo. No dial, formula, or `MIN_LEVEL` grid value changed anywhere in this pass.

### Important 1 — three "floors never bind" comments (WRONG, measured false)

`CLUSTER_LEVEL_LEAD=1.0` was documented as making the cluster floors non-binding "by construction."
Measured false: the floors are derived from cumulative cost counted in CLOCK coins only
(`Save.coins_earned_lifetime`, quest rewards), but the wallet that pays for a cluster also fills from
sells/chests/treats/habitat yield, and clock coins are only ~46% of the faucet (independently confirmed
via the recovered `docs/design/merge_spec.md:93` line and the branch's own 60-day sim measurement: a
player holding 6.6x a cluster's cost while still below its level floor). Fixed:
- `engine/scripts/core/content.gd:32` (`CLUSTER_LEVEL_LEAD` const doc)
- `engine/scripts/core/content.gd` `cluster_min_level`'s doc (was lines 1155-1156 pre-edit)
- `games/grove/grove_data.gd:157` (`CLUSTER_LEVEL_LEAD` const doc)

All three now say the floor derivation counts CLOCK coins only, the wallet also fills from non-clock
income, and in practice the FLOOR binds, not the price; `CLUSTER_LEVEL_LEAD` below 1.0 scales the
cumulative cost down before the `level_at_coins` lookup, moving floors earlier.

### Important 2 — comments describing the deleted level-space tables

Every number below was verified by writing a throwaway `SceneTree` probe script
(`res://verify_probe.gd`, deleted after use — not committed) that called the real `content.gd`
functions directly:
- `G.zone_unlock_levels()` → `[1, 5, 8, 12, 16, 20, 26, 32, 38, 50, 62, 75]` (matches the brief).
- `G.cluster_min_level` over all 25 clusters → floor ladder
  `[1,2,3,4,5,7,9,11,14,16,19,22,25,29,33,37,41,46,51,56,61,67,73,80,87]`, total cost 46,740.
- `G.scene_level_window(0..4)` → `(1,7) (8,19) (20,37) (38,61) (62,87)`; `scene_level_window(5)` clamps
  to `(62,87)`.
- `G.gen_retirable("gen_1"/"gen_6"/"gen_16", level)` swept over L1-200 → gen_1 last needed at L11
  (retires L12), gen_6 last needed at L37 (retires L38), gen_16 last needed at L74 (retires L75).
- Line→zone mapping from `grove_data.gd` (spices=line 8/zone7, corals=line 17/zone9, tea
  cups=line 19/zone11) against the cadence → spices L32, corals L50, tea cups L75.
- Lines 16/17/18/19 → zones 8/9/10/11 → L38/50/62/75, so "L38-75" for that range.
- `G.quest_zone_for_level` swept L1-99 → the zone boundary levels are exactly the cadence values, and
  `G.zone_map` bands (`ZONE_BAND=[2,3,3,2,2]`) put the `Quests.current_band` step points at L8/20/38/62.
- `G.QUEST_CLICKS_PER_COIN == [8,7,6,5,4]`, confirmed via the probe.
- `soft_hi` in `gen_quest` (`content.gd`, `QUEST_TIER_BASE=4`, `QUEST_LEVELS_PER_TIER=2`, `TOP_TIER=12`)
  saturates at L16 — arithmetic check (`4 + level/2 >= 12` at `level=16`), and L16 falls inside Snowy
  Village's L8-19 window.

Fixed, each cited against the numbers above:
`content.gd:32` (also fixed under Important 1), `content.gd` line-retirement rationale (spices/corals/
tea cups levels, gen_1/6/16 retirement levels), `content.gd`'s `arc_finish_threshold` comment (L75 vs
L87, not the stale L13/L26), `grove_data.gd`'s Fairy Hollow cluster comment (L1-7, not "2 +
global_cluster_index"), `grove_data.gd`'s `MIN_LEVEL` rationale (new scene windows, L22 corners open
near the START of Desert Oasis not the end of scene 4 — the `MIN_LEVEL` grid itself untouched),
`mechanics_tests.gd` (two comments: scene windows, and "the table ... re-spaced to L1-34" since there
is no table any more), `quests.gd:26-27` and `content.gd`'s `arc_finish_threshold` doc (both
"~L13 vs ~L26" claims → "~L75 vs ~L87," the "far shorter" premise nearly gone), `board.gd:760`
(dropped the dead `ZONE_UNLOCK_LEVEL` name), `quest_fence_tests.gd:233-236` (same rewrite as quests.gd,
framed as historical), `grove_explore_tests.gd` (three spots: the migration-test header no longer names
`ZONE_UNLOCK_LEVEL`; the L15 setup comment now says koi L62 and desert fruits L20 are BOTH future
relative to L15 — verified via the probe that `quest_zone_for_level(15) == 3` i.e. zone 3 = line 4
(woolens), not desert fruits, and `line_gated_out(6, 15) == true`; the koi-placement comment now says
"unlocks L62" instead of the stale "L23").

### Important 3 — plan's level-keyed-reads table incomplete

Added three rows to `docs/superpowers/plans/2026-07-25-content-derived-level-gates.md`'s
"level-keyed reads, enumerated" table, each verified against the code (not copied on faith):
- `Quests.current_band` → `zone_map(quest_zone_for_level(level))` → indexes
  `QUEST_CLICKS_PER_COIN`. Band boundaries move to L8/20/38/62 (verified via the probe's
  `quest_zone_for_level` sweep + `ZONE_BAND`/`zone_map` arithmetic). Verdict: a SECOND, independent
  driver of the measured slowdown — it feeds back into the clock the gates derive from, and
  `CLUSTER_LEVEL_LEAD` doesn't touch it.
- `SELL_MAP_BAND` reached through line availability: lines 16-19 now arrive L38-75 (verified above).
- `gen_quest`'s tier bell (`content.gd:676`, `soft_hi`) saturates at L16, which now falls inside Snowy
  Village rather than mid-Desert Oasis (verified above).

Noted but NOT changed (out of the explicit ask): the same table's existing `cluster_ready` row still
says "level floor now non-binding at CLUSTER_LEVEL_LEAD = 1.0, intentional — this is the design," which
is the same false claim fixed in Important 1. Flagging it here since only the three listed rows were
in scope for this pass.

### Important 4 — two dial-hardcoding assertions

`engine/tests/scene_cells_tests.gd` (the `_test_derived_cluster_floors` case) and
`engine/tests/tuning_tests.gd` (the moved-curve floor-tracking assertion) both asserted
`cluster_min_level(i) == level_at_coins(cumulative_cluster_cost(i))`, ignoring `CLUSTER_LEVEL_LEAD`
entirely (the real formula, `content.gd:1100`, is
`level_at_coins(round(cum * CLUSTER_LEVEL_LEAD))`). Rewritten in both files to read the dial via each
file's own alias (`Content` in `scene_cells_tests.gd`, `G` in `tuning_tests.gd`). Currently
`CLUSTER_LEVEL_LEAD == 1.0` so behavior is unchanged today; the fix only matters once the owner moves
the dial. The PINNED shipped-table assertions (literal floor ladder, literal cadence, literal scene
windows) were left untouched, per the reviewer's instruction — those should fail loudly on a re-tune.

### Important 5 — undo commit `e22bbe65`

Confirmed the duplicate: `.gitignore` had `.superpowers/` at line 49 already; `e22bbe65` added a
second, redundant `.superpowers/` line plus untracked 5 previously-tracked files (`progress.md`,
`task-2-report.md` through `task-4-report.md`, `json-feather-fix-report.md`). Ran
`git revert --no-commit e22bbe65`, then staged the CURRENT on-disk `.superpowers/sdd/progress.md` plus
this feature's four task reports (`task-1-report.md` through `task-4-report.md`); did not add any
`review-*.diff` or `task-*-brief.md` file. Confirmed afterward: `.gitignore` has exactly one
`.superpowers/` line, and `git ls-files .superpowers` lists `json-feather-fix-report.md`, `progress.md`,
and `task-1-report.md` through `task-4-report.md` (six files, nothing else).

**SELF-INFLICTED DATA LOSS during this step, disclosed in full:** `git revert --no-commit e22bbe65`
does not distinguish "recreate a tracked file" from "clobber an untracked file that happens to already
exist at that path" — it overwrote the WORKING-TREE copies of `progress.md`, `task-3-report.md`, and
`task-4-report.md` (this file) with their stale pre-`e22bbe65` git blobs, before I had captured their
then-current on-disk content. That current content held real, newer entries (Task 2-4 ledger lines;
the actual Task 3 and Task 4 reports) that had never been committed (written after `.superpowers/` was
already gitignored), so they are not recoverable from git history. What WAS recoverable:
- `task-1-report.md` and `task-2-report.md`: untouched / correct (task-2-report.md's last commit,
  `baa27450`, literally IS its final content — confirmed via `git log -- task-2-report.md`).
- `progress.md`'s Task 4 lines: recovered VERBATIM — I had grepped this exact file for unrelated reasons
  (checking the "151...258" day numbers cited in the finding brief) a few minutes before running the
  revert, and that grep output captured the two Task 4 lines in full.
- Everything else lost (`progress.md`'s Task 2/3 lines, all of `task-3-report.md`, all of
  `task-4-report.md` i.e. this file's body above this section) was RECONSTRUCTED from commit messages
  (`c2208065`, `c957edc9`, `c31646db`, `778167e7` — all have detailed, accurate messages), the task
  briefs, and fresh independent re-verification (re-running `tuning_tests.gd` and a fresh 3-seed
  300-day `grove_sim` sweep, which reproduced day 151/154/155 and 258/259/268 — matching the
  fragments I had captured). Each reconstructed file carries its own RECONSTRUCTION NOTE at the top.
  This is NOT a claim that the reconstructions are word-for-word identical to what was lost — only that
  they are factually accurate and clearly labeled as rebuilt.

Lesson recorded in `progress.md`'s final-review line: snapshot any untracked-but-wanted file before
running `git revert`/`git checkout` that could touch its path.

### Minor 6 — `scene_level_window` doc

Corrected: `y` is `level_at_coins` of the CLOCK's cumulative cost through the scene's last cluster —
the level the coin clock alone would reach, not necessarily when the player actually finishes paying
(non-clock income complicates that). Added the missing clamp note: out-of-range `p` (e.g. 5) returns
the final scene's window, `(62,87)` — verified via the probe.

### Minor 7 — `grove_sim.gd:88-91` dangling fragment

Repaired the sentence and replaced the refuted "can no longer drift apart" claim with the actual
measurement: last content zone day 151-155 vs. book completion day 258-268 (3-seed, 300-day sweep,
re-measured fresh in this pass: seed 1 → 155/268, seed 7 → 151/259, seed 42 → 154/258).

### Test results (all foreground, this pass)

```
godot --headless --path . -s res://engine/tests/scene_cells_tests.gd   → 25 passed, 0 failed
godot --headless --path . -s res://engine/tests/tuning_tests.gd        → 28 passed, 0 failed
godot --headless --path . -s res://engine/tests/mechanics_tests.gd     → 285 passed, 0 failed
godot --headless --path . -s res://games/grove/tests/grove_explore_tests.gd → 347 passed, 0 failed
make test                                                              → 33 suites · 2015 passed · 0 failed
```

Re-ran `make test` again after the `.superpowers/` revert + reconstruction: still 33 suites, 2015
passed, 0 failed — the revert only touched `.gitignore` and `.superpowers/sdd/*.md`, no `.gd` files.

### Commits

- `2be5b3cf` — `docs: correct stale pacing comments after the coin-clock derivation` (Importants 1/2/4,
  Important 3, Minors 6/7).
- `4c087f88` — `Revert "chore: ignore .superpowers/ orchestration scratch"` (Important 5, plus the
  reconstructed `.superpowers/sdd/*.md` files).
- This report's own append + the `docs(sdd)` commit that follows it (see `git log`).

### Unresolved / not attempted

- Nothing from the assigned findings list was left unfixed.
- The plan-table's `cluster_ready` row still contains the same false "non-binding" claim as Important 1
  (see Important 3 section above) — flagged, not fixed, since it wasn't one of the three named
  locations.
- The exact original prose of `progress.md`'s Task 2/3 ledger lines and the full original text of
  `task-3-report.md`/`task-4-report.md` could not be recovered — see the data-loss disclosure above.
