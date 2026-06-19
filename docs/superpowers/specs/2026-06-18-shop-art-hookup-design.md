# Shop art intake + screen hookup — design

Date: 2026-06-18. Approved approach: **re-skin + shared panel** (keep all sections,
prices, and tested buy-logic; only the *look* changes).

## Goal

Two steps the `bag_asset.png` drop only did the first half of (sliced, never wired):

1. **Process** `games/grove/assets/_new/shop_asset.png` — a UI-kit sheet baked on a
   cyan chroma background — into named, alpha-cut PNG pieces.
2. **Hook up** `engine/scripts/ui/shop.gd` so the storefront renders with those pieces,
   matching the `shop.png` mockup. `shop.png` is the composed reference (not shipped).

## Intake

`shop.plan.json` — `category: matte`, `inner: sheet`, `params {key:#40C8F5, tol:0.30,
min_area:3000, pad:4}` (mirrors the `bag` plan; verified to yield 17 clean islands).
tol bumped 0.22 → **0.30** after the first pass left a teal chroma-blend hairline on the
close disc's wooden ring; 0.30 clears it and still keeps the teal water droplet (island 13)
intact, while 0.40 erodes the droplet enough to drop it and shift the island indices.
Island → file:

| Island | Piece | Path |
|---|---|---|
| 0 | main parchment panel | `ui/shared/panel_parchment.png` (**promoted to shared kit**) |
| 1 | gold ribbon banner | `ui/shop/shop_banner.png` |
| 2 | thin tan plank pill | `ui/kit/shop_plank.png` |
| 3 | wide panel | `ui/kit/shop_card_wide.png` |
| 4 | square card | `ui/kit/shop_card.png` |
| 5 | square card (variant) | `ui/kit/shop_card_b.png` |
| 6 | wooden oval base | `ui/kit/shop_oval.png` |
| 7 | green button | `ui/kit/shop_buy.png` |
| 8 | grey/disabled button | `ui/kit/shop_buy_off.png` |
| 9 | cream label plate | `ui/kit/shop_plate.png` |
| 10 | red ✕ disc | `ui/kit/shop_close.png` |
| 11 | acorn icon | `ui/kit/shop_acorn.png` |
| 12 | red ribbon tag | `ui/kit/shop_tag.png` |
| 13 | water droplet | `ui/kit/shop_droplet.png` |
| 14 | leaf sprig | `ui/kit/shop_leaf.png` |
| 15 | white daisy | `ui/kit/shop_daisy.png` |
| 16 | pink flower | `ui/kit/shop_flower.png` |

Raws archived to `_originals/ui/`; `shop.png` reference archived alongside (not shipped).

## Hookup (the slots in `shop.gd` / `skin.gd`)

- **Shared parchment panel** ← island 0 at `ui/shared/panel_parchment.png` (this REPLACES the
  prior shared panel art). `kit_panel("parchment")` already prefers this path, so the shop
  card, confirm dialogs, info sheets, bag overlay — every parchment modal — pick it up at once.
  `Tune.KIT_TEX_MARGIN` (96) verified against the shop card AND a small confirm dialog (the
  worst case for the nine-patch) — the decorated frame holds, no corner smear, no collapse.
- **Title banner** ← island 1. The shop header swaps its plank/stall art for the gold
  ribbon banner behind the engine "Shop" text (images never carry words — §0.3).
- **Card backgrounds** ← islands 4/3. `_card_button` (help/featured/gem) and the wide
  `_starter_card` gain a textured surface, kept behind a fallback to today's StyleBox.
- **Buy pill** ← island 7 (green). `_price_pill` renders on the leaf-green button art (wide-H /
  small-V nine-patch margin so short pills don't collapse), fallback = the solid green capsule.
- **Close ✕** ← island 10. The procedural red disc becomes the art disc. A ROUND button is
  FULL-STRETCHED (zero texture margin), NOT nine-patched — 9-slicing a disc keeps its
  transparent corners and pinches the ring into a star, leaking the backdrop through.
- **"Popular"/"Best value"/"2×" badge** ← island 12 (red ribbon). `_badge`.
- Currency (11/13), supporting (2/6/8/9) and decoration (14–16) pieces are filed for use;
  wired only where a slot cleanly fits without app-wide side effects.

Every art slot keeps its existing code-drawn fallback, so a missing/!imported sprite never
breaks the screen — the §-kit invariant.

## Verification

- `make test` green (engine + grove; `grove_shop_ads_tests` covers buy-logic, untouched).
- Visual: capture the shop and confirm it reads like `shop.png` (panel, banner, cards,
  green buy pills, red ✕, Popular tag). Tune margins/pads from the capture, not by eye.
