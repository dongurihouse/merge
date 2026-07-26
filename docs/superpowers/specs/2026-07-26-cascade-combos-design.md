# Cascade combos + ready-ladder outlines — design

Date: 2026-07-26
Branch: `spec/cascade-combos` (spec only — implementation is rollout **step 3** of the parent)
Status: **draft, for Dev review.**
Parent: `2026-07-26-progression-systems-design.md` §5 (chain rule, outlines, rewards, FTUE), §7
(economy laws), §8 step 3. This spec expands §5 to implementation grade. Where wording differs,
this spec wins — the deltas are listed in §2. All numbers remain provisional dials.

## 1 · Goal

Give the one merge verb a second layer of skill without adding a timer: a **chain** counts merges
that each consume the piece the previous merge just created; **ready-ladder outlines** show where
a chain is waiting; small **spendable coin bonuses** and a **once-per-real-day chest** reward the
tip-over; a **one-time FTUE** teaches it. Home board only — the Rush keeps its own combo.

Four deliverables in one Dev-given task: the chain rule (replacing the current time-window streak
on the home board), ladder detection + the stitched outline, rewards, cascade FTUE.

## 2 · What exists today, and corrections to the parent

The home board already has a merge streak — the cascade **re-cadences it** rather than adding a
second counter:

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

1. *"the existing merge-streak audio machinery in `board_logic`"* — only the pure cadence lives
   there. The escalation is **note selection** (a baked 10-note ladder; per-note pitch jitter is
   deliberately disabled, `audio.gd:71-84`), not a rising `pitch_scale`. The chain count drives
   the **same degree ladder**; nothing about the audio path changes.
2. *"a duplicated bottom"* is generalized to *any duplicated tier with consecutive rungs above*
   (§6) — a stray lower singleton adjacent to a real ladder must not kill its outline.
3. New ruling the parent didn't cover: **craft merges join the chain** (R2, §3).
4. New rule the parent didn't cover: the daily chest is **recorded only when it actually lands**
   (§8) — board drops are silently discarded on a full board today (`board.gd:3348-3351`).
5. *"confetti burst at ×5"* maps to `FX.burst` (`fx.gd:664`, the petal burst) — the repo has no
   separate confetti primitive, and doesn't need one.

## 3 · The chain rule

> A merge continues the chain only if it uses the piece the previous merge just created.
> Otherwise it starts a new chain. Pops and deliveries end the chain. Nothing else matters —
> rearrange and think as long as you like. No timer anywhere.

State, scene-local in `board.gd`: `_chain_count: int` and `_chain_cell: Vector2i` (the **armed**
cell — where the newest merge result sits; `(-1,-1)` = disarmed). Reset on board open; survives
`_rebuild_all` (cells are stable across view rebuilds); never saved.

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

- **R1 — replacement, not addition.** With the `cascade` flag ON, the chain count **is** the
  `combo` value: same variable, new cadence. Every existing consumer — note degree, milestone
  words, bloom — reads it unchanged. Flag OFF = today's 2.5 s window, byte-for-byte.
  `combo_step` stays (pure, tested, the OFF path); the Rush never changes.
- **R2 — craft merges are merges.** A recipe merge that consumes the armed piece continues the
  chain and re-arms on its product; one that ignores it restarts. Today `_apply_recipe` skips
  `_bump_combo` **and** the merge-impact FX entirely — an inconsistency; under the flag it
  reports to the chain and fires the same impact with the chain count. (Parallels the parent
  §10 Q1 mastery law: crafts are productive use. Dev confirm — §13 Q1.)
- **R3 — generator merges are housekeeping, not dominoes.** They produce a generator, not a
  board piece; neutral, as today (they never bumped the streak).
- **R4 — only player merge commits touch the chain.** The tracker is called from exactly two
  seams: `_after_merge` and `_apply_recipe`. Future automatic merges (Mirror echoes, step 4)
  bypass it by construction — the parent §7 "no chain credit, no combo coins" law needs no
  guard code.
- **R5 — every mergeable line participates uniformly**, coins, chests and specials included
  (they merge like anything else — `can_merge`, `board_model.gd:305`). A coin ladder can
  cascade; the daily chest is an ordinary chest piece. No special cases.

## 4 · Pure seams — `board_logic.gd`

Three statics beside `combo_step`; the scene keeps the two fields and the one-line
follow/disarm updates at the handlers named in §3.

```gdscript
# Chain cadence: prev+1 when the merge uses the armed cell, else 1.
static func chain_on_merge(prev_count: int, armed: Vector2i, a: Vector2i, b: Vector2i) -> int

# Coins for reaching chain count n: 0 below ×2, else min(1 << (n - 2), 8).
#   ×2 +1 · ×3 +2 · ×4 +4 · ×5 +8 · every step past ×5 +8 flat.
static func chain_bonus(n: int) -> int

# §6 detection. [{ "cells": Array[Vector2i], "line": int, "n": int, "top_cell": Vector2i }]
static func ready_ladders(board: BoardModel) -> Array
```

The swap point, sketched (`_after_merge` passes its `a`/`b`; `_apply_recipe` calls the same):

```gdscript
func _bump_combo(a: Vector2i, b: Vector2i) -> int:
    if Features.on("cascade"):
        _chain_count = BoardLogic.chain_on_merge(_chain_count, _chain_cell, a, b)
        _chain_cell = b
        return _chain_count
    # legacy: the 2.5 s window (combo_step) — unchanged, flag-OFF path
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
the t3 pair-step would need tier 3 < `SPECIAL_TOP` 3 and stops (`merge_top` cap, R5).

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
  transpose. No new art assets: stitches, tag, and the FTUE diagram are code-drawn/composited.

## 7 · Rewards

- Per chain step `n ≥ 2`: `Save.add_coins(BoardLogic.chain_bonus(n))` — the spendable wallet
  (`save.gd:156`), **never** `G.earn_coins` (`save.gd:171` — the clock is quests only; parent
  §7 law, spelled out in `save.gd`'s own comment).
- **Floater:** one per step at the merge center, carrying both the multiplier and the gain
  (`FX.floating_reward`, `fx.gd:369`, coin icon, prefix `"×%d · +"`; if that composite reads
  badly, `floating_text` "×n" + a coin floater slightly offset — implementer's call). Size
  steps up with `n`. At n = 3/5/8 the milestone word also fires (`combo_words` cue) — offset
  the floater so the two never overlap; final placement is a workbench pass.
- **×5:** `FX.burst` at the merge center, scaled up. The word at 5 ("Lovely") now lands on a
  real cascade.
- **HUD:** the wallet chip refresh already rides `_update_hud()` inside `_after_board_change`.
- **Economy guard:** no `grove_sim` re-pass needed for step 3 (the parent §8 gates only steps
  2/4/5): bonuses are spendable-only, and a ×n chain consumes ~2^(n−1) pieces whose production
  cost (water, pops) dwarfs +8-coin steps — self-limiting by construction. Echo merges pay
  nothing (R4).

## 8 · The daily chest

Once per **real day**, the first chain to *reach* ×5 drops a small chest.

- **The chest is ordinary:** the existing tier-1 chest piece (line 10, code `1001` — 40 coins
  on open, `CHEST_OPEN_COINS`, `grove_data.gd:365`; dial is the sim's). It drops near the ×5
  merge cell through the existing path — `_drop_special_near` (`board.gd:3348`), standard
  arc-in + land FX, **no modal** — and, being ordinary, can be merged richer before opening
  (the starfall philosophy).
- **Day key:** the codebase's single convention — UTC unix-day, via the claim ledger. Reuse
  `Save.claim_can_show("cascade_chest", 1, 0.0)` / `Save.claim_record("cascade_chest")`
  (`save.gd:433` / `:453`): free day rollover, no schema change, existing test-backdating
  idiom (`grove_shop_tests.gd:116`).
- **Land-then-record.** `_drop_special_near` silently discards when no ground is open
  (`pick_drop_cell` returns `(-1,-1)`, `board_logic.gd:170`) — so the claim is recorded **only
  when the chest actually lands.** On a qualifying ×5: if `claim_can_show` and a cell exists →
  drop + `claim_record`. Board full → set session-local `_chest_owed`; every
  `_after_board_change` retries while owed; record on landing. Session ends still owed →
  nothing recorded, the next ×5 re-arms. No dupes: record-on-land, owed cleared on land.
- Reaching ×6/×7 in the same chain does not re-trigger; a later ×5 chain can, if the day's
  chest is still unclaimed.

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
  OFF = today's behaviour exactly: time-window streak, no outlines, no coins, no chest, no FTUE.
- **Save:** nothing new in the schema — `ftue_seen["cascade"]` (existing dict,
  `save.gd:339-344`) and `claim_ledger["cascade_chest"]` (existing additive grove-blob path).
  **No `SCHEMA_VERSION` bump** — a bump discards saves wholesale.
- **Chain state** is scene-local, survives `_rebuild_all`, resets on board open, never saved.

## 12 · Verification

- **New engine suite** `engine/tests/cascade_tests.gd` (+ `ENGINE_TESTS`, `Makefile:11`),
  template `mechanics_tests.gd`'s `combo_step` block; the `test_base` printed format is a hard
  contract — don't reformat.
  - `chain_on_merge`: continue via `a`, via `b`; restart on a stranger merge; disarmed start;
    armed sentinel handling.
  - `chain_bonus`: the full table 0 · 0 · 1 · 2 · 4 · 8 · 8 · 8.
  - `ready_ladders`: minimal `t·t·t+1` → n 2; `+t4` → n 3; a gap kills the run; duplicate
    rungs don't extend; a stray lower singleton doesn't disqualify the component; the chest
    line caps at n 2 (`merge_top`); two components → two entries; empty board → none.
- **New grove suite** `games/grove/tests/grove_cascade_tests.gd` (+ `GROVE_TESTS`,
  `Makefile:15`, **and the project `CLAUDE.md` suite list line** — it must stay in step). Boot
  idiom from `grove_ftue_tests.gd:34-56` (real `Board.tscn`, `_settle()`, lookup by script).
  - Chain wiring: pair-then-result continues (`_chain_count` reads 2, armed on the result
    cell); a stranger merge restarts at 1; pop and delivery zero it; the armed cell follows
    `_commit_move`.
  - Coins: wallet delta equals `chain_bonus`; `coins_earned` (the clock — `G.level()`)
    unchanged.
  - Outline: node present iff a ladder exists; the tag reads ×n; gone when the ladder is
    consumed.
  - FTUE: card presents once (mutate ledger + rebuild idiom); flag OFF → nothing.
  - Chest: first ×5 lands a chest **and** records the claim; a second ×5 the same day is dry;
    a backdated ledger day re-arms it; a full board records nothing and the owed chest lands
    on the next free cell.
- **Visual gate:** a quiet-godot capture of a board with a lit 3-rung ladder (stitches + tag)
  and a mid-chain floater — produced and **looked at** before the step is called done.
- `make test` green before merge.

## 13 · Open questions for Dev review

1. **R2 — craft merges continue chains and earn combo coins.** Mirrors the parent §10 Q1
   mastery law (crafts as productive use). Confirm, or keep crafts chain-neutral?
2. **Day boundary is UTC unix-day** (the codebase's only daily convention). Fine, or is the
   daily chest worth local-midnight machinery the repo doesn't have yet?
3. **Chest size: tier-1** (40 coins on open). Or seed it at tier-2 (120) since ×5 is rare?
