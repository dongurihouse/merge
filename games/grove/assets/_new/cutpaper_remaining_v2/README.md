Cut-paper remaining-lines pass.

Generated and sliced into live `games/grove/assets/items/...` folders:
- `coin`: 12-tier line, source `item_lines_cutpaper_v2/coin/line_coin_v2.png`.
- `well_water`: 12-tier line, source `item_lines_cutpaper_v2/well_water/line_well_water_v4.png`.
- `acorn`: 12-tier premium drop line, source `item_lines_cutpaper_v2/acorn/line_acorn_v2.png`.
- `chest`, `key`, `water`, `spark`: 3-tier special drops, source `special_items_v2/special_items_3x5_cutpaper_v2.png`.

Previous live PNGs were copied to `previous_live/` before replacement.

Slicing note:
- The live 512x512 PNGs were cut from the source sheets with magenta-key removal, centered into square canvases, and strict foreground-component filtering. This removes neighboring-cell slivers and tiny anti-aliased alpha islands after resizing.
- The special-items generation returned at `916x1717`; the raw generation was preserved as `special_items_v2/special_items_3x5_cutpaper_v2_raw_916x1717.png`, and the production source sheet was normalized to exact `1024x1920`.
- `live_sliced_contact.png` is the review contact sheet for the final live assets.
- `component_qc.json` records the post-clean foreground component check for each live asset.

Remaining old generated line folders not regenerated in this pass:
- `games/grove/assets/_new/_processed/line_flower_boxes_v1`
- `line_garden_birds_v1`
- `line_garden_juice_v1`
- `line_garden_kites_v1`
- `line_garden_mossy_trinkets_v1`
- `line_garden_rain_charms_v1`
- `line_garden_small_critters_v1`
- `line_garden_stones_v1`
- `line_garden_vegetables_v1`
- `line_gate_arch_tokens_v1`
- `line_gate_bells_v1`
- `line_gate_glowcaps_v1`
- `line_gate_star_pebbles_v1`
- `line_hearth_ember_v7`
- `line_kitchen_herbs_v3`
- `line_larder_provisions_v1`
- `line_mill_gears_v1`
- `line_mill_small_animals_v1`
- `line_mill_small_fish_v1`
- `line_mill_water_plants_v1`
- `line_orchard_fruits_v1`
- `line_orchard_scarecrows_v1`
- `line_orchard_seeds_v1`
- `line_orchard_tools_v1`
- `line_porch_packages_v1`
