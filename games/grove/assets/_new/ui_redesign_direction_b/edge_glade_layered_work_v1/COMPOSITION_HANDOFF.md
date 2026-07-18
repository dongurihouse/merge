# Edge Glade Layered Composition Handoff

**Purpose:** handoff for the agent that will rebuild the approved Edge Glade dressed mock as a coherent layered composition with independently generated elements.

**Reference image:** `edge_glade_dressed_reference.png` (`853 × 1843`, reference-only)

**Source prompt:** `edge_glade_dressed_reference.prompt.txt`
**Shared art rules:** `docs/design/meadow_sky_cut_paper_generation_guide.md`

## 1. What the image is

The Edge Glade is the welcoming first clearing on the Acorn Forest Lantern Trail. A pale path enters from the bottom, climbs through a small lived-in garden clearing, and ends at a woodland creature's home set beneath the roots of a mature tree.

The scene should communicate this sequence without text:

`forest trail -> mailbox -> tended living area -> lantern-lit threshold -> creature home`

It is not a collection of decorations arranged around an empty lawn. Every object must have a believable reason for its location:

- the mailbox greets visitors near the approach;
- the bench creates a resting place with a view of the path and home;
- the berry planter and tools form one gardening area without touching;
- the firewood sits in a dry, accessible storage area;
- the lantern illuminates the final approach;
- the doormat belongs at the threshold;
- flowers and mushrooms grow at sheltered perimeter edges;
- the path terminates exactly at the door.

The reference is approved for overall direction: larger close creature home, readable path, separated props, Meadow Sky color, Cut-Paper Playground material, and quiet UI-safe space. It is not a runtime asset and must not be used as a source for cutting out props.

## 2. Production model

Use this pipeline:

- `map_mode`: `scene_mode`
- `visual_model`: `layered_raster`
- `runtime_object_model`: separate selectable props + invariant foreground occluders
- `collision_model`: none; this is a cosmetic customization scene
- `engine_target`: project-native Godot composition
- anchor convention: center-bottom for every replaceable element

The runtime scene is composed from:

1. foundation-only background;
2. invariant root/tree back layer;
3. restore-only natural elements;
4. independently customizable elements;
5. invariant foreground root/foliage occluders;
6. UI, added by the game rather than baked into art.

The current `853 × 1843` image establishes the composition and aspect ratio. Use that exact canvas for the first round-trip reconstruction. Before runtime integration, confirm whether the production manifest requires a larger canvas and scale all placements consistently rather than regenerating at mismatched ratios.

## 3. Layer split

### Foundation-only plate

The foundation contains:

- Meadow Sky sky and distant blue forest silhouettes;
- distant hills and broad low-detail foliage masses;
- one continuous meadow ground plane;
- the complete pale approach path, ending at the den threshold;
- subtle ground color variation and low flat leaf shapes;
- empty, neutral placement areas for every element.

The foundation must not contain any selectable object's silhouette, cast shadow, turf island, flower ring, shaped pad, or object-specific hole. It must still look coherent when every element is hidden.

### Invariant tree/root setting

Do not make the entire mature tree customizable. Split it into:

- `root_canopy_back`: the large tree trunk, root mound, moss, and cavity behind the den;
- `root_lip_front`: a small foreground occluder that overlaps the top and side edges of the inserted den shell.

The cavity between these layers is a registered home slot. Every den variation uses the same center-bottom anchor, doorway position, threshold width, maximum envelope, and occlusion seam. This preserves the impression that the home is nested beneath roots without requiring every home style to regenerate the whole tree.

### Restore-only natural elements

These have build/restoration states but no cosmetic style picker:

- Wildflower Patch
- Toadstool Cluster

Each must be a separate transparent element so it can progress from grey/absent to fully restored. Consolidate the reference's scattered prominent flowers into one readable Wildflower Patch element. The foundation may retain sparse green ground leaves, but not colored flowers that undermine the patch's restoration states.

### Customizable elements

These are generated and replaced independently:

1. Hollow-Log Den
2. Mossy Bench
3. Berry-Bush Planter
4. The First Lantern
5. Acorn Mailbox
6. Doormat
7. Twig/Firewood Stack
8. Tiny Garden Tools set

`Acorn Mailbox` replaces the earlier generic `Trail Signpost` in this composition. If runtime data still names the slot `eg_signpost`, either migrate it to `eg_mailbox` or explicitly document the compatibility alias; do not silently ship a mailbox under a misleading content name.

The watering can plus hand trowel form one registered Garden Tools set. They may overlap one another inside that sprite, but the set must remain separate from the planter, den, and other objects.

This scene intentionally has ten visible runtime element candidates: eight customizable elements plus two restore-only natural elements. That is an explicit exception to the usual nine-candidate reference-mock limit because the item roster was directly approved.

## 4. Placement intent

Coordinates below are starting envelopes for the `853 × 1843` reference canvas, not final pixel-perfect measurements. The composition agent should refine them during round-trip reconstruction while preserving their semantic relationships.

| Element | Intended area | Approximate anchor `(x,y)` | Approximate display envelope | Placement rule |
| --- | --- | ---: | ---: | --- |
| Hollow-Log Den | upper-middle hero | `(475, 1010)` | `560 × 500` | Door centered on path; close and dominant |
| Doormat | threshold | `(475, 1055)` | `180 × 75` | Directly before door; distinct from path |
| Mossy Bench | middle-left rest area | `(205, 1020)` | `275 × 180` | Faces path/home; does not touch roots |
| Firewood Stack | lower-left dry area | `(125, 1195)` | `210 × 120` | Separate grass gap from bench and lantern |
| First Lantern | final approach, left of path | `(320, 1160)` | `105 × 145` | Small, mailbox-scale; never a monument |
| Berry Planter | middle-right garden area | `(695, 1095)` | `220 × 190` | Large readable crate/planter silhouette |
| Garden Tools set | lower-right garden area | `(735, 1310)` | `225 × 175` | Near planter but separated by visible grass |
| Acorn Mailbox | lower-left approach | `(150, 1490)` | `225 × 260` | Visitor-facing; open grass around hit area |
| Wildflower Patch | right perimeter | `(755, 1460)` | `190 × 220` | One consolidated colored-flower patch |
| Toadstool Cluster | lower-right perimeter | `(655, 1590)` | `220 × 170` | Natural sheltered edge; separate from flowers |

Composition constraints:

- Keep approximately one prop-width of visible grass between neighboring selectable elements whenever possible.
- No selectable silhouettes may touch, overlap, hide behind, or visually fuse with one another.
- The home is the only large hero; all cozy items remain subordinate but readable at phone size.
- Spread elements through the central 60% of the screen instead of crowding the doorway.
- Preserve the upper 15–18% as quiet sky/distant foliage and the lower 12–15% as path entry/open meadow for UI.
- Keep every important hit area away from extreme side edges.
- The path does not loop, fork, or continue behind the den.

## 5. Shared customization style families

Initial production should use four coherent style families. A player may mix them, but each family also forms a visually coordinated full-clearing set.

### A. Woodland Natural

The default, low-cost set. Moss, warm bark, muted garden green, cream fiber, and simple handmade joinery. Decoration is minimal and practical.

### B. Meadow Bloom

Friendly floral set. Warm cream, coral petals, garden green, small daisy motifs, rounded painted details, and woven flower accents. Colorful but not dense or frilly.

### C. Acorn Craft

Story-rich crafted set. Carved acorn motifs, warm wood, restrained reward-gold hardware, scalloped forms, and neat artisan construction. Gold remains a small meaningful accent.

### D. Moonlit Trail

Quiet premium story set that still works in daylight. Structural slate, receding blue, rare purple, cream star or moon cutouts, and restrained gold light. It must not turn the scene dark, neon, crystalline, or high-fantasy.

Seasonal sets are deferred. Do not introduce autumn-orange, snow, holiday holly, or unrelated themes in the first composition pack.

## 6. Per-element variation matrix

Each element keeps one invariant footprint and anchor across all variants. Variants change silhouette details and finish without changing scale class or blocking neighboring slots.

| Element | Woodland Natural | Meadow Bloom | Acorn Craft | Moonlit Trail |
| --- | --- | --- | --- | --- |
| Hollow-Log Den | Bare Log: bark arch, moss cap, slate-blue round door | Flower-Wreathed: cream trim, coral blossoms, leaf window | Carved Acorn: acorn door relief, scalloped wood trim, small gold latch | Star Window: slate door, cream star window, purple-blue trim, tiny gold light |
| Mossy Bench | Simple log bench with moss cushion | Cream-painted bench with coral flower end caps | Carved acorn finials and tidy slat seat | Slate-blue bench with purple cushion and small star cutouts |
| Berry Planter | Plain timber crate with berry bush | Cream flower box with coral blooms and berries | Woven acorn basket planter with gold-colored ties | Slate planter with night-blue leaves and sparse purple blooms |
| First Lantern | Woven-reed or simple wood lantern | Cream-and-coral flower glass lantern | Carved acorn lamp with restrained gold frame | Star-jar lantern with slate frame, cream glow, rare purple accent |
| Acorn Mailbox | Plain acorn shell on a wood post | Cream/coral painted acorn with flower flag | Carved acorn shell with small gold flag hinge | Slate-blue acorn with cream star flag and purple trim |
| Doormat | Woven leaf-fiber mat | Daisy-braid cream/coral mat | Acorn-weave geometric mat | Slate-and-cream star-stitch mat |
| Firewood Stack | Loose tidy twig stack with simple bark tones | Neat bundle tied with coral flower cord | Small carved wood rack with acorn end caps | Covered slate rack with purple tie and cream star notch |
| Garden Tools set | Green watering can, wood-handled trowel | Cream can with coral flower mark, coral handles | Acorn-embossed can, carved handles, small gold hardware | Slate can, receding-blue handles, cream star perforations |

Variation rules:

- Keep every surface within the Meadow Sky palette roles. Natural bark may use desaturated warm brown compatible with the palette.
- Use only one or two family motifs per item. Avoid costume-like over-decoration.
- Preserve large readable handles, doors, caps, seats, and tool heads.
- Do not add loose flowers, rocks, grass, path pieces, or scenic bases to make a variant look richer.
- Do not let a premium variant become larger, brighter, or more complete than a coin variant.

## 7. Restoration/build states

Build state and cosmetic style are separate axes.

### Wildflower Patch and Toadstool Cluster

- `state_0`: absent or muted grey silhouette/ground trace;
- `state_1`: sparse buds or small caps, partial color;
- `state_2`: complete restored form in full Meadow Sky color.

These do not receive the four customization families.

### Cozy items

- `state_0`: empty placement area; no baked pad;
- `state_1`: compact believable work-in-progress material, such as a small tied bundle or simple frame;
- `state_2`: built default variant;
- customization variants become available only after built.

### Hollow-Log Den and First Lantern

Follow their scene-spec step counts. Intermediate construction states must fit the same registered envelope and must not change the path, tree, or neighboring placement areas.

## 8. Asset-generation contract

Generate identity-sensitive or large objects one by one:

- Hollow-Log Den
- Mossy Bench
- Berry-Bush Planter
- First Lantern
- Acorn Mailbox

The smaller Doormat, Firewood Stack, Garden Tools set, Wildflower Patch, and Toadstool Cluster may be generated in one compact prop pack only if every object receives an equal cell, generous chroma-key margin, and no edge contact. If any silhouette is clipped or scale drifts, regenerate it one by one.

For every asset:

- show both the original foundation and dressed reference immediately before generation;
- state their roles explicitly in the prompt;
- match the exact elevated three-quarter camera, upper-left light, Meadow Sky palette, Cut-Paper Playground material, and reference scale;
- use a perfectly flat removable chroma-key background;
- keep the full object visible with generous padding;
- save the exact prompt beside the raw and cleaned result;
- remove chroma key deterministically and inspect alpha edges;
- use center-bottom anchors and explicit display envelopes;
- include a tight contact shadow only when it belongs to the sprite;
- never include a grass floor, turf skirt, path, water, detached flower ring, rocks, or mini-landscape base.

Do not extract objects from `edge_glade_dressed_reference.png`. Generate them separately from the visible reference context.

## 9. Recommended work-folder output

The composition agent should extend this folder to this shape:

```text
edge_glade_layered_work_v1/
  COMPOSITION_HANDOFF.md
  edge_glade_dressed_reference.png
  edge_glade_dressed_reference.prompt.txt
  foundation/
    edge_glade_foundation.png
    edge_glade_foundation.prompt.txt
  invariant/
    root_canopy_back.png
    root_lip_front.png
  elements/
    hollow_log_den/<style>.png
    mossy_bench/<style>.png
    berry_planter/<style>.png
    first_lantern/<style>.png
    acorn_mailbox/<style>.png
    doormat/<style>.png
    firewood_stack/<style>.png
    garden_tools/<style>.png
    wildflower_patch/<state>.png
    toadstool_cluster/<state>.png
  data/
    edge_glade_placements.json
  edge_glade_reconstruction.png
```

Suggested placement fields:

```json
{
  "id": "eg_mailbox",
  "image": "elements/acorn_mailbox/woodland_natural.png",
  "x": 150,
  "y": 1490,
  "w": 225,
  "h": 260,
  "anchor": "center_bottom",
  "sort_y": 1490,
  "layer": "props",
  "hit_shape": { "type": "rect", "x": -92, "y": -220, "w": 184, "h": 220 }
}
```

The actual hit shape should follow the visible object while remaining forgiving at phone scale. It must not overlap another element's primary hit area.

## 10. Required review gates

Do not generate all variants immediately.

1. Create the foundation with every selectable item removed.
2. Create `root_canopy_back` and `root_lip_front` and verify the den slot.
3. Generate only the Woodland Natural Hollow-Log Den.
4. Reconstruct foundation + roots + den and obtain owner approval.
5. Generate one Woodland Natural version of every remaining element.
6. Reconstruct the complete scene from individual assets and compare at original detail.
7. Verify item spacing, scale, grounding, path termination, UI-safe margins, and hit-area separation.
8. Obtain owner approval before generating the other three style families.

The reconstruction is accepted only when it feels like one coherent illustration and no object looks pasted onto its own piece of grass.

## 11. Rejection conditions

Reject the composition or asset when any of these occur:

- den is small, distant, cornered, or obscured;
- props cluster against the house or overlap one another;
- mailbox, lantern, tools, or doormat are too small to recognize;
- lantern becomes a monument;
- path misses the doorway, forks, loops, or continues behind the den;
- removing an object reveals its shadow, flower ring, pad, or grass island;
- an object sprite includes surrounding turf or unrelated scenery;
- the root occluder cannot hide the den insertion seam;
- variant silhouettes change the registered footprint or collide with neighbors;
- scale, camera, paper depth, light, or shadow direction differ between assets;
- colored flowers remain baked into the foundation and conflict with restoration states;
- the scene becomes glossy, painterly, clay-like, sticker-like, neon, dark fantasy, or overly detailed.

## 12. Source-of-truth links

- Shared image-generation guide: `docs/design/meadow_sky_cut_paper_generation_guide.md`
- Palette authority: `games/grove/assets/_new/ui_redesign_direction_b/palette_studies_board_v1/palette_a_meadow_sky_board.png`
- Camera/scale authority: `games/grove/assets/_new/ui_redesign_direction_b/screen_reference_pack_meadow_sky_v1/home_screen_meadow_sky_v2_working_farm.png`
- Journey design: `/Users/xup/dh/merge/docs/superpowers/specs/2026-07-17-acorn-forest-journey-design.md`

Before asset production, reconcile the Journey design's original `Trail Signpost` slot with this handoff's approved `Acorn Mailbox` replacement.
