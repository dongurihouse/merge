# Layered Storybook Board and Home UI Plan

> **Implementation type:** concept-asset generation only. No scene, script, or runtime UI file changes.

## Task 1: Record the visual contract

**Files**

- Add: `docs/superpowers/specs/2026-07-20-layered-storybook-board-home-ui-design.md`
- Add: this plan

**Steps**

1. Capture the approved Layered Storybook HUD direction, required Board and Home composition, shared material constraints, and asset destination.
2. Inspect the documents for incomplete wording, conflicting visual requirements, and placeholder markers.
3. Commit the design record before generating assets.

## Task 2: Generate the Board concept

**Files**

- Add: `games/grove/assets/_concepts/screens/cutpaper_storybook_ui_v1/board_cutpaper_storybook_ui_v1.png`
- Add: `games/grove/assets/_concepts/screens/cutpaper_storybook_ui_v1/board_cutpaper_storybook_ui_v1.prompt.txt`

**Steps**

1. Use the current Board concept only as a content/layout reference.
2. Use the Meadow Sky Board reference, the Home camera/detail reference, and the new scene art as material authorities.
3. Generate a 1080 × 1920 Board mock that preserves its recognisable gameplay hierarchy while replacing the plastic control treatment with individual cut-paper layers.
4. Inspect it for paper material, legible safe areas, and absence of glossy pill/card language.

## Task 3: Generate the Home concept

**Files**

- Add: `games/grove/assets/_concepts/screens/cutpaper_storybook_ui_v1/home_cutpaper_storybook_ui_v1.png`
- Add: `games/grove/assets/_concepts/screens/cutpaper_storybook_ui_v1/home_cutpaper_storybook_ui_v1.prompt.txt`

**Steps**

1. Use the current farm home concept as the content/camera reference.
2. Generate a 1080 × 1920 Home mock that preserves the farm as the dominant play field while redrawing only the HUD into the shared layered paper system.
3. Inspect it for a clear farm center, compact edge tabs, and a visible but non-obstructive lower-right customization action.

## Task 4: Package and validate

**Files**

- Add: `games/grove/assets/_concepts/screens/cutpaper_storybook_ui_v1/README.md`

**Steps**

1. Write a concise reference and usage README.
2. Confirm both PNGs are valid 1080 × 1920 RGB/RGBA files and prompts match the delivered imagery.
3. Run `make test-fast` as the project regression check.
4. Commit the asset set, merge it to `main`, and remove the isolated worktree without altering unrelated changes already present in the main checkout.

