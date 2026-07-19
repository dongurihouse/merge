# Cherry Blossom Garden v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a new layered Cherry Blossom Garden v2 bundle that restores paper grain, environmental depth, raked zen sand, a recessed pond, dense garden dressing, and corrected pavilion and lantern composition.

**Architecture:** Preserve v1 and create a sibling v2 bundle. Three independent asset streams produce environment depth, pond/dressing assets, and hero-prop revisions; root integration creates the placement manifest, deterministic reconstruction, and cross-layer QA.

**Tech Stack:** built-in `image_gen`, Pillow postprocessing, installed chroma-key cleanup helper, `generate2dsprite.py`, JSON placement metadata, PNG RGB/RGBA assets.

## Global Constraints

- Canvas is exactly 1320 x 2346, preserving the 941 x 1672 reference ratio.
- Use `scene_mode + layered_raster + separate_props + foreground_occluders`.
- Save every accepted prompt and untouched generated raw beside its asset.
- Transparent working images use exact flat `#FF00FF`; accepted runtime finals contain zero visible magenta.
- Every major prop must retain visible fibrous paper grain at 941 x 1672 review scale.
- Do not overwrite any v1 asset or the original mock.
- Do not bake ground islands, broad bottom shadows, UI, labels, borders, or text into props.
- Use one lantern master twice with identical display dimensions, flanking the torii approach.

---

### Task 1: Environment foundation and depth plates

**Files:**
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/01_backdrop/*`

**Produces:** opaque foundation; far/mid/near RGBA mountains; rear/near RGBA horizon vegetation; exact prompts and raws.

- [ ] Generate an opaque foundation with pale paper sky and continuous warm-cream sand carrying broad readable rake marks.
- [ ] Generate three separate full-width mountain plates with pale, muted, and darker distance shades.
- [ ] Generate two large full-width horizon vegetation plates that cover the hard ground/sky seam without hiding more than 80 percent of the mountains.
- [ ] Chroma-clean all transparent plates and verify transparent corners, RGBA mode, and zero visible magenta.
- [ ] Produce `metadata/environment_report.json` with dimensions, modes, alpha bboxes, and visible-magenta counts.

### Task 2: Recessed pond and compact dressing packs

**Files:**
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/02_terrain/*`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/05_dressing/*`

**Produces:** recessed koi pond; 3 x 3 vegetation pack; 3 x 3 rock pack; extracted RGBA sprites; prop-pack manifests.

- [ ] Generate one pond terrain asset with irregular planted stones, moss breaks, inward stone overlap, and a narrow inner depth edge.
- [ ] Generate a 3 x 3 vegetation and flower pack using exact flat magenta and generous cell margins.
- [ ] Process and extract nine vegetation sprites with `generate2dsprite.py`; reject edge-touching cells.
- [ ] Generate and process a 3 x 3 rock-cluster pack with nine distinct compact silhouettes.
- [ ] Verify the pond and every extracted sprite are RGBA with transparent corners and zero visible magenta.

### Task 3: Paper material and hero-prop revisions

**Files:**
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/00_style/*`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/03_structures/*`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/04_garden_items/*`

**Produces:** paper-grain master; furnished pavilion; reusable matched lantern master; texture-preserved bridge, torii, bonsai, and three sakura masters.

- [ ] Generate a neutral high-resolution fibrous paper master as the material reference.
- [ ] Regenerate the pavilion with the exact tea table, teapot, cups, and cushion inventory.
- [ ] Generate one stone lantern master suitable for two identical-scale placements.
- [ ] Copy the accepted v1 bridge, torii, bonsai, and sakura masters into v2 and apply the generated paper material inside each alpha mask without altering silhouettes.
- [ ] Verify paper tooth remains visible after rendering each hero prop at its planned phone-scale size.

### Task 4: Integration, reconstruction, and verification

**Files:**
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/metadata/placements.json`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/metadata/asset_manifest.json`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/09_reconstruction/cherry_blossom_garden_reconstruction_v2.png`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/cherry_blossom_garden_elements_v2/README.md`

**Consumes:** all accepted assets from Tasks 1-3.

- [ ] Place environment layers behind all props with unique z values.
- [ ] Place the three sakura trees 25-30 percent larger than v1.
- [ ] Place approximately 14-18 vegetation sprites and 7-10 rock sprites around boundaries and object bases.
- [ ] Place two instances of the lantern master with identical dimensions, flanking the torii approach.
- [ ] Compose the 1320 x 2346 reconstruction and a 941 x 1672 review render.
- [ ] Visually inspect paper grain, mountain separation, zen rake marks, pond depth, pavilion contents, edge blending, and lantern placement.
- [ ] Run manifest validation for file existence, JSON parsing, modes, dimensions, transparent corners, unique z values, and zero visible magenta.

