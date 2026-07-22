# Daily dialog — code-drawn cut-paper cards

## Goal

Replace the daily reward dialog's baked day-card PNG faces with the code-drawn
cut-paper card (`engine/scripts/ui/cut_paper.gd`), using the existing paper color
roles. The current day gets a double-layer highlight (a golden cut-paper layer
below the cream one). Day 7 is a single golden cut-paper card. Reward icons on the
cards get a shape-true drop shadow.

## Constraints

- **Workbench drives the game.** The card look must live in **one** shared kit
  builder that both the workbench mock (`ui_workbench_kit.gd` `daily_card` /
  `daily_dialog`) and the real dialog (`engine/scripts/ui/login.gd`, which already
  loads the kit dynamically at `KIT_PATH`) consume. No divergent second look.
- **Existing color tones only.** Cream `#F6EBDD` and gold `#D6A94C` from
  `PAPER_SURFACES`; the shared `PAPER_EDGE` rim. No new palette.
- **Day 7 uses the standalone assets that already exist** (chest, oak sprigs,
  sparkles) composed over the gold card — not the baked `day7.png`.
- Headless engine + grove suites must pass (`make test`).

## Architecture

One new static builder in the shared kit, `games/grove/tools/ui_workbench_kit.gd`:

```gdscript
static func daily_card_face(size: Vector2, tone: String, cp_opts: Dictionary = {}, opts: Dictionary = {}) -> Control
```

Returns **only the card background**: a full-rect, mouse-transparent `Control`
holding one or two `CutPaperPanel`s. The caller anchors its own content over it
(content-layout unification between the two surfaces is out of scope — each pins
content differently, and that is fine). Both `login.gd._day_cell` / `_capstone`
and the workbench `daily_card` build their face through this one function,
replacing the baked `day_*.png` / `day7.png` sprite path.

`cp_opts` are the shared normalized cut-paper edge knobs (corner · deckle_amp ·
deckle_freq · rim_width · edge_shadow · shadow_reach · shadow_blur ·
shadow_strength) — same set every other cut-paper component consumes, defaulted
per a new `DAILY_CARD_CP_DEFAULTS` and scaled to the card size (corner tracks card
width). `opts` carries the double-layer knobs (below).

### Tones

- **`"cream"`** — days 1–6 (past / future / plain). One `CutPaperPanel`,
  `paper_color = #F6EBDD`, shared cream fibre (`cut_paper_tile()`), `PAPER_EDGE`
  rim, its own shape-true drop shadow (`draw_shadow` on).

- **`"today"`** — the highlighted current day. **Double layer:** a **gold**
  `CutPaperPanel` (`paper_color = #D6A94C`, cream fibre tinted gold — consistent
  with how every other paper role renders in the deckle path) laid out *behind*,
  inflated on all sides by `gold_inflate` px and shifted down by `gold_drop` px, so
  a golden deckled rim peeks out around and below the cream panel on top. The
  bottom **gold** panel casts the card's ground shadow; the **cream** top panel's
  own shadow is suppressed (`draw_shadow` off) to avoid a muddy double shadow
  between the two layers. `gold_inflate` (default `size.x * 0.05`) and `gold_drop`
  (default `size.x * 0.03`) are tunable via `opts`.

- **`"gold"`** — day 7 capstone. One gold `CutPaperPanel` (no cream on top), so the
  whole banner reads golden.

### Day 7 content

Drawn over the `"gold"` face by reusing `login.gd`'s existing `_capstone_drawn`
composition (standalone `ART_CHEST` + `ART_LEAF_L/R` oak sprigs + code sparkles),
with its flat `_cell_box` background swapped for the gold `daily_card_face`. The
`day7.png` / `day7_claimed.png` baked banner path is retired from `login.gd`.

### Icon shadows

Reward icons on the day cards currently render as flat `TextureRect`s
(`_skin_sprite`, `_reward_art`, `make_icon` → `_icon_rect`). Give them the
shape-true, warm-tinted drop shadow that already exists in the kit
(`silhouette_shadow` / `add_drop_shadow`, which follow the sprite alpha), baked
into the icon image behind a `shadow` opt on the daily icon builder so it applies
uniformly on both surfaces. Reuse the existing shadow knobs
(`shadow_offset` · `shadow_blur` · `shadow_alpha` · `shadow_pad` · `shadow_spread`).

### State on cream cards

The baked faces carried per-state chrome; now drawn on the plain cream card:

- **future** — cream card + wrapped-gift sprite (`gift_0..4`, standalone, already
  used).
- **today** — gold-under-cream face + reward icon + amount + full-cell tap target.
- **past / done** — cream card dimmed (`modulate` α), reward icon shown dimmed,
  plus the `✓` mark (`ART_CHECK`). (The old baked face hid the icon on done days;
  keeping it dimmed is the intended change.)

## Out of scope

- Content-layout unification between the workbench mock and the real dialog.
- New art / new palette roles.
- The `daily_card.png` nine-patch (retired only from the daily path; other callers
  unaffected).

## Testing

- `make test-fast` after each edit; `make test` (engine + grove) before handoff.
- Grove UI/placement suites instantiate the daily dialog; extend the daily suite to
  assert the face builder returns a `CutPaperPanel`-backed control for each tone and
  that `today` yields two stacked panels.
- Visual confirmation via the workbench render of `daily_dialog` (composite /
  measure, never eyeball a thumbnail).
```
