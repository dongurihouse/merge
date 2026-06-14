# Zone Generation & Decompose Pipeline

A runbook for producing a zone's art **and** its per-object cutouts **and** their
placement coordinates from a *single coherent render*. Built so another agent can
execute it step by step.

Worked example throughout: the **farmhouse** zone (zone 0). The same recipe works
for `barn`, `pond`, `orchard`, `meadow` — swap the object list.

---

## Why this works (the idea)

If you generate one image with every unlockable already placed, the objects are
lit, scaled, and styled *consistently with each other and with the room*. From
that single image you can harvest three things at once:

1. **The empty background** — the room with the objects removed.
2. **Each object as a clean transparent sprite** — cut straight out of the full
   render, so it already matches the room's style and lighting.
3. **Each object's placement** — the box you cut it from *is* its position. No
   separate placement guesswork.

Paste the cutouts back onto the empty background at the boxes you cut them from
and you reconstruct the original full image almost exactly. That round-trip is the
built-in correctness check (Phase 6).

---

## Mapping to the original 6-step idea

| Original step | Where it lives here |
|---|---|
| 1. Prompt the full zone with all unlockables | **Phase 1** |
| 2. LLM removes everything → empty room | **Phase 4** (moved later, see note) |
| 3. Two near-identical images (full + empty) | Output of Phases 1 + 4 |
| 4. Screenshot each object, LLM removes bg, remember source (x,y) | **Phase 2 (detect) + Phase 3 (cut)** |
| 5. Place clean objects back into the empty room | **Phase 5** |
| 6. User verifies manually | **Phase 6** |

> **Why detection moved before the empty-room step.** The object boxes are needed
> twice: to crop the objects *and* to mask the empty-room edit. Detecting first
> means the empty room is built by inpainting **only** the object regions, so every
> pixel *outside* the objects stays byte-identical to the full render. The
> reconstruction then lands almost perfectly. A simpler "just delete everything"
> variant that matches the original ordering is in **Phase 4, Variant B**.

---

## What you need

- An **image model with edit + vision** (the project uses ChatGPT / `gpt-image`).
  - Generate (text → image), Edit/inpaint (image + mask → image), Vision (image → text/JSON).
- **ImageMagick v7** (`magick`) for cropping, compositing, and diffing — or an
  equivalent PIL/Pillow script. Commands below assume `magick`.
- The repo, for the optional game-integration step (Phase 7).

## File layout (per zone)

```
assets/zones/<zone>/
  full.png            # Phase 1 — the generated full render (the source of truth)
  manifest.json       # Phase 2 — object ids + pixel boxes
  mask.png            # Phase 4 — white = object regions to inpaint (recommended variant)
  empty.png           # Phase 4 — room with objects removed
  objects/
    <id>_raw.png      # Phase 3 — tight crop straight from full.png
    <id>.png          # Phase 3 — same crop, background removed (transparent)
  reconstructed.png   # Phase 5 — empty.png + all cutouts pasted back
  qa_diff.png         # Phase 6 — difference map vs full.png
  qa_sidebyside.png   # Phase 6 — full | reconstructed, for the human
```

## Naming convention

Object ids **must** match the spot ids in `scripts/grove_content.gd` so the result
can feed the game. Farmhouse:

| id | object (use in prompts) |
|---|---|
| `fh_chest`   | a wooden treasure chest |
| `fh_bed`     | a cozy bed |
| `fh_table`   | a small wooden table |
| `fh_rug`     | a round woven floor rug |
| `fh_plant`   | a potted plant |
| `fh_wheel`   | an old wooden cart/spinning wheel |
| `fh_chair`   | a wooden chair |
| `fh_picture` | a framed picture on the wall |

---

## STYLE LOCK (reuse verbatim in every generation/edit prompt)

Throughout this runbook, **`[STYLE LOCK]` is a placeholder for *your game's* locked style
suffix** — the one paragraph that pins the look. Paste it **identically** into the full render,
the empty-room edit, and every per-object prompt, so the whole game stays visually consistent.
This method is game-agnostic: substitute your game's string; the runbook never hardcodes a look.

> *Reference instantiation:* the Ghibli Grove's locked style core lives in
> [`../grove/grove_spec.md`](../grove/grove_spec.md) §8 (Art Direction) — drop that paragraph in
> wherever `[STYLE LOCK]` appears.

---

## Canvas size

- The in-game zone canvas is **1084 × 1451** (≈ 3:4 portrait). See
  `scenes/place_test.gd` (`HOUSE = Vector2(1084, 1451)`).
- `gpt-image`'s nearest portrait size is **1024 × 1536** (2:3, slightly taller).
- **Internal consistency** (Phases 1–6) needs only that `full.png`, `empty.png`,
  and the crops all share one canvas — any size works.
- **For clean game integration** (Phase 7), match the game aspect: generate at
  1024 × 1536, then crop to 1084 × 1451 proportions (trim a little top/bottom), or
  just re-tune positions later in the `place_test` sandbox. Normalized coords are
  resolution-independent, so absolute pixels don't matter once the *aspect* matches.

---

# Phase 1 — Generate the full zone

Generate the room with **all 8 objects placed and clearly separated**. Separation
is what makes detection and cutting clean later.

**Prompt (P1):**

```
[STYLE LOCK]

A small cozy farmhouse interior room, viewed in soft isometric 2.5D, portrait
composition. The room is fully furnished and decorated with these 8 distinct
objects, each clearly separated with empty space around it (no overlapping),
each sitting naturally on the floor or hung on the back wall:

1. a wooden treasure chest
2. a cozy bed
3. a small wooden table
4. a round woven floor rug
5. a potted plant
6. an old wooden cart wheel leaning against the wall
7. a wooden chair
8. a framed picture on the back wall

Show plenty of bare floor and bare wall between the objects. Use soft, even
lighting with only a small soft contact shadow directly under each object — no
long or overlapping cast shadows. Center the full room in frame with a small
margin on all sides.
```

Generate at **1024 × 1536**. Save as `assets/zones/farmhouse/full.png`.

**Acceptance:** all 8 objects present, visually separated, each with breathing
room, soft contact shadows only. If two objects touch or overlap, regenerate —
overlap makes Phases 2–3 messy.

---

# Phase 2 — Detect objects → manifest

Ask the vision model for a tight pixel box around each object. The box should
**include the object's small contact shadow** (so the cutout keeps its grounding).

**Prompt (P2):**

```
This image is <W>x<H> pixels (origin top-left, +x right, +y down). Find each of
these objects and return a TIGHT pixel bounding box that includes the object and
its small contact shadow:

fh_chest = wooden treasure chest
fh_bed = cozy bed
fh_table = small wooden table
fh_rug = round woven floor rug
fh_plant = potted plant
fh_wheel = old wooden cart wheel
fh_chair = wooden chair
fh_picture = framed wall picture

Output ONLY JSON, no prose:
{ "canvas": [W, H],
  "objects": [ { "id": "fh_chest", "bbox_px": [x, y, w, h] }, ... ] }
```

Save as `assets/zones/farmhouse/manifest.json`, adding `"zone"` and `"source_full"`:

```json
{
  "zone": "farmhouse",
  "canvas": [1024, 1536],
  "source_full": "assets/zones/farmhouse/full.png",
  "objects": [
    { "id": "fh_chest", "label": "wooden treasure chest", "bbox_px": [x, y, w, h] }
  ]
}
```

**Verify the boxes (don't trust raw vision output — it's often a few % off).**
Draw the boxes onto a copy and eyeball them:

```bash
# one box at a time, or script the loop over manifest.json
magick full.png -fill none -stroke red -strokewidth 4 \
  -draw "rectangle X,Y X+W,Y+H" /tmp/boxes.png
```

Nudge any box in `manifest.json` until it tightly contains its object + contact
shadow and nothing else. This file is the single source of truth for Phases 3–5.

---

# Phase 3 — Cut each object (crop, then LLM background removal)

For every object in the manifest:

**3a. Crop the raw object from the full render** (pure pixel copy, no model):

```bash
magick full.png -crop WxH+X+Y +repage assets/zones/farmhouse/objects/fh_chest_raw.png
```

**3b. Remove the background with the image LLM.** Send `<id>_raw.png` and ask for
transparent alpha. The crop has *room texture* behind it (wall/floor), so this is
true background removal, not flat-color keying.

**Prompt (P3):**

```
[STYLE LOCK]

Here is a single object cropped from a game illustration, with some room
background still around it. Return the SAME object on a fully transparent
background (PNG with alpha).

- Keep the object's own soft contact shadow as a soft semi-transparent shadow.
- Do NOT change the object's colors, outlines, shape, or size.
- Do NOT add, complete, or invent any new parts — only erase the surrounding
  floor/wall background.
- Output a transparent PNG at the same pixel dimensions as the input.
```

Save the result as `assets/zones/farmhouse/objects/fh_chest.png`.

**Verify the alpha is clean.** A transparent PNG looks fine on a light UI but can
hide fringes. Composite over magenta (the project's "composite over magenta =
truth" rule) and inspect edges:

```bash
magick objects/fh_chest.png -background magenta -flatten /tmp/chest_check.png
```

Look for magenta haloing, leftover wall/floor scraps, or chewed edges. If the
model resized or redrew the object, re-run P3 emphasizing "same size, do not
redraw." Repeat 3a–3b for all 8 objects.

---

# Phase 4 — Build the empty room

### Variant A — masked inpaint (recommended; best fidelity)

Inpaint **only** the object regions, so all other pixels stay byte-identical to
`full.png`. Build a mask where the object boxes are white and everything else is
black, padded slightly to swallow contact shadows:

```bash
# start black, then paint each manifest box white (pad ~12px). Script over manifest.
magick -size 1024x1536 xc:black -fill white \
  -draw "rectangle X-12,Y-12 X+W+12,Y+H+12" ... mask.png
```

Send `full.png` + `mask.png` to the edit/inpaint endpoint.

**Prompt (P4-A):**

```
[STYLE LOCK]

Here is a farmhouse room and a mask. Repaint ONLY the masked (white) regions as
plausible bare floor and bare wall that continues the surrounding room — same wood
floor, same wall color, same perspective, same lighting. Remove the objects and
their shadows completely in those regions. Leave everything outside the mask
exactly as-is. Output the same 1024x1536 image.
```

> Note on mask polarity: OpenAI's `gpt-image` edit API treats the mask's
> **transparent** pixels as the editable area (alpha = where to paint). If you use
> that API, supply the mask as a PNG whose object regions are transparent rather
> than white. In the ChatGPT UI, just brush over the objects with the eraser/select
> tool instead of supplying a mask file. The intent is identical: edit the object
> regions only.

Save as `assets/zones/farmhouse/empty.png`.

### Variant B — whole-image removal (simpler; matches the original step ordering)

No mask. One edit pass over the whole image:

**Prompt (P4-B):**

```
[STYLE LOCK]

Here is a furnished farmhouse room. Remove ALL furniture and decorations (chest,
bed, table, rug, plant, cart wheel, chair, wall picture) and their shadows,
leaving a completely empty room. Keep the walls, floor, windows, architecture,
perspective, lighting, palette, and art style EXACTLY the same. Output the same
framing and size.
```

Faster, but the model usually redraws the whole canvas, so the empty background
won't be pixel-aligned with `full.png` and the Phase 6 diff will be noisier.
Acceptable for a "fairly identical" pass; use Variant A when you want the
reconstruction to land cleanly.

**Acceptance (either variant):** empty room, no object ghosts or leftover shadows,
same perspective and palette as `full.png`.

---

# Phase 5 — Recompose

Paste every cutout back onto `empty.png` at the **top-left of its manifest box**
(`+X+Y`). Chain one `-composite` per object:

```bash
# offset = the box's top-left (+x+y) from manifest.json, one -composite per object
magick empty.png \
  objects/fh_chest.png -geometry +<chest_x>+<chest_y> -composite \
  objects/fh_bed.png   -geometry +<bed_x>+<bed_y>     -composite \
  objects/fh_table.png -geometry +<table_x>+<table_y> -composite \
  ... \
  reconstructed.png
```

(If a cutout's pixel size changed during P3, either re-cut it or composite with
`-geometry <w>x<h>+<x>+<y>` to fit it back into its original box.)

**Acceptance:** `reconstructed.png` looks like `full.png`.

---

# Phase 6 — Verify (human)

Produce two artifacts for the user:

```bash
# difference map — darker = more identical
magick compare -metric RMSE full.png reconstructed.png qa_diff.png ; echo

# side-by-side for the eyeball check
magick full.png reconstructed.png +append qa_sidebyside.png
```

Hand the user `qa_sidebyside.png` (full vs reconstructed) and `qa_diff.png`. They
confirm:

- Objects landed in the right places (boxes were correct).
- Cutout edges are clean (no halos / leftover background).
- The empty room behind has no object ghosts.

The diff map highlights exactly where reconstruction drifted from the original —
bright regions point at a bad box (Phase 2), a dirty cutout (Phase 3), or empty-
room drift (Phase 4, expect more with Variant B).

---

# Phase 7 — (Optional) Feed it into the game

The harvested boxes convert directly to the project's placement format
(`data/placements.json`, read/written via `scripts/layout.gd`). The game stores,
**per stable spot id**:

- `pos` = the sprite's **normalized center**: `center / (1084, 1451)`.
- `fsize` = the object's **on-screen width in pixels** at the 1084-wide canvas.

For a manifest box `[x, y, w, h]` on a `[W, H]` canvas:

```
center_x = x + w/2
center_y = y + h/2
pos   = [ center_x / W , center_y / H ]      # normalized center, 0..1
fsize = w * (1084 / W)                        # width scaled to the game canvas
```

(`pos` is clamped to 0..1 and `fsize` to 40..700 on save — see
`Layout.set_spot_pos` / `set_spot_fsize`.) Aspect must match the game's ~3:4 or the
`y` mapping drifts — see the Canvas-size note. For final tuning, drop the cutouts
in and nudge them live in the `place_test` sandbox (`godot --path . scenes/place_test.tscn`).

**Godot import gotcha:** Godot's texture importer can flatten a transparent PNG's
alpha to white. `scenes/place_test.gd` works around it by decoding the PNG at
runtime (`Image.load_png_from_buffer`). When installing a cutout as a real sprite,
either set its import to preserve alpha or decode it the same way.

---

## Prompt appendix (copy-paste)

All prompts in one place. `[STYLE LOCK]` = the block under **STYLE LOCK** above.

- **P1 — full zone:** Phase 1.
- **P2 — detect boxes:** Phase 2.
- **P3 — background removal (per crop):** Phase 3.
- **P4-A — masked empty room:** Phase 4 Variant A.
- **P4-B — whole-image empty room:** Phase 4 Variant B.

## Gotchas checklist

- [ ] Objects in `full.png` are **separated**, not touching — regenerate if not.
- [ ] Manifest boxes **verified** by overlay, not trusted raw from vision.
- [ ] Boxes **include the contact shadow**, exclude neighbors.
- [ ] P3 must not resize/redraw the object — same pixels, just erased background.
- [ ] Cutouts checked **over magenta** for halos/scraps.
- [ ] Variant A mask is **padded** (~12px) so shadows get inpainted, not left behind.
- [ ] For game use: canvas **aspect matches** ~3:4; alpha preserved on Godot import.
