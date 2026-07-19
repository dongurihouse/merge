# Uniform UI shadow — design

**Date:** 2026-07-19
**Status:** approved (Dev picked candidate I)

## Goal

Every piece of UI chrome (panels, cards, dialogs, buttons, pills, badges, bars) casts **one
identical shadow**, defined in one place, tuned from one workbench surface. Today there are six
coexisting mechanisms and two colour families; 31 of 39 workbench components cast nothing.

## The shadow (candidate I — measured from the picturebook mocks)

Reference screens: `games/grove/assets/_concepts/screens/board_next_unlock_v1_1080x1920.png`
and `maps_page_v1_1080x1920.png`. Measured profile on clean card edges: strong bottom cast
(~45% peak darkening fading over ~10 game-px), narrower right cast, **no** top/left cast,
cool slate tint (red channel suppressed far more than green/blue).

Translated to the shared box-shadow model at game resolution (720×1280):

| param | value |
|---|---|
| tint | `#294654` (existing `MEADOW_SHADOW_TINT`) |
| offset_x | 3 |
| offset_y | 7 |
| blur | 10 |
| spread | −2 |
| alpha | 0.38 |

One shadow, period — no elevation tiers. Elements that must read sunken (locked cells, wells,
trays) simply cast **nothing** (absence, not a third state). The exact numbers stay tunable
from the workbench Shadow item; the point of this spec is that there is exactly one set of
numbers and every element reads it.

## Scope

**In:** all UI chrome drawn through the UI kit / skin — dialogs, cards (all variants), shop,
vault, settings, bag, buttons, pills, badges, info bars, progress bars, the board frame,
action bar, home buttons.

**Out (unchanged):** ground/silhouette shadows (`prop_shadow.gd`), board-piece contact
shadows (`piece_view.gd`), move-FX transient shadows (`feel.gd` / `move_fx.gd`), shadows baked
into icon textures, font shadows, the gold-badge inner groove. These are physically different
things (objects on the ground / in flight), not chrome floating above a surface.

## Architecture

`engine/scripts/ui/skin.gd` stays the single owner of the box-shadow model. Changes:

1. **Slate becomes the model's tint.** The shadow builder colours shadows `#294654` directly.
   The `warmth` param and `warm_shadow_color()` ramp are removed from the shadow path (the
   warm brown look is retired). `shadow_params` drops `warmth`; passing it is ignored.
2. **Defaults = candidate I.** `shadow_params` defaults become offset (3,7), blur 10,
   spread −2, alpha 38 (still stored 0–100 in config). This kills the current hazard where a
   code path that misses the saved config falls back to a heavy dark collar.
3. **Kit meadow wrappers collapse.** `_meadow_shadow_rect/_circle/_with_shadow` and
   `_normalize_meadow_shadow` in `ui_workbench_kit.gd` become unnecessary once skin.gd itself
   is slate — replace call sites with the plain `Look.shadow_*` / `with_shadow` API and delete
   the wrappers. `MEADOW_SHADOW_TINT` moves to skin.gd as the model's tint constant;
   `MEADOW_SHADOW_MAX_ALPHA` is retired (one alpha, no cap needed).
4. **StyleBox tiers re-derived, not parallel.** `tuning.gd` `SHADOW_RESTING` / `SHADOW_RAISED`
   collapse to one constant built from the same numbers (tint `#294654` at 0.38,
   `shadow_size` 10, `shadow_offset` (3,7)) so StyleBoxFlat-native shadows are visually the
   same shadow. `SHADOW_SUNK` stays as the transparent "casts nothing" style. The other
   bespoke constants (`BODY_SHADOW`, `PILL_SHADOW`, `PARCH_SHADOW`, `BTN_SHADOW`,
   `CARD_SHADOW`, `BUY_SHADOW`, …) converge on the same derivation. Press-settle
   (`BTN_PRESS_SHADOW_*`) keeps its animation but between the uniform value and none.
5. **Per-side shadow keys retired.** The `shadow_top/bottom/left/right/soft` per-side model on
   the home badge and currency pill is replaced by the shared model. `shadow_shot.gd` (the
   per-side harness) is deleted with it.
6. **Local cool-slate copies deleted.** The hand-rolled `#294654` StyleBox constants in
   `residents.gd`, `giver_stand.gd`, `board.gd`, `explore_rush.gd`, `action_bar.gd` are
   replaced by the shared constant/builder. These were tuned to the same mocks, so their look
   barely moves.
7. **Config becomes authoritative.** The forced `opts["shadow"] = true` overrides in
   `action_bar.gd` / `map.gd` are removed; every chrome component's config gets
   `shadow: true`. `ui_workbench_settings.json`'s shadow block is rewritten to candidate I.

## Workbench & verification (test on one thing first)

1. **Shadow item first.** The workbench Shadow preview (`_shadow_preview`) currently renders
   the warm tint — after change 1 it automatically shows the real slate shadow. Verify
   candidate I on the Shadow item alone (`make shot-workbench EL=shadow`), compare against the
   mock crops, and lock the numbers.
2. **Then everywhere.** Flip `shadow: true` for every chrome component in
   `ui_workbench_settings.json`; extend `SHADOW_WIRED` handling so no component double-wraps.
   Sweep the full workbench (`make shot-workbench`) and the real screens
   (`make shot-grove MODE=hud`, shop/bag/daily/level dialog shots) and eyeball each against
   the mocks.
3. **Headless assert.** Add a `grove_ui_tests` case that builds representative components
   (dialog, card, button, pill, board frame) and asserts the shadow panel/stylebox exists with
   tint `#294654` and the uniform params — so a future bespoke shadow regression fails a test,
   not an eyeball.
4. `make test-fast` after each change; full `make test` before merge.

## Risks / notes

- Most visible change: the board frame, action bar and residents keep their look (already
  mock-true); dialogs, shop, vault, settings, bag and all card variants go from **no shadow**
  to the uniform shadow. That is the intent, but it is a broad visual change — screenshot
  sweep is the gate.
- Translucent chrome: the model fills its footprint (`draw_center = true`); elements with
  see-through fills would show the slate plate behind them. Audit call sites during rollout;
  any translucent element keeps `draw_center` off via the existing builder hazard note.
- `games/grove/tools/_tmp_shadow_mock_shot.gd` is a temporary comparison harness from the
  design phase — delete it (and its `.uid`) once implementation lands.
