# Task 3 report: board triggers, completion hooks, and idle-hint coordination

Commit: `3d8399291c6b2c50d7f5c7ad4d172430dcb58766` on branch `ftue-hand-hint` (worktree
`/Users/xup/dh/wt-ftue-hand-hint`).

## What changed

Followed `task-3-brief.md` steps 1–11 in order, verbatim on the code content (only line-number
references drifted, since the file had grown since the brief was written).

1. **`engine/tests/ftue_hand_hint_tests.gd`** — appended the 7-assertion eligibility section
   before the final `print`/`quit`, exactly as specified in Step 1. Did not touch anything
   already in the file.
2. Ran the suite headless — confirmed it failed with `Parse Error: Static function
   "next_hint_id()" not found` (Step 2's expected failure).
3. **`engine/scripts/ui/hand_hint.gd`** — appended the `next_hint_id` pure static seam exactly
   as specified in Step 3.
4. Ran the suite again — all assertions passed (45 total: the 38 from Tasks 1–2 plus the 7 new
   eligibility ones; the brief's "34" estimate was off, per its own caveat that the count is a
   hand count).
5. **`engine/scripts/scenes/board.gd`**:
   - Added `const HandHint = preload(...)` alongside the other `ui/` preloads.
   - Added `_hand_hint: Control` and `_hand_hint_id: String` members next to `gen_nodes`.
   - Added `_maybe_hand_hint`, `_hand_hint_eligible`, `_hand_hint_gen_cell`, `_hand_hint_rects`,
     `_local_rect`, `_dismiss_hand_hint`, `_end_hand_hint` — all as specified in Step 6, inserted
     directly after `_hint_pair`.
   - Called `_maybe_hand_hint()` at the end of `_rebuild_all` (Step 7).
   - Added `_end_hand_hint("merge")` in `_after_merge`, immediately after `_mark_seen(produced)`
     (Step 7).
   - Added `_end_hand_hint("gen_tap")` in `_release_gen`'s still-tap `else:` branch, immediately
     after `_pop_seed(from)` (Step 7).
   - Replaced `_hint_pair`'s guard with the FTUE-aware suppression (Step 8): a live hand hint, or
     an unseen merge teach while the flag is on, both blank the idle re-nudge.
6. Parse-checked `board.gd` (Step 9) — `PARSE-OK`, no errors.
7. Ran `make test` (Step 10) — all 30 suites green, 1724 passed, 0 failed. No grove suite failed,
   so `games/grove/tests/grove_test_base.gd` was **not** touched (see "Deviations" below).
8. Committed (Step 11), staging only the three files this task touched (see "Deviations").

## Exact commands run and their output

```
$ godot --headless --path . -s res://engine/tests/ftue_hand_hint_tests.gd
...
SCRIPT ERROR: Parse Error: Static function "next_hint_id()" not found in base
"res://engine/scripts/ui/hand_hint.gd".
ERROR: Failed to load script "res://engine/tests/ftue_hand_hint_tests.gd" with error "Parse error".
```
(confirmed the RED step, before adding the seam)

```
$ godot --headless --path . -s res://engine/tests/ftue_hand_hint_tests.gd
...
== 45 passed, 0 failed ==
```
(after adding `next_hint_id` — all pre-existing 38 plus the 7 new eligibility assertions)

```
$ godot --headless --path . --check-only --script res://engine/scripts/scenes/board.gd && echo PARSE-OK
...
PARSE-OK
```

```
$ make test
...
  30 suites · 1724 passed · 0 failed
  ALL SUITES PASSED
```
(includes `engine/tests/ftue_hand_hint_tests` at 45 passed, and every grove suite that
instantiates the board scene — `grove_board_actions_tests`, `grove_explore_tests`,
`grove_shop_tests`, `grove_scene_workbench_tests`, `grove_scene_covers_tests`,
`grove_ui_workbench_tests`, `grove_zone_workbench_tests` — all green with no changes needed)

```
$ git add engine/scripts/scenes/board.gd engine/scripts/ui/hand_hint.gd engine/tests/ftue_hand_hint_tests.gd
$ git commit -m "FTUE: board triggers for the merge and generator-tap hand hints

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
[ftue-hand-hint 3d839929] FTUE: board triggers for the merge and generator-tap hand hints
 3 files changed, 123 insertions(+)
```

## Self-review findings

- Traced every consumer the brief lists (`Save.ftue_seen`/`mark_ftue_seen`, `HandHint.present`/
  `retarget`/`dismiss`/`GESTURE_DRAG`/`GESTURE_TAP`) against their actual definitions before
  wiring — all signatures match what the brief assumed.
- Confirmed `gen_nodes` is keyed by `Vector2i` cell (not a generator index, despite its stale
  inline comment "generator index -> node") by grepping every assignment site
  (`gen_nodes[cell] = gn` at board.gd:1558) — so `_hand_hint_gen_cell`'s
  `board.is_gen(cell)` / `board.gen_id_at(cell)` calls over `gen_nodes.keys()` are correctly
  typed.
- Verified `BoardLogic.find_mergeable_pair`, `BoardModel.is_gen`/`gen_id_at`, and
  `Content.is_accumulator`/`is_treat_gen` all exist with the signatures the brief's code assumes.
- No unintended interaction with `_pop_seed`'s own logic — `_pop_seed` is called unconditionally
  in the still-tap branch regardless of hand-hint state; the new `_end_hand_hint("gen_tap")` call
  is purely additive bookkeeping after it, matching the brief's placement exactly.
- Went beyond the brief's own headless checks (Steps 2/4/9/10) with three additional end-to-end
  probes against the **real** `Board.tscn` scene, through the real input handlers
  (`_on_press`/`_on_release`, the same path `grove_shot.gd`'s "played" mode uses) — see the
  host-size section below and "Real-path verification beyond the brief's own steps".

## Deviations from the brief, with reasons

1. **Staged specific files instead of `git add -A`.** Before I started, the worktree already had
   an unrelated, uncommitted edit to `.superpowers/sdd/progress.md` (Task 1/Task 2 review-notes
   additions, predating this session — confirmed via `git status` at the very start and `git diff`
   showing only Task 1/Task 2 lines, nothing about Task 3). The brief's Step 11 says `git add -A`,
   but that would have swept this unrelated, not-mine change into my commit. I staged only
   `board.gd`, `hand_hint.gd`, and `ftue_hand_hint_tests.gd` by name instead. `progress.md`
   remains modified-but-uncommitted in the worktree, exactly as I found it — untouched by me,
   left for whoever owns that note to commit separately.
2. **`games/grove/tests/grove_test_base.gd` left untouched.** The brief's Step 10 conditional
   ("if grove_ui_tests or grove_placement_tests now fail...") only applies if a suite actually
   fails. `make test` was fully green (30/30 suites, 1724/1724 assertions) without it — no suite
   in this codebase's current suite set is even named `grove_ui_tests` or `grove_placement_tests`
   (the project's suite names have since diverged from the description in the top-level
   CLAUDE.md's project notes); the suites that do build the board scene
   (`grove_board_actions_tests`, `grove_explore_tests`, `grove_shop_tests`, etc.) all passed
   as-is. No change made.
3. **`.superpowers/sdd/task-3-report.md` was a stale report from an unrelated earlier task**
   (the `action-button-component` plan's own Task 3, "workbench `action_button` component") —
   the file path is being reused across feature branches/plans. I read it in full before
   overwriting it with this report, per the "never distribute/discard what you haven't seen"
   rule for pre-existing files.
4. **Line numbers in the brief were stale** (e.g. `_hint_pair` is at line 425, not 422;
   `_rebuild_all` at 1527, not 1524; `_release_gen` at 2744, not 2668; `_after_merge` at 3039, not
   2939) — the file has grown since the brief was authored. Located every insertion point by
   function name / anchor text instead of by line number; the code content matches the brief
   verbatim.

## Host-size finding (the question flagged in my task)

Verified empirically, through the **real** `Board.tscn` scene (not a synthetic test `Control`),
running headless with a real, frame-pumped `SceneTree` (via `create_timer`/`process_frame`
awaits — the same mechanism `games/grove/tools/grove_shot.gd` uses):

- Immediately after `add_child`, `board.size` reads `(0, 0)` (not yet laid out).
- After the same 0.5s settle `grove_shot.gd` uses (plus the extra `process_frame` awaits inside
  `_maybe_hand_hint` itself), `board.size` reads `(1920, 1920)` — non-zero.
- I temporarily instrumented `_maybe_hand_hint` with a one-line
  `print("PROBE host.size at present() = ", size)` immediately before the
  `HandHint.present(self, ...)` call, confirmed the printed value was `(1920, 1920)` — non-zero
  at the exact moment `present()` is invoked — then removed the print before committing
  (confirmed absent via `grep PROBE board.gd`; the parse-check and `make test` reruns quoted
  above are the ones taken after removal).
- The overlay's own `_veil` bands were measured directly: total band area `3652591.34` vs. host
  area `3686400.0` (`1920 × 1920`) minus the two grown merge cutouts — matching to within float
  error, confirming the dim actually covers the whole board (using the host-size fallback from
  Task 2's `_screen_size()`, since the overlay's own `size` stays `(0,0)` as Task 2 documented).

**Conclusion: passing `self` as the host is reliable.** By the time `_maybe_hand_hint` reaches
its `HandHint.present(self, ...)` call — after the brief's `await get_tree().process_frame` —
`board.gd`'s own `size` is already resolved to the real, non-zero board size, on both the very
first `_rebuild_all` call (from `_ready`) and every subsequent one. No change to which host is
passed was needed.

## Real-path verification beyond the brief's own steps

Per working-style notes on verifying the real rendered result rather than trusting proxies like
"parse succeeds" or "unit test passes," I ran three additional real-scene probes (temporary
scripts, run from the session scratchpad, never added to the repo):

1. **Fresh board, real screenshot** (`make shot-grove MODE=fresh`, the quiet/no-window-steal
   renderer): confirms visually that on a genuinely fresh save the merge hint appears correctly —
   two bright cutouts around the actual mergeable pair (two matching cookie items), everything
   else dimmed, the Task-2 fallback hand-drawn cursor mid-animation between them.
2. **gen_tap eligibility + a real tap ending it**: with `Save.mark_ftue_seen("merge")` pre-set,
   loaded the real board — confirmed `_hand_hint_id == "gen_tap"`, gesture `tap`, cutout centred
   on a real generator cell. Then performed a **real** still-tap via `_on_press`/`_on_release` on
   that generator cell (the same input path the game itself uses) — confirmed
   `Save.ftue_seen("gen_tap")` flipped to `true` and `_hand_hint` was dismissed
   (`_hand_hint_id == ""`, invalid).
3. **A real drag-merge ending the merge teach and handing off live**: on a fresh save, confirmed
   `_hand_hint_id == "merge"` pre-merge, then performed the same real drag-merge
   `grove_shot.gd`'s "played" mode uses (`_on_press`/`_on_release` on two matching pieces).
   Post-merge: `Save.ftue_seen("merge") == true`, and — without any rebuild call beyond the merge
   path's own `_after_merge` → `_end_hand_hint("merge")` → `_maybe_hand_hint()` chain —
   `_hand_hint_id` had already flipped live to `"gen_tap"` (gesture `tap`), confirming the
   hand-off-without-restart behaviour the brief's comments describe.

All three probes ran through the real `Board.tscn` scene and the real input handlers, not
synthetic stand-ins.

## Test summary

`make test`: 30 suites, 1724 passed, 0 failed (includes `ftue_hand_hint_tests` at 45/45).

## Concerns

None blocking. Two non-blocking notes for whoever picks up Task 4 or the final whole-branch
review:

- `.superpowers/sdd/progress.md` still carries the pre-existing uncommitted Task 1/Task 2 notes
  addition mentioned above; it was not committed as part of this task and needs its own
  resolution (either committed separately or folded into a future progress-ledger update,
  possibly along with a Task 3 line for this task).
- The real-scene probes above relied on the current fresh-board layout happening to contain both
  a mergeable pair and a tappable generator; if a future map/board-seed change removes either at
  game start, the corresponding hand hint would simply wait (per `next_hint_id`'s documented
  behaviour) rather than error — this is by design, not a gap, but worth knowing when re-checking
  visually after content changes.

---

## Review-fix addendum: flag-off must dismiss a hint that's already live

**Finding (Important, reviewer-confirmed via a live probe):** the spec requires that flipping
`ftue_hand_hint` off "removes both hints entirely with no other behaviour change." That held for
a hint not yet shown, but a hint already ON SCREEN when the flag flipped off was stuck forever —
`_maybe_hand_hint()` and `_end_hand_hint()` both checked `Features.on("ftue_hand_hint")` and
`return`ed before reaching their own `_dismiss_hand_hint()` call, so nothing downstream of that
check — including a real merge, which calls `_end_hand_hint("merge")` directly from
`_after_merge` — could ever tear the overlay down while the flag was off.

### What changed

`engine/scripts/scenes/board.gd`, two functions, both minimal (no restructuring beyond moving the
dismiss above the existing flag check):

- **`_maybe_hand_hint()`** (was line 447): added one line — `_dismiss_hand_hint()` — immediately
  before the existing `if not Features.on("ftue_hand_hint"): return`. This function runs at the
  end of every `_rebuild_all`, so any board rebuild after the flag flips off now clears whatever
  hint is live, unconditionally.
- **`_end_hand_hint(id)`** (was line 519): moved the existing `if _hand_hint_id == id:
  _dismiss_hand_hint()` block from AFTER the flag check to BEFORE it (it previously ran after
  `Save.mark_ftue_seen(id)`, which itself was gated behind the flag check). No new logic — the
  same conditional dismiss the function already did, just sequenced ahead of the early return.

### The `_end_hand_hint` question: still mark the ledger when the flag is off?

Chose **no** — kept `Save.mark_ftue_seen(id)` (and the `_maybe_hand_hint()` hand-off call) behind
the flag check, unchanged from before. Only the dismiss moved earlier. Reasoning:

- The dismiss is the part the finding is actually about — an on-screen overlay must go away. That
  has nothing to do with the ledger.
- The ledger (`Save.ftue_seen` / `mark_ftue_seen`) only has one other reader in this file:
  `_hint_pair()`'s idle-rock suppression, and that reader itself is `Features.on("ftue_hand_hint")`-
  gated (line 433: `if Features.on("ftue_hand_hint") and not Save.ftue_seen("merge"): return []`).
  So marking the ledger while the flag is off changes no observable behaviour today — but leaving
  it unmarked keeps a stronger invariant: the ledger only records "the player was actually taught
  and it stuck," meaning the flag can flip back on later without the seen-once teaches having
  silently skipped ahead based on actions taken while the feature was fully off. Marking on every
  off-flag action would be a NEW behaviour, not implied by the finding, and the task said to keep
  this minimal.
- This also matches the finding's own bar: "no other behaviour change." Gating the ledger write
  behind the flag, as before, changes nothing else about save state; moving it would.

`_maybe_hand_hint()`'s post-flip-off dismiss doesn't touch the ledger at all (it never did — it
only reads eligibility, never marks it), so no equivalent question applies there.

### Regression test added

`engine/tests/ftue_hand_hint_tests.gd` — three new assertions appended immediately before the
final `print("== %d passed...")`/`quit(...)` lines (the existing 45 assertions above were not
touched, reordered, or rewritten):

- `HandHint.present(...)` while the flag is on → overlay is live.
- Flipping `Feat.FLAGS["ftue_hand_hint"] = false` by itself does not touch the live overlay
  (`not v_flagflip.dismissed`) — isolates that the flag alone has no side effect on an existing
  instance, so the fix's behaviour is coming from board.gd explicitly calling `dismiss()`, not
  from some latent flag-reactivity in `HandHint` itself.
- `v_flagflip.dismiss()` after the flag is off still tears the overlay down
  (`v_flagflip.dismissed == true`).

**I first attempted board-level coverage in this same file** (instantiate the real `Board.tscn`,
seed `_hand_hint`/`_hand_hint_id` directly, flip the flag off, call the real `_maybe_hand_hint()`
/ `_end_hand_hint()` and assert on the outcome) — that's the actual reviewer-probed scenario, and
`Board.tscn`'s own dependencies are all static preloads inside `board.gd` (no project autoloads
declared in `project.godot`), so it isn't blocked by autoload wiring. It did not work cleanly:

- The first attempt (letting the engine drive `_ready()` via the normal `add_child()` /
  `NOTIFICATION_READY` path, mirroring `games/grove/tests/grove_test_base.gd`'s
  `_test_2x_doubler_rehome()`) **hung** — the process sat idle (~2s CPU over 120+s wall, not
  spinning) with no output at all, even the `Godot Engine v4.6.2...` banner. Killed it
  (`kill -9`) rather than let it run indefinitely; never let it finish.
- Investigating why: `grove_test_base.gd`'s board test only works because, by the time it runs,
  an earlier `await` elsewhere in that same suite has already pumped at least one engine frame —
  so `is_inside_tree()` is genuinely true when it inspects `scn.board`. This file's `_initialize()`
  never awaits/pumps a frame before reaching the board section, so `add_child(brd)` had not yet
  completed tree-entry when the next line ran. Falling back to the same
  `if brd.board == null: brd._ready()` guard `grove_test_base.gd` uses, called explicitly on a
  node that has been `add_child()`'d but not yet actually entered the tree, produced real engine
  errors instead of a hang: `ERROR: Unable to start the timer because it's not inside the scene
  tree` (board.gd:359), `ERROR: Condition "!is_inside_tree()" ... get_viewport_rect` (board.gd:360),
  then inside the `_rebuild_all()` → `_maybe_hand_hint()` chain `_ready()` itself triggers,
  `get_tree()` returned null and `await get_tree().process_frame` crashed with `Invalid access to
  property or key 'process_frame' on a base object of type 'null instance'`. The assertions after
  that point still nominally printed PASS, but only because a bug in the probe script itself
  (calling `HandHint.present()` a second time while the flag was already off, which correctly
  returns null per its own contract) meant the final two assertions were comparing against `null`
  and would have failed loudly had one more not itself crashed on `null.dismissed` first.
- Standing up a genuine frame pump (or otherwise getting the node reliably inside-tree before
  `_ready()` in a bare, frame-naive `extends SceneTree` script) is more machinery than "keep the
  change minimal" covers for this task, and risks leaving a flaky or slow test behind. Reverted
  to the overlay-level-only test described above.

**What the kept test covers, and what it doesn't:** the actual bug lived in `board.gd`'s
orchestration (`_maybe_hand_hint` / `_end_hand_hint` early-returning before dismissing), not in
`hand_hint.gd`. The kept test proves the piece it CAN reach reliably: `HandHint.dismiss()` carries
no flag gate of its own — it is unconditionally callable and effective regardless of
`Features.on("ftue_hand_hint")`. That is the exact mechanism `board.gd`'s fix depends on; if
`dismiss()` ever grew its own flag guard, this would catch it — though, like the attempt above, it
would NOT have caught the original board.gd bug itself (dismiss() was never broken; the caller not
reaching it was).

**Left uncovered, and why:** the board-level assertion that a live `_hand_hint` on a real, running
board actually goes to `null` (and the overlay actually leaves the scene tree) when the flag flips
off mid-session — specifically that a real merge (`_after_merge` → `_end_hand_hint("merge")`)
clears a live merge-teach overlay even while the flag is off, which is the exact scenario the
reviewer's live probe used to confirm the original bug. I did NOT re-run that live probe against
the fixed code myself — I do not have independent confirmation beyond code reading (the fix moves
the existing, already-correct `_dismiss_hand_hint()` call earlier, ahead of a flag check that
previously blocked it; both call sites were re-read after the edit to confirm the guard sequencing
is now un-conditional on the flag, per the diff quoted above) and the passing `make test` full
sweep (which exercises `board.gd` structurally via the grove suites' scene instantiation, but none
of those suites specifically toggle `ftue_hand_hint` off against a pre-existing live hint). This
is a real gap: an automated headless assertion of the reviewer's exact scenario does not exist in
this repo after this task. It belongs in a `games/grove/tests/grove_*_tests.gd` suite (one of the
suites that already knows how to reliably get a board instance inside-tree), as follow-up.

### Commands run and full output

`godot --headless --path . -s res://engine/tests/ftue_hand_hint_tests.gd`:

```
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org

== FTUE hand hint tests ==
  PASS  fresh save: merge is unseen
  PASS  fresh save: gen_tap is unseen
  PASS  an unknown id reads as unseen (never crashes)
  PASS  marking merge makes it seen
  PASS  marking merge leaves gen_tap alone
  PASS  marking twice is idempotent
  PASS  seen state survives a reload
  PASS  unseen state survives a reload
  PASS  a save missing the ftue_seen key reads as unseen (no migration)
  PASS  the ftue_hand_hint flag exists
  PASS  the ftue_hand_hint flag defaults ON
  PASS  drag: present returns an overlay
  PASS  drag: the overlay is parented to the host
  PASS  drag: the gesture is recorded
  PASS  drag: two cutouts (source + target)
  PASS  drag: cutout 0 is centred on the source
  PASS  drag: cutout 1 is centred on the target
  PASS  drag: every node in the overlay ignores mouse input (never blocks play)
  PASS  retarget: cutout 0 follows the new source
  PASS  retarget: cutout 1 follows the new target
  PASS  retarget: the overlay stays live (no re-present)
  PASS  dismiss: the overlay is marked dismissed immediately (the fade then frees it)
  PASS  tap: present returns an overlay
  PASS  tap: one cutout (the target only)
  PASS  tap: every node ignores mouse input
  PASS  flag off: present returns null
  PASS  flag off: nothing is added to the host
  PASS  veil: tap bands' total area == host area minus the grown cutout
  PASS  veil: tap bands never overlap the cutout
  PASS  veil: drag bands' total area == host area minus both grown cutouts
  PASS  veil: drag bands never overlap either cutout
  PASS  veil: overlapping cutouts — bands' total area == host area minus the UNION (no double-counted area)
  PASS  veil: overlapping cutouts — the bands themselves have no gaps or overlaps
  PASS  veil: overlapping cutouts — no band overlaps either cutout
  PASS  veil: an off-screen-partial cutout — bands still tile the visible screen (only the on-screen sliver is punched out)
  PASS  veil: an off-screen-partial cutout — no band has a negative size
  PASS  veil: an off-screen-partial cutout — no band overlaps the (clipped) cutout
  PASS  retarget after dismiss: a no-op — the target doesn't move
  PASS  fresh board: merge is the eligible hint
  PASS  merge seen: gen_tap follows
  PASS  both seen: nothing is eligible
  PASS  no mergeable pair: the merge hint waits (does not skip ahead)
  PASS  no generator node: gen_tap waits
  PASS  gen_tap already done: merge still shows
  PASS  gen_tap already done: it never shows afterwards
  PASS  flag-flip: a hint can be live while the flag is on
  PASS  flag-flip: flipping the flag off, by itself, does not touch a live overlay
  PASS  flag-flip: dismiss() still tears the overlay down after the flag is off
== 48 passed, 0 failed ==
```

(48 = the pre-existing 45 + 3 new. Also preceded by six harmless `ERROR: ... GodotApplePlugins*
.gdextension` lines — a pre-existing, unrelated missing-addon warning on every headless run in
this project, not caused by this change; omitted above for brevity, present in the raw run.)

`make test` (full sweep — required because this change touches `board.gd`, which the grove
suites instantiate):

```
================================================================
      time   pass  status  suite
  ------------------------------------------------------------
     5.12s    210  ok      games/grove/tests/grove_shop_tests
     4.80s    252  ok      games/grove/tests/grove_explore_tests
     3.46s    112  ok      games/grove/tests/grove_ui_workbench_tests
     1.90s    183  ok      engine/tests/mechanics_tests
     1.21s     64  ok      games/grove/tests/grove_board_actions_tests
     1.13s    124  ok      engine/tests/layering_tests
     1.12s     13  ok      engine/tests/action_button_tests
     1.03s     66  ok      engine/tests/quest_fence_tests
     0.94s     93  ok      engine/tests/save_tests
     0.94s     47  ok      engine/tests/quest_tests
     0.94s    170  ok      games/grove/tests/grove_scene_workbench_tests
     0.94s      4  ok      engine/tests/strings_tests
     0.84s     31  ok      engine/tests/bucket_adapter_tests
     0.83s     48  ok      engine/tests/ftue_hand_hint_tests
     0.83s      4  ok      engine/tests/kit_config_cache_tests
     0.83s     12  ok      engine/tests/hint_tests
     0.83s     33  ok      engine/tests/home_build_tests
     0.75s     37  ok      engine/tests/iap_tests
     0.75s     18  ok      engine/tests/inbox_sync_tests
     0.75s     19  ok      engine/tests/tuning_tests
     0.75s     15  ok      engine/tests/bust_tests
     0.75s      9  ok      engine/tests/store_tests
     0.74s      4  ok      engine/tests/build_info_tests
     0.74s     20  ok      games/grove/tests/grove_scene_covers_tests
     0.74s     13  ok      games/tools/tests/slice_islands_tests
     0.74s     66  ok      engine/tests/resident_bucket_tests
     0.74s     25  ok      engine/tests/boot_trace_tests
     0.74s      6  ok      engine/tests/identity_tests
     0.74s     22  ok      games/grove/tests/grove_zone_workbench_tests
     0.73s      7  ok      engine/tests/scene_warm_tests
  ------------------------------------------------------------
  wall  11.09s  (sum of suite-times  37.37s, speed-up 3.4× at JOBS=4)
  30 suites · 1727 passed · 0 failed

  ALL SUITES PASSED
```

Both commands were re-run once more, unchanged, after reverting the board-scene test attempt
described above (final board.gd/test-file state) — same results both times.

### Files touched by this addendum

- `engine/scripts/scenes/board.gd` — `_maybe_hand_hint()` and `_end_hand_hint()`.
- `engine/tests/ftue_hand_hint_tests.gd` — 3 new assertions appended before the final print/quit.
- `.superpowers/sdd/task-3-report.md` — this addendum.

`.superpowers/sdd/progress.md` has pre-existing uncommitted edits from other in-flight work not
touched by this fix; left as-is, not staged, per the task's own instruction.
