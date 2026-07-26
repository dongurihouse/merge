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
