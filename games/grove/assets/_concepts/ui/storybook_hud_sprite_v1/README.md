# Storybook HUD sprite sheet

`storybook_hud_controls_v2.png` is the current transparent 5-column × 5-row sprite atlas. Its canvas
is exactly `1250 × 1250`; every cell is `250 × 250`. It supersedes the earlier `storybook_hud_5x4.png`
exploration.

## Grid map

| Row | Cells, left to right |
| --- | --- |
| 0 | water plate · coin plate · acorn plate · leaf plate · berry plate; all include a visible `+` tab and an empty wide runtime text zone |
| 1 | flower rosette · star flower · flower + leaf · sunburst · laurel seal |
| 2 | scallop tab · ticket tab · arch plaque · folded-corner tab · leaf-edged oval tab |
| 3 | dark slate utility card · dark slate tall card · dark slate hex plaque · dark slate clipped-corner card · dark slate ticket card |
| 4 | Map · Kin · Daily · Mail · PLAY |

Currency plates include their icon and green `+` tab, but keep their centre-right number field empty
for long runtime text. Level badges have blank cream centers. Cream and slate side-screen backplates
contain no icon or text. **All delivered sprites are shadow-free**; add any runtime shadow separately.

## Files

- `storybook_hud_controls_v2.png` — transparent, grid-aligned delivery atlas.
- `storybook_hud_controls_v2_raw.png` — original 5×5 source generated on a flat magenta key.
- `storybook_hud_controls_v2.prompt.txt` — source-generation contract.
- `storybook_hud_5x4.png` and its raw source — earlier exploration, retained for reference only.

This is an art-direction asset pack. It is not yet wired into runtime UI.
