# Board Quest Card Variations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce three high-resolution, directly comparable Meadow Sky quest-card row mockups for the Grove board.

**Architecture:** Generate each approved composition as an independent image task using the same screenshot and palette/material references. The coordinator reviews each output against the shared content contract, stores the accepted PNG and exact prompt, and adds a compact comparison README. No runtime code changes are included.

**Tech Stack:** Built-in image generation, PNG raster assets, Markdown documentation, Git worktree workflow.

## Global Constraints

- Follow `docs/design/art-style-guide.md` and its canonical STYLE BLOCK.
- Use the current board screenshot as the content and scale reference.
- Every variation shows the same four residents, asks, and rewards.
- Save concept assets only; do not modify runtime UI code.
- Preserve visible text exactly as `+5`, `+24`, `+34`, and `+12`.

---

### Task 1: Generate Story Bubble

**Files:**
- Create: `games/grove/assets/_concepts/screens/quest_card_variations_v1/quest_cards_a_story_bubble.png`
- Create: `games/grove/assets/_concepts/screens/quest_card_variations_v1/quest_cards_a_story_bubble.prompt.txt`

**Interfaces:**
- Consumes: approved Variation A and the shared comparison contract.
- Produces: one four-card row PNG and its exact generation prompt.

- [ ] **Step 1: Generate the mockup**

Use built-in image generation with the board screenshot, Meadow Sky palette
reference, and the Variation A composition from the design spec.

- [ ] **Step 2: Verify the composition**

Inspect the PNG and confirm four complete cards, portrait/bubble/reward
hierarchy, consistent content, and no surrounding board UI.

- [ ] **Step 3: Save the output and prompt**

Copy the generated PNG to the exact destination path and store the final prompt
verbatim in the sibling prompt file.

### Task 2: Generate Split Ticket

**Files:**
- Create: `games/grove/assets/_concepts/screens/quest_card_variations_v1/quest_cards_b_split_ticket.png`
- Create: `games/grove/assets/_concepts/screens/quest_card_variations_v1/quest_cards_b_split_ticket.prompt.txt`

**Interfaces:**
- Consumes: approved Variation B and the shared comparison contract.
- Produces: one four-card row PNG and its exact generation prompt.

- [ ] **Step 1: Generate the mockup**

Use built-in image generation with the board screenshot, Meadow Sky palette
reference, and the Variation B composition from the design spec.

- [ ] **Step 2: Verify the composition**

Inspect the PNG and confirm four complete cards, two connected fields, hanging
reward tabs, consistent content, and no speech bubbles.

- [ ] **Step 3: Save the output and prompt**

Copy the generated PNG to the exact destination path and store the final prompt
verbatim in the sibling prompt file.

### Task 3: Generate Layered Postcard

**Files:**
- Create: `games/grove/assets/_concepts/screens/quest_card_variations_v1/quest_cards_c_layered_postcard.png`
- Create: `games/grove/assets/_concepts/screens/quest_card_variations_v1/quest_cards_c_layered_postcard.prompt.txt`

**Interfaces:**
- Consumes: approved Variation C and the shared comparison contract.
- Produces: one four-card row PNG and its exact generation prompt.

- [ ] **Step 1: Generate the mockup**

Use built-in image generation with the board screenshot, Meadow Sky palette
reference, and the Variation C composition from the design spec.

- [ ] **Step 2: Verify the composition**

Inspect the PNG and confirm four complete cards, overlapping residents,
separate cream notes, seed-shaped reward tags, consistent content, and no split
fields or speech bubbles.

- [ ] **Step 3: Save the output and prompt**

Copy the generated PNG to the exact destination path and store the final prompt
verbatim in the sibling prompt file.

### Task 4: Package and verify the comparison

**Files:**
- Create: `games/grove/assets/_concepts/screens/quest_card_variations_v1/README.md`

**Interfaces:**
- Consumes: all three accepted PNG/prompt pairs.
- Produces: a reviewer-facing index and verified concept bundle.

- [ ] **Step 1: Compare the three images**

Confirm the same content roster is present and that the three layout structures
remain visibly different at thumbnail size.

- [ ] **Step 2: Validate raster files**

Run a Pillow validation that opens all three PNGs, asserts RGB/RGBA mode, and
asserts each dimension is at least 1024 pixels on its long edge.

- [ ] **Step 3: Write the comparison README**

Document each direction, its information hierarchy, its main trade-off, and
the PNG/prompt filenames.

- [ ] **Step 4: Run the repository check**

Run `make test-fast`. Expected: all suites pass with zero failures.

- [ ] **Step 5: Commit the concept bundle**

Run:

```bash
git add docs/superpowers/specs/2026-07-19-board-quest-card-variations-design.md \
  docs/superpowers/plans/2026-07-19-board-quest-card-variations.md \
  games/grove/assets/_concepts/screens/quest_card_variations_v1
git commit -m "art: add board quest card variations"
```
