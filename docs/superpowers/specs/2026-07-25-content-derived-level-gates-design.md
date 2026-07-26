# Content-derived level gates — the pacing spine reads the cluster cost ladder

**Date:** 2026-07-25
**Status:** design, approved for planning

## The problem

The game has three pacing ladders that are supposed to move together:

1. **The coin clock** — `level_at_coins(lifetime organic coins)`, an arithmetic curve
   with dials `LEVEL_BASE_COINS = 30` / `LEVEL_STEP_COINS = 12`.
2. **The cluster ladder** — 25 cover-up clusters across the 5 scenes, each with a coin
   `cost` and a level floor `cluster_min_level = 2 + round(index × CLUSTER_LEVEL_STEP)`.
3. **The content arc** — 12 zones (item lines + generators), each gated by a
   hand-authored `ZONE_UNLOCK_LEVEL` entry, banded `[2,3,3,2,2]` across the 5 scenes.

Ladders 2 and 3 are authored **in level-space**, by hand, and are re-spaced by hand
whenever either moves. Ladder 1 is what actually converts play into level. Nothing
checks that the level range the tables use corresponds to the coins the ladder demands
— and it does not.

The cluster ladder costs **46,740 coins** end to end:

| scene | clusters | cost | cumulative |
|---|---|---|---|
| Fairy Hollow | 6 | 420 | 420 |
| Snowy Village | 5 | 2,100 | 2,520 |
| Desert Oasis | 5 | 6,220 | 8,740 |
| Coral Reef | 5 | 15,000 | 23,740 |
| Cherry-Blossom Garden | 4 | 23,000 | 46,740 |

`ZONE_UNLOCK_LEVEL` tops out at L34, which on the shipped curve is **7,326 earned
coins** — inside *Desert Oasis*, cluster 14 of 25. **Every item line in the game is
delivered by the middle of scene 3**, with two and a half scenes left to restore.
`cluster_min_level` tops out at L34 for the same reason.

Asking the shipped curve where the player actually stands when they have earned what
each cluster costs gives a very different table:

| scene completes | floor as shipped | floor the cost ladder implies |
|---|---|---|
| Fairy Hollow | L9 | **L7** |
| Snowy Village | L15 | **L19** |
| Desert Oasis | L22 | **L37** |
| Coral Reef | L29 | **L61** |
| Cherry Blossom | L34 | **L87** |

The two agree through scene 2 and then diverge without limit. This is the root cause of
the symptom the 2026-07-25 `stretch-content` commit treated: grove_sim measured the
content arc emptying by ~day 19 while restoration ran past day 60. Stretching
`ZONE_UNLOCK_LEVEL` from L1–25 to L1–34 moved the exhaustion point from scene 2 to
scene 3. It could not fix it, because the table's whole range covers 16% of the game's
coin arc.

The curve's **scale** is fine. The **gates** are what is disconnected.

## The design

### 1. Derive the cluster floors from the cost ladder

```
cluster_min_level(z, id) = level_at_coins(cumulative_cluster_cost(global_index(z, id)))
```

where `cumulative_cluster_cost(i)` is the sum of the `cost` fields of clusters 0..i in
global play order. `CLUSTER_LEVEL_STEP` is retired.

The number of levels a cluster spans is no longer a constant — it grows with the curve,
from ~1 level per cluster in Fairy Hollow to ~6 in Cherry Blossom. That is the correct
behaviour: per-level coin cost escalates, so a fixed levels-per-cluster mapping cannot
hold.

Derived floors, per cluster (shipped curve 30/12):

```
FH    L1  L2  L3  L4  L5  L7
SV    L9  L11 L14 L16 L19
DO    L22 L25 L29 L33 L37
CR    L41 L46 L51 L56 L61
CB    L67 L73 L80 L87
```

### 2. Derive the zone unlocks from the same windows

Each scene's completion level defines its **level window**:

```
Fairy Hollow  L1–7     Snowy L8–19     Desert L20–37     Coral L38–61     Cherry L62–87
```

`ZONE_BAND = [2,3,3,2,2]` spreads that scene's zones evenly inside its own window: for a
scene spanning `[a,b]` with `k` zones, zone `j` unlocks at `a + round(j × (b+1-a) / k)`.
Zone 0 is pinned to L1 (the anchor line, available from the first tap).

```
ZONE_UNLOCK_LEVEL  [1, 5, 8, 12, 16, 20, 26, 32, 38, 50, 62, 75]   derived
                   [1, 5, 10, 12, 15, 17, 19, 22, 23, 27, 30, 34]  shipped, hand-authored
```

The last item line lands **74% through the ladder** (34,632 of 46,740 coins) instead of
16%. Scene alignment — the property the source comments describe as load-bearing and
warn must be re-spaced by hand — becomes arithmetic and can no longer drift.

### 3. Where the dials go

`ZONE_UNLOCK_LEVEL` and `CLUSTER_LEVEL_STEP` leave `grove_data.gd` as authored constants.
The owner-facing pacing dials that remain are:

- `LEVEL_BASE_COINS` / `LEVEL_STEP_COINS` — the curve. Moving these now moves *both*
  content ladders coherently, because both read the curve.
- The per-cluster `cost` fields in `MAPS` — the content ladder itself.
- `ZONE_BAND` — which zones belong to which scene.
- **New:** `CLUSTER_LEVEL_LEAD` (default `1.0`) — scales the cumulative cost before the
  level lookup. `< 1.0` makes the padlock lead affordability (level reached first, save
  for the coins); `> 1.0` makes it lag (coins held, level not yet reached). At the
  default the floor is non-binding by construction: the player reaches the level at
  about the moment they can afford the cluster.

### 4. What does not change

- The clock stays **quests only**. `_earn_coins` / `Save.earn_coins` are untouched;
  purchased and sold coins never advance a level. grove_sim's invariant Y still hard-fails
  if any non-quest coin path leaks into progression.
- The curve keeps its arithmetic shape and its dials, so saves, `economy_tuning.json`
  overrides, and `coins_at_level` callers are unaffected.
- The board's save migration (`board.gd`, strips out-of-cadence generators/items) keeps
  working — it queries the cadence rather than hardcoding it.

### 5. Consequences to measure, not pre-tune

**Level-up cadence itself does not change.** The curve is untouched, so a player levels at
exactly the same rate per coin earned as today — the water gift (`LEVEL_WATER_GIFT = 40💧`)
and `LEVEL_DIAMONDS = 3` fire on the same schedule. What changes is only *where the gates
sit on that arc*: the book now ends around L87 instead of the gates all being satisfied by
L34. The gift/diamond totals over a full restoration go up only because the run is longer
in level terms, not because levels come faster.

Second-order effects that do need measuring:

- **Per-scene gift-vs-spend (I2) shifts.** Clusters unlock later relative to level, so the
  water gift lands against a different per-scene spend. Report the new ratios; do not
  pre-tune the gift.
- **The first cluster's floor drops to L1** (Fairy Hollow's `mushroom_hall` costs 10 coins,
  below the L2 threshold of 30). Today it is L2. This makes the first padlock purely a
  coin gate — check it against the FTUE flow before accepting it, or pin cluster 0 to L2.
- **Coins may pile differently.** Later floors mean the wallet can run ahead of the ladder;
  grove_sim's P1/P2 pile checks and the Z absorption ratio are the signals.
- **Board-cell gates and any other level-keyed content** now sit at different points
  relative to the scenes. Enumerate the level-keyed reads during planning and confirm each
  is intentional.

## Testing

- **Derivation unit tests** (`engine/tests/mechanics_tests.gd`): floors are strictly
  non-decreasing; each cluster's floor equals `level_at_coins` of its cumulative cost;
  `ZONE_UNLOCK_LEVEL` is strictly increasing and `ZONE_COUNT` long; each zone's unlock
  level falls inside its own scene's window (the scene-alignment property, now asserted
  rather than commented).
- **Dial-independence test**: change `LEVEL_BASE_COINS`/`LEVEL_STEP_COINS` and confirm
  both derived tables move with it and the scene-alignment assertion still holds. This is
  the guard that stops the hand-authored drift from coming back.
- **Existing assertions**: the tests re-derived in the `stretch-content` commit already
  query the cadence instead of hardcoding it, so they should survive. Any that pin
  specific levels get re-derived the same way.
- **grove_sim**, 3 seeds × 60 days: zero jams, sim PASS, and a report showing the day the
  last content zone lands versus the day the book completes. The pass condition for this
  work is that those two no longer sit 40 days apart.
- `make test-fast` after each change; `make test` before handoff.

## Out of scope

- Re-tuning `LEVEL_BASE_COINS` / `LEVEL_STEP_COINS` themselves. The scale is fine; this
  change is about the gates. A curve sweep on top of the derived gates is a separate pass.
- Re-tuning the per-cluster `cost` fields.
- Re-scaling the water gift or diamond grants (measure and report only).
- The parked §5 bucket economy pass and the §7 economy tuning pass in `docs/BACKLOG.md`.
