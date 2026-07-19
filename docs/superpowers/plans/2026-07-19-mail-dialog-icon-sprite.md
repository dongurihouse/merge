# Mail Dialog Icon Sprite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate, slice, and validate the nine reusable Mail-dialog icons defined by the approved `3x3` sheet contract.

**Architecture:** Generate one coherent project-native prop pack on flat magenta using the Mail mock, Meadow Sky palette reference, and a geometry-only layout guide. Use the owned sprite processor only for deterministic key removal, frame extraction, centering, transparent export, and QC metadata.

**Tech Stack:** Built-in image generation, `generate2dsprite.py`, Godot asset import, Git.

## Global Constraints

- Follow `docs/design/art-style-guide.md` and its canonical style block verbatim.
- Raw sheet is exactly `3x3` on uniform `#FF00FF` with no visible grid or text.
- Final masters are transparent `512x512` PNGs with no baked shadow.
- Preserve the row-major identity map from the design spec.
- Do not modify or wire runtime UI.

---

### Task 1: Generate the raw Mail icon sheet

**Files:**
- Create: `games/grove/assets/_concepts/dialogs/mail_dialog_v1/icon_sprite_v1/prompt-used.txt`
- Create: `games/grove/assets/_concepts/dialogs/mail_dialog_v1/icon_sprite_v1/references/3x3-layout-guide.png`
- Create: `games/grove/assets/_concepts/dialogs/mail_dialog_v1/icon_sprite_v1/mail_icons_3x3_raw.png`

**Interfaces:**
- Consumes: approved Mail mock, fixed Meadow Sky palette reference, and the geometry-only layout guide.
- Produces: one raw generated `3x3` pack whose cells can be deterministically extracted.

- [x] **Step 1: Create the geometry-only layout guide**

  Run `python3 /Users/xup/.codex/skills/generate2dsprite/scripts/make_layout_guide.py --rows 3 --cols 3 --cell-width 512 --cell-height 512 --output games/grove/assets/_concepts/dialogs/mail_dialog_v1/icon_sprite_v1/references/3x3-layout-guide.png`.

- [x] **Step 2: Generate the raw sheet**

  Use the built-in image generator with `prompt-used.txt` and the three explicitly assigned references.

- [x] **Step 3: Inspect sheet identity and containment**

  Confirm all nine icons appear once in the specified row-major order, with flat magenta gutter on all four sides of every cell.

### Task 2: Process and validate the sprite pack

**Files:**
- Create: `games/grove/assets/_concepts/dialogs/mail_dialog_v1/icon_sprite_v1/mail_icons_3x3_transparent.png`
- Create: `games/grove/assets/_concepts/dialogs/mail_dialog_v1/icon_sprite_v1/frames/*.png`
- Create: `games/grove/assets/_concepts/dialogs/mail_dialog_v1/icon_sprite_v1/pipeline-meta.json`
- Create: `games/grove/assets/_concepts/dialogs/mail_dialog_v1/icon_sprite_v1/manifest.json`
- Create: `games/grove/assets/_concepts/dialogs/mail_dialog_v1/icon_sprite_v1/previews/*.png`
- Create: `games/grove/assets/_concepts/dialogs/mail_dialog_v1/icon_sprite_v1/README.md`

**Interfaces:**
- Consumes: `mail_icons_3x3_raw.png`.
- Produces: transparent `512x512` icon masters and a transparent atlas suitable for later intake.

- [x] **Step 1: Process the raw sheet**

  Run the owned `generate2dsprite.py process` command with `rows=3`, `cols=3`, center alignment, shared scale, all intentional components retained, and safe padding.

- [x] **Step 2: Rename frames by identity**

  Map processor frames `00` through `08` to `mail_envelope_leaf`, `reward_star_coin`, `garden_delivery_crate`, `water_drop`, `acorn`, `ribbon_gift_chest`, `claim_all_envelope`, `close_x`, and `unread_dot`.

- [x] **Step 3: Build review previews and manifest**

  Create dark, light, and warm-cream contact sheets without changing the generated icon pixels; record dimensions and row-major names in `manifest.json`.

- [x] **Step 4: Verify QC and repository health**

  Confirm nine `512x512` RGBA masters, transparent corners, zero cell-edge touches, and no visible magenta fringe; run `make import` and `make test-fast`.

- [x] **Step 5: Commit**

  Run `git add docs/superpowers games/grove/assets/_concepts/dialogs/mail_dialog_v1/icon_sprite_v1 && git commit -m "art: add Mail dialog icon sprite pack"`.
