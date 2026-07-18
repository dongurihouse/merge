# Coral Reef V2 Extraction Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a new `coral_reef_elements_v2` layered bundle whose backdrop, platforms, props, bubbles, palette, paper grain, and reconstruction closely match the approved original Coral Reef mock.

**Architecture:** Keep V1 untouched. Build one coherent opaque environmental plate by editing the original mock, then generate eight independent extraction-style runtime layers against flat magenta. Clean them to RGBA, place them at source-normalized coordinates, and produce a deterministic 1320 × 2346 reconstruction plus QA metadata.

**Tech Stack:** Built-in image generation/editing, Pillow image inspection and deterministic composition, `remove_chroma_key.py`, JSON placement metadata, PNG RGB/RGBA assets.

## Global Constraints

- The exact visual authority is `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/coral_reef.png`.
- Preserve V1 and create only `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/coral_reef_elements_v2`.
- Logical canvas and reconstruction are exactly 1320 × 2346.
- Runtime subjects use flat `#FF00FF` working backgrounds followed by RGBA cleanup.
- Preserve paper fiber, hand-cut edges, printed mottling, palette, lighting, source direction, silhouette, and camera.
- Keep canyon walls and all usable shelves in one opaque environmental plate.
- Do not put shelves, sand islands, dark shadow slabs, halos, or unrelated scenery inside runtime subject assets.
- Bubble bodies remain close to the water palette and composite at 55–70% opacity.
- Bottom pebble additions remain irregular and edge-weighted while the center navigation floor stays open.
- No UI, text, fish, creatures, extra treasure, ruins, anchors, or decorative landmarks.

---

### Task 1: Create the V2 bundle contract and source registration

**Files:**
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/coral_reef_elements_v2/README.md`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/coral_reef_elements_v2/00_source/coral_reef_reference.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/coral_reef_elements_v2/metadata/source_bounds.json`

**Interfaces:**
- Consumes: approved V2 design and the original 941 × 1672 mock.
- Produces: fixed folder contract and normalized source bounds for later placement tasks.

- [ ] **Step 1: Create the V2 directory contract**

Create `00_source`, `01_environment`, `02_subjects`, `03_atmosphere`, `04_reconstruction`, and `metadata`. The README must record the layered-raster model, source authority, 1320 × 2346 canvas, center-bottom placement convention, extraction-edit policy, and V1 preservation rule.

- [ ] **Step 2: Register the source reference and geometry**

Copy the original mock to `00_source/coral_reef_reference.png`. Write `source_bounds.json` with canvas `{ "width": 941, "height": 1672 }` and these source bounds:

```json
{
  "ship": [160, 262, 858, 800],
  "coral_garden": [0, 405, 385, 875],
  "anemones": [783, 683, 941, 858],
  "treasure_chest": [103, 939, 258, 1075],
  "mermaid_statue": [634, 889, 801, 1100],
  "giant_clam": [89, 1133, 357, 1422],
  "kelp_bed": [532, 914, 941, 1520],
  "bubble_left": [270, 82, 307, 346],
  "bubble_upper_center": [518, 41, 561, 525],
  "bubble_lower_center": [465, 843, 506, 1267]
}
```

- [ ] **Step 3: Verify the contract**

Run:

```bash
python3 - <<'PY'
from PIL import Image
from pathlib import Path
import json
r=Path('games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/coral_reef_elements_v2')
assert Image.open(r/'00_source/coral_reef_reference.png').size == (941,1672)
assert set(json.loads((r/'metadata/source_bounds.json').read_text())['bounds']) == {'ship','coral_garden','anemones','treasure_chest','mermaid_statue','giant_clam','kelp_bed','bubble_left','bubble_upper_center','bubble_lower_center'}
print('contract: PASS')
PY
```

Expected: `contract: PASS`.

### Task 2: Generate the coherent environmental plate with enlarged shelves

**Files:**
- Create: `coral_reef_elements_v2/01_environment/coral_reef_environment_v2.prompt.txt`
- Create: `coral_reef_elements_v2/01_environment/coral_reef_environment_v2_raw.png`
- Create: `coral_reef_elements_v2/01_environment/coral_reef_environment_v2.png`
- Create: `coral_reef_elements_v2/metadata/environment_qc.json`

**Interfaces:**
- Consumes: `00_source/coral_reef_reference.png` and shelf-width requirements from the design.
- Produces: one opaque RGB 1320 × 2346 plate used as the reconstruction base.

- [ ] **Step 1: Write the environment edit prompt**

State that the reference is the exact edit target. Remove only the ship, coral garden, anemones, chest, statue, clam, kelp, and bubbles. Preserve the original canyon silhouette, rock shapes, sand, paper grain, palette, camera, and lighting. Enlarge the coral shelf to at least 500 px, chest shelf to 300–340 px, clam shelf to 450–500 px, anemone shelf to 300–340 px, statue shelf to 340–380 px, and give kelp a broad continuous lower-right contact zone. Add 12–20 irregular slate pebbles near the lower edges and keep the center open.

- [ ] **Step 2: Generate and save the environment plate**

Use built-in image editing with the original mock visible as the edit target. Save the untouched generated output as `_raw.png`, then resize with Lanczos to exactly 1320 × 2346 and save RGB as `coral_reef_environment_v2.png`.

- [ ] **Step 3: Verify the environmental plate**

Check visually that every listed subject and all bubbles are absent, walls remain coherent, shelf tops meet their target widths, the bottom contains additional irregular pebbles, and the center floor remains open. Record measured shelf widths and pass/fail decisions in `environment_qc.json`.

- [ ] **Step 4: Run technical validation**

Run:

```bash
python3 - <<'PY'
from PIL import Image
from pathlib import Path
p=Path('games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/coral_reef_elements_v2/01_environment/coral_reef_environment_v2.png')
im=Image.open(p)
assert im.size == (1320,2346)
assert im.mode == 'RGB'
print('environment: PASS')
PY
```

Expected: `environment: PASS`.

### Task 3: Extract the ship, coral garden, and anemone cluster

**Files:**
- Create: `coral_reef_elements_v2/02_subjects/{sunken_ship,coral_garden,anemones}/prompt.txt`
- Create: `coral_reef_elements_v2/02_subjects/{sunken_ship,coral_garden,anemones}/raw.png`
- Create: `coral_reef_elements_v2/02_subjects/{sunken_ship,coral_garden,anemones}/final.png`
- Create: `coral_reef_elements_v2/metadata/upper_subjects_qc.json`

**Interfaces:**
- Consumes: the original mock as exact identity/edit authority.
- Produces: three transparent RGBA subject layers with source-matching direction and morphology.

- [ ] **Step 1: Write one extraction prompt per subject**

Every prompt must say: isolate only the existing named subject; preserve exact silhouette, proportions, facing, camera angle, paper grain, warm cut edges, printed mottling, palette, lighting, and visible construction; do not rotate, flip, mirror, front-face, simplify, sharpen, vectorize, emboss, or redesign; remove water, shelves, sand, rocks, and neighbors; use flat `#FF00FF`; add no floor, shadow, halo, platform, or scenery.

Add the subject locks from the design: the ship's bow high-left and mast up-right; coral's salmon/cream/lavender veined fans and chunky tubes; anemones' soft organic cup and flower forms.

- [ ] **Step 2: Generate the three extraction raws**

Use one built-in edit call per subject with the original mock as edit target. Reject and regenerate any result that changes direction, morphology, paper grain, palette, or aspect by more than roughly 10%.

- [ ] **Step 3: Clean each raw to RGBA**

Run `remove_chroma_key.py` for every raw using exact key `#FF00FF`, soft matte, despill, and one-pixel edge contraction. Preserve untouched raw files.

- [ ] **Step 4: Verify the three finals**

For each final, verify RGBA mode, transparent corners, nonempty alpha bounds, zero visible magenta, no edge touch, and visual agreement with the original. Record direction, aspect, material, palette, and morphology decisions in `upper_subjects_qc.json`.

### Task 4: Extract the chest, statue, clam, and kelp bed

**Files:**
- Create: `coral_reef_elements_v2/02_subjects/{treasure_chest,mermaid_statue,giant_clam,kelp_bed}/prompt.txt`
- Create: `coral_reef_elements_v2/02_subjects/{treasure_chest,mermaid_statue,giant_clam,kelp_bed}/raw.png`
- Create: `coral_reef_elements_v2/02_subjects/{treasure_chest,mermaid_statue,giant_clam,kelp_bed}/final.png`
- Create: `coral_reef_elements_v2/metadata/lower_subjects_qc.json`

**Interfaces:**
- Consumes: the original mock as exact identity/edit authority.
- Produces: four transparent RGBA subject layers with source-matching direction and material.

- [ ] **Step 1: Write one extraction prompt per subject**

Use the same exact-extraction core as Task 3. Lock the chest to its source three-quarter turn and visible top/side planes; the clam to its backward-leaning upper shell, foreshortened lower shell, asymmetric turn, lavender exterior, cream interior, and nested pearl; the statue to its seated center-left gaze, hair, flower, and compact pedestal; and the kelp to muted olive narrow S-curved blades with shallow paper layering.

- [ ] **Step 2: Generate the four extraction raws**

Use one built-in edit call per subject. Reject symmetrical front-facing chest or clam, a generic 3D statue, bright emerald ribbon kelp, or any loss of visible paper grain.

- [ ] **Step 3: Clean each raw to RGBA**

Run the same chroma cleanup settings as Task 3 and preserve untouched raws.

- [ ] **Step 4: Verify the four finals**

Verify RGBA mode, transparent corners, alpha bounds, zero visible magenta, no edge touch, and source-facing agreement. Record direction, aspect, material, and palette decisions in `lower_subjects_qc.json`.

### Task 5: Extract and tone the bubble-stream backdrop

**Files:**
- Create: `coral_reef_elements_v2/03_atmosphere/bubble_stream/prompt.txt`
- Create: `coral_reef_elements_v2/03_atmosphere/bubble_stream/raw.png`
- Create: `coral_reef_elements_v2/03_atmosphere/bubble_stream/final.png`
- Create: `coral_reef_elements_v2/metadata/bubble_qc.json`

**Interfaces:**
- Consumes: the source bubble locations and palette.
- Produces: one transparent RGBA atmosphere layer to composite behind all solid subjects.

- [ ] **Step 1: Write the bubble extraction prompt**

Preserve the original irregular two-ribbon rhythm, spacing, and scale. Specify bodies near `#8FC1D0`, edges near `#6FA9C0`, tiny highlights near `#D4E7E5`, no cream or white bodies, no dark outlines, no glassy rendering, and flat `#FF00FF` outside the bubbles.

- [ ] **Step 2: Generate and clean the bubble layer**

Use a built-in edit call against the original mock. Clean to RGBA, then multiply the alpha channel to 62% for the final runtime layer while keeping the untouched raw.

- [ ] **Step 3: Verify the bubble layer**

Verify the layer is RGBA, has transparent corners, contains zero visible magenta, and its mean visible RGB remains within the source water-blue family rather than warm cream. Record bubble count, palette samples, and final opacity in `bubble_qc.json`.

### Task 6: Build the placement manifest and integrated reconstruction

**Files:**
- Create: `coral_reef_elements_v2/metadata/placements.json`
- Create: `coral_reef_elements_v2/04_reconstruction/coral_reef_reconstruction_v2.png`
- Create: `coral_reef_elements_v2/metadata/reconstruction_qc.json`

**Interfaces:**
- Consumes: the environment plate and eight accepted RGBA runtime layers.
- Produces: deterministic source-normalized placements and the integrated V2 QA scene.

- [ ] **Step 1: Convert source bounds to the 1320 × 2346 canvas**

Scale source x coordinates by `1320 / 941` and y coordinates by `2346 / 1672`. Preserve each source bounding box aspect within roughly 10%. Use ascending z order: bubbles `10`, ship `20`, coral `30`, anemones `31`, chest `32`, statue `33`, clam `34`, kelp `35`.

- [ ] **Step 2: Write `placements.json`**

Record canvas dimensions, base environment path, center-bottom anchor convention, source bounds, target x/y/w/h, z values, collision `none`, and bubble opacity `0.62`.

- [ ] **Step 3: Compose the reconstruction**

Use Pillow or `compose_layered_preview.py` to render the RGB environment plus the eight layers at their manifest coordinates. Do not add procedural shadows, floors, color corrections, or new art.

- [ ] **Step 4: Perform visual comparison**

Compare V2 beside the original and V1. Verify shelf usability, source-facing chest and clam, source-like coral morphology, visible paper grain, water-toned bubbles, increased bottom pebbles, open center floor, and absence of forced ground pads. Record decisions in `reconstruction_qc.json`.

### Task 7: Run final bundle validation and present the review checkpoint

**Files:**
- Create: `coral_reef_elements_v2/metadata/final_validation.json`
- Create: `coral_reef_elements_v2/04_reconstruction/coral_reef_v1_v2_comparison.png`

**Interfaces:**
- Consumes: all V2 outputs.
- Produces: evidence-backed validation and the user-facing comparison checkpoint.

- [ ] **Step 1: Validate every runtime file**

Check the environment and reconstruction are RGB 1320 × 2346. Check all eight placement-referenced subjects exist as RGBA, have transparent corners and nonempty alpha, and contain zero visible magenta. Parse every JSON file and verify unique z values.

- [ ] **Step 2: Validate requirements explicitly**

Write `final_validation.json` with one boolean and note for every acceptance criterion in the approved design. A failed criterion prevents completion and names the asset requiring regeneration.

- [ ] **Step 3: Create the comparison image**

Create a three-column labeled comparison containing the original mock, V1 reconstruction, and V2 reconstruction at equal displayed height. This is deterministic postprocessing only.

- [ ] **Step 4: Stop for user review**

Present the V2 reconstruction and comparison image before any replacement, merge, or deletion. Keep V1 intact.
