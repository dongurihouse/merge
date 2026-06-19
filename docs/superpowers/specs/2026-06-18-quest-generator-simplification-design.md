# Quest + generator simplification — design

**Date:** 2026-06-18
**Branch:** `worktree-quest-simplify`
**Status:** design, pending implementation

## Goal

1. **One quest type.** Every quest asks for exactly one item from one line. No gate type, no grant type.
2. A quest's **level = its asked item's tier** — one number that sets the ask, the reward, and the
   giver's badge. Any level 1–`TOP_TIER` is askable (no tier ceiling reserved for a special quest).
3. **Reward is a simple function of level** (capped stars + linear coins, plus premium currency at
   high levels).
4. **Generators persist** (no hand-in consumption) and are storable in a new bag section.
5. **Near the end of each map, one ordinary quest rewards the next map's generator** — the simplest
   replacement for the gate's old "grant the next tool" role.
6. Move toward **one generator per map** (each producing its two lines at random). The roster
   re-authoring and the t9–12 item art are a **separate content pass**; this change wires the
   mechanics data-drivenly and keeps today's 5-map/12-generator roster otherwise intact.

## Quest model — one type

A quest is `{line, tier, reward, featured}`. `tier` (1–`TOP_TIER`) is the quest's **level**. The
map-completion quest additionally carries `reward.generators: [ids]`.

`content.gd:quest_asks(q) -> Array` is replaced by:

```gdscript
static func quest_item(q: Dictionary) -> Dictionary:
    if q.has("line"):
        return {"line": int(q.line), "tier": int(q.tier)}
    if q.has("asks") and not q.asks.is_empty():   # tolerate a stale pre-change save
        return {"line": int(q.asks[0].line), "tier": int(q.asks[0].tier)}
    return {}
```

`board_logic.wanted_lines`, `board_logic.wanted_tiers`, and the `avoid` loop in `quests.refill` call
`quest_item(q)` and `continue` on an empty dict.

### Level range

- **`TOP_TIER` rises 8 → 12.** The merge ladder and asks both reach 12. (Item art for t9–12 doesn't
  exist yet — placeholder, deferred to the content pass.)
- The "regular quests never ask the top tier" rule is removed — any level 1–12 is askable.
- `gen_quest` still scales the asked level with player progress (the `QUEST_TIER_BASE` /
  `QUEST_LEVELS_PER_TIER` band), but the ceiling is now `TOP_TIER`, not `TOP_TIER - 1`.
- **TOP_TIER cascade — pin the economy.** Two values derive from `TOP_TIER` today and must NOT move
  silently when the ceiling rises: `water_to_earn_diamond` (`2^(TOP_TIER-1)` = 128 at t8 → would be
  2048 at t12, a ~16× diamond nerf) and `sell_reward`'s flat-1💎 premium pinnacle (the 32×
  anti-arbitrage cap, currently t8). Both are **re-pinned to a new `PREMIUM_TIER = 8` constant**
  instead of `TOP_TIER`, so raising the ladder ceiling leaves the premium/energy economy untouched.
  Re-tiering the pinnacle and re-proving anti-arbitrage at the new ceiling is part of the deferred
  balance pass.

### Reward (level-based)

```gdscript
static func quest_reward(level: int) -> Dictionary:
    var r := {"stars": clampi(level, 1, STAR_CAP), "coins": maxi(0, level - STAR_CAP)}
    if level >= QUEST_PREMIUM_MIN_LEVEL:           # high-level quests also pay premium currency
        r["gems"] = QUEST_PREMIUM_GEMS
    return r
```

- `STAR_CAP = 3` (kept) preserves the "level advances mainly by quest count" pacing — stars cap, so
  deeper asks pay their surplus in coins, not runaway stars.
- `QUEST_PREMIUM_MIN_LEVEL = 10`, `QUEST_PREMIUM_GEMS = 1` (new, provisional). A level-10/11/12 quest
  also pays a small 💎.
- The expected-clicks machinery (`avg_pop_value`, `quest_expected_clicks`, `CLICK_TO_VALUE`) is
  removed — reward no longer derives from generator-click effort.
- **Provisional / sim-tunable.** Linear coins likely under-price very deep asks relative to the
  merges they take; the balance pass owns the real curve. Flagged, not solved here.
- The `featured` bonus (extra coins, occasional 💎, never extra ★) is unchanged and stacks.

### Payability + fulfillment

- `board_logic.quest_payable(board, q)` → `board.count_of(line * 100 + tier) >= 1`.
- One delivery path in `board.gd:_on_giver_tap`: take one item of `line*100+tier`, animate it, pay
  `reward` (stars, coins, gems). If `reward.generators` is present, append those ids to `gen_bag`.

## Quest givers carry a level

Each giver shows a **level badge = the quest's `tier`**, so difficulty reads at a glance.
`giver_stand.make` adds the badge; no persistent per-character progression (the level is the current
quest's, rebuilt with the fence).

## Generators persist

- **content.gd:** remove `gen_grant`, `gen_can_grant`, `grant_map`, `surplus_gen_ids`,
  `grant_quests_for_map`, `gate_quest`, `anchor_lines`. `grant_from` loses its meaning (left inert
  for the content pass, or removed); `gen_cell_of` returns the generator's own `cell`.
- **board_model.gd:** remove `grant_gen`, `place_surplus_gen`, `grow_surplus_gens`. `seed_gens` /
  `live_gen_state` / `set_active_gens` stay — they seed the **first map's** generators at game start
  and back the sim/shot tools.
- **`askable_lines` = current map only** (no anchor union). Old-map lines aren't quested; the
  newest-line bias keeps the fence on recent content. Old generators stay usable for selling and the
  collection ladder.

## The bag's generator section

- New persisted `gen_bag: Array` of generator ids, alongside the item `bag`. Soft cap 100.
- **Owned generators** = `board.gens.values()` ∪ `gen_bag`.
- **BagOverlay** grows a generator region below the item-slot ladder; each tile is draggable to the board.
- Drag a board generator onto the bag well → move its id `board.gens` → `gen_bag` (frees the cell).
  Drag from the section onto an open cell → move it back. Stored generators don't produce; generators
  are never sellable.

## Map progression + generator arrival

- **First map:** seeded on the board at start, unchanged (anchor live immediately; `pantry_crock`
  grows in at its `appear_level`).
- **Next-map unlock** happens on **spots restored** — when the spot purchase that completes map `z`'s
  unlocks lands, `z` is appended to `gates` and the frontier advances. (The gate *quest* is gone; the
  gate *record* now sets automatically on spots-done.)
- **Generator grant, near the end:** while finishing map `z`, when the stars still needed to restore
  its remaining spots ≤ `GEN_GRANT_REMAINING_STARS` (new tunable) **and** some of map `z+1`'s
  generators aren't yet owned, the fence surfaces **one ordinary quest carrying**
  `reward.generators = <unowned ids of generators_for_map(z+1)>`. Delivering it appends those ids to
  `gen_bag`; being owned, it won't surface again. The player drags the new generator onto the board
  when they reach the next map. The giver card previews the generator it rewards.

This keeps generator delivery decoupled from the unlock: the generator arrives a quest or two before
the map completes (gauged by remaining stars), the unlock fires on spots-done.

## Removed / retired

- Quest: the `asks` array, `count`, `QUEST_2COUNT_RATE`; the **gate quest type** (`gate_quest`,
  `gate: true`, `GATE_ASK_COUNT`, `GATE_STARS`, `GATE_COIN_BONUS`, `GATE_TIER_BASE`, `_deliver_gate`);
  the **grant quest type** (`grant_quests_for_map`, `pending_grant_quests`, the `grant` branch,
  `_deliver_grant`); the expected-clicks reward math (`avg_pop_value`, `quest_expected_clicks`,
  `CLICK_TO_VALUE`); the "never ask the top tier" rule.
- Generators: `gen_grant`, `gen_can_grant`, `grant_map`, `surplus_gen_ids`, `grant_gen`,
  `place_surplus_gen`, `grow_surplus_gens`, the anchor exemption (`anchor_lines`), the lineage walk
  in `gen_cell_of`.

## Constants (grove_data.gd)

- Change: `TOP_TIER` 8 → 12.
- Add: `PREMIUM_TIER = 8` (pins the diamond-earn rate + sell pinnacle, decoupled from `TOP_TIER`),
  `QUEST_PREMIUM_MIN_LEVEL = 10`, `QUEST_PREMIUM_GEMS = 1`, `GEN_GRANT_REMAINING_STARS` (tune).
- Re-point `water_to_earn_diamond` and `sell_reward`'s pinnacle check from `TOP_TIER` to `PREMIUM_TIER`.
- Remove: `QUEST_2COUNT_RATE`, `GATE_ASK_COUNT`, `GATE_STARS`, `GATE_COIN_BONUS`, `GATE_TIER_BASE`,
  `CLICK_TO_VALUE`.
- Keep: `STAR_CAP`, `QUEST_TIER_BASE`, `QUEST_LEVELS_PER_TIER`, `QUEST_DEBUT_TIER_CAP`,
  `QUEST_NEWEST_BIAS`, `QUEST_REPEAT_PENALTY`, `QUEST_FEATURED_*`, `MAX_GIVERS`, `STARS_PER_QUEST_EST`,
  `TIER_ODDS`, `BURST_*`.

## Files touched

`content.gd`, `grove_data.gd`, `board_logic.gd`, `quests.gd`, `board.gd`, `board_model.gd`,
`giver_stand.gd`, `bag_overlay.gd`, `games/grove/tools/grove_sim.gd`, and tests: `quest_tests`,
`featured_tests`, `anchor_tests`, `mechanics_tests`, `quest_fence_tests`, `grove_model_tests`,
`grove_placement_tests`.

## Testing strategy

TDD per change — update the suite to the new shape first, watch it fail, then change the code:

- **quest_tests:** `quest_reward(level)` → capped stars + linear coins, +💎 at level ≥ 10;
  `gen_quest` returns flat `{line, tier}` and can ask up to `TOP_TIER`; no gate/grant generators;
  determinism preserved.
- **featured_tests:** `quest_reward(quest_item(q).tier)`; featured never inflates ★.
- **anchor_tests:** `askable_lines` is current-map-only (anchor exemption gone).
- **mechanics_tests:** hand-in/grant/gate functions are gone; the near-end generator quest lists map
  `z+1`'s unowned generators and stops once they're owned.
- **quest_fence_tests:** fence is single-item quests metered to the next unlock; the near-end quest
  carries `reward.generators`; spots-done advances the frontier without a gate quest.
- **grove_model_tests / grove_placement_tests:** giver result carries one `item` (not an `asks`
  array) plus a level badge; delivery takes one item; delivering the generator quest appends to
  `gen_bag`.
- New coverage: `gen_bag` round-trips through save; dragging a generator to/from the bag moves its id;
  reward gems appear only at level ≥ 10.

Run `make test-fast` after each engine change; `make test` before hand-off.

## Decisions made (defaults — revisit if wrong)

1. **Quest level = asked tier** — one number for ask, reward, and giver badge.
2. **Generators arrive into the bag**, dragged out to place (avoids cell collisions in the current
   roster). The reward quest's card previews its generator.
3. **Next-map unlock fires on spots-done** (auto); the generator is a separate near-end reward.
4. **`TOP_TIER = 12`** as a constant now; t9–12 item art and the one-generator-per-map roster are the
   deferred content pass.

## Out of scope

- Re-authoring the map/line/generator roster to one-generator-per-map; t9–12 item art.
- FTUE highlight / tutorial choreography.
- A collection/museum UI for non-current lines.
- The economy balance pass (the real reward curve) — `grove_sim` is only updated to read the new shapes.
- Auto-placing rewarded generators directly on the board (revisit after the roster pass).
