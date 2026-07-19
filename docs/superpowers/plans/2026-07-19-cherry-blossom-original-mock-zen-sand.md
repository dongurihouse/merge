# Cherry Blossom Original Mock Zen Sand Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace only the canonical Cherry Blossom Garden original mock's meadow ground with the approved raked zen-sand treatment.

**Architecture:** Use a two-reference built-in image edit: the original mock is the edit target and `cherry_blossom_garden.jpg` is a material-only reference. Inspect the generated candidate before mechanically normalizing it to the canonical 930 x 1691 canvas and replacing the project asset.

**Tech Stack:** Built-in image generation, PNG/JPEG source assets, macOS `sips`, Git.

## Global Constraints

- Preserve the original composition, geometry, objects, object scale, palette, lighting, and paper-cut rendering.
- Change only the continuous pale meadow and cream walkable ground to pale ivory raked zen sand.
- Keep the historical v4 decomposition reference copy unchanged.
- Final canonical PNG must be opaque and exactly 930 x 1691 pixels.

---

### Task 1: Generate and review the texture-only edit

**Files:**
- Modify: `games/grove/assets/_concepts/zones/cherry_blossom_garden_original_mock_v1.png`
- Modify: `games/grove/assets/_concepts/zones/cherry_blossom_garden_original_mock_v1.prompt.txt`

**Interfaces:**
- Consumes: the canonical original mock and `games/grove/assets/_concepts/zones/cherry_blossom_garden.jpg`
- Produces: one accepted 930 x 1691 opaque PNG and its exact prompt sidecar

- [x] **Step 1: Make both source images visible and verify their roles**

Inspect Image 1 as the edit target and Image 2 as the material-only reference. Confirm Image 1 is 930 x 1691 and Image 2 is 941 x 1672.

- [x] **Step 2: Generate one texture-only candidate**

Use the built-in image editor with both local references and the exact structured prompt saved to the sidecar. Repeat every locked invariant in the prompt.

- [x] **Step 3: Inspect the candidate at full resolution**

Reject the candidate if any object moves, disappears, changes scale, or is redesigned; if pond/path geometry drifts; or if rake marks cross occluding objects.

- [x] **Step 4: Normalize the accepted candidate**

Mechanically resize/crop only if necessary so the PNG is exactly 930 x 1691 without changing its portrait framing.

- [x] **Step 5: Save the accepted asset and exact prompt**

Replace only the canonical concept PNG and prompt sidecar. Do not modify the historical v4 reference copy.

- [x] **Step 6: Verify artifact properties**

Run:

```bash
sips -g pixelWidth -g pixelHeight -g format games/grove/assets/_concepts/zones/cherry_blossom_garden_original_mock_v1.png
git status --short
git diff --check
```

Expected: `pixelWidth: 930`, `pixelHeight: 1691`, `format: png`; only the canonical PNG, its prompt, and task documentation are changed; `git diff --check` exits 0.

- [x] **Step 7: Review at phone scale**

Create a temporary 465 x 846 review copy, visually confirm sand readability and object preservation, then discard the temporary review artifact.

- [x] **Step 8: Commit**

```bash
git add docs/superpowers/specs/2026-07-19-cherry-blossom-original-mock-zen-sand-design.md \
  docs/superpowers/plans/2026-07-19-cherry-blossom-original-mock-zen-sand.md \
  games/grove/assets/_concepts/zones/cherry_blossom_garden_original_mock_v1.png \
  games/grove/assets/_concepts/zones/cherry_blossom_garden_original_mock_v1.prompt.txt
git commit -m "art: give cherry original mock zen sand"
```
