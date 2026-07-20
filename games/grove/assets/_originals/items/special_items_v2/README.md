Special drops v2.

Source:
- `special_items_3x5_cutpaper_v2.png` remains the accepted 3 columns x 5 rows source sheet.
- `special_items_3x5_cutpaper_v2_raw_916x1717.png` preserves the original generated output before the source was normalized to exact 1024x1920.

Processing:
- `games/grove/assets/_new/_processed/special_drops_cutpaper_v2.plan.json` records the intake mapping.
- The plan uses the repo intake runner: chroma-key saturated magenta, split by islands, then `process_icon` to 512 square transparent PNGs.
- Live rows processed from the sheet: chest islands 0-2, key islands 3-5, water islands 6-8, spark islands 12-14. The acorn preview row is intentionally not installed because live acorn uses a 12-tier line.
- Final outputs received strict alpha-island cleanup and magenta boundary despill so the checkerboard review has no clipped cells or key-color fringe.

Review:
- `special_drops_v2_intake_montage.png` is the cleaned live-output review montage.
