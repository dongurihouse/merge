# Fairy Hollow Original Mock V4 Reconstruction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recreate the original Fairy Hollow concept as a fully editable v4 Scene Workbench bundle, with a river-and-path foundation and separate complete placeable assets.

**Architecture:** Build a new `fairy_hollow_elements_v4` layered-raster bundle at the existing picturebook scenes root. The foundation is the only opaque ground layer; all environment, heroes, contact dressing, and foreground cover are separate PNGs placed by one `metadata/placements.json` document. A local compositor reads that document, validates intake provenance and alpha/path rules, then emits the visual-review composite.

**Tech Stack:** Built-in image generation; Pillow validation/composition; Godot Scene Workbench; `make shot-sw`; existing `grove_scene_workbench_tests`.

## Global Constraints

- Use `games/grove/assets/_concepts/zones/fairy_hollow_original_mock_v1.png` as the active composition/camera/scale reference.
- Use the palette and camera reference images in `/Users/xup/dh/merge/.worktrees/codex-zone-mocks-concepts-v3/games/grove/assets/_new/ui_redesign_direction_b/` as supporting Meadow Sky authorities; do not copy their farm content.
- Bundle canvas is exactly `1320 x 2346`, anchors are center-bottom, and all paths stored in metadata are repo-relative.
- The opaque foundation contains only night sky, continuous meadow, creek, stepping-stone path, cottage threshold stones, and picnic-area cobbles. It contains no hero object, bridge, foliage collar, lantern, animal, or foreground occluder.
- Color sprites are transparent and carry no baked shadow. Grounding is made with independent compact vegetation/rock/contact assets; no dark ovals, turf islands, forced flower rings, or grass plates.
- Rebuild occluded objects as complete reference-conditioned assets. Do not crop them from the mock.
- Each generated accepted asset stores its exact prompt and source-reference provenance in the asset manifest.
- Preserve normal Workbench move/resize/reorder behavior. `placements.json` is the sole coordinate, size, z, and cluster authority.
- Do not change unrelated UI assets or attempt to repair the branch's pre-existing full-suite asset failures.

---

### Task 1: Establish the V4 bundle, clean foundation, and environment plates

**Files:**
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/01_backdrop/foundation/fairy_hollow_foundation_v4.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/01_environment/distant_hills/fairy_hollow_distant_hills_v4.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/01_environment/forest_band/fairy_hollow_forest_band_v4.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/01_environment/frame_trees/fairy_hollow_frame_trees_v4.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/01_environment/sky_dressing/fairy_hollow_sky_dressing_v4.png`
- Create: matching `*.prompt.txt` source files beside every generated plate
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/metadata/asset_manifest.json`

**Interfaces:**
- Consumes: source mock plus the two supporting Meadow Sky references.
- Produces: opaque `foundation` and transparent named environment plates with manifest entries `{id, category, final, source, sourcePrompt, transparent, requiredSize}` for Tasks 2–4.

- [ ] **Step 1: Generate the clean foundation from the visible source mock**

Make the original mock and supporting references visible immediately before the generation call. Generate a `1320 x 2346` portrait plate with only the night sky, continuous meadow, creek, winding stepping-stone route, cottage threshold stones, and picnic-area cobbles. Explicitly exclude all buildings, bridge, furniture, mushrooms, lanterns, animals, foliage masses, flowers, trees, and UI.

- [ ] **Step 2: Generate clean environment plates**

Generate four separate chroma-keyed transparent plates matching the same camera and exact canvas: distant hills, distant conifer/forest band, side/top framing trees and canopy, and sparse moon/star dressing. Each prompt must state that it matches the visible original mock and does not contain ground-contact heroes or UI.

- [ ] **Step 3: Process and validate the transparent plates**

Use the installed chroma-key helper for every keyed plate. Confirm RGBA output, zero visible key pixels, transparent corners, nonzero visible coverage, and no opaque canvas edge clipping for finite props. Preserve prompt text beside the final asset.

- [ ] **Step 4: Write the first manifest entries and verify the foundation**

Write manifest entries for all Task 1 assets. Run a short Pillow check asserting foundation dimensions are `[1320, 2346]`, foundation is opaque, every environment plate is RGBA, and every referenced file exists.

- [ ] **Step 5: Commit**

```bash
git add games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4
git commit -m "feat(grove): add Fairy Hollow v4 foundation and environment"
```

### Task 2: Generate complete hero props and their contact dressing

**Files:**
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/03_structures/toadstool_cottage/fairy_hollow_toadstool_cottage_v4.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/03_structures/fox_den/fairy_hollow_fox_den_v4.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/04_garden_items/wishing_well/fairy_hollow_wishing_well_v4.png`, `stone_bridge/fairy_hollow_stone_bridge_v4.png`, `picnic_table/fairy_hollow_picnic_table_v4.png`, `picnic_stools/fairy_hollow_picnic_stools_v4.png`, `bluebell_pot/fairy_hollow_bluebell_pot_v4.png`, `glowing_mushrooms/fairy_hollow_glowing_mushrooms_v4.png`, `well_mushrooms/fairy_hollow_well_mushrooms_v4.png`, `golden_mushrooms/fairy_hollow_golden_mushrooms_v4.png`, `lantern_branch/fairy_hollow_lantern_branch_v4.png`, `cottage_lantern/fairy_hollow_cottage_lantern_v4.png`, `den_lantern/fairy_hollow_den_lantern_v4.png`, and `cottage_fence/fairy_hollow_cottage_fence_v4.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/05_dressing/contact_pack/fairy_hollow_contact_pack_v4.png`, `fireflies/fairy_hollow_fireflies_v4.png`, and `foreground_foliage/fairy_hollow_foreground_foliage_v4.png`
- Modify: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/metadata/asset_manifest.json`

**Interfaces:**
- Consumes: Task 1 foundation/environment reference and manifest schema.
- Produces: clean complete transparent hero/color assets plus separate contact details, with manifest source/prompt provenance used by Tasks 3–4.

- [ ] **Step 1: Generate the two major structures one by one**

Generate a complete toadstool cottage (including chimney and entry steps) and a complete fox-den mound/entrance as separate keyed sprites. Match the mock’s camera and scale. Exclude grass skirts, flower rings, cast shadows, water, and unrelated props. The sleeping fox is not baked into the den.

- [ ] **Step 2: Generate placeable clearing props one by one**

Generate the well, stone bridge, stump picnic table, three-stool pack, potted bluebells, main glowing mushroom cluster, small well mushroom cluster, lower golden mushroom pair, cottage fence, branch lantern assembly, cottage eave lantern, and den lantern. Keep bridge and table large assets separate; compact stools may share one clearly separated 3-piece pack only if each stool has a clean independent silhouette.

- [ ] **Step 3: Generate contact and foreground dressing separately**

Generate compact asymmetric contacts for cottage, den, well, bridge, picnic furniture, and mushrooms; a sparse firefly-light overlay; and independent lower/side foreground foliage. Contacts must overlap local feet/bases but never become a continuous platform, obscure a door/deck, or contain a baked shadow.

- [ ] **Step 4: Process every keyed asset and update manifest provenance**

Chroma-key all outputs, validate alpha/corners/key-fringe/nonempty coverage, retain the raw source only outside the addable palette, and add `id`, `final`, `source`, `sourcePrompt`, `transparent`, and `[w, h]` required size to the manifest. The manifest must have exactly one final path per asset id.

- [ ] **Step 5: Commit**

```bash
git add games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4
git commit -m "feat(grove): add Fairy Hollow v4 placeable assets"
```

### Task 3: Compose and validate the editable Scene Workbench document

**Files:**
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/metadata/placements.json`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/09_reconstruction/compose_reconstruction.py`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/09_reconstruction/fairy_hollow_reconstruction_v4_1320x2346.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/09_reconstruction/fairy_hollow_reconstruction_v4_review_941x1672.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/09_reconstruction/reconstruction_report.json`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/metadata/validation_report.json`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/README.md`

**Interfaces:**
- Consumes: Task 1/2 assets and `asset_manifest.json`.
- Produces: valid v4 Workbench bundle, deterministic full/review reconstruction, and strict report used by Task 4.

- [ ] **Step 1: Write initial placements with documented clusters and z bands**

Use center-bottom anchors and unique z values. Add unclustered foundation/environment first, then these named clusters: `toadstool_cottage`, `fox_den`, `wishing_well`, `stone_bridge`, `picnic_set`, `glowing_mushrooms`, `well_mushrooms`, `golden_mushrooms`, `lantern_branch`, and `cottage_fence`. Group every local contact with its hero. Use `500+` only for foreground cover.

- [ ] **Step 2: Implement the compositor/validator**

Adapt the v3 compositor contract without copying v3 placement coordinates. It must load only `placements.json` and the manifest; sort by `(z, authoring order)`; render each entry at saved `x/y/w/h`; generate full and review images; reject absolute/traversal paths, missing files, duplicate manifest final paths, invalid geometry, image/asset-id mismatch, visible `#FF00FF`, fully transparent accepted PNGs, and palette files not represented in the manifest.

- [ ] **Step 3: Record provenance and use instructions**

Document source mock path, prompt files, canvas, cluster rules, edit loop, standard compositor commands, and `make sw SCENE=fairy_hollow ROOT=/Users/xup/dh/merge/.worktrees/codex-fairy-hollow-original-mock-v4/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1` in the bundle README.

- [ ] **Step 4: Run deterministic validation**

```bash
python3 games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/09_reconstruction/compose_reconstruction.py
python3 games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/09_reconstruction/compose_reconstruction.py --validate-only
```

Expected: JSON status `pass`, no missing assets, no visible key pixels, a `1320 x 2346` full image, and a `941 x 1672` review image.

- [ ] **Step 5: Commit**

```bash
git add games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4
git commit -m "feat(grove): compose Fairy Hollow v4 workbench scene"
```

### Task 4: Verify real Workbench behavior and visual handoff

**Files:**
- Modify: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/fairy_hollow_elements_v4/README.md` only if verification reveals a real usage correction
- Create: `/tmp/fairy_hollow_v4_scene_workbench.png` as a non-repo verification artifact

**Interfaces:**
- Consumes: Task 3 bundle.
- Produces: focused test evidence, a real Workbench capture, and a visual-approval handoff. No merge occurs before user approval.

- [ ] **Step 1: Run the focused Workbench suite**

```bash
make test-one SUITE=games/grove/tests/grove_scene_workbench_tests
```

Expected: all assertions pass. Record any pre-existing non-failing Godot diagnostics separately.

- [ ] **Step 2: Capture the actual v4 workbench**

```bash
make shot-sw SCENE=fairy_hollow ROOT=/Users/xup/dh/merge/.worktrees/codex-fairy-hollow-original-mock-v4/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1 OUT=/tmp/fairy_hollow_v4_scene_workbench.png
```

Expected: `SHOT saved=/tmp/fairy_hollow_v4_scene_workbench.png err=0`. Inspect the capture for correct foundation, river under bridge, readable clusters, open doors/bridge deck, and foreground framing.

- [ ] **Step 3: Exercise Workbench edit round trip in a disposable copy**

Copy the v4 bundle to a temporary directory, modify one placement's `x/y/w/h`, add one manifest-backed palette asset without `assetId`, and run normal plus `--validate-only` compositor commands. Both must pass and render saved geometry. Then add an unmanifested PNG and confirm validation fails.

- [ ] **Step 4: Final scope checks and commit**

Run `git diff --check`, verify v4-only status is clean after committed changes, and inspect the full/review reconstruction plus the Workbench screenshot. Commit any documentation correction only if Step 1–3 required one.

## Plan Self-Review

- Spec coverage: Tasks 1–3 implement every layer, asset, contact, provenance, Workbench, validation, and visual-approval requirement. Task 4 proves real tool behavior and leaves integration gated on the user’s visual approval.
- Placeholder scan: no implementation task relies on an unspecified file or test command; generation prompts are required to be saved per asset and use the exact named source authorities.
- Type/path consistency: every task uses the one v4 bundle root, `asset_manifest.json`, and `metadata/placements.json`; Task 3 is the only producer of reconstruction reports, and Task 4 consumes those outputs.
