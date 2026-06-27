# Rush view layout — top-to-bottom structure + responsiveness

Status: approved 2026-06-27. Implements a four-band Rush screen and makes the whole screen
reflow on a live viewport resize. Touches `engine/scripts/scenes/explore_rush.gd` only
(plus a guard test in `games/grove/tests/grove_explore_tests.gd`).

## Problem

The Rush screen (`ExploreRush`) reads as "a beautiful scene buried under a big empty table":
the 9×7 board is sized to fill the whole band between the top bar and the bottom safe area,
so at the start of a run ~80% of the screen is empty beige board. The screen is also built
once in `_ready()` from the startup viewport size and never re-fits — dragging the window
border (or a rotation) leaves it pinned to the old width, unlike the home/map and the board
action bar, which both re-fit on `size_changed`.

## Goals (this change)

1. A clear four-band layout, top to bottom: **top bar → activity bar → board → bottom hint**.
2. A new **activity bar** between the top bar and the board that telegraphs the treefall:
   a warning line, a draining countdown bar (the existing 4 s `Explore.WARN`), and a
   down-arrow aligned to the doomed column. Today the bar carries **only** the treefall
   notice; a second indicator is explicitly out of scope (parked).
3. The **bottom hint** keeps its text but is bigger / higher-contrast so it reads as real
   guidance rather than a faint caption.
4. **Every band, plus the live tiles, reflows on a viewport resize**, matching the
   `map.gd` / board-action-bar pattern (coalesced `size_changed` → one relayout per frame).

Non-goals: changing gameplay, the grid size (stays 9×7), the scoring, or the reward overlay.
No second activity-bar indicator (multiplier-cooldown / board-fill / rain) today.

## Layout (top to bottom)

The screen reserves vertical budget in this order; the board takes whatever is left.

1. **Top bar** — unchanged content (`Kit.rush_bar`: Time · Score · Mult, + exit ×). Now
   rebuilt on relayout so it re-centers and re-scales to the new width, seeded with the
   live time/score/mult so a resize mid-run keeps the readouts.
2. **Activity bar** — a fixed-height slot (`clampf(vh*0.05, 44, 70)` px) directly below the
   top bar, centred, `vw - 2·margin` wide. Reserved height so the board never jumps between
   states. Two stacked sub-panels toggled by visibility:
   - **Idle** (`_tf.ph == "idle"`): a quiet parchment rail, calm caption ("No treefall —
     keep merging"). Low-key so it is not a second empty void.
   - **Warning** (`_tf.ph == "tele"`): a red/amber strip — tree icon, "Treefall in Ns"
     (N = `ceil(WARN - _tf.t)`), and a countdown fill that drains from full to empty over
     `Explore.WARN`. A separate down-chevron sits just above the board, centred on the
     doomed column (`_board.position.x + _cellxy(0, col).x + _cell*0.5`), so the eye reads
     bar → arrow → column. The existing on-board red column tint (`_tele`) stays.
3. **Board** — same 9×7 grid, same shared frame (`Kit.board_panel`) and slot wells
   (`Kit.slot_cell`). Cells fit the band between the activity bar's bottom and the bottom
   hint's top, centred, frame overhang clear of both.
4. **Bottom hint** — same text ("Tap again to fling · empty a column before the treefall"),
   bigger font (`clampf(vw*0.038, 22, 30)`), more solid panel (ink @ 0.82), so it reads
   clearly on both the board and the grass. Node names `RushBottomHintStrip` /
   `RushBottomHint` are preserved (a test asserts them).

## Responsiveness

Mirror the established pattern (`map.gd::_on_viewport_resized` / `board.gd::_relayout_action_bar`):

- In `_ready()`, after the first build, connect `get_viewport().size_changed` to a coalescing
  handler: a `_relayout_queued` flag + `call_deferred` so a burst of resize events collapses
  to one relayout at end of frame; skip when `get_viewport_rect().size == _last_view`.
- A single `_layout()` rebuilds the **stateless** chrome (top bar, activity bar, bottom hint,
  and the board's frame + slot wells + telegraph, grouped under a `_chrome` child kept behind
  the tiles) and recomputes board geometry (`_cell`, board position).
- The **stateful** tiles are never destroyed (they hold the run grid in `_grid[r][c].node`);
  `_layout()` repositions and resizes each to its cell and re-paints its piece at the new
  `_tile_px()`.
- After geometry settles, `_apply_treefall_visual()` re-syncs the telegraph pane, the arrow
  position, and which activity sub-panel is visible, then `_refresh_readouts()` updates text.

The painted backdrop (`board2_bg.png`) is anchored full-rect with `KEEP_ASPECT_COVERED`, so
it auto-fits the viewport and is built once (not rebuilt on resize).

## Testing

- `make test-fast` after each change; full `make test` before merge.
- New guard in `grove_explore_tests.gd` (`_test_rush_resize`), mirroring the home-map
  S-RESIZE test: instantiate `ExploreRush`, drive two known viewport widths, wait two frames
  (deferred coalesce), and assert the board re-fits each width (board width tracks the
  viewport, board stays horizontally centred) and the activity bar + bottom hint stay
  on-screen. Existing `_test_rush_intro_hint` / `_test_screens` guard the preserved node
  names and the build smoke.
- Visual check via `engine/tools/quiet_godot.sh -s res://games/grove/tools/rush_shot.gd`
  at two widths (e.g. `720x1280` and `1280x720`) to confirm the four bands and the reflow.
