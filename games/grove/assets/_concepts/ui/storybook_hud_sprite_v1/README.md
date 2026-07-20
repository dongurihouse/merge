# Storybook HUD sprite sheet

`storybook_hud_5x4.png` is a transparent 5-column × 4-row sprite atlas. Its canvas is exactly
`1400 × 1120`; every cell is `280 × 280`.

## Grid map

| Row | Cells, left to right |
| --- | --- |
| 0 | water plate · coin plate · acorn plate · leaf plate · berry plate |
| 1 | flower rosette · star flower · flower + leaf · sunburst · laurel seal |
| 2 | scallop tab · ticket tab · arch plaque · folded-corner tab · leaf-edged oval tab |
| 3 | Home · Board · Explore · Bag · Shop |

Currency plates include their icon and green `+` tab, but keep their centre-right number field empty
for runtime text. Level badges have blank cream centers. Side-screen backplates contain no icon or text.

## Files

- `storybook_hud_5x4.png` — transparent, grid-aligned delivery atlas.
- `storybook_hud_5x4_raw.png` — original 5×4 source generated on a flat magenta key.
- `prompt.txt` — source-generation contract.

This is an art-direction asset pack. It is not yet wired into runtime UI.
