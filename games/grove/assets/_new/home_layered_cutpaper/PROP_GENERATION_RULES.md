# Cut-Paper Home Prop Generation Rules

These rules are the reusable source of truth for structures placed over the road-free importable runtime plate at `games/grove/assets/map/home_layered_cutpaper/home_base_no_road.png`. Raw generations and prompts remain here under `_new`; cleaned review assets live in the importable map folder.

## Shape and complexity

- Generate exactly one readable structure per image at a three-quarter elevated storybook-map angle.
- Use a chunky silhouette and a maximum of three major architectural masses.
- Keep surface detail broad: large roof tiles, simple wall panels, and a few oversized accents. Avoid tiny trim, dense foliage, and texture noise.
- Preserve a clean center-bottom anchor and generous transparent padding.

## Color and material

- Use saturated coral, cobalt, violet, lemon, mint, emerald, lime, white, and deep navy.
- Use two or three visible cut-paper layers with subtle paper fiber.
- Use a narrow deep-green or navy cut edge. Never use a white sticker halo.
- Keep the prop slightly more saturated than the foundation while sharing its material and contrast.

## Ground contact

- End the building sprite at its real architectural foundation and attached architectural steps. Do not confuse the house steps with the separate stepping-stone road layer.
- Never include grass, turf, soil, a ground pad, flowers, rocks, shrubs, path pieces, or any environment silhouette in a building sprite.
- Do not bake a cast shadow, contact shadow, outline shadow, glow, or dark grounding strip into the building, stair, or grass sprites.
- Ground the building with three to five small independent grass clusters placed around portions of the lower foundation edge. Never form a continuous ring or skirt.
- Grass clusters contain connected blades or leaves only, with transparent gaps and no soil, turf slab, rocks, or shadow. Keep the doorway and path corridor clear.
- Remove road stones from the base background. Generate several individual road-stone variants as transparent props and create straight or curved routes through placement data.

## Isolation and cleanup

- Generate against a perfectly flat solid `#FF00FF` background with no gradient, texture, floor, horizon, border, or vignette.
- Do not generate UI, badges, labels, numbers, characters, animals, outlines, or restoration effects.
- Prefer the shared image-generation chroma cleanup with border-key sampling, soft matte, despill, and a one-pixel edge contraction. Keep magenta and violet out of exposed building edges so cleanup cannot create a colored fringe.
- Use `games/grove/tools/chroma_connected_prop.py` only when an approved design contains essential raspberry or violet interiors that the shared despill pass would damage.
- Crop to alpha bounds with padding and place by center-bottom anchor.
