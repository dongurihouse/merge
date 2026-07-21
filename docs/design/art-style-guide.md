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
| Keying | Flat `#FF00FF` by default, removed deterministically **including enclosed pockets**. Switch to a subject-safe flat key (for example `#00FF00` behind purple assets) when the default key overlaps legitimate subject color (§8). |
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
| **Character bust (giver / portrait pool)** | `256²` transparent | sheet on flat `#FF00FF` | none | complete silhouette ending in an **authored rounded paper base** — never a grid-line truncation; consistent visual weight across the pool; key gutter visible on **all four sides** of every face in the sheet (§8 containment) |
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

**Containment — check the SHEET before cutting anything.** Every subject must sit fully inside its grid
cell with visible key-color gutter on **all four sides** — including *below* a character's torso. Measure,
don't eyeball: if any subject pixel lies on a cell boundary line, the sheet is defective — **reject and
regenerate it**. A silhouette truncated by a cell line (the classic flat-bottomed bust) was never drawn by
the generator; no cutter can recover art that doesn't exist, and re-cutting only preserves the defect.
Character/bust sheets are the high-risk case: the prompt must demand an authored rounded base with clear
key color visible under every character (§10e).

**Keying rule.** Flat `#FF00FF` by default (or another corner-sampled flat key chosen to be absent from
the subject). Purple, violet, pink, and translucent warm-glow assets may require a flat green key instead;
never let magenta despill gray or erase legitimate purple pixels. Remove the outer field **and enclosed
pockets** (gaps between legs/rungs, a cog's center, a bell arch, the wedge between two stems). Border
flood-fill alone leaves those pockets opaque — the classic "hole" bug. Small light highlights fully
enclosed by the subject survive; large enclosed background regions are punched. Zero RGB outside alpha
and rebuild resampled edges from opaque interior RGB (no color fringe).

**Edge treatment (despill) — every keyed cut, whatever tool.** A binary key leaves the anti-aliased edge
band contaminated with the key color (a magenta halo on every silhouette). Three steps, always:
1. **Soft alpha ramp** — alpha from key-distance over a band (e.g. magenta-excess `min(R,B)−G` mapped
   30→110 to opaque→transparent), never a hard threshold.
2. **Despill** — in every still-visible pixel with residual key tint, clamp the key channels toward the
   subject (magenta key: `R,B ≤ G+δ`, δ≈15). Skip pixels whose color is legitimate (see the green-key
   exception above for purple/pink subjects).
3. **Zero RGB outside alpha**; rebuild resampled edge RGB from opaque interior color.

**Acceptance gate — measured, not eyeballed (visual review alone has missed every one of these at least
once).** A cut sprite ships only when all four counts are **zero**:
| Check | Metric |
|---|---|
| No key fringe | visible px (`A>16`) with key excess (magenta: `min(R,B)−G > 40`) = 0 |
| No edge clipping | opaque px (`A>16`) on any canvas edge row/column = 0 |
| No leftover pockets | enclosed background regions (key-colored **or** flat sheet-white) with area > ~200 px = 0 |
| Sheet containment | subject px on any raw-sheet cell boundary = 0 (checked pre-cut, see above) |

Then **inspect over three backgrounds** — dark, light, and the shipping surface (board cream `#ECDFC2` /
warm cream `#F6EBDD`): a light checkerboard hides white leftovers, cream hides cream fringe, dark hides
dark edges. One background is never enough.

**Use the owned tools — do not hand-roll a keyer:**

| Job | Tool |
|---|---|
| One sheet → 12 clean tier sprites (component-segmented, never grid-sliced) | `games/tools/slice_item_lines.py` (`--montage` to preview) |
| Punch enclosed background pockets a border flood-fill can't reach | `games/tools/cutout_holes.gd` |
| Strip a baked white/bright matte background | `games/tools/cutout_bg.gd` |
| Chroma-key a saturated flat background | `games/tools/chroma_key.gd` (or `key`/`tol` in a `matte` plan) |
| Kill an OPAQUE chroma halo a keyer can't reach (pre-keyed/upscaled drop) | `games/tools/erode_edge.py` (alpha erode + soften; colour-blind, so same-hue art is safe) |
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

### 10e · Character bust / portrait pool sheet

```text
Generate a character portrait sheet for [POOL_PURPOSE], [ROWS] rows x [COLS] columns on a solid flat
#FF00FF background.
Style: <PASTE THE §2 STYLE BLOCK>.
Each cell contains exactly one character bust: head + shoulders + upper torso, ending in an AUTHORED
rounded cut-paper base — a deliberate curved paper edge that completes the silhouette. The base is part
of the drawing, never an implied crop.
CONTAINMENT (hard requirement): every character floats fully inside its own cell with clear magenta
visible on ALL FOUR sides — above the hat, beside the arms, and BELOW the finished base. No character
may touch or cross a cell boundary. Characters never touch each other.
Consistency: all characters share the same scale, camera, and visual weight; distinct silhouettes via
headwear/costume/species, not size. No text, labels, props on the ground, cast shadows, or watermark.
```

Reject the returned sheet on sight if any bust bottom is a straight line coinciding with its cell
boundary — that is a generation truncation, not a base; it cannot be repaired in post (§8 containment).

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

### 11b · Exact source-mock extraction and Scene Workbench reconstruction

Use this workflow when an approved mock is the composition authority and the deliverable must reproduce
its backdrop, object sizes, facing directions, angles, paths, and occlusion in Scene Workbench (`make sw`).
This is a **registered reconstruction task**, not a loose style-transfer task. General resemblance is a
failure when the source measurements can be preserved.

#### Lock one source authority

- Write the exact source path at the top of the bundle README and metadata before extracting anything.
  Similar names such as `*_original_mock_*`, `*_concept_*`, and `*_backdrop_*` are not interchangeable.
- Show that exact source in the Workbench reference column and in every extraction review. Do not extract
  from one mock and judge the reconstruction against another.
- Preserve an untouched copy under `00_source/` or `00_style/`. Record its pixel dimensions and the target
  Workbench canvas dimensions. The source controls composition, camera, object scale, facing, angle,
  spacing, and light; this guide continues to control material and processing quality.
- Make a source inventory before prompting: backdrop surfaces, terrain features, hero objects, reusable
  decals, local contact dressing, broad environmental framing, and atmosphere. The inventory is also the
  explicit removal list for the backdrop pass.

#### Choose extraction versus generation correctly

| Need | Correct method |
|---|---|
| Preserve visible pixels, silhouette, size, and angle exactly | Full-canvas mask/segmentation from the approved mock |
| Preserve an object but complete small occluded or cropped edges | Mask the source pixels first; use image generation only for the missing edge repair |
| Remove foreground objects while preserving the original ground/horizon | Full-canvas edit of the approved mock with an explicit removal inventory and preservation lock |
| Create a new variation inspired by the mock | Reference-based image generation; treat it as new art requiring approval |

Do not prompt image generation to "extract" or "cut out" an object when exact preservation is required.
The model commonly redraws, recenters, rotates, mirrors, changes scale, simplifies detail, or invents a
scenic base. A clean generated cutout may still be the wrong asset if it no longer registers to the mock.

#### Marked-reference protocol

When image generation is needed for an occlusion repair or a subject that cannot be segmented cleanly:

1. Attach the untouched full mock as the camera, scale, lighting, palette, and context authority.
2. Create a second review-only copy with **one** rectangle, ellipse, or translucent highlight around the
   target. The mark identifies the target; it does not define its silhouette.
3. When useful, attach a tight crop as a detail reference, but never use the crop alone: a crop loses the
   scene camera, relative scale, and facing context.
4. State the target's exact identity and exclusions. Say which nearby pixels belong to other objects and
   must not be included.
5. Require the original facing, three-quarter angle, proportions, light direction, and paper grain. Forbid
   rotation, mirroring, straightening, front-facing redesign, recentering, scenic floors, and extra props.
6. Generate on a perfectly flat subject-safe chroma key with generous clearance on all four sides, then
   apply the deterministic §8 keying/despill workflow. The highlight never appears in the generated asset.

Suggested extraction/repair prompt lock:

```text
The untouched full mock is the exact identity, camera, scale, facing, three-quarter angle, palette,
paper-grain, and upper-left-light authority. The marked image identifies only the target object.
Reconstruct only that object, preserving its source silhouette, aspect ratio, direction, visible planes,
and proportions. Complete only the small parts hidden in the source. Do not rotate, mirror, straighten,
front-face, redesign, simplify, add a floor/base/shadow, or include neighboring scenery. Show the complete
object with generous clearance on a perfectly flat solid #FF00FF background.
```

#### Backdrop extraction

The backdrop pass starts from the approved full mock, not from a prose description and not from a newly
generated blank scene. Give image generation the original image as the **edit target** and name every item
to remove. "Remove the foreground" is too ambiguous: it often removes the ground texture as well.

```text
Edit the approved mock in place. Remove only: <complete enumerated object list>.
Preserve exactly: canvas, crop, camera, horizon, mountains/sky, continuous ground geometry, ground color,
raked-sand/path texture, paper grain, lighting, and all low terrain markings named as permanent.
Fill every exposed hole with the immediately surrounding source material and directional texture.
Do not smooth, flatten, recolor, zoom, crop, repaint, or add any object.
```

- Decide explicitly whether ponds, roads, bridges, stairs, and paths are permanent terrain or removable
  plates. If they must be editable in Workbench, remove them from the backdrop and extract them separately.
- Keep the edited backdrop at the exact source canvas size. Reject any result that changes the horizon,
  loses the ground texture, alters raked-line direction, leaves object ghosts, or invents clean empty pads.
- Compare source and backdrop at equal size. Inspect every removed object's footprint at 100%, especially
  patterned ground, water banks, stairs, fences, and contact shadows.

#### Measure instead of eyeballing

Record each source-space object rectangle as `(left, top, width, height)` in
`metadata/source_bounds.json`. For a source `Sw x Sh` reconstructed on a Workbench canvas `Cw x Ch`:

```text
scale_x = Cw / Sw
scale_y = Ch / Sh
target_visible_left   = source_left   * scale_x
target_visible_top    = source_top    * scale_y
target_visible_width  = source_width  * scale_x
target_visible_height = source_height * scale_y
target_visible_center_x = target_visible_left + target_visible_width / 2
target_visible_bottom   = target_visible_top  + target_visible_height
```

Scene Workbench uses a center-bottom anchor:

```text
x = target_visible_left + target_visible_width / 2
y = target_visible_top + target_visible_height
```

Do not assume the PNG canvas equals its visible subject bounds. Chroma-keyed sprites and processed decals
often retain transparent padding. Measure the alpha bounding box `(Ax, Ay, Aw, Ah)` inside the asset canvas
`Iw x Ih`, then compensate when setting the Workbench envelope:

```text
placement_w = target_visible_width  * Iw / Aw
placement_h = target_visible_height * Ih / Ah
placement_x = target_visible_center_x - (Ax + Aw / 2 - Iw / 2) * placement_w / Iw
placement_y = target_visible_bottom   + (Ih - (Ay + Ah)) * placement_h / Ih
```

This compensation is mandatory for paths and small decals: setting `w` to the desired visible stone width
can render the actual stone at half size when half the PNG is transparent. Store source bounds, alpha
bounds, final center-bottom anchor, display envelope, z, facing, and any approved tolerance in metadata.

#### Identify atomic assets and groups

Inventory the mock in this order:

1. **Backdrop:** continuous, non-selectable surfaces and permanent low terrain.
2. **Terrain features:** ponds, roads, stairs, bridges, cliffs, and paths that may need independent control.
3. **Hero objects:** buildings, gates, washing stations, large trees, statues, and other scale-setting props.
4. **Reusable decals:** individual stones, rocks, bushes, petals, flowers, and small bonsai/ornaments.
5. **Local contact dressing:** small pieces that visually ground one hero.
6. **Broad environment/foreground:** edge vegetation, canopies, horizon bands, and atmosphere that frame the
   whole scene rather than belonging to one object.

Extract atomic assets first; create Workbench groups second. Do not bake a bridge into a pond, a whole path
into one sprite, or broad vegetation into a building merely because they overlap in the mock.

A Workbench cluster represents a semantic move/scale unit:

- A hero cluster contains the hero plus only the contact shadow, tufts, rocks, petals, or trim that should
  always move with it.
- A path cluster contains separate stone entries so the route can move as a whole while each stone remains
  individually adjustable.
- A pond and bridge remain separate atomic assets. Cluster them only after their independent alignment is
  approved and only if product behavior says they always move together.
- Broad edge vegetation, horizon plates, and atmosphere do not join the nearest hero cluster.
- Visual proximity alone does not imply ownership. Ask: "If this hero moved or were replaced, should this
  piece move too?" If not, it belongs to another cluster or remains unclustered.

For dense scenes, first make a marked inventory image with one numbered/colored region per proposed atomic
asset. Review group boundaries before generating. A useful grouping plan names the hero, its inseparable
parts, optional local dressing, and excluded neighboring scenery.

#### Reconstruct procedurally in Scene Workbench

`metadata/placements.json` is the composition authority. Reconstruct in visible checkpoints; never populate
the whole scene in one pass:

1. **Backdrop only.** Open and render it. Confirm canvas, horizon, texture direction, and absence of ghosts.
2. **One scale anchor.** Add the largest or most central hero at its measured source bounds. Fix extraction,
   alpha bounds, anchor, scale, and angle before adding anything else.
3. **Bare major layout.** Add only the other major terrain/hero objects. No trees, bushes, rocks, lanterns,
   or contact dressing yet. Match normalized position and visible size against the source.
4. **Paths and repeated decals.** Rebuild them from individual variants using measured center points,
   spacing, count, direction, and perspective scale. Do not extract a whole stepping-stone path as one image.
5. **Occlusion order.** Give paths/ground decals lower z than structures that cover them in the mock. Match
   where a route disappears behind a pond bank, pavilion, gate, tree, or foreground frame and reappears.
6. **Local clusters.** Add only approved contact dressing and assign it the hero's `cluster` value.
7. **Broad framing and atmosphere last.** These should complete the composition, not hide inaccurate anchors.

For paths specifically, trace the source route as a polyline of stone centers. Record every center, visible
width/height, variant/facing, and z. Preserve the source count and gaps unless an occluded stone is inferred.
Scale foreground stones only when the mock shows perspective growth. If Workbench has no rotation control,
generate/extract angle variants; do not fake direction by stretching a stone's width and height.

After every checkpoint:

```sh
make import
make shot-sw SCENE=<scene> ROOT=<scene-root> OUT=/tmp/<scene>-review.png
```

View the Workbench capture with the correct source visible in the reference column. Compare landmark boxes,
path centerline, visible alpha bounds, spacing, occlusion, and phone-size readability. Save named checkpoint
renders (`backdrop`, `major-layout`, `path-v1`, `path-v2`, `dressed`) rather than overwriting the evidence.
When the reconstruction drifts, remove later layers and correct the earliest wrong checkpoint; do not hide
bad geometry under vegetation.

#### Acceptance gate

- Correct source mock is visible and named; no similarly named reference was substituted.
- Backdrop retains source ground/horizon texture and contains none of the enumerated removable objects.
- Every hero preserves source facing, camera angle, visible aspect, and size within the scene-specific
  tolerance; exact-preservation assets use source pixels rather than a redraw.
- Placement envelopes compensate for transparent padding; comparison uses visible alpha bounds.
- Clusters express semantic ownership, not incidental proximity.
- Paths match source count, centerline, spacing, direction, perspective scaling, and occlusion breaks.
- The minimal major-layout checkpoint matches before dressing is allowed.
- A fresh `make shot-sw` capture has been visually compared against the correct source; JSON parses and the
  relevant Workbench/project tests pass before integration.

### 11c · Coral Reef case study — generate for a three-layer reconstruction

Coral Reef is the reference workflow for a scene that must look like one coherent cut-paper illustration
while still allowing the game to replace or unlock meaningful objects. Its current authoring bundle is
`games/grove/assets/_concepts/zones/coral_reef_paper_elements_v1/`; `metadata/placements.json` is the
single scene authority.

#### Start with a layer-ready mock, not a decomposition rescue

Prompt the **first full-scene mock** with the runtime layers already in mind:

1. **Foundation/backdrop** — continuous water, sand, low rock geometry, light shafts, paper grain, and
   large, readable prop sockets. No hero props, coral cover clusters, bubbles, or scenic object bases.
2. **Primary objects** — only four to six large, separable landmarks. Coral uses a shipwreck, chest,
   anchor, mermaid statue, and giant clam. Each has a distinct, roomy socket and its own thin paper plate
   where that plate is part of the object design.
3. **Coverup** — broad, repeatable paper-coral / shell / kelp masses that can hide an entire region. These
   are deliberately large; do not try to build a locked scene from dense micro-coral clutter.

The mock is a composition and material authority. It is not a flattened runtime layer. If a future object
may unlock, move, animate, or be replaced, keep it out of the foundation from the first prompt.

#### Generate the foundation as a controlled edit

For a palette or atmosphere revision, use the active foundation as the edit target and lock every terrain
silhouette and socket. Coral's `coral_reef_paper_foundation_undersea_gray_v3.png` was made this way:
retain the exact rock ledges, pebble placement, central channel, sand opening, and light-shaft geometry;
change only the color read from saturated cyan/royal blue to muted gray-teal water, slate-blue rock sides,
desaturated blue-gray tops, and soft gray-beige sand. This preserves reconstruction placement while making
the scene feel underwater rather than neon.

Prompt contract:

```text
Repaint only the backdrop color and underwater atmosphere. Preserve the exact silhouette, proportions,
perspective, and positions of every cut-paper rock ledge, platform, pebble, central water channel, sandy
bottom opening, and upper light shaft. Keep the foundation clean: no landmarks, coral, shells, kelp,
bubbles, characters, text, or UI. Use muted gray-teal water, slate-blue rock sides, desaturated blue-gray
platform tops, restrained pale-aqua shafts, and subtle paper grain. Do not add terrain or raised plates.
```

#### Deconstruct by ownership, then reconstruct in Workbench

- Keep each landmark as a separate transparent primary-object sprite. Do not bake grass/sand floors,
  flower rings, or heavy bottom shadows into it.
- Keep only permanently shared terrain in the foundation. In Coral, extra socket plates were removed from
  the foundation because the landmark sprites already own their paper plates; two stacked plates immediately
  reveal the layer split.
- Use small contact dressing only as separate cluster members. It integrates an object after placement
  without forcing it to carry a scenic base.
- Place every sprite on the foundation using center-bottom anchors, then render `make shot-sw
  SCENE=coral_reef_paper OUT=/tmp/coral.png`. Compare against the source before adding more dressing.
- Correct the earliest wrong layer—foundation geometry, visible bounds, anchor, or scale—rather than
  covering a mismatch with foreground decoration.

#### Locked-state coverup contract

`coverup` is the dedicated topmost Scene Workbench layer. It is not ordinary foreground dressing.
Create **one cluster per primary-object region**, so one unlock action removes the meaningful visible area
around that object. Coral has five: `unlock_region_shipwreck`, `unlock_region_chest`,
`unlock_region_anchor`, `unlock_region_statue`, and `unlock_region_clam`.

Each coverup cluster may contain multiple repeated transparent pieces—shell caps, coral fans, sponge
clusters, kelp curtains, and pebble mats—but every member shares the region's cluster name and the
`coverup` layer. Lay large pieces past the screen edges and overlap their paper rims to form a mostly
covered page with a few intentional water gaps, matching the locked mock. Do not make one cluster per
sprite: that makes the page read as scattered props and makes an unlock feel too small.

Before shipping, hide one region at a time in the Workbench. The remainder must still read as a coherent
locked page, and removing the region must reveal a clear landmark/socket without a turf island, duplicate
plate, dark shadow slab, or accidental hole.

### 11d · Common generation failures and fixes

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
| Purple asset turns gray or loses its rim | The subject color is too close to the magenta key and despill treats it as contamination | Regenerate on a flat green key (or another absent hue); do not compensate by weakening alpha QC |
| Scene quality drifts late | Too many assets generated before visual approval | Gate the pipeline: dressed mock -> backdrop+one hero test -> remaining assets -> final reconstruction |
| "Extracted" object changes size or angle | A generative redraw was used for an exact source-preservation task | Mask the approved source in full-canvas coordinates; reserve generation for edge repair or an explicitly new variation |
| Horizon layer covers the lake or playable floor | A full-width plate contains foreground terrain below its intended band | Crop/mask it to its registered horizon band and validate the alpha footprint before compositing |
| Locked cover reads as scattered decorations | One cover cluster was made per sprite instead of per meaningful region | Group repeated cover sprites into one topmost `coverup` cluster for each primary-object region; test hiding one region at a time |
| Landmark shows a doubled paper plate | Both the foundation and the landmark sprite own the same raised plate | Keep the plate in only one layer—normally the movable landmark—and regenerate/edit the foundation to remove its duplicate socket plate |

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
- **Sheet containment (pre-cut):** any subject touching or crossing a grid-cell boundary — especially a
  bust whose bottom is a straight line on the cell line (a generation truncation, unrecoverable in post)?
- **Cut quality (the §8 gate, measured not eyeballed):** magenta/white left in an enclosed pocket; key
  fringe/halo at the alpha edge (despill missing); opaque pixels on a canvas edge; subject eaten; a tier
  cell empty or off-center. Inspected over dark + light + shipping backgrounds?

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
