# Coral Reef unlock covering concept

Purpose: explore the locked-state treatment for the Coral Reef scene.

The intended model:

- The normal scene stays underneath.
- The locked scene is covered by repeated cut-paper reef patches.
- Unlocking an area removes one or more cover pieces from that region.
- Cover pieces should be reusable families, not unique one-off paint.

Files:

- `coral_reef_covered_scene_mock_v1.png` — art-direction mock for the mostly covered/locked scene.
- `raw/coral_cover_pieces_3x3_raw.png` — generated magenta-background source sheet.
- `raw/coral_cover_pieces_3x3_clean.png` — alpha-cleaned sheet.
- `cover_pieces/*.png` — nine transparent reusable cover pieces, extracted by alpha connected components.
- `cover_pieces_contact_sheet.png` — quick review sheet.
- `cover_pieces_rough_assembly_test.png` — rough proof that the pieces can be manually composed over the unlocked scene.
- `cover_pieces_manifest.json` — source cell, image, bbox, and size metadata.

Design note: use larger repeated patches rather than dense micro-clutter. Good unlock pieces are big enough that removing one feels meaningful and reveals a readable part of the scene.
