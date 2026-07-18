> **SUPERSEDED (archived 2026-07-18).** This doc was absorbed into the single `docs/design/art-style-guide.md` — the production source of truth for art direction and asset generation. Kept for history; do not treat as current.

# Meadow Sky + Cut-Paper Playground Image Generation Guide

**Status:** production art-direction source of truth
**Applies to:** Grove UI mocks, Home and Maps scenes, Acorn Forest clearings, buildings, props, icons, and customization variants
**Default direction:** Meadow Sky palette + Cut-Paper Playground style

This guide gives another agent enough context to generate new images without relying on prior chat history. Scene-specific design specs still control content, topology, and item lists. When a scene spec conflicts with a generic example in this guide, follow the scene spec while preserving the fixed palette, material, camera, scale, and separability rules below.

## 1. Mandatory visual references

Every new mock or world-scene generation must include these references with explicit roles:

1. **Palette and material authority**
   `games/grove/assets/_new/ui_redesign_direction_b/palette_studies_board_v1/palette_a_meadow_sky_board.png`
2. **World camera, object scale, shadow, and detail-budget authority**
   `games/grove/assets/_new/ui_redesign_direction_b/screen_reference_pack_meadow_sky_v1/home_screen_meadow_sky_v2_working_farm.png`

Do not tell the model merely to “match the references.” State what each image controls and what must not be copied:

- The board controls palette relationships, matte paper treatment, warm cut edges, UI surfaces, and shallow shadows. It does not control world layout or content.
- The Farm controls elevated three-quarter camera, common scale, landscape integration, silhouette simplicity, vegetation density ceiling, and detail budget. It does not authorize copying its buildings, path network, UI, or farm theme.

For an edit, add the current image as the first reference and identify it as the precise edit target. The two approved images remain supporting authorities.

## 2. Fixed Meadow Sky palette

| Role | Color | Usage |
| --- | --- | --- |
| Sky / distant atmosphere | `#6FA9C0` | Open sky, broad page background |
| Structural slate | `#3F6D7D` | Deep structure, water, roof/details |
| Shared meadow | `#A8D3B9` | Large ground and open cells |
| Receding blue | `#8296AF` | Distant hills, locked/inactive surfaces |
| Warm cream | `#F6EBDD` | Paths, cards, pills, light surfaces |
| Ink | `#243B4B` | Text and deepest local edge; never large black masses |
| Garden/action green | `#5F9B6D` | Selected states, foliage accents, primary action |
| Coral | `#D87865` | Flowers, doors, small roof or feedback accents |
| Reward gold | `#D6A94C` | Coins, keystones, rewards, small light accents |
| Rare purple | `#8677A3` | Sparse story or secondary accent |
| Tinted shadow | `#294654` | Approximately 18–20% opacity |

Color rules:

- Keep 60–70% of a screen below roughly 45% saturation.
- Large backgrounds use approximately 28–42% saturation; structural surfaces 32–48%; actions 55–70%; small gameplay items may reach 65–85%.
- Reserve the strongest chroma for interactive objects, fruit, crops, rewards, keystones, and feedback.
- Use cream and ink as the neutral pair, one dominant structural family, one action color, and at most two supporting accents in a local composition.
- Purple is rare. Gold is meaningful. Coral is an accent, not a default repeated roof color.
- Avoid pure white, pure black, neon color, electric cyan, ultramarine dominance, lime grass, muddy brown scenes, and equal-strength rainbow treatment.

## 3. Cut-Paper Playground material rules

The world is made from friendly matte hand-cut cardstock, not plastic, clay, stickers, watercolor, or a realistic miniature diorama.

- Use broad, rounded, low-complexity silhouettes.
- Limit a building or major prop to two or three dominant masses.
- Give each surface one flat base color and at most one same-hue shadow plane.
- Use subtle paper fiber: about 2–4% local value variation.
- Use a fine warm cut edge plus a thin locally darker edge.
- Do not use universal white sticker outlines or heavy black outlines.
- Use one upper-left light source. Cast and contact shadows fall shallowly down-right.
- Shadows are soft, short, tinted, and approximately 18–20% opacity. They explain contact; they must not create deep paper sculpture.
- Consolidate leaves, flowers, shingles, stones, and ornament into a few readable shapes. Never render thousands of tiny details.
- Features must remain legible at phone size: large doors, windows, handles, fruit, caps, and tool heads.

## 4. Camera, canvas, and UI-safe framing

### Full mobile-screen mocks

- Default to a modern iPhone portrait aspect ratio near `9:19.5` unless the consuming screen specifies exact dimensions.
- Use an elevated three-quarter storybook-map camera, never eye-level and never a flat top-down board-game view.
- Reserve the upper 15–18% for resource pills and other chrome. Use quiet sky, distant hills, or simple distant foliage there.
- Reserve the lower 12–15% for navigation or actions. Use path entry, open meadow, or low foreground foliage there.
- Concentrate meaningful world content in the middle band with comfortable left/right margins.
- Do not draw UI during a background-only or environment-approval pass.

### Foundation and production art

Use the exact canvas defined by the consuming scene or manifest. Existing three-zone references use `941 × 1672`; do not silently substitute that size for a scene with a different runtime contract.

## 5. Scene-composition logic

Generate a believable place first and a list of required items second. The image must explain how someone approaches, lives in, and uses the location.

### Spatial story

Organize a clearing into four semantic areas:

1. **Approach:** where the player visually enters; suitable for a mailbox, gate, or wayfinding object.
2. **Activity:** a garden, rest area, workshop, water edge, or other useful middle-space.
3. **Threshold:** the final steps, light, doormat, and entrance of the creature home or hero building.
4. **Perimeter:** wildflowers, mushrooms, roots, hedges, rocks, and other natural backdrop elements.

A prop belongs where it would be used. Do not distribute objects only to balance the frame.

### Paths

- A path is narrative structure, not filler.
- It enters from a plausible boundary and terminates exactly at a door, gate, bridge, or destination.
- It may bend gently to reveal the scene.
- Do not create loops, forks, crossroads, or paths continuing behind a destination unless the scene spec requires them.
- The path must meet steps and thresholds naturally and share the same perspective.

### Focal hierarchy

- Establish one clear hero structure or destination.
- On a single-home clearing screen, the creature home should normally occupy about 55–62% of canvas width and sit in the upper-middle, close enough to inspect and customize.
- Secondary objects must remain large enough to recognize and tap, but no cozy item or lantern may compete with the home.
- Keystone lanterns are landmarks, not buildings. A normal path lantern is approximately mailbox-sized and much smaller than the home.
- Use asymmetry and overlap in background vegetation, but keep interactive silhouettes distinct.

### Negative space

- Keep breathing room without leaving a large hollow oval in the center.
- Fill the center with meaningful circulation: path, threshold, and one or two activity relationships.
- Large quiet areas belong in UI-safe margins or intentionally calm zone fields, not between unrelated props.

## 6. Customizable-object separability

Every cozy item, creature home, keystone, and other customizable element must be removable, replaceable, and selectable independently.

### In a dressed mock

- Give every customizable element a complete readable silhouette and its own clear ground footprint.
- Leave approximately one prop-width of visible grass between neighboring customizable elements whenever possible.
- Related items may be near one another but must not touch, overlap, hide, or visually fuse.
- Do not place small props inside the home silhouette, beneath its roots, or against its wall.
- Spread items through the middle play area instead of crowding every object around the home.
- Natural backdrop vegetation may overlap other natural backdrop shapes, but must not obscure interactive items.
- Keep item scale large enough to preview its customization differences at phone size.

### In separate production assets

- Generate exactly one object per asset unless a registered customization slot explicitly groups pieces, such as a watering can plus trowel tool set.
- Use the same center-bottom anchor, contact geometry, display envelope, camera, and light direction for every variant of an object.
- Include only tight contact shadow and truly attached components.
- Do not include grass skirts, turf islands, path pieces, water, banks, loose rocks, detached flowers, flower rings, or mini-landscape bases.
- A few tight overlapping grass blades may be part of the foundation, not the object sprite.
- Use a flat removable chroma-key background for raw generation; remove it deterministically and inspect the alpha edge before integration.
- Reconstruct the dressed scene from foundation plus extracted objects. If the reconstruction looks pasted-on, fix grounding, anchor, scale, or shadow rather than adding a scenic base.

## 7. Grounding and shared-world coherence

- All elements stand on one continuous meadow, orchard floor, path system, or water body.
- Match camera pitch, horizon, scale, light direction, and shadow length across every asset.
- Use tight down-right contact shadows and minimal local grass overlap to connect objects to the ground.
- Paths, waterlines, bridge endpoints, doors, and steps must physically meet.
- Foundations remain coherent with every customizable object hidden.
- Foundations must not contain object shadows, shaped pads, building-specific flower rings, or empty silhouettes that only work with one variant.
- Never use circular clearings, rectangular pads, abrupt color patches, glowing borders, sticker halos, turf islands, or forced scenic bases beneath individual objects.

## 8. UI treatment

When the requested image includes UI:

- Use warm-cream cards and resource pills with ink text and shallow tinted shadows.
- Navigation shares a coordinated quiet surface family; only the selected tab receives the full action accent.
- Use soft-tinted resident or content cards, not fully saturated slabs.
- Gameplay objects and feedback remain more colorful than chrome.
- Preserve exact requested text. Do not invent labels, badges, counters, or extra buttons.
- For environment or background approvals, omit UI completely so composition can be judged independently.

## 9. Prompt construction

Every prompt should explicitly state:

1. use case and asset type;
2. input-image roles;
3. scene purpose and spatial story;
4. required items and their fictional use;
5. canvas, camera, and UI-safe areas;
6. focal and scale hierarchy;
7. customization/separability requirements;
8. palette and material rules;
9. grounding rules;
10. a targeted avoid list.

Prefer semantic instructions over arbitrary coordinates. For example, write “place the mailbox where a visitor first reaches the home” before prescribing left/right placement. Add coordinates only when the runtime layout or a rejected composition requires precise correction.

### Reusable full-scene prompt scaffold

```text
Use case: stylized-concept
Asset type: vertical mobile game environment mockup

Input images:
- Image 1: mandatory Meadow Sky palette and Cut-Paper Playground material authority; do not copy its UI or board layout.
- Image 2: mandatory elevated three-quarter camera, common scale, shallow shadow, and detail-budget authority; do not copy its farm content or UI.

Primary request:
Create [SCENE] as a believable [PLACE/PURPOSE]. The visual story is [APPROACH -> ACTIVITY -> DESTINATION]. Arrange required elements according to how the place is used, not as evenly spaced showcase props.

Required content:
[LIST EACH ELEMENT, ROLE, AND FICTIONAL USE]

Composition:
- Modern iPhone portrait; upper 15–18% and lower 12–15% remain UI-safe.
- Elevated three-quarter camera.
- One hero destination with a clear path that terminates at it.
- Interactive items are large, readable, separated by visible ground, and never overlap.
- Natural backdrop elements frame the perimeter.

Style:
Use the fixed Meadow Sky role colors and Cut-Paper Playground rules from the generation guide. One upper-left light, subtle paper fiber, warm cut edges, shallow tinted contact shadows, broad low-detail silhouettes.

Grounding:
One continuous ground plane. No turf islands, pads, sticker halos, object-specific flower rings, or scenic bases.

Avoid:
inventory-display layout, hollow center, arbitrary grid, oversized keystone, tiny distant hero, crowded doorway, overlapping customizable items, painterly gradients, glossy plastic, realistic miniature diorama, dense micro-detail, UI, text, watermark.
```

### Reusable separate-object prompt scaffold

```text
Use case: stylized-concept
Asset type: reusable game object sprite

Create exactly one [OBJECT] matching the supplied approved scene and mandatory Meadow Sky references. Preserve the scene's elevated three-quarter camera, scale, upper-left light, shallow down-right contact shadow, matte cardstock, warm cut edge, and low detail budget.

The object must fit the registered [WIDTH x HEIGHT] display envelope with a center-bottom anchor. Keep the entire silhouette visible with generous padding. Include only attached components and a tight contact shadow. No grass skirt, turf island, path, water, bank, detached flowers, loose rocks, scenic base, text, character, or watermark.

Render on one perfectly flat chroma-key background color that does not occur in the object, with no background texture, gradient, or background shadow.
```

## 10. Generation and review workflow

1. Read the scene's design spec and identify each element's role before prompting.
2. Generate one dressed, reference-only scene mock.
3. Review composition early before producing foundations or object packs.
4. Approve the spatial story, hero scale, path logic, UI-safe areas, and item separability.
5. Generate the foundation-only plate.
6. Generate one hero object separately.
7. Reconstruct a test scene from foundation plus hero and review grounding.
8. Only then generate remaining objects and customization variants.
9. Save every accepted PNG beside its exact prompt. Never rely on chat history as the prompt source.

Do not generate a complete asset batch before the dressed composition and one-object reconstruction are accepted.

## 11. Rejection checklist

Reject and regenerate when any answer is “yes”:

- Does the scene look like unrelated objects placed for visual balance?
- Is the center hollow while objects cling to the edges?
- Is the hero too small, too distant, cropped, or pushed into a corner?
- Does a path loop, fork without purpose, miss a door, or continue behind its destination?
- Is a lantern, mushroom, sign, or other prop implausibly large?
- Are customizable items touching, overlapping, hidden, or too small to inspect?
- Would removing one item expose a turf island, flower ring, shaped pad, shadow, or hole?
- Do separate objects carry their own grass floors or mini-landscapes?
- Are buildings or props using inconsistent scale, camera, light, or shadow direction?
- Is coral repeated as the default roof color, purple common, or gold used without meaning?
- Is detail dominated by tiny leaves, flowers, shingles, outlines, or texture?
- Does the result look glossy, painterly, clay-like, sticker-like, or photoreal?
- Did the model add UI, text, characters, animals, badges, or landmarks that were not requested?

## 12. Current approved examples

- Palette/material: `games/grove/assets/_new/ui_redesign_direction_b/palette_studies_board_v1/palette_a_meadow_sky_board.png`
- World camera/scale: `games/grove/assets/_new/ui_redesign_direction_b/screen_reference_pack_meadow_sky_v1/home_screen_meadow_sky_v2_working_farm.png`
- Distinct-zone composition: `games/grove/assets/_new/ui_redesign_direction_b/zone_reference_pack_meadow_sky_v3/`
- Edge Glade lived-in composition and separated customization footprints: `games/grove/assets/_new/ui_redesign_direction_b/journey_clearing_mocks_v1/edge_glade_mock_v4_customizable.png`

The Edge Glade mock is a composition reference, not a universal layout template. New zones must keep the shared art system while changing path topology, landmark distribution, hero placement, and silhouette families to suit their own meaning.
