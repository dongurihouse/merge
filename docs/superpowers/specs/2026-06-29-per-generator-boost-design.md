# Per-generator boost — design

Date: 2026-06-29

## Problem

Buying the temporary generator boost (the info-bar boost chip on a tapped generator)
arms a **board-wide** bonus: every generator sparkles, every generator tap draws the
bonus, and the count ticks down on any tap. This is intentional today — the boost is a
single global counter (`Save.grove()["boost_taps"]`) read by every generator — but it
reads as a bug: the buy button lives inside one generator's info bar, so the player
expects the boost to apply to **that** generator only, not all of them.

## Goal

Make the boost apply to a single, chosen generator. Each generator carries its own boost.

## Decisions (locked with the user)

1. **Stackable per-generator.** Several generators can be boosted at once, each with its
   own remaining-taps counter. The "no re-buy while live" rule becomes per-generator:
   you cannot re-buy on an already-boosted generator, but you can boost a different one.
2. **Merge combines the taps.** When two generators merge (2:1 → survivor gains a tier),
   the survivor's boost taps = source taps + target taps. No boost is wasted, and which
   generator was dragged onto which does not matter.
3. **Move carries the boost.** Relocating a generator carries its boost with it.
4. **Sell / spent clears the boost.** A sold generator, or a bonus generator that
   vanishes when spent, loses its boost.
5. **Bag carries the boost.** Storing a boosted generator into the bag keeps its remaining
   taps; re-placing it restores them (a parallel bag array, mirroring `gen_bag_tiers`).
6. **Free charge spent on the board.** The map-3 free boost charge is no longer armed from
   the map screen. The board boost chip shows "Free" when a charge is in stock and spends a
   charge instead of coins, targeting the selected generator like a paid boost. The map
   screen's "Use boost" button is removed.
7. **Cost / magnitude unchanged.** `BOOST_COST`, `BOOST_TAPS`, `BOOST_BONUS` keep their
   current values. Stacking is the new capability; each purchase is an independent coin
   sink. Rebalance later from playtest if needed.

## Architecture

The per-generator boost **state** lives in `BoardModel` (`engine/scripts/core/board_model.gd`)
as data that rides alongside `gens` and `gen_tiers`, reusing the exact mutation seams that
already keep `gen_tiers` correct. `content.gd` keeps the boost **constants**. `board.gd`
orchestrates purchase, taps, and the on-board indicator through the new `BoardModel` API.
`Habitat` owns the free-charge stock. `map.gd` loses the Use-boost button.

Rejected alternatives:
- **State in the `grove` save blob.** `board.gd` would have to manually re-sync the boost
  at every generator mutation (move / merge / sell / store / place) — many fragile sync
  sites, away from the data they mutate.
- **Global counter + a single boosted cell.** Cannot represent stacking (decision 1).

### Ownership boundaries

| Unit | Owns |
|------|------|
| `BoardModel` | Per-cell + per-bag boost state and its mutation rules (move/merge/sell/store/place); serialization. Unit-testable with no scene. |
| `content.gd` | Boost constants: `boost_cost()`, `boost_bonus()`, `BOOST_TAPS`. |
| `Habitat` | Free-charge stock (`boost_charges`) and spending one charge. |
| `board.gd` | Orchestration: purchase chip, charged-tap consume, bonus-gen collect, on-board indicator. |
| `map.gd` | (removal) the map-screen Use-boost affordance. |

## Data model — `BoardModel`

New state, parallel to the existing generator dictionaries (`gens`, `gen_tiers`,
`gen_bag`, `gen_bag_tiers`):

- `gen_boost: Dictionary` — cell → remaining taps (absent / 0 = not boosted).
- `gen_bag_boost: Array` — PARALLEL to `gen_bag`: remaining taps of each stored generator.
  Invariant: `gen_bag_boost.size() == gen_bag.size()`.

New methods:

- `gen_boost_at(cell) -> int` — remaining taps at a cell (0 if absent).
- `is_gen_boosted(cell) -> bool` — `gen_boost_at(cell) > 0`.
- `arm_gen_boost(cell, taps) -> void` — set the cell's taps (the purchase / free-charge arm).
- `consume_gen_boost(cell) -> void` — decrement; `erase` at 0 (never underflows; no-op if absent).

### Mutation rules (wired into existing seams)

- `move_gen(from, to)` (board_model.gd:132): carry — `gen_boost[to] = gen_boost_at(from)` (only if > 0), `gen_boost.erase(from)`.
- `merge_gens(from, to)` (board_model.gd:147): combine — `gen_boost[to] = gen_boost_at(to) + gen_boost_at(from)` (only if the sum > 0), `gen_boost.erase(from)`.
- `remove_gen(cell)` (board_model.gd:163): clear — `gen_boost.erase(cell)`.
- `store_gen(cell)` (board_model.gd:85): move into the bag — append `gen_boost_at(cell)` to `gen_bag_boost`, `gen_boost.erase(cell)`.
- `place_gen_from_bag(id, cell)` (board_model.gd:95): restore — read the bagged boost at the same index used for the tier, set `gen_boost[cell]` (only if > 0), remove the bag entry.
- `place_gen(id, cell, tier)` (board_model.gd:173) / `seed_gens` / `grow_gens`: no boost (a fresh generator starts unboosted).
- `bag_add(id, tier)` (board_model.gd:110): gains a `boost := 0` default param and appends to `gen_bag_boost` so the parallel arrays stay aligned.
- `prune_bag(should_keep)` (board_model.gd:120): rebuild `gen_bag_boost` alongside `gen_bag` / `gen_bag_tiers` so all three stay aligned.

### Serialization (board_model.gd:375 `to_dict` / 387 `from_dict`)

- Each generator entry already serializes as `[row, col, id, tier]`. Append boost as the
  **5th element**: `[row, col, id, tier, boost]`. `from_dict` reads index 4 when present;
  4-element legacy entries → boost 0.
- `gen_bag_boost` serializes as a parallel array beside `gen_bag` / `gen_bag_tiers`
  (key `"gen_bag_boost"`); absent in old saves → all 0.

## `content.gd` (engine/scripts/core/content.gd:643–690)

- Keep `boost_cost()` (646), `boost_bonus()` (650), and `BOOST_TAPS` (54).
- Remove the global state seam now superseded by per-cell state in `BoardModel`:
  `boost_taps_left()` (654), `boost_active()` (658), `try_activate_boost()` (663),
  `arm_boost_free()` (675), `consume_boost_tap()` (684), and the `grove["boost_taps"]` key.
- Audit callers of each removed function and re-point them at the `BoardModel` API (see
  Touchpoints). The burst-odds helper (`burst_count`, content.gd:627) is unchanged — it
  already takes the bonus as a parameter.

## Purchase flow — `board.gd`

- `_on_burst_chip()` (board.gd:1922): target `_selected_cell`.
  - Refuse (soft wobble) if `board.is_gen_boosted(_selected_cell)` — this generator is
    already boosted (other generators stay buyable).
  - If `Habitat.boost_charges() > 0`: spend a free charge (`Habitat.spend_boost_charge()`),
    no coins. Else require `Save.coins() >= G.boost_cost()` and `Save.spend(BOOST_COST, "boost")`.
  - `board.arm_gen_boost(_selected_cell, G.BOOST_TAPS)`, then `_persist()`.
  - Light the indicator for that cell; juice the selected generator (existing FX at 1936–1941).
- `_refresh_burst_chip()` (board.gd:~1900): chip label shows "Free" when
  `Habitat.boost_charges() > 0`, else the coin cost. Faded when the **selected** generator
  is already boosted (per-generator), not when any boost is live.
- `_activate_gen_boost()` (board.gd:2689): folded into `_on_burst_chip` (the coin/charge
  decision and the per-cell arm now live there) or reduced to a thin `board.arm_gen_boost`
  call. No longer delegates to the removed `G.try_activate_boost`.

## Free charge — `Habitat` (engine/scripts/core/habitat.gd:312–330) and `map.gd`

- Add `Habitat.spend_boost_charge() -> bool`: decrement one charge if `boost_charges() > 0`,
  persist, return whether one was spent. Does NOT arm a boost (board.gd arms the cell).
- `use_boost_charge()` (habitat.gd:324) is removed (it armed the global boost via the
  removed `Content.arm_boost_free`).
- `map.gd`: remove the "Use boost (N)" button and its `_on_use_boost()` handler
  (map.gd:1285–1290, 1728–1736). `boost_charges()` is still minted by the map-3 reward; it
  is now spent on the board.

## Tap / consume flow — `board.gd`

- Charged generator tap (`_pop_seed`, board.gd:~2520 and 2585–2590): replace the global
  `G.boost_active()` / `_gen_boost_bonus()` / `G.consume_boost_tap()` with the cell's own
  state — bonus = `G.boost_bonus()` if `board.is_gen_boosted(cell)` else 0; after a boosted
  tap, `board.consume_gen_boost(cell)` and refresh the indicator.
- `_gen_boost_bonus()` (board.gd:2683): takes a `cell` and returns `G.boost_bonus()` when
  that cell is boosted, else 0.
- Bonus-generator collect (board.gd:~3040–3074): `boosted := board.is_gen_boosted(cell)`
  (the bonus generator's own cell); on a boosted collect, `board.consume_gen_boost(cell)`
  and refresh.

## On-board indicator — `board.gd` (`_refresh_boost_indicator`, board.gd:1311)

Already iterates every generator cell. Per cell: read `t := board.gen_boost_at(cell)`; if
`t > 0` show the sparkle + taps badge ("%d" % t); else clear both. The existing
`owns_badge` rule (a bonus/treat generator shows its own count badge in that corner, so the
boost badge is suppressed there while the boost still applies) is unchanged.

## Migration

- Old generator entries (4 elements) → boost 0; missing `gen_bag_boost` → all 0.
- A legacy save with a live global `grove["boost_taps"] > 0`: the board-wide boost ends on
  update (the key is dropped). Acceptable one-time loss of a temporary effect across an update.

## Testing (TDD)

`BoardModel` unit tests (no scene, fast):
- arm sets taps; consume decrements and erases at 0; consume on an unboosted cell is a no-op.
- `move_gen` carries the boost; `merge_gens` sums both generators' taps; `remove_gen` clears.
- `store_gen` moves the boost into `gen_bag_boost`; `place_gen_from_bag` restores it; the
  three bag arrays stay aligned through `bag_add` and `prune_bag`.
- `to_dict`/`from_dict` round-trip the per-cell and per-bag boost; a 4-element legacy
  generator entry and a save with no `gen_bag_boost` both read as 0.

Flow tests (extend the existing boost tests in
`games/grove/tests/grove_economy_tests.gd` and `games/grove/tests/grove_residents_tests.gd`,
which reference the removed global seam):
- Buying a boost on generator A leaves generator B unboosted; a second buy on B is allowed
  while A is live (per-generator re-buy).
- A charged tap on a boosted generator gets the bonus and decrements that generator's
  counter; a tap on a non-boosted generator gets no bonus.
- With a free charge in stock, the purchase spends a charge and no coins; with none, it
  spends coins.

## Out of scope

- Rebalancing `BOOST_COST` / `BOOST_TAPS` / `BOOST_BONUS` (revisit from playtest).
- Any change to the burst-odds tables or the Expedition "Load out" boosters (a separate,
  correctly per-id feature).
