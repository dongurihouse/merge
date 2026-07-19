# Fairy Hollow Scene Workbench Reconstruction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a clean `fairy_hollow_elements_v3` bundle that opens in Scene Workbench and reproduces the approved Fairy Hollow v2 composite from editable center-bottom-anchored layers and clusters.

**Architecture:** Keep `fairy_hollow_elements_v2` as the generation/source archive and create a palette-clean v3 runtime-authoring bundle. A deterministic intake script derives only accepted v3 assets from v2, `metadata/placements.json` is the single composition authority shared by Scene Workbench and the reconstruction compositor, and headless QA compares the reconstruction with the approved v2 preview.

**Tech Stack:** Godot 4 Scene Workbench, schema-v2 JSON, Python 3, Pillow, PNG/RGBA assets, Make targets `shot-sw`, `test-one`, and `test-fast`.

## Global Constraints

- Work only in `/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks` on branch `codex/ui-redesign-rush-maps-mocks`; preserve unrelated dirty files.
- Follow `/Users/xup/dh/merge/docs/design/scene-workbench-guide.md`: `1320 x 2346` canvas, top-left origin, center-bottom placement anchors, repo-relative image paths, and cluster-based editing.
- Use `scene_mode + layered_raster + separate_props + foreground_occluders + collisionModel none + existing_assets + project-native`.
- The base contains only the accepted ground/floor image; trees, structures, lights, vegetation, contacts, and foreground roots remain separate assets.
- The right host tree and carved dwelling remain one inseparable hero asset.
- Preserve the approved swing interleave as two members of one `moon_swing` cluster: support behind the rear trees, ropes and crescent seat in front.
- Preserve exactly seven editable hero clusters: `toadstool_cottage`, `tree_house`, `moon_swing`, `lantern_vines`, `wishing_well`, `glowing_mushrooms`, and `firefly_lanterns`.
- Use five contact-foliage placements: one with mushrooms, two with the well, and two with the firefly lanterns. Contact art must be separately movable and must not include lawns, floor patches, or baked dark shadows.
- Keep full-canvas environment plates unclustered; place the foreground root plate at z `500`.
- `metadata/placements.json` is the sole placement authority; no second hardcoded placement table may exist in the compositor.
- New visible v3 assets must have lineage and prompt provenance recorded in `metadata/asset_manifest.json`.
- Accepted transparent assets must be RGBA, nonempty, have transparent corners when tight, and contain zero visible chroma-key pixels.
- The complete reconstruction must exist at `1320 x 2346`; the review image must exist at `941 x 1672`.

---

### Task 1: Build the palette-clean v3 asset intake

**Files:**
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v3/00_style/prepare_workbench_assets.py`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v3/metadata/asset_manifest.json`
- Create: accepted PNGs under `01_backdrop/foundation`, `01_environment`, `03_structures`, `04_garden_items`, and `05_dressing`

**Interfaces:**
- Consumes: accepted v2 floor, registered plates, keyed alpha sprites, contact foliage, and prompt files.
- Produces: a self-contained v3 palette with canonical `fairy_hollow_<element>_v3.png` names and manifest entries consumed by Task 2.

- [ ] **Step 1: Write the deterministic intake script**

The script must locate the scenes root from its own path, read only accepted v2 sources, and generate these v3 assets:

```text
01_backdrop/foundation/fairy_hollow_foundation_v3.png
01_environment/background_trees/fairy_hollow_background_trees_v3.png
01_environment/midground_foliage/fairy_hollow_midground_foliage_v3.png
03_structures/toadstool_cottage/fairy_hollow_toadstool_cottage_v3.png
03_structures/tree_house/fairy_hollow_tree_house_v3.png
04_garden_items/moon_swing/fairy_hollow_moon_swing_support_v3.png
04_garden_items/moon_swing/fairy_hollow_moon_swing_seat_v3.png
04_garden_items/wishing_well/fairy_hollow_wishing_well_v3.png
04_garden_items/glowing_mushrooms/fairy_hollow_glowing_mushrooms_v3.png
04_garden_items/firefly_lanterns/fairy_hollow_firefly_lanterns_v3.png
05_dressing/lantern_vines/fairy_hollow_lantern_vines_v3.png
05_dressing/vegetation_pack/ground_tuft_01/fairy_hollow_ground_tuft_01_v3.png
05_dressing/vegetation_pack/ground_tuft_02/fairy_hollow_ground_tuft_02_v3.png
05_dressing/vegetation_pack/ground_tuft_03/fairy_hollow_ground_tuft_03_v3.png
05_dressing/vegetation_pack/ground_tuft_04/fairy_hollow_ground_tuft_04_v3.png
05_dressing/foreground_roots/fairy_hollow_foreground_roots_v3.png
```

Use v2's registered `1320 x 2346` plates as the crop authority for cottage, well, mushrooms, firefly lanterns, lantern vines, and contact instances. Normalize background trees, midground foliage, and foreground roots to full-canvas RGBA. Split the registered `941 x 1672` swing with masks `0..249` for support and `240..1671` for front, preserve the 10-pixel overlap, resize each plate to delivery size, then alpha-crop. Resize the complete tight host-tree asset to `730 x 1291` without cropping its right edge.

- [ ] **Step 2: Write the asset manifest**

For each accepted v3 asset record `id`, v3 repo-relative `final`, v2 repo-relative `source`, `sourcePrompt`, `transparent`, and either `requiredSize: [1320, 2346]` for full plates or the derived native size for tight sprites. Record `schemaVersion: 1`, `scene: fairy_hollow_v3`, and `visualAssetSource: existing_assets`.

- [ ] **Step 3: Run intake and validate the palette**

Run:

```bash
python3 games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v3/00_style/prepare_workbench_assets.py
```

Expected: all 16 accepted files exist; the four ground-tuft assets appear under the `vegetation` palette category; there are no `_raw`, `_review`, `rejected`, `local`, `montage`, `contact`, or preview PNGs outside skipped directories.

- [ ] **Step 4: Commit Task 1**

Stage only the v3 intake script, manifest, and accepted v3 assets, then commit with `feat(grove): intake Fairy Hollow workbench assets`.

### Task 2: Make placements.json the composition authority

**Files:**
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v3/metadata/placements.json`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v3/09_reconstruction/compose_reconstruction.py`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v3/README.md`
- Generate: `09_reconstruction/fairy_hollow_reconstruction_v3_1320x2346.png`
- Generate: `09_reconstruction/fairy_hollow_reconstruction_v3_review_941x1672.png`
- Generate: `09_reconstruction/reconstruction_report.json`
- Generate: `metadata/validation_report.json`

**Interfaces:**
- Consumes: Task 1 manifest and accepted assets.
- Produces: the schema-v2 Scene Workbench document and deterministic QA outputs.

- [ ] **Step 1: Author the schema-v2 placement document**

Set the base to the v3 foundation with z `0`. Use these z bands and clusters:

```text
10 moon_swing_support_back (cluster moon_swing)
20 background_trees (full canvas, unclustered)
30 midground_foliage (full canvas, unclustered)
250 toadstool_cottage (cluster toadstool_cottage)
260 tree_house (cluster tree_house)
270 moon_swing_seat_front (cluster moon_swing)
280 lantern_vines (cluster lantern_vines)
300 wishing_well (cluster wishing_well)
310 glowing_mushrooms (cluster glowing_mushrooms)
320 firefly_lanterns (cluster firefly_lanterns)
330 mushrooms contact (cluster glowing_mushrooms)
331-332 well contacts (cluster wishing_well)
333-334 lantern contacts (cluster firefly_lanterns)
500 foreground_roots (full canvas, unclustered)
```

Full-canvas rows use `x: 660`, `y: 2346`, `w: 1320`, `h: 2346`. Tight rows use the generated native asset size and center-bottom anchors derived from these accepted delivery bounds:

```text
toadstool_cottage [32, 801, 480, 1245]
lantern_vines [572, 342, 1301, 633]
wishing_well [809, 1210, 1058, 1568]
glowing_mushrooms [81, 1470, 571, 1778]
firefly_lanterns [900, 1547, 1241, 1954]
mushrooms_contact [106, 1708, 217, 1788]
well_contact_left [765, 1523, 873, 1578]
well_contact_right [995, 1508, 1100, 1572]
lantern_contact_left [876, 1891, 987, 1965]
lantern_contact_right [1175, 1891, 1278, 1965]
```

Place the complete `730 x 1291` tree house at `x: 996`, `y: 1291` so the initial right-edge clipping matches the approved composition while the full host tree remains available when moved. Derive both swing anchors directly from the generated split assets' recorded source bounds.

- [ ] **Step 2: Write the data-driven compositor and validator**

Read `metadata/placements.json`, sort by `(z, list index)`, render every item using center-bottom anchors, and produce full/review images. Validate manifest paths, placement paths, image modes, transparent corners, zero visible chroma-key pixels, unique ids/z values, exact counts (`16` placements, `7` clusters, `5` contact placements), full-canvas sizes, tree-house structural metadata, output dimensions, and palette cleanliness. Write results to `metadata/validation_report.json`; exit nonzero on failure. Support `--validate-only`.

- [ ] **Step 3: Document the workbench workflow**

README must identify `metadata/placements.json` as the sole authority and include the exact commands:

```bash
python3 games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v3/09_reconstruction/compose_reconstruction.py
make shot-sw SCENE=fairy_hollow ROOT=/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1 OUT=/tmp/fairy_hollow_scene_workbench.png
make sw SCENE=fairy_hollow ROOT=/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1
```

- [ ] **Step 4: Rebuild and validate**

Run the compositor normally and with `--validate-only`. Expected: status `pass`, 16 placements, 7 clusters, 5 contacts, zero missing assets, zero visible key pixels, and exact full/review dimensions.

- [ ] **Step 5: Commit Task 2**

Stage only Task 2 files and generated reports/previews, then commit with `feat(grove): reconstruct Fairy Hollow in scene workbench`.

### Task 3: Verify the real Scene Workbench integration

**Files:**
- Inspect: `/tmp/fairy_hollow_scene_workbench.png`
- Inspect: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v3/09_reconstruction/fairy_hollow_reconstruction_v3_1320x2346.png`
- Inspect: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v2/03_preview/fairy_hollow_complete_1320x2346.png`

**Interfaces:**
- Consumes: complete v3 bundle.
- Produces: verified workbench discovery/render evidence and final visual approval checkpoint.

- [ ] **Step 1: Run the focused workbench tests**

From `/Users/xup/dh/merge`, run:

```bash
make test-one SUITE=games/grove/tests/grove_scene_workbench_tests
```

Expected: the Scene Workbench suite passes with zero failures.

- [ ] **Step 2: Render the born-minimized workbench screenshot**

From `/Users/xup/dh/merge`, run:

```bash
make shot-sw SCENE=fairy_hollow ROOT=/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1 OUT=/tmp/fairy_hollow_scene_workbench.png
```

Expected terminal evidence: `SHOT saved=/tmp/fairy_hollow_scene_workbench.png err=0`.

- [ ] **Step 3: Inspect both QA images**

Open the workbench screenshot and the v3 reconstruction. Confirm the foundation fills the scene, the swing support is hidden behind rear trees while the seat remains in front, the host-tree dwelling remains fused, all seven hero clusters are present, the center clearing remains open, and foreground roots occlude only the bottom edge.

- [ ] **Step 4: Run the full fast regression suite**

From `/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks`, run `make test-fast`. Expected: all suites pass with zero failures.

- [ ] **Step 5: Record final verification**

Run `git diff --check` for the v3 bundle and plan, inspect `git status --short` to ensure no unrelated files were staged or committed, and report the exact workbench launch command with the visual checkpoint. Do not merge before the user approves the reconstruction screenshot.
