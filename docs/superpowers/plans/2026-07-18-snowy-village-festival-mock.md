# Snowy Village Festival Mock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate one non-destructive winter village mock revision that makes the frozen pond the central Christmas festival scene.

**Architecture:** Use the original `snowy_village.png` as the edit target and preserve its portrait size, picture-book texture, camera angle, snowy palette, cabins, pond footprint, snowmen, and lantern rhythm. Apply one focused raster image edit that relocates/removes awkward foreground props and adds the approved festival elements, then save the result as a sibling PNG for review.

**Tech Stack:** Built-in Codex image generation tool, local PNG file inspection, `sips` for dimension verification.

## Global Constraints

- Source: `/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/snowy_village.png`
- Output: `/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/snowy_village_festival_v2.png`
- Preserve exact output dimensions: 941 x 1672.
- Do not overwrite the source mock.
- No UI, labels, signs, logos, border, watermark, or readable text.
- Keep the scene colorful, high-contrast, handcrafted paper-cut picture-book style.
- Avoid photorealism, dark heavy shadows, plastic 3D rendering, awkward clipping, or pasted-on props.

---

### Task 1: Generate Festival Mock Candidate

**Files:**
- Read: `/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/snowy_village.png`
- Create: `/Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/snowy_village_festival_v2.png`

**Interfaces:**
- Consumes: Original snowy village PNG as the edit target.
- Produces: One reviewable PNG sibling named `snowy_village_festival_v2.png`.

- [ ] **Step 1: Inspect the source image**

Use the local image viewer on the source path and confirm these existing landmarks before editing: two cabins on the far shore, large central frozen pond, snowmen on the lower-left bank, lanterns along the right shoreline, oversized lower-left sled, and foreground lower-right gift stall.

- [ ] **Step 2: Generate one edited candidate**

Use the built-in image generation edit workflow with the source image as the edit target and this exact prompt:

```text
Use case: precise-object-edit
Asset type: portrait mobile game scene mock
Input image: Image 1 is the edit target.

Primary request: Regenerate the snowy village mock as a pond-centered Christmas festival scene while preserving the same portrait framing, high 3/4 camera angle, frozen pond footprint, warm cabin lighting, snowy terrain, paper texture, and colorful handcrafted picture-book style.

Scene composition:
- Keep the two cozy log cabins on the far shore, with the small cabin on the upper-left and larger cabin on the upper-right.
- Make the frozen pond the dominant central shape and keep most of the center open and readable.
- Add one prominent decorated Christmas tree on the snowy far shore between the two cabins, grounded naturally in snow, with warm lights and colorful ornaments.
- Move the gift shop stall away from the foreground; place a smaller festive stall on the upper-right shoreline beside or slightly below the larger cabin, scaled below the cabin and integrated into the snowbank.
- Remove the oversized foreground sled from the lower-left snowbank.
- Add two simple translucent ice sculptures on the upper-middle area of the pond, offset left and right, shaped like a festive swan and a reindeer.
- Add a small red wooden sled and a pair of skates resting on the lower area of the frozen pond, small enough that the pond still feels open.
- Keep the snowman pair on the lower-left bank and keep the warm lantern rhythm along the right shoreline.

Style and rendering:
- Colorful high-contrast handcrafted paper-cut picture-book illustration.
- Palette: icy blue pond, warm amber window light, cream snow, evergreen trees, holiday red, small lavender accents.
- Rounded simple forms, visible paper grain, soft cut-paper layering, cozy winter lighting, short soft shadows matched to the existing scene.

Constraints:
- Change only the festival layout and props described above; keep the overall camera, pond shape, snowy village scale, and background structure recognizable.
- Every new prop must sit naturally on snow or ice with matching perspective, contact shadow, texture, and scale.
- No people, no UI, no labels, no signage, no readable text, no logos, no border, no watermark.
- Avoid photorealism, dark heavy shadows, glossy plastic 3D, cluttering the pond center, floating props, clipping, or pasted-on edges.
```

- [ ] **Step 3: Save candidate into the workspace**

Copy the selected generated output from the Codex generated-images location into the exact output path:

```bash
cp <generated_png_path> /Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/snowy_village_festival_v2.png
```

- [ ] **Step 4: Verify dimensions**

Run:

```bash
sips -g pixelWidth -g pixelHeight /Users/xup/dh/merge/.worktrees/codex-ui-redesign-rush-maps-mocks/games/grove/assets/_new/ui_redesign_direction_b/picturebook_scene_mocks_v1/snowy_village_festival_v2.png
```

Expected output includes:

```text
pixelWidth: 941
pixelHeight: 1672
```

- [ ] **Step 5: Visual QA**

Open the generated image and check all acceptance criteria:

```text
1. Stall is on the upper-right shore beside or slightly below the larger cabin, not in the foreground.
2. Pond is still the dominant central shape with open readable ice.
3. Christmas tree is a clear focal point between cabins and does not obscure them.
4. Ice sculptures are translucent, simple, and naturally placed on the pond.
5. Lower pond has only a small sled and skates, not an oversized foreground sled.
6. Snowmen and lantern rhythm remain present.
7. New props share the same scale, perspective, paper texture, and shadow behavior.
8. No readable text, UI, labels, logos, border, or watermark.
```

- [ ] **Step 6: If needed, run one targeted image edit iteration**

Only run this step if Step 5 finds one clear issue. Use the generated candidate as the edit target and make one targeted correction while repeating all invariants from Step 2. Save the corrected result to the same output path and rerun Steps 4 and 5.
