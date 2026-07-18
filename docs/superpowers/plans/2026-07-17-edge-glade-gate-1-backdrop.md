# Edge Glade Gate 1 Backdrop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate and present the first production-resolution Edge Glade true backdrop containing only sky, meadow, radiance, and a soft horizon.

**Architecture:** Use the approved dressed PNG only as a style, palette, material, lighting, camera, and broad-composition reference. Generate a new object-free opaque image with the built-in image-generation tool, preserve the raw output and exact prompt, conform it non-destructively to the 1320 × 2868 master canvas, and stop at the Gate 1 user-review checkpoint.

**Tech Stack:** Built-in image generation, PNG, ImageMagick or Pillow for deterministic dimension conformance and pixel inspection, Git.

## Global Constraints

- Production canvas is exactly 1320 × 2868 px, portrait, opaque RGB.
- Sky occupies approximately the upper 28–30%; the soft irregular horizon is centered near y = 820 px.
- Meadow is cooler and darker near the horizon and brighter yellow-green through the central play area.
- Warm lime radiance enters from the upper-left to upper-middle.
- Top y = 0–487 px and bottom y = 2466–2867 px remain visually quiet.
- Do not include clouds, paths, stones, trees, bushes, flowers, mushrooms, buildings, roots, soil patches, grass tufts, cast shadows, dark grounding bands, UI, text, frames, or watermarks.
- The dressed reference is visual context only and may not be resized, painted over, or used as a production layer.
- Stop after Gate 1; do not generate any transparent sprites.

---

### Task 1: Generate, validate, and present the true backdrop

**Files:**

- Reference: `games/grove/assets/_new/ui_redesign_direction_b/edge_glade_layered_work_v1/edge_glade_dressed_reference.png`
- Reference: `docs/superpowers/specs/2026-07-17-edge-glade-layered-assets-design.md`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/edge_glade_layered_work_v1/backdrop/source/edge_glade_true_backdrop_v1.prompt.txt`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/edge_glade_layered_work_v1/backdrop/source/edge_glade_true_backdrop_v1_raw.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/edge_glade_layered_work_v1/backdrop/final/edge_glade_true_backdrop_v1.png`

**Interfaces:**

- Consumes: the approved reference PNG for visual style only and the Gate 1 constraints above.
- Produces: one exact prompt record, one untouched raw generated PNG, and one opaque 1320 × 2868 Gate 1 review PNG.

- [ ] **Step 1: Create the exact generation prompt**

Write the following prompt verbatim to `backdrop/source/edge_glade_true_backdrop_v1.prompt.txt` and use the same text in the built-in image-generation call:

```text
Use case: stylized-concept
Asset type: production background plate for a portrait mobile game home screen
Input image: Edge Glade dressed reference; use it only for its colorful high-contrast cut-paper cartoon style, Meadow Sky palette, soft upper-left lighting, paper texture, camera feeling, and cheerful woodland atmosphere. Do not copy or retain any discrete object from it.
Primary request: create a completely empty true backdrop containing only an open blue sky above a continuous green meadow.
Scene/backdrop: sky occupies the upper 28 to 30 percent. Make the boundary a soft irregular distant horizon centered near 29 percent of image height, not a hard stripe. The meadow is cooler and slightly darker at the horizon, transitioning into luminous fresh yellow-green through the central play area. Add a broad warm lime radiance from the upper-left to upper-middle. Use subtle layered-paper texture and broad gentle tonal variation, but no object-like marks.
Style/medium: polished colorful high-contrast children's cut-paper game illustration, matte layered paper, clean broad shapes, friendly and premium, consistent with the reference but entirely object-free.
Composition/framing: very tall portrait matching 1320 by 2868. Keep the upper 17 percent and lower 14 percent visually quiet. The entire ground must remain one continuous neutral placement plane.
Lighting/mood: bright welcoming daylight, soft upper-left illumination, cheerful and calm.
Constraints: opaque full-bleed background; no transparent areas; no discrete scenery; no generated text.
Avoid: clouds, sun disc, hills, mountains, paths, roads, stepping stones, trees, bushes, hedges, flowers, mushrooms, rocks, buildings, dens, roots, fences, props, grass tufts, individual leaves, soil patches, turf islands, cast shadows, dark grounding strips, gradients that form hard bands, borders, UI, icons, labels, frames, watermarks.
```

- [ ] **Step 2: Generate one raw backdrop candidate**

Load the reference PNG for inspection, then call the built-in image-generation tool once with the prompt from Step 1 and the reference path as a style/composition reference. Copy the resulting PNG without alteration to:

```text
games/grove/assets/_new/ui_redesign_direction_b/edge_glade_layered_work_v1/backdrop/source/edge_glade_true_backdrop_v1_raw.png
```

Expected: one tall portrait opaque image with only sky, meadow, radiance, and a soft horizon.

- [ ] **Step 3: Inspect the raw candidate before processing**

Open the raw candidate at original detail and reject it if any forbidden discrete object, hard horizon stripe, dark lower band, text, frame, watermark, or obvious generation seam is visible. If rejected, make one targeted prompt correction and generate a versioned raw candidate; do not silently broaden the art direction.

Expected: the accepted raw candidate satisfies all semantic Gate 1 constraints.

- [ ] **Step 4: Conform the accepted raw image to the master canvas**

Preserve the raw file. Create the final file with a high-quality center crop and resize to exactly 1320 × 2868, flattening to RGB. Use this command when ImageMagick is available:

```bash
magick backdrop/source/edge_glade_true_backdrop_v1_raw.png \
  -colorspace sRGB \
  -resize '1320x2868^' \
  -gravity center \
  -extent 1320x2868 \
  -alpha off \
  -type TrueColor \
  backdrop/final/edge_glade_true_backdrop_v1.png
```

If ImageMagick is unavailable, use Pillow `ImageOps.fit(..., (1320, 2868), method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))` followed by `.convert("RGB")` and save as PNG.

Expected: final image is exactly 1320 × 2868 and has no alpha channel.

- [ ] **Step 5: Verify file properties and visual acceptance**

Run:

```bash
file games/grove/assets/_new/ui_redesign_direction_b/edge_glade_layered_work_v1/backdrop/final/edge_glade_true_backdrop_v1.png
```

Expected output includes:

```text
PNG image data, 1320 x 2868, 8-bit/color RGB
```

Inspect the final image at original detail. Confirm:

- horizon near y = 820 px;
- sky approximately 28–30%;
- warm upper-left/upper-middle radiance;
- continuous unobstructed meadow;
- quiet top and bottom zones;
- no forbidden object or accidental placement constraint;
- no crop, resize, color-mode, or edge artifact.

- [ ] **Step 6: Commit and stop at Gate 1**

Run:

```bash
git add \
  docs/superpowers/plans/2026-07-17-edge-glade-gate-1-backdrop.md \
  games/grove/assets/_new/ui_redesign_direction_b/edge_glade_layered_work_v1/backdrop/source/edge_glade_true_backdrop_v1.prompt.txt \
  games/grove/assets/_new/ui_redesign_direction_b/edge_glade_layered_work_v1/backdrop/source/edge_glade_true_backdrop_v1_raw.png \
  games/grove/assets/_new/ui_redesign_direction_b/edge_glade_layered_work_v1/backdrop/final/edge_glade_true_backdrop_v1.png
git commit -m "art(grove): add Edge Glade true backdrop"
```

Expected: the Gate 1 plan, prompt, raw source, and final backdrop are committed together. Present the final PNG to the user and wait for explicit approval before beginning Gate 2.
