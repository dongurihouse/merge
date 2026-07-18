# Home Grounding Kit Checkpoint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the pasted-on house grounding with a shadow-free building, a road-free base, separate road stones, and sparse grass-edge sprites, then show one in-engine checkpoint.

**Architecture:** Edit the base so it contains terrain but no stone road. The manifest composes one house sprite with its architectural steps intact, reusable individual road-stone sprites, and four independent grass clusters using center-bottom anchors and explicit z-order. No sprite may contain a continuous ground pad.

**Tech Stack:** Built-in image generation, `generate2dsprite.py`, Godot 4.6, JSON manifest, GDScript contract test.

## Global Constraints

- Preserve the approved house identity, palette, perspective, roof, walls, door, windows, porch, and structural foundation.
- The house contains no exterior cast/contact shadow; its attached architectural front stairs remain unchanged.
- Grass sprites contain leaves/blades only: no soil, turf strip, rocks, shadow, or continuous base.
- The base background contains no baked tan road stones.
- Road stones are individual transparent props that can be placed into straight or curved routes.
- Keep all other buildings absent from the checkpoint.

---

### Task 1: Revise the house and base

**Files:**
- Create: `games/grove/assets/_new/home_layered_cutpaper/raw/fh_hearth_shadowless_v3_raw.png`
- Create: `games/grove/assets/map/home_layered_cutpaper/props/fh_hearth_shadowless_v3.png`
- Create: `games/grove/assets/_new/home_layered_cutpaper/raw/home_base_no_road_raw.png`
- Create: `games/grove/assets/map/home_layered_cutpaper/home_base_no_road.png`

- [x] Edit the approved raw house with built-in image generation, changing only the removal of its exterior dark shadow; keep the attached front steps.
- [x] Edit the approved base with built-in image generation, removing every tan road stone and filling those areas with matching grass while preserving all other scenery.
- [x] Normalize the edited base to exactly `941x1672` and chroma-clean the house.

### Task 2: Generate separate grounding sprites

**Files:**
- Create: `games/grove/assets/_new/home_layered_cutpaper/raw/fh_grass_edge_patterns_2x2_raw.png`
- Create: `games/grove/assets/_new/home_layered_cutpaper/raw/fh_road_stones_2x3_raw_v2.png`
- Create: `games/grove/assets/map/home_layered_cutpaper/props/fh_grass_edge_1.png` through `fh_grass_edge_4.png`
- Create: `games/grove/assets/map/home_layered_cutpaper/props/fh_road_stone_1.png` through `fh_road_stone_6.png`

- [x] Generate a 2x2 pack of four compact, connected grass clusters against flat `#FF00FF`.
- [x] Generate six varied compact road stones in a 2x3 pack against flat `#FF00FF`.
- [x] Process with `generate2dsprite.py`; require no edge-touch frames and exactly one meaningful component per output.

### Task 3: Compose and verify the checkpoint

**Files:**
- Modify: `games/grove/assets/map/home_layered_cutpaper/home_props.json`
- Modify: `games/grove/tests/grove_home_layer_workbench_tests.gd`
- Create: `games/grove/assets/_new/home_layered_cutpaper/home_house_grounded_checkpoint.png`

- [x] Keep the house at the approved upper-center placement with its attached steps aligned to the first separately placed road stone.
- [x] Recreate the road using repeated individual stone sprites and place four sparse grass clusters around only portions of the foundation edge.
- [x] Run `make test-one SUITE=games/grove/tests/grove_home_layer_workbench_tests` and require zero failures.
- [x] Run `make shot-home-layers MODE=all OUT=games/grove/assets/_new/home_layered_cutpaper/home_house_grounded_checkpoint.png` and visually inspect the full-resolution composition.
