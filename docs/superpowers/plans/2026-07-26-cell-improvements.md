# Cell Improvements Draft 6 Review Plan

**Goal:** Replace the Draft 5 build-mode implementation with Draft 6 seed-item acquisition for Soil and Magnet improvements.

**Scope:** Grove board only. Keep the `improvements` feature flag, keep placed improvement rows in `g["board"]`, and leave the review branch unmerged.

## Completed Changes

- [x] Remove the build-mode surface: board-edge button, pads, chooser modal, direct build/move/demolish scene flows, and build-price action APIs.
- [x] Add Soil and Magnet seed pseudo-lines: line 14 and line 15, top 1, ordinary draggable/stashable/sellable board occupants.
- [x] Add seed drop gating: one unplaced seed per kind on board or in bag, and block kind once placed cap is reached.
- [x] Preserve the special-drop RNG contract: filtering happens before `pick_special_drop`, and the picker still makes exactly one `randi_range` call.
- [x] Add `BoardActions.place_seed(board, cell)` and `BoardActions.unsocket_improvement(board, cell)`.
- [x] Carry Soil rank through unsocketed seeds using metadata while keeping the visible seed code at tier 1.
- [x] Add info-bar actions for seed Place, Bag, and Sell.
- [x] Add info-bar actions for empty improved cells: Unsocket, and Soil Rank.
- [x] Replace level-6 Soil FTUE build mode with a deterministic Soil seed grant and hand hint.
- [x] Keep the review-round regressions covered: drag-to-bag fall-through, board second-tap delivery, primary giver delivery t7 warning, magnet bramble RNG byte identity, growing-piece ordinary actions, stale info refresh, and drag-safe Soil tick.
- [x] Update `grove_sim.gd` from build-price adoption to seed supply/drop gate plus rank/unsocket ledgers.

## Verification

- [x] `make test-one SUITE=engine/tests/improvements_tests`
- [x] `make test-one SUITE=games/grove/tests/grove_improvements_tests`

Before review handoff, also run:

- [x] `make test-fast`
- [x] `make test`
- [x] `godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- 30 1`
