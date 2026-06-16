# Board decomposition — breaking up `scenes/board.gd`

Status: in progress — **Wave 1 shipped 2026-06-15**. Implements within the layering
invariant (`merge_spec.md` §15). Companion to the engine layering split already shipped
for `core/` / `ui/` / `scenes/`.

## Problem

`engine/scripts/scenes/board.gd` is a 2621-line, 109-function God-scene
(`extends Control`). It holds ~12 distinct responsibilities at once: the board
grid (pieces / brambles / generators), drag-drop + merge/move/swap, the
quest-giver fence, merchant / basket / porter, HUD / water / wallet, bag, the
generator-burst coin sink, the FTUE spotlight, state persistence, the discovery
ladder, bust/sprite helpers, and lifecycle glue. It is hard to hold in context,
hard to test, and changes to one subsystem risk the others.

Goal: break it into focused, independently understandable units **without a new
architectural layer and without behaviour change**, addressing all four drivers
(editability, testability, isolation, hygiene) in de-risked waves.

## Constraints (do not violate)

1. **Layering invariant (`merge_spec.md` §15):** imports may only flow
   `scenes/ → ui/ → core/`. `core/` imports neither `ui/` nor `scenes/`; `ui/`
   never imports `scenes/`. Enforced headless by `engine/tests/layering_tests.gd`.
   Every new module obeys this; extracted components live in `ui/` and must never
   import `board.gd`.
2. **`ui/` already supports both shapes** — no new layer needed:
   - *Stateless builder*: `extends RefCounted` + `static build(host, opts) -> Dictionary`
     returning node refs and closures (e.g. `ui/hud.gd`, `ui/ambient.gd`).
   - *Stateful component Control*: `extends Control` + a `static` factory
     (e.g. `ui/spotlight_overlay.gd` → `static present(host, target, …, on_done := Callable())`).
   Components talk **upward only via injected `Callable`s / emitted signals**, the
   same seam `spotlight_overlay` already uses.
3. **RNG order is load-bearing.** The rng is seeded and persisted; spawn/refill
   call order must be preserved exactly (see `core/board_logic.gd` `roll_spawn`).
   Any extraction touching spawning/refilling must not reorder `rng` calls.
4. **Save schema is frozen.** `_persist()` writes a fixed key set
   (`board`, `quests`, `quests_zone`, `bag`, `rng_state`, `water`, `refills_used`,
   `regen_ts`, `last_seen`). Extraction must not change what is written or read.
5. **No behaviour change.** This is a structural refactor. Visuals and gameplay
   must be byte-for-byte equivalent (verified by composite/measure, never eyeball).
6. **Edits to `board.gd` are sequential within a wave** (they touch one file, so
   parallel worktrees would conflict). New independent `core/` and `ui/` files in
   the same wave may be authored in parallel worktrees, merged before the
   `board.gd` rewire step.

## Architecture decision: coordinator owns state, components are views

**Approved seam.** The coordinator (`scenes/board.gd`) owns the mutable run-state
— the `BoardModel`, `bag`, `basket`, `quests`, `water`, drag state — and **all
transactions**. Components are *views + input*: they render the data they are
handed and emit *intents*; they never mutate shared state directly.

Why: in a merge game many systems read the board (quests check payability, the
merchant reads top-tier cells, the bag stashes from it) and one action fans out
to several (a merge can drop a coin → wallet; a delivery grants currency + may
fire a spotlight; a sell frees a cell → un-dims the generator + relights givers).
Keeping every transaction in one place stops those cross-effects from smearing
across components and prevents inter-component coupling.

**The fan-out contract.** Today the same post-mutation cluster recurs verbatim in
`_sell_item`, `_on_merchant_tap`, `_buy_back`, etc.:

```
_persist(); _update_hud(); _refresh_giver_lights(); _refresh_generator_dim()
```

Wave 3 consolidates this into one coordinator method, `_after_board_change()`,
called after **any** board mutation regardless of which component triggered it. It
persists, then fans out `refresh()` to every board-dependent component (grid dim,
fence lights, hud). This is the contract the components depend on; they emit an
intent and trust the coordinator to apply + refresh.

```
  ┌────────────────────────── scenes/board.gd (coordinator) ──────────────────────────┐
  │  owns: BoardModel, bag, basket, quests, water, drag-state                          │
  │  owns: transactions (_commit_merge/move/swap, _grant_sale, _deliver_*, _buy_back)  │
  │  owns: lifecycle (_ready/_process), water tick, winback, gate cue, spotlight orch. │
  │  on intent → mutate model/Save → _after_board_change() → fan out refresh()         │
  └───▲────────────▲────────────▲────────────▲────────────▲───────────────────────────┘
      │ intents     │            │            │            │   (signals / injected Callables up)
   ┌──┴───┐     ┌───┴────┐   ┌───┴─────┐  ┌───┴─────┐  ┌───┴────────┐
   │ grid │     │ fence  │   │merchant │  │bag_view │  │ burst_chip │   ui/ components (Control)
   └──┬───┘     └───┬────┘   └───┬─────┘  └───┬─────┘  └───┬────────┘
      │ build/render via static builders (down only)      │
   ┌──┴───────────────┐  ┌──────┴───┐                ┌─────┴────┐
   │ ui/piece_view.gd │  │ ui/bust  │   …            │ ui/hud   │   ui/ builders (RefCounted)
   └──────────────────┘  └──────────┘                └──────────┘
      │ pure rules (down only)
   ┌──┴──────────────┐  ┌─────────────┐  ┌──────────────┐
   │ core/board_logic│  │ core/quests │  │ core/content │   core/ (stateless)
   └─────────────────┘  └─────────────┘  └──────────────┘
```

## Target module map

| Module | Layer | Shape | Receives | Status |
|---|---|---|---|---|
| `core/board_logic.gd` | core | statics | model/data in | extend: `openable_for_hint` |
| `core/quests.gd` | core | statics | grove dict, `board.gens`, rng | **new** |
| `ui/piece_view.gd` | ui | builder | `(code, size)` etc. | **new** (~550) |
| `ui/bust.gd` | ui | builder | `(which, px)` | **new** (~80) |
| `ui/grid.gd` | ui | Control | model + render calls; emits merge/move/swap/stash/tap | **new** (~450) |
| `ui/fence.gd` | ui | Control | quests + render; emits deliver/ask | **new** (~450) |
| `ui/merchant.gd` | ui | Control | basket + render; emits sell/buyback/treat | **new** (~350) |
| `ui/bag_view.gd` | ui | Control | bag + render; emits tap | **new** (~120) |
| `ui/burst_chip.gd` | ui | Control | level/cost; emits buy | **new** (~80) |
| `scenes/board.gd` | scenes | coordinator | — | shrinks to ~400 |

## Wave 1 — logic to `core/` (smallest; calibration note below)

The pure rules are **mostly already in `core/`** (`content.gd`: `sell_reward`,
`burst_upgrade_cost`, `gate_quest`, `gen_quest`, `active_giver_count`,
`zone_cheapest_spot`, `frontier_zone`, …; plus `board_logic.gd`). What remains in
`board.gd` is Save-reading + rng orchestration glue, not trapped computation. So
Wave 1 is deliberately modest:

- **Move** `openable_for_hint` (already a pure `static`) → `core/board_logic.gd`.
- **Add `core/quests.gd`** — the fence-composition decision, made testable by
  taking state as params instead of reading `Save`/`rng` ambiently. Pure-ish
  statics mirroring `board_logic`:
  - `meter_target(grove, zone, level) -> int`
  - `gate_pending(grove, zone) -> bool`, `map_done(grove) -> bool`,
    `gate_ready(grove, zone, level) -> bool`
  - `pending_grant_quests(grove, board_gens) -> Array`
  - `refill(quests, grove, board_gens, zone, level, rng) -> Array` (preserves rng
    order — load-bearing)
  - `ladder_entries(seen, line) -> Array`
  - `quest_stars/coins/gems(q) -> int`
  `board.gd` keeps thin wrappers that read `Save`/`board.gens` and delegate.
- Net `board.gd` shrink: ~60–80 lines. Primary payoff is **testability**
  (`quest_tests.gd` can exercise fence composition headless).

**Gate:** `layering_tests.gd` green; new cases for `core/quests.gd`; `smoke.gd` green.

**SHIPPED 2026-06-15.** `openable_for_hint` moved to `board_logic.gd` (`hint_tests.gd`
repointed — it no longer preloads the 2621-line scene). New `core/quests.gd` (88 lines,
11 pure statics: `zone`, `map_done`, `gate_pending`, `meter_target`, `gate_ready`,
`pending_grant_quests`, `refill`, `ladder_entries`, `stars`/`coins`/`gems`); board.gd's
11 instance methods collapsed to one-line delegations (signatures unchanged, so
`gate_unveil_tests` / `grove_tests` callers are untouched). New cases landed in a
dedicated `engine/tests/quest_fence_tests.gd` (23 cases) rather than appended to
`quest_tests.gd`, so the existing suite stayed green throughout RED. board.gd 2621 → 2581.
Verified: full engine suite green (incl. `layering` 32→34, `quest_fence` 23, `mechanics`
50, `gate_unveil` 29, `smoke` OK) + `grove_tests` 282, zero script errors.

**Parked (discovered):** `games/grove/tools/grove_sim.gd` has its own `_refill_quests` /
`_gate_pending` — a divergent simulation fork (own `live_quests`/`zone` state, no grant
branch). It could delegate to `core/quests.gd`, but that needs a decision (should the sim
mirror prod's fence composition exactly, grant quests included?), so it's left for the Dev
to pull, not auto-changed.

## Wave 2 — leaf view builders to `ui/` (biggest single line win)

Construction only; state stays in `board.gd`. These are self-contained builders
taking explicit params (no hidden instance reads).

- **`ui/piece_view.gd`** — `_make_piece`, `_make_bramble`, `_make_generator`,
  `_make_board_mat`, `_bramble_mat`, `_backing_tex`, `_mini_item`, and both shader
  consts (`BRAMBLE_WARM_SHADER`, `MAT_MASK_SHADER`). `board.gd` calls
  `PieceView.make_piece(code, size)` etc. (~550 lines out — the single biggest
  reduction; callers include `_rebuild_pieces`, `_buy_back`, `_rebuild_basket`).
- **`ui/bust.gd`** — `_bust`, `_bust_layer` (giver/merchant portrait builder).

**Gate:** `smoke.gd` green; **visual composite check** (headless real-renderer per
the project's no-eyeball rule) proving pieces / brambles / generators / busts
render pixel-identical before vs after.

**REASSESS HERE** before Wave 3. With Waves 1–2 done, `board.gd` is ~1900 lines
and all construction lives in `ui/`. Confirm the component seam still fits the
code as it actually reads before the stateful surgery.

## Wave 3 — stateful component Controls to `ui/` (the isolation payoff)

Each cluster becomes an `extends Control` component (the `spotlight_overlay`
precedent) owning its own subtree, node dicts, input, and `render`/`refresh`
methods. It emits intents upward; the coordinator owns state + transactions and
calls `_after_board_change()` to fan refreshes back out.

| Component | Owns (view) | Emits (intent) | Coordinator applies |
|---|---|---|---|
| `ui/grid.gd` | `board_area`, piece/bramble/gen node dicts, drag/input | `merge_requested(a,b)`, `move(a,b)`, `swap(a,b)`, `stash(cell)`, `sell(cell)`, `tap(cell)`, `gen_burst(cell)` | mutate `BoardModel`, maybe coin drop, `_after_board_change()` |
| `ui/fence.gd` | `giver_bar`, stands, bob, lights, gate stand | `deliver(qi)`, `ask_tapped(qi)` | grant currency / unlock, spotlight, refill, `_after_board_change()` |
| `ui/merchant.gd` | merchant chip, basket chip, sell affordance, porter timer | `sell_top()`, `buyback(idx)`, `buy_treat()` | pay wallet, record sale, `_after_board_change()` |
| `ui/bag_view.gd` | bag slots | `slot_tapped(i)` | place/stash, `_after_board_change()` |
| `ui/burst_chip.gd` | the coin-sink pill | `buy()` | spend, bump `burst_lvl`, refresh |

`scenes/board.gd` becomes the coordinator: builds the layout shell (the `_ready`
VBox: spacer → chapter ribbon → fence slot → grid slot → bag slot, plus gate
button, bottom bar, HUD), instantiates each component into its slot, owns
run-state + transactions + lifecycle (`_process`, water tick, winback, gate cue,
spotlight orchestration), and wires intents → transactions → `_after_board_change()`.
Target ~400 lines.

**Gate:** full suite green (`layering`, `quest`, `gate_unveil`, `ftue_pop`,
`gendim`, `featured`, `floater`, `spotlight`, `save`, `smoke`); visual composites
for grid / fence / merchant; one scripted play-through smoke (spawn → merge →
deliver → sell → buy-back → gate).

## Non-goals / risks

- **Not** refactoring `map.gd` (the sibling 1388-line scene) in this effort,
  though `ui/bust.gd` / shared HUD glue may later DRY both. Out of scope here.
- **Not** changing save schema, rng order, tuning values, or any visual.
- Risk: a component needs state the coordinator owns mid-frame → resolve by the
  coordinator pushing data into `render(data)`, never the component reaching up.
- Risk: drag state spans grid + bag + merchant (drag a piece to the stall to
  sell). The drag *gesture* lives in `grid`; the *drop target resolution* (sell
  vs stash vs swap) is an intent the coordinator routes. Keep gesture in grid,
  routing in the coordinator.

## Verification summary

Run headless after every step (never eyeball):

```
godot --headless --path . -s res://engine/tests/layering_tests.gd
godot --headless --path . -s res://engine/tests/smoke.gd
# plus the suite relevant to the wave (quest_tests, gate_unveil_tests, …)
```

Visual gates use the project's minimized real-renderer composite capture
(`override.cfg` no-focus trick), comparing before/after — not a human glance.
