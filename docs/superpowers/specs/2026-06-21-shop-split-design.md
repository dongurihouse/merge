# Split the shop into Water / Coin / Premium

**Date:** 2026-06-21
**Status:** Approved

## Goal

Replace the single unified storefront (`engine/scripts/ui/shop.gd`, `Shop.open`) with three
focused shops — **Water**, **Coin**, **Premium** — each holding only its corresponding items,
each reached from its own entry point.

## Item split (by what each shop GRANTS)

| Shop | Banner | Cards |
|------|--------|-------|
| **Water** | "Water" | Fill water (costs 💎) — gated on `water_grant`, as today |
| **Coin** | "Coins" | Coin pouch (grants coins) + coin-priced shortcuts: Wildflower, Garden tools, Mushroom |
| **Premium** | "Acorns" | 💎-priced shortcut (Honey) + Welcome gift (starter bundle) + cash→💎 Acorn-pouch ladder |

Each card lands where the thing it grants belongs, regardless of the currency it is paid in
(so the Coin pouch and Fill water — both paid in 💎 — sit in the Coin and Water shops by
what they hand back).

## Architecture

One `shop.gd`, parametrized by `kind ∈ {"water","coin","premium"}`. Each shop is the same
dialog (one set of buy flows, confirm dialogs, kit chrome, blurred backdrop) with a filtered
section list and its own banner title. Keeps the "one recipe" ethos; the buy/confirm/feedback
machinery is untouched.

### shop.gd

- New public entries: `open_water(host, opts)`, `open_coin(host, opts)`, `open_premium(host, opts)`.
  Each sets `opts.kind` and forwards to a private `_open(host, opts, kind)` — today's `open`
  body, generalized. `kind` is carried into `refs`.
- `_sections(refs)` reads `refs.kind` and builds only that shop's cards (table above).
- Offer selection moves from "first `SHOP_FEATURED_COUNT` of `SHOP_ITEM_OFFERS`" to a currency
  filter: `offers_for(currency)` returns the offers paid in that currency, capped at
  `SHOP_FEATURED_COUNT`. Coin shop uses `"coins"`, Premium uses `"diamonds"`. This is what puts
  Honey into Premium — it currently never shows, since it sits past the fixed featured slice.

### hud.gd

- `Hud.build` returns three open callables — `open_coin`, `open_premium`, `open_water` —
  closures over the same `shop_opts` (so wallet / refresh / water_grant wiring stays in one place).
- Per-pill "+" wiring: **coin pill → coin shop**, **gem pill → premium shop**,
  **star pill → premium shop** (stars are not purchasable).
- `_pill` takes the specific open callable for its pill.

### board.gd

- The top-left water meter gains a small green "+" mirroring the currency pills, wired via
  `Button.pressed` (avoids the touch-emulation double-fire documented in `hud.gd`), opening the
  **water shop** via `hud.open_water`.
- `_build_hud` runs before `_build_water_hud`, so the open-water callable is stored on a board
  field (`_open_water`) in `_build_hud` for the meter to consume.

### map.gd

- The "new offer" badge (lit while the starter pack is unclaimed) moves from the coin pill to the
  **gem pill** (`hud.gem_plus`), because the Welcome gift now lives in the Premium shop — the dot
  should point at the shop that actually carries the offer.

### Cleanup

- `_open_shop` (board + map) is a now-unused remnant after the FTUE-spotlight removal; repoint it
  to `open_premium` rather than leave a dangling generic-shop reference.

## Edge cases

- Water shop opened without `water_grant` renders empty-but-valid. In practice it is only reachable
  from the board, which always passes `water_grant`.

## Testing

- `grove_ui_tests.gd` §17: instead of asserting one combined row count, assert per shop —
  - Water: 1 row (Fill water) with `water_grant`; 0 without it.
  - Coin: Coin pouch + 3 coin shortcuts; no 💎-ladder / cash card present.
  - Premium: Honey + acorn ladder (+ Welcome gift when unclaimed); no coin-priced card present.
- Pure-grant tests (`buy_coin_pack`, `grant_cash_pack`, `buy_water`) unchanged.
- Run `make test-grove`, then the full `make test`.
