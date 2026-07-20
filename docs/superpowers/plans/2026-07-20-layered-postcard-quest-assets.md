# Layered Postcard Quest Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce five clean transparent sprites, two runtime derivatives, and a documented layout contract for the approved Layered Postcard quest card.

**Architecture:** Generate each identity-sensitive portrait as an independent precise edit and generate the request note and reward tag as isolated UI props. Process every raw magenta source deterministically, then assemble a review-only 3 x 2 sprite sheet and record runtime placement metadata without changing game code.

**Tech Stack:** Built-in image generation, `generate2dsprite`, chroma-key cleanup, Pillow validation/assembly, PNG, JSON, Markdown, Git worktree workflow.

## Global Constraints

- Follow `docs/design/art-style-guide.md` and include its canonical STYLE BLOCK verbatim in every generation prompt.
- Generate raw sprites on flat `#FF00FF`, except use flat `#00FF00` for the
  legitimate-purple `giver_m2_3` portrait. Add no cast shadow, floor, text,
  label, watermark, border, or UI scene.
- Preserve the three resident identities; remove only the held acorn cluster,
  the sandcastle resident's shovel and shield, or the purple resident's jar.
- The note and tag are empty chrome; live items, coin, reward text, readiness, tinting, rotation, and shadows are not baked into them.
- No runtime code or existing production asset may change.
- Every final alpha/chroma acceptance count must be zero.

---

### Task 1: Generate three prop-free resident portraits

**Files:**
- Create: `games/grove/assets/_concepts/screens/quest_card_variations_v1/layered_postcard_assets_v1/raw/giver_m2_1_clean_raw.png`
- Create: `games/grove/assets/_concepts/screens/quest_card_variations_v1/layered_postcard_assets_v1/raw/giver_m2_2_clean_raw.png`
- Create: `games/grove/assets/_concepts/screens/quest_card_variations_v1/layered_postcard_assets_v1/raw/giver_m2_3_clean_raw.png`
- Create: matching files under `prompts/`.

**Interfaces:**
- Consumes: current `giver_m2_1.png`, `giver_m2_2.png`, and `giver_m2_3.png` identity references.
- Produces: three isolated flat-key portrait sources with complete rounded bases.

- [ ] Generate each portrait as a separate built-in image edit, preserving identity and changing only the specified held prop.
- [ ] Inspect each raw source for complete hands, costume, rounded base, and generous magenta gutter.
- [ ] Save each accepted raw PNG and exact prompt at the declared paths.

### Task 2: Generate empty Layered Postcard chrome

**Files:**
- Create: `games/grove/assets/_concepts/screens/quest_card_variations_v1/layered_postcard_assets_v1/raw/quest_request_note_raw.png`
- Create: `games/grove/assets/_concepts/screens/quest_card_variations_v1/layered_postcard_assets_v1/raw/quest_reward_seed_tag_raw.png`
- Create: matching files under `prompts/`.

**Interfaces:**
- Consumes: the Layered Postcard concept plus Meadow Sky palette/material references.
- Produces: one empty note and one empty tag on independent magenta-keyed canvases.

- [ ] Generate the request note with a deckled cream perimeter and no content or shadow.
- [ ] Generate the seed tag with gold edge, transparent hole, attached loop, and no content or shadow.
- [ ] Inspect both sources for correct silhouette, empty safe area, and full containment.

### Task 3: Process and validate production sprites

**Files:**
- Create: seven PNGs under `layered_postcard_assets_v1/final/`.

**Interfaces:**
- Consumes: the five accepted raw flat-key sources.
- Produces: three 256 x 256 portraits, a 512 x 576 note master and 256 x 288 derivative, and a 512 x 512 tag master and 256 x 256 derivative.

- [ ] Remove magenta with the installed chroma-key helper using soft matte, despill, and one-pixel edge contraction.
- [ ] Center each subject on its declared transparent canvas without stretching.
- [ ] Punch the tag hole through alpha and zero RGB outside alpha.
- [ ] Measure visible magenta fringe, canvas-edge alpha, enclosed pockets, and RGB outside alpha; each count must equal zero.
- [ ] Inspect all sprites over dark, light, and warm-cream review surfaces.

### Task 4: Assemble and document the bundle

**Files:**
- Create: `games/grove/assets/_concepts/screens/quest_card_variations_v1/layered_postcard_assets_v1/layered_postcard_assets_review_3x2.png`
- Create: `games/grove/assets/_concepts/screens/quest_card_variations_v1/layered_postcard_assets_v1/layout.json`
- Create: `games/grove/assets/_concepts/screens/quest_card_variations_v1/layered_postcard_assets_v1/manifest.json`
- Create: `games/grove/assets/_concepts/screens/quest_card_variations_v1/layered_postcard_assets_v1/README.md`

**Interfaces:**
- Consumes: all final sprites and the approved logical layout.
- Produces: one review sheet and the complete handoff contract.

- [ ] Assemble a transparent 1536 x 1024 review sheet with 512 x 512 cells, five assets in row-major order, one empty final cell, and no boundary contacts.
- [ ] Record dimensions, filenames, reuse dependencies, logical rectangles, pivots, safe areas, rotations, and layer order in JSON.
- [ ] Document that the bundle is concept-ready but not runtime-integrated.
- [ ] Run PNG integrity/QC checks and `make test-fast`.
- [ ] Commit the complete bundle and documentation.
