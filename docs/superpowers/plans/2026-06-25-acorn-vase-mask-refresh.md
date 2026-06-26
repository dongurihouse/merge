# Acorn Vase Mask Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the Purge progress vase to use the new acorn glass art, constrain animated water to the supplied mask, show progress as readable percent text, and remove the old card frame/star count.

**Architecture:** Keep the progress percentage source in `Board._purge_progress()`. Keep all art-specific water clipping, drop sizing, shadow, glow, and sparkle drawing inside `VaseWaterEffect`. The board only lays out the frameless tappable Purge slot and percent label.

**Tech Stack:** Godot 4.6 GDScript, Pillow for source image resizing, existing headless water tests, existing screenshot helper.

## Constraints

- Use `vase_acorn.png` as the visible vase art.
- Use `vase_acorn_mask.png` to derive the water span so water never renders outside the glass section.
- Remove the star/exp count from the Purge vase slot.
- Add readable `%` progress text.
- Remove the old card background/frame while keeping the Purge slot tappable.
- Make the drop 3x larger and make fill gain animation visibly more energetic.

### Task 1: Capture Expected Behavior In Tests

- [x] Add tests for acorn vase and mask assets.
- [x] Add tests for larger droplet and stronger fill energy.
- [x] Add tests that the Purge slot has percent text, no star count, and no old card frame.
- [x] Run the focused water suite to verify the new tests fail before implementation.

### Task 2: Import Acorn Vase Assets

- [x] Copy source acorn vase assets into this worktree's `_originals/ui`.
- [x] Create runtime `games/grove/assets/ui/vase/vase_acorn.png`.
- [x] Resize the source mask to align with the runtime vase canvas as `games/grove/assets/ui/vase/vase_acorn_mask.png`.
- [x] Run Godot import so runtime assets have import metadata.

### Task 3: Implement Masked Vase Rendering

- [x] Load the acorn mask in `VaseWaterEffect`.
- [x] Derive waterline, side spans, and fill body from the mask.
- [x] Draw a soft shadow behind the vase.
- [x] Increase droplet scale and fill/wave intensity.

### Task 4: Refresh Purge Slot Layout

- [x] Remove the old quest-card frame from `_make_purge_card`.
- [x] Remove the star row.
- [x] Add outlined percent text.
- [x] Keep the vase progress, ready glow/sparkles, breathing, and tap behavior.

### Task 5: Verify And Commit

- [x] Run `godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd`.
- [x] Run `make test-fast`.
- [x] Run `make test`.
- [x] Capture and inspect `make shot-grove MODE=gate OUT=/tmp/grove_acorn_vase_gate.png`.
- [x] Commit the completed change.
