# Global resident bucket — one shared habitat, per-line rewards

**Date:** 2026-07-16 · **Status:** approved design, replaces the per-map habitat model in `grove_spec.md` §3 · **Code touched (later, at implementation):** `engine/scripts/core/habitat.gd`, map/dock UI, save migration.

## The problem (why the per-map model is out)

The Residents expansion was designed as the keystone **coin sink**, but the built per-map production model turned it into an unbounded **faucet**:

- The spec's containment story ("each map matures a FIXED reward unit; tier speeds cadence only; diamonds hard-day-capped") was **not** what got built. `habitat.gd` computes `rate = 0.25 × Σtier × mult` per hour — tier and count both scale the **rate**, and the code comment states the per-map mult "REPLACES the old per-unit value + the hard caps."
- The ceiling is 5 maps × 8 slots × tier 12 = Σtier 96 **per map, all five streams running concurrently**: ~120 coins/h, 24 water/h, **2.4 diamonds/h**, and 4.8 spirits/h (a self-compounding stream). Diamonds are the "earned-only & precious" IAP-guard currency (milestones pay +3 per 10 levels), so this breaks the invariant outright.
- Patching it with hard caps was rejected: a cap that binds makes high-tier merging pointless, and pointless merging kills the loop. The fix has to make the bound emerge from **player choice**, not a wall.

## The model

**One global habitat bucket, detached from maps.** There are no per-map rosters. The bucket is a shared set of **cells**; it starts at **0** and grows only when a map is **fully restored** — each completed map grants cells (grant schedule is a tuning call; ~8 total across the five home-grove maps). A map's completion reward *is* its capacity grant: maps keep their purpose without owning a habitat.

**Four resident lines, one per resource.** Every resident kind belongs to a **line**, and each line pays one resource:

| Line | Pays | Tier does | Bound |
|---|---|---|---|
| Coin-kin | Coins | scales rate + bank cap | none needed — sink-positive vs. the 150🪙 expedition, re-proven in sim |
| Water-kin | Water | scales rate + bank cap | banks to a small cap; a top-up, never an energy replacement |
| Boost-kin | Generator-boost charges | scales rate + bank cap | small bank cap |
| Diamond-kin | Diamonds | shortens the maturation timer **and** raises the bank cap; the per-day yield ceiling is a designed number | bounded by construction (~1–2/day at full dedication, sim-tuned) + rarity-gated acquisition |

The old fifth stream (residents producing residents, Meadow) is **cut** — it self-compounds and competes with the expedition, which must stay the only spirit source (it is the coin sink).

**Cells > lines; duplicates stack.** The same line may occupy any number of cells. A line's output is driven by its **Σtier** — the sum of tiers of all placed residents of that line. Two tier-3 coin-kin equal one tier-6 in Σtier, but the tier-6 frees a cell — merging buys **cell efficiency**, the scarce thing.

**Merge always pays (hard design invariant).** *Every merge must perceptibly improve at least one of cadence (time to produce) or bank cap (max accrued before a collect is needed) on its line.* On scaling lines tier raises both. On the diamond line the daily ceiling is fixed by design, but tier still shortens the timer and deepens the bank — no merge is ever a dead upgrade. This invariant is testable and the sim pass must assert it per tier step.

**Why the ceiling is now safe — opportunity cost is the limiter.** Total Σtier ≤ cells × 12 ≈ 96, **shared across all four lines** (vs. 480 concurrent before). Maxing one line means zeroing the others; full diamond dedication costs every coin/water/boost cell and still lands on the designed daily number. The bound is a trade-off the player makes, not a wall they hit.

**Acquisition — rarity is the second brake.** Expedition boxes roll a **line** by weight (coin-kin common → diamond-kin rare) and a **tier** off the existing t1-heavy curve. Climbing the diamond ladder needs 2^(n−1) copies of a rare drop, so its high tiers are naturally slow with no cap the player can feel. The rarity table is a sim-tuned dial. (This is drop-rate weighting on free skill-earned boxes — distinct from the parked white/blue/orange/red rarity-axis extension, and it does not touch the premium-capsule guardrails.)

**Capacity comes only from map completion.** The previously planned coin-purchasable map-capacity upgrades are **cut**: capacity is the brake, and selling cells for coins would let players buy past the opportunity-cost limiter. The expedition load-out stays the primary open-ended coin sink.

## Surfaces and fiction

- **UI:** the spirits dock evolves into the bucket surface — cells + the unbounded hand + per-line pending badges; the verbs (hand-merge, place, place-merge, move, sell, collect) are unchanged in kind. The per-map collect cards on map select **retire**; collection happens on the one dock surface.
- **Fiction:** completed maps keep a simple ambient crowd. Future polish (parked, not v1): placed residents ambient-walk **whichever map the player is currently viewing**, so the one roster always looks at work everywhere.
- **Almanac (still parked):** the collection grid is now legible by construction — 4 lines × 12 tiers of per-tier art. Map-signature ambient variety (frog-kin, orchard-bees…) moves to the ambient-crowd art layer, not the merge roster.

## Migration and retirement

- **Saves:** all placed spirits return to the hand; completed maps grant their cells immediately, so nothing is lost — only re-chosen. Pending production is settled and granted at migration.
- **Retired:** the per-map `REWARD` table and per-map cap ramp in `habitat.gd`, map-card collect UI, the Meadow spirits stream, capacity-as-coin-sink.
- **Unchanged:** expeditions/Rush end to end, the 12-step ladder (`RESIDENT_MAX_TIER`), per-tier art plan, selling as the valve, the hand.

## Economy re-author scope (the parked §5 pass, now smaller)

One bucket, four line dials, one rarity table. Re-prove: coins sink > faucet (load-out vs. coin line), water stays a top-up (I2), diamonds/day at full dedication vs. the IAP ladder, the merge-always-pays invariant per tier step, and the early-game window (the bucket opens at first map completion, as today). All numbers in this doc are provisional feel-dials until that pass runs.
