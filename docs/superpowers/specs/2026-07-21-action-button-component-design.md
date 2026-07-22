# Action Button component — unified rugged-edge nav tiles

**Date:** 2026-07-21
**Status:** Approved design, pre-implementation

## Problem

The home-screen bottom nav (map · residents · daily · vault · mail · play) and the board screen's Home
and Bag wells each render as a **baked `nav_<x>.png` sprite** through `SpriteButton`. Every sprite fuses
the rugged cut-paper edge, the paper fill, and the icon art into one PNG, generated independently. The
result is inconsistent — the map tile has a blue fill and blue deckle, the home tile is cream — because
nothing shares an edge. Meanwhile the codebase already draws the rugged edge **in code** (`cut_paper.gd`,
driven by the shared `CUT_PAPER_KNOBS` schema) for pill/CTA buttons, dialog frames, and settings rows, all
tunable from one workbench spot.

The `home_button` workbench component previews `Kit.home_button` rect tiles — a path the live bar no
longer uses (the baked sprite wins whenever it exists).

## Goal

One workbench component and one shared builder for the action/nav buttons. Each button draws the rugged
edge **in code** from the shared cut-paper config, with a **separate icon glyph** composited in the middle.
Home and board build their tiles from this single component, configured the same way. A fresh, consistent
icon glyph set is generated in one batch so the glyphs read as a family.

## Scope

**In:** the core nav set — home-screen bottom bar (map, residents, daily, vault, mail, play/board) plus the
board screen's Home and Bag wells.

**Out (this pass):** back arrow, gear/settings, the map place-picker tiles, and the info-bar ⓘ. These
remain on their current path; they can fold into the component later.

## Decisions

- **Shared edge, per-button tint.** All buttons share one edge config and paper tile from the workbench
  block. Each button's **fill color** comes from a **named tint palette in the config block** (e.g.
  `map → sky`, `home → cream`), so tints are workbench-tunable from one source and the live game reads them.
- **Flatten to calm paper roles.** No warm accent for Play/board — every tile uses a calm paper-role fill.
  The **icon glyph is the only differentiator** between tiles.
- **Generate the full glyph set at once.** Transparent, edge-free glyphs, one batch, per the art-style guide.

## Design

### 1. Shared builder — `Kit.action_button(...)`

A code-drawn deckle button, analogous to `SpriteButton.build` but with the rugged edge drawn in code:

- Reuses `engine/scripts/ui/cut_paper.gd` as the button surface (the same applier `_apply_deckle_button_surface`
  already uses): a full-rect `CutPaperPanel` behind a flat `Button`, configured from the shared cut-paper opts.
- Composites a centered **icon glyph** on top (via the existing `make_icon` / `_icon_rect` polish), sized by
  an `icon_scale` fraction, mouse-transparent so the Button is the only hit surface.
- Adds the shared drop shadow (shaped to the button's corner) and `Look.add_press_juice`.
- Takes a **per-button fill tint** on top of the shared edge/tile config.
- Signature mirrors the current call sites so `map.gd` / `board.gd` (which already `load(KIT_PATH)` at
  runtime) swap directly:
  `Kit.action_button(icon_id_or_tex, size, action, opts)` where `opts` carries the cut-paper opts, `fill`,
  `icon_scale`, `shadow`, `name`, `tooltip`.
- `Kit.action_button_opts_from_config(cfg)` reads the `action_button` block: the shared cut-paper opts (via
  `cut_paper_opts_from_config`), geometry (icon_scale, shadow), and the tint palette.

### 2. Workbench component — `action_button` (replaces `home_button`)

- **IDS / labels / sections**: add `action_button`, remove `home_button`.
- **Sidebar**: the shared `_cut_paper_section("action_button")` (same rugged-edge rows as Frame/Button) +
  geometry (px, icon scale, shadow toggle) + the **per-button tint palette** (a paper-role selector per
  button, or a compact role map).
- **Preview**: a live row of all the action tiles — map, residents, daily, vault, mail, play, home, bag —
  each built through the exact `Kit.action_button` the game uses, with its glyph and paper-role fill.
- **Config block defaults**: cut-paper opts seeded from `BUTTON_CP_DEFAULTS`, a default tint palette, geometry.
- Remove `home_button`'s config block, sidebar case, preview builder, `HOME_BAR_TILES`, and its entries in
  IDS/LABELS/SECTIONS/SHADOW_WIRED/etc. `Kit.home_button` the **function** stays (still the fallback in
  map.gd/board.gd and used elsewhere) — only the workbench component is removed.

### 3. Icon glyph sprite set

- Generate transparent, edge-free glyphs in one batch (art-style guide + `generating-images-with-codex`):
  **map, residents (house), daily, vault, mail, board (play), home, bag** — 8 glyphs, one visual family.
- Store under a new folder, e.g. `games/grove/assets/ui/nav/glyphs/`, and resolve through the existing icon
  polish. Follow the guide's intake workflow (classify → plan.json → `make intake` → verify → archive raws).

### 4. Swap live call sites

- `map.gd:_build_bottom_bar`: build each tile via `Kit.action_button(role, ...)` reading
  `action_button_opts_from_config`, instead of `SpriteButton.build(load(nav_<x>.png), ...)`.
- `board.gd`: Home well (`nav_home.png`) and Bag well (`nav_bag.png`) build via `Kit.action_button`. The Bag
  well keeps its stashed-item overlay + count and its drag-to-stash global-rect behavior unchanged (the
  overlay parents to the new button the same way).
- Retire the baked `nav_<x>.png` tiles — **archive, not delete** — once the code path is verified.

### 5. Tests

- Update `grove_explore_tests` (asserts `nav_<x>.png` tiles today) to the new builder.
- Add coverage: `action_button` builds a Button whose surface is a `CutPaperPanel`, honors the fill tint and
  icon glyph, and `action_button_opts_from_config` round-trips the config block (edge opts + palette).
- `make test` green before hand-off.

## Verification

Render the real home bar and the real board bottom bar through the live path (not just the workbench
preview) and confirm every tile shares one rugged edge, the glyphs read as a family, and per-button paper
roles apply. Compare against the current baked bar.

## Risks / notes

- The Bag well's stashed-item overlay and drag-to-stash hit-testing must survive the swap — keep the same
  child structure and `global_rect` semantics.
- `Kit.home_button` has other callers (HUD/shop, fallbacks); leave the function intact, remove only the
  workbench component.
- Icon glyph style must match the existing cozy cut-paper direction — the current baked tiles and the
  `cutpaper_storybook_ui_v1` concept screens are the reference.
