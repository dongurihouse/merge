# Level dialog — design

Add the polished **Level** dialog (reference: `_originals/ui/lvl.png`) to the UI workbench and hook it
up to the game. The dialog is the art version of the existing `engine/scripts/ui/level_popup.gd`. It
serves two roles: a tap-to-view info popup (unchanged triggers) and a **level-up celebration** that
fires when the player gains a level and lets them **Collect** the level-up reward.

## Current state (base: `main` @ 9179832)

- `engine/scripts/ui/level_popup.gd` — `LevelPopup.open(host)` builds a plain parchment card: a
  `Look.title_ribbon("Level N")`, `Look.make_level_badge(lvl, 120)`, a "X / Y ★ earned" label, a
  code-drawn `_progress_bar(into, span)`, a "N more ★ to reach Level N+1" line, and a `Look.button("Got it")`.
  Triggered by tapping the HUD level badge and tapping a locked board cell.
- `engine/scripts/core/content.gd::earn_stars(n)` — the **sole** way Level advances (called once, from
  `board.gd::_on_giver_tap`, on quest delivery). On a level-up it **auto-grants** `LEVEL_WATER_GIFT × gained`
  water + `LEVEL_DIAMONDS × gained` diamonds, runs `Vault.skim(lvl_gems)`, and writes the save.
- `board.gd::_on_giver_tap` (~L1887) — on `levels_up > 0` it re-syncs water, refreshes locked cells, and
  plays floaters ("Level N!", water, gem) + `level_complete` audio.
- The UI workbench (`games/grove/tools/ui_workbench_view.gd` + `ui_workbench_kit.gd`) is a `@tool` gallery.
  Each component is an entry in `IDS`/`COLUMNS`, a `_params` block (saved config + `TEST_KEYS` scaffolding),
  a `_make_element` builder, and a sidebar. Saved design config lives in `ui_workbench_settings.json`; the
  **game reads the same JSON** via `Kit.*_from_config` helpers, so a workbench tweak flows to the game.

## Asset extraction (`lvl_asset.png` → `ui/kit/`)

Follow `docs/design/asset-intake.md`, category `sheet`. The raws already sit in `_originals/ui/`
(`lvl.png`, `lvl_asset.png`), so the plan's `source` points there and `archive` is a no-op self-path.
Slice to scratch with `slice_islands.gd`, read indices, then author `lvl_asset.plan.json`. Pieces:

| Output (`ui/kit/`) | What | Used by |
|---|---|---|
| `level_frame.png`  | ornate parchment card (decorative corners) | the dedicated frame (nine-patch, large corner slices) |
| `level_title.png`  | gold "Level N" pill | the frame's banner |
| `level_ring.png`   | thick gold medallion ring | the medallion's new border |
| `level_wreath.png` | laurel wreath | behind the medallion |
| `level_btn.png`    | green button background | the Collect / Got-it button |
| `prog_track.png`   | empty capsule | progress-bar track |
| `prog_fill.png`    | honey fill capsule | progress-bar fill |

Star / sparkles are **not** extracted — reuse the existing `star` icon and the code-drawn `Sparkle`.
Exact island indices are resolved at build time from the slice peek.

## Kit components (`ui_workbench_kit.gd`)

All four compose existing primitives and read their style from config helpers (mirroring `dialog_*`).

1. **`progress_bar(frac, opts) -> Control`** — the new standalone, reusable component. A `prog_track`
   capsule with a `prog_fill` overlay clipped to `frac` (min a rounded nub at 0%). Falls back to the
   current code-drawn track+fill if art is missing. `opts`: `label` ("" = none; e.g. "75%", centered —
   for the future home-screen unlock %), `star_knob` (bool — a star at the fill head), `height`, `art` (bool).
   Replaces `level_popup._progress_bar`. Added to the BUILDING-BLOCKS column.
2. **`level_medallion(level, px, opts) -> Control`** — **reuses the badge disc** (`shell_texture`/the
   badge item's polish) as the inner cream face, with the new `level_ring` as its border and the
   `level_wreath` layered behind, and the level number centered on top. (Q3 = ring + wreath + number.)
3. **`level_frame(content, width, opts) -> Control`** — a frame **just for this dialog** (not the shared
   `dialog_frame`): the `level_frame` parchment border, the `level_title` pill banner with the level text,
   inner padding, and **no scroll / no ✕** (the reference has none). Content is laid out statically.
4. **`level_dialog(data, width, opts) -> Control`** — composes `level_frame` + `level_medallion` +
   "X / Y ★ earned" + `progress_bar` + the bottom line + an optional **reward row** (cream water/gem chips
   via the existing `reward_chip`) + the bottom button (**reuses `pill_button`** with `art_rel = level_btn.png`).
   `data`: `level`, `earned`, `next`, `into`, `span`, `remaining`, optional `gift` ({water, gems}), `mode`
   ("info" | "levelup"), `on_button` (Callable). In `info` mode: no reward row, button "Got it". In
   `levelup` mode: reward row shown, button "Collect".
5. **Config helpers** — `level_opts_from_config(cfg)` (+ `level_dialog`/`progress_bar`/`medallion` sub-opts)
   reading a new `"level"` and `"progress_bar"` section of the settings JSON, used by BOTH the workbench
   preview and the game. `level_btn.png` is registered in the kit's art map.

## Workbench items (`ui_workbench_view.gd`)

Two new gallery entries, each following the existing pattern (`IDS`, `COLUMNS`, `_params`, `TEST_KEYS`,
`CAPTIONS`, `_make_element`, sidebar group, persisted via `_save_settings`):

- **`progress_bar`** — building-blocks column. Saved: `height`, `art`, `label_on`, `star_knob`. Test-only:
  a `frac` slider to preview fill.
- **`level`** — dialog column. Saved: `width_pct`, the medallion size, the frame banner/border/padding knobs
  ("just for this" — folded here, not a shared frame item), the button art toggle, reward-row toggle. Test-only:
  a preview `level`, `into/span`, and a `mode` switch (info vs levelup) to preview both states.

## Game wiring

**Reward deferral (Q1 = re-skin + level-up; reward = defer to Collect).** Split the level-up gift out of
`earn_stars` so the dialog's **Collect** grants it:

- `earn_stars(n)` keeps crediting stars + the earned clock and returns `levels_gained`, but **no longer
  grants** the water/diamond gift or runs `Vault.skim`. Add `level_gift(levels) -> {water, gems}` (pure,
  from `LEVEL_WATER_GIFT`/`LEVEL_DIAMONDS`) and `grant_level_gift(gift)` (applies water cap, `add_diamonds`,
  `Vault.skim`, writes save). Net economy is identical — only the **moment** of granting moves to Collect.
- `level_popup.gd` rebuilt on the kit:
  - `LevelPopup.open(host)` — **info** mode. Same triggers (HUD level badge, locked cell). Veil-dismissable,
    button "Got it". No reward.
  - `LevelPopup.open_levelup(host, levels_up)` — **levelup** mode. Computes the new level + `level_gift`,
    shows the reward row, button "Collect". **Not** veil-dismissable, no ✕ — the only exit is Collect, so the
    reward can't be lost. Collect calls `grant_level_gift`, updates the HUD/water, then closes.
- `board.gd::_on_giver_tap` — replace the `levels_up > 0` floater block with `LevelPopup.open_levelup(self, levels_up)`.
  Keep `_refresh_locked_cells()`; the water/HUD re-sync happens in the Collect callback (after the grant).

## Testing

- `make test-fast` after every change; `make test` before handoff.
- **Economy tests** (`grove_economy_tests`): assert `earn_stars` advances level **without** granting the gift;
  assert `level_gift` returns the right amounts and `grant_level_gift` applies water cap + diamonds + skim,
  with the same net result as the old auto-grant (no double, no loss).
- **UI tests** (`grove_ui_tests`): `Kit.level_dialog` builds in both modes; `Kit.progress_bar` builds at
  0% / 50% / 100% and with a label; `LevelPopup.open` / `open_levelup` instantiate and the Collect callback grants once.
- Visual: `make shot-grove` (or the workbench) to confirm the dialog matches `lvl.png` — verified by measuring/
  delivering the capture, not eyeballing a thumbnail.

## Out of scope

- The **home-screen unlock %** display (Q2 = component only). `progress_bar` is built ready for it (label
  support), but wiring that screen is a separate follow-up.
- Changing star/level thresholds, the evolving HUD badge (`make_level_badge` stays for the HUD/locked cells),
  or quest economy beyond moving the gift grant.

## Worktree

Built in worktree `worktree-level-dialog` (the user explicitly requested a worktree for this task, overriding
the standing "work on main" default). Merges back to `main` on verified-done.
