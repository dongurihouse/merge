# Boost on a top-tier generator — per-tier boosted odds

Date: 2026-07-26 (T64)

## Problem

The temporary per-generator boost rolls the flat `BURST_ODDS_BOOST = [0.20, 0.45, 0.35]`
(grove_data.gd), which is byte-identical to `GEN_TIER_BURST_ODDS[2]` — the tier-3 row the
2026-06-28 gen redesign (#8) reused as its top row. A boost on a tier-3 generator therefore
changes nothing while still costing `BOOST_COST` (120🪙) and burning its `BOOST_TAPS` (10).
Boost value by tier (ΔEV items/tap): +0.90 (t1) · +0.50 (t2) · **+0.00 (t3)**.

## Decision

Boosted odds become **per-tier**, parallel to the unboosted table:

```gdscript
const GEN_TIER_BURST_ODDS_BOOST := [
    [0.20, 0.45, 0.35],          # tier 1 — the pre-T64 flat boost table (live tuning preserved)
    [0.20, 0.45, 0.35],          # tier 2 — unchanged live behavior
    [0.10, 0.30, 0.40, 0.20],    # tier 3 — 4th burst slot; only a boosted top-tier gen pops 4
]
```

- EV items/tap: unboosted 1.25 / 1.65 / 2.15 → boosted 2.15 / 2.15 / 2.70.
  Boost ΔEV +0.90 / +0.50 / +0.55 (≈ +9.0 / +5.0 / +5.5 items per 120🪙 activation of 10 taps).
- Invariant (test-guarded): every tier's boosted row sums to 1.0 and strictly beats its
  unboosted row on EV — the boost is never a no-op at any tier.
- Seam: `G.gen_burst_count(tier, rng, boosted := false)` picks the row (clamped to row
  length, so the boosted top row tops at 4); the board's charged pop passes
  `board.is_gen_boosted(cell)`. `_gen_boost_bonus` (board.gd) is removed.
- `burst_count(map, bonus, rng)` stays, unchanged, as the UNTIERED special-generator roll
  (boosted accumulator collect · treat pop · grove_sim); `BURST_ODDS` / `BURST_ODDS_BOOST`
  remain its tables. `BURST_MAX` (3) stays the flat tables' ceiling.
- RNG stream: both rolls draw exactly one `randf` per tap — stream-neutral swap.
- The tier-3 row odds are an owner pacing dial (one line to re-tune).

## Rejected

- **Refuse / discount the buy on tier-3:** deletes the §10 boost coin sink exactly at
  endgame, when all generators trend tier-3 and sinks matter most.
- **Accept + document:** a sold no-op; breaks the "multiples become the norm" promise the
  boost chip makes.
- **Boost = roll one tier up:** nerfs boosted t1 (EV 2.15 → 1.65) — a silent retune of live
  behavior, out of scope for a bug fix.
