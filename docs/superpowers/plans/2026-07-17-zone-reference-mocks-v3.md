# Distinct Zone Reference Mocks V3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate new Appleblossom Commons and Bellwater Vale reference mocks that retain the approved Meadow Sky Cut-Paper Playground rendering while using unmistakably different map topologies and building silhouettes.

**Architecture:** Treat each mock as an independent reference-only `baked_scene_mode` render. Both consume the approved Meadow Sky board and Farm Home as mandatory style references, but each receives an exclusive layout signature and silhouette roster. A final pairwise gate rejects either image if their topology, landmark placement, or structure grammar converges.

**Tech Stack:** Built-in `image_gen`, local PNG inspection with `view_image`, shell dimension/hash validation, Markdown prompt files.

## Global Constraints

- Logical canvas is exactly `941 x 1672`, portrait.
- Palette is fixed to Meadow Sky: `#6FA9C0`, `#3F6D7D`, `#A8D3B9`, `#8296AF`, `#F6EBDD`, `#243B4B`, `#5F9B6D`, `#D87865`, `#D6A94C`, `#8677A3`; shadow `#294654` at approximately 18–20%.
- Preserve the approved Farm's camera pitch, matte cut-cardstock texture, shallow upper-left shadows, object scale, and low detail budget.
- No UI, labels, characters, animals, white sticker outlines, glossy surfaces, deep paper sculpture, turf islands, or building-specific scenic bases.
- Adjacent zone mocks must differ in at least four of five fields: water topology, path topology, building distribution, hero 3 x 3 grid cell, and negative-space location.
- Maximum one four-post open shelter per zone; at least three of six silhouette classes must be absent from the adjacent zone.

---

### Task 1: Appleblossom Commons Terraced Crescent

**Files:**
- Create: `games/grove/assets/_new/ui_redesign_direction_b/zone_reference_pack_meadow_sky_v3/appleblossom_commons_mock_v3.prompt.txt`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/zone_reference_pack_meadow_sky_v3/appleblossom_commons_mock_v3.png`

**Interfaces:**
- Consumes: approved board `palette_studies_board_v1/palette_a_meadow_sky_board.png`, approved Farm `screen_reference_pack_meadow_sky_v1/home_screen_meadow_sky_v2_working_farm.png`, and the Appleblossom section of the approved art spec.
- Produces: one reference-only PNG and its exact generation prompt for pairwise QA.

- [ ] **Step 1: Write the generation prompt**

Encode the exclusive signature `right-edge stream / open promenade / two unequal edge groups / upper-center tree hero / central quiet lawn`. Require the six thumbnail silhouettes `arc, barrel, tree-ring, parasol, folded canopy, drum`, zero repeated coral gable roofs, and at least 45% quiet lawn, path, orchard floor, or water.

- [ ] **Step 2: Generate from the mandatory visual references**

Use built-in `image_gen` with the approved board and Farm paths as `referenced_image_paths`. Save the selected output non-destructively as `appleblossom_commons_mock_v3.png`.

- [ ] **Step 3: Verify the Appleblossom output**

Run:

```bash
file games/grove/assets/_new/ui_redesign_direction_b/zone_reference_pack_meadow_sky_v3/appleblossom_commons_mock_v3.png
```

Expected: `PNG image data, 941 x 1672`. Inspect at original detail and reject if the central lawn is filled, the promenade closes into a loop, structures scatter evenly, or more than one structure reads as a conventional coral-roof cottage.

### Task 2: Bellwater Vale Side-Loaded Basin

**Files:**
- Create: `games/grove/assets/_new/ui_redesign_direction_b/zone_reference_pack_meadow_sky_v3/bellwater_vale_mock_v3.prompt.txt`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/zone_reference_pack_meadow_sky_v3/bellwater_vale_mock_v3.png`

**Interfaces:**
- Consumes: approved board `palette_studies_board_v1/palette_a_meadow_sky_board.png`, approved Farm `screen_reference_pack_meadow_sky_v1/home_screen_meadow_sky_v2_working_farm.png`, and the Bellwater section of the approved art spec.
- Produces: one reference-only PNG and its exact generation prompt for pairwise QA.

- [ ] **Step 1: Write the generation prompt**

Encode the exclusive signature `right-edge cropped basin / short diagonal spillway / bent dead-end path / two outer clusters / quiet center`. Require the six thumbnail silhouettes `wedge-and-wheel, open frame, long chevron, diamond canopy, flat-cap square, low arch-and-tongue`, only one coral roof, and at least 50% uninterrupted meadow, path, or water.

- [ ] **Step 2: Generate from the mandatory visual references**

Use built-in `image_gen` with the approved board and Farm paths as `referenced_image_paths`. Do not use Appleblossom as a composition reference. Save the selected output non-destructively as `bellwater_vale_mock_v3.png`.

- [ ] **Step 3: Verify the Bellwater output**

Run:

```bash
file games/grove/assets/_new/ui_redesign_direction_b/zone_reference_pack_meadow_sky_v3/bellwater_vale_mock_v3.png
```

Expected: `PNG image data, 941 x 1672`. Inspect at original detail and reject if water becomes a full-height S river, the path loops or traces the shoreline, structures scatter evenly, or multiple structures become coral-roof cottages.

### Task 3: Pairwise Anti-Convergence Review

**Files:**
- Create: `games/grove/assets/_new/ui_redesign_direction_b/zone_reference_pack_meadow_sky_v3/README.md`
- Modify only if a targeted correction is required: the rejected zone's v3 prompt and PNG.

**Interfaces:**
- Consumes: both v3 PNGs and prompts from Tasks 1 and 2.
- Produces: an accepted pair with recorded layout signatures and validation evidence.

- [ ] **Step 1: Inspect both images side by side**

Record each image's five-field signature: water topology, path topology, building distribution, hero 3 x 3 cell, and negative-space 3 x 3 cell.

- [ ] **Step 2: Apply the acceptance gate**

Require at least four of five signature fields to differ, including path topology and building distribution. Require different hero cells with Manhattan distance at least two, no repeated central-pavilion/lower-right-cottage pair, no more than one open shelter per zone, and no more than three shared silhouette classes.

- [ ] **Step 3: Perform no more than two targeted correction calls per failed zone**

Change only the failed structural dimension while repeating all approved style invariants. Preserve the accepted zone unchanged. A second correction is allowed only when original-detail review proves that the first correction did not alter the failed structural dimension; never use it to explore a new composition.

If the final whole-branch review identifies a new binding topology or silhouette defect that task-level review missed, it may authorize one final precise edit per affected zone. The final edit must address only the cited defect, preserve accepted invariants, and be re-reviewed against the complete pair.

- [ ] **Step 4: Save validation metadata**

Write `README.md` with the exact filenames, five-field signatures, silhouette rosters, reference paths, and accepted/rejected status. Run:

```bash
file games/grove/assets/_new/ui_redesign_direction_b/zone_reference_pack_meadow_sky_v3/*.png
shasum -a 256 games/grove/assets/_new/ui_redesign_direction_b/zone_reference_pack_meadow_sky_v3/*.png
```

Expected: two RGB PNGs at `941 x 1672` with stable SHA-256 values recorded in command output.

- [ ] **Step 5: Commit accepted artifacts**

```bash
git add docs/superpowers/plans/2026-07-17-zone-reference-mocks-v3.md games/grove/assets/_new/ui_redesign_direction_b/zone_reference_pack_meadow_sky_v3
git commit -m "art: regenerate distinct Meadow Sky zone mocks"
```
