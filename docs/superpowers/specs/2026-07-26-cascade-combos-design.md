# Cascade combos — design

Date: 2026-07-26 · Status: **draft rev 3, for Dev review** · Parent: `2026-07-26-progression-systems-design.md` §5/§8-step-3.
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
| `games/grove/assets/items/chest/chest_4/5.png` | **new** — placeholders (t3 copies) until intake art (§6) |
| `engine/scripts/core/features.gd` + `docs/FEATURES.md` | + `"cascade"` flag + row (§9) |
| `games/grove/tools/grove_shot.gd` | + seeded `cascade` capture mode (§12 step 7) |
| `engine/tests/cascade_tests.gd` · `games/grove/tests/grove_cascade_tests.gd` | **new** suites (§10) |
| `Makefile` + project `CLAUDE.md` | suite registrations (§10) |

## 2 · Rules

- **Only a player merge tips a run** — drag merge (`_commit_merge`) or recipe merge
  (`_apply_recipe`). Placements never auto-merge: moves, swaps, bag retrieves, pops, drops,
  starfall (step 5), soil harvests (step 4).
- **Step-4 cells** (Magnet range auto-merger; the Mirror is cut —
  `2026-07-26-cell-improvements-design.md` §5-6): its auto-merges neither tip nor extend runs,
  and it holds fire while a run executes. The scene exposes `chain_running() -> bool` as that
  gate (this replaces the `chain_armed_cell()` named in that spec's amendment — rev 3 has no
  armed state; a cascade is atomic).
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
  (flag-gated) and `_chain_n := 1`.
- After each merge resolves, if `_chain_run` is non-empty: pop the next partner, keep
  `animating` true, `board.merge(result_cell, partner)`, slide + standard merge-impact FX,
  `_chain_n += 1`, reward hook (§5), repeat. Step pace `CHAIN_STEP_MS ≈ 250`, a workbench knob.
- Per step ≥ ×2: a "×n" floater at the merge (`FX.floating_text`, `fx.gd:330`), size stepping
  up with n. `FX.burst` (`fx.gd:664`) at ×5. Offset from the streak's milestone words.

## 5 · Rewards

One reward per chain, by final length. Born mid-run on the cell the step just vacated — always
free, synchronously, before the lucky rolls.

| Chain reaches | Reward |
|---|---|
| ×2 | a coin piece is born |
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
  only; `G.earn_coins` (the quest clock) is never touched. Run `grove_sim` before merge
  (chests-per-chain + per-step lucky rolls are a bigger faucet than parent §5's coin steps).

## 6 · Chest line extension (option B — in scope)

- Data: `"top": 5` on the line-10 def (`SPECIAL_TOP` stays 3; per-def override already exists,
  `grove_data.gd:343-349`) + `CHEST_OPEN_COINS`/`ACORNS` rows `4:` and `5:`
  (`grove_data.gd:365-366`). Detection, outlines and `merge_top` follow automatically.
- Art: `items/chest/chest_4.png`, `chest_5.png` — **do not exist yet**; two new pieces through
  the intake pipeline (`docs/design/art-style-guide.md`), same cut-paper chest family, richer
  dressing per tier.

## 7 · Ready-ladder outline

- Node `engine/scripts/ui/cascade_outline.gd`, one `board_area` child. Insert after slot
  cells, before pieces (`move_child`; draw order = child order, no CanvasLayers). Template:
  `focus_ring.gd` (`@tool`, `@export` knobs, `_draw`).
- Per `ready_ladders` component: stitched dashes along the perimeter (cell edges whose
  neighbour is outside), slightly inset, rounded dash ends, per-stitch jitter, a whisper of
  warm shadow under each dash. Thickness + alpha step with n (×2 / ×3 / ×4+). Optional
  interior wash: a light line-color tint inside the group (`fill_pct` knob 0–8; the approved
  mock uses ~5). Redraw only on recompute — in `_after_board_change()` (`board.gd:1011`)
  and after `_rebuild_all`.
- Color: `G.line_color(code)` — **new accessor** in `content.gd` reading `G.LINES[line].color`,
  fallback `Pal.TEXT_MUTED` (mirrors `piece_view.gd:297`). No hex literals
  (`palette_ssot_tests`).
- ×n tag: small code-drawn paper chip on `top_cell`'s corner, above the pieces, updated per
  recompute.
- Geometry via `_cell_pos` (`board.gd:1704`, owns the landscape transpose).

## 8 · Drag guide

On `_begin_drag` of an item (never a generator): `chain_placements` once (the model is frozen
mid-drag); each candidate cell gets a stitched ghost pad — dashed rounded square, modest
inset, light interior tint (~8 %), line color, thickness + brightness step by resulting n.
Cleared on every release outcome. The merge telegraph (`_update_telegraph`) is untouched;
pads mark empty cells only.

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
  - A tipped t·t·t+1 auto-runs to ×2 with input locked, board state correct after.
  - Rewards: ×2 coin then ×3 chest `1001` on the vacated cells; ×4 upgrades that cell to
    `1002`; wallet and `coins_earned` unchanged until chest-open; open credits `add_coins`
    only.
  - Guide pads on `_begin_drag`, cleared on release; generator drag → none.
  - Outline present iff a ladder exists; tag text ×n.
  - Flag OFF → no chain, no outline, no pads.
- **Visual gate:** quiet-godot captures — lit ladder (stitches + tag), ghost pads under a
  lifted piece, a mid-run step with floater — looked at before done.
- `make test` green before merge.

## 11 · Open questions

1. ×2 pays a guaranteed coin piece — keep, or start rewards at ×3?
2. Auto-steps also roll the 10 %/2 % lucky drops (uniform-merge stance) — confirm, or should
   auto-steps skip them? The sim pass will quantify either way.

## 12 · Implementation directions (for the implementing agent)

**Workspace.** Branch `feat/cascade-combos` from latest `main` in a NEW worktree outside the
repo: `git worktree add /Users/xup/dh/merge-wt-cascade -b feat/cascade-combos` (in-repo
worktrees get wiped by other agents). Seed the import cache before the first run:
`rsync -a --delete /Users/xup/dh/merge/.godot/ /Users/xup/dh/merge-wt-cascade/.godot/`.
**Do not merge to main and do not remove the worktree** — implementation ends with the branch
committed in place; code review happens in the worktree.

**Order** — each step lands with its tests green (`make test-fast`, a few seconds) before the next:

1. `board_logic.gd`: `chain_path` + `ready_ladders` + `chain_placements` (§3); new
   `engine/tests/cascade_tests.gd` with the §10 engine battery; add the suite to `ENGINE_TESTS`
   (`Makefile:11`).
2. Chest extension (§6): `"top": 5` on the line-10 def + `CHEST_OPEN_COINS`/`ACORNS` rows 4/5;
   placeholder art — copy `items/chest/chest_3.png` to `chest_4.png` / `chest_5.png` (approved
   t4/t5 direction mocks exist; real art lands separately via the intake pipeline);
   `make import`.
3. Run executor + rewards in `board.gd` (§4, §5): `_chain_run` computed in `_commit_merge` /
   `_apply_recipe`, the step loop, ×n floater, ×5 burst, reward births/upgrades,
   `chain_running()`.
4. `engine/scripts/ui/cascade_outline.gd` + the `G.line_color(code)` accessor (§7).
5. Drag guide (§8).
6. `"cascade"` flag + `docs/FEATURES.md` row (§9); new
   `games/grove/tests/grove_cascade_tests.gd` with the §10 grove battery; add to `GROVE_TESTS`
   (`Makefile:15`) **and** the project `CLAUDE.md` suite-list line.
7. Evidence + regression: extend `grove_shot.gd` with a seeded, byte-deterministic `cascade`
   mode (a lit ladder + ghost pads + a mid-run frame) and save captures to
   `/tmp/cascade_*.png`; run
   `godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- 60 <seed>` for 3
   seeds — a structural regression (invariant Y, "the clock is quests only", must hold; the
   sim bot does not play cascades); full `make test` green. The hand-off summary lists suites
   run, capture paths, and the sim's Z faucet lines.

**Open-question defaults** (§11 — the Dev has not ruled; make each a one-line flip): ship the
§5 table as written (×2 coin included) as one `CHAIN_REWARDS` const table; auto-steps roll the
lucky drops, gated by one bool const.

**Repo rules that bite:**

- Do not touch `_bump_combo` / `combo_step` / the combo consts in `tuning.gd` / any Rush file
  (`explore*.gd`) — the streak must behave byte-identically with the flag ON.
- The mastery branch lifts `_apply_recipe` into `BoardActions.apply_recipe`; if that has landed
  on `main` before §4 wiring, hook the chain at the `board.gd` call site (the scene wrapper),
  never inside the lifted action.
- Engine code never references `games/` directly — colors via the new `G.line_color` only, and
  no new `Color("#…")` hex literals (`palette_ssot_tests` fails the build).
- No bare `z_index` integer literals (`layering_tests`) — child order or named consts.
- Don't reformat `test_base` output — the runner parses the `"  PASS"` lines and the footer.
- New `.gd` files: run `make import` before committing so `.uid` sidecars exist and are
  committed.
- Fast parse check: `godot --headless --check-only --script <file.gd>`; suites only via
  `make test-fast` / `make test` — a bare foreground `godot -s` run can hang a shell.
- Tests comparing Control positions/sizes use `is_equal_approx` (float32 truncation); headless
  runs dispatch notifications with `obj.notification(what)`, never `_notification()` directly.
