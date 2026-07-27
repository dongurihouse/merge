# Cascade combos — design

Date: 2026-07-26 · Status: **SHIPPED** · Parent: `2026-07-26-progression-systems-design.md` §5/§8-step-3.
Supersedes the parent §5 wording: chains auto-execute — the parent's break rules ("any pop, any
delivery…") and §6's "nothing ever merges by itself" clause are obsolete. All numbers are
provisional dials; the sim owns finals.

## 1 · What it is

A player merge **tips a cascade**: if the result lines up with adjacent matches, the follow-up
merges run **by themselves**, one hop at a time. One algorithm finds the longest run; the UI
follows it. Chain length pays one reward — a chest that grows with the run. Ready ladders get a
stitched outline; dragging a piece shows where placing it would build a chain — the guide IS
the teach (no FTUE dialog). Home board only; the Rush is untouched.

**What gets built:**

| File | Change |
|---|---|
| `engine/scripts/core/board_logic.gd` | + `chain_path` · `ready_ladders` · `chain_placements` (§3) |
| `engine/scripts/scenes/board.gd` | + run executor, rewards, `chain_running()`, drag-guide wiring (§4–5, §8) |
| `engine/scripts/ui/cascade_outline.gd` | **new** — stitched outlines, ×n tags, ghost pads (§7–8) |
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
  gate. There is no `chain_armed_cell()` state; a cascade is atomic.
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
# { cells, line, n, top_cell }
#   n        = best chain over every in-component tip-over (direction matters)
#   top_cell = the best run's final landing cell (anchors the ×n tag)
static func ready_ladders(board: BoardModel) -> Array

# Drag guide: empty ground cells (≠ from) where placing `code` raises the joined
# component's best chain to ≥ 2 and above its prior value. [{ cell, n }]
static func chain_placements(board: BoardModel, from: Vector2i, code: int) -> Array
```

Direction matters: merging A onto B lands the result at B, so only partners adjacent to B
continue the run — `ready_ladders` computes n over both tip-over directions. Longest beats
greedy: with two adjacent partners, the DFS must take the one whose onward neighbours extend
the run.

## 4 · Run execution — `board.gd`

- `_commit_merge` / `_apply_recipe` compute `_chain_run := BoardLogic.chain_path(board, a, b)`
  (flag-gated). `_prepare_chain` arms only if `1 + _chain_run.size() >= CHAIN_MIN_N`; otherwise
  it clears the run and the merge ends normally.
- Before the first automatic step, `_schedule_chain_step` holds for `CHAIN_PREROLL_MS` (`300`) and
  `_show_chain_preroll` pulses the exact run cells with the ×n tag. Input remains locked during
  the pre-roll.
- After each merge resolves, if `_chain_run` is non-empty: pop the next partner, keep
  `animating` true, `board.merge(result_cell, partner)`, slide + standard merge-impact FX,
  `_chain_n += 1`, reward hook (§5), repeat. Step pace `CHAIN_STEP_MS = 250`.
- Per step ≥ ×2: a "×n" floater at the merge (`FX.floating_text`, `fx.gd:330`), size stepping
  up with n. `FX.burst` (`fx.gd:664`) at ×5. Offset from the streak's milestone words.

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

- Node `engine/scripts/ui/cascade_outline.gd`, one `board_area` child. The scene passes only
  `ready_ladders` entries with `n >= CHAIN_MIN_N`, so a ×2 ladder draws nothing.
- Stack invariant: the outline child index must sit above every slot/mat node and below every
  live piece/generator (`move_child`; draw order = child order, no CanvasLayers). Exclude
  queued-for-deletion nodes from the computation because `queue_free` is deferred; the guard is
  `grove_cascade_tests.gd`'s stack assertion with stale generator nodes present. Template:
  `focus_ring.gd` (`@tool`, `@export` knobs, `_draw`).
- Per `ready_ladders` component: stitched dashes along the perimeter (cell edges whose
  neighbour is outside), slightly inset, rounded dash ends, per-stitch jitter, a whisper of
  warm shadow under each dash. Thickness + alpha step with n (×2 / ×3 / ×4+). Optional
  interior wash: a light line-color tint inside the group (`fill_pct` knob 0–8; the approved
  mock uses ~5). Redraw only on recompute — in `_after_board_change()` (`board.gd:1011`)
  and after `_rebuild_all`.
- Color: `G.line_color(code)` reads `G.LINES[line].color`, fallback `Pal.TEXT_MUTED`
  (mirrors `piece_view.gd:297`). No hex literals (`palette_ssot_tests`).
- ×n tag: small code-drawn paper chip on `top_cell`'s corner, above the pieces, updated per
  recompute.
- Geometry via `_cell_pos` (`board.gd:1704`, owns the landscape transpose).

## 8 · Drag guide

On `_begin_drag` of an item (never a generator): `chain_placements` once (the model is frozen
mid-drag); each candidate cell gets a stitched ghost pad — dashed rounded square, modest
inset, light interior tint (~8 %), line color, thickness + brightness step by resulting n.
The scene keeps only placements with `n >= CHAIN_MIN_N`, so ×2 placements draw no pads. Cleared on
every release outcome. The merge telegraph (`_update_telegraph`) is untouched; pads mark empty
cells only.

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
    extend; stray singleton doesn't disqualify; n is direction-aware; two components → two
    entries.
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
  - Outline present iff an armed ladder exists; tag text ×n; stack index above mat/slots and below
    live items, with stale queued-for-deletion generator nodes present.
  - Flag OFF → no chain, no outline, no pads.
- **Visual gate:** quiet-godot `cascade` captures — lit ladder (stitches + tag), `phase=guide`
  ghost pads under a lifted piece, a mid-run step with floater — looked at before done.
  `phase=guide` needs a ×3-capable fixture; ×2 placements exit 0 with a bare board because the
  scene filters out pads that would not arm a cascade.
- `make test` green.

## 11 · Open questions

1. Auto-steps also roll the 10 %/2 % lucky drops (uniform-merge stance) — confirm, or should
   auto-steps skip them? The sim pass will quantify either way.
