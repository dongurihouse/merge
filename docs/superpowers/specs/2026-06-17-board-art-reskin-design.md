# Board art reskin — design

**Date:** 2026-06-17
**Scope:** Reskin the board scene (`engine/scripts/scenes/board.gd`) with a new hand-painted UI
kit, keeping every live system working. Match the *look* of the reference mockup
(`assets/board/board.png`), not its simplified layout.

## Source images (`assets/board/`)

- `board.png` — composed target look (reference only, not shipped).
- `board_bg.png` — full backdrop **with** a baked radish hero + squirrel market stall. **Not used**
  (the baked characters would collide with the live merchant/givers).
- `borad_bg_empty.png` — clean backdrop: sky, windmill, cottage, a wooden **fence rail**, flowery
  meadow. **This is the board backdrop.**
- `board_asset.png` — 1448×1086 transparent UI sheet holding every chrome piece.

## Decision summary

| Question | Decision |
|---|---|
| Fidelity | Reskin over the live systems; the mockup is the style target, not a literal layout. |
| Backdrop | `borad_bg_empty.png` (no baked characters). |
| Grid art | Grid frame cut as a nine-patch (corners preserved, interior cleared); real 7×9 cells drawn inside from the tile-slot sprite. |
| Currencies | clover→coins, acorn→stars, droplet→water; diamonds keep the existing gem icon; level number sits in the rope ring. |
| HUD scope | The top HUD is shared (`ui/hud.gd`) → the Map inherits the new wallet pill + level ring. Intentional, for consistency. |
| Bag / water-refill / Decorate gate | Kept and functional; restyled only where the kit makes it trivial, otherwise left as-is. |
| Merchant vs baked stall | Live merchant stand kept; backdrop has no baked stall now, so no conflict. |
| Inline bag row | Kept (live drag-to-bag); not collapsed into a nav button. |

## 1 — Asset processing

`board_asset.png` pieces sit on transparency, irregularly placed, so a uniform-grid slice fails.

**Tool:** `games/tools/slice_islands.gd` (headless `SceneTree` script). Extracts each connected
alpha-island (8-connectivity over pixels with `a > threshold`), trims to its bounding box, writes a
PNG per island, and prints `index → bbox (w×h)` so islands can be mapped to names. Filters specks
below a min-area. Run:

```
godot --headless --path . -s res://games/tools/slice_islands.gd -- assets/board/board_asset.png /tmp/board_slice/cell_
```

**Grid frame special-case:** the grid-panel island has a painted parchment interior + faint grid
lines. After extraction, clear its interior to transparent (keep the woven rope border ring), so it
nine-patches to a clean frame of any size. Done in a follow-up process step (`process_grid_frame`),
or by a dedicated helper in the slice tool.

**Mapping → `games/grove/assets/ui/kit/`** (the dir `skin.gd`'s `kit()` reads). Final names assigned
after inspecting printed bboxes:

| Island | Kit file | Use |
|---|---|---|
| rope ring | `ring_level.png` | level badge frame |
| long pill | `panel_pill.png` | resource/wallet bar |
| clover / acorn / droplet | `icon_coin.png` / `icon_star.png` / `icon_water.png` | currency icons (overwrite existing kit icons) |
| speech-bubble card | `card_quest.png` | quest-giver card background |
| big grid frame | `panel_grid.png` | nine-patch frame behind the grid (interior cleared) |
| tile slot | `slot_tile.png` | per-cell background |
| locked slot | `slot_locked.png` | locked-cell background |
| 5 finished buttons | `nav_home/shop/leaf/gear/bag.png` | bottom nav |
| green pill / round base | `btn_pill_green.png` / `btn_round.png` | gate CTA + round buttons |

Backdrop: `borad_bg_empty.png` copied to `games/grove/assets/ui/bg_grove_board2.png` (new name, so
the old flat field stays available as a fallback).

Each new `.png` needs a Godot `.import` (generated on first headless import pass).

## 2 — `board.gd` reskin, element by element

All systems stay; only the visuals change.

- **Backdrop** — replace `_field_backdrop()` (flat field) with `bg_grove_board2.png` as a
  `TextureRect`, `STRETCH_KEEP_ASPECT_COVERED`. Clouds + weather still drift over it.
- **Top HUD** (`ui/hud.gd`, shared) — wallet pill = `panel_pill.png` nine-patch; currency icons =
  the new clover/acorn/droplet; level chip = `ring_level.png` rope ring with the level number inside.
- **Grid** — `panel_grid.png` nine-patch frame sized to the 7×9 board; each cell = `slot_tile.png`,
  locked cells = `slot_locked.png`. Frame interior is transparent so the backdrop/parchment reads
  in the gutters.
- **Quest givers** (`ui/giver_stand.gd`) — card background = `card_quest.png` speech-bubble; busts,
  asks, ✓, bob, scrolling fence behaviour all unchanged.
- **Bottom nav** — a centered bar of the 5 new buttons: home / shop / leaf (=board, current) / gear /
  bag. Same actions as today (home→Map, shop→Shop, gear→Settings); leaf = current-scene indicator;
  bag opens/serves the bag.
- **Merchant** — live stand kept, restyled with the kit's card/button art.
- **Decorate gate CTA** — kept; restyled as the green-pill button (`btn_pill_green.png`).
- **Bag row, water-refill surfaces** — kept and functional; restyled only where trivial.

## 3 — Skin / tuning wiring

- Add the new kit names to `skin.gd` where it resolves panels/icons/buttons; set per-asset
  nine-patch texture margins (the kit pieces are ~512-source; margins tuned per piece, not the global
  `KIT_TEX_MARGIN` alone).
- Keep glyph fallbacks so a missing asset degrades to today's look (no hard breakage).

## 4 — Verification

- **Logic tests** stay green (headless `SceneTree` suites — no window):
  `godot --headless --path . -s res://engine/tests/<suite>.gd`.
- **Visual** — off-screen screenshot via the project's grove screenshot tool with the
  minimized/no-focus `override.cfg` (never steal focus). Compare composition against `board.png`;
  confirm every system renders (grid 7×9, givers, merchant, nav, HUD, bag, gate). Measured, not
  eyeballed.

## Honest divergences from the literal painting (forced by "keep systems")

- Grid is **7×9 in a frame**, not the painting's ~5×7.
- The **inline bag row** stays (live drag), where the painting shows none.
- Water-refill + Decorate-gate surfaces exist (painting omits them); kept, lightly restyled.
