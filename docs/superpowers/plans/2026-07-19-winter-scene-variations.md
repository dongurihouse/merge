# Winter Scene Variations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate three non-destructive portrait winter-scene mocks that preserve the Grove cut-paper grain language while progressively increasing creative freedom.

**Architecture:** Use `baked_scene_mode` with `baked_raster`, no runtime objects, no collision, and raw project PNG output because the user explicitly requested reference-only mocks. Run three independent built-in image-generation calls with the same three role-labeled references and progressively looser content constraints, then normalize, inspect, and save each accepted PNG beside its exact prompt.

**Tech Stack:** Built-in Codex image generation, local image viewer, `sips`, Git.

## Global Constraints

- Work only in `/Users/xup/dh/merge/.worktrees/codex-winter-scene-variations` on branch `codex/winter-scene-variations`.
- Use `games/grove/assets/_concepts/zones/snowy_village_v2.png` only as winter mood and scene-family reference.
- Use `games/grove/assets/_new/ui_redesign_direction_b/palette_studies_board_v1/palette_a_meadow_sky_board.png` only as palette and material authority.
- Use `games/grove/assets/_new/ui_redesign_direction_b/screen_reference_pack_meadow_sky_v1/home_screen_meadow_sky_v2_working_farm.png` only as camera, common scale, shallow shadow, and detail-budget authority.
- Generate one asset per built-in image-generation call; do not use CLI batch mode.
- Save every accepted asset beside its exact `.prompt.txt` file.
- Final PNG dimensions must be exactly 941 x 1672.
- Do not overwrite `snowy_village_v2.png` or any existing mock.
- No text, labels, numerals, UI, logo, border, or watermark.

---

### Task 1: Author the Three Generation Prompts

**Files:**
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/winter_scene_variations_v1/winter_scene_familiar_v1.prompt.txt`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/winter_scene_variations_v1/winter_scene_gathering_v1.prompt.txt`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/winter_scene_variations_v1/winter_scene_surprise_v1.prompt.txt`

**Interfaces:**
- Consumes: The approved design and canonical style block in `docs/design/art-style-guide.md`.
- Produces: Three complete prompts used verbatim by Tasks 2-4.

- [ ] **Step 1: Create the output directory and prompt files**

Write each prompt with the same role-labeled references, exact canonical style block, canvas/camera/lighting contract, and avoid list. Change only the creative-freedom section between files.

- [ ] **Step 2: Check prompt completeness**

Run:

```bash
for prompt in games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/winter_scene_variations_v1/*.prompt.txt; do
  test -s "$prompt"
  for pattern in "Image 1:" "Image 2:" "Image 3:" "941 x 1672" "Meadow Sky + Cut-Paper Playground style" "No text"; do
    rg -F -q "$pattern" "$prompt"
  done
done
```

Expected: all prompt files are non-empty and every required phrase check exits zero.

---

### Task 2: Generate Familiar Village Remix

**Files:**
- Read: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/winter_scene_variations_v1/winter_scene_familiar_v1.prompt.txt`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/winter_scene_variations_v1/winter_scene_familiar_v1.png`

**Interfaces:**
- Consumes: Three visible role-labeled reference images and the familiar prompt.
- Produces: One baked reference-only scene mock.

- [ ] **Step 1: Make all three references visible**

Open the winter source, palette authority, and camera authority with the local image viewer immediately before generation.

- [ ] **Step 2: Generate one candidate**

Call built-in image generation with the three reference paths and the prompt file verbatim. This is generation with references, not an edit.

- [ ] **Step 3: Persist and normalize**

Copy the generated PNG to the exact output path. If dimensions differ, normalize non-destructively to 941 x 1672 while preserving the portrait composition.

- [ ] **Step 4: Inspect and reject obvious failures**

Open the saved PNG and reject it if it lacks cut-paper grain, loses the elevated camera, reproduces the source inventory mechanically, contains malformed structures, floating props, clipping, text, UI, or watermark.

---

### Task 3: Generate Reimagined Winter Gathering

**Files:**
- Read: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/winter_scene_variations_v1/winter_scene_gathering_v1.prompt.txt`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/winter_scene_variations_v1/winter_scene_gathering_v1.png`

**Interfaces:**
- Consumes: Three visible role-labeled reference images and the gathering prompt.
- Produces: One baked reference-only scene mock with more content freedom than Task 2.

- [ ] **Step 1: Make all three references visible**

Open the same three references immediately before generation.

- [ ] **Step 2: Generate one candidate**

Call built-in image generation with the three reference paths and the prompt file verbatim. Allow the model to choose the gathering place, terrain, landmarks, circulation, and seasonal activity.

- [ ] **Step 3: Persist, normalize, and inspect**

Copy to the exact output path, normalize to 941 x 1672 if required, and reject the same objective failure classes as Task 2.

---

### Task 4: Generate Storybook Winter Surprise

**Files:**
- Read: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/winter_scene_variations_v1/winter_scene_surprise_v1.prompt.txt`
- Create: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/winter_scene_variations_v1/winter_scene_surprise_v1.png`

**Interfaces:**
- Consumes: Three visible role-labeled reference images and the surprise prompt.
- Produces: One baked reference-only scene mock with broad content freedom.

- [ ] **Step 1: Make all three references visible**

Open the same three references immediately before generation.

- [ ] **Step 2: Generate one candidate**

Call built-in image generation with the three reference paths and the prompt file verbatim. Preserve only winter readability, portrait scene language, palette/material, camera/detail budget, and a believable spatial story.

- [ ] **Step 3: Persist, normalize, and inspect**

Copy to the exact output path, normalize to 941 x 1672 if required, and reject the same objective failure classes as Task 2.

---

### Task 5: Verify and Commit the Mock Set

**Files:**
- Verify: `games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/winter_scene_variations_v1/`

**Interfaces:**
- Consumes: Three PNGs and three prompts.
- Produces: A clean committed review set.

- [ ] **Step 1: Verify files and dimensions**

Run:

```bash
test "$(find games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/winter_scene_variations_v1 -name '*.png' | wc -l | tr -d ' ')" = "3"
test "$(find games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/winter_scene_variations_v1 -name '*.prompt.txt' | wc -l | tr -d ' ')" = "3"
sips -g pixelWidth -g pixelHeight games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/winter_scene_variations_v1/*.png
```

Expected: three PNGs, three prompts, and every PNG reports 941 x 1672.

- [ ] **Step 2: Run repository verification**

Run:

```bash
make test-fast
git diff --check
```

Expected: 1,346 tests pass, zero failures, and no whitespace errors.

- [ ] **Step 3: Commit**

Run:

```bash
git add docs/superpowers/plans/2026-07-19-winter-scene-variations.md games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/winter_scene_variations_v1
git commit -m "art: add winter scene variations"
```
