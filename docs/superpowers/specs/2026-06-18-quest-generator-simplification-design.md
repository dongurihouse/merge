# Quest + generator simplification — design

**Date:** 2026-06-18
**Branch:** `worktree-quest-simplify`
**Status:** design, pending implementation

## Goal

Simplify the quest system so a quest **always asks for exactly one item from one line**, and
rework the generator economy so **generators persist** instead of being consumed by a hand-in.
The two are coupled: persistence is what lets us delete the multi-item gate ask and redefine the
hand-in quest into a no-input "claim your generator" beat.

## Motivation

- The ask shape is polymorphic (`asks: [{line, tier, count}, …]`) but only the gate quest ever
  used more than one ask, and `count` was 1–2. The flexibility is unused complexity spread across
  generation, payability, fulfillment, and UI.
- The hand-in model *consumes* an old generator to grant a new one (`gen_grant`), which means a
  player permanently loses tools and old lines retire. For a cozy collection/restoration game this
  is loss-averse and off-genre. Letting generators persist fits the fantasy and removes the need
  for an item-less "hand-in" — generators just arrive.

## Quest model — three types

All quests lose the `asks` array. The required item (when there is one) is stored flat.

| Type | Asks for | Shape (after) |
|------|----------|---------------|
| Regular | one item, one line | `{line, tier, reward, featured}` |
| Gate | one item, one line, ceiling tier | `{line, tier, gate: true, reward}` |
| Grant | nothing — claims a generator | `{grant: {grants: id}, reward: {stars: 1, coins: 0}}` |

### Accessor

Replace `content.gd:quest_asks(q) -> Array` with:

```gdscript
static func quest_item(q: Dictionary) -> Dictionary:
    if q.has("line"):
        return {"line": int(q.line), "tier": int(q.tier)}
    if q.has("asks") and not q.asks.is_empty():   # tolerate a stale pre-change save
        return {"line": int(q.asks[0].line), "tier": int(q.asks[0].tier)}
    return {}                                      # a grant quest has no item
```

The three call sites that scan *all* quests — `board_logic.wanted_lines`, `board_logic.wanted_tiers`,
and the anti-monotony `avoid` loop in `quests.refill` — call `quest_item(q)` and `continue` on an
empty dict. This matches today's behavior, where a grant quest's empty `asks: []` made those loops
a no-op.

### Reward math (single tier)

`count` is gone (always 1), so reward is a function of one tier:

```gdscript
static func quest_expected_clicks(tier: int) -> float:
    return pow(2.0, tier - 1) / avg_pop_value()

static func quest_reward(tier: int) -> Dictionary:
    var value := int(round(quest_expected_clicks(tier) * CLICK_TO_VALUE))
    return {"stars": clampi(value, 1, STAR_CAP), "coins": maxi(0, value - STAR_CAP)}
```

### Generation

- `gen_quest(level, live_lines, rng, avoid)` drops the `count` roll and the `QUEST_2COUNT_RATE`
  dependency. Returns `{line, tier, reward, featured}`. Featured logic (coin/gem bonus, never extra
  ★) is unchanged.
- `gate_quest(roster, map, rng)` picks **one** line (randomized from the map's roster; `rng == null`
  → the single richest line) at the ceiling tier `min(GATE_TIER_BASE + map, TOP_TIER)`. Returns
  `{line, tier, gate: true, reward: {stars: GATE_STARS, coins: quest_reward(tier).coins + GATE_COIN_BONUS}}`.
  The **redundant top-level `stars`** is dropped (every consumer reads `reward.stars`).

### Payability + fulfillment

- `board_logic.quest_payable(board, q)` becomes a single presence check:
  `board.count_of(line * 100 + tier) >= 1`.
- `board.gd:_on_giver_tap` and `_deliver_gate`: no loops — take one item of `line*100+tier`, animate it.

## Generators persist

The hand-in machinery retires entirely:

- **content.gd:** remove `gen_grant`, `gen_can_grant`, `grant_map`, `surplus_gen_ids`. The
  `grant_from` field loses its lineage meaning; `gen_cell_of` no longer walks a lineage (each
  generator owns its `cell`). `anchor_lines` and the anchor exemption in `askable_lines` are removed.
- **board_model.gd:** remove `grant_gen`, `place_surplus_gen`, `grow_surplus_gens`. `seed_gens` /
  `live_gen_state` / `set_active_gens` stay as **tool/test helpers** (sim, shot) that place a map's
  generators directly, but the **live board no longer auto-seeds** (see Arrival).
- **askable_lines = current map only.** `askable_lines(roster, map, level)` returns
  `lines_for_map(roster, map, level)` — no anchor union. Old-map lines are never quested; the
  existing newest-line bias keeps the fence on recent content. Old generators stay usable for
  selling and the collection ladder.

## The bag's generator section

- New persisted field `gen_bag: Array` of generator id strings, alongside the existing item `bag`.
  Soft cap 100 (effectively unlimited; guards a runaway).
- **Owned generators** = `board.gens.values()` ∪ `gen_bag`. This is the set used to decide which
  grant quests are still pending.
- **BagOverlay** grows a second region below the item-slot ladder: the generator section, one tile
  per id in `gen_bag`, each draggable onto the board.
- **Interactions:**
  - Drag a board generator onto the bag well → move its id from `board.gens` into `gen_bag` (frees
    the cell). Reuses the existing "dragged onto bag" drop resolution in `_on_release`.
  - Drag a generator from the section onto an open cell → move its id from `gen_bag` into
    `board.gens` at that cell.
  - A generator in `gen_bag` does not produce. Generators are never sellable (the merchant only
    buys item spares).

## Arrival flow — the redefined grant quest

A generator is **claimable** when: its map is open, the player's level ≥ its `appear_level`, and it
isn't owned yet. That surfaces a **grant quest** leading the fence.

- `content.gd:grant_quests_for_map(roster, map)` emits one grant quest **per generator of the map**,
  regardless of `grant_from` (standardized — map 0 included):
  `{grant: {grants: id}, reward: {stars: 1, coins: 0}}`.
- `quests.gd:pending_grant_quests(z, owned_gen_ids)` returns the map's grant quests whose generator
  is not in `owned_gen_ids` and whose `appear_level` ≤ level. The old `gen_can_grant` hand-in
  precondition is removed. The lead grant still reserves the first fence slot (existing refill
  ordering preserved).
- `board.gd:_deliver_grant(qi, q, chip)`: append `q.grant.grants` to `gen_bag` (the bag generator
  section), pay the 1★ reward, remove the quest, refresh. No `board.grant_gen`.
- `board.gd:_deliver_gate` no longer places the next map's generators (the `place_surplus_gen` loop
  is removed). It only records the gate (unlocks the next map) and pays its reward; the new map's
  generators then arrive through their grant quests once the player is on that map.
- **Fresh game starts with an empty board** — `board.gd` no longer calls `seed_gens` on a fresh
  run ([board.gd:332](engine/scripts/scenes/board.gd:332)). The first quest is "claim your seed
  satchel"; claiming drops it in the bag, the player drags it onto the board and taps to produce.
  This is the new FTUE opening (highlight polish deferred).

## Removed / retired

- Quest: the `asks` array, `count`, `QUEST_2COUNT_RATE`, `GATE_ASK_COUNT`, the gate's top-level `stars`.
- Generators: `gen_grant`, `gen_can_grant`, `grant_map`, `surplus_gen_ids`, `grant_gen`,
  `place_surplus_gen`, `grow_surplus_gens`, the anchor exemption (`anchor_lines` + its use in
  `askable_lines`), the auto-`seed_gens` on a live fresh run.

## Files touched

`content.gd`, `grove_data.gd`, `board_logic.gd`, `quests.gd`, `board.gd`, `board_model.gd`,
`giver_stand.gd`, `bag_overlay.gd`, `games/grove/tools/grove_sim.gd`, and tests: `quest_tests`,
`featured_tests`, `anchor_tests`, `mechanics_tests`, `quest_fence_tests`, `grove_model_tests`,
`grove_placement_tests`.

## Testing strategy

TDD per change. Update each suite to the new shape *first*, watch it fail, then change the code:

- **quest_tests:** reward/clicks take a tier; `gen_quest` returns flat `{line, tier}` (no `asks`, no
  `count`); `gate_quest` asks one line at the ceiling tier and varies across seeds; `rng == null` →
  the single richest line.
- **featured_tests:** `quest_reward(quest_item(q).tier)`; the featured-never-inflates-★ invariant holds.
- **anchor_tests:** rewrite the anchor-exemption assertions — `askable_lines` is now current-map-only.
- **mechanics_tests:** grant quests exist for *every* generator of a map (including map 0); no
  hand-in precondition.
- **quest_fence_tests:** the lead grant surfaces from the *owned* set (board ∪ gen_bag), not the
  on-board set; one grant leads the fence; the rest of the fence is single-item regular quests.
- **grove_model_tests / grove_placement_tests:** giver-stand result carries a single `item`, not an
  `asks` array; delivery takes one item; the multi-pair render test becomes a single-item render test.
- New coverage: `gen_bag` round-trips through save; dragging a generator to/from the bag moves its
  id between `board.gens` and `gen_bag`; claiming a grant quest appends to `gen_bag`.

Run `make test-fast` after each engine change; `make test` before hand-off.

## Decisions made (defaults — revisit if wrong)

1. Claiming a grant quest puts the generator in `gen_bag`, not auto-onto the board — one uniform
   "drag it out to place" interaction; a full board never blocks an arrival.
2. Map 1 starts empty; its starter generator is claimed via the first grant quest (the "standard"
   instruction taken literally).
3. The grant quest keeps a small 1★ reward, now carried in a `reward` dict.

## Out of scope

- FTUE highlight / tutorial choreography for the new claim-and-place opening.
- A dedicated collection/museum UI for retired lines.
- Re-tuning the economy constants (the Monte-Carlo balance pass) beyond keeping `grove_sim` reading
  the new shapes.
- Letting old-map lines be quested (explicitly rejected — current map only).
