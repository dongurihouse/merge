# FX Workbench Plan

## Goal

Create a Grove-only FX lab that behaves like the existing UI workbench: a standalone clickable scene with a fixed sidebar and a live preview stage. The lab should make each shipped FX discoverable, tunable, and testable in the game context where the player will see it.

## First Slice

1. Add a new standalone runner, `games/grove/tools/fx_workbench.gd`, and scene, `games/grove/tools/FxWorkbench.tscn`.
2. Add `games/grove/tools/fx_workbench_view.gd` with a cozy two-column layout:
   - left sidebar: scrollable FX list, then effect controls
   - right stage: contextual preview surface for board/home/map UI
3. Seed the list with planned reward FX entries.
4. Build reward-arrival previews for all listed first-pass entries:
   - coin pickup
   - board refill
   - stash to bag
   - quest payout
   - 2x reward accept
   - map task reward
   - sale payout
5. Add per-FX on/off toggles in the sidebar and selected-effect controls; toggling off suppresses the FX while keeping its preview visible.
6. Build the `Coin pickup` preview as a board-context stage:
   - wallet chip at the top
   - board grid with one clickable coin piece
   - replay button and live sliders for amount, icon size, trail count, and coin size
7. Wire every preview to the real `FX.reward_arrival(...)` helper so the lab is testing the same effect spine used in the game.
8. Add a focused headless test for scene load, list visibility, controls, toggles, and spawned reward-arrival nodes.
9. Add Makefile targets without replacing the existing `fx` shatter demo.

## Next Ladders

1. Split per-effect dials into typed option groups once more than one effect needs timing/shape tuning.
2. Add preset capture/export once the dials become design source-of-truth rather than preview-only knobs.
3. Add screenshot focus args for capturing one selected FX directly from the command line.
