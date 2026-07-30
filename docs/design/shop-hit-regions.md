# The shop's hit regions: mock → regions → overlay

The shop screen IS the concept painting. The game draws nothing on it; it lays transparent hit rects
over it, measured from the art. This is the loop that authors those rects and proves each one hits the
purchase it sits on. Run it whenever the storefront art changes or a new shop element is added.

For art direction and intake see `docs/design/art-style-guide.md`; for like-for-like mock measurement,
`docs/design/verifying-against-a-mock.md`.

## The split

Scripts are deterministic — they scan pixels, build the screen, probe the picker. All judgement (which
anchor is which offer, where a seam goes, how far a region may open past the art) lives in the registry
JSON, authored by hand from the scan.

| file | what it owns |
| --- | --- |
| `games/grove/assets/ui/dialogs/shop/storefront_market_stall.png` | the storefront: every pixel the player sees |
| `…/storefront_market_stall.regions.json` | ALL judgement: one rect per offer id, in the picture's own px, plus the `unplaceable` block |
| `games/grove/tools/measure_shop_screen.py` | the deterministic scan: finds the price plates, tags, planks, gutters, close disc |
| `engine/scripts/ui/shop_screen.gd` | ships: puts the picture up, lays the rects on it, stamps the metas |
| `engine/scripts/ui/shop.gd` | ships: the offer ids and what pressing one does |
| `engine/tools/shop_hit_overlay.gd` | the overlay — **a tool, excluded from the shipped pack**; probes the engine's own picker and draws what it answers |
| `games/grove/tools/map_shot.gd` (`shophits`) | composes that overlay over the storefront it just opened |
| `games/grove/tools/tests/test_shop_screen_regions.py` | re-measures the registry against the PNG on every `make test-config` |
| `games/grove/tests/grove_shop_tests.gd` | region ↔ purchase per tier, the overlay's picker check, the unlabelled-region catch, the close region |

## The loop

```bash
# 1. MEASURE the art. Prints every anchor; --check also diffs the registry against them.
PYTHONPATH=. python3 games/grove/tools/measure_shop_screen.py
PYTHONPATH=. python3 games/grove/tools/measure_shop_screen.py --check

# 2. WRITE the regions by hand into storefront_market_stall.regions.json (picture px, ids from shop.gd).

# 3. RENDER the overlay over the real screen.
make shot-map MODE=shophits OUT=/tmp/hits.png

# 4. ASSERT, headless.
make test-config                                        # the registry re-measure
make test-one SUITE=games/grove/tests/grove_shop_tests   # region ↔ purchase, overlay, close ✕
```

## Reading `hits.png`

| mark | means |
| --- | --- |
| green rect + id | shelf cell; the id is the offer it declares AND what the picker returned |
| blue rect + id | the price plate on top of that cell, same offer |
| amber dashed rect + ring | the close ✕: dashed = the tap region, ring = the disc the picture draws, amber between = tap area the art does not show |
| RED rect, `declared → resolved` | the region resolves to something else. This is the failure the overlay exists to show |
| white `×` + legend line | a probe that hit NO region, and what it hit instead (on this screen: the modal's veil, which dismisses) |

## Rules

1. The overlay never ships. It lives under `engine/tools/`, which `export_presets.cfg` excludes from
   the pack; no shipped script may name it. `engine/tests/layering_tests.gd` fails if one does.
2. The capture composes it — there is no runtime flag. Mounting IS the arming:
   `HitOverlay.mount(<the shop's modal>, <the built ShopScreen>)`, in the frame the shop opened.
3. The metas stay in the game: `shop_slot`, `shop_offer`, `shop_close`, `shop_close_drawn` (plus
   `shop_buy` / `shop_cash`, used by other capture tooling). They are the contract that makes this loop
   re-runnable, and they are a few bytes. Do not strip them.
4. A label is never typed twice. `shop_offer` is stamped from the same card dictionary that supplies
   `on_buy`, so the overlay's label and the purchase cannot disagree.
5. The overlay reports the ENGINE's picker (`Viewport.gui_get_hovered_control` after a pushed
   `InputEventMouseMotion`), five points per region — never a rectangle intersection of its own. A
   centre-only probe passes a region whose edges a neighbour has stolen.
6. Order is load-bearing in `shop_screen.gd`: the eight cells go down first and tile without
   overlapping; the eight price rects go on top. A price plate that hangs below its own shelf keeps its
   taps that way.
7. Off-region probes are part of the picture. The painting stops no taps of its own, so most of this
   screen is the modal's veil — drawing only the offers shows a screen that looks nine-tenths inert.
8. An offer with no region is not silently dropped: it is stamped on the built screen as `shop_unplaced`
   and listed in the registry's `unplaceable` block. `grove_shop_tests.gd` fails when that set changes.

## Adding a shop element

1. New art → intake (art-style-guide.md), replacing `storefront_market_stall.png`.
2. `measure_shop_screen.py` → the new anchors.
3. Give the offer an id in `shop.gd` (`OFFER_*` / `cash_offer_id`), a section entry, and a region under
   that same id in the registry. An offer id with no region is `unplaceable`; a region id no offer emits
   is dead.
4. `make shot-map MODE=shophits` — the new cell must be green and named, and no region red.
5. Extend the per-tier assertions in `grove_shop_tests.gd`; the counts there (8 cells, 8 plates, 1 ✕)
   are asserted literally and must move with the art.
