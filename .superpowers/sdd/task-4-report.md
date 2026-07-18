# Task 4 report: Meadow Sky whole-UI visual and regression verification

Status: complete

Fix commits:

- `9c49b2ba fix(grove): keep home labels below modal overlays`
- `5e381205 fix(grove): fit Meadow action bar copy`

## Review captures

All review images are intentionally untracked under `tmp/meadow_ui_v2_review/`.

- Home: `home_live.png` (`map_shot built ... noftue=1`)
- Board: `board_fixed_v3.png` (`grove_shot questready`)
- Maps: `maps_live.png` (`map_shot progress ... noftue=1`)
- Rush: `rush_live.png` (`rush_shot retired`)
- Level: `level_component.png` (focused live workbench component)
- Bag: `bag_component.png` (focused live workbench component)
- Shop: `shop_fixed.png` (`map_shot shop`)
- representative dialog: `mail_dialog_fixed.png` (`inbox_shot`)

The initial `fresh` Board and `intro` Rush captures were not representative gameplay views: those modes deliberately show full-screen tutorial art. The final Board uses `questready`; the final Rush uses `retired` so the live runtime board and chrome are visible.

## Visual inspection

- Home: Meadow wallet, level badge, rail buttons, and play disc are unclipped and consistent. World/building mats remain outside this UI-only pass.
- Board: board frame and authored cell states retain their corners without stretching. The final bottom action tray keeps the two-line title and compact help copy inside the frame, with the info button in its reserved slot and no overlap. No obvious magenta fringe was visible.
- Maps: level/wallet/rail chrome is stable and unobscured; the no-FTUE capture shows the map surface without an unintended Daily overlay.
- Rush: the live board, score readouts, cells, Meadow close affordance, and dedicated wide Meadow three-slice hint are unclipped. The chevron route is covered by the active Rush regression test. The capture tool emits pre-existing audio `add_child()` setup errors, but still saves a valid image.
- Level: the shared title ribbon is not clipped. The badge sits tightly above the progress copy, but the copy remains readable and inside the frame; no broader spacing redesign was made.
- Bag: title ribbon, close target, balance pill, open/next/locked cells, and cost chips are unclipped and consistently registered.
- Shop: title, close target, cards, ribbons, price buttons, and scroll rail are unclipped. Map restore labels no longer pierce the modal surface.
- Mail: title, close target, message cards, reward chips, and Claim buttons are unclipped. Map restore labels remain correctly behind the modal veil.

## Defects found and fixed with TDD

1. Home build labels and props used authored painter z-indices up to 1510, but shared modals mounted at z=100/110. Restore labels therefore rendered over Daily, Shop, and Mail. An active `home_zone_view_tests` assertion first failed (`14 passed, 1 failed`); the shared modal band now mounts at 2048/2110. The test passes (`15 passed, 0 failed`) and Shop/Mail recaptures confirm the labels remain below the veil.
2. The saved bottom action-bar typography and info-button offsets were oversized for the Meadow tray at phone width. New active geometry/line-fit assertions first failed (`193 passed, 2 failed`, followed by the stronger overlap assertion). Resetting the saved values to the workbench-safe 32/18 fonts and neutral button scale/offset preserves tray geometry and input targets. Final focused result: `197 passed, 0 failed`; `board_fixed_v3.png` confirms no clipping or overlap.

## Fresh verification evidence

- `make import` -> exit 0.
- `make bake-textures` -> exit 0; 24 dialogs, 41 sprites, all up to date.
- `make test-one SUITE=engine/tests/home_zone_view_tests` -> 15 passed, 0 failed.
- `make test-one SUITE=games/grove/tests/grove_info_bar_tests` -> 197 passed, 0 failed.
- `make test-one SUITE=engine/tests/level_badge_tests` -> 41 passed, 0 failed.
- `make test-one SUITE=engine/tests/kit_bake_tests` -> 16 passed, 0 failed; 0 un-baked sprites.
- `make test-grove` -> 11 suites, 1809 passed, 0 failed.
- `make test-fast` -> 40 suites, 1298 passed, 0 failed.
- `python3 -m unittest games.grove.tools.tests.test_extract_meadow_ui_v2 -v` -> 13 passed.
- `git diff --check` -> clean before commits.

## Scope notes

- `games/grove/tests/grove_ui_tests.gd` remains in the repository's disabled suite list with known unrelated baseline failures; active equivalent coverage is in Grove info-bar/workbench/palette suites and engine badge/bake tests.
- Nine import-generated bucket/home `.gd.uid` files remain untracked and were deliberately excluded.
- Screenshot tools log existing shutdown resource/RID warnings. The Rush tool additionally logs audio-node setup errors during `_ready`; these did not prevent captures and were not changed in this UI-art pass.

## Final integration review follow-up

- Replaced the remaining visible legacy Home/navigation shells with deterministic Meadow paper shells at their exact fixed consumer dimensions; the Play CTA now uses action green, while neutral navigation uses cream.
- Replaced Level's legacy frame with the Meadow dialog surface, Rush's exit with the Meadow close control, and Rush's fixed-aspect bottom hint with a deterministic wide three-slice derived from the Meadow secondary button.
- Clamped live Home/navigation and wallet shadows to structural slate `#294654` at no more than 20% alpha; reset the saved wallet override from 72% to 20%.
- Moved all 15 generated QC montages from production `assets/ui/meadow_v2/qc` to export-excluded `assets/_review/ui/meadow_v2`; the iOS export preset and active routing suite guard that boundary.
- Re-captured `home_final_review.png`, `level_final_review.png`, and `rush_final_review.png` after refreshing baked textures. Home shells, the green Play CTA, Level frame, Rush close control, and wide hint render without clipping or fixed-aspect distortion.
