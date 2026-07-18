# Coral Reef Elements V2

Source-faithful layered-raster rebuild of the approved Coral Reef mock.

## Bundle contract

- Visual model: `layered_raster`.
- Source authority: `../coral_reef.png` is the exact authority for identity, composition, palette, paper material, camera, lighting, silhouette, scale, and direction. An untouched copy lives at `00_source/coral_reef_reference.png`.
- Logical canvas: 1320 × 2346 px, preserving the approved 941 × 1672 source ratio.
- Placement convention: center-bottom for every runtime layer. Placement `x` is the horizontal center and placement `y` is the bottom of the rendered layer in logical-canvas pixels.
- Extraction-edit policy: derive runtime subjects from the source with extraction-oriented edits. Preserve the source object's silhouette, proportions, facing, paper grain, printed mottling, palette, and lighting; remove surrounding water, terrain, and neighboring objects; reconstruct only tiny portions hidden in the source. Raw subject extractions use a flat `#FF00FF` background before cleanup to transparent RGBA.
- V1 preservation: `../coral_reef_elements_v1/` remains intact. V2 work is isolated to this sibling bundle and must not modify, replace, or overwrite V1 assets or metadata.

## Directory layout

```text
00_source/         immutable source reference
01_environment/    opaque edited environmental plate
02_subjects/       independent runtime subject layers
03_atmosphere/     independent bubble-stream layer
04_reconstruction/ flattened QA reconstructions only
metadata/          source bounds, placements, and QA records
```

`metadata/source_bounds.json` records source-pixel rectangles as `[left, top, right, bottom]`. Later placement metadata normalizes those bounds onto the logical canvas and uses the center-bottom convention above.
