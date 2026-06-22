# Manual unlock-button placement in the vine tool — design

Date: 2026-06-21

## Goal

Let the artist set each region's unlock-button location in the vine mask tool by dragging a marker,
instead of the button always sitting at the polygon centroid. Free placement (anywhere on the image),
per region, with the centroid as the default/fallback so every existing map is unchanged.

## Design

### Schema (additive, optional)

Each region in `mapN_regions.json` gains an optional `"button": [x, y]` in pixel coords (same space as
`points`). **Absent → the game and tool use the polygon centroid** (today's behavior). Written only when
the artist has explicitly placed the button, so an auto button keeps following polygon reshapes.

### Tool — `region_editor_overlay.gd` (the draw/drag surface)

- **Draw a marker** per region with ≥3 points: a gold ✿-style disc, visually distinct from the
  cyan/white vertex handles, at `region.button` if set else the live centroid. When `button` is set,
  draw a faint connector line from the marker to the centroid so it is clear which region it belongs to.
- **Drag** the marker (new `dragging_button` state) → sets `region.button`, clamped to image bounds, with
  **no vertex-snapping**. On a press that hits both a vertex and the marker, the **vertex wins** (checked
  first) so vertex dragging is never hijacked.
- **Right-click** the marker → `erase("button")` (reset to auto; marker snaps back to centroid).
- Marker edits emit the existing `regions_changed` signal. `_clone_regions` carries `button` when present
  (omits it when absent) so both directions (tool→overlay load, overlay→tool edit) round-trip, and a
  reset is distinguishable from "unchanged".
- Add `_centroid(points)`, `_button_pos(region)`, `_find_button_handle(pos)` helpers.

### Tool — `vine_mask_tool.gd`

- `_on_regions_changed`: merge `button` back by index — set it when the incoming region has one, `erase`
  it when it does not (so a reset propagates).
- `_save_regions_to_file`: write `"button": [roundi(x), roundi(y)]` only when the region has one.
- `_load_saved_regions`: read `button` (a `[x,y]` array) into the in-memory region as a clamped `Vector2`.

In-memory region dict: `{name, points:[Vector2], enabled, cost, tuning, button?:Vector2}`.

### Game — `vine_maps.gd`

- `spots_for` resolves each spot's `pos` via a new `_button_or_centroid(region, isize)`: the normalized
  `button` when the region carries a valid `[x,y]`, else the existing centroid of `points`.
- Nothing in `map.gd` changes — `_build_vine_spot`/`_home_badge` already place the disc at `spot.pos`.

## Components & boundaries

| Unit | Change | Depends on |
|---|---|---|
| `region_editor_overlay.gd` | draw + drag + reset the per-region button marker; carry `button` in clone | — |
| `vine_mask_tool.gd` | merge / save / load `button` | overlay |
| `vine_maps.gd` | `spots_for` button-or-centroid | regions JSON |
| regions JSON schema | optional `button:[x,y]` | — |
| `grove_vine_tests.gd` | assert `spots_for` honors `button`, falls back to centroid | fixtures |

## Testing

- **Headless (active `grove_vine_tests`):** a fixture region with a `button` yields that normalized pos;
  a region without one yields the centroid (regression guard for the fallback).
- **Visual (real renderer):** capture the tool/home with a region's button dragged off-centroid and
  confirm the ✿ disc renders at the placed point, not the centroid. Deliver the PNG.

## Out of scope

- Snapping the button to vertices or polygon edges (free placement was chosen).
- Per-button styling/size in the tool (the disc look is the kit's, tuned elsewhere).
- Numeric X/Y entry in the list panel (drag-marker was chosen).
