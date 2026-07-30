# Cascade combos — design

Date: 2026-07-26 · Status: **SHIPPED** · Parent: `2026-07-26-progression-systems-design.md` §5/§8-step-3.
Supersedes the parent §5 wording: chains auto-execute — the parent's break rules ("any pop, any
delivery…") and §6's "nothing ever merges by itself" clause are obsolete. All numbers are
provisional dials; the sim owns finals.

## 1 · What it is

A player merge **tips a cascade** when an equal pair produces a result that can continue through
adjacent same-line, same-tier partners. The follow-up merges run **by themselves**, one hop at a
time. One algorithm finds the longest run; the UI follows it. Chain length pays one reward — a
chest that grows with the run. Armed ladders wear a paper ribbon along the run. Runways — same-line
tier staircases with no equal pair yet, but one duplicate away from a cascade — wear a weaker
mark tagged with the tier they need. Dragging a piece shows ignition pads and weaker extension
pads; the guide IS the teach (no FTUE dialog). Home board only; the Rush is untouched.

**What gets built:**

| File | Change |
|---|---|
| `engine/scripts/core/board_logic.gd` | + `chain_path` · `ready_ladders` · `runways` · `chain_placements` (§3) |
| `engine/scripts/scenes/board.gd` | + run executor, rewards, `chain_running()`, drag-guide wiring (§4–5, §8) |
| `engine/scripts/ui/cascade_outline.gd` | **new** — run ribbons, ×n tags, drop marks (§7–8) |
| `engine/scripts/core/content.gd` | + `G.line_color(code)` accessor (§7) |
| `games/grove/grove_data.gd` | chest line `"top": 5` + loot rows 4/5 (§6) |
| `games/grove/assets/items/chest/chest_4/5.png` | chest line art tiers 4/5 (§6) |
| `engine/scripts/core/features.gd` + `docs/FEATURES.md` | + `"cascade"` flag + row (§9) |
| `games/grove/tools/grove_shot.gd` | + seeded `cascade` capture mode (§10 visual gate) |
| `engine/tests/cascade_tests.gd` · `games/grove/tests/grove_cascade_tests.gd` | **new** suites (§10) |
| `Makefile` + project `CLAUDE.md` | suite registrations (§10) |

## 2 · Rules

- **Only a player merge tips a run** — drag merge (`_commit_merge`) or recipe merge
  (`_apply_recipe`). Placements never auto-merge: moves, swaps, bag retrieves, pops, drops,
  starfall (step 5), soil harvests (step 4).
- **Arming floor:** a player merge tips a run only when the final length would reach
  `CHAIN_MIN_N` (`3`). A `t·t·t+1` board resolves as an ordinary merge to ×2; `_prepare_chain`
  drops any run where `1 + _chain_run.size() < CHAIN_MIN_N`.
- **Step-4 cells** (Magnet range auto-merger; the Mirror is cut —
  `2026-07-26-cell-improvements-design.md` §5-6): its auto-merges neither tip nor extend runs,
  and it holds fire while a run executes. The scene exposes `chain_running() -> bool` as that
  gate, and passes `_chain_armed_cell()` — the run's next partner (`board.gd:2707`) — to
  `BoardActions.magnet_merge_once` so a Magnet cannot consume a cell a queued step needs.
- **Auto-steps are same-code merges onto adjacent partners.** Legality per `can_merge`
  (`board_model.gd:305`), which caps at `merge_top`. Recipes never fire automatically.
- **Landing rule:** each step slides the result onto its partner's cell (same as a player
  merge: source vacates, target hosts the upgrade). The run snakes along the partner path.
- **Auto-steps are real merges**, routed through the normal commit path: discovery
  (`_mark_seen`), bramble unseal, the 10 % coin / 2 % special lucky rolls, daily-quest merge
  counters, and the 2.5 s merge streak (`_bump_combo` → note ladder / words / bloom —
  untouched, and it escalates through a run naturally) all observe them as usual.
- **Input stays locked for the whole run** (`animating`); each step persists via
  `_after_board_change()`. A crash mid-run just leaves a shorter chain.
- **Count:** the tipping merge is ×1; each auto-step +1. The path is computed once at commit
  and cannot be invalidated mid-run (partners are occupied cells; drops land only on empty
  ones).

## 3 · The algorithm — `board_logic.gd`

One DFS, three thin consumers. Branching ≤ 3, depth ≤ 11 — brute force, no caching.

```gdscript
# THE algorithm. The auto-run if `a` is merged onto `b`: ordered partner cells the
# result will slide onto. Empty = nothing lined up. Final chain = 1 + path.size().
# DFS over adjacent same-code partners, longest run wins; ties break row-major.
static func chain_path(board: BoardModel, a: Vector2i, b: Vector2i) -> Array

# Outline data: per qualifying same-line component (best chain ≥ 2):
# { cells, run, line, n, top_cell }
#   n        = best chain over every in-component tip-over (direction matters)
#   run      = merge destination + auto-chain path; excludes the duplicate source
#   top_cell = the best run's final landing cell (anchors the ×n tag)
static func ready_ladders(board: BoardModel) -> Array

# Runway data: same-line components that have no equal pair today, but adding
# one duplicate of a present tier would reach min_n. Ignite cells are the empty
# ground cells where dropping needs_code would fire the cascade.
# { cells, run, line, needs_code, would_be_n, ignite_cells }
static func runways(board: BoardModel, min_n: int) -> Array

# Drag guide: empty ground cells (≠ from) where placing `code` raises the joined
# component's best chain to ≥ 2 and above its prior value. [{ cell, n }]
static func chain_placements(board: BoardModel, from: Vector2i, code: int) -> Array
```

Direction matters: merging A onto B lands the result at B, so only partners adjacent to B
continue the run — `ready_ladders` computes n over both tip-over directions. Longest beats
greedy: with two adjacent partners, the DFS must take the one whose onward neighbours extend
the run. `runways` reuses `chain_placements` for `ignite_cells`; it does not create a second
placement search.

## 4 · Run execution — `board.gd`

- `_commit_merge` / `_apply_recipe` compute `_chain_run := BoardLogic.chain_path(board, a, b)`
  (flag-gated). `_prepare_chain` arms only if `1 + _chain_run.size() >= CHAIN_MIN_N`; otherwise
  it clears the run and the merge ends normally.
- Before the first automatic step, `_schedule_chain_step` holds for `CHAIN_PREROLL_MS` (`300`) and
  `_show_chain_preroll` pulses the exact run cells with the ×n tag. Input remains locked during
  the pre-roll.
- After each merge resolves, if `_chain_run` is non-empty: pop the next partner, keep
  `animating` true, `board.merge(result_cell, partner)`, slide + standard merge-impact FX,
  `_chain_n += 1`, reward hook (§5), repeat. Step pace ramps from `CHAIN_STEP_START_MS` (`320`)
  to `CHAIN_STEP_END_MS` (`180`) by `CHAIN_STEP_RAMP_END_N` (`5`); `CHAIN_STEP_RAMP_ENABLED`
  falls back to `CHAIN_STEP_MS` (`250`).
- Per step ≥ ×2: a "×n" floater at the run origin cell (`FX.floating_text`, `fx.gd:330`), size
  stepping up with n. `CHAIN_COUNTER_ANCHOR_ORIGIN` falls back to the step merge cell. `FX.burst`
  (`fx.gd:664`) stays at the ×5+ merge cell. Offset from the streak's milestone words.
- During an armed run, input stays locked but `board_area` remains fully visible; no board-wide
  dimming is applied.

## 5 · Rewards

One reward per chain, by final length. Rewards start at ×3. Born mid-run on the cell the step just
vacated — always free, synchronously, before the lucky rolls.

| Chain reaches | Reward |
|---|---|
| ×3 | chest t1 is born (40 c) |
| ×4 | the chest upgrades in place → t2 (120 c + 1 acorn) |
| ×5 | → t3 (320 c + 3 acorns) + burst |
| ×6 | → t4 (dial ~800 c + 6) |
| ×7+ | → t5 (dial ~2000 c + 12), cap |

- Upgrade = swap the chest's code in place + pop FX. Tracked by run-local cell; if the player
  later opens or merges it, that's theirs — no further handling (the run already ended).
- The chest is an ordinary piece: second-tap open (`_open_chest`, `board.gd:3393` →
  `G.chest_open_reward`), mergeable with other chests, persisted by the normal board save.
- Economy: payouts flow through chest-open → `Save.add_coins` / `add_diamonds` — spendable
  only; `G.earn_coins` (the quest clock) is never touched. `grove_sim` tracks
  chests-per-chain plus per-step lucky rolls.

## 6 · Chest line extension (option B — in scope)

- Data: `"top": 5` on the line-10 def (`SPECIAL_TOP` stays 3; per-def override already exists,
  `grove_data.gd:343-349`) + `CHEST_OPEN_COINS`/`ACORNS` rows `4:` and `5:`
  (`grove_data.gd:365-366`). Detection, outlines and `merge_top` follow automatically.
- Art: `items/chest/chest_4.png`, `chest_5.png` — produced separately from approved direction
  mocks and landed on `main` via the intake pipeline.

## 7 · Ready-ladder outline

- Node `engine/scripts/ui/cascade_outline.gd`, one `board_area` child. The scene passes armed
  `ready_ladders` entries with `n >= CHAIN_MIN_N`; ×2-only ladders draw nothing. It also passes
  `runways(board, CHAIN_MIN_N)` entries for weaker resting marks.
- Stack invariant: the outline child index must sit above every slot/mat node and below every
  live piece/generator (`move_child`; draw order = child order, no CanvasLayers). Exclude
  queued-for-deletion nodes from the computation because `queue_free` is deferred; the guard is
  `grove_cascade_tests.gd`'s stack assertion with stale generator nodes present. Template:
  `focus_ring.gd` (`@tool`, `@export` knobs, `_draw`).
- Per armed `ready_ladders` component: the run's cells are unioned into ONE shape and its outline
  extracted as closed contours (`engine/scripts/ui/cell_contour.gd`, pure + unit-tested). The
  cells are the `run` — the cells the cascade walks — never `cells`, a same-line flood fill with
  no tier condition. A tipped `1,1,2,3` run starts at the merge destination, so the duplicate
  source cell is outside the shape. One rule covers every shape: straight, bend, T, ring (the hole
  is its own loop, wound the other way) and the DIAGONAL PINCH (two cells meeting at a corner
  only, which is two loops — a walk that keys boundary edges by their start corner drops one).
  Convex corners round to the tile's own radius; reflex corners stay SHARP, because rounding them
  cuts a notch out of the shape, and because a sharp corner is exactly where the strip's mitre
  offset clips instead of self-intersecting. Redraw on recompute and, while a chain is marked,
  per frame for the animation.
- Material: light, not paper. The contour carries a layered profile drawn as ONE vertex-coloured
  triangle strip per loop — a soft haze outside, a warm band filling the tray gap, a hot line ON
  the tile's cut edge — and a subtle wave train travels around the whole contour once (`u` = arc
  length; 2 crests, integer so the wrap is seamless). The chain's own tiles carry a static warm
  lift and the tray gutters BETWEEN two chain cells glow steadily, as if lit from underneath. The
  interior is deliberately NOT driven by the arc parameter: inside the shape it is discontinuous
  across the medial axis and stamps a hard seam down the middle. The profile's rails are anchored
  to lengths derived from the board — the pitch (read back off `_cell_pos`), the contour-to-tile-edge
  gap, and the hull corner radius — so the mark scales with the cell; the inner rails stop at
  `INNER_CAP` of the corner radius, past which the inner rail turns inside out around the arc centre.
- The line colour is pulled `GOLD_PULL` toward warm gold: the light pools over a whole chain and
  shows through a piece's transparent margins, so a saturated hue tints the art itself (measured —
  at a 0.68 pull, line 1's pink washed its mushrooms salmon). The line leans the hue; gold is what
  a line looks like as light on this tray.
- The wave is PINNABLE: `CascadeOutline.forced_phase`, set by `engine/tools/shot_base.gd`'s
  `begin` (`cascade_phase=<0..1>`, or `auto` for live). `make shot` compares captures byte for
  byte, and a running animation lands on a different phase in a warm batch process than in a
  fresh one; `tools/test_shot_batch.py` is the guard. `_process` runs only when there is a chain
  to animate and the phase is not pinned.
- Per `runways` component: the same light, at half strength with a tighter halo. It carries no
  tier text; the glow is the only resting runway hint.
- Color: `G.line_color(code)` reads `G.LINES[line].color`, fallback `Pal.TEXT_MUTED`
  (mirrors `piece_view.gd:297`). No hex literals (`palette_ssot_tests`).
- Tags: resting armed ladders show a small code-drawn ×n paper chip on `top_cell`'s corner.
  During drag, the same ×n anchors on the occupied drop target (`tag_cell`) so the player sees
  which item to drop onto. Empty staging pads and inert runways never carry text.
- Geometry via `_cell_pos` (`board.gd:1704`, owns the landscape transpose).

## 8 · Drag guide

On `_begin_drag` of an item (never a generator): compute drag guide marks once (the model is
frozen mid-drag). Cleared on every release outcome. The merge telegraph (`_update_telegraph`)
is untouched.

**Only a merge fires a cascade.** `_prepare_chain` is reachable from `_commit_merge_confirmed`
and `_apply_recipe_confirmed` only; a drop on an empty cell is `_commit_move` → `board.move()`
and arms nothing. The marks say which of the two a drop is:

| Mark | Where | Style | ×n |
|---|---|---|---|
| `cascade` | an occupied same-code target whose merge reaches `CHAIN_MIN_N` | strongest | **yes** |
| `merge` | any other occupied same-code target | mid | no |
| `stage` | an empty cell that would grow the held line beside a single lower/higher tier, finish `chain_placements` at `n >= CHAIN_MIN_N`, or extend a runway/ladder | weakest | no |

The three are different **materials**, not three weights of one stroke: `stage` cuts a shallow well
into the cardstock (something goes here), while `cascade` and `merge` pool warm light behind an
occupied piece. The pool is warmed ~60 % toward gold — it shows through the piece's own transparent
margins, so a saturated line colour tints the art itself rather than reading as light. Never a
`modulate` brighten: that clamps to nothing on art this bright.

- **A ×n appears only for a drop that really runs a chain.** During drag focus it anchors on the
  occupied drop target, not the chain end; empty staging cells never carry ×n.
- **`stage` starts from one adjacent tier.** Holding `t2`, for example, marks every empty ground
  cell beside same-line `t1` and `t3` pieces. These are build hints only: they do not promote the
  single neighbor to `merge`/`cascade`, and they never show ×n.
- **`stage` marks are suppressed whenever a `cascade` mark exists** — when a firing move is
  available it is the answer, and the staging cells around it compete with it.
- When a held item has a `cascade` target, the outline uses a drag-focused ladder built from
  `[target] + BoardLogic.chain_path(board, from, target)`. Resting ready/runway ribbons and their
  tags are hidden until release, so the guide describes the chain the held item will create.
- Nothing draws when the held piece neither merges nor builds.

## 9 · Flags & save

- `"cascade": true` in `features.gd` + a `docs/FEATURES.md` row. OFF = today's behaviour
  exactly.
- No FTUE and no save changes: no new fields, no `SCHEMA_VERSION` bump. The outline, tag and
  ghost pads are the teach. No chain state exists outside a running cascade.

## 10 · Verification

- **Engine** `engine/tests/cascade_tests.gd` (+ `ENGINE_TESTS`, `Makefile:11`):
  - `chain_path`: no partner → empty; straight ladder → full path; direction asymmetry (A→B
    runs, B→A doesn't); longest-beats-greedy (two partners, only one extends); tie-break
    determinism; `merge_top` stops the walk (chest t5 cap); recipes/other codes never chain.
  - `ready_ladders`: minimal t·t·t+1 → n 2; +t4 → n 3; gap → none; duplicate rung doesn't
    extend or draw as part of `run`; stray singleton doesn't disqualify; n is direction-aware;
    two components → two entries.
  - `chain_placements`: completes a ladder → candidate; lengthens → n+1; spare beside a ready
    ladder → not a candidate; bridges two clusters → candidate; `d == from` excluded; no kin →
    empty.
- **Grove** `games/grove/tests/grove_cascade_tests.gd` (+ `GROVE_TESTS`, `Makefile:15`, +
  the project `CLAUDE.md` suite list line). Boot idiom: `grove_ftue_tests.gd:34-56`.
  - A ×2-only ladder neither telegraphs nor arms nor shows drag pads.
  - A tipped ×3-capable ladder auto-runs with input locked; the pre-roll holds before the first
    auto-step and telegraphs the exact run.
  - Cascade watchdog keeps input locked past the single-merge timeout; unrelated player input is
    ignored until the queued steps and final reward finish.
  - Bailouts for an empty queue or invalid next partner release the input gate.
  - Rewards: ×3 chest `1001` is the first reward; ×4 upgrades that cell to `1002`; wallet and
    `coins_earned` unchanged until chest-open; open credits `add_coins` only.
  - Guide pads on `_begin_drag`, cleared on release; generator drag → none.
  - Weak guide pads start from a single lower/higher neighboring tier; they stay unnumbered and
    below cascade strength.
  - Resting runways draw no `tN` label, drag cascade tags sit on the occupied drop target, and
    ready ribbons exclude the duplicate source cell.
  - A mixed component with a lower-tier `×5` at rest focuses to the held item's `×3` run while
    dragging; ordered ribbon links do not connect touching non-consecutive path cells.
  - Outline present iff an armed ladder exists; tag text ×n; stack index above mat/slots and below
    live items, with stale queued-for-deletion generator nodes present.
  - Flag OFF → no chain, no outline, no pads.
- **Visual gate:** quiet-godot `cascade` captures — lit ladder (stitches + tag), `phase=guide`
  ghost pads under a lifted piece, `phase=seedguide` for one-neighbor build pads,
  `phase=dragfocus` for a mixed-component held-path guide, and a mid-run step with floater —
  looked at before done.
  `phase=guide` needs a ×3-capable fixture; ×2 placements exit 0 with a bare board because the
  scene filters out pads that would not arm a cascade.
- `make test` green.

## 11 · Open questions

1. Auto-steps also roll the 10 %/2 % lucky drops (uniform-merge stance) — confirm, or should
   auto-steps skip them? The sim pass will quantify either way.
