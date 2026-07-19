# Cherry Blossom Original Mock Zen Sand Design

## Objective

Regenerate the canonical `cherry_blossom_garden_original_mock_v1` concept so its walkable ground uses the pale raked zen-sand treatment from `cherry_blossom_garden`, while the original scene remains otherwise visually unchanged.

## Pipeline

- `map_mode`: `baked_scene_mode`
- `visual_model`: `baked_raster`
- `runtime_object_model`: `none`
- `collision_model`: `none`
- `engine_target`: project-native concept reference
- generation path: built-in image edit with two local image references

## Image roles

- Image 1, edit target: `games/grove/assets/_concepts/zones/cherry_blossom_garden_original_mock_v1.png`
- Image 2, material reference only: `games/grove/assets/_concepts/zones/cherry_blossom_garden.jpg`

Image 2 supplies only the pale ivory zen-sand color, fine fibrous paper grain, and broad subtle raked arcs. It does not supply composition, geometry, object designs, object placement, or scale.

## Transformation

Replace only the continuous pale meadow and cream walkable ground in Image 1 with raked zen sand. The rake marks should follow the ground perspective, flow naturally around the existing stepping stones and fixed objects, remain subtle at phone scale, and disappear cleanly beneath all occluding objects.

The resulting sand should retain the original scene's warm paper-cut material language and upper-left lighting. It must not become stark white, striped, noisy, photorealistic, or detached from the scene.

## Locked invariants

Preserve Image 1's exact portrait framing and overall composition, including:

- sky, clouds, mountain silhouettes, hills, and horizon vegetation;
- pond and river shapes, shoreline stones, water texture, lily pads, koi, and petals;
- stepping-stone path geometry and placement;
- pavilion, bridge, torii gate, lanterns, sakura trees, shrubs, flowers, rocks, and all object scale and placement;
- palette, paper-cut rendering, lighting direction, shadows, depth order, and edge treatment.

Do not add, remove, redesign, resize, or move any object. Do not import the wider river layout, bonsai placement, pavilion placement, or other scene geometry from Image 2. Add no UI, text, labels, borders, or watermark.

## Files

- Replace the canonical concept PNG at `games/grove/assets/_concepts/zones/cherry_blossom_garden_original_mock_v1.png` after visual review.
- Replace its prompt sidecar with the exact accepted edit prompt.
- Keep the historical v4 decomposition reference copy unchanged.

## Acceptance criteria

- Output is an opaque RGB/RGBA PNG at exactly 930 x 1691 pixels.
- The original composition and all locked objects remain immediately recognizable in the same positions and proportions.
- Former meadow ground reads as pale ivory raked zen sand at both full resolution and phone-scale review.
- Rake marks are visible but subordinate to the scene and do not cross water, objects, rocks, vegetation, or stepping stones.
- No text, UI, labels, watermark, added props, missing props, or obvious generation artifacts appear.
- The prompt sidecar records both image roles and all invariants.

