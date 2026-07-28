# Sell economy rework — doubling ladder + acorn top

Replaces the linear sell curve (`round(tier × band)`) with a ladder that doubles per tier, and pays
**acorns** at t10–t12. Owner decision 2026-07-27.

## Rules

`content.sell_reward(code) -> Vector2i(coins, acorns)`:

1. Seeds keep their flat payouts: soil seed `250🪙`, magnet seed `1000🪙`.
2. `tier = code % 100`; `band = TREAT_SELL_BAND` (3.5) for a treat line, else `SELL_MAP_BAND[map_for_code(code)]`.
3. `tier ≥ SELL_ACORN_TIER` (10) → `Vector2i(0, SELL_ACORNS[tier])`. Acorns are **flat — the band does not
   apply** and these tiers pay **no coins**.
4. Otherwise → `Vector2i(round(SELL_TIER_COINS[tier - 1] × band), 0)`.

`SELL_MAP_BAND` `[1.0, 1.3, 1.7, 2.2, 2.8]` and `TREAT_SELL_BAND` `3.5` are unchanged.
`GEN_SELL_COINS` `[2, 6]` (redundant generators) is unchanged.

## Dials (`games/grove/grove_data.gd`)

```gdscript
const SELL_TIER_COINS := [1, 2, 3, 4, 8, 16, 32, 64, 128, 0, 0, 0]  # index tier-1; 0 = pays acorns
const SELL_ACORN_TIER := 10                                          # lowest acorn-paying tier
const SELL_ACORNS := {10: 1, 11: 2, 12: 4}                           # flat, no band
```

`SELL_TIER_COINS` has exactly `TOP_TIER` entries; entries `SELL_ACORN_TIER..TOP_TIER` are 0 and every
tier `SELL_ACORN_TIER..TOP_TIER` has a `SELL_ACORNS` entry (asserted).

## Numbers

Coins per item, by map band:

| tier | today (m1) | m1 | m2 | m3 | m4 | m5 | treat |
|---|---|---|---|---|---|---|---|
| t1 | 1 | 1 | 1 | 2 | 2 | 3 | 4 |
| t2 | 2 | 2 | 3 | 3 | 4 | 6 | 7 |
| t3 | 3 | 3 | 4 | 5 | 7 | 8 | 11 |
| t4 | 4 | 4 | 5 | 7 | 9 | 11 | 14 |
| t5 | 5 | 8 | 10 | 14 | 18 | 22 | 28 |
| t6 | 6 | 16 | 21 | 27 | 35 | 45 | 56 |
| t7 | 7 | 32 | 42 | 54 | 70 | 90 | 112 |
| t8 | 8 | 64 | 83 | 109 | 141 | 179 | 224 |
| t9 | 9 | 128 | 166 | 218 | 282 | 358 | 448 |

Acorns, every map and every line: **t10 = 1🌰 · t11 = 2🌰 · t12 = 4🌰**. A treat line pays the same flat
acorns at t10+ — the 3.5 band applies to coin tiers only.

## Invariants (each an assert)

| # | Rule | Margin at these numbers |
|---|---|---|
| S1 | A merge never destroys value from t4 up: `v(t+1) ≥ 2·v(t)` in coin-equivalents (`1🌰 = COINS_PER_ACORN`) for `t ≥ 4` | equality t4→t9 and t10→t12; `+768🪙` at the t9→t10 acorn step. t1–t3 stay on today's linear `1·2·3` (the FTUE sell proofs + `buy_price`'s 10× rule read them), so a shallow merge loses at most `2🪙` — bounded by S2 |
| S2 | Splitting never pays: `max(2·v(t-1) − v(t)) < SCISSORS_COST` | max gain `2🪙` (t4) vs `40🪙` |
| S3 | No water↔acorn round trip: `tier_clicks(t) / SELL_ACORNS[t] ≥ 10 × water_a_diamond_buys()` for every acorn tier | `512💧` per acorn vs a `40💧` floor (12.8×) |
| S4 | Selling never beats buying: `SELL_ACORNS[t] < buy_price(t).y` | 1 < 21 · 2 < 34 · 4 < 55 |
| S5 | Selling never advances the level clock (existing sim invariant Y) | sells route through `Save.add_coins` / `add_diamonds` only |

`content.water_to_earn_diamond()` re-keys from `PREMIUM_TIER` to `SELL_ACORN_TIER`, so S3 and the sim's
Y print measure the real rate (`512💧`, was `128💧`). `PREMIUM_TIER` keeps its other uses.

## Touch points

| File | Change |
|---|---|
| `games/grove/grove_data.gd` | the three dials above; drop the stale `t8 = 1💎 pinnacle` comment on `SELL_MAP_BAND` |
| `engine/scripts/core/content.gd` | const mirrors; `sell_reward` per the rules; `water_to_earn_diamond` |
| `engine/scripts/core/board_actions.gd` | `farewell_preview` + `sweep_line` gain an `acorns` key (a retiring line holding t10+ items pays 0 today under the new curve) |
| `engine/scripts/scenes/board.gd` | credit + show the farewell card's acorns; the info-bar sell chip already swaps to the gem icon and `_sell_item` already credits `rw.y` via `Save.add_diamonds` + `Vault.skim` — no change |
| `games/grove/tools/grove_sim.gd` | both sell paths credit `rw.y` into `gems_from_sells`; the D-ledger label reads "top-tier sells", not "t8-sells" |

## Tests

- `engine/tests/quest_tests.gd:160` — the two "no tier mints acorns / t8 sells for coins" asserts are
  replaced: t8 pays coins on the new ladder, `SELL_ACORN_TIER..TOP_TIER` pay acorns and no coins, and
  every tier below pays coins and no acorns.
- New asserts for S1–S4 (a suite covering the ladder shape, not just spot values) and for the
  `SELL_TIER_COINS` / `SELL_ACORNS` coverage rule.
- `engine/tests/mechanics_tests.gd:932` (buy = 10× sell at t1–t3) and `mastery_tests.gd:216` (scissors
  floor) must pass **unchanged** — t1–t3 are untouched and S2 holds.
- `grove_board_actions_tests.gd:409` — the farewell preview/sweep asserts extend to the acorn key.
- `make test` green, then re-run `grove_sim` and record the new Z/D ledger.

## Known consequences (out of scope here)

- **The coin sink needs a re-price.** Baseline sim (7-day run): sells are `52🪙` of a `2,375🪙` faucet
  (2%) and the sink absorbs 99%. The same mid-ladder sales pay 3–8× more here, so coins will pile —
  `BOOST_COST`, the expedition loadout and the `4,316🪙` cover-up ladder are the parked §5 economy pass.
  Re-measure, do not re-tune here.
- **t9→t10 is a deliberate value cliff** (8× on map 1): reaching the acorn tiers is the reward.
- **Acorns are flat across maps**, so the per-map step-up flattens at the top of the ladder.
- The acorn faucet grows by roughly one acorn per 512💧 the player chooses to cash out, against a
  baseline faucet of `119🌰` per 7-day run (114 of it from level milestones).
