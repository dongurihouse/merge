# Cascade combos + ready-ladder outlines — design

Date: 2026-07-26
Branch: `spec/cascade-combos` (spec only — implementation is rollout **step 3** of the parent)
Status: **draft, rev 2 — after first Dev review (same day).**
Parent: `2026-07-26-progression-systems-design.md` §5 (chain rule, outlines, rewards, FTUE), §7
(economy laws), §8 step 3. This spec expands §5 to implementation grade. Where wording differs,
this spec wins — the deltas are listed in §2. All numbers remain provisional dials.

Rev 2 (Dev review, three calls): **the chain is its own counter, fully separate from the
existing merge combo** (nothing existing is re-cadenced); **dragging an item shows a placement
guide** — the cells where dropping it would form or lengthen a chain; and **every chain pays one
reward scaled by its length** — the growing chain chest replaces both the per-step coins and the
daily ×5 chest.

## 1 · Goal

Give the one merge verb a second layer of skill without adding a timer: a **chain** counts merges
that each consume the piece the previous merge just created; **ready-ladder outlines** show where
a chain is waiting; a **drag guide** shows where placing the lifted piece would build one; every
chain pays **one reward scaled by its length — a chest born mid-chain that grows with it**; a
**one-time FTUE** teaches it. Home board only — the Rush keeps its own combo.

Five deliverables in one Dev-given task: the chain counter (beside the cozy time-window streak,
never mixed with it), ladder detection + the stitched outline, the drag placement guide, rewards,
cascade FTUE.

## 2 · What exists today, and corrections to the parent

The home board already has a merge streak — **it stays exactly as it is** (rev 2 Dev call). The
chain runs beside it and drives none of its cues. The table is what the cascade must not disturb:

| Piece | Where |
|---|---|
| Streak state `_combo_count` / `_last_merge_ms` | `board.gd:132-133` |
| Cadence: `_bump_combo()` → `BoardLogic.combo_step(prev, dt, window)` | `board.gd:3238`, `board_logic.gd:155` — **time-window**, `Tune.COMBO_WINDOW := 2.5` (`tuning.gd:279`) |
| Call site: `combo` → `GridFx.play_merge(...)` | `board.gd:3194-3205` |
| Merge note ladder (10 baked pentatonic degrees, no pitch warp) | `feel.gd:98` `_merge_degree`, played `merge_fx.gd:134-143`, `MERGE_NOTES := 10` `tuning.gd:329` |
| Milestone words at 3 / 5 / 8 | `merge_fx.gd:152-157`, `COMBO_MILESTONES` `tuning.gd:280` |
| Screen bloom | `ComboBloom.bump(combo, pct)` `board.gd:3208`, `combo_bloom.gd` |
| Rush twin (separate, untouched) | `Explore.combo_after`, 1.5 s window — `explore.gd:129`, `explore_rush.gd:638` |

**Corrections / deltas to the parent §5:**

1. *"sound pitch rises per step (the existing merge-streak audio machinery … is the base)"* —
   **superseded by the rev 2 separation call.** The chain drives no audio of its own: the note
   ladder, the milestone words and the bloom all belong to the time-window streak and stay
   untouched. (A fast cascade still *sounds* escalating — its merges also ride the 2.5 s streak —
   but a slow, thoughtful cascade only advances the chain. Accepted consequence.) For the record,
   the parent's attribution was also imprecise: the escalation is **note selection** off a baked
   10-note ladder (`feel.gd:98`, jitter deliberately disabled `audio.gd:71-84`), not a rising
   `pitch_scale`, and it lives in the FX layer, not `board_logic`.
2. *"a duplicated bottom"* is generalized to *any duplicated tier with consecutive rungs above*
   (§6) — a stray lower singleton adjacent to a real ladder must not kill its outline.
3. New ruling the parent didn't cover: **craft merges join the chain** (R2, §3).
4. The parent's per-step coin bonuses and once-per-real-day ×5 chest are **replaced (rev 2 Dev
   call)** by one reward per chain, scaled by its final length: the **chain chest** (§7). No
   daily gate, no wallet credits mid-chain.
5. *"confetti burst at ×5"* maps to `FX.burst` (`fx.gd:664`, the petal burst) — the repo has no
   separate confetti primitive, and doesn't need one.

## 3 · The chain rule

> A merge continues the chain only if it uses the piece the previous merge just created.
> Otherwise it starts a new chain. Pops and deliveries end the chain. Nothing else matters —
> rearrange and think as long as you like. No timer anywhere.

State, scene-local in `board.gd`, **new fields beside the untouched streak pair**:
`_chain_count: int` and `_chain_cell: Vector2i` (the **armed** cell — where the newest merge
result sits; `(-1,-1)` = disarmed). Reset on board open; survives `_rebuild_all` (cells are
stable across view rebuilds); never saved.

The complete verb table — every player action and its chain effect. **END** = count 0, disarmed
(the next merge starts a fresh ×1). **Restart** = the merge arms its own result at ×1.

| Verb (handler) | Chain effect |
|---|---|
| Item merge using the armed piece — `a == armed or b == armed` (`_commit_merge` → `_after_merge`, `board.gd:3179`) | **count+1**, re-arm on the result cell `b` |
| Item merge ignoring the armed piece (including the first merge) | **restart** at ×1, arm `b` |
| Craft/recipe merge (`_apply_recipe`, `board.gd:3126`) | same two rules — see **R2** |
| Any generator pop: `_pop_seed` `:2964`, `_pop_treat` `:3565`, `_collect_accumulator` `:3429` | **END** |
| Delivery — all three entries funnel into `_deliver_quest` `:3767` | **END** |
| Plain move (`_commit_move` `:3605`) | neutral; if it moves the armed piece, the armed cell follows |
| Swap (`_commit_swap` `:3619`) | neutral; armed cell follows either side |
| Generator verbs — move / swap / **gen merge** / store (`_release_gen` `:2881`) | neutral (**R3**) |
| Stash to bag (`_stash` `:3639`), sell (`_sell_item` `:3985`, `_sell_generator` `:3918`, `_retire_line` `:3969`), collect coin / open chest / collect special (`:3332` / `:3393` / `:3372`) | neutral — **unless it consumes the armed piece → END** |
| Bag retrieve `:3678`, buy `:2404`, boost `:3146`, bag-slot buy, 2× offer | neutral |
| Passive arrivals: coin/special drops `:3290`/`:3348`, bramble seeds `:3258`, gen birth `:3085`, gen self-dup `:3104` — and the step-5 starfall when it lands | neutral |

The breaks are exactly the parent's three: a merge that ignores the newest piece, a pop, a
delivery. Everything else is at most a disarm — consuming the armed piece by any non-merge means
ends the chain silently, because there is nothing left to continue with.

**Rulings:**

- **R1 — two counters, never mixed (rev 2 Dev call).** The time-window streak (`_combo_count`,
  `_bump_combo`, `combo_step`, the 2.5 s window) is **not modified in any way** and keeps
  driving everything it drives today: the `combo` argument into `GridFx.play_merge`, the note
  degree, the milestone words, the bloom. The chain is a second, additive counter with its own
  presentation (×n floater, the chain chest, ×5 burst, outline vocabulary) and **feeds none of
  the streak's cues**. During a fast cascade the two rise together; that is fine and expected.
- **R2 — craft merges are merges, for the chain.** A recipe merge that consumes the armed piece
  continues the chain and re-arms on its product; one that ignores it restarts. It reports to
  the chain seam only — the streak is untouched by R1, so today's `_apply_recipe` oddity (it
  skips `_bump_combo` and the merge-impact FX) stays as-is, noted, out of scope. (Chain credit
  parallels the parent §10 Q1 mastery law: crafts are productive use. Dev confirm — §13 Q1.)
- **R3 — generator merges are housekeeping, not dominoes.** They produce a generator, not a
  board piece; neutral, as today (they never bumped the streak).
- **R4 — only player merge commits touch the chain.** The tracker is called from exactly two
  seams: `_after_merge` and `_apply_recipe`. Future automatic merges (Mirror echoes, step 4)
  bypass it by construction — the parent §7 "no chain credit, no combo coins" law needs no
  guard code.
- **R5 — every mergeable line participates uniformly**, coins, chests and specials included
  (they merge like anything else — `can_merge`, `board_model.gd:305`). A coin ladder can
  cascade; the chain chest is an ordinary chest piece. No special cases.

## 4 · Pure seams — `board_logic.gd`

Three statics beside the untouched `combo_step`; the scene keeps the new fields and the
one-line follow/disarm updates at the handlers named in §3.

```gdscript
# Chain cadence: prev+1 when the merge uses the armed cell, else 1.
static func chain_on_merge(prev_count: int, armed: Vector2i, a: Vector2i, b: Vector2i) -> int

# §5 detection. [{ "cells": Array[Vector2i], "line": int, "n": int, "top_cell": Vector2i }]
static func ready_ladders(board: BoardModel) -> Array

# §5 drag guide: empty ground cells where placing `code` (lifted from `from`) creates or
# lengthens a ready ladder. [{ "cell": Vector2i, "n": int }] — n is the value after placement.
static func chain_placements(board: BoardModel, from: Vector2i, code: int) -> Array
```

The wiring, sketched — a **new** function beside the untouched `_bump_combo()`, called from
`_after_merge` (which has `a`/`b` in hand) and `_apply_recipe`:

```gdscript
func _bump_chain(a: Vector2i, b: Vector2i) -> int:
    if not Features.on("cascade"):
        return 0
    _chain_count = BoardLogic.chain_on_merge(_chain_count, _chain_cell, a, b)
    _chain_cell = b
    return _chain_count
```

## 5 · Ready-ladder detection

A **ready ladder** is a connected group of same-line pieces whose tiers cascade from a
duplicated tier: merge the pair, and each result lands next to its next match.

Algorithm, pure over `BoardModel`:

1. **Components:** 4-orthogonal adjacency over cells holding items of the same line
   (generators, empties, brambles excluded).
2. **Chain value:** within a component, for each tier `t` present at count ≥ 2 and legal to
   merge (`t < merge_top(line)`), walk up: the pair merge yields `t+1`; the chain extends while
   a piece at the next tier exists **and** that tier is still legal to merge. `n(t)` = number of
   merges in the walk; the component's `n` = the best `n(t)`.
3. **Qualifies** when `n ≥ 2` (a bare pair is just a merge, not a cascade — no outline).
4. **Outline** hugs the whole component — spare duplicates and stray tiers included (they're
   the same-line cluster the player is looking at; delta 2 in §2).
5. **Tag:** `×n`, anchored to the top piece of the best walk (`top_cell`; ties → higher tier,
   then scan order). Multiple qualifying components each get their own outline and tag.

Worked examples: `t2·t2·t3` → ×2; `+t4` → ×3; a gap (`t2·t2·t4`) → no rungs, ×1, no outline;
duplicate rungs don't extend (`t2·t2·t3·t3` → ×2); chest line `t1·t1·t2·t3` → **×2**, because
the t3 pair-step would need tier 3 < the chest line's top (3 today) and stops (`merge_top` cap,
R5 — under §8 option B, top 5, the same group walks to ×3).

**Placement candidates — the drag guide's model.** For a lifted item, `chain_placements`
simulates the board without the piece at `from`, then for each empty ground cell `d ≠ from`:
place the code at `d`, compute the ladder value `n_after` of `d`'s component, and compare it
with `n_before` — the best ladder value among the components `d` joins (0 = no duplicated
legal tier; a bare pair = 1). **Candidate iff `n_after ≥ 2` and `n_after > n_before`** —
placement must create or lengthen a ladder, so a no-op drop (a spare parked beside an
already-ready ladder) never glows. Bridging two clusters across a gap counts: the multisets
join, and the bridge piece may itself be a spare. Putting the piece back where it came from is
excluded by `d ≠ from`. Cost: ≤62 candidates × a local component walk — computed **once at
drag start**; the model is frozen during a drag.

**Recompute:** full re-scan in `_after_board_change()` (`board.gd:1011` — the single fan-out
after every board mutation; `_commit_move` / `_commit_swap` / `_stash` all end there) and after
`_rebuild_all`. 63 cells (`G.ROWS 9 × G.COLS 7`) — trivial; no caching, no dirty-tracking.
Pieces enter the model before their flight lands, so an outline can appear a beat before the art
settles — accepted, same as the quest-ready glow.

**Reuse contract for step 4:** the Magnet consumes `ready_ladders` (and will add its own
"what extends this ladder" query here, not in the scene); it must never glide the armed piece —
the scene exposes `chain_armed_cell()`. Mirror echoes bypass the chain seam entirely (R4).

## 6 · The outline — presentation

One new node, `engine/scripts/ui/cascade_outline.gd`, a single `board_area` child that draws
every detected component.

- **Layer:** child order is draw order (one canvas, no CanvasLayers — `overlay.gd:8`). Insert
  after the slot cells, before generators/pieces, via `move_child` (precedent:
  `_refresh_locked_cells`, `board.gd:2632`). No bare `z_index` literals (`layering_tests.gd`
  guard); no negative z (that would sink under the board mat).
- **Template:** `focus_ring.gd` — `@tool`, `@export` knobs, `_draw()` polylines — so the stitch
  look is tunable in the UI workbench.
- **Stitches:** the component's perimeter = every cell edge whose orthogonal neighbour is
  outside the component; drawn as short hand-marched dashes (nothing uses `draw_dashed_line`
  today; short segments with slight per-stitch jitter read as thread on cut paper), slightly
  inset, rounded caps. Static between board changes — the escalation is the animation.
- **Escalation:** stitch thickness + alpha step up with `n` — base at ×2, mid at ×3, full at
  ×4+ ("grows and brightens as the player extends the ladder").
- **Color:** the line's palette color. Add the missing accessor
  `G.line_color(code) -> Color` in `content.gd` (beside `item_name`), reading
  `G.LINES[line].color` with the `Pal.TEXT_MUTED` fallback (mirrors `piece_view.gd:297`).
  Never re-type a hex — `palette_ssot_tests` fails the build on role-value literals.
- **The ×n tag:** a small code-drawn paper chip (rounded panel + label, ink on cream, a trim of
  the line color) pinned to `top_cell`'s top-right corner. Stitches sit under the pieces; the
  tag must stay legible **above** them (own late-order child) and update on every recompute.
- **Geometry:** all placement through `_cell_pos` (`board.gd:1704`) — it owns the landscape
  transpose. No new art assets: stitches, tag, ghost pads and the FTUE diagram are all
  code-drawn/composited (§8 option B is the one exception, and it's optional).

**The drag guide.** On `_begin_drag` of an item (never a generator), the placement candidates
light up as stitched **ghost pads** — a dashed inset square per candidate cell, the same stitch
vocabulary, the line's color, brightness stepped by the resulting `n` (the same escalation
ramp). Drawn by the same node, under the pieces (the pads mark empty cells, so nothing covers
them but the floating drag itself). Cleared on every release outcome — the commit paths end in
`_after_board_change`'s recompute, and snap-back clears explicitly. The hover **telegraph**
(`_update_telegraph`, `board.gd:2695`) is a different verb — merge-target feedback on occupied
cells — and is untouched; pads live on empty cells only, so the two never collide.

## 7 · Rewards — every chain pays one reward, by its length

No per-step wallet credits, no daily gate (rev 2 Dev call). A chain's reward is a **board
piece born mid-chain that grows with it** — the chain chest.

| Chain reaches | Reward |
|---|---|
| ×2 | a **coin piece** is born (guaranteed; the 10 % lucky roll stays independent) |
| ×3 | the coin's moment is over — a **chest t1** is born (40 c on open) |
| ×4 | the born chest **upgrades in place** to t2 (120 c + 1 acorn) |
| ×5 | → t3 (320 c + 3 acorns), plus the `FX.burst` celebration |
| ×6+ | option A (recommended v1): stays t3 · option B: → t4, then t5 at ×7 (§8) |

All amounts are the existing `CHEST_OPEN_COINS` / `CHEST_OPEN_ACORNS` dials
(`grove_data.gd:365-366`) — the sim owns them.

- **Birth, hazard-free:** the qualifying merge just vacated its source cell `a` — the reward
  is born **exactly there**, synchronously, before the lucky rolls run. Always a free cell, no
  `pick_drop_cell` discard risk, no owed queue. Standard arc-in + land FX, no modal. The ×3
  chest replaces the ×2 coin's *slot in the table*, not the piece — the coin born at ×2 stays
  on the board as loot; the chest is born on the newly vacated cell of the ×3 merge.
- **Growth:** each further step swaps the chest's code up one tier in place (`board` model +
  re-rendered piece, a small pop FX + the ×n floater). Tracked by a session-local
  `_chain_chest_cell` that follows moves like the armed cell. If the player opens it, merges
  it away, or stashes it mid-chain, upgrades stop — they cashed out early, their call. A
  chain's end needs **no handling at all**: the chest already reflects the achieved length.
- **Ordinary piece (R5):** opened by the existing second-tap path (`_open_chest`,
  `board.gd:3393`, loot via `G.chest_open_reward`, `content.gd:1423`); mergeable with other
  chests — two ×3 chains leave two t1 chests, and merging them into a t2 pays more than
  opening both, which the chest's own desc already teaches (*"Merge first for a richer one"*).
- **Floater:** a plain "×n" per step `n ≥ 2` at the merge center (`FX.floating_text`,
  `fx.gd:330`), size stepping up with `n` — no coin amounts, since nothing hits the wallet
  mid-chain. The streak's milestone words (3/5/8) can coincide during a fast cascade — offset
  the floater; final placement is a workbench pass.
- **Economy:** every payout flows through chest-open → `Save.add_coins` / `add_diamonds` —
  spendable-only; `G.earn_coins` (the clock) is never touched (parent §7 law, spelled out at
  `save.gd:118-124`). Echo merges pay nothing (R4). **Rev 2 raises the stakes** from ≤ +8-coin
  steps to a chest per chain — recommend step 3 now joins the `grove_sim` re-pass list before
  merge (amends the parent §8, which gated only steps 2/4/5 — Dev call, §13 Q4).

## 8 · Extending the chest line (option B — only if ×6+ should keep paying)

- **Machinery: already built.** `SPECIAL_TOP := 3` is only the default ceiling — *"a def may
  override with `top`"* (`grove_data.gd:343-349`). Option B is data: `"top": 5` on the line-10
  def, plus `CHEST_OPEN_COINS`/`ACORNS` rows for 4/5 (dials — of the order 800 c + 6 and
  2000 c + 12; the sim decides). Ladder detection, outlines and `merge_top` all follow the
  override automatically (§5's chest example becomes ×3).
- **Art: does NOT exist yet.** Checked `items/chest/` (t1–t3), the 5×5 specials icon sheet
  (chests stop at t3 there too), and the archive — no t4/t5 chest anywhere in the tree. Option
  B therefore needs **two new pieces through the intake pipeline**
  (`docs/design/art-style-guide.md` scaffold; same cut-paper chest family, richer dressing per
  tier). Option A ships with zero new art, which is why it's the v1 recommendation; B can land
  later as pure data + art with no code change.

## 9 · FTUE

The first time a ready ladder exists, one cut-paper card, then the hand traces the tip-over.

- **Eligibility**, checked in `_after_board_change` when `animating` is false and no modal is
  open (`Overlay.is_open`): `Features.on("cascade")` · `Save.ftue_seen("merge")` (never teach
  cascades before the merge teach) · `not Save.ftue_seen("cascade")` · `ready_ladders`
  non-empty.
- **The card:** `Overlay.modal` (`overlay.gd:47`) + `Kit.dialog_frame`, mirroring
  `update_prompt.gd` (85 lines, kit loaded by path — `ui/` keeps no `games/` dep). Body: a tiny
  three-piece diagram (t·t·t+1 with an arrow — composite real item art of the mushroom line,
  the parent's own example) + one line — *"Merge the pair — the new piece lands by its match.
  Keep going."* — + one `pill_button` **Got it**. Copy in `strings.json` under
  `board.cascade.*` (`strings_tests` covers).
- **On dismiss:** `Save.mark_ftue_seen("cascade")` (`save.gd:344`, idempotent) → the outline is
  already lit → `HandHint.present(host, GESTURE_DRAG, pair_a_rect, pair_b_rect)`
  (`hand_hint.gd:57`; input-transparent, loops) traces the best ladder's pair merge. The hand
  ends at the next merge commit, or when a recompute finds the ladder gone.
- **Not** entered into `HandHint.next_hint_id`'s two-teach ordering — this is a one-shot nudge
  owned by the cascade wiring; the seen flag is the card's, set at dismissal, so nothing
  re-presents even if the hand is cut short.
- Idle-hint suppression rides the existing `_hint_pair` early-return while a hand hint is live.
- The flag rule: every FTUE ships behind a feature flag (rule N4) — covered by the one
  `cascade` flag; no separate FTUE flag.

## 10 · Scope: home board only

The Rush keeps its own combo, window, scoring and FTUE (`explore.gd` / `explore_rush.gd`) —
zero shared state with this feature. All cascade code lives in `board.gd`'s path plus
`board_logic.gd` statics, so no mode discriminator is needed (none exists today; `board.gd`
contains no Rush references).

## 11 · State & flags

- **Flag:** `"cascade": true` in `features.gd` (feature block) + a row in `docs/FEATURES.md`.
  OFF = today's behaviour exactly: no chain, no outlines, no ghost pads, no rewards, no FTUE —
  and the time-window streak is identical in both positions (R1 never touches it).
- **Save:** one touch — `ftue_seen["cascade"]` (existing dict, `save.gd:339-344`). **No
  `SCHEMA_VERSION` bump** — a bump discards saves wholesale. The chain chest is an ordinary
  board piece, persisted like any other by the normal board save.
- **Chain state** (`_chain_count`, `_chain_cell`, `_chain_chest_cell`) is scene-local,
  survives `_rebuild_all`, resets on board open, never saved.

## 12 · Verification

- **New engine suite** `engine/tests/cascade_tests.gd` (+ `ENGINE_TESTS`, `Makefile:11`),
  template `mechanics_tests.gd`'s `combo_step` block; the `test_base` printed format is a hard
  contract — don't reformat.
  - `chain_on_merge`: continue via `a`, via `b`; restart on a stranger merge; disarmed start;
    armed sentinel handling.
  - `ready_ladders`: minimal `t·t·t+1` → n 2; `+t4` → n 3; a gap kills the run; duplicate
    rungs don't extend; a stray lower singleton doesn't disqualify the component; the chest
    line caps at n 2 (`merge_top`); two components → two entries; empty board → none.
  - `chain_placements`: completing a pair+rung → candidate with n 2; lengthening an existing
    ladder → n+1; a spare beside an already-ready ladder → **not** a candidate; bridging two
    clusters across a gap → candidate; `d == from` excluded; a code with no same-line kin →
    empty; `merge_top` respected.
- **New grove suite** `games/grove/tests/grove_cascade_tests.gd` (+ `GROVE_TESTS`,
  `Makefile:15`, **and the project `CLAUDE.md` suite list line** — it must stay in step). Boot
  idiom from `grove_ftue_tests.gd:34-56` (real `Board.tscn`, `_settle()`, lookup by script).
  - Chain wiring: pair-then-result continues (`_chain_count` reads 2, armed on the result
    cell); a stranger merge restarts at 1; pop and delivery zero it; the armed cell follows
    `_commit_move`.
  - **Separation (R1):** two chain merges > 2.5 s apart → `_chain_count == 2` while
    `_combo_count == 1`; rapid stranger merges → `_combo_count` climbs while the chain keeps
    restarting at 1.
  - Rewards: ×2 births a coin piece on the vacated cell; ×3 births chest `1001` there; ×4
    upgrades that cell to `1002` in place; an early-opened chest stops upgrading; a second
    chain births a second chest; wallet and `coins_earned` (the clock — `G.level()`) both
    unchanged until a chest is opened, and opening credits `add_coins` only.
  - Guide: `_begin_drag` on a seeded board lights the expected pads; release clears them;
    dragging a generator lights nothing.
  - Outline: node present iff a ladder exists; the tag reads ×n; gone when the ladder is
    consumed.
  - FTUE: card presents once (mutate ledger + rebuild idiom); flag OFF → nothing.
- **Visual gate:** a quiet-godot capture of a board with a lit 3-rung ladder (stitches + tag),
  the ghost pads under a lifted piece, and a mid-chain floater — produced and **looked at**
  before the step is called done.
- `make test` green before merge.

## 13 · Open questions for Dev review

1. **R2 — craft merges continue chains** (and so grow the chain chest). Mirrors the parent
   §10 Q1 mastery law (crafts as productive use). Confirm, or keep crafts chain-neutral?
2. **The reward table (§7):** confirm the length→reward mapping, and pick **A** — cap at
   chest t3, zero new art (recommended v1) — or **B** — extend to t4/t5, which is pure data
   (`"top": 5` + two loot rows) **plus two new art pieces**: t4/t5 chest art does not exist
   anywhere in the tree (checked `items/chest/`, the 5×5 specials sheet, the archive).
3. **×2 pays a guaranteed coin piece.** Keep, or start rewards at ×3 and let ×2 be outline +
   floater only?
4. **Sim gate:** chests-per-chain is a bigger faucet than the old ≤ +8-coin steps — should
   step 3 join the `grove_sim` re-pass list before merge? (Recommended: yes.)
