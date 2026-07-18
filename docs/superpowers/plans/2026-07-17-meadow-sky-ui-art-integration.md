# Meadow Sky UI Art Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Grove's visible interface art with the approved Meadow Sky, Cut-Paper Playground UI atlas while preserving runtime text, layout behavior, and input semantics.

**Architecture:** Archive the four approved source sheets, extract them deterministically into named transparent icons, scalable nine-slice surfaces, normalized badge variants, and periodic texture tiles, then route the existing centralized Grove UI kit to those canonical assets. Keep all text and numbers native, keep generated art shadow-free, and add only shallow tinted runtime shadows.

**Tech Stack:** Godot 4.6/GDScript, Python 3 + Pillow for deterministic image extraction, Grove shared `Skin`/`ui_workbench_kit`, existing headless screenshot and test targets.

## Global Constraints

- Use the fixed Meadow Sky role colors from `docs/design/meadow_sky_cut_paper_generation_guide.md`.
- Preserve Cut-Paper Playground matte paper, warm cut edges, broad low-complexity silhouettes, and phone-size legibility.
- Do not ship baked shadows in extractable UI art; runtime shadows must be shallow, tinted `#294654`, and about 18–20% opacity.
- Runtime renders every label, number, price, counter, and state; atlas art stays text-free.
- Repeatable textures are borderless, mathematically periodic, and verified in an offset montage.
- Existing gameplay behavior, button hit targets, and screen composition remain unchanged in this pass.

---

### Task 1: Deterministic Meadow Sky atlas intake

**Files:**
- Create: `games/grove/tools/extract_meadow_ui_v2.py`
- Create: `games/grove/tools/tests/test_extract_meadow_ui_v2.py`
- Create: `games/grove/assets/_originals/ui/meadow_sky_v2/*`
- Create: `games/grove/assets/ui/meadow_v2/manifest.json`
- Create: `games/grove/assets/ui/meadow_v2/qc/*`
- Modify: `docs/design/asset-intake.md`

**Interfaces:**
- Consumes: four approved 1254 x 1254 source sheets and their row-major manifests.
- Produces: `extract_sheet(sheet, rows, cols, entries, output_root)`, named PNGs, manifest metadata, and QC montages.

- [ ] **Step 1: Write failing extractor tests** covering fractional grid boundaries, noisy-magenta flood removal, row-major identity preservation, equal badge registration, no baked shadow pixels outside alpha, and exact first/last tile edge equality.
- [ ] **Step 2: Run `python3 -m unittest games.grove.tools.tests.test_extract_meadow_ui_v2 -v`** and confirm failures are caused by the missing extractor module.
- [ ] **Step 3: Implement the extractor** with corner-sampled flood removal, centroid bucketing inside `round(index * extent / count)` cells, per-entry icon/surface/badge policies, alpha-edge decontamination, and mirrored periodic tile construction.
- [ ] **Step 4: Copy the four raw sheets and prompt manifests into `_originals/ui/meadow_sky_v2/`, run the extractor, and emit the named manifest.**
- [ ] **Step 5: Run the extractor tests and inspect contact sheets plus 3 x 3 offset montages.**
- [ ] **Step 6: Document this fixed-grid atlas policy in the asset-intake runbook and commit the intake unit.**

### Task 2: Meadow Sky palette and canonical asset routing

**Files:**
- Create: `docs/design/meadow_sky_cut_paper_generation_guide.md`
- Modify: `games/grove/grove_palette.gd`
- Modify: `games/grove/tests/grove_ui_tests.gd`
- Replace: canonical PNGs under `games/grove/assets/ui/{shared,currency,kit,mail,map,board,rush,vase}/`

**Interfaces:**
- Consumes: named outputs under `games/grove/assets/ui/meadow_v2/`.
- Produces: unchanged `Game.PALETTE` constant names and unchanged canonical `Skin.icon()` paths with Meadow Sky values/art.

- [ ] **Step 1: Add failing UI tests** asserting the fixed role colors and canonical resource paths for currency, navigation, controls, board cells, progress, dialog banner, Rush, Shop, and Vault atoms.
- [ ] **Step 2: Run `make test-one SUITE=games/grove/tests/grove_ui_tests`** and confirm the new palette/resource assertions fail against the previous art system.
- [ ] **Step 3: Copy the approved generation guide into the current branch, update every retained palette constant to the nearest fixed Meadow Sky semantic role, and map extracted assets onto canonical paths.**
- [ ] **Step 4: Run `make import`, rerun the focused UI suite, and commit the palette/routing unit.**

### Task 3: Shared UI kit component integration

**Files:**
- Modify: `games/grove/tools/ui_workbench_kit.gd`
- Modify: `games/grove/tools/ui_workbench_settings.json`
- Modify: `games/tools/bake_targets.gd` only if a newly routed top-level dialog is absent from bake discovery.
- Modify: `games/grove/tests/grove_ui_tests.gd`
- Modify: `games/grove/tests/grove_info_bar_tests.gd`

**Interfaces:**
- Consumes: canonical Meadow Sky icons, nine-slice surfaces, badge variants, and texture tiles.
- Produces: existing constructors `pill_button`, `_banner`, `dialog_frame`, `level_badge`, `board_panel`, and `slot_cell_background` with unchanged public signatures.

- [ ] **Step 1: Add failing component-tree tests** proving shared dialogs use the banner atom, buttons use the primary/secondary/danger shells, board states use the correct cell shells, and level tiers select stable 256 x 256 badge variants.
- [ ] **Step 2: Run the two focused suites** and confirm the assertions fail on previous component paths/states.
- [ ] **Step 3: Route the shared constructors to the extracted nine-slice art, configure explicit patch margins, normalize runtime tinted shadows, and retain native text/input nodes.**
- [ ] **Step 4: Update workbench defaults to Meadow Sky roles, run `make bake-textures`, and rerun focused suites.**
- [ ] **Step 5: Commit the shared-kit integration unit.**

### Task 4: Whole-UI visual and regression verification

**Files:**
- Regenerate: `games/grove/assets/baked/**`
- Create: `tmp/meadow_ui_v2_review/*` (untracked review output)

**Interfaces:**
- Consumes: integrated canonical art and shared constructors.
- Produces: representative Home, Board, Maps, Rush, Level, Mail, Vault, Shop, Bag, and Tier screenshots plus passing focused/full test evidence.

- [ ] **Step 1: Run `make import` and `make bake-textures`.**
- [ ] **Step 2: Capture `make shot-grove MODE=fresh`, `make shot-grove MODE=level`, `make shot-grove MODE=bag`, `make shot-map MODE=fresh`, `make shot-map MODE=shop`, and the Rush/dialog screenshot tools into `tmp/meadow_ui_v2_review/`.**
- [ ] **Step 3: Inspect screenshots for magenta fringe, stretched corners, clipped labels, over-strong shadows, broken hit-target layout, and inconsistent palette roles; correct any issue at the shared seam.**
- [ ] **Step 4: Run `make test-one SUITE=games/grove/tests/grove_ui_tests`, `make test-one SUITE=games/grove/tests/grove_info_bar_tests`, `make test-grove`, and `make test-fast`.**
- [ ] **Step 5: Review `git diff --check`, the final asset manifest, and `git status --short`; commit the verified integration.**

## Self-review

- Coverage includes all four source sheets, all reusable foreground UI categories, palette roles, nine-slice routing, badges, texture periodicity, baked-cache regeneration, representative screen captures, and regression tests.
- The plan deliberately excludes world/background replacement and gameplay-item art because the request scopes this pass to UI elements other than backgrounds.
- Public runtime constructor signatures stay unchanged so screen behavior and inputs cannot drift as a side effect of the art replacement.
