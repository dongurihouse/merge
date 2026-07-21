# Cut-paper buttons — design

## Goal

Give the shared button (`Kit.pill_button`) the same code-drawn rugged (deckled) edge the dialog
frame uses (`CutPaperPanel`), tunable from the workbench with frame-style toggles, and route the
game's ad-hoc baked-sprite buttons (mail Claim / Claim All / reward, shop buy, welcome/starter deal)
through it so every button reads one shared setting set (color, size, deckle, shadow).

## Current state

- **Shared button**: `Kit.pill_button(text, opts)` — the workbench "Button" element. Its paper roles
  (green/cream/purple/coral/gold, `PAPER_SURFACES`) wear a **smooth rounded-box** shader mask over a
  grain texture (`_apply_rounded_paper_surface` → `PAPER_MASK_SHADER`). Not a torn edge.
- **Frame**: `engine/scripts/ui/cut_paper.gd` `CutPaperPanel` — code-drawn deckled polygon + tiled
  paper (`paper_tile_cream.png`) + shape-true drop shadow + warm rim. Knobs: `corner`, `deckle_amp`,
  `deckle_freq`, `rim_width`, `draw_shadow`, `paper_color`, `paper_tex`.
- **Bypassers** (baked sprites, to be rerouted):
  - Mail **Claim** / **Claim All** / reward → `Kit._skin_button` (baked `btn_green` TextSpriteButton).
  - **Shop** buy → `shop.gd _price_pill` (baked `button_green` StyleBoxTexture).
  - **Welcome/starter** deal → shop offer (`_price_pill`).
  - **Bag** purchase CTA → already `pill_button` green (no change).

## Decisions (approved)

1. **Deckle ON by default** game-wide (like the frame ships `cut_paper` on); workbench toggle can
   turn it off to compare.
2. **Reuse `CutPaperPanel`** as the button background (one deckle implementation shared with the
   frame), drawn behind a transparent `Button`; press/disabled states tint the panel.

## Design

### 1. `pill_button` gains a deckle path

When `opts.deckle` is on (default), instead of the shader paper surface:
- Button styleboxes (normal/hover/pressed/disabled) → transparent `StyleBoxFlat` carrying only the
  content margins (so text/icon keep their inset off the deckled edge).
- Add a `CutPaperPanel` child, `show_behind_parent = true`, full-rect, `mouse_filter = IGNORE`:
  - `paper_color` = the role fill (green/cream/purple/coral/gold).
  - `paper_tex` = the shared paper tile (`CUT_PAPER_TILE`).
  - `corner` / `deckle_amp` / `deckle_freq` / `rim_width` from opts.
  - `draw_shadow` = `opts.shadow` — the panel casts its OWN shape-true shadow, so we do NOT also
    wrap the button in the rectangular `_maybe_shadow` (that is the double-shadow bug on the frame).
- Press feedback: `button_down` darkens `paper_color` (~0.08) + `queue_redraw`; `button_up` restores.
  Disabled → the panel is built dimmed.
- Keep the existing font-color overrides (cream on green, ink on cream, etc.).

The smooth shader surface stays as the fallback when `deckle` is off (and for any caller that opts
out), so nothing regresses when the toggle is flipped.

### 2. Config-driven — `button_opts_from_config`

Add `Kit.button_opts_from_config(cfg)` (the standard kit pattern) reading a new `button` config
block: `deckle`, `deckle_amp`, `deckle_freq` (0..N percent ÷ 100), `rim_width`, `corner`, `shadow`.

`pill_button` reads these as **defaults** from the cached `load_config(CONFIG_PATH)` when the caller
doesn't pass them; explicit opts always win (mail Claim keeps its larger font/corner). This makes
every existing `pill_button` caller respect the workbench Button settings with no per-call threading.

### 3. Workbench Button element

Mirror the frame's toggles in the "Button" element sidebar: a "Rugged edge (code-drawn)" toggle
(`deckle`) + sliders `deckle_amp` [0,20], `deckle_freq` [1,20], `rim_width` [0,8], `corner`, and the
existing shadow toggle. Ship `deckle: true` in `ui_workbench_settings.json`.

### 4. Reroute call sites

- `Kit.mail_card` Claim + Claim All: drop the `_skin_button` baked path, build `pill_button` green.
- Mail reward chip: the shared static `pill_button` (cream role, static).
- `shop.gd _price_pill`: build via `Kit.pill_button` green (retire the baked `button_green` path).
- Verify the starter/welcome deal (a shop offer) inherits the same.
- Bag CTA: unchanged (already `pill_button`).

### 5. Fold-in: frame double-shadow fix

In the workbench, `_maybe_wrap_shadow` wraps the frame in a rectangular box-shadow even though the
`CutPaperPanel` already casts a deckled one. Skip the rectangular wrap for `frame` (and any element
whose deckle/cut-paper own shadow is on) so buttons and the frame each cast exactly one shadow.

## Verification

- `make test` (full sweep) green.
- Real-renderer screenshots (quiet_godot): mail (Claim/Claim All/reward), shop buy, bag CTA, and the
  workbench Button element — each shows the deckled edge, correct role colors, one shadow, readable
  press state. Compare against the frame's edge for consistency.

## Out of scope

- Home/nav buttons (`home_button`, `SpriteButton` disc/rect tiles) — those are a separate icon-tile
  component; not part of "the shared buttons" here.
