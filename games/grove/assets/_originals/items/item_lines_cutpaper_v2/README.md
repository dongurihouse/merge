V2 cut-paper item-line batch.

Style source:
- Meadow Sky + Cut-Paper Playground guide.
- Accepted Glowshroom v2 sheet is the local item-line style reference.

Generation contract:
- 1024x1536 PNG.
- 3 columns x 4 rows, row-major tiers 1-12.
- Solid flat #FF00FF source background.
- No shadows, grounding, glow, particles, labels, or detached FX.
- One readable connected object per cell with matched footprint.

V3 diversity rule:
- A tier must differ from its neighbors by at least two of: physical silhouette, object subtype/construction, dominant color family, and broad motif/material.
- Decoration-only variants fail. For example, the same cup with a new stripe, the same koi with a new patch map, the same fan coral in a new color, or the same rounded shell with a new rim is not enough.
- Name concrete subtypes before generating. Shells use cap/razor/spiral/cowrie/tower/fan/sand-dollar/murex/nautilus/helmet/abalone/conch. Corals use cup/knobby/brain/disk/tubes/plates/leather fingers/star boulder/elkhorn/fan/sun-cups/crown. Koi vary body proportion and fin construction. Tea cups vary handle/no-handle, lid/no-lid, bowl/tall glass/tumbler/chalice, saucer/foot/pedestal, rim shape, and palette.
- Process item-line sheets with `games/tools/slice_item_lines.py --montage`; do not grid-crop by cell.

Status:
- coin: v2 generated and sliced into live `games/grove/assets/items/coin`.
- acorn: v2 generated as a 12-tier premium drop line and sliced into live `games/grove/assets/items/acorn`.
- fairy_hollow_glowshroom: v3 revises the line with star/moon/sun late, crystal before final, and rainbow mushroom final.
- fairy_hollow_wild_berries: v6 generated and sliced into live `games/grove/assets/items/fairy_hollow_wild_berries`.
  Rebuilt the roster so every tier owns one hue and one silhouette (bud, redcurrant sprig, strawberry, ribbed
  gooseberry, blueberry, raspberry cone, golden husk berry, blackberry, rosehip, snowberry, crystal dewberry,
  rainbow berry) — v5 spent three tiers on near-identical greens and its cloudberry/salmonberry/rainbow tiers
  read as loose orange balls, a mango, and a beach ball. Chosen from six candidates (see v6 sidecar).
- snowy_village_snow_ice: v4 generated; starts with one simple snowflake, adds igloo and snow slide, removes the extra snowflake and round snow cylinder.
- snowy_village_woolens: v4 generated; replaces the duplicate tier 10 sock/bootie shape with a neck-warmer cowl.
- snowy_village_winter_berries: v5 generated; removes duplicate bud/acorn shapes and odd ornate flowers, broadening into winter needles, holly, juniper, pinecone, mistletoe, cabbage, fern, lichen, reeds, wreath, and seed crest.
- well_water: v4 generated and sliced into live `games/grove/assets/items/well_water`.
- v2_parallel_batch_contact.png: quick review contact sheet for the four parallel-agent outputs.
- oasis_desert_fruits: v5 generated; revised away from berry-like fruit into yellowish desert vegetation, cacti, and sun-baked oasis items/buildings.
- oasis_sand_sculptures: v3 generated; starts with sand fleck, keeps shell/moon, adds sandcastle wall/castle, removes mask.
- oasis_spices: v3 generated; separates first pod from pepper, replaces odd final with spice container, changes tier 11.
- coral_reef_shells: v3 generated, magenta-normalized, sliced via `slice_item_lines.py`, then strict alpha-island cleanup + magenta boundary despill.
- coral_reef_corals: v3 generated, magenta-normalized, sliced via `slice_item_lines.py`, then strict alpha-island cleanup + magenta boundary despill.
- cherry_blossom_koi: v3 generated, magenta-normalized, sliced via `slice_item_lines.py`, then strict alpha-island cleanup + magenta boundary despill.
- cherry_blossom_tea_cups: v3 generated, magenta-normalized, sliced via `slice_item_lines.py`, then strict alpha-island cleanup + magenta boundary despill.
- v2_remaining_lines_contact.png: quick review contact sheet for Oasis, Coral Reef, and Cherry-Blossom outputs.
- v2_revision_contact.png: quick review contact sheet for Wild Berries v4, Desert Fruits v3, and Sand Sculptures v3 revisions.
- v2_revision_snow_spices_contact.png: quick review contact sheet for Spices v3, Snow/Ice v3, Winter Berries v3, and Woolens v3 revisions.
- v2_revision_berries_fruits_contact.png: quick review contact sheet for Wild Berries v5 and Desert Fruits v4.
- v2_revision_snow_vegetation_wool_contact.png: quick review contact sheet for Snow/Ice v4, Winter Vegetation v4, and Woolens v4.
- v2_revision_desert_v5_compare_contact.png: quick comparison sheet for Wild Berries v5, Desert Fruits v4, and Desert Veg/Items v5.
- v2_revision_winter_vegetation_v5_compare_contact.png: quick comparison sheet for Winter Vegetation v4 and v5.
- ../cutpaper_remaining_v2/remaining_currency_drop_contact.png: quick contact sheet for Coin v2, Well Water v4, Acorn v2, and Special Drops v2.
