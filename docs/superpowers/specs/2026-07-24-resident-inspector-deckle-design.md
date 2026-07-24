# Resident Inspector Deckle Design

## Goal

Replace the Resident dialog inspector bar's baked `strip_bg.png` background with the shared code-drawn jagged paper surface.

## Current State

`engine/scripts/ui/residents.gd` makes the inspector panel transparent when `strip_bg.png` exists. `_rebuild_inspector()` then adds a rounded runtime shadow and stretches that texture across the inspector body.

## Chosen Design

- Keep `ResidentsInspector` in the pinned footer at its current height and width.
- Keep the portrait, resident name, info button, Sell button, empty-state hint, padding, and interaction callbacks unchanged.
- Make the inspector panel background unconditionally transparent.
- In every inspector rebuild, add one `Kit.rugged_paper_surface` named `ResidentsInspectorDeckleSurface` behind the content.
- Configure the surface from the saved `toggle_card` cut-paper settings, falling back to `Kit.ROW_CP_DEFAULTS`.
- Use the existing cream inspector fill, the shared `Kit.PAPER_EDGE` rim, and the current capsule corner radius.
- Remove the baked `strip_bg.png` texture layer and its separate rounded shadow. The shared cut-paper surface owns paper fibre, jagged silhouette, rim, and shape-matched shadow.

## Invariants

- No dialog dimensions or footer budgeting change.
- Expedition remains pinned and visible.
- Inspector content order and hit targets do not change.
- Selected and empty inspector states use the same generated surface.
- Other dialogs and shared row components remain unchanged.

## Verification

- Add a runtime Resident dialog assertion that `ResidentsInspectorDeckleSurface` exists and uses `engine/scripts/ui/cut_paper.gd`.
- Assert the inspector tree no longer contains a texture using `strip_bg.png`.
- Run the focused Grove exploration suite, `make test-fast`, and the full `make test`.
- Capture the selected Resident dialog and visually confirm the jagged edge, paper fibre, content alignment, and pinned footer geometry.
