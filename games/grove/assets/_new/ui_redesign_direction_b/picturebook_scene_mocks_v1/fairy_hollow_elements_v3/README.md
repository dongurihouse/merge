# Fairy Hollow v3 Scene Workbench

This directory is the accepted, self-contained Fairy Hollow v3 workbench. It
consumes the canonical PNGs registered by `metadata/asset_manifest.json` and
keeps editable scene composition separate from generated review artifacts.

`metadata/placements.json` is the sole composition authority. Its schema-v2
document owns the canvas, foundation, center-bottom anchors, native display
sizes, z order, clusters, contact dressing, and the complete tree-house
structural rule. The compositor reads that document directly; do not edit the
flattened reconstruction PNGs or duplicate placement values in code.

## Rebuild and validate

Run from the repository root:

```bash
python3 games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v3/09_reconstruction/compose_reconstruction.py
```

The normal run deterministically rebuilds both flattened previews and
`09_reconstruction/reconstruction_report.json`, then writes
`metadata/validation_report.json`. To validate the existing generated outputs
without rebuilding them:

```bash
python3 games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v3/09_reconstruction/compose_reconstruction.py --validate-only
```

Both modes exit nonzero if manifest/placement paths, asset modes, tight-asset
corner alpha, exact `#FF00FF` palette cleanliness, native sizes, counts,
tree-house structure, output dimensions, or report hashes fail validation.

## Scene Workbench

Capture the Fairy Hollow workbench and open it interactively with:

```bash
make shot-sw SCENE=fairy_hollow ROOT=/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1 OUT=/tmp/fairy_hollow_scene_workbench.png
make sw SCENE=fairy_hollow ROOT=/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1
```

The seven cluster names let the workbench move each hero assembly as one unit.
The split moon swing intentionally renders its support at z 10 and its seat at
z 270 while both remain members of `moon_swing`. The tree-house asset remains a
complete `730 x 1291` host tree; its initial x position clips the right edge to
match the approved composition, but moving the cluster reveals the full asset.

## Deterministic outputs

- `09_reconstruction/fairy_hollow_reconstruction_v3_1320x2346.png` — full-size RGB QA flatten.
- `09_reconstruction/fairy_hollow_reconstruction_v3_review_941x1672.png` — phone-review RGB flatten.
- `09_reconstruction/reconstruction_report.json` — ordered render bounds and input/output hashes.
- `metadata/validation_report.json` — machine-readable manifest, geometry, transparency, palette, count, and output validation.

Generated outputs are review evidence only. Make composition changes in
`metadata/placements.json`, rerun the compositor, and inspect both preview
sizes before accepting an edit.
