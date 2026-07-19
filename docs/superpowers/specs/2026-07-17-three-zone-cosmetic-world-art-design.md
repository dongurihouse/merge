# Three-Zone Cosmetic Home World — Art Design

**Date:** 2026-07-17
**Status:** approved direction; reference and layered-art production in progress
**Art direction:** Meadow Sky palette + Cut-Paper Playground

## Decision

The Home world grows as three large, meaningful cosmetic zones rather than many shallow
maps:

1. **The Farmstead** — belonging and making a home.
2. **Appleblossom Commons** — community, celebration, memory, reflection, and play.
3. **Bellwater Vale** — shared history, welcome, remembrance, and wonder.

Buildings have **no gameplay functions**. They grant no resident cells, resources, boosts,
unlocks, production, timers, or numerical advantages. Building and customization purchases
change the world visually only. This supersedes the `cells_granted` behavior proposed in
`2026-07-17-home-build-upgrade-map-design.md`; the runtime schema must set it to zero or
remove it before implementation.

## Meaningful-building rule

Every principal building must satisfy all four conditions:

- a clear fictional or social purpose in the world;
- a memorable silhouette that remains readable at Home-map scale;
- a strong relationship to paths, water, orchard, or public space;
- customization that changes architectural identity, finish, and narrative mood.

No principal building exists only to fill space. Its fictional purpose is ambient world
story, never a menu, resource source, progress gate, or interaction requirement.

## Zone 2 — Appleblossom Commons

Appleblossom combines the old Orchard and Garden themes as a **terraced crescent commons**.
A crescent orchard ridge frames the upper third while one broad, quiet social lawn becomes
the visual center. One promenade descends around the lawn's left and lower edges and ends at
a lower-right pond; it never closes into a loop or branches into a Farm-like crossroads. The
stream remains against the far-right boundary and never becomes the compositional centerline.
Buildings hug the crescent in two unequal edge groups rather than scattering evenly across
the map. Keep at least 45% of the zone as quiet lawn, path, orchard floor, or water.

Principal buildings:

1. **Blossom Hall** — low semicircular hall with a broad sage arc roof.
2. **Petal Conservatory** — long, low capsule form with opaque mint paper panels.
3. **Storytree Library** — a large apple canopy over a low ring-shaped reading shelter.
4. **Orchard Tea Pavilion** — wide, low parasol-like cream roof on four plain posts.
5. **Rainwatch House** — asymmetrical folded slate canopy opening toward the pond.
6. **Kite Hill Playhouse** — compact round drum with a shallow lavender-blue cone roof.

At thumbnail scale the six silhouettes must read as **arc, barrel, tree-ring, parasol,
folded canopy, and drum**. Coral is an accent on doors and awnings, not a repeated roof
plane.

Natural seam: Farm orchard trees mature into Appleblossom terraces. The shared path and
irrigation water pass under a dense hedge/root culvert before reappearing in the new zone.

## Zone 3 — Bellwater Vale

Bellwater combines the old Mill and Gate themes as a peaceful **side-loaded basin**. The
middle-right is one large millpond cropped by the right edge. A short, broad spill channel
leaves its lower-left corner and exits diagonally through the lower-left edge; no river crosses
the full scene and no S-shaped water spine is allowed. A path enters at the top-left, bends
once toward the mill, and ends there, with at most three short dead-end spurs. Structures form
two uneven groups of three around the outer thirds while the center remains quiet meadow and
water. Keep at least 50% of the zone as uninterrupted meadow, path, or water.

Principal structures:

1. **Bellwater Millhall** — squat wedge-roof hall with one oversized flat slate wheel.
2. **Welcome Bell Arch** — roofless open pi-shaped frame with a single flat gold bell.
3. **Millbridge Meeting House** — long, low covered crossing with a shallow chevron roof.
4. **Lilybell Pavilion** — wide diamond canopy on four plain posts; Bellwater's only coral roof.
5. **Lanternkeeper’s Nook** — compact slate square with an oversized flat cream cap.
6. **Otter Landing** — low receding-blue arch shell with a simple dock tongue.

At thumbnail scale the six silhouettes must read as **wedge-and-wheel, open frame, long
chevron, diamond canopy, flat-cap square, and low arch-and-tongue**.

Natural seam: Appleblossom's boundary stream feeds Bellwater's right-edge millpond behind a
continuous hedge, while the promenade becomes Bellwater's separate top-left path entrance.
Avoid a portal-like frame or a second artificial edge unless a future fourth zone is
deliberately approved.

## Zone anti-convergence gate

Before accepting adjacent zone mocks, record five fields for each: water topology, path
topology, building distribution, hero location on a 3 x 3 grid, and negative-space location.
Adjacent zones must differ in at least four fields, including path topology and building
distribution.

- No adjacent zones may reuse a central pavilion plus lower-right cottage composition.
- A zone may contain at most one four-post open shelter.
- At least three of six building silhouette classes must be absent from the adjacent zone.
- The largest structure must move at least two Manhattan cells on the 3 x 3 grid.
- Adjacent zones must use different large/medium/small building-count distributions.
- Palette, camera pitch, paper material, object scale, and detail budget remain common; map
  topology and silhouette rosters do not.

## Customization contract

Use a constrained three-axis system:

1. **Form** — a complete pre-authored architectural shell; never freeform roof/wall parts.
2. **Finish** — a curated three-channel Meadow Sky material mask for roof, body, and trim.
3. **Story dressing** — one registered accessory overlay expressing an occasion or mood.

Hero target: 3 forms × 4 finishes × 3 dressings = 36 coherent appearances. Standard
buildings target 12–24. Every axis has coin-purchasable options. Premium-currency choices
are parallel luxury looks, not stronger, more complete, or numerically better choices.
Purchased options remain owned; switching equipped choices is free.

All forms for a building share one center-bottom anchor, contact geometry, and maximum
customization envelope. Painter-sort each complete building root. Child customization
layers never use global z values.

## Layered-art contract

Each zone ships as:

- one `941 × 1672` foundation-only plate;
- six separately generated principal building roots;
- optional invariant foreground occluders where water or foliage must overlap a building;
- placement data with position, display size, sort order, and contact/alignment metadata;
- a flattened reconstruction preview used only for QA.

The foundation remains coherent with every building hidden. It may contain terrain, paths,
water, low vegetation, orchard rows, rocks, lilies, and natural boundaries. It must not
contain buildings, building shadows, shaped pads, or building-specific flower rings.

Building sprites contain architecture, tight contact shadows, attached planters, and
registered dressings only. They must not contain grass skirts, turf islands, path pieces,
water, banks, loose rocks, detached flowers, or mini-landscape bases.

### Alignment-sensitive Bellwater structures

- **Millhall:** preserve wheel axle, waterline, bank footprint, and porch-step contact.
  Use an invariant `mill_water_front` occluder over the lower wheel. If the wheel animates,
  split body, pivoted wheel, and water-front occluder.
- **Meeting House:** preserve both bank endpoints, deck pitch, piling line, and step/path
  contacts across every form. Customize only the roof, rail surfaces, finish, and attached
  dressing.
- **Arch:** keep transparent space between independent pillar footprints so the path remains
  visible and open.
- **Pavilion and Landing:** preserve piling/waterline contacts; water and lilies stay in the
  foundation.

## Fixed visual rules

- Meadow Sky palette: `#6FA9C0`, `#3F6D7D`, `#A8D3B9`, `#8296AF`, `#F6EBDD`,
  `#243B4B`, `#5F9B6D`, `#D87865`, `#D6A94C`, `#8677A3`; shadow `#294654` at
  approximately 18–20%.
- Matte cut cardstock, subtle 2–4% paper fiber, warm cut edges, one upper-left light.
- Two or three major architectural masses per building; consolidate tiny ornamental detail.
- No white sticker halos, black outlines, glossy plastic, neon color, watercolor rendering,
  turf islands, circular clearings, rectangular pads, or forced scenic bases.

## Production checkpoint

Do not generate all building assets at once. For each zone:

1. approve the dressed reference;
2. create and inspect the foundation-only plate;
3. generate one hero building as a separate asset;
4. reconstruct a test scene from foundation + hero;
5. obtain owner feedback before generating remaining buildings and cosmetic variants.
