# Cherry Garden Koi and Horizon Design

## Goal

Improve the layered cherry-blossom garden workbench by adding editable koi to the baked-in pond and restoring visual clearance between the pond and the distant landscape.

## Koi asset

- Generate one 2 x 3 source pack containing six individual koi viewed from directly above.
- Match the current cherry-garden paper-cut picture-book rendering: simple shapes, crisp high-contrast markings, light paper texture, and no photoreal detail.
- Use varied traditional koi markings across white, vermilion, orange, gold, and black.
- Keep each fish isolated in its cell on flat chroma-key magenta, with no water tile, cast shadow, ripple halo, plants, rocks, text, or border.
- Process the pack into six transparent individual PNG sprites and retain the source prompt and processing metadata.
- Give the fish slightly softened, water-muted color and highlights within their silhouettes so they read below the water surface without requiring an opaque water patch.

## Koi composition

- Place five of the six koi as separate workbench placements in a `koi` cluster.
- Vary position, rotation, and scale to avoid a stamped pattern while keeping the school sparse and readable.
- Keep every koi fully inside the blue pond water and away from the stone shoreline.
- Paint koi above the baked backdrop but below pond-edge dressing, bridge, and other structures.
- Concentrate the school in the open central and lower pond, with no koi hidden under the bridge.

## Distant landscape adjustment

- Move only these five full-width background layers upward as one visual group:
  - `mountain_far`
  - `mountain_middle`
  - `mountain_near`
  - `horizon_vegetation_rear`
  - `horizon_vegetation_near`
- Preserve their relative spacing, scale, horizontal alignment, and z-order.
- Do not move the seven pond-edge vegetation and rock placements or any foreground props.
- Raise the group enough that the distant vegetation no longer covers the pond's upper water boundary, while keeping the landscape connected to the top edge of the scene.

## Integration and review

- Update `metadata/placements.json` through `scene_workbench_model.gd`, preserving unknown metadata and the existing one-time backup behavior.
- Render a fresh workbench screenshot using `make shot-sw`.
- Visually verify koi containment, koi scale and style, pond-edge clearance, landscape continuity, and correct z-order.
- Run the existing fast test suite before completion.

## Out of scope

- Editing the baked pond or backdrop.
- Moving pond-edge vegetation, bridge, pavilion, cherry trees, bonsai, torii, lanterns, or foreground dressing.
- Animating the koi in this pass.
