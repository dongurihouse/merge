# Board scene reskin — design

> **Superseded (2026-06-20):** the girl / farmer / dog giver portraits (`board_asset.png`
> islands 48/49/50) were retired. Quest givers now draw from a 16-creature pool
> `characters/giver_0..15.png` (sliced from `characters_1.png`), keyed off the quest line —
> see `giver_stand.gd` / `bust.gd`. The giver references below are historical.

**Date:** 2026-06-19 · **Worktree:** `worktree-board-reskin` · **Source art:** `_new/board.png`
(composed reference, not shipped) + `_new/board_asset.png` (1448×1086, baked near-white
`#F4F5F6` background — the sliceable sheet).

## Goal

Reskin the board scene to match `board.png`. Four named deltas, plus a full-match pass on the
surrounding chrome:

1. **Quest look** — new vine-framed giver card + three character portraits.
2. **Transition between quest and board** — a wooden **branch divider** between the quest fence
   and the grid (clarified with the user: not the tier ladder; that is a separate drop with no
   `_asset.png` yet and is out of scope here).
3. **Bottom button icons** — new round wood nav buttons.
4. **Board border** — new wood-plank frame.

User decisions: keep the current background (`bg_grove_board2.png`); make Bag + Merchant **round
wood buttons** (keep their drag-drop behavior + preview overlays).

## Approach

Follow the asset-intake pipeline for the clean single islands; use bespoke crops for the two
pieces island-slicing can't deliver cleanly (the modular frame and the card with a baked reward).
Code changes are limited to: one new node (branch divider), reshaping the bag/merchant nav wells
into round buttons, giver-card anchor tuning, and nine-patch/`FRAME_*` constant tuning.

## Island map (`board_asset.png`)

| Island | Piece | Target |
|---|---|---|
| 31 | market stall | `ui/nav/nav_shop.png` |
| 37 | gear | `ui/nav/nav_gear.png` |
| 38 | house | `ui/nav/nav_home.png` |
| 39 | satchel | `ui/nav/nav_bag.png` |
| 40 | coin sack | `ui/nav/nav_merchant.png` (new) |
| 48 / 49 / 50 | girl / farmer / dog | `characters/giver_0/1/2.png` |
| 18 | long leafy branch | `ui/board/branch_divider.png` (new) |
| 24 / 25 / 26 | cell empty / locked / active | `ui/board/slot_tile.png` / `slot_locked.png` / `slot_active.png` (new) |
| 1 | wood banner | `ui/shared/panel_pill.png` (HUD cluster) — full-match |
| 0 | level medallion "1" | `ui/lvl/badge_00.png` — full-match |
| flower/coin/acorn | currency icons | `ui/shared/icon_star.png`, `ui/currency/coin.png`, `ui/currency/gem.png` — full-match |

**Bespoke crops (not clean islands):**
- **Board frame** — crop the complete framed panel (wood planks + leafy corners + parchment
  center, ≈ `x[15:635] y[535:870]`), clear the interior to transparent via
  `process_grid_frame.py`, save `ui/board/panel_grid.png`. Tune `FRAME_OUT` / `FRAME_MARGIN`.
- **Quest card** — crop card template (island 8), erase the baked "+25 🌸" reward (engine draws
  the reward as text), save `ui/quest/card_quest.png`.

## Code changes (`board.gd` + ui/)

- `board.gd` — add a branch-divider `TextureRect` in the root VBox between the giver fence and
  the grid; reshape `_make_bag_button` / `_make_merchant_button` from square slot-wells into round
  wood buttons (new art) keeping drop-target + preview overlay; tune `FRAME_OUT`/`FRAME_MARGIN`.
- `giver_stand.gd` — retune bust/item/`bub` anchors + reward position to the new card's portrait
  socket and item panel; cycle all three portraits (`qi % 3`).
- `bust.gd` — point the portrait names at `giver_0/1/2.png`.

## Verification

`make test` green (engine + grove suites). Visual: `make shot-grove` (board) and `make shot-map`
(the HUD/nav are shared modules — confirm the map screen still reads well after the banner/icon
swaps). Then merge `worktree-board-reskin` back into `main` from the primary tree, `--import`.

## Sequencing

Phase 1 = the four named items + portraits (verify with a board shot). Phase 2 = full-match extras
(cells, HUD banner/icons, level badge; re-verify board + map).

## Outcome (2026-06-19)

Done, both scenes verified (`make test` 24 suites · 1017 passed):

- **#1 quest look** — new vine-framed card (island 8, baked "+25" erased) + portraits (girl/farmer/dog);
  `giver_stand` retuned to the oval socket / item panel / reward pill; busts cycle `qi % 3`.
- **#2 branch divider** — island 18 as a nine-patch band between the fence and the grid;
  `DIVIDER_H` reserved in the `csz` height budget so the grid still clears the bottom nav.
- **#3 bottom buttons** — five round wood buttons (shop/gear/home + bag/merchant reshaped from
  square wells, drop-targets + previews kept). `grove_placement_tests` updated to the new design.
- **#4 board border** — `panel_grid.png` composited from the kit's corner+plank parts
  (`build_board_frame.py`), nine-patch margin 108.
- **Full-match** — cells (slot_tile/locked/active), and the HUD wood banner (island 1 → `panel_pill.png`,
  fit to the 65px nine-patch slot) + currency icons (flower/coin/acorn) + green check (island 12).

**Deferred (technical constraint, not done):** the level-badge medallion (island 0). The HUD badge is
an evolving 16-rung ladder (`badge_00`–`15` from `lvls.png`); this drop has only one medallion, and its
center is opaque (baked "1" + flower) where `make_level_badge` needs a transparent ring. Swapping only
`badge_00` would clash with rungs 1–15. A faithful badge reskin needs the full ladder as its own drop.
