# Desert Oasis elements v3

This bundle reconstructs `desert_oasis_original_mock_v1.png` as a layered cut-paper scene.

- `01_backdrop/` is the true, opaque foundation: sky, clouds, hills, dunes, sand, stepping path,
  pond, rim, and lily pads only.
- `03_structures/`, `04_garden_items/`, and `05_dressing/` contain independently placeable,
  alpha-checked cutouts. Color sprites deliberately contain no cast shadows.
- `metadata/placements.json` is the Scene Workbench authority. It uses a 1320x2346 canvas and
  center-bottom anchors.

The original mock remains in `00_style/reference/` as the composition authority. The 3x3
vegetation sheet is retained as the source pack; its nine delivery cells are split into
`05_dressing/vegetation_pack/` for Workbench placement.
