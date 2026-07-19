# Fairy Hollow Original Mock V4 Design

## Goal

Rebuild Fairy Hollow as an editable Scene Workbench scene from
`games/grove/assets/_concepts/zones/fairy_hollow_original_mock_v1.png`.
The final composition must retain the mock's night-forest story while every
major placeable remains a complete, replaceable asset.

## Source and canvas

- The original mock is the composition, camera, scale, and content authority.
- `docs/design/art-style-guide.md` remains the Meadow Sky + Cut-Paper material,
  palette, light, and separability authority.
- The scene workbench canvas is `1320 x 2346`, center-bottom anchored. The
  931 x 1690 source mock is reference-only and is never used as a flattened
  runtime layer.

## Layer architecture

The new highest-version Fairy Hollow bundle uses a layered-raster scene mode.
`metadata/placements.json` is the sole authority for all movable asset
coordinates, dimensions, paint order, and cluster membership.

1. **Foundation** is one opaque, prop-free image containing only night sky,
   continuous meadow, creek, and the winding stepping-stone route. The route
   includes cottage-threshold stones and the table-area cobbles, but no bridge,
   structures, vegetation collars, props, animals, lanterns, or foreground
   occluders.
2. **Environment** is separate full-width or edge-framing art: distant hills,
   conifers, rear shrub band, framing trees/canopy, moon, and sparse stars.
3. **Hero clusters** are separate transparent assets: toadstool cottage,
   fox-den mound, sleeping fox and cushion, wishing well, stone bridge,
   stump picnic table, three stump stools, potted bluebells, main glowing
   mushroom cluster, secondary mushrooms, lower golden mushrooms, lantern
   assemblies, and small cottage fence.
4. **Contact dressing** is independent, irregular foliage/rock/flower detail
   grouped with each hero. It overlaps only local lower silhouettes, never
   creates a circular grass platform, and never covers a doorway, bridge deck,
   or other usable threshold.
5. **Foreground** is separate edge foliage, bridge-bank cover, side trunks,
   and top canopy that visually frames rather than hides hero objects.

## Reconstruction rules

- Regenerate clean complete props from the visible mock as the active visual
  reference; do not literal-cut objects that are occluded by foliage, water,
  other props, or the image edge.
- Every movable color sprite is transparent and shadow-free. Any grounding is
  a separate compact contact asset or shallow scene-layer detail.
- Match the mock's elevated three-quarter camera, upper-left light, cut-paper
  material, and readable object scale. Preserve the mock's spatial order:
  cottage upper-middle, den right, well left, picnic clearing center-lower,
  bridge lower-left over creek, and mushrooms/lanterns as landmarks.
- The stepping-stone route and creek remain in the foundation so their
  continuous connections stay exact beneath bridge, cottage, and clearing.
- Suspended lantern bodies and their warm glows remain separate so they can
  layer against any future backdrop.

## Workbench behavior and validation

- Use Scene Workbench `v4` conventions: repo-relative images, center-bottom
  anchors, unique ids/z values, and 0/10-19/100s/200s/250-420/500+ z bands.
- Each hero plus its contact details is a named cluster. Backdrop and broad
  environmental bands remain unclustered.
- The bundle must include a compositor, validation report, full reconstruction,
  review-size reconstruction, asset manifest with source/prompt provenance,
  and README instructions.
- Validation must fail closed for missing images, paths outside the bundle,
  malformed placements, visible chroma-key pixels, fully transparent accepted
  assets, and a missing foundation. It must permit normal Scene Workbench
  move/resize/reorder edits.
- Verify with normal compositor run, `--validate-only`, the focused Scene
  Workbench suite, and a real minimized `make shot-sw SCENE=fairy_hollow`
  capture using the new bundle root. The currently failing unrelated full fast
  suite is recorded as a branch baseline issue, not changed by this art task.

## Acceptance criteria

- The capture visibly reconstructs the original mock's river/bridge/cottage/
  den/well/picnic scene without any baked hero object in the foundation.
- Major objects can be selected, moved, resized, reordered, and grouped in
  Scene Workbench without compositor validation failing.
- Contacts make objects belong to the clearing without dark ovals, turf
  islands, forced flower rings, or grass-floor cutout plates.
- The scene is ready for a visual approval gate before integration into main.
