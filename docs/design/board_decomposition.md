# Board decomposition — breaking up `scenes/board.gd`

Status: in progress — **Waves 1–2 shipped 2026-06-15**; Wave 3 pending reassess. Implements within the layering
invariant (`merge_spec.md` §15). Companion to the engine layering split already shipped
for `core/` / `ui/` / `scenes/`.

**Vocabulary note (2026-06-15):** a later repo-wide rename swept `zone → map`
(`G.ZONES`→`G.MAPS`, `frontier_zone`→`frontier_map`, `zone_done`→`map_spots_done`,
`zone_cheapest_spot`→`map_cheapest_spot`, `_quest_zone`→`_quest_map`, the save key
`quests_zone`→`quests_map`, and `core/quests.gd` `zone()`→`current_map()`). The Wave 1/2
history below keeps its original `zone` wording; read it as today's `map`.

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
   (`board`, `quests`, `quests_map`, `bag`, `rng_state`, `water`, `refills_used`,
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
| `core/board_logic.gd` | core | statics | model/data in | **shipped**: `openable_for_hint` |
| `core/quests.gd` | core | statics | unlocks/gates, `board.gens`, stars, level, rng | **shipped** (88) |
| `ui/piece_view.gd` | ui | builder | `(code, size)`, `(cell, csz)`, board dims | **shipped** (340) |
| `ui/bust.gd` | ui | builder | `(which, px)` | **shipped** (66) |
| `ui/grid.gd` | ui | Control | model + render calls; emits merge/move/swap/stash/tap | Wave 3 (~470 today) |
| `ui/fence.gd` | ui | Control | quests + render; emits deliver/ask | Wave 3 (~580 today) |
| `ui/merchant.gd` | ui | Control | basket + render; emits sell/buyback/treat | Wave 3 (~340 today) |
| `ui/bag_view.gd` | ui | Control | bag + render; emits tap/buy-slot/drag | Wave 3 (~175 today) |
| `ui/burst_chip.gd` | ui | Control | level/cost; emits buy | Wave 3 (~74 today) |
| `scenes/board.gd` | scenes | coordinator | — | 2621 → 2316 now → ~450 target |

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

**SHIPPED 2026-06-15.** New `ui/bust.gd` (66 lines: `make`/`layer`) and
`ui/piece_view.gd` (340 lines: `make_piece`, `make_board_mat`, `make_bramble`,
`make_generator`, `bramble_mat`, `backing_tex`, `mini_item`, both shaders + caches).
Instance state became explicit params (`csz`, board dims); `tr()` → static-safe
`TranslationServer.translate()` (no translations loaded → identical output).
Realization vs plan: board.gd KEEPS thin instance wrappers (e.g. `_make_piece(c,s)
→ PieceView.make_piece(c,s)`) rather than rewiring ~20 call sites — `grove_tests`
calls `_make_piece` externally, and the wrappers let one montage tool render the
same API before/after. Only the ~300 lines of construction bodies moved. board.gd
2581 → 2225. New gate tool `engine/tools/board_montage.gd` (deterministic widget
montage via the real renderer). Verified: before/after montage **byte-identical**
(sha e091780a), full engine suite green (layering 34→36, smoke OK, mechanics 50) +
grove_tests 282, zero script errors. Note: the montage runs base art (grove `.ctex`
imports absent in this checkout), so the real-sprite `load()` branches are covered
by smoke, not the pixel-diff — they are trivial verbatim lines.

**REASSESS HERE** before Wave 3. After Waves 1–2 `board.gd` is **2225 lines** (was
2621), with quest composition in `core/` and all view construction in `ui/`. Before
the stateful surgery, confirm the component seam (coordinator owns state +
transactions; components are views emitting intents) still fits the code as it reads.

### Reassess outcome (2026-06-15, worktree off `91d15c3`)

Done — the seam holds against the code as it reads today. Three findings:

1. **board.gd is now 2471 lines, not 2225.** Since Wave 2, T43 (`dac167a`, out-of-water
   monetization) added ~155 lines to the **water/HUD** area — `_first_visible_refill`,
   `_on_ad_refill`, `_on_oow_offer`, `_grant_oow_offer`, `_open_oow_confirm` (rewarded-ad
   refill + IAP offer + confirm dialog). This is **coordinator residue** (or a future
   `ui/` offer-card builder), NOT one of the five components — the five are structurally
   unchanged. T39 (drag-only selling) and T41 (6→18 bag model) also landed and are
   reflected in the merchant/bag counts below.

2. **Coupling map drives the order** (measured attach points + interaction modes):
   - **fence** (`giver_bar`→`root`): tap-driven (`_on_giver_tap`), reads the board only
     for payability lights, **no drag**. Fully decoupled from the drag system.
   - **merchant** (stand): selling is **drag-only** (T39) — the *grid* detects the drag
     onto the stall (`_on_release`→`_sell_item`, `_show_sell_affordance`). View coupled to
     grid drag events.
   - **bag** (`bag_bar`→`root`): owns its **own** drag system (`_input`/`_on_bag_slot_input`/
     `_end_bag_drag`) dropping onto board cells — crosses into grid coords.
   - **burst** (`burst_chip`→`board_area`): **grid-internal** — positioned via `_cell_pos`/
     `csz`; `_gen_burst_level()` is also read by the grid's `_pop_seed`. Not a standalone peer.
   - **grid**: the core — originates every drag, hosts burst.

3. **Revised order: fence → merchant → bag → grid (+ burst folded in).** (The original
   plan's implicit "small-first = burst" is wrong — burst is grid-internal.) Fence first
   because it is the *only* component fully decoupled from the drag system, so it carries
   zero entanglement with the thorniest cross-cut. Grid last because it owns the drag
   gesture that bag/merchant drops resolve against; `burst_chip` rides with grid.

**Fence in two slices** (cleanest boundary, but ~580 lines):
- **Slice 1 — giver-stand builder** → `ui/giver_stand.gd`: lift the construction
  (`_make_giver_stand`/`_ask_pill`/`_featured_ribbon`/`_ready_check`/`_dock_check`) to a
  Wave-2-style stateless builder taking injected `Callable`s for the ask-tap (`_open_ladder`)
  and stand-tap (`_on_giver_tap`). Low-risk; gate = giver-stand visual composite + full suite.
- **Slice 2 — fence controller** → `ui/fence.gd` (Control): owns `giver_bar`, bob, lights,
  `_active_quest_idx`/`_rebuild_givers`/`_refresh_giver_lights`; emits `deliver(qi)`. The
  coordinator keeps the delivery transactions (`_deliver_grant`/`_deliver_gate`), quest
  state, refill, gate-cue, and `_after_board_change()`.

## Wave 3 — stateful component Controls to `ui/` (the isolation payoff)

Each cluster becomes an `extends Control` component (the `spotlight_overlay`
precedent) owning its own subtree, node dicts, input, and `render`/`refresh`
methods. It emits intents upward; the coordinator owns state + transactions and
calls `_after_board_change()` to fan refreshes back out.

**Current inventory (measured 2026-06-15 in worktree off `91d15c3` — board.gd = 2471
lines, 117 funcs, 54 vars).** After Waves 1–2 the view *construction* is gone; what
remains is the coordinator spine plus the stateful subsystems below. The five subsystems
are ~65% of the file and are what Wave 3 extracts; the rest is coordinator residue that
stays (and grew by the T43 OOW cluster — see Reassess outcome).

| Cluster → component | ~lines today | Key functions today |
|---|---|---|
| **fence** → `ui/fence.gd` | ~580 | `_rebuild_givers`, `_make_giver_stand` (119), `_ask_pill`/`_featured_ribbon`/`_ready_check`/`_dock_check`, `_giver_bob*`, `_giver_is_payable`, `_refresh_giver_lights`, `_on_giver_tap`, `_deliver_grant`, `_deliver_gate`, gate-cue, thin quest wrappers |
| **grid** → `ui/grid.gd` | ~470 | `_rebuild_all`/`_rebuild_pieces`, `_on_press`/`_on_release`/`_release_gen`/`_snap_back`, `_pop_seed` (71), `_commit_merge`/`_after_merge`/`_commit_move`/`_commit_swap`, `_open_bramble`, `_drop_coin_near`/`_collect_coin`, `_refresh_generator_dim`, `_hint_pair`, cell helpers |
| **merchant** → `ui/merchant.gd` | ~340 | `_make_merchant_stand` (104), `_buy_treat`, sell-affordance (`_show`/`_hide_sell_affordance`, `_swap_tag_icon`, `_note_item_landed`), `_sell_item`/`_grant_sale`/`_record_sale`/`_buy_back`/`_rebuild_basket`, porter (`_porter_collect`/`_porter_tick`/`_play_porter`) |
| **bag** → `ui/bag_view.gd` | ~175 | `_bag_capacity`/`_bag_has_buy_slot`, `_stash`/`_retrieve_from_bag`, `_buy_bag_slot` (💎 slot), `_build_bag_bar`/`_rebuild_bag`, `_on_bag_slot_input`/`_end_bag_drag` (drag-to-place), `_drain_shop_pieces` |
| **burst** → `ui/burst_chip.gd` | ~74 | `_gen_burst_level`/`_upgrade_gen_burst`, `_rebuild_burst_chip`/`_refresh_burst_chip`, `_on_burst_chip_input`/`_try_buy_burst` |

**Stays in the coordinator (~600 today → ~450 target):** `_ready` (the 186-line scene
assembly), `_process`, state + persistence (`_load_state`/`_persist`/`_mark_seen`/
`_apply_regen`), HUD/water wiring (`_build_hud`/`_build_water_hud`/`_update_hud`/water
tick), FTUE spotlight orchestration, the discovery ladder (`_open_ladder`), the gate
button (`_on_gate`), and the transaction + signal-wiring glue.

> **The bag grew since Wave 2.** An external feature added 💎 slot-buying + drag-to-place
> (`_buy_bag_slot`, `_build_bag_bar`, `_retrieve_from_bag`, `_end_bag_drag`, `_input`,
> `_bag_has_buy_slot`), pushing board.gd **2225 → 2316**. Fresh evidence the file is still
> a magnet — each subsystem wants its own home, and `bag_view` is now meatier than first
> estimated (~120 → ~175).

| Component | Owns (view) | Emits (intent) | Coordinator applies |
|---|---|---|---|
| `ui/grid.gd` | `board_area`, piece/bramble/gen node dicts, drag/input | `merge_requested(a,b)`, `move(a,b)`, `swap(a,b)`, `stash(cell)`, `sell(cell)`, `tap(cell)`, `gen_burst(cell)` | mutate `BoardModel`, maybe coin drop, `_after_board_change()` |
| `ui/fence.gd` | `giver_bar`, stands, bob, lights, gate stand | `deliver(qi)`, `ask_tapped(qi)` | grant currency / unlock, spotlight, refill, `_after_board_change()` |
| `ui/merchant.gd` | merchant chip, basket chip, sell affordance, porter timer | `sell_top()`, `buyback(idx)`, `buy_treat()` | pay wallet, record sale, `_after_board_change()` |
| `ui/bag_view.gd` | bag slots + buy-slot pill | `slot_tapped(i)`, `buy_slot()`, `drag_to(cell)` | place/stash/retrieve, spend 💎, `_after_board_change()` |
| `ui/burst_chip.gd` | the coin-sink pill | `buy()` | spend, bump `burst_lvl`, refresh |

`scenes/board.gd` becomes the coordinator: builds the layout shell (the `_ready`
VBox: spacer → chapter ribbon → fence slot → grid slot → bag slot, plus gate
button, bottom bar, HUD), instantiates each component into its slot, owns
run-state + transactions + lifecycle (`_process`, water tick, winback, gate cue,
spotlight orchestration), and wires intents → transactions → `_after_board_change()`.
Target ~450 lines.

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
