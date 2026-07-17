# Layered Cut-Paper Home Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone Godot preview that composes seven separately generated cut-paper Home structures over a structure-free 941x1672 background.

**Architecture:** Generated art is stored under a prototype-only asset folder. A JSON manifest is the single source of truth for image paths, center-bottom anchors, display sizes, and sort order; one focused Godot script loads the manifest and builds the review scene. The shipped Home renderer remains untouched.

**Tech Stack:** Godot 4.6 GDScript, PNG raster assets, JSON placement metadata, built-in image generation, deterministic chroma-key cleanup.

## Global Constraints

- Preserve the selected saturated cut-paper Direction B across background and props.
- Base image is exactly `941x1672` and contains no removable structures or their shadows.
- Generate all seven identity-critical structures one-by-one.
- Every structure has a connected turf skirt and a shared top-left light/down-right shadow treatment.
- Generated prompts are saved beside their accepted assets.
- Do not modify the live Home scene, map renderer, or progression data.

---

### Task 1: Produce and validate layered visual assets

**Files:**
- Create: `games/grove/assets/map/home_layered_cutpaper/home_base.png`
- Create: `games/grove/assets/_new/home_layered_cutpaper/home_base.prompt.txt`
- Create: `games/grove/assets/_new/home_layered_cutpaper/home_dressed_reference.png`
- Create: `games/grove/assets/_new/home_layered_cutpaper/home_dressed_reference.prompt.txt`
- Create: `games/grove/assets/map/home_layered_cutpaper/props/fh_hearth.png`
- Create: `games/grove/assets/map/home_layered_cutpaper/props/fh_larder.png`
- Create: `games/grove/assets/map/home_layered_cutpaper/props/fh_boxes.png`
- Create: `games/grove/assets/map/home_layered_cutpaper/props/fh_kitchen.png`
- Create: `games/grove/assets/map/home_layered_cutpaper/props/fh_well.png`
- Create: `games/grove/assets/map/home_layered_cutpaper/props/fh_lantern.png`
- Create: `games/grove/assets/map/home_layered_cutpaper/props/fh_porch.png`
- Create: one matching `.prompt.txt` per prop

**Interfaces:**
- Consumes: the selected Direction B mockup and the design spec's shared structure contract.
- Produces: one exact-size base and seven alpha PNGs ready for center-bottom placement.

- [x] Generate a foundation-only background with no structures, UI, labels, or structure shadows.
- [x] Normalize the accepted background to exactly `941x1672` and save its prompt.
- [x] Generate a dressed-reference image from the visible accepted base with all seven structures naturally placed.
- [x] Generate every structure one-by-one on flat `#FF00FF`, using the visible base and dressed reference as context.
- [x] Extract the largest connected silhouette, crop transparent excess, and preserve the opaque turf skirt/contact shadow without desaturating violet or raspberry.
- [x] Verify dimensions, alpha channels, transparent corners, nonempty coverage, and absence of residual magenta edge contamination.

### Task 2: Define placement data and a failing scene contract test

**Files:**
- Create: `games/grove/assets/map/home_layered_cutpaper/home_props.json`
- Create: `games/grove/tests/grove_home_layer_workbench_tests.gd`
- Modify: `Makefile`

**Interfaces:**
- Consumes: final prop filenames and the design spec placement table.
- Produces: JSON entries with `id`, `image`, `x`, `y`, `w`, `h`, `sort_y`, and a test that expects the workbench API.

- [x] Write `home_props.json` with `canvas`, `background`, and exactly seven `props` entries.
- [x] Write a headless test that loads `HomeLayerWorkbench.tscn`, asserts a `941x1672` canvas, seven named prop nodes, importable textures, and working all/none toggles.
- [x] Add the suite to `GROVE_TESTS`.
- [x] Run `make test-one SUITE=games/grove/tests/grove_home_layer_workbench_tests` and confirm it fails because the scene does not exist.

### Task 3: Implement the standalone Godot workbench and screenshot harness

**Files:**
- Create: `games/grove/tools/HomeLayerWorkbench.tscn`
- Create: `games/grove/tools/home_layer_workbench.gd`
- Create: `games/grove/tools/home_layer_shot.gd`
- Modify: `Makefile`

**Interfaces:**
- Consumes: `home_props.json` and the referenced PNG assets.
- Produces: `reload_manifest()`, `set_all_props_visible(visible: bool)`, `set_guides_visible(visible: bool)`, `prop_count() -> int`, and `canvas_size() -> Vector2`.

- [x] Create the minimal `.tscn` root wired to `home_layer_workbench.gd`.
- [x] Implement manifest parsing, aspect-fit canvas placement, background creation, center-bottom prop placement, y sorting, and the public test API.
- [x] Implement keyboard toggles `1`–`7`, `A`, `N`, `G`, `R`, and `H` plus a hidden-by-default help overlay.
- [x] Add `home_layer_shot.gd` to instantiate the scene, wait for import/layout, render the exact art canvas, and save the requested PNG.
- [x] Add `home-layers` and `shot-home-layers` Make targets.
- [x] Run the targeted test and confirm it passes.

### Task 4: Compose and visually verify the result

**Files:**
- Create: `games/grove/assets/_new/home_layered_cutpaper/home_layered_assembled_preview.png`

**Interfaces:**
- Consumes: the workbench default state.
- Produces: the flattened QA image shown to the user and retained with the prototype assets.

- [x] Run `make import` so all PNGs are available to Godot.
- [x] Run the screenshot harness to produce `home_layered_assembled_preview.png` at the exact art-canvas crop.
- [x] Inspect the base-only view, every individual prop, and the assembled preview for seams, scale, lighting, and occlusion.
- [x] Adjust only placement/scale metadata when art is sound; regenerate a prop only when its perspective, turf skirt, or light direction is incompatible.
- [x] Run `make test-fast`, the targeted Grove suite, and `make test`.
- [x] Review `git diff --check`, asset dimensions/alpha, and repository status before commit.
