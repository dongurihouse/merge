# Cherry Blossom Garden v2 Design

## Objective

Revise the layered Cherry Blossom Garden so it retains the tactile paper-cut character of the original mock at phone scale, has stronger environmental depth, and feels planted into a dense garden instead of arranged on an empty flat sheet.

The v1 bundle remains untouched. The revision is created in `cherry_blossom_garden_elements_v2` on a 1320 x 2346 canvas.

## Scene architecture

- `map_mode`: `scene_mode`
- `visual_model`: `layered_raster`
- `runtime_object_model`: `separate_props + foreground_occluders`
- `collision_model`: `none`
- `engine_target`: `raw_canvas + project-native`
- foundation: opaque sky and continuous raked zen-sand only
- scenery: separate far, middle, and near mountain bands plus rear and near horizon vegetation
- terrain feature: one registered recessed koi pond with irregular planted stone banks
- hero props: independently placeable sakura trees, bridge, furnished pavilion, bonsai, torii, and one reusable stone-lantern master
- dressing: independent vegetation/flower and rock-cluster packs
- atmosphere: independent petal layer

## Material treatment

Every accepted runtime asset must retain visible fibrous paper tooth after being rendered in the 941 x 1672 reference-scale preview. A generated neutral paper-grain master provides a consistent material reference and may be composited inside each prop's alpha mask. There is no scene-wide grain overlay floating over object boundaries.

New or regenerated art explicitly requests coarse visible paper fiber, layered cardstock edges, and lightly mottled printed pigment. Glossy vector surfaces, smooth 3D plastic, and generic low-noise painting are rejected.

## Depth and foundation

The opaque foundation contains a pale blue paper sky and warm cream zen sand with deliberate broad raked arcs and flowing bands. The rake marks remain subtle but readable at phone scale and continue behind removable props without forming closed pads around them.

Three independent mountain plates create atmospheric distance:

1. far: pale blue-gray, lowest contrast, broad high silhouette;
2. middle: cooler muted blue, overlapping offset peaks;
3. near: darker slate-blue/green, lower silhouette partially hidden by vegetation.

Two independent horizon vegetation plates bridge the horizon:

- rear shrubs: pale broad lobes with intermittent gaps;
- near vegetation: larger darker clusters at left, center, behind the pavilion, and right edge.

At least 20 percent of the mountain silhouette remains visible.

## Pond and garden dressing

The pond is slightly lower than the sand. Its bank uses irregular stones in three size bands, interrupted by moss, grass, and flowers. Stones overlap inward over the water and carry only a narrow restrained inner depth tint. There is no bead-like alternating necklace, continuous raised wall, grass island, or broad shadow halo.

The vegetation pack contains nine compact props: short grass, wide grass, low shrub, tall shrub, pink flowers, mixed cream/coral flowers, low pond-overhang grass, flowering pond-overhang, and a tree-base flowering patch.

The rock pack contains nine compact props: two-stone cluster, three-stone cluster, five-stone crescent, large boulder trio, flat stepping cluster, rock with grass, rock with flowers, mossy rocks, and narrow pond-edge rocks.

Use approximately 14-18 vegetation placements and 7-10 rock placements. Cluster them around the pond, tree bases, horizon, pavilion, bonsai cell, gate approach, and lower edges while keeping the central sand readable.

## Hero prop corrections

- Sakura trees are placed approximately 25-30 percent larger than v1. The left tree remains dominant; center remains subordinate; right clips into the page edge.
- The pavilion contains exactly one low tea table, one teapot, one or two cups, and two or three round cushions. The tea service remains clearly legible beneath the roof at phone scale.
- One stone-lantern master is instantiated twice at identical size. The two instances flank the torii approach symmetrically and sit visually before the gate.
- Bridge, torii, bonsai, sakura, pavilion, and lantern finals all receive the same asset-local paper-grain treatment.
- No prop gains a gravel patch, turf platform, sticker border, universal outline, or broad detached bottom shadow.

## Acceptance criteria

- foundation and reconstruction are 1320 x 2346 RGB;
- every runtime prop is RGBA with transparent corners and zero visible magenta;
- three visually distinct mountain shades are visible;
- raked zen-sand marks remain readable at the 941 x 1672 review scale;
- paper grain is visible on every major prop at review scale;
- the pond reads lower than the surrounding sand;
- all three sakura trees are visibly larger than v1;
- the pavilion tea set is visible and complete;
- both lantern instances use one source image and identical display dimensions;
- at least 14 vegetation and 7 rock-cluster placements appear in the reconstruction;
- placements and manifests parse as valid JSON;
- v1 files and the original mock remain unchanged.

