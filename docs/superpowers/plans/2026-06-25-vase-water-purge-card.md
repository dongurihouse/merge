# Vase Water Purge Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Use the jar art from `vault_asset.png` as an animated water/vase visual and place it in the board Purge card while preserving the existing Purge button behavior.

**Architecture:** Extract a transparent jar sprite from the `_originals/ui/vault_asset.png` sheet with a deterministic crop/chroma-key helper. Add a focused `VaseWaterEffect` `Control` that draws the jar sprite plus animated water overlay and exposes test helpers. Add a demo scene and then embed the same node into `_make_purge_card()`.

**Tech Stack:** Godot 4.6 GDScript, Pillow for deterministic PNG extraction, existing Godot test runner and quiet screenshot pattern.

## Global Constraints

- Preserve the existing Purge behavior: button tap still plays `button_tap`, persists, sets `HomeScene.decorate_map`, and transitions to `res://engine/scenes/Map.tscn`.
- Do not integrate the old box/tank visual into the board Purge card.
- Use the embedded jar in `games/grove/assets/_originals/ui/vault_asset.png` for this prototype.
- Keep the extracted jar asset transparent and committed under `games/grove/assets/ui/vase/`.
- Add an editor-openable `engine/tools/VaseWaterDemo.tscn`.
- Run the focused vase/water test and `make test-fast`.

---

### Task 1: Extract Jar Asset

**Files:**
- Create: `games/tools/extract_vase_asset.py`
- Create: `games/grove/assets/ui/vase/vase_front.png`

**Interfaces:**
- Produces: transparent PNG at `res://games/grove/assets/ui/vase/vase_front.png`.

- [ ] **Step 1: Create extractor**

Create `games/tools/extract_vase_asset.py` with constants:

```python
SRC = Path("games/grove/assets/_originals/ui/vault_asset.png")
OUT = Path("games/grove/assets/ui/vase/vase_front.png")
CROP = (625, 610, 1068, 1068)
```

The script crops the jar, flood-fills contiguous cyan background from edges using color-distance tolerance, feathers the alpha by one pixel, crops to non-transparent bounds with 8px padding, and writes `OUT`.

- [ ] **Step 2: Run extractor**

```bash
python3 games/tools/extract_vase_asset.py
```

Expected: `games/grove/assets/ui/vase/vase_front.png` exists and has alpha.

### Task 2: Vase Water Node and Demo

**Files:**
- Create: `engine/scripts/ui/vase_water_effect.gd`
- Create: `engine/tools/VaseWaterDemo.tscn`
- Modify: `engine/tests/water_fill_effect_tests.gd`

**Interfaces:**
- Produces: `VaseWaterEffect`, a `Control` with:
  - `const VASE_PATH := "res://games/grove/assets/ui/vase/vase_front.png"`
  - `func set_time_for_test(value: float) -> void`
  - `func trigger_impact_for_test() -> void`
  - `func energy_for_test() -> float`
  - `func water_surface_for_test() -> PackedVector2Array`

- [ ] **Step 1: Extend the focused test first**

Add checks to `engine/tests/water_fill_effect_tests.gd` that preload `vase_water_effect.gd`, instantiate it, verify the texture loads, impact raises energy, `water_surface_for_test()` has multiple points, and `VaseWaterDemo.tscn` loads with a `VaseWaterEffect` child.

- [ ] **Step 2: Run red**

```bash
godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd
```

Expected: failure because `vase_water_effect.gd` and/or `VaseWaterDemo.tscn` do not exist.

- [ ] **Step 3: Implement node and demo**

Create `engine/scripts/ui/vase_water_effect.gd` as a code-drawn `Control`. It loads `VASE_PATH`, draws the jar texture, draws a semi-transparent animated water shape over the jar interior, draws a brighter surface line near the existing waterline, and reuses the droplet/impact cadence from the box demo.

Create `engine/tools/VaseWaterDemo.tscn` with a full-rect background and one centered `VaseWaterEffect`.

- [ ] **Step 4: Run green**

```bash
godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd
```

Expected: all checks pass.

### Task 3: Purge Card Visual Integration

**Files:**
- Modify: `engine/scripts/scenes/board.gd`
- Modify: `engine/tests/water_fill_effect_tests.gd`

**Interfaces:**
- Consumes: `VaseWaterEffect`.
- Produces: `_make_purge_card()` includes a child named `PurgeVaseWater` while preserving the existing Purge button.

- [ ] **Step 1: Write failing structural test**

Add a test helper that instantiates `Board.tscn`, calls `_make_purge_card(360.0)`, and verifies:

- `PurgeVaseWater` exists.
- A `Button` still exists in the returned stand.

- [ ] **Step 2: Run red**

```bash
godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd
```

Expected: failure because `_make_purge_card()` has no `PurgeVaseWater` child yet.

- [ ] **Step 3: Wire board**

Preload `VaseWaterEffect` in `engine/scripts/scenes/board.gd`. In `_make_purge_card()`, add a `VaseWaterEffect` child named `PurgeVaseWater`, centered in the card above the button. Keep the existing star balance and button, but reduce the star row footprint so the vase is the primary visual.

- [ ] **Step 4: Verify**

```bash
godot --headless --path . -s res://engine/tests/water_fill_effect_tests.gd
make test-fast
```

Expected: all checks pass.
