# Fairy Hollow v4 — editable scene bundle

`metadata/placements.json` is the sole placement authority for this 1320 × 2346
center-bottom-anchored picture-book scene. The bundle reconstructs the arrangement of
`games/grove/assets/_concepts/zones/fairy_hollow_original_mock_v1.png` with generated,
separate assets rather than a flattened zone mock.

## Layering and clusters

The opaque `foundation` holds only the stable night sky, meadow, creek, stepping-stone path,
threshold stones, and picnic cobbles. Environment plates occupy z 10–13: the enlarged bounded
forest-band crop carries the mid-woodland down behind the cottage and den, while the distant hills
and edge trees retain the sky and side framing. Major scene clusters
follow the original mock: upper-center `toadstool_cottage`, right `fox_den`, left
`wishing_well`, lower-left `stone_bridge`, center `picnic_set`, and the three mushroom clusters.
Each local ground-dressing member is in the same cluster as the prop it blends into. There is no
global dark contact shadow. `foreground_foliage` is the only 500+ occluder; its authored
`sourceCrop` selects one edge-anchored clump from its source strip, so it frames the lower-right
edge instead of reading as three detached turf islands. The rear-side cottage fence sits behind
the enlarged cottage, preserving the open doorstep and path.

Every generated element is listed in `metadata/asset_manifest.json` with the exact source mock
and its accepted generation prompt (`*.prompt.txt`). The initial document places every manifest
asset once; a placement entry always names exactly one `assetId` and image.

## Edit and render loop

Open the editable document with:

```bash
make sw SCENE=fairy_hollow ROOT=/Users/xup/dh/merge/.worktrees/codex-fairy-hollow-original-mock-v4/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1
```

Save in the workbench, then regenerate deterministic review output:

```bash
python3 games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/09_reconstruction/compose_reconstruction.py
python3 games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/09_reconstruction/compose_reconstruction.py --validate-only
```

The compositor reads only `placements.json` and the manifest, paints in `(z, authoring order)`,
and writes the full PNG, 941 × 1672 review PNG, `reconstruction_report.json`, and validation
report. It rejects missing, absolute, parent-traversal, duplicate-manifest, invalid-geometry or
out-of-bounds source crop,
asset-id/image mismatch, fully transparent, missing-inventory, and visible `#FF00FF` inputs.
