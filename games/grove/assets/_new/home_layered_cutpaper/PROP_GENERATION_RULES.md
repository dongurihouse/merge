# Cut-Paper Home Prop Generation Rules

These rules are the reusable source of truth for structures placed over the importable runtime plate at `games/grove/assets/map/home_layered_cutpaper/home_base.png`. Raw generations and prompts remain here under `_new`; cleaned review assets live in the importable map folder.

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

- Connect the structure to one irregular opaque turf skirt, 8 to 16 percent of the total prop height.
- Match the foundation's lime-green grass and use only a few large grass tufts, stones, leaves, or flowers.
- Keep the turf silhouette organic; never use a rectangle, circle, or obvious placement pad.
- Illuminate from the top left. Paint one small soft down-right contact shadow entirely on the opaque turf skirt.
- No shadow, flower, stone, or leaf may float as a detached alpha island.

## Isolation and cleanup

- Generate against a perfectly flat solid `#FF00FF` background with no gradient, texture, floor, horizon, border, or vignette.
- Do not generate UI, badges, labels, numbers, characters, animals, outlines, or restoration effects.
- Extract the largest connected non-magenta silhouette with `games/grove/tools/chroma_connected_prop.py`; this preserves raspberry and violet interiors while removing textured magenta spill.
- Crop to alpha bounds with padding and place by center-bottom anchor.
