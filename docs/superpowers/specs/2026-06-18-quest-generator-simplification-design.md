# Quest + generator simplification — design

**Date:** 2026-06-18
**Branch:** `worktree-quest-simplify`
**Status:** design, pending implementation

## Goal

1. Every quest **asks for exactly one item from one line**.
2. **Generators persist** instead of being consumed by a hand-in.
3. A map's **final (gate) quest rewards the next map's generator(s)** — the standalone "hand-in"
   quest type is removed.
4. Move toward **one generator per map** (each still producing its two lines at random). The exact
   map/line roster is re-authored in a **separate content pass**; this change wires the mechanic
   data-drivenly so it works on today's 5-map/12-generator roster and on a future one-per-map roster.

## Motivation

- The ask shape is polymorphic (`asks: [{line, tier, count}, …]`) but only the gate quest used more
  than one ask, and `count` was 1–2. Unused flexibility, spread across generation, payability,
  fulfillment, and UI.
- The hand-in model *consumes* an old generator (`gen_grant`), so the player loses tools and old
  lines retire. For a cozy collection/restoration game this is loss-averse and off-genre. Persisting
  generators fits the fantasy; with persistence there is nothing to "hand in," so the generator
  simply arrives as the reward for finishing a map.

## Quest model — two types

Both lose the `asks` array; the required item is stored flat.

| Type | Asks for | Shape (after) |
|------|----------|---------------|
| Regular | one item, one line | `{line, tier, reward, featured}` |
| Gate | one item, one line, ceiling tier | `{line, tier, gate: true, reward: {stars, coins, generators: [ids]}}` |

The **grant quest type is deleted** (`grant_quests_for_map`, `pending_grant_quests`, the `grant`
branch in `giver_stand`/`board`, `_deliver_grant`). Generators now arrive two ways only: the first
map's are seeded on the board at game start (today's behavior, unchanged); every later map's are the
**reward of the previous map's gate quest**.

### Accessor

Replace `content.gd:quest_asks(q) -> Array` with:

```gdscript
static func quest_item(q: Dictionary) -> Dictionary:
    if q.has("line"):
        return {"line": int(q.line), "tier": int(q.tier)}
    if q.has("asks") and not q.asks.is_empty():   # tolerate a stale pre-change save
        return {"line": int(q.asks[0].line), "tier": int(q.asks[0].tier)}
    return {}
```

`board_logic.wanted_lines`, `board_logic.wanted_tiers`, and the anti-monotony `avoid` loop in
`quests.refill` call `quest_item(q)` and `continue` on an empty dict.

### Reward math (single tier)

```gdscript
static func quest_expected_clicks(tier: int) -> float:
    return pow(2.0, tier - 1) / avg_pop_value()

static func quest_reward(tier: int) -> Dictionary:
    var value := int(round(quest_expected_clicks(tier) * CLICK_TO_VALUE))
    return {"stars": clampi(value, 1, STAR_CAP), "coins": maxi(0, value - STAR_CAP)}
```

### Generation

- `gen_quest(level, live_lines, rng, avoid)` drops the `count` roll and `QUEST_2COUNT_RATE`. Returns
  `{line, tier, reward, featured}`.
- `gate_quest(roster, map, rng)` picks **one** line (randomized from the map's roster; `rng == null`
  → the single richest line) at the ceiling tier `min(GATE_TIER_BASE + map, TOP_TIER)`. Its reward
  carries the **next map's generators**:
  `reward: {stars: GATE_STARS, coins: quest_reward(tier).coins + GATE_COIN_BONUS, generators: ids}`,
  where `ids = generators_for_map(roster, map + 1)` (a single id once the roster is one-per-map;
  the last map's gate carries an empty list). The redundant top-level `stars` is dropped.

### Payability + fulfillment

- `board_logic.quest_payable(board, q)` → `board.count_of(line * 100 + tier) >= 1`.
- `board.gd:_on_giver_tap` and `_deliver_gate`: take one item of `line*100+tier`, animate it.

## Generators persist

The hand-in machinery retires:

- **content.gd:** remove `gen_grant`, `gen_can_grant`, `grant_map`, `surplus_gen_ids`,
  `grant_quests_for_map`. `grant_from` loses its meaning (kept inert in the data for the upcoming
  content pass, or removed); `gen_cell_of` returns the generator's own `cell` (no lineage walk).
  Remove `anchor_lines` and the anchor exemption.
- **board_model.gd:** remove `grant_gen`, `place_surplus_gen`, `grow_surplus_gens`. `seed_gens` /
  `live_gen_state` / `set_active_gens` stay — they seed the **first map's** generators at game start
  (and back the sim/shot tools). Later maps' generators no longer auto-seed.
- **askable_lines = current map only.** `askable_lines(roster, map, level)` returns
  `lines_for_map(roster, map, level)` — no anchor union. Old-map lines are never quested (the
  newest-line bias keeps the fence on recent content). Old generators stay usable for selling and
  the collection ladder.
- **One generator per map** is the target content shape, reached in the separate roster pass. The
  mechanic here is data-driven (`generators_for_map(map)`), so a map with one generator or several
  both work; today's roster is left intact apart from removing hand-in semantics.

## The bag's generator section

- New persisted `gen_bag: Array` of generator id strings, alongside the item `bag`. Soft cap 100.
- **BagOverlay** grows a second region below the item-slot ladder: one tile per id in `gen_bag`,
  each draggable onto the board.
- **Interactions:**
  - Drag a board generator onto the bag well → move its id from `board.gens` into `gen_bag` (frees
    the cell). Reuses the existing "dragged onto bag" drop resolution in `_on_release`.
  - Drag a generator from the section onto an open cell → move its id from `gen_bag` into
    `board.gens` at that cell.
  - A stored generator does not produce. Generators are never sellable.

## Arrival flow

- **First map:** seeded on the board at game start, exactly as today — the anchor `seed_satchel` is
  live from the first second; `pantry_crock` grows in at its `appear_level`. **Map 1 is unchanged.**
- **Every later map:** delivering map N's gate quest unlocks map N+1 (records the gate) **and appends
  map N+1's generator ids to `gen_bag`**. The player opens the bag and drags the new generator onto
  an open cell to start producing map N+1's lines. `_deliver_gate` no longer calls `place_surplus_gen`.
- The **gate quest's giver card shows the generator it will reward** (reusing the icon rendering from
  the deleted grant branch), so the player sees "finish this → new tool."

Landing the reward in the bag (rather than auto-onto the board) avoids the cell collisions in the
current shared-cell roster and works regardless of how the roster is later re-authored. Auto-placing
on the board can be revisited once each generator has a distinct cell.

## Removed / retired

- Quest: the `asks` array, `count`, `QUEST_2COUNT_RATE`, `GATE_ASK_COUNT`, the gate's top-level
  `stars`, the entire **grant quest type** and its delivery/render paths.
- Generators: `gen_grant`, `gen_can_grant`, `grant_map`, `surplus_gen_ids`, `grant_gen`,
  `place_surplus_gen`, `grow_surplus_gens`, `grant_quests_for_map`, `pending_grant_quests`, the
  anchor exemption (`anchor_lines` + its use in `askable_lines`), the lineage walk in `gen_cell_of`.

## Files touched

`content.gd`, `grove_data.gd`, `board_logic.gd`, `quests.gd`, `board.gd`, `board_model.gd`,
`giver_stand.gd`, `bag_overlay.gd`, `games/grove/tools/grove_sim.gd`, and tests: `quest_tests`,
`featured_tests`, `anchor_tests`, `mechanics_tests`, `quest_fence_tests`, `grove_model_tests`,
`grove_placement_tests`.

## Testing strategy

TDD per change — update the suite to the new shape first, watch it fail, then change the code:

- **quest_tests:** reward/clicks take a tier; `gen_quest` returns flat `{line, tier}` (no `asks`/
  `count`); `gate_quest` asks one line at the ceiling tier, varies across seeds, and its reward
  carries the next map's generator ids (empty on the final map); `rng == null` → richest single line.
- **featured_tests:** `quest_reward(quest_item(q).tier)`; the featured-never-inflates-★ invariant holds.
- **anchor_tests:** rewrite — `askable_lines` is now current-map-only (no anchor exemption).
- **mechanics_tests:** drop the grant-quest assertions; assert the hand-in functions are gone and
  that a gate reward lists map N+1's generators.
- **quest_fence_tests:** no grant quest leads the fence; the fence is single-item regular quests plus
  the lone gate when the map is restored; the gate reward grants generators into `gen_bag`.
- **grove_model_tests / grove_placement_tests:** giver-stand result carries a single `item`, not an
  `asks` array; delivery takes one item; the multi-pair render test becomes a single-item render
  test; the gate card shows its rewarded generator.
- New coverage: `gen_bag` round-trips through save; dragging a generator to/from the bag moves its id
  between `board.gens` and `gen_bag`; delivering a gate appends the next generators to `gen_bag`.

Run `make test-fast` after each engine change; `make test` before hand-off.

## Decisions made (defaults — revisit if wrong)

1. **Map 1 unchanged** — its generators seed on the board at start, exactly as today.
2. **Generators arrive into the bag**, dragged out to place (avoids cell collisions in the current
   roster). The gate card previews the generator it rewards.
3. The **grant quest type is removed entirely**; the generator rides as a field on the gate reward.
4. **One generator per map** is the content target, deferred to a separate roster pass; this change
   keeps today's roster and only removes hand-in semantics.

## Out of scope

- Re-authoring the map/line/generator roster to one-generator-per-map (the separate content pass).
- FTUE highlight / tutorial choreography.
- A dedicated collection/museum UI for non-current lines.
- Economy re-tuning beyond keeping `grove_sim` reading the new shapes.
- Auto-placing gate-rewarded generators directly on the board (revisit after the roster pass).
