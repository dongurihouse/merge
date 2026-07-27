# Item fly-away — design

Date: 2026-07-27 · Status: **draft 1**

## 1 · What it is

Pieces leaving the board **fly to the wallet** instead of vanishing on rebuild. One primitive serves
both removal paths: the §8 farewell sweep (many pieces at once, currently unanimated) and a single-item
sell (currently a short straight hop clipped inside `board_area`). The arriving piece IS the payout —
it lands on the currency pill, the pill pulses, `+N` pops there, and the counter ticks. The line's
generator does not fly: it is kept, not sold, so it gets its own in-place gesture.

**What gets built:**

| File | Change |
|---|---|
| `engine/scripts/ui/fx.gd` | + `fly_piece_to` · `fly_pieces_away` · `keepsake_fade` (§2) · `"farewell_sweep"` in `REWARD_FX_IDS` (§6) |
| `engine/scripts/core/tuning.gd` | + the `PIECE_FLY_*` / `SWEEP_*` / `KEEPSAKE_*` dials (§3) |
| `engine/scripts/scenes/board.gd` | `_grant_sale` rewrite (§4) · `_sweep_farewell` reorder (§5) |
| `games/grove/tools/fx_workbench_view.gd` | + `farewell_sweep` preview action (§8) |
| `games/grove/tools/grove_shot.gd` | + `flyaway` capture mode, mid-flight frames (§8) |
| `engine/tests/fx_flight_tests.gd` | **new** suite (§7) |
| `Makefile` + project `CLAUDE.md` + `README.md` | suite registration (§7) |

Out of scope: the bag-stash path keeps its own animation. No new art — the flight reuses the live
piece sprites.

## 2 · The primitive

```gdscript
static func fly_piece_to(host: Control, node: Control, to_chip: Control,
        opts: Dictionary = {}, then: Callable = Callable()) -> void
static func fly_pieces_away(host: Control, flights: Array, to_chip: Control,
        opts: Dictionary = {}, then_each: Callable = Callable(),
        all_done: Callable = Callable()) -> void
static func keepsake_fade(node: Control, then: Callable = Callable()) -> void
```

`fly_piece_to`:
1. Reparent `node` to `host`, preserving global position. Set `z_index = Tune.FLY_Z`.
   Reparenting is load-bearing — a piece left in `board_area` is clipped at the board edge, which is
   why today's sell hop stays inside the board and cannot arc.
2. Two-leg arc, matching `fly_to_wallet` (fx.gd:575): to `mid = (from + dest)/2 + PIECE_FLY_ARC` over
   `PIECE_FLY_T_UP` (`TRANS_QUAD`/`EASE_OUT`), then to `dest` over `PIECE_FLY_T_DOWN` (`EASE_IN`),
   with `scale → PIECE_FLY_SCALE` in parallel on the second leg.
3. `dest` = `to_chip.get_global_rect().get_center()`, or `from + Tune.FLY_FALLBACK` when `to_chip`
   is null or invalid.
4. On arrival: `then.call()`, then `node.queue_free()`.

`opts` keys, all optional — an empty dict means "use the §3 dials":

| Key | Type | Default |
|---|---|---|
| `fx_id` | `String` | `""` — when non-empty, `reward_fx_enabled(fx_id)` gates the flight (§7) |
| `arc` | `Vector2` | `PIECE_FLY_ARC` |
| `scale` | `Vector2` | `PIECE_FLY_SCALE` |
| `t_up` / `t_down` | `float` | `PIECE_FLY_T_UP` / `PIECE_FLY_T_DOWN` |

`fly_pieces_away` owns stagger and nothing else. `flights` is an `Array` of
`{"node": Control, "payout": int}`. Launch spacing is
`min(SWEEP_STAGGER, SWEEP_STAGGER_CAP / max(1, flights.size()))` — the cap holds the total launch
window flat so a twelve-piece sweep does not run three times as long as a four-piece one. Each
landing calls `then_each.call(payout)`; `all_done` fires after the last.

`keepsake_fade` is the generator's gesture: lift by `KEEPSAKE_LIFT`, `scale → KEEPSAKE_SCALE` and
`modulate:a → 0` over `KEEPSAKE_T`, with one `FX.burst` at the node centre, then free. No flight, no
destination — the generator pays no coins (`farewell_preview` sums `G.sell_reward(code).x` over
items only, board_actions.gd:264) and its best tier/boost is preserved in `gen_kept`.

## 3 · Dials

Provisional; tune in the workbench (§8). Siblings of the existing `FLY_*` block (tuning.gd:220-226).

| Dial | Value | Note |
|---|---|---|
| `PIECE_FLY_T_UP` | `0.20` | vs `FLY_T_UP` 0.18 — a piece is larger, reads slower |
| `PIECE_FLY_T_DOWN` | `0.26` | vs `FLY_T_DOWN` 0.22 |
| `PIECE_FLY_ARC` | `Vector2(0, -140)` | vs `FLY_ARC` (0,-110) — more lift to clear the board |
| `PIECE_FLY_SCALE` | `Vector2(0.30, 0.30)` | ends near pill-icon size |
| `SWEEP_STAGGER` | `0.06` | per-piece launch spacing |
| `SWEEP_STAGGER_CAP` | `0.90` | total launch window ceiling |
| `KEEPSAKE_T` | `0.45` | |
| `KEEPSAKE_LIFT` | `Vector2(0, -18)` | |
| `KEEPSAKE_SCALE` | `Vector2(0.55, 0.55)` | |

## 4 · Sell path — `_grant_sale` (board.gd:6335)

Replaces the inline tween at 6159-6165 and the `reward_arrival` coin/gem flight at 6170/6175.

1. Credit the model first, unchanged: `Save.add_coins(reward.x)` / `Save.add_diamonds(reward.y)` +
   `Vault.skim`.
2. Target pill: `diamonds_label` when `reward.y > 0`, else `coins_label`.
3. `FX.fly_piece_to(self, node, target, {}, on_arrive)` under the existing `"sale_payout"` FX id.
4. `on_arrive` → the §6 arrival beat with the amount that applies (`reward.y` gems, else `reward.x`).

`_after_board_change(true)` still defers the HUD; the arrival callback owns the tick.

## 5 · Sweep path — `_sweep_farewell` (board.gd:6245)

Ordering change. Today: model sweep → `_rebuild_all()` frees the nodes, so nothing can fly.

1. **Before** the model call, collect the nodes to animate.
   - Items: scan `board.items` for `code > 0 and not G.is_coin(code) and BoardModel.line_of(code) == line`
     — the same predicate `sweep_line` uses (board_actions.gd:294), because `farewell_preview` returns
     item *counts*, not item cells. For each hit take `piece_nodes[BoardModel.cell_of(i)]` and record
     `G.sell_reward(code).x` as that flight's payout.
   - Generators: the nodes at `farewell_preview(...).gen_cells`.
   - **Erase every collected cell from `piece_nodes`** so the rebuild neither frees nor re-lays them.
2. `BoardActions.sweep_line(board, line)` — model truth, unchanged, still `Save.add_coins(coins)` up
   front.
3. `FX.keepsake_fade` on each generator node; `FX.fly_pieces_away(self, flights, coins_label, {},
   on_each, on_all)` on the item nodes, under the new `"farewell_sweep"` FX id.
4. `_rebuild_all()` immediately — the board settles underneath while the detached pieces are still in
   flight above it.
5. `_after_board_change(true)`; `on_all` does the final `_update_hud()`.

The `retired` write, the `gen_kept` merge and `_queue_farewell_check_after_frame()` are untouched.

## 6 · The arrival beat

Per landing: pulse the target pill (`FX.breathe_once`), `FX.floating_reward` at the pill for `+N`,
and advance the displayed counter.

The counter is **paced, not recomputed**. `sweep_line` banks the whole total up front, so calling
`_update_hud()` on the first arrival would snap the full amount. Instead `_sweep_farewell` declares a
local `var shown := Save.coins() - coins` (the pre-sweep displayed value) captured by the arrival
closure; each `on_each(payout)` does `shown += payout` and `FX.tick(coins_label, shown)`
(fx.gd:553). `on_all` then calls `_update_hud()` to reconcile to the true save value. The model is
never paced — only the display.

## 7 · Failure behavior

**Invariant: the player is paid exactly once, whether or not anything animates.**

Every one of these skips the flight, frees the node, and fires the arrival callback immediately —
never twice, never zero times:

- the FX id is disabled (`reward_fx_enabled("farewell_sweep")` / `("sale_payout")` false)
- `Features.on("fly_to_wallet")` is false
- `host` is null, freed, or not inside the tree
- `node` is null or already freed
- `to_chip` is null or freed → `FLY_FALLBACK` destination, flight still runs

`host` is held by `weakref` and re-validated on every arrival, matching `reward_arrival`
(fx.gd:634).

### Tests — `engine/tests/fx_flight_tests.gd` (new)

1. `fly_pieces_away` with N flights calls `then_each` exactly N times and `all_done` exactly once —
   asserted with FX enabled, with the id disabled, with `fly_to_wallet` off, and with a freed host.
   **This is the no-stranded-coins guarantee and the suite's reason to exist.**
2. `fly_piece_to` reparents to `host` and preserves global position across the reparent
   (`is_equal_approx`, not `==` — Control geometry is float32).
3. Stagger honours the cap: launch spacing for 12 flights is `SWEEP_STAGGER_CAP / 12`, not
   `SWEEP_STAGGER`.
4. `keepsake_fade` frees the node and fires `then` once.

### Tests — existing suites

5. `grove_board_actions_tests._test_farewell_sweep` stays green unchanged (model untouched).
6. New grove case: `_sweep_farewell` credits exactly `farewell_preview(...).coins` with the FX id on
   AND off, and `piece_nodes` holds no entry for the swept line afterwards.
7. New grove case: `_grant_sale` credits the same coins/gems with FX on and off.

Register the new suite in `ENGINE_TESTS` (Makefile), project `CLAUDE.md` and `README.md` together —
`engine/tests/suite_registry_tests.gd` fails when the three disagree.

## 8 · Visual gate

A single frame cannot verify motion. Both are required before the task is done:

- `fx_workbench_view.gd`: a `farewell_sweep` preview action that spawns N dummy pieces and runs the
  batch, so the dials in §3 are tunable without reaching L33.
- `grove_shot.gd`: a `flyaway` capture mode seeded from `G.zone_unlock_level(3)` — **seed from the
  symbolic accessor, never a literal level** — capturing frames mid-flight (launch, apex, arrival) so
  the arc, the stagger and the keepsake gesture are all inspectable. Look at the output; a mode that
  renders a plain board has silently rotted.
