# Meadow Seedling Courier Giver Tiers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce and validate the approved 12-tier Meadow Seedling Courier quest-giver source sheet.

**Architecture:** A single generation prompt encodes the immutable sprite-sheet contract and all twelve costume states. The resulting raw source remains under `_new` for art review; it is not connected to runtime portrait selection in this task.

**Tech Stack:** Built-in image generation, PNG inspection, ImageMagick/file metadata checks, and the existing Grove asset tree.

## Global Constraints

- Canvas is exactly `1024x1536` PNG, 3 columns × 4 rows, row-major.
- Background is exact flat `#FF00FF`; the sheet has no baked shadow or detached effects.
- Every character is a complete, consistent-weight 256px-ready bust with a rounded authored base and visible key gutter on all four sides.
- Use `docs/design/art-style-guide.md` as the current art source of truth.
- Do not change runtime code or overwrite the existing 5×5 giver pool.

---

### Task 1: Generate the Meadow Seedling Courier source sheet

**Files:**
- Create: `games/grove/assets/_new/quest_givers_meadow_tiers_v1/quest_givers_meadow_seedling_courier_3x4_v1_raw.png`
- Create: `games/grove/assets/_new/quest_givers_meadow_tiers_v1/quest_givers_meadow_seedling_courier_3x4_v1.prompt.txt`

**Interfaces:**
- Consumes: the approved tier list in `docs/superpowers/specs/2026-07-20-meadow-seedling-courier-giver-tiers-design.md`.
- Produces: a raw, keyable, generation source for a later character-sheet slicing pass.

- [ ] **Step 1: Save the exact generation prompt**

Write the approved Meadow Sky style block, the 3×4 contract, and the twelve
row-major stages verbatim into the prompt companion file.

- [ ] **Step 2: Generate one raw source sheet**

Use the built-in image generator once with the saved prompt. Require a uniform
`#FF00FF` backdrop, cell-safe complete busts, no text, and no shadows.

- [ ] **Step 3: Place the generated PNG non-destructively**

Copy the generated output to the exact `_new/quest_givers_meadow_tiers_v1/`
path without touching `assets/characters/giver_*.png`.

### Task 2: Verify source-sheet acceptance

**Files:**
- Test: `games/grove/assets/_new/quest_givers_meadow_tiers_v1/quest_givers_meadow_seedling_courier_3x4_v1_raw.png`

**Interfaces:**
- Consumes: the raw source from Task 1.
- Produces: a reviewed source sheet ready for the user to approve or reject.

- [ ] **Step 1: Verify PNG metadata**

Run `file` and `identify` (when available) and require `1024 x 1536` RGBA PNG.

- [ ] **Step 2: Inspect the full sheet and every cell**

Render the sheet for review. Confirm all twelve stages are present, cell gutters
are visible, every base is rounded and complete, and tier 10–12 are distinct
without becoming larger or cluttered.

- [ ] **Step 3: Verify the key-color field and boundaries**

Use ImageMagick or a short read-only pixel inspection to confirm the corners are
`#FF00FF` and no non-key subject pixel lies on x=341/682 or y=384/768/1152.

- [ ] **Step 4: Commit**

Run `git add` for the raw PNG, prompt, design, and plan, then commit with
`art: add meadow seedling courier giver tiers`.
