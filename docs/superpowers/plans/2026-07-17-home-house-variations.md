# Home House Variations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one simple and one fancy swappable farmhouse asset around the approved current middle-tier house and render all three in identical scene context.

**Architecture:** Each house is a separate transparent bottom-anchored prop with its attached steps at the shared road endpoint. The road-free base, road stones, and grass props remain unchanged; deterministic preview composition swaps only the house texture, size, and position.

**Tech Stack:** Built-in image generation, PNG chroma-key cleanup, Pillow preview composition, existing Godot placement manifest.

## Global Constraints

- Preserve the approved cut-paper material, coral/cream/gold/cobalt palette family, elevated three-quarter view, upper-left light, and attached three-tread stairs.
- Keep the entrance and stairs at 39–42 percent of the sprite width and align the lowest stair to world `(412, 686)`.
- No grass, road, turf, soil, environment, cast/contact shadow, dark grounding strip, or detached object inside a house sprite.
- Progression comes primarily from architectural complexity and height. The approved starter may use a modestly smaller footprint, while the fancy tier must not exceed the current house's ground footprint.

---

### Task 1: Generate the simple and fancy houses

**Files:**
- Create: `games/grove/assets/_new/home_layered_cutpaper/raw/fh_house_simple_raw.png`
- Create: `games/grove/assets/_new/home_layered_cutpaper/raw/fh_house_fancy_raw.png`
- Create: `games/grove/assets/_new/home_layered_cutpaper/props/fh_house_simple.prompt.txt`
- Create: `games/grove/assets/_new/home_layered_cutpaper/props/fh_house_fancy.prompt.txt`

- [x] Generate the one-story starter cottage one-by-one against flat `#FF00FF`.
- [x] Generate the grand farmhouse one-by-one against flat `#FF00FF`.

### Task 2: Clean and validate the transparent assets

**Files:**
- Create: `games/grove/assets/map/home_layered_cutpaper/props/fh_house_simple.png`
- Create: `games/grove/assets/map/home_layered_cutpaper/props/fh_house_fancy.png`

- [x] Remove the magenta key with soft matte, despill, and one-pixel edge contraction.
- [x] Crop to alpha bounds with six pixels of transparent padding and verify one connected component with transparent corners.

### Task 3: Render the progression comparison

**Files:**
- Create: `games/grove/assets/_new/home_layered_cutpaper/house_variant_simple_preview.png`
- Create: `games/grove/assets/_new/home_layered_cutpaper/house_variant_current_preview.png`
- Create: `games/grove/assets/_new/home_layered_cutpaper/house_variant_fancy_preview.png`
- Create: `games/grove/assets/_new/home_layered_cutpaper/house_variants_comparison.png`

- [x] Compose all non-house manifest props unchanged over the road-free base.
- [x] Render simple at `[450,690]` / `[420,380]`, current at `[470,690]` / `[500,474]`, and fancy at `[470,690]` / `[560,520]`.
- [x] Combine the three full scenes into a labeled comparison strip and visually verify the road meets every attached staircase.
