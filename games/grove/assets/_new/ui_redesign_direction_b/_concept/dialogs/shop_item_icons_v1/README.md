# Shop Item Icons v1

Production-ready Cut-Paper Playground icons for the unified shop dialog. The
transparent sprite sheet is arranged as a 3 x 3 grid of 512 px cells. Each icon
is also exported as a separate transparent 512 x 512 master.

## Sprite mapping

| Row | Column | Asset | Shop use |
| --- | --- | --- | --- |
| 1 | 1 | `watering_can_512.png` | Free and paid water fills |
| 1 | 2 | `coin_pouch_512.png` | Coin bundle |
| 1 | 3 | `acorn_currency_512.png` | Acorn currency glyph |
| 2 | 1 | `acorn_pack_80_512.png` | 80 acorns |
| 2 | 2 | `acorn_pack_450_512.png` | 450 acorns |
| 2 | 3 | `acorn_pack_1000_512.png` | 1,000 acorns |
| 3 | 1 | `acorn_pack_2200_512.png` | 2,200 acorns |
| 3 | 2 | `acorn_pack_6000_512.png` | 6,000 acorns |
| 3 | 3 | `acorn_pack_13000_512.png` | 13,000 acorns |

## Files

- `shop_item_icons_sheet_1536.png`: transparent 1536 x 1536 sprite sheet.
- `final_frames/`: transparent individual 512 x 512 masters.
- `source/raw-sheet.png`: original flat-magenta generation source.
- `prompt-used.txt`: generation and revision prompts.
- `manifest.json`: machine-readable cell and file mapping.

## Art and export rules

- Meadow Sky palette and Cut-Paper Playground material language.
- Simple, centered silhouettes with a consistent visual footprint.
- Containers use a few explicit acorns plus one broad implied fill mass; higher
  values change the container silhouette instead of adding visual clutter.
- Transparent outputs have no baked scene, floor, text, UI, or cast shadow.
- The source is keyed on flat magenta; final exports are edge-eroded and
  despilled for clean in-game compositing.

## QC

- Sprite: 1536 x 1536 RGBA.
- Frames: 512 x 512 RGBA.
- Cell-boundary contacts: 0.
- Visible magenta fringe pixels: 0.
- Opaque canvas-edge pixels: 0.
- Non-zero RGB outside alpha: 0.

These are concept assets and are not wired into the runtime shop yet.
