# Farmhouse Redo — Artist Prompt Set (camera-unified, color-matched)

**Status:** owner-approved 2026-06-13. Re-rolls the farmhouse zone-1 interior
background **and all 7 furniture items** to ONE shared camera.

**Why a full rewrite (not a re-roll + one constraint):** the background and the
items were specified at *different* camera angles — the room was a *gentle* high
"roof lifted" angle (`BUILD_QUEUE.md:998`) while the items used `ROOM CAMERA v2`,
a *steep* top-down bird's-eye (`BUILD_QUEUE.md:978`). A gentle room + steep
furniture can never sit together, which is what kept failing the side-by-side and
forced the `fh_bed` / `fh_chair` / `fh_wheel` re-rolls. This is a spec bug; we fix
it at the source by giving both layers ONE identical camera.

**Owner decision (2026-06-13):** unified camera = **moderate three-quarter ~45°**
("dollhouse cutaway" — top *and* front of each object both clearly visible).

---

## How to use this doc

- Generate the whole set in **one session** (one chat), per the `GROVE_STYLE.md §4`
  consistency drill.
- Every prompt below is **complete and self-contained** — paste the whole fenced
  block. Each one already inlines the three shared blocks ①②③ **verbatim**. That
  shared, identical text IS the fix — **do not paraphrase it per asset** (drift
  compounds; `GROVE_STYLE.md §4.4`).
- Order: background first, then the items; judge every item *beside* the new
  background before accepting (the acceptance law below).

## The three shared blocks (inlined in every prompt; shown here for reference)

**① STYLE CORE — interior variant of `GROVE_STYLE.md §1`.**
> hand-painted anime-film art style, soft gouache and watercolor texture with
> visible brushwork, gentle diffuse daylight, painterly cel-shaded subject with
> clean simple line work, no photorealism, no glossy 3D render, no text

> *Note: this is `§1` with the outdoor-scenery terms (cumulus clouds, wind-blown
> grass, sky-blue palette, atmospheric haze) dropped — they belong to vistas, not
> a roofed interior. Interior color is governed by block ③. This matches how the
> current `int_farmhouse` interior prompt was already written.*

**② CAMERA ¾ — the unifying block (identical in the room and every floor item).**
> a warm dollhouse cutaway from a single fixed camera: a three-quarter view
> looking DOWN at about 45°, raised as if standing on a low stool beside the
> scene — TOP surfaces and FRONT faces are both clearly visible and roughly
> equal, never a flat overhead floor-plan and never a straight-on side or
> eye-level shot; everything recedes the same way, soft daylight from the upper
> RIGHT, gentle shadows to the lower left

**③ INTERIOR PALETTE — the color-match block (identical in the room and items).**
> warm farmhouse-interior palette: honey wooden floorboards and bark-brown wood
> (#8A5A3B), cream plaster (#FBF3EA), straw-gold firelight warmth (#E3B23C),
> muted clay-red cloth accents (#C96F4A), meadow green (#7FA65A) only as small
> fabric touches — all under one warm, slightly-faded daylight so nothing looks
> pasted in

---

## A. Background — `int_farmhouse` v3

**Intended empty-floor layout** (the room art draws NONE of these — they are where
sprites get placed later; keep the floor clear and roomy enough for all of them):
hearth on the **left** wall · window on the **right** wall · door + one bare
picture patch on the **back** wall · open floor with room for: **bed** (right/back),
**chest** (back-left), **chair** (left, by the hearth), **table** (center),
**rug** (center, under the table), **spinning wheel** (front-right).

```
hand-painted anime-film art style, soft gouache and watercolor texture with visible brushwork, gentle diffuse daylight, painterly cel-shaded with clean simple line work, no photorealism, no glossy 3D render, no text. A warm dollhouse cutaway from a single fixed camera: a three-quarter view looking DOWN at about 45°, raised as if standing on a low stool beside the scene — TOP surfaces and FRONT faces are both clearly visible and roughly equal, never a flat overhead floor-plan and never a straight-on side or eye-level shot; everything recedes the same way, soft daylight from the upper RIGHT, gentle shadows to the lower left. Warm farmhouse-interior palette: honey wooden floorboards and bark-brown wood (#8A5A3B), cream plaster (#FBF3EA), straw-gold firelight warmth (#E3B23C), muted clay-red cloth accents (#C96F4A), meadow green (#7FA65A) only as small fabric touches — all under one warm, slightly-faded daylight so nothing looks pasted in.
The inside of a cozy old farmhouse with the roof and near walls lifted away. ARCHITECTURE ONLY, baked into the room: honey wooden floorboards across an open floor, cream plaster walls, exposed timber ceiling beams, a stone FIREPLACE built into the LEFT wall with a low warm fire, a WINDOW in the RIGHT wall letting in daylight, a simple plank DOOR in the back wall, and one clear bare patch of back wall left empty for a picture. The wooden floor is COMPLETELY EMPTY and uncluttered — NO furniture, NO rug, NO objects, NO people, NO text — generous open floorboards with comfortable room for furniture to be placed later (a clear area beside the hearth, an open center, and space along the right and back). OUTSIDE the cutaway walls show the cottage garden at the same high angle — grass, a dirt path, flowerbeds — never white, never blank. Tall portrait, 3:4; compose nothing critical within 4% of the edges.
```
→ process: `decor 1080 1440 --opaque`

---

## B. Floor items (×6) — `icon 512` + hole-punch

All six share blocks ①②③ then the per-item subject. Template tail (identical for
all six): *…one object only, floor-standing, chunky readable silhouette, clean
outline, one soft warm rim light, centered on plain solid white background,
generous margin, no baked-in shadow, no floor, no text. Square.*

### `fh_bed`
```
hand-painted anime-film art style, soft gouache and watercolor texture with visible brushwork, gentle diffuse daylight, painterly cel-shaded with clean simple line work, no photorealism, no glossy 3D render, no text. A warm dollhouse cutaway from a single fixed camera: a three-quarter view looking DOWN at about 45°, raised as if standing on a low stool beside the scene — TOP surfaces and FRONT faces are both clearly visible and roughly equal, never a flat overhead floor-plan and never a straight-on side or eye-level shot; everything recedes the same way, soft daylight from the upper RIGHT, gentle shadows to the lower left. Warm farmhouse-interior palette: honey wooden floorboards and bark-brown wood (#8A5A3B), cream plaster (#FBF3EA), straw-gold firelight warmth (#E3B23C), muted clay-red cloth accents (#C96F4A), meadow green (#7FA65A) only as small fabric touches — all under one warm, slightly-faded daylight so nothing looks pasted in.
A single cozy wooden bed with a plump patchwork quilt in warm cream and clay-red and one soft pillow, one object only, floor-standing, chunky readable silhouette, clean outline, one soft warm rim light, centered on plain solid white background, generous margin, no baked-in shadow, no floor, no text. Square.
```
→ `icon 512` + hole-punch

### `fh_chair`
```
hand-painted anime-film art style, soft gouache and watercolor texture with visible brushwork, gentle diffuse daylight, painterly cel-shaded with clean simple line work, no photorealism, no glossy 3D render, no text. A warm dollhouse cutaway from a single fixed camera: a three-quarter view looking DOWN at about 45°, raised as if standing on a low stool beside the scene — TOP surfaces and FRONT faces are both clearly visible and roughly equal, never a flat overhead floor-plan and never a straight-on side or eye-level shot; everything recedes the same way, soft daylight from the upper RIGHT, gentle shadows to the lower left. Warm farmhouse-interior palette: honey wooden floorboards and bark-brown wood (#8A5A3B), cream plaster (#FBF3EA), straw-gold firelight warmth (#E3B23C), muted clay-red cloth accents (#C96F4A), meadow green (#7FA65A) only as small fabric touches — all under one warm, slightly-faded daylight so nothing looks pasted in.
A single well-loved wooden rocking chair with a knitted blanket in muted clay-red draped over one arm, one object only, floor-standing, chunky readable silhouette, clean outline, one soft warm rim light, centered on plain solid white background, generous margin, no baked-in shadow, no floor, no text. Square.
```
→ `icon 512` + hole-punch

### `fh_chest`
```
hand-painted anime-film art style, soft gouache and watercolor texture with visible brushwork, gentle diffuse daylight, painterly cel-shaded with clean simple line work, no photorealism, no glossy 3D render, no text. A warm dollhouse cutaway from a single fixed camera: a three-quarter view looking DOWN at about 45°, raised as if standing on a low stool beside the scene — TOP surfaces and FRONT faces are both clearly visible and roughly equal, never a flat overhead floor-plan and never a straight-on side or eye-level shot; everything recedes the same way, soft daylight from the upper RIGHT, gentle shadows to the lower left. Warm farmhouse-interior palette: honey wooden floorboards and bark-brown wood (#8A5A3B), cream plaster (#FBF3EA), straw-gold firelight warmth (#E3B23C), muted clay-red cloth accents (#C96F4A), meadow green (#7FA65A) only as small fabric touches — all under one warm, slightly-faded daylight so nothing looks pasted in.
A single sturdy bark-brown wooden storage chest with a rounded lid and simple dark iron bands, one object only, floor-standing, chunky readable silhouette, clean outline, one soft warm rim light, centered on plain solid white background, generous margin, no baked-in shadow, no floor, no text. Square.
```
→ `icon 512` + hole-punch

### `fh_table`
```
hand-painted anime-film art style, soft gouache and watercolor texture with visible brushwork, gentle diffuse daylight, painterly cel-shaded with clean simple line work, no photorealism, no glossy 3D render, no text. A warm dollhouse cutaway from a single fixed camera: a three-quarter view looking DOWN at about 45°, raised as if standing on a low stool beside the scene — TOP surfaces and FRONT faces are both clearly visible and roughly equal, never a flat overhead floor-plan and never a straight-on side or eye-level shot; everything recedes the same way, soft daylight from the upper RIGHT, gentle shadows to the lower left. Warm farmhouse-interior palette: honey wooden floorboards and bark-brown wood (#8A5A3B), cream plaster (#FBF3EA), straw-gold firelight warmth (#E3B23C), muted clay-red cloth accents (#C96F4A), meadow green (#7FA65A) only as small fabric touches — all under one warm, slightly-faded daylight so nothing looks pasted in.
A single round farmhouse table on turned wooden legs with a bare honey-wood top, one object only, floor-standing, chunky readable silhouette, clean outline, one soft warm rim light, centered on plain solid white background, generous margin, no baked-in shadow, no floor, no text. Square.
```
→ `icon 512` + hole-punch *(re-rolled too: the room angle changed, so the kept v1 no longer matches)*

### `fh_rug` *(flat floor piece — same camera, naturally reads as a shallow ellipse)*
```
hand-painted anime-film art style, soft gouache and watercolor texture with visible brushwork, gentle diffuse daylight, painterly cel-shaded with clean simple line work, no photorealism, no glossy 3D render, no text. A warm dollhouse cutaway from a single fixed camera: a three-quarter view looking DOWN at about 45°, raised as if standing on a low stool beside the scene — TOP surfaces and FRONT faces are both clearly visible and roughly equal, never a flat overhead floor-plan and never a straight-on side or eye-level shot; everything recedes the same way, soft daylight from the upper RIGHT, gentle shadows to the lower left. Warm farmhouse-interior palette: honey wooden floorboards and bark-brown wood (#8A5A3B), cream plaster (#FBF3EA), straw-gold firelight warmth (#E3B23C), muted clay-red cloth accents (#C96F4A), meadow green (#7FA65A) only as small fabric touches — all under one warm, slightly-faded daylight so nothing looks pasted in.
A single soft oval braided rug lying flat on the floor, woven in concentric rings of cream, straw-gold and clay-red, one object only, chunky readable silhouette, clean outline, one soft warm rim light, centered on plain solid white background, generous margin, no baked-in shadow, no floor, no text. Square.
```
→ `icon 512` + hole-punch

### `fh_wheel`
```
hand-painted anime-film art style, soft gouache and watercolor texture with visible brushwork, gentle diffuse daylight, painterly cel-shaded with clean simple line work, no photorealism, no glossy 3D render, no text. A warm dollhouse cutaway from a single fixed camera: a three-quarter view looking DOWN at about 45°, raised as if standing on a low stool beside the scene — TOP surfaces and FRONT faces are both clearly visible and roughly equal, never a flat overhead floor-plan and never a straight-on side or eye-level shot; everything recedes the same way, soft daylight from the upper RIGHT, gentle shadows to the lower left. Warm farmhouse-interior palette: honey wooden floorboards and bark-brown wood (#8A5A3B), cream plaster (#FBF3EA), straw-gold firelight warmth (#E3B23C), muted clay-red cloth accents (#C96F4A), meadow green (#7FA65A) only as small fabric touches — all under one warm, slightly-faded daylight so nothing looks pasted in.
A single wooden spinning wheel on a small stool base with a tuft of cream wool, one object only, floor-standing, chunky readable silhouette, clean outline, one soft warm rim light, centered on plain solid white background, generous margin, no baked-in shadow, no floor, no text. Square.
```
→ `icon 512` + hole-punch

---

## C. Wall item (×1) — `fh_picture` — `icon 512`

**The one exception to the ¾ floor camera:** it hangs flat on a wall, so it is
drawn nearly frontal (NOT block ②). It still uses ① and ③.
```
hand-painted anime-film art style, soft gouache and watercolor texture with visible brushwork, gentle diffuse daylight, painterly cel-shaded with clean simple line work, no photorealism, no glossy 3D render, no text. Warm farmhouse-interior palette: honey wooden tones (#8A5A3B), cream (#FBF3EA), straw-gold (#E3B23C), muted clay-red (#C96F4A), meadow green (#7FA65A) accents.
A single small framed painting of a sunny meadow in a simple warm wooden frame, drawn nearly frontal with the slightest downward tilt as if hanging flat on a wall, soft daylight from the upper right, chunky readable silhouette, clean outline, centered on plain solid white background, generous margin, no baked-in shadow, no text. Square.
```
→ `icon 512`

---

## Acceptance (the FURN-ACCEPTANCE side-by-side law — `BUILD_QUEUE.md:989`)

The prompt claiming "¾ camera" is **not** acceptance. For each item, open the
processed take **beside** the new `int_farmhouse` v3 backdrop: if the top/front
balance does not match the room's floor, the object can't sit on it — **RE-ROLL**
with the SAME prompt (don't rewrite it). The background is the reference; generate
and accept it first.

## Processing summary

| Asset | Mode | Notes |
|---|---|---|
| `int_farmhouse` | `decor 1080 1440 --opaque` | 3:4, contain-fit; garden outside, never white |
| `fh_bed/chair/chest/table/rug/wheel` | `icon 512` + hole-punch | floor items, block ② camera |
| `fh_picture` | `icon 512` | wall-hung exception, near-frontal |

## Re-wiring after the art lands

The new background changes where things sit, so the old `data/placements.json`
`fh_*` coords are stale. Per `TIDY_UP_V2_SPEC §0c #12`, **a human re-places** the
six floor items (+ the wall picture) on the real v3 art with the placement tool;
the tool writes the new normalized coords (and footprints) back into
`data/placements.json`. Agents do not hand-guess coords.

## Notes / deviations

- **Style core is the interior variant** of `GROVE_STYLE.md §1` (outdoor scenery
  nouns dropped — see block ① note). Flag for owner if the bible should record an
  explicit "interior core" variant.
- **All 7 items are re-rolled**, including `fh_table` and `fh_rug` that were
  previously "keep" — because the unified camera angle changed, they must match.
- `fh_plant` (seen in `ART_DONE` history) is not a current farmhouse spot in
  `data/placements.json`; not included. Add it back here if it returns.
