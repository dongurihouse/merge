# Home Build-and-Upgrade Map — Design Spec

> **SUPERSEDED (2026-07-24)** by
> [`2026-07-24-habitat-cells-per-scene-design.md`](2026-07-24-habitat-cells-per-scene-design.md).
> The home-building system described here (BUILDINGS, home.gd/home_build.gd, per-zone cells) has
> been removed: all maps are cover-up scenes, and habitat cells now derive from completed scenes
> (one per fully-unlocked scene). Kept for history.

**Date:** 2026-07-17
**Decision:** Replace the mask-based multi-map restoration system with one evolving home world
of coin-built, upgradable, customizable buildings rendered through the layered cut-paper
pipeline. Big-bang replacement (Approach C — breakage on main accepted during the build).

## 1 · Player model

One evolving home world. The loop:

1. Earn coins on the board (quests, merges, selling).
2. Spend coins to build buildings **step by step** on the home map.
3. A **finished building grants resident cells** to the global bucket.
4. Residents produce back into the game (the bucket system, unchanged).
5. Built buildings take **cosmetic customization** for coins or premium currency.

Removed concepts: region masks, map-select, maps 2–5, stars, exp. Buildings never produce
anything — production belongs exclusively to the resident bucket.

This reverses two recorded spec decisions, deliberately:

- `grove_spec` cut the hub upgrade loop ("no hub yield any more"). This design reintroduces
  building ladders but **without yields** — buildings are a coin sink and a capacity source,
  never a faucet, so the "coins' power lives in the Expedition" rule survives.
- `grove_spec` granted bucket cells only on **map completion**. With one evolving home there
  is no map-completion event; the cell source moves to **building completion**, and the
  capacity brake moves from exp-gated maps to **level-gated build steps** (§4).

The economy was already marked REOPENED in `grove_spec §5`; the sim re-pass in §7 covers
these reversals.

## 2 · World and rendering

A new Home scene replaces both views of `engine/scripts/scenes/map.gd` (map view and
map-select view).

- **World = a list of zones.** Each zone is one self-contained pipeline-generated diorama:
  a foundation image plus independent prop sprites. Zones sit at fixed positions in one
  world space. v1 ships exactly one zone — the 941×1672 cut-paper farmhouse scene already
  produced (`games/grove/assets/map/home_layered_cutpaper/`).
- **Expansion model: zones-as-dioramas.** A future release appends a new generated zone
  adjacent to the existing world, bordered by natural paper-style edges (tree lines, river,
  hedge) — no pixel-seam matching, no oversized up-front canvas. The renderer draws through
  a world→screen transform from day one: fit-to-viewport while there is one zone, pan/zoom
  clamped to the world rect when a second zone lands.
- **Props.** Center-bottom anchored, painter-sorted by `sort_y`, exactly as the
  `HomeLayerWorkbench` prototype renders them. Each building shows the sprite of its
  **current state**: `empty → site(s) → built → customized`.
- **Input.** The single-input-surface rule carries over: one content Control receives
  input; every visual descendant is `MOUSE_FILTER_IGNORE`; a test asserts it.
- **Chrome carries over unchanged:** bottom nav, HUD, garden CTA, resident dock, vault,
  login calendar, settings, inbox. The resident dock remains the bucket's one management
  surface, now hosted by the Home scene.

## 3 · Data model

**Zone manifest** (JSON, extending the prototype's `home_props.json` shape):

```
zone: {
  id, foundation_texture, canvas: [w, h], world_pos: [x, y],
  buildings: [
    {
      id, label, position: [x, y], display_size: [w, h], sort_y,
      states:      [ {id, texture} ],            # "empty" may have no texture
      build_steps: [ {cost_coins, min_level, shows_state} ],
      cells_granted,                              # bucket cells on completion
      customizations: [ {id, texture, cost: {coins | diamonds}} ]
    }
  ]
}
```

- Minimum 3 states per building (empty / site / built). Later buildings may carry several
  site stages for longer visible progressions; steps map to states via `shows_state`, so
  step count and art count are independent.
- Premium buildings are future-compatible: a building whose first step prices in diamonds,
  same schema (not built in v1).

**Save state:** per building `steps_done` and `customization`; one new global counter
`coins_earned_lifetime` (organic earnings only — shop/premium coin conversions excluded).

## 4 · Progression and economy

- **Level = f(coins_earned_lifetime)** through the existing arithmetic-curve shape
  (`content.gd` level math re-pointed at the coin clock). Purchased coins spend normally
  but never advance the clock: the **level gate reads the earned total; the price reads the
  held balance**. Level-ups keep gifting water + diamonds.
- **Quests pay coins only.** The exp award and `QUEST_CLICKS_PER_EXP` retire; the quest
  coin formula (`QUEST_CLICKS_PER_COIN`, featured bonuses) stays.
- **Build step purchase** requires the step's `min_level` AND its coin price. The final
  step marks the building built and grants `cells_granted` to the bucket **exactly once**.
  The level gate is the capacity brake — coins alone cannot rush cells.
- **Sinks:** the building ladder (finite, early/mid game — this fills the sim's parked
  "early-game coin pile" gap) · customizations (cosmetic, coins/diamonds) · the Expedition
  load-out (unchanged, the open-ended endgame sink) · generator burst upgrades (unchanged).
- **Invariants for the sim re-pass** (a follow-up tuning task, not part of this build):
  - *No-strand:* at every level an affordable next build step exists at nominal coin flow.
  - *Sink > faucet:* re-proven with the building ladder added and exp removed.
  - *Selling tripwire, extended:* selling mints coins, and coins are now the level clock —
    verify sell-farming cannot meaningfully rush levels (and therefore cells).

## 5 · Deletions

- `map.gd`: mask/plate machinery (`_build_home_spot`, clean/broken plates, per-building
  masks, shatter veil, vine locks), the map-select view and cards, `_make_spot` placeholder
  tiles, the ★ price surface, the free-claim spot flow (`spot_unlock_exp` gating).
- Maps 2–5 data and scenes. **Art is archived, never deleted.**
- Exp as a concept: quest exp awards, exp tunables. `content.gd`'s level curve survives,
  re-parameterized over the coin clock.
- Board-side entries (`Decorate`, nav) re-route to the Home scene.

## 6 · Migration

Pre-launch: **saves reset**. Old exp, spot ownership, and map state are dropped. A debug
grant (coins + level + built-building presets) supports testing mid-game states. No coarse
migration is built.

## 7 · Testing

- **Pure build module** — `(model, action) → outcome` statics, no scene dependencies —
  with headless tests: level gate honored; insufficient coins rejected; step advance;
  cells granted exactly once per building; customization apply/price; level-from-coins
  curve (including purchased-coins exclusion); save round-trip.
- **Renderer** — headless node-tree asserts: one prop node per building, correct state
  texture, painter order by `sort_y`, single input surface. A `quiet_godot` screenshot
  for the Dev share-gate eyeball (never the agent's judgment).
- `make test-fast` after every change; full `make test` before hand-off.
- **Economy sim re-pass** — parked as an explicit follow-up (owner: Dev tuning pass);
  invariants listed in §4.

## 8 · Art pipeline follow-ups (not this build)

- Per-building **site-state** sprites (one shared construction-site look suffices for v1).
- Customization variant sprites per building.
- Future zones (new dioramas) and premium buildings ride the same schema.

## Out of scope

- Bucket internals, Expedition, board, quest generation (beyond removing exp awards).
- Sim tuning numbers (all costs, level thresholds, cell counts are placeholders until the
  economy re-pass).
- Pan/zoom camera polish beyond what one zone needs.
