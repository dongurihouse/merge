# Buy an item from the board info bar (T55)

*2026-06-23 · follows the shop's item-shortcut removal (`9ce053d`, "take item-buying out of the
shop") and reuses the T54 info-bar chip pattern. Owner directive: item-buying belongs on the
board, not the store.*

## What

Tapping a regular board item selects it into the info bar (already true — preview + name + sell).
This adds a **Buy** chip beside the sell button: buy a *copy* of that item and drop it on the
board (the bag when the board is full). The chip is the T54 action-chip recipe (caption over a
green badge with a currency icon + number), so the bar reads one button language:

`ⓘ · [sprite] · "Wildflower · Tier 4" · [Buy 🪙12] · [Sell 🪙4]`

- Affordable → full green, tap buys + places (pop-in + "Bought!" floater). Broke → dimmed, tap →
  wobble + "Need more". Board AND bag full → wobble + "No room!" (no spend).
- Shown only for a **sellable** item (a generator shows the burst chip instead; a raw coin shows
  nothing).

## Pricing — mirror selling + markup (Dev call)

The game had no general buy price (only `sell_reward` + a since-removed curated list). Decision:

`G.buy_price(code) = ceil(sell_reward(code) × BUY_MARKUP)` — same currency split as selling
(**coins** for sub-top tiers scaled by the map band, **💎** for the top tier), marked up over the
sell value. Because `BUY_MARKUP > 1` and we ceil, **buying always costs strictly more than selling
returns** — the buy-low/sell-high loop is impossible by construction (the same anti-arbitrage
discipline `sell_reward` keeps). `BUY_MARKUP = 3.0` is an owner/sim feel dial (`grove_data.gd`).

This honors §4 ("premium buys speed, not possibility"): you can only buy a copy of an item already
on your board — something you can already make, never a gate to a new tier.

## Architecture

- `content.gd` `buy_price(code)` joins `sell_reward` (the economy layer); `BUY_MARKUP` re-exported
  from `grove_data.gd`.
- `board.gd` — the T54 burst-chip builder was extracted to a shared `_build_action_chip(opts, row,
  caption, on_press)`; both the burst chip and the new buy chip build from it (one recipe). The buy
  chip sits just left of the sell button; `_select_item` shows+refreshes it for sellable items,
  `_select_generator` / `_clear_selection` hide it. `_on_buy_pressed` picks a destination (first
  empty board cell, else bag), refuses with no spend if there's no room, else spends the currency
  and places a live copy.

## Acceptance

- A sellable item shows Buy + Sell; a generator shows neither (its action is Boost); a coin shows
  nothing.
- Tapping Buy spends `buy_price` (coins or 💎) and drops one copy on the board (bag if full);
  refuses cleanly when broke or out of room.
- `buy_price` mirrors the sell currency split and is strictly > sell for every tier (anti-arbitrage).

## Parked

- **Buying a *bag* item.** The info bar populates from board taps; the bag is a separate overlay.
  Buying a copy of a bagged item would need the bag overlay to route into the info bar — a small
  follow-up, out of this task's scope.
