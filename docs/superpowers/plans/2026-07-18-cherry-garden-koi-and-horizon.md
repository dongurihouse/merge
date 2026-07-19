# Cherry Garden Koi and Horizon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add five editable, water-integrated koi to the cherry garden pond and move the five distant landscape layers upward so the pond remains visually clear.

**Architecture:** Generate a six-item top-down koi pack as one chroma-keyed 2 x 3 sheet, deterministically split it into transparent sprites, then add five sprites to the existing workbench document through `scene_workbench_model.gd`. The baked backdrop and pond-edge dressing remain unchanged; only the three mountain and two horizon-vegetation placement anchors move.

**Tech Stack:** Built-in `image_gen`, `generate2dsprite.py`, PNG with alpha, Godot 4.6 `scene_workbench_model.gd`, jq assertions, `make shot-sw`, `make test-fast`.

## Global Constraints

- Match the current cherry-garden paper-cut picture-book rendering with simple shapes, crisp high-contrast markings, light paper texture, and no photoreal detail.
- The source sheet background is exactly solid `#FF00FF`, with no water tile, cast shadow, ripple halo, plants, rocks, text, labels, frames, or borders.
- Produce six individual top-down koi and place five as editable entries in cluster `koi`.
- Keep koi inside the pond and paint them above the baked backdrop but below pond-edge dressing and structures.
- Move only `mountain_far`, `mountain_middle`, `mountain_near`, `horizon_vegetation_rear`, and `horizon_vegetation_near`; preserve their relative spacing, scale, horizontal alignment, and z-order.
- Do not change the baked backdrop, pond-edge placements, bridge, pavilion, cherry trees, bonsai, torii, lanterns, or foreground dressing.
- Mutate `metadata/placements.json` through `scene_workbench_model.gd`, not a direct JSON rewrite.

---

### Task 1: Generate and process the koi sprite pack

**Files:**
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/koi_pack_2x3_v1.prompt.txt`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/raw-sheet-generated.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/raw-sheet.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/raw-sheet-clean.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/sheet-transparent.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/koi-1.png` through `koi-6.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/prompt-used.txt`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/pipeline-meta.json`

**Interfaces:**
- Consumes: `cherry_blossom_garden_pure_backdrop_v2.png` and the current workbench screenshot as style and scale references.
- Produces: six square transparent PNGs named `koi-1.png` through `koi-6.png`, each centered and safe for independent workbench placement.

- [ ] **Step 1: Inspect the approved scene reference**

Use `view_image` on:

```text
/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/01_backdrop/foundation/cherry_blossom_garden_pure_backdrop_v2.png
```

Confirm the pond is seen from above, uses deep teal-blue water, and has a softly textured cut-paper surface.

- [ ] **Step 2: Write the exact generation prompt**

Write this text to `koi_pack_2x3_v1.prompt.txt`:

```text
Use case: stylized-concept
Asset type: editable 2D game map prop pack
Primary request: Create exactly six distinct koi fish as a 2 x 3 sprite sheet: two rows and three equal columns. Each cell contains exactly one individual koi viewed directly from above, with the full fish centered and isolated.
Reference role: Match the cherry-blossom garden reference's colorful high-contrast handmade cut-paper picture-book style, lightly fibrous paper texture, clean low-complexity shapes, crisp silhouette, and friendly premium mobile-game finish.
Subjects: six slender koi with varied orientations and gentle swimming body curves. Use distinct traditional markings: vermilion and white, orange and white, gold, black and white, red black and white, and pale cream with orange markings.
Water integration: Slightly soften and cool the fish colors as if seen just below clear teal pond water. Keep this treatment entirely within each fish silhouette. No external blue haze and no water patch.
Composition: exact 2 x 3 grid, consistent fish scale, each fish occupying the central 60 to 70 percent of its cell, generous padding, nothing crossing a cell edge. Vary the direction of the fish between cells so the individual sprites can form a natural school.
Background: perfectly flat uniform solid #FF00FF chroma-key background across the entire image.
Constraints: no cell borders, no frames, no grid lines, no text, no labels, no UI, no water tiles, no ponds, no rocks, no vegetation, no bubbles, no ripple rings, no cast shadows, no contact shadows, no glow, and no detached effects. Do not use #FF00FF anywhere in the fish.
```

- [ ] **Step 3: Generate the raw sheet with built-in image generation**

Call built-in `image_gen` using the prompt file contents and the approved backdrop as the visual style reference. Copy the returned PNG into the exact path:

```text
games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/raw-sheet-generated.png
```

Expected: exactly six isolated fish in a 2 x 3 grid on uniform magenta.

- [ ] **Step 4: Process the sheet into individual alpha sprites**

Run from the asset worktree root:

```bash
python3 /Users/xup/.codex/skills/generate2dsprite/scripts/generate2dsprite.py process \
  --input games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/raw-sheet-generated.png \
  --target asset \
  --mode sheet \
  --output-dir games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack \
  --prompt-file games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/koi_pack_2x3_v1.prompt.txt \
  --rows 2 \
  --cols 3 \
  --label-prefix koi \
  --cell-size 256 \
  --fit-scale 0.78 \
  --trim-border 2 \
  --edge-clean-depth 2 \
  --align center \
  --shared-scale \
  --component-mode largest \
  --component-padding 3 \
  --min-component-area 100 \
  --edge-touch-margin 4 \
  --reject-edge-touch
```

Expected: exit 0 and six `koi-N.png` files plus `pipeline-meta.json`.

- [ ] **Step 5: Validate the generated sprites**

Run:

```bash
jq -e '.rows == 2 and .cols == 3 and (.edge_touch_frames | length) == 0 and (.frames | length) == 6' \
  games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/pipeline-meta.json
```

Expected: `true`.

Inspect `sheet-transparent.png` with `view_image`. Reject and regenerate if any fish is cropped, includes a water patch or shadow, loses fins during cleanup, or breaks the project style.

- [ ] **Step 6: Commit the accepted koi pack**

```bash
git add games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack
git commit -m "art: add cherry garden koi sprite pack"
```

---

### Task 2: Place five koi and raise the distant landscape

**Files:**
- Modify: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/metadata/placements.json`
- Preserve: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/metadata/placements.json.bak`

**Interfaces:**
- Consumes: Task 1's `koi-1.png` through `koi-5.png`.
- Produces: five `koi` cluster placements at z 200 through 204 and five raised distant landscape placements at their existing z values.

- [ ] **Step 1: Run the pre-change assertion**

```bash
jq -e '([.placements[] | select(.cluster == "koi")] | length) == 5 and ([.placements[] | select(.id == "mountain_far")][0].y == 2126)' \
  games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/metadata/placements.json
```

Expected: nonzero exit because koi placements do not exist and `mountain_far.y` is still 2346.

- [ ] **Step 2: Apply the workbench-model mutation**

Create a temporary Godot script under the main checkout's `games/grove/tools/`, load `scene_workbench_model.gd`, and use `Model.set_pos` for the five distant layers with a delta of `(0, -220)`. Use `Model.add_entry` to append exactly these entries:

```gdscript
{
 "id": "koi_vermilion_white", "category": "dressing", "cluster": "koi",
 "image": "games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/koi-1.png",
 "x": 270, "y": 1450, "w": 112, "h": 112, "z": 200, "layer": "koi"
}
{
 "id": "koi_orange_white", "category": "dressing", "cluster": "koi",
 "image": "games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/koi-2.png",
 "x": 500, "y": 1495, "w": 96, "h": 96, "z": 201, "layer": "koi"
}
{
 "id": "koi_gold", "category": "dressing", "cluster": "koi",
 "image": "games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/koi-3.png",
 "x": 365, "y": 1625, "w": 122, "h": 122, "z": 202, "layer": "koi"
}
{
 "id": "koi_black_white", "category": "dressing", "cluster": "koi",
 "image": "games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/koi-4.png",
 "x": 590, "y": 1690, "w": 102, "h": 102, "z": 203, "layer": "koi"
}
{
 "id": "koi_tricolor", "category": "dressing", "cluster": "koi",
 "image": "games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/koi-5.png",
 "x": 395, "y": 1790, "w": 108, "h": 108, "z": 204, "layer": "koi"
}
```

Set the `y` anchor of `mountain_far`, `mountain_middle`, `mountain_near`, `horizon_vegetation_rear`, and `horizon_vegetation_near` from 2346 to 2126 without changing any other entry field. Require exactly five matched landscape IDs and exactly five added koi before calling `Model.save_doc`. Delete the temporary script after it exits successfully.

- [ ] **Step 3: Validate placement invariants**

Run:

```bash
jq -e '
  ([.placements[] | select(.cluster == "koi")] | length) == 5 and
  ([.placements[] | select(.cluster == "koi") | .z] == [200,201,202,203,204]) and
  ([.placements[] | select(.id == "mountain_far" or .id == "mountain_middle" or .id == "mountain_near" or .id == "horizon_vegetation_rear" or .id == "horizon_vegetation_near") | .y] | unique) == [2126] and
  ([.placements[] | select(.cluster == "pond")] | length) == 7 and
  (.placements | length) == 45
' games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/metadata/placements.json
```

Expected: `true`.

- [ ] **Step 4: Render and inspect the updated workbench**

From `/Users/xup/dh/merge`, run:

```bash
make shot-sw \
  SCENE=cherry_blossom_garden \
  ROOT=/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1 \
  OUT=/tmp/cherry_scene_workbench_koi.png
```

Expected: `SHOT saved=/tmp/cherry_scene_workbench_koi.png err=0`.

Inspect `/tmp/cherry_scene_workbench_koi.png` with `view_image`. If any koi crosses the stone shoreline or is hidden by the bridge, adjust only the koi positions or sizes through the model. If the distant vegetation still covers the pond boundary, move all five distant layers upward by the same additional delta and re-render.

- [ ] **Step 5: Commit the placement update**

```bash
git add games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/metadata/placements.json
git commit -m "art: place koi and clear cherry garden pond"
```

---

### Task 3: Final verification

**Files:**
- Verify: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack/pipeline-meta.json`
- Verify: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/metadata/placements.json`
- Verify: `/tmp/cherry_scene_workbench_koi.png`

**Interfaces:**
- Consumes: completed koi pack and workbench placements.
- Produces: fresh test evidence and the review screenshot delivered to the user.

- [ ] **Step 1: Run focused asset and placement assertions**

Run the exact jq commands from Task 1 Step 5 and Task 2 Step 3 again from a clean shell.

Expected: both print `true` and exit 0.

- [ ] **Step 2: Run the fast project suite**

From `/Users/xup/dh/merge`, run:

```bash
make test-fast
```

Expected: all suites pass with zero failures.

- [ ] **Step 3: Re-render from saved placement state**

Run Task 2 Step 4's `make shot-sw` command again without making any intervening edits.

Expected: exit 0 and a fresh `/tmp/cherry_scene_workbench_koi.png` matching the accepted composition.

- [ ] **Step 4: Review repository scope**

```bash
git status --short -- \
  docs/superpowers/specs/2026-07-18-cherry-garden-koi-and-horizon-design.md \
  docs/superpowers/plans/2026-07-18-cherry-garden-koi-and-horizon.md \
  games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/koi_pack \
  games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/metadata/placements.json
```

Expected: only the intended cherry-garden design, plan, koi assets, and placements are in scope; unrelated pre-existing worktree changes remain untouched.
