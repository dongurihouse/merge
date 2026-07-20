# Fairy Hollow v3 Scene Workbench

This directory is the accepted, self-contained Fairy Hollow v3 workbench. It
consumes the canonical PNGs registered by `metadata/asset_manifest.json` and
keeps editable scene composition separate from generated review artifacts.

`metadata/placements.json` is the sole composition authority. Its schema-v2
document owns the canvas, foundation, editable center-bottom anchors and display
sizes, z order, clusters, contact dressing, and the complete tree-house
structural rule. The compositor reads that document directly; do not edit the
flattened reconstruction PNGs or duplicate placement values in code.

The same document declares the project-native pipeline contract: `scene_mode`,
`layered_raster`, separate props plus foreground occluders, no collision model,
existing visual assets, and the project-native engine target. Validation
requires every value exactly.

## Rebuild and validate

Run from the repository root:

```bash
python3 games/grove/assets/_concepts/zones/fairy_hollow_elements_v3/09_reconstruction/compose_reconstruction.py
```

The normal run deterministically rebuilds both flattened previews and
`09_reconstruction/reconstruction_report.json`, then writes
`metadata/validation_report.json`. To validate the existing generated outputs
without rebuilding them:

```bash
python3 games/grove/assets/_concepts/zones/fairy_hollow_elements_v3/09_reconstruction/compose_reconstruction.py --validate-only
```

Both modes exit nonzero if manifest/placement paths, asset modes, tight-asset
corner alpha, exact `#FF00FF` palette cleanliness, positive editable geometry,
tree-house structure, output dimensions, or report hashes fail validation.
Paths must be repo-relative, may not contain `..`, and must resolve inside the
project root. Validate-only also binds the existing reconstruction to the
current placements document, asset manifest, foundation, and every ordered
placement source SHA-256, so source changes require a normal rebuild.

Every Workbench-addable PNG in the v3 palette folders must have exactly one
accepted manifest record, and every accepted `final` must exist inside this
bundle. Inventory discovery follows the Workbench exclusions for style,
reconstruction, metadata, references, raw, review, montage, and contact files.
Fully transparent accepted RGBA files are rejected. Placement `assetId` is
optional: the compositor derives it uniquely from `image`; when present, it must
match that derived manifest asset.

## Scene Workbench

Capture the Fairy Hollow workbench and open it interactively with:

```bash
make shot-sw SCENE=fairy_hollow ROOT=/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_concepts/zones OUT=/tmp/fairy_hollow_scene_workbench.png
make sw SCENE=fairy_hollow ROOT=/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_concepts/zones
```

The checked-in initial checkpoint contains 16 placements, seven clusters, and
five contact placements. Those values are report context, not immutable
validation limits: Workbench edits may add, remove, move, or resize placements.
The initial seven cluster names let the workbench move each hero assembly as one unit.
The split moon swing intentionally renders its support at z 10 and its seat at
z 270 while both remain members of `moon_swing`. The tree-house asset remains a
complete `730 x 1291` host tree; its initial x position clips the right edge to
match the approved composition, but its saved x/y/w/h are editable and moving
the cluster reveals the full asset. `sourceBounds`, `deliveryBounds`, and native
PNG dimensions are intake provenance only; rebuilds render the saved geometry.

## Deterministic outputs

- `09_reconstruction/fairy_hollow_reconstruction_v3_1320x2346.png` — full-size RGB QA flatten.
- `09_reconstruction/fairy_hollow_reconstruction_v3_review_941x1672.png` — phone-review RGB flatten.
- `09_reconstruction/reconstruction_report.json` — ordered render bounds and input/output hashes.
- `metadata/validation_report.json` — machine-readable manifest, inventory, geometry, transparency, palette, checkpoint, and output validation.

Generated outputs are review evidence only. Make composition changes in
`metadata/placements.json`, rerun the compositor, and inspect both preview
sizes before accepting an edit.
