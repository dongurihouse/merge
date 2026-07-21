# Edge Glade Layered Asset Pack Design

**Date:** 2026-07-17

**Status:** Approved visual design; written specification awaiting final review

**Target:** Grove home screen, Direction B

## Goal

Rebuild the approved Edge Glade composition as a production-oriented set of independent raster layers. The assembled result must preserve the colorful, high-contrast cut-paper cartoon direction while allowing scenery, clouds, paths, buildings, vegetation, and props to be positioned or animated independently.

The pack must feel like one illustrated world when assembled. No object may look pasted onto the scene because of a baked grass island, soil patch, dark grounding strip, mismatched camera, or mismatched lighting.

## Source of Truth

These files travel with the asset work:

- `games/grove/assets/_new/ui_redesign_direction_b/edge_glade_layered_work_v1/edge_glade_dressed_reference.png` — approved composition and visual target.
- `games/grove/assets/_new/ui_redesign_direction_b/edge_glade_layered_work_v1/edge_glade_dressed_reference.prompt.txt` — historical source prompt context.
- `games/grove/assets/_new/ui_redesign_direction_b/edge_glade_layered_work_v1/COMPOSITION_HANDOFF.md` — historical placement and layer analysis.

The 853 × 1843 reference is a composition guide, not a production-resolution asset and not a source from which props should be cut out.

This design specification is the production authority for the layered rebuild. It supersedes the historical prompt and handoff wherever they conflict, especially their edit-in-place framing, object ground footprints, original 853 × 1843 round-trip canvas, baked distant vegetation, baked path, folder layout, and earlier review order. The reference PNG alone is the authority for visual feel, palette, camera, material, lighting, and broad composition. The prompt and handoff remain useful context for semantic placement, prop roles, root/den separation, and rejection conditions. Links in the historical handoff to files that are absent from this branch are context only and are not production dependencies.

## Production Canvas

- Master viewport: **1320 × 2868 px**, portrait, matching the native pixel dimensions of the current iPhone Pro Max target selected for this work.
- Backdrop: opaque RGB PNG at the full master size.
- Transparent layers: RGBA PNGs at or above their intended maximum display envelope in the 1320 × 2868 reconstruction. Runtime and review composites may downscale assets but may not upscale them.
- Composition coordinates and review composites use the 1320 × 2868 coordinate system.
- The measurable quiet zones are **y = 0–487 px** at the top (17%) and **y = 2466–2867 px** at the bottom (14%). These areas may carry backdrop color and nonessential atmospheric scenery, but no critical seam, identity-bearing detail, or primary interaction target may depend on them.

### Reference mapping

Do not resize the reference raster into a production layer. Transfer composition through normalized coordinates:

- `target_x = reference_x / 853 × 1320`
- `target_y = reference_y / 1843 × 2868`
- Convert reference placement envelopes with the same independent axis ratios as planning values only.
- Generate each asset natively, preserve its aspect ratio, and refine scale and position during reconstruction; never distort an asset to force it into a converted envelope.

The two canvas aspect ratios differ by less than 1%. Use the normalized anchors as starting positions, then reframe visually while preserving the approved semantic sequence and quiet zones. Overlay comparisons should fit the reference to the target height and center-crop the negligible side excess; they are review aids, not runtime assets.

## Layer Architecture

Use a hybrid architecture:

1. One full-canvas opaque backdrop.
2. Independent transparent sprites for vegetation bands and clouds.
3. Individual transparent files for large or identity-sensitive objects.
4. Regular sprite sheets for coordinated small and medium variations.
5. Separate assembly-test composites that are never runtime source assets.

No visible environmental element other than the sky, meadow color field, and soft horizon transition is baked into the true backdrop.

Suggested runtime depth order, back to front:

1. True backdrop
2. Clouds
3. Far vegetation
4. Mid vegetation
5. Near vegetation
6. Root setting and den
7. Path stones
8. Medium props
9. Small scatter and edge-softening accents
10. Front root or vegetation occluders

## True Backdrop

Generate one opaque 1320 × 2868 image containing only:

- Blue sky in approximately the upper 28–30% of the canvas.
- A soft, irregular horizon transition centered near **y = 820 px**.
- A broad green meadow covering the remainder.
- Warm lime radiance entering from the upper-left to upper-middle area.
- Cooler and slightly darker meadow color near the horizon, transitioning toward brighter yellow-green in the central play area.
- Subtle paper texture and broad tonal variation only; no discrete objects or object-like marks.

The backdrop must not contain clouds, paths, stones, trees, bushes, flowers, mushrooms, buildings, roots, soil patches, grass tufts, cast shadows, or dark grounding bands.

### Backdrop acceptance

- The horizon reads softly without a hard stripe.
- The center remains bright enough for dark-edged objects to read clearly.
- Top and bottom safe regions remain calm.
- There are no accidental features that would constrain later placement.
- At 100% scale, the image contains no obvious generation seams, text, frames, or edge artifacts.

## Vegetation System

Vegetation forms three independent depth bands around the floor/sky boundary. Sprites overlap one another by approximately **20–35%** so the horizon reads as a continuous woodland rather than a row of isolated stickers.

All vegetation uses the same slightly elevated, near-front three-quarter camera, cut-paper material language, and upper-left lighting direction.

### Far band

- Six cool blue-green woodland silhouette variations.
- Lowest contrast, lowest saturation, softest detail.
- Broad shapes designed to overlap and establish atmospheric distance.
- Deliver six extracted independent sprites. An assembled convenience strip may be supplied in addition, but never as the only runtime deliverable.

### Mid band

- Six muted emerald and teal young-tree or shrub-mass variations.
- Medium contrast and detail.
- Shapes must bridge gaps between far and near layers without forming a repeated picket-fence rhythm.
- Deliver six extracted independent sprites. An assembled convenience strip may be supplied in addition, but never as the only runtime deliverable.

### Near band

- Six individually generated, detailed tree variations.
- Nine bush variations delivered as a 3 × 3 sheet and extracted sprites.
- Highest saturation, contrast, and edge definition of the three bands.
- Each asset has a clear center-bottom placement anchor.

### Vegetation rejection rules

Reject any sprite with:

- A grass floor, turf halo, soil island, flower ring, stone ring, or baked scenery at its base.
- A dark horizontal shadow pad or heavy bottom outline.
- Cropped branches or foliage touching the cell boundary.
- Perspective, outline weight, paper texture, or lighting inconsistent with the reference.
- A base that cannot be overlapped naturally by other plants or small scatter.

Contact softness should come from irregular roots, stems, fallen leaves, and separately placeable grass or flower accents—not a built-in ground platform.

## Clouds

Create six clouds on a transparent **3 × 2** source sheet, then extract them as individual sprites.

The default cloud sheet is 1536 × 1024 px with six 512 × 512 px cells and at least 12.5% clear padding inside each cell.

- Three size classes: small, medium, and large, with two silhouette variations per class.
- Warm white to cream paper tops with pale blue undersides.
- Soft dimensional layering, simple silhouettes, and no sky-colored rectangle.
- Generous transparent padding; no cloud touches a cell edge.
- Designed for two horizontal motion lanes behind all vegetation.
- Each extracted cloud has a center anchor, native bounds, motion-lane recommendation, and wrap padding recorded in metadata.

The animation system may later translate and wrap the clouds horizontally; animation implementation is outside the initial asset-generation scope.

## Sprite-Sheet Policy

Use sheets only when the objects share scale, camera, lighting, and detail density.

### 3 × 3 sheets

Use for nine readable variations of:

- Path stones
- Grass tufts
- Flower clusters
- Mushrooms
- Small rocks
- Bushes

Each cell contains exactly one isolated variation with even safe padding. Objects must remain large enough to inspect and chroma-key cleanly.

Default source-sheet size is 1536 × 1536 px with nine 512 × 512 px cells. Use at least 12.5% clear padding inside every cell and keep the visible object large enough that its extracted native bounds meet or exceed its maximum intended display size.

### 6 × 6 sheets

Use only for tiny, low-detail scatter such as:

- Individual leaves
- Petals
- Pebbles
- Tiny accent marks

Do not use 6 × 6 for objects whose identity, internal detail, or silhouette would become ambiguous.

Default source-sheet size is 1536 × 1536 px with thirty-six 256 × 256 px cells. Use at least 12.5% clear padding inside every cell.

### 2 × 2 sheets

Use only when four coordinated medium-object variations remain comfortably readable. If details or edges become cramped, generate the objects individually instead.

The default 2 × 2 source sheet is 1536 × 1536 px with four 768 × 768 px cells and at least 12.5% clear padding inside each cell.

### Individual files

Generate these separately because silhouette, seams, scale, or visual identity matter:

- Den or house variations
- Root-back setting
- Root-front occluder
- Six large near trees
- Bench
- Planter
- Mailbox
- Lantern

Size each individual source canvas so the cleaned visible bounds meet or exceed the asset's maximum intended display envelope and retain at least 12.5% clear padding on every side. Do not accept a result that would require upscaling in the master reconstruction.

## Modular Path

The stone road is not part of the backdrop and is not attached to the den.

- Generate nine individual stepping-stone variations on a 3 × 3 source sheet.
- Extract stones into independent transparent sprites.
- Keep scale, thickness, camera, outline, and upper-left light direction consistent.
- Avoid grass platforms, dirt plates, dark shadow bars, or surrounding turf.
- Allow only light, local contact shading intrinsic to the stone edge.
- Assemble stones with subtle changes in rotation, spacing, and overlap.
- Align the final stone to the den threshold while keeping the den's structural doorstep or entry step attached to the den itself.

## Den and Root Seam Strategy

The root setting is separated into back and front layers so the den can appear nestled into the landscape rather than placed on top of it:

- `root_back` sits behind the den and establishes the large organic silhouette.
- `den` contains the building, its structural doorstep, and only object-intrinsic shading.
- `root_front` is a shallow occluder that overlaps the registered top and side insertion seams, with only limited thin roots or foliage allowed across selected lower corners. It may not form a wide lower base or dark grounding mass.
- Grass tufts, flower clusters, mushrooms, leaves, and small rocks are optional independent seam-softening assets.

The den must not include a grass floor, turf rectangle, detached stone road, or broad dark bottom shadow. A small physically plausible contact shadow may be supplied as a separate adjustable sprite if the seam test demonstrates it is necessary.

## Generation and Cleanup Rules

- Maintain the approved colorful, high-contrast cut-paper cartoon style; do not retain the legacy game's visual style.
- Use simple, readable silhouettes and low internal complexity for small assets.
- Favor bold color grouping, dark but warm edge definition, visible paper layering, and soft upper-left illumination.
- Every raw transparent-asset generation uses a perfectly flat **#FF00FF** chroma background. No final pixel may retain opaque chroma or visible magenta fringe.
- Never accept generated text, UI, frames, cell labels, watermarks, duplicated fragments, or partial neighboring objects.
- Preserve source prompts beside generated source sheets or individual source images.
- Chroma cleanup must remove colored fringe without eroding warm highlights or fine foliage.
- Review every asset both isolated on checkerboard and in a 1320 × 2868 reconstruction test.
- For every transparent asset, retain the raw chroma source, exact prompt, cleaned RGBA output, checkerboard QC image, reconstruction QC image, and metadata record. This evidence is mandatory, not optional.
- Record each extracted sprite's source cell, pixel bounds, intended anchor, and recommended scale range using the metadata schema below.

### Metadata schema

Store records in `metadata/edge_glade_assets.json`. Pixel values are integers. Bounds and anchors use top-left image origin with positive x rightward and positive y downward. Scale ranges are relative multipliers around the native intended display size.

```json
{
  "schema_version": 1,
  "assets": [
    {
      "id": "cloud_medium_01",
      "image": "clouds/final/cloud_medium_01.png",
      "source": "clouds/source/clouds_3x2_raw.png",
      "source_cell": { "column": 1, "row": 0, "width": 512, "height": 512 },
      "bounds_px": { "x": 24, "y": 51, "width": 460, "height": 208 },
      "anchor_px": { "x": 254, "y": 155 },
      "anchor_kind": "center",
      "display_size_px": { "width": 460, "height": 208 },
      "scale_range": { "min": 0.75, "max": 1.0 },
      "layer": "clouds",
      "motion_lane": 1,
      "wrap_padding_px": 96
    }
  ]
}
```

Use `center_bottom` for grounded sprites and `center` for clouds. Omit `motion_lane` and `wrap_padding_px` from non-cloud records. Asset IDs and filenames use lowercase snake case and are unique within the pack.

### Composition manifest

Store the reproducible default assembly in `metadata/edge_glade_composition.json`. Every placed occurrence has a unique instance ID and references an asset ID from `edge_glade_assets.json`. Positions are master-canvas pixels at the referenced asset anchor. Rotation is clockwise in degrees. `z_index` is an integer and provides deterministic ordering within the named layer.

```json
{
  "schema_version": 1,
  "canvas_px": { "width": 1320, "height": 2868 },
  "instances": [
    {
      "instance_id": "path_stone_01_instance_03",
      "asset_id": "path_stone_01",
      "position_px": { "x": 612, "y": 2318 },
      "display_size_px": { "width": 176, "height": 92 },
      "rotation_deg": -4.0,
      "layer": "path_stones",
      "z_index": 2,
      "visible": true
    }
  ]
}
```

The Gate 5 reconstruction must be rendered from this manifest rather than from hand-positioned, undocumented layers. Repeated use of a sprite creates multiple instance records; it does not duplicate the asset record.

## Output Layout

All work stays under:

`games/grove/assets/_new/ui_redesign_direction_b/edge_glade_layered_work_v1/`

Planned structure:

```text
edge_glade_layered_work_v1/
├── COMPOSITION_HANDOFF.md
├── edge_glade_dressed_reference.png
├── edge_glade_dressed_reference.prompt.txt
├── backdrop/
│   ├── source/
│   └── final/
├── vegetation/
│   ├── far/
│   ├── mid/
│   └── near/
├── clouds/
├── root_setting/
├── dens/
├── props/
├── scatter/
├── paths/
├── metadata/
└── review_composites/
```

Every generated category contains `source/` and `final/` subfolders. Raw generated images and exact prompt records belong in `source/`. Chroma-cleaned runtime candidates belong in `final/`. Checkerboard and reconstruction QC images belong in `review_composites/`, named with the asset or sheet ID and review type. Review composites must never be used as sprite sources.

## Review Gates

Generation stops after every gate until the user reviews the rendered result.

### Gate 1 — True backdrop

Deliver only the 1320 × 2868 backdrop and its prompt. Confirm canvas, horizon, radiance, meadow color, safe areas, and absence of baked objects.

### Gate 2 — Horizon system

Deliver far, mid, and near vegetation variations plus clouds, with an assembly test over the approved backdrop. Confirm depth, overlap, natural bases, and motion-ready cloud separation.

### Gate 3 — Root and default den seam

Deliver root-back, one default den, root-front, and only the minimum small accents required for a seam test. Include a focused composite with no unrelated props. Confirm that the den feels embedded without a turf island or dark bottom shadow.

### Gate 4 — Default supporting assets

Deliver the modular path, default individual props, and small sprite packs. Confirm consistent scale, camera, material, lighting, padding, and anchors.

### Gate 5 — Full reconstruction

Reconstruct the approved scene at 1320 × 2868 using only independent final assets. Confirm visual coherence, depth order, path-to-threshold alignment, seam handling, safe areas, and absence of forced-looking placement.

### Gate 6 — Variants and animation preparation

Only after the default scene passes, generate additional den styles, expanded prop variations, or cloud animation integration assets.

## Initial Implementation Boundary

The first implementation plan and generation pass must cover **Gate 1 only**. It ends by presenting the true backdrop for user approval. No vegetation, cloud, den, root, path, prop, or scatter generation begins until that backdrop is approved.

## Definition of Done for the Full Pack

- Every visible scene component can be positioned independently according to the layer architecture.
- The full reconstruction matches the approved composition and art direction at production resolution.
- Objects integrate through overlap and modular edge accents rather than baked ground patches.
- The path reaches the den threshold and remains independently editable.
- Cloud sprites are ready for horizontal motion without repainting the backdrop.
- All final sprites have clean transparency, safe bounds, consistent visual rules, documented anchors, and traceable source prompts.
- Every review gate has explicit user approval.
