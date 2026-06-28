# Global dialog width + content scaling

**Date:** 2026-06-28
**Status:** Design approved (mechanism + scope + upscale decisions made)

## Goal

Every in-game dialog renders at a single, globally-configurable screen-width
percentage (default **75%**). When a dialog's width changes, its inner content
(text, cells, padding) scales with it so the dialog keeps its proportions; the
frame chrome (border, banner, close ✕) stays crisp. The per-dialog width knob in
the workbench is replaced by one global knob on the shared frame.

## Decisions (locked)

1. **Scaling = "scale content, crisp chrome."** Inner content scales; the
   parchment border / banner ribbon / close disc are rebuilt at the target width
   (native resolution), never transform-scaled, so they stay sharp.
2. **Scope = all dialogs**, including the two outliers: Level (uses a separate
   `level_frame()`) and Mystery Spin (hardcoded in `login_mystery.gd`).
3. **Upscale = scale up to fill** (no 1.0× cap). Dialogs authored narrower than
   75% (Settings/Level ≈1.5×, Info ≈1.29×) grow their content to fill.

## Current state

- Shared frame: `Kit.dialog_frame(content, width_px, opts)` in
  `games/grove/tools/ui_workbench_kit.gd:1962`. Takes an absolute pixel width;
  chrome is already sized to that width.
- Each dialog computes `width = viewport_w × width_pct / 100` at runtime, reading
  a **per-dialog** `width_pct` from `ui_workbench_settings.json`:
  mail/daily/bag = 75, info = 58, level = 50, settings = 50, shop = 85,
  tiers = 85, vault = 80.
- `ui_workbench_view.gd` holds per-dialog defaults + a width slider per dialog.
- `project.godot` uses `stretch/mode = canvas_items`, `aspect = expand`, base
  1080×1920 — so all UI already scales uniformly to the device. The viewport
  width is effectively constant (1080) at runtime, so `width_px` and the scale
  factor below depend only on percentages, not the physical device.
- Content does **not** currently scale to dialog width (fonts/cells are fixed px;
  grids only reflow column counts).

## Mechanism

### Scale factor

For each dialog, define a **design baseline percentage** `design_pct` = the width
the dialog's content is currently authored at (its present `width_pct`). The
content scale is:

```
s = global_width_pct / design_pct
```

At `global_width_pct = 75`: mail/daily/bag = 1.0 (unchanged), vault = 0.94,
shop/tiers = 0.88, info = 1.29, settings/level = 1.5. `design_pct` is a code
constant per dialog (same category as its cell sizes) — **not** a workbench knob.

### Shared frame (`dialog_frame`)

- Chrome (card/parchment stylebox, banner ribbon, close disc, panel padding,
  banner spacer) is built at the target `width_px` exactly as today → crisp.
- The inner `content` is wrapped in a **scale container** that:
  - lays its child out at the design inner width (`target_inner / s`), so the
    child's fonts/cells/wrapping render at their authored sizes (looks like
    today),
  - applies a uniform `scale = s`,
  - reports its child's **scaled** combined-minimum-size upward, so the
    `ScrollContainer` computes scroll height/bars correctly.
- New opt: `opts["content_scale"]` (default `1.0`). When ≈1.0 the wrapper is a
  no-op pass-through (mail/daily/bag stay byte-identical).

The scale container is a small reusable `Container` subclass (own `.gd`) so it is
unit-testable in isolation: given a child min size and a scale `s`, its own min
size = child_min × s, and it sizes the child to own_size / s.

### Runtime callers

Each dialog script (inbox, login, shop, settings, vault, ladder, gen_lines,
bag_overlay, level_popup, map, + shop info-sheet) changes from reading its own
`cfg.<dialog>.width_pct` to:

```
global_pct = cfg.dialog_frame.width_pct        # one shared key, default 75
width      = viewport_w × global_pct / 100
s          = global_pct / DESIGN_PCT           # DESIGN_PCT = per-caller constant
... dialog_frame(content, width, opts + {content_scale: s})
```

### Outliers

- **Level** (`level_frame()` + `level_popup.gd`, design_pct = 50): apply the same
  `content_scale` wrapper inside `level_frame`, and drive width from the global
  key. Reuses the same scale-container component.
- **Mystery Spin** (`login_mystery.gd`): drive its width from the global key and
  scale its content by `s = global_pct / current_effective_pct`. Its current
  sizing is `min(560, 94%)`; baseline captured as the matching pct. Verified by
  screenshot since it is bespoke.

## Workbench changes

- **Remove** the per-dialog `width_pct`: the slider rows in `ui_workbench_view.gd`
  (lines ~2343/2367/2381/2389/2541/2587/2647/2814), the per-dialog defaults, and
  the `width_pct` entries in `ui_workbench_settings.json`.
- **Add** one global `dialog_frame.width_pct` (default 75) with a single slider in
  a shared "Dialog frame" section of the workbench sidebar. The workbench preview
  (`_dlg_px`) and all runtime callers read this one value.

## Net effect at 75%

Mail / Daily / Bag unchanged · Vault ≈0.94× · Shop / Tiers ≈0.88× (shrink) ·
Info ≈1.29× · Settings / Level ≈1.5× (grow). All frames render at 75% of screen.

## Testing & verification

- **Unit (TDD):** the scale-container component (min-size math, child sizing);
  the scale-factor helper (`s = global / design`); callers read the global key.
  Add to an existing gated grove/engine suite. `make test-fast` after each change,
  `make test` before handoff.
- **Visual (required, per "see the result"):** render each dialog through the real
  game path at the default 75% and capture a screenshot; compare against the
  pre-change look (composite, don't eyeball). Confirm chrome is crisp and content
  is proportionally scaled. Mystery Spin and Level checked explicitly.

## Out of scope

- Re-tuning any dialog's authored content sizes.
- Changing dialog heights, positions, or non-width chrome behavior.
- Collapsing the per-dialog `design_pct` baselines into one shared value (would
  require re-tuning every dialog; explicitly rejected).
