# Art & Asset Style Guide

**Status:** production source of truth. Supersedes every prior art-direction and asset-generation doc.
**Applies to:** every generated or processed image in the game — item tiers, merge/UI icons, generators,
characters, world scenes, backgrounds, textures, and customization variants.

> **Read this before generating or processing ANY asset.** One direction, one palette, one set of
> contracts. When a scene-specific spec conflicts with a generic example here, follow the scene spec but
> keep the fixed palette, material, camera, scale, canvas, and separability rules below.

## 0 · Rulings (how the old conflicts resolve)

The docs this replaces disagreed. These are the decisions; the rest of the guide assumes them.

| Question | Ruling |
|---|---|
| Art direction | **Meadow Sky + Cut-Paper Playground wins everywhere.** The old Direction-F "gouache / watercolor / visible brushwork" STYLE LOCK is retired. |
| Merge ladder | **12 tiers** (the 8-tier / 24-line era is retired). |
| Baked shadow on gameplay sprites | **None.** Item tiers, merge icons, UI/shop icons, generators, and movable world objects ship shadow-free. Layered scenes use a separate registered contact-shadow sprite or a runtime shadow; only a permanently flattened scene may bake shadows into the scene (§6). |
| Icon size | **512² master → 256 runtime.** Generate/store at 512²; the runtime UI glyph is 256 via the bake/clean path (§8). |
| Keying | Flat `#FF00FF`, removed deterministically **including enclosed pockets** (§8). |
| Content roster | The **picture-book 5-page / 12-line** roster (§10). Old Farm/Orchard/Garden/Mill/Gate and 24-line rosters are retired. |
| Existing painted art | **Legacy.** Not retro-fitted on a schedule; replaced opportunistically as lines are redone (§10). The engine scales sprites, so mismatched master sizes (e.g. 250² generators) are not a forced re-cut. |

## 1 · Mandatory references

Every world-scene or mock generation must attach these two images with **explicit, separate roles** —
never "just match the references":

1. **Palette & material authority** — `games/grove/assets/_new/ui_redesign_direction_b/palette_studies_board_v1/palette_a_meadow_sky_board.png`
   Controls palette relationships, matte paper treatment, warm cut edges, UI surfaces, shallow shadows.
   Does **not** control world layout or content.
2. **Camera / scale / detail-budget authority** — `games/grove/assets/_new/ui_redesign_direction_b/screen_reference_pack_meadow_sky_v1/home_screen_meadow_sky_v2_working_farm.png`
   Controls the elevated three-quarter camera, common object scale, landscape integration, silhouette
   simplicity, vegetation ceiling, detail budget. Does **not** authorize copying its buildings, paths,
   UI, or farm theme.

For an **edit**, attach the current image first as the precise edit target; these two remain supporting
authorities. Further approved examples are listed in §12.

## 2 · The STYLE BLOCK (paste into every prompt)

This paragraph is the single canonical style string. Paste it verbatim; do not paraphrase.

```text
Meadow Sky + Cut-Paper Playground style: the world is friendly matte hand-cut cardstock — never
plastic, clay, sticker, watercolor, gouache, visible brushwork, painterly gradient, glossy 3D, or
realistic miniature diorama. Broad, rounded, low-complexity silhouettes; two or three dominant masses
per object; each surface one flat base color plus at most one same-hue shadow plane; subtle paper fiber
of about 2-4% local value variation; a fine warm cut edge plus a thin locally-darker edge. No universal
white sticker outline and no heavy black outline. One upper-left light source. Consolidate leaves,
shingles, stones, and ornament into a few readable shapes; never render thousands of tiny details.
Features stay legible at phone size. Use the fixed Meadow Sky role palette. No text, labels, numerals,
or watermark.
```

## 3 · Palette (Meadow Sky, fixed)

| Role | Hex | Usage |
|---|---|---|
| Sky / distant atmosphere | `#6FA9C0` | Open sky, broad page background |
| Structural slate | `#3F6D7D` | Deep structure, water, roof/details |
| Shared meadow | `#A8D3B9` | Large ground, open cells |
| Receding blue | `#8296AF` | Distant hills, locked/inactive surfaces |
| Warm cream | `#F6EBDD` | Paths, cards, pills, light surfaces |
| Ink | `#243B4B` | Text and deepest local edge; never large black masses |
| Garden / action green | `#5F9B6D` | Selected states, foliage accents, primary action |
| Coral | `#D87865` | Flowers, doors, small roof/feedback accents |
| Reward gold | `#D6A94C` | Coins, keystones, rewards, small light accents |
| Rare purple | `#8677A3` | Sparse story / secondary accent |
| Tinted shadow | `#294654` | ~18–20% opacity |

**Rules.** Keep 60–70% of a screen below ~45% saturation. Backgrounds ~28–42% sat; structural surfaces
32–48%; actions 55–70%; small gameplay items may reach 65–85%. Reserve the strongest chroma for
interactive objects, fruit, crops, rewards, keystones, and feedback. Per local composition: cream + ink
as the neutral pair, one dominant structural family, one action color, at most two supporting accents.
Purple is rare; gold is meaningful; coral is an accent, not a default roof color. **Avoid** pure white,
pure black, neon, electric cyan, ultramarine dominance, lime grass, muddy-brown scenes, and equal-strength
rainbow treatment.

## 4 · Material, light & shadow

- Broad rounded silhouettes; a building or major prop is 2–3 dominant masses.
- One flat base color per surface, at most one same-hue shadow plane; 2–4% paper fiber.
- Fine warm cut edge + thin locally-darker edge. No white sticker outline, no heavy black outline.
- **One upper-left light.** World cast/contact shadows fall shallowly **down-right**, soft, short, tinted,
  ~18–20% opacity — they explain contact, never sculpt deep paper.
- **Shadow boundary rule.** Gameplay sprites and movable world objects bake **no** shadow into their color
  sprite. The engine adds it, or the asset bundle supplies a separate registered contact-shadow layer.
  Only a permanently flattened scene may bake the final short contact shadows into the scene pixels.
- Consolidate ornament into a few shapes. Keep doors, windows, handles, fruit, caps, tool heads legible at
  phone size.

## 5 · Asset contracts (canvas · background · shadow · anchor)

Use the exact canvas of the consuming scene/manifest when it specifies one; otherwise this table governs.

| Asset type | Master canvas | Background | Baked shadow | Anchor / notes |
|---|---|---|---|---|
| **Item line sheet (raw gen)** | `1024×1536`, 3 cols × 4 rows, generous gutters | flat `#FF00FF` | none | 12 tiers row-major, tier 1 top-left → 12 bottom-right |
| **Item tier sprite (final)** | `512²` transparent | transparent | none | centered; enclosed gaps cut through |
| **Merge / UI / shop icon (master)** | `512²` transparent | transparent | none | flat front-on glyph — no horizon/scene/perspective |
| **UI glyph (runtime)** | `256²` | transparent | none | derived from the 512² master via bake/clean (§8); `Look.icon(id, px)` |
| **Generator sprite (master)** | `512²` transparent | flat `#FF00FF` or transparent | none | legacy `250²` grandfathered; engine scales |
| **Meadow atlas `icon`** | `256²` transparent | (in-sheet) | none | cutout fit onto the 256² canvas |
| **Meadow atlas `badge`** | `256²`, visible reg `[20,20,236,236]` | (in-sheet) | none | one canonical star alpha across variants |
| **Meadow atlas `tile`** | `256²` **opaque**, periodic | (in-sheet) | n/a | seam-verified via `*_3x3_offset.png` |
| **Meadow atlas `surface`** | native tight aspect | (in-sheet) | none | nine-slice; no fixed px |
| **World object sprite** | registered `W×H` envelope | flat chroma-key | none in color sprite | center-bottom anchor; attached components only; optional separate registered shadow layer |
| **Map scene** | `1084×1451` (≈3:4) | painted (no white bleed) | in-scene | 8 spot objects floor-standing, separated |
| **Full-screen mock** | `9:19.5` portrait | painted | in-scene | upper 15–18% + lower 12–15% UI-safe |
| **Three-zone reference** | `941×1672` | painted | in-scene | — |
| **Game base canvas (runtime)** | `1080×1920` portrait-locked | — | — | top ~160 px band kept clear for chrome |

## 6 · Composition (world scenes & mocks)

Generate a believable **place** first, a required-item list second. The image must explain how someone
approaches, lives in, and uses the location.

- **Spatial story — four semantic areas:** Approach (entry: mailbox/gate/wayfinding) → Activity
  (garden/rest/workshop/water edge) → Threshold (final steps, light, doormat, entrance) → Perimeter
  (wildflowers, mushrooms, roots, hedges, rocks). A prop belongs where it would be used — never placed
  only to balance the frame.
- **Paths** are narrative structure, not filler: enter from a plausible boundary, terminate exactly at a
  door/gate/bridge/destination, bend gently to reveal the scene. No loops, forks, crossroads, or paths
  continuing behind a destination unless the spec requires them. Paths meet steps/thresholds in the same
  perspective.
- **Focal hierarchy:** one clear hero. On a single-home clearing the creature home occupies ~55–62% of
  canvas width, upper-middle. Keystone lanterns are landmarks, not buildings (a path lantern is
  ~mailbox-sized). Secondary objects stay large enough to recognize and tap; none competes with the home.
- **Negative space:** breathing room without a hollow central oval — fill the center with meaningful
  circulation (path, threshold, one or two activity relationships). Large quiet areas belong in UI-safe
  margins or intentionally calm zone fields.
- **Separability (customizable elements):** every cozy item, home, and keystone is independently
  removable, replaceable, selectable. Each gets a complete readable silhouette and its own ground
  footprint, ~one prop-width of visible ground between neighbors, no touching/overlap/fusing. Don't tuck
  small props inside the home silhouette. Natural backdrop vegetation may overlap other backdrop shapes
  but must not obscure interactive items.
- **Grounding:** one continuous ground plane; matched camera pitch, horizon, scale, light, and shadow
  length across every asset; add only a separate short, soft, tinted down-right contact shadow when the
  reconstruction needs it. Never use circular clearings, rectangular
  pads, glowing borders, sticker halos, turf islands, object-specific flower rings, or forced scenic
  bases beneath individual objects. A foundation must stay coherent with every customizable object hidden.

## 7 · UI treatment

- Warm-cream cards and resource pills, ink text, shallow tinted shadows.
- Navigation shares one quiet surface family; only the selected tab gets the full action accent.
- Resident/content cards are soft-tinted, not fully saturated slabs. Gameplay objects and feedback stay
  more colorful than chrome.
- Preserve exact requested text; invent no labels, badges, counters, or buttons. For environment/
  background approvals, omit UI entirely so composition is judged on its own.

## 8 · Cutting & post-processing

Raw art is generated on a flat removable background and cut **deterministically** — the scripts do every
pixel op; judgment lives in the plan (§9). Always inspect the alpha edge before integration.

**Keying rule.** Flat `#FF00FF` (or a corner-sampled flat key). Remove the outer field **and enclosed
pockets** (gaps between legs/rungs, a cog's center, a bell arch, the wedge between two stems). Border
flood-fill alone leaves those pockets opaque — the classic "hole" bug. Small light highlights fully
enclosed by the subject survive; large enclosed background regions are punched. Zero RGB outside alpha
and rebuild resampled edges from opaque interior RGB (no color fringe).

**Use the owned tools — do not hand-roll a keyer:**

| Job | Tool |
|---|---|
| One sheet → 12 clean tier sprites (component-segmented, never grid-sliced) | `games/tools/slice_item_lines.py` (`--montage` to preview) |
| Punch enclosed background pockets a border flood-fill can't reach | `games/tools/cutout_holes.gd` |
| Strip a baked white/bright matte background | `games/tools/cutout_bg.gd` |
| Chroma-key a saturated flat background | `games/tools/chroma_key.gd` (or `key`/`tol` in a `matte` plan) |
| Trim/center one cutout to a square icon | `process_icon` (`icon:512`), then bake to 256 |
| Meadow v2 fixed-grid atlases | `games/grove/tools/extract_meadow_ui_v2.py` (row-major name maps + per-entry policy live here) |

**Why component slicing, not grid cells.** Artists don't draw each subject perfectly inside its cell;
a grid cut drops a sliver of a neighbor into a cell, so the content bbox spans subject+sliver and the
subject comes out shrunk and off-center with a stray fragment. `slice_item_lines.py` segments connected
components on the whole de-backgrounded sheet and buckets each into its cell by centroid — slivers can't
exist — and fails loudly on any empty tier cell.

**Runtime glyph bake (`make bake-textures`).** `clean_tex_path()` defringes + alpha-feathers a sprite the
first time it's drawn (a per-pixel pass that froze dialog opens ~0.7s). The bake runs the identical
`_clean_image()` offline into a committed `baked/<subpath>@<cap>.png` mirror (e.g. `@192` rail icons,
256 glyphs). Baked PNGs + `.import` sidecars are committed; the source stays un-polished (idempotent).
`engine/tests/kit_bake_tests` fails if any drawn sprite is un-baked. After changing a sprite: land the
source → (new top-level dialog only) add a line to `BakeTargets.build_all` → `make bake-textures` →
commit the regenerated `baked/*`.

## 9 · Intake workflow

Raw art lands in `games/grove/assets/_new/`. Nothing watches it; run this loop when the Dev says "pick up
the new art." **You classify, name, and choose params; the scripts do every pixel op and file move — same
plan + same source → identical result.**

1. **List the drop.** `ls games/grove/assets/_new/`. Pairs come as `X.png` (reference, usually not
   shipped) + `X_asset.png` (the sliceable sheet).
2. **Classify each image** into one `category`: `icon` (clean square) · `decor` (positioned layer) ·
   `grid` (even tier sheet) · `sheet` (irregular UI pieces) · `scene` (map locale → §11 scene pipeline) ·
   `matte` (any of those on a baked white/bright background, add `"inner"`). Fits none → park it back to
   the Dev; never force a category.
3. **Slice to scratch and read indices** before naming (`slice_islands.gd` prints `n -> x,y wxh`).
4. **Write `<name>.plan.json`** next to the raw:
   ```json
   {
     "source": "_new/bag_asset.png",
     "category": "sheet",
     "params": { "min_area": 400 },
     "outputs": [
       { "island": 3, "name": "nav_bag", "path": "ui/kit/nav_bag.png", "post": "icon:512" }
     ],
     "archive": "_originals/ui/bag_asset.png"
   }
   ```
   `matte` adds `"inner": "<category>"`; a saturated background adds `"key": "#RRGGBB"` (+ optional `"tol"`,
   default 0.18). Raws archive under `_originals/<kind>/`, never deleted.
5. **Apply.** `make intake` (all pending) or `make intake PLAN=<file>`. The runner writes outputs, moves
   the raw to `archive`, moves the plan to `_new/_processed/`, and reimports; a tool failure skips that
   plan and leaves the raw for retry.
6. **Verify.** Outputs landed, raw gone, plan in `_processed/`. In-engine: `make shot-grove` / `make shot-map`.
   Keep `make test` green.

Item-line sheets bypass the generic `grid` path — re-slice with `slice_item_lines.py` (§8). Meadow v2
atlases regenerate with `extract_meadow_ui_v2.py` + its unittest.

**Review montages** live in the export-excluded `assets/_review/` tree, never under production `assets/ui`;
`*_contact.png` proves row-major identity and `*_3x3_offset.png` must be fully opaque, gap-free, and free
of magenta before shipping.

## 10 · Prompt scaffolds

Every prompt states: use case & asset type; input-image roles; scene purpose & spatial story; required
items & their fictional use; canvas, camera & UI-safe areas; focal & scale hierarchy; separability;
palette & material (the §2 STYLE BLOCK); grounding; a targeted avoid list. Prefer semantic placement
("place the mailbox where a visitor first reaches the home") over coordinates; add coordinates only to
correct a rejected composition.

### 10a · Full world scene / mock

```text
Use case: stylized-concept.  Asset type: vertical mobile game environment mock.
Input images:
- Image 1: mandatory Meadow Sky palette + Cut-Paper material authority; do not copy its UI or board layout.
- Image 2: mandatory elevated three-quarter camera, common scale, shallow shadow, detail-budget authority;
  do not copy its farm content or UI.
Primary request: create [SCENE] as a believable [PLACE/PURPOSE]. Visual story: [APPROACH -> ACTIVITY ->
  DESTINATION]. Arrange elements by how the place is used, not as evenly spaced showcase props.
Required content: [LIST EACH ELEMENT, ROLE, AND FICTIONAL USE]
Composition: modern iPhone portrait; upper 15-18% and lower 12-15% UI-safe; elevated three-quarter camera;
  one hero destination with a path that terminates at it; interactive items large, readable, separated by
  visible ground, never overlapping; natural backdrop frames the perimeter.
Style: <PASTE THE §2 STYLE BLOCK>.
Grounding: one continuous ground plane; no turf islands, pads, sticker halos, object flower rings, scenic bases.
Avoid: inventory-display layout, hollow center, arbitrary grid, oversized keystone, tiny distant hero,
  crowded doorway, overlapping customizable items, painterly gradients, glossy plastic, realistic diorama,
  dense micro-detail, UI, text, watermark.
```

### 10b · Single world object sprite

```text
Use case: stylized-concept.  Asset type: reusable game object sprite.
Create exactly one [OBJECT] matching the supplied approved scene and mandatory Meadow Sky references.
Preserve the scene's elevated three-quarter camera, scale, upper-left light, shallow down-right contact
shadow, matte cardstock, warm cut edge, low detail budget. Fit the registered [WIDTH x HEIGHT] envelope
with a center-bottom anchor; whole silhouette visible with generous padding; attached components + a tight
contact shadow only. No grass skirt, turf island, path, water, bank, detached flowers, loose rocks, scenic
base, text, character, or watermark. Render on one perfectly flat chroma-key color that does not occur in
the object, no background texture/gradient/shadow.
```

### 10c · 12-tier item line sheet

```text
Generate a 12-tier merge-line sheet for the [PAGE] [LINE_NAME] line.
Canvas: exact 1024x1536 PNG, 3 columns x 4 rows, generous gutters. Background: solid flat #FF00FF only.
Style: <PASTE THE §2 STYLE BLOCK>.
Sizing: all 12 elements share the same visual footprint and fill the same amount of each cell; early tiers
  may be simpler but not smaller; center every item.
One clean cutout-friendly item per cell, row-major tier 1 -> 12: [TIER_01] ... [TIER_12].
Constraints: one connected object per cell (no scenes, bundles, crossed tools, piles, or containers unless
  the line's identity is containers); broad attached details (avoid tiny leaves, loose seeds, thin strings/
  legs/antennae, hairline decoration); make tiers 10-12 premium through silhouette/material/palette + one
  bold central motif, not effects; where an object family has a natural emblem slot, put ONE Grove acorn
  emblem on tiers 10-12 (replace an existing central motif; never add dangling/corner/floating acorns; omit
  if no natural slot); choose a dominant silhouette/material family DIFFERENT from the neighboring line;
  whole intact food/creatures only (no cut interiors/slices/piles). No shadows, grounding, glow, sparkles,
  detached FX, text, labels, or watermark. Output only the image sheet.
```

### 10d · UI / shop / currency icon

```text
[SUBJECT], a single game UI icon, centered, chunky readable silhouette, flat front-on glyph — no horizon,
no scene, no perspective; interior gaps fully cut through (transparent), not filled; on a flat #FF00FF
background. Output 512x512, no text or numerals.
Style: <PASTE THE §2 STYLE BLOCK>.
```

Currency canon (`ui/kit/icon_<id>.png`): **coin** = plump golden-brown acorn; **gem** = faceted
teal/sky dewdrop; **water** = clear sky-blue droplet; **rain** = tin watering can pouring three droplets;
**star** = five-point straw-gold bloom-star. Do the currency set as one batch for a consistent language.
Hook-up: process → 512² master → drop at the engine path → `make import` → bake to 256 → verify at the real
sizes (`PRICE_ICON 28`, `HERO_ICON 72`, HUD pill). No code change — `Look.icon(id)` resolves the PNG.

## 11 · Generation & review workflow

1. Read the scene's design spec; identify each element's role before prompting.
2. Generate one dressed reference-only scene mock (no UI). **Review composition early**, before any
   foundations or object packs.
3. Approve the spatial story, hero scale, path logic, UI-safe areas, and separability.
4. Generate the foundation-only plate → one hero object separately → reconstruct a test scene (foundation +
   hero) and review grounding. Fix grounding/anchor/scale/shadow rather than adding a scenic base if it
   looks pasted-on.
5. Only then generate the remaining objects and variants.
6. Save every accepted PNG beside its exact prompt (`_originals/…`). Never rely on chat history as the
   prompt source. **Never batch a full set before the dressed composition and one-object reconstruction are
   accepted.**

**The share-gate is the Dev's eye, never an LLM's** — visual quality judgment is low-reliability for the
model; measure/composite for verification, hand the artifact to the human for sign-off.

### 11a · Layered scene generation learnings

The strongest scene pipeline is layered and test-composited. Do not ask for one final flattened map and
then try to carve it apart. Build the scene from pieces that can survive being hidden, moved, replaced,
and recomposed.

**Backdrop first.** The true foundation is only the continuous ground/floor plane and its low, flat
material texture. It is valid for the top of the image to be empty or transparent where later horizon,
sky, canopy, or atmosphere plates will cover it. For open world pages, keep the floor broad, readable,
and softly radiant. Do not bake sky, mountains, horizon trees, buildings, ponds, roads, shrubs, tree
bases, decorative rings, or object-specific shadows into the foundation.

**Depth plates second.** Generate mountains, distant trees, bushes, and horizon vegetation as full-width
transparent plates. Use several mountain bands with clearly different value/saturation so distance reads
even on a phone. Let horizon vegetation overlap the mountain bases to hide seams and add depth, but keep
enough mountain silhouette exposed to preserve the far/middle/near read. Clouds are separate transparent
plates so they can drift later.

**Terrain features are removable plates.** Lakes, ponds, roads, bridges, steps, cliffs, and paths are not
part of the foundation unless the whole location is permanently defined by them. Generate them separately
with transparent edges and then test them on the plain backdrop. A road/path must terminate exactly at its
destination in the same perspective. If the road is optional or may vary, keep it out of the backdrop.

**Hero structures one by one.** Homes, huts, gates, pavilions, large trees, bridges, and other scale-setting
objects should be generated as standalone sprites, not inside square prop packs. Use one sprite per hero
object with a center-bottom anchor, transparent background, matched camera, and matched light. Keep its
color sprite shadow-free; if grounding needs help, generate a separate registered shadow companion.
Reject dark bottom smears, scenic plinths, grass skirts, turf islands, flower rings, and any baked "little
floor" around the object; those make later placement feel forced. When two forms are structurally one
landmark—such as a door and dwelling carved into the roots of its host tree—generate them as one hero
asset rather than trying to hide a seam between independent sprites.

**Blend contacts with dressing, not scenic bases.** If an object looks pasted-on, add separate low grass,
flower tufts, moss, small stones, petals, or edge-overhang sprites around the contact after placement.
These are reusable dressing sprites, not attached bases. They should overlap object feet/pond banks/path
edges lightly and asymmetrically, leaving the main silhouette and touch target readable.

**Use sprite packs only for compact variation.** `3x3` and `4x4` packs are for compact shrubs, flowers,
rocks, small ornaments, and contact patches. Do not pack large trees, buildings, roads, bridges, gates,
ponds, stairs, cliffs, or collision-bearing objects into square grids. Use one-by-one generation or custom
wide cells for those.

**Keep paper texture local.** Generated props often lose the shared paper tooth after alpha extraction or
resampling. Preserve or reapply the local paper material after keying, then inspect at phone-review size.
The texture must be visible on sky, sand, mountains, water, roofs, walls, bridges, stones, foliage, and
hero props, but it stays subtle; it is not brushwork or noise.

**Verify by reconstruction.** Every accepted layered scene needs a deterministic compositor, placement JSON,
asset manifest, full-size render, and phone-review render. Rebuild from the source PNGs each time; do not
copy cached layers into the reconstruction folder. Validation checks must cover file existence, dimensions,
RGBA/RGB mode, transparent corners for sprites, zero visible magenta, unique z values, placement counts, and
deterministic repeat renders.

**Separate source extraction from generative repair.** If an asset must stay *exactly* the same size,
position, silhouette, and camera angle as an approved mock, do not ask image generation to "cut it out."
That request commonly redraws and recenters the subject. Preserve the approved source pixels with a mask
or segmentation pass in full-canvas coordinates; use image generation only to repair occluded edges or
missing pixels. A generated replacement is a variation and must pass a new visual approval.

**Keep every layer registered to one canvas.** Store large plates and positioned hero sprites on the full
scene canvas with a shared top-left origin, even when a tight-cropped source sprite is also retained. Record
the crop box, center-bottom anchor, intended display size, and z-order in metadata. Never resize one layer
until it "looks about right" in the preview; that hides camera/scale drift and makes reconstruction fragile.

### 11b · Common generation failures and fixes

| Symptom | Cause | Fix |
|---|---|---|
| Building looks forced onto the grass | The generated sprite includes its own grass floor, flower ring, or dark base shadow | Regenerate the building without a scenic base; add separate contact dressing after placement |
| Bottom shadow looks dirty or heavy | Prompt asked for grounding but not shadow limits | Specify one upper-left light and a short, soft, tinted down-right contact shadow only |
| Road misses the doorstep/gate | Road was baked into an independent backdrop or composed without the destination visible | Generate the road/path as its own terrain plate and test it with the destination object |
| Pond/lake reads like a sticker | Edge rocks form a necklace or the water lacks an inner bank/depth cue | Use irregular overlapping stones, moss, planted banks, and a narrow inner shadow; preserve sand-to-bank-to-water steps |
| Props lose the cut-paper feel | Keying/resizing flattened or removed paper tooth | Reapply local paper material after extraction and inspect the phone-size review render |
| Mountains look flat | One mountain layer or too-similar values | Split far/middle/near bands with distinct shades and layer horizon foliage over their bases |
| Large objects crop or shrink in a pack | Square prop pack is the wrong container | Generate large or collision-important objects one by one with their own registered envelope |
| Magenta holes remain inside props | Border-only flood fill removed only the outside field | Use the deterministic key/hole workflow and validate enclosed transparent pockets |
| Scene quality drifts late | Too many assets generated before visual approval | Gate the pipeline: dressed mock -> backdrop+one hero test -> remaining assets -> final reconstruction |
| "Extracted" object changes size or angle | A generative redraw was used for an exact source-preservation task | Mask the approved source in full-canvas coordinates; reserve generation for edge repair or an explicitly new variation |
| Horizon layer covers the lake or playable floor | A full-width plate contains foreground terrain below its intended band | Crop/mask it to its registered horizon band and validate the alpha footprint before compositing |

### Rejection checklist (regenerate if any is "yes")

- Unrelated objects placed only for visual balance? Center hollow while objects cling to edges?
- Hero too small/distant/cropped/cornered? A path that loops, forks without purpose, misses a door, or
  continues behind its destination? A lantern/mushroom/sign implausibly large?
- Customizable items touching, overlapping, hidden, or too small to inspect? Would removing one expose a
  turf island, flower ring, shaped pad, shadow, or hole? Do separate objects carry their own grass floors?
- Inconsistent scale/camera/light/shadow direction across assets? Coral used as a default roof, purple
  common, or gold used without meaning?
- Detail dominated by tiny leaves/shingles/outlines/texture? Result glossy, painterly, clay-, sticker-, or
  photo-like? Any un-requested UI, text, characters, badges, or landmarks?
- **Cut quality:** magenta/white left in an enclosed pocket; color fringe/halo at the alpha edge; subject
  eaten; a tier cell empty or off-center.

## 12 · Content roster & legacy

**Roster (picture-book v1, 5 pages).** Play order: **P1 Fairy Hollow → P2 Snowy Village → P3 Desert Oasis
→ P4 Coral Reef → P5 Cherry-Blossom.** 12 lines = 8 base generators (`glowshroom`, `wildberries`,
`snowballs`, `woolens`, `desert_fruits`, `sand`, `shells`, `koi`) + 4 crafted specials (`winter_berries`,
`spices`, `corals`, and the page-5 special). Every line is a 12-tier ladder. **Tier caps** (pacing rule):
own base lines cap at **t8** (one t9 capstone in the whole book, Torii Gate); borrowed lines cap at **t6**;
specials cap at **t5** borrowed / **t6** on their own page. Per-item stage recipes and economy numbers are
**not** here — they change every economy pass; see `docs/design/picturebook_lines_recipes.md`.

**Approved visual examples.**
- Palette/material: `…/palette_studies_board_v1/palette_a_meadow_sky_board.png`
- Camera/scale: `…/screen_reference_pack_meadow_sky_v1/home_screen_meadow_sky_v2_working_farm.png`
- Distinct-zone composition: `…/zone_reference_pack_meadow_sky_v3/`
- Lived-in clearing + separated customization footprints: `…/journey_clearing_mocks_v1/edge_glade_mock_v4_customizable.png`
  (a composition reference, **not** a universal layout template — new zones keep the shared art system but
  change path topology, landmark distribution, hero placement, and silhouette families).

**Legacy policy.** Art generated in the retired Direction-F painterly style (current item lines, residents,
special items, generators, most icons) is **grandfathered**. It is not retro-fitted on a schedule; replace
it opportunistically when a line is otherwise being redone. Because the engine scales sprites, a legacy
master at a non-standard size (e.g. 250² generators) is not a forced re-cut. New art conforms to this guide.
