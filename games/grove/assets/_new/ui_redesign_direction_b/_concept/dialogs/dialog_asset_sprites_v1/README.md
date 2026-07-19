# Level + Daily Reward dialog sprite masters

Concept-only transparent UI sprite masters in the Meadow Sky / Cut-Paper Playground style. These are not hooked into the game yet.

- Master sheet: `dialog_level_daily_sheet_1536.png` — 3 x 3 grid of 512 x 512 cells.
- Individual masters: `final_frames/`.
- Prompt and raw generation source: `prompt-used.txt`, `raw-sheet-v2.png`.

## Level dialog

- `level_medallion_base_512.png`: leaf-wreath medal; overlay the current level numeral in UI.
- `level_progress_star_512.png`: progress / earned-star marker.
- `level_milestone_reward_512.png`: optional reward marker for a level-up state.

## Daily rewards dialog

- `daily_coin_stack_512.png`
- `daily_water_droplet_512.png`
- `daily_acorn_512.png`
- `daily_mystery_gift_512.png`
- `daily_mystery_chest_512.png`
- `daily_claimed_check_512.png`

All objects use transparent backgrounds, have no baked shadows, and have clear padding for safe composition. QC results are recorded in `manifest.json`; visible chroma fringe, opaque canvas-edge pixels, and nonzero RGB outside alpha are all zero.
