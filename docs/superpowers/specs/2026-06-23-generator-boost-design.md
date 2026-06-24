# Temporary generator boost — design

## Problem

Today's "Boost" is a *permanent, global* burst upgrade: a 4-level coin ladder
(`BURST_UPGRADE_COSTS = [120, 360, 840, 1800]`) where each bought level permanently
adds +1 item to every generator tap on every map, forever. There is no active state,
no duration, no on-board indication, and the chip simply hides once maxed.

The desired feature is a *temporary, turns-limited* booster: activate one booster, it
boosts the board for a number of taps, then expires.

## Decisions (locked with the user)

- **Model:** temporary, turns-based. A "turn" = one generator tap (water-pop).
- **Scope:** global — while active, *every* generator on the board is boosted.
- **Numbers:** cost **120 coins**, **+2 items per tap**, lasts **10 taps**.
- **Indicator:** generator sparkle (reuse `gen_sparkle`) + a small corner badge on each
  generator showing taps remaining, while the boost is live.

## Mechanic

State lives in the grove save under a single key `boost_taps` (int, taps remaining;
replaces the old `burst_lvl`). The boost is *active* when `boost_taps > 0`.

- **Activate** (info-bar Boost chip on a selected generator): if already active → no-op
  refusal; if broke → no-op refusal; else spend `BOOST_COST`, set `boost_taps = BOOST_TAPS`.
- **Apply:** the existing `burst_count(map, paid_addend, rng)` already adds a "paid" amount
  on top of the free base burst. The addend source changes from a persisted level to
  `BOOST_BONUS` while active, else `0`. The free base burst (base roll + per-map scale-up)
  is unchanged.
- **Decay:** each charged generator tap that actually pops a burst consumes one tap
  (`boost_taps -= 1`). At 0 the boost ends.

`BURST_MAX` drops from 8 to `BURST_FREE_MAX + BOOST_BONUS` = 6 (the paid ceiling now is the
single boost bonus, not a 4-level stack).

## Engine seams (`content.gd`, backed by `grove_data.gd` constants)

Replace the 4-level ladder API with a boost API:

- `boost_cost() -> int` → `BOOST_COST`
- `boost_bonus() -> int` → `BOOST_BONUS` (extra items/tap while active)
- `boost_taps_left() -> int` → `Save.grove().get("boost_taps", 0)`
- `boost_active() -> bool` → `boost_taps_left() > 0`
- `try_activate_boost() -> bool` → refuse if already active or broke; else spend + set taps + persist
- `consume_boost_tap() -> void` → if active, decrement + persist

`burst_count` keeps its signature; the paid addend is clamped to `[0, BOOST_BONUS]`.

Removed: `burst_upgrade_cost`, `burst_upgrade_max`, `burst_level`, `try_upgrade_burst`,
`BURST_UPGRADE_COSTS`.

## UI (`board.gd`)

- `_gen_boost_bonus()` (was `_gen_burst_level`) → `boost_bonus()` when active, else 0.
- `_pop_seed`: after a charged burst pops, `consume_boost_tap()`, then refresh the chip,
  the on-board indicator, and (if a generator is selected) the info-bar label.
- `_refresh_burst_chip` → drives the single boost chip: full when affordable & inactive,
  dimmed when broke, **dimmed + inert while active** (can't re-buy mid-boost). Never hidden.
- `_on_burst_chip`: active → soft refusal; broke → existing nudge; else activate.
- `_select_generator`: when active, the info label reads
  `"<name> · ⚡ +<bonus>/tap · <taps> left"` instead of just `<name>`.
- `_refresh_boost_indicator()`: iterate `gen_nodes`; while active, overlay a `gen_sparkle`
  + a small taps-left badge on each generator; remove the overlay when inactive. Called
  from `_rebuild_all`, on activation, and on each pop.

## Removed surfaces

- The water-shop Boost card (`_burst_card` / `_flow_burst` in `shop.gd`) — one entry point,
  the info-bar chip. Its `shop.burst.*` strings become dead and are removed.

## Tests

- `grove_economy_tests`: rewrite the burst-upgrade cases to the boost seam — activation
  spends + sets taps; re-activation while active is refused (no double spend); broke is
  refused; `consume_boost_tap` decays to 0; `burst_count` adds `+BOOST_BONUS` while active,
  capped at `BURST_MAX`.
- `grove_ui_tests`: drop the "burst card present on fresh save" assertion (card removed).
- `grove_sim.gd`: stop referencing the removed ladder constants.
- Verify the on-board indicator visually (screenshot of an active boost) — not eyeballed
  from memory.
