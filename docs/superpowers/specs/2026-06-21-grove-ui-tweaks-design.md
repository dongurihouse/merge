# Grove UI tweaks — design (2026-06-21)

Six tweaks, all in the worktree `ui-tweaks`. The UI is built by the kit
(`games/grove/tools/ui_workbench_kit.gd`) from knobs in
`games/grove/tools/ui_workbench_settings.json`; sliders live in
`games/grove/tools/ui_workbench_view.gd`; the live game reads the same config
(`engine/scripts/ui/*`, `engine/scripts/scenes/*`). "Make it editable in the
workbench" = add a kit knob + a view slider; the live game picks it up.

## 1. Home button caption padding
The caption is `Look.title_ribbon()` in a CenterContainer. Gap to the disc is the
existing `caption_gap`; internal padding is shared `Tune.TITLE_PAD_*` plus a
hardcoded `+22` band (`ui_workbench_kit.gd:882`).
**Change:** add `caption_pad_x` / `caption_pad_y` knobs that override the ribbon's
content-margins for the home button only, and replace the `+22` band with
`2*caption_pad_y` so the box matches the ribbon. Add two sliders under
`home_button` in the view.

## 2. Currency pill "+" size & x
`plus_gap` already controls the "+" horizontal offset (kept as the x knob). The
"+" size is hardcoded (`_plus_token`: 26px box / 22px font in the kit;
`Tune.PLUS_BOX`/`PLUS_SIZE` live).
**Change:** add a `plus_size` knob driving the box and font for both the kit
preview (`_plus_token`) and the live HUD "+" (`hud.gd:_plus_button`). Add a
`plus_size` slider under `currency_pill`.

## 3. Side-rail badge offset (top-right LiveOps rail)
The rail (Daily · Free · Vault · Inbox) uses shared home-button discs; their
red-dot / count badge is placed by `Look.attach_badge()` from a single hardcoded
`Tune.BADGE_OVERHANG = (6,6)`, not workbench-tunable, and floats off the disc's
transparent margin.
**Change:** add `badge_dx` / `badge_dy` knobs to the `home_button` element; add an
optional offset arg to `attach_badge(host, b, over)` (defaulting to
`Tune.BADGE_OVERHANG`); the rail (`map.gd`) passes the tuned offset. Show a sample
count badge on the home_button workbench preview so the offset is tunable live.
Default the offset tighter to the disc.

## 4. Quest item not repeating within 5
Mirrors the existing "giver within 5" rule (`board.gd:_next_giver`). Keep a rolling
`_recent_lines` window (last 5 asked item-lines); feed it into the existing `avoid`
list in `Quests.refill` (a soft penalty via `_weighted_line_pick`, so it degrades
gracefully on maps with few item-lines instead of starving the pool). Record a
line into the window when its quest leaves the fence (delivered/replaced).

## 5. Purge card breathes when ready
Call `FX.breathe_once()` on the purge card when it is in the ready (enough-stars)
state, same as payable giver cards (`board.gd:_refresh_giver_lights`).

## 6. Purge card: stars instead of lock
Drop the padlock. Always show the card while the map has unowned spots (currently
shows only when ready). Display the layer's **current star count only** (banked
`Save.stars()`). Grey it out (no breathe) when banked < cheapest unowned-spot cost;
full colour + breathing when affordable (`_gate_ready()`). Hidden only when the map
is done.

## Testing
- Logic (items 4, 6): unit tests in the grove/engine suites (TDD).
- Workbench knobs (items 1, 2, 3): assert the kit reads the new keys and the view
  declares the sliders (extend `grove_workbench_tests.gd` / `grove_ui_tests.gd`).
- `make test-fast` after each change; `make test` before handing off.
