# HUD level badge v3

New top-left level badge for the Meadow Sky / Cut-Paper Playground HUD.

## Design

- Mint scalloped rosette connects the HUD badge to the Level dialog.
- Warm-cream ring separates it from the blue screen background.
- Sky-blue center is deliberately empty for a runtime-rendered level number.
- Small gold star crown preserves the existing level/star association without competing with the number.
- Leaves, flowers, and ribbons are omitted so the silhouette remains readable around 96-120 screen pixels.

## Files

- `level_badge_base_master_1254.png`: transparent source-resolution master.
- `level_badge_base_1024.png`: large transparent export.
- `level_badge_base_512.png`: standard transparent export.
- `level_badge_base_256.png`: HUD-ready transparent export.
- `level_badge_board_preview_v3.png`: in-context board preview with sample level 2.
- `level_badge_source_magenta.png`: original generated chroma-key source.
- `prompt-used.txt`: generation and refinement brief.

The numeral is not baked into the production asset. Render it at runtime in warm cream with a dark-navy edge or shadow, centered slightly below the geometric center to account for the star crown.
