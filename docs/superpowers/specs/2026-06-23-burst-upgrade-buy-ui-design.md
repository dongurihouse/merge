# Burst-upgrade buy UI — re-surfacing the §6/§10 coin sink (T54)

*2026-06-23 · follows T48 (the dark `stat_chip` pill retirement) + the UI-language redesign
(T50/T51). The burst coin sink stayed in code through T48; this gives it a buy affordance again
in the new cream-chip language.*

## The sink (unchanged, intact)

One **global** `burst_lvl` (in the grove blob) sizes every generator's tap-burst on every map.
- `content.gd` `burst_count(map, lvl, rng)` — free per-map roll + the paid `lvl` added on top.
- `content.gd` `burst_upgrade_cost(lvl)` → next cost or `-1` when maxed.
- `BURST_UPGRADE_COSTS = [120, 360, 840, 1800]` (coins; L0→1 … L3→4), max level 4.
- `board.gd` `_gen_burst_level()` / `_upgrade_gen_burst()` — read + buy (spend + cap + persist).

Only the **buy affordance** was missing after T48.

## Decision — two surfaces (Dev call, 2026-06-23)

The Dev rejected a persistent on-board chip (the board was deliberately decluttered in the
redesign, and the on-board pill was what T48 removed). The buy lives on **two contextual
surfaces**:

### 1. The board info bar, on a generator tap (primary)

The bottom info bar `[ⓘ] [piece + name] [action]` is the board's contextual "what did I tap"
read. Tapping an **item** fills it (preview · name · tiers · **sell**); tapping the **generator**
pops (the core loop) and previously left the bar empty.

Change: a still-tap on the generator now **also selects it into the info bar** (after the pop),
and the **action slot** — which is empty for a generator, since generators can't be sold — holds
the **burst-upgrade chip** instead of the sell button. This is the "limited space" answer: it
reuses the slot that's already free for generators, adding **zero** new board chrome.

The chip mirrors the sell button's `[glyph] N [coin]` shape (a sprout glyph + next cost + coin),
in the Rest-plane cream language, and follows the gate-CTA **affordability** pattern:
- **Affordable** (coins ≥ next cost): full-saturation, tappable → buy → success juice (FX pop on
  the generator + a "Bigger bursts!" floater + audio) → re-select to show the next cost.
- **Unaffordable**: dimmed (cost shown as a goal); tap → "need more" wobble + soft-invalid audio
  (no spend).
- **Maxed**: a quiet "Max" read, not tappable (so the player sees it's fully bought, not blank).

### 2. The water shop card

A burst-upgrade card in the **water stall** (`shop.gd` `_water_sections`, reached from the water
pill's `+`). The Dev's framing: burst makes each **water-pop** produce more, so "make your water
go further" sits with water. The card is coin-priced (`price_icon: "coin"`), shows the next cost,
and is disabled/maxed-stated like every other shop card. Reuses the existing card schema +
buy-feedback (wallet wiggle on broke, fly-home on success, storefront rebuild to the next cost).

## Architecture — one upgrade function, two callers

To avoid duplicating the spend, the canonical buy moves to **`content.gd`**
(`G.try_upgrade_burst()` — spend the next cost, bump `burst_lvl`, persist; returns false when
broke or maxed). It joins `burst_count`/`burst_upgrade_cost` there (content.gd already does
Save-backed economy mutations for residents). `board.gd._upgrade_gen_burst()` becomes a thin
delegate (keeps its name — tests + the info-bar chip call it); `shop.gd` calls `G.try_upgrade_burst()`
directly. One spend path, unit-tested once at the seam.

## Acceptance

- Tapping the info-bar burst chip (generator selected) raises `burst_lvl` + spends the ladder
  cost; refuses cleanly (wobble, no debt) when broke; reads "Max" when maxed.
- The water-shop burst card buys the same way and rebuilds to the next cost.
- `G.try_upgrade_burst()` spends/stacks/caps/persists/broke-refuses (unit test).
- Visuals verified by composite capture, not eyeball: the info bar with a generator selected
  (the chip in affordable + maxed states) and the water shop with the burst card.
