# Rush FX workbench — split into individual triggers + per-effect knobs

Date: 2026-06-27
Status: approved (design)

## Problem

The Rush screen-juice effects (`engine/scripts/ui/rush_fx.gd`) are previewed as a **single
element** in the UI workbench (`games/grove/tools/ui_workbench_view.gd`, the `rush_fx` element).
That preview has two problems:

1. **Everything fires at once.** One ▶ Replay button runs *all* enabled effects in one demo
   sequence (`ui_workbench_view.gd:783-801`). You cannot feel a single effect in isolation.
2. **No knobs.** The sidebar exposes only on/off toggles (`ui_workbench_view.gd:2061-2066`).
   Every intensity value is a hardcoded magic number inside `rush_fx.gd` (burst counts, text
   size, shake amplitude, hitstop duration, …). There is no way to tune intensity or feel.

The seven effects: `merge_burst`, `score_tick`, `score_pulse`, `mult_pop`, `combo_heat`,
`timer_low`, `treefall_crack`.

## Goals

- Trigger **each effect individually** from the workbench (a per-effect ▶ Replay), keeping a
  master "Replay all".
- Give **each effect targeted knobs** for intensity / feel, bound to real FX parameters.
- **Wire the knobs to the live rush**: `explore_rush.gd` reads the saved knob values and applies
  them in the real game (the same way it already reads the on/off toggles). Tuning in the
  workbench changes the actual Expedition Rush.

## Non-goals

- No new standalone tool / no new gallery rows (the effect stays one workbench element).
- No color/look pickers in this pass (single targeted knob per effect; three for treefall).
- No changes to *which* effects exist or when the game calls them.

## Approach (chosen)

In-place rework of the existing `rush_fx` workbench element, reusing the existing
`_slider_row` / `_toggle_row` / `_apply_edit` / config-persistence patterns. The shared demo
(scaled rush bar + two tiles) already hosts every target an effect needs — score cell, mult
cell, time label, tiles, and the bar for shake — so one demo can fire any single effect.

### Knob set

Each knob maps to a real FX parameter. Default = today's value, so behavior is unchanged until
a slider moves. All knobs are integer sliders (the workbench's only slider type).

| Effect          | Knob(s)                          | Param it drives                         | Default      | Range            |
|-----------------|----------------------------------|-----------------------------------------|--------------|------------------|
| Merge burst     | Burst count                      | `FX.burst` `amount`                     | 20           | 4–40             |
| Score ticks up  | Roll time (ms)                   | `FX.tick` `dur` (new optional param)    | 400          | 80–600           |
| Score cell pulse| Pop strength %                   | `FX.squash_pop` `strength` (new param)  | 100          | 40–180           |
| Mult pop        | Pop strength %                   | `FX.squash_pop` `strength`              | 100          | 40–180           |
| Combo heat      | Text size                        | `FX.floating_text` `size` base          | 24           | 18–60            |
| Timer urgency   | Trigger ≤ (s)                    | `timer_low` threshold (was hardcoded 10)| 10           | 3–20             |
| Treefall crack  | Debris count · Shake px · Hitstop ms | `FX.burst` amount · `FX.shake` amp · `FX.hitstop` secs | 18 · 16 · 60 | 4–40 · 0–40 · 0–160 |

Param key names in `_params["rush_fx"]` (snake_case, suffix-per-knob):
`merge_burst_count`, `score_tick_ms`, `score_pulse_pct`, `mult_pop_pct`, `combo_heat_size`,
`timer_low_secs`, `treefall_debris`, `treefall_shake`, `treefall_hitstop_ms`.

Where an effect scales with a runtime quantity in-game (merge result tier, combo length), the
knob is the **base** and the runtime bonus still applies:
- `merge_burst`: `count = clampi(merge_burst_count + (tier - 1) * 4, 4, 40)`
- `combo_heat`: `size = clampi(combo_heat_size + combo * 3, combo_heat_size, combo_heat_size + 30)`
The workbench demo passes representative values (tier 3, combo 6) so the preview reads richly.

## Components & data flow

### 1. `engine/scripts/ui/fx.gd` — two additive params (backward-compatible)

- `squash_pop(node, strength := 1.0)` — scale each squash keyframe's deviation from 1.0 by
  `strength`: `s' = Vector2.ONE + (k - Vector2.ONE) * strength`. `strength == 1.0` reproduces
  today exactly. The calm-mode branch scales `SQUASH_CALM` the same way.
- `tick(label, to_value, dur := Tune.TICK_T_COUNT)` — use `dur` for the count tween duration
  instead of the constant. Default reproduces today.

No other callers change (defaults preserve behavior).

### 2. `engine/scripts/ui/rush_fx.gd` — parameterized effects + knob defaults

- Add a `KNOBS` table (id → default) and extend `defaults()` / `from_config()` so the resolved
  opts dict carries the numeric knobs as well as the booleans. `from_config` reads each knob
  from `cfg["rush_fx"]` with the default fallback (mirrors the existing boolean resolve loop).
- Each effect fn gains the tuning it needs, sourced from the resolved opts. Signatures change
  to accept the value(s) explicitly (callers pass them):
  - `merge_burst(host, gpos, tier, count)` → `FX.burst(host, gpos, LEAF, clampi(count + (tier-1)*4, 4, 40))`
  - `score_tick(label, to_value, ms)` → `FX.tick(label, to_value, ms / 1000.0)`
  - `cell_pop(cell, pct)` → `FX.squash_pop(cell, pct / 100.0)` (used by score_pulse + mult_pop)
  - `combo_heat(host, gpos, combo, base_size)` → size = clampi(base_size + combo*3, base_size, base_size+30)
  - `timer_low(label, secs_left, threshold, silent)` → urgency when `secs_left <= threshold`
    (warmth lerps over `[0, threshold]`)
  - `treefall_crack(host, board, gpos, debris, shake_amp, hitstop_secs, silent)`
- A small helper `knob(opts, id)` returns `int(opts.get(id, KNOBS[id]))` for callers.

### 3. `games/grove/tools/ui_workbench_view.gd` — split UI + per-effect replay

- Extend `_params["rush_fx"]` with the nine knob keys (defaults from `RushFx.KNOBS`). Knobs are
  **persisted** (not added to `TEST_KEYS`), so they save like the toggles.
- Refactor the `rush_fx` preview build (`:752-803`) to store the demo context in a member
  (`_rush_fx_ctx := {bar, score_label, mult_label, time_label, score_cell, mult_cell, tile_a,
  tile_b, wrap, tile_ctr}`) and to **not** auto-fire on build. Add a method
  `_rush_fx_play(effect_id)` that fires exactly one effect (or `"__all__"`) on that context,
  reading the live knob values from `_params["rush_fx"]`.
- Sidebar (`:2061-2066`): master toggle; then per effect a group of: a row `[label · toggle · ▶]`
  where ▶ calls `_rush_fx_play(id)`, followed by that effect's knob slider row(s). The ▶ buttons
  carry `wb_active` meta so the gallery's select-on-click does not swallow them (same as the
  existing Replay button at `:780`).
- The single existing preview button becomes "▶ Replay all" → `_rush_fx_play("__all__")`. That is
  the only "all" trigger; per-effect ▶ lives in the sidebar.

### 4. `engine/scripts/scenes/explore_rush.gd` — forward knobs to the live game

`explore_rush.gd` already resolves `_fx = RushFx.from_config(...)`. Update each gated call site
(`_merge`, `_drop_timber`, `_refresh_readouts`) to pass the knob values from `_fx`:
- `RushFx.merge_burst(self, ctr, int(win.tier), RushFx.knob(_fx, "merge_burst_count"))`
- `RushFx.score_tick(_lbl_score, Explore.score(), RushFx.knob(_fx, "score_tick_ms"))`
- `RushFx.cell_pop(_score_cell, RushFx.knob(_fx, "score_pulse_pct"))`
- `RushFx.cell_pop(_mult_cell, RushFx.knob(_fx, "mult_pop_pct"))`
- `RushFx.combo_heat(self, …, _combo, RushFx.knob(_fx, "combo_heat_size"))`
- `RushFx.timer_low(_lbl_time, s, RushFx.knob(_fx, "timer_low_secs"))`
- `RushFx.treefall_crack(self, _board, …, RushFx.knob(_fx, "treefall_debris"),
  RushFx.knob(_fx, "treefall_shake"), RushFx.knob(_fx, "treefall_hitstop_ms") / 1000.0)`

### Persistence

Saved to the `rush_fx` block in `games/grove/tools/ui_workbench_settings.json` (the path
`RushFx.from_config` reads via `Kit.load_config`). Knob keys live alongside the existing boolean
toggles. No schema/migration concerns — `from_config` defaults any missing knob.

## Testing (TDD)

New/extended coverage (active grove suites):

1. **`from_config` knobs** (`grove_*` model-level): defaults present when the config omits them;
   explicit values override; booleans still resolve.
2. **Effects honor params** (where assertable without a renderer):
   - `merge_burst` with a count creates a `GPUParticles2D` whose `amount` reflects count+tier.
   - `treefall_crack` shake uses the amp / hitstop uses the secs (assert via the created tween
     or via a seam; at minimum assert the call does not error with custom values).
   - `squash_pop(node, strength)` with strength ≠ 1 changes the first keyframe vs strength == 1.
   - `tick(label, to, dur)` uses `dur` (assert the tween duration or end-state).
3. **Persistence round-trip** (workbench test): set a knob in `_params["rush_fx"]`, trigger the
   save, reload config, assert the knob persisted; confirm it is NOT in `TEST_KEYS["rush_fx"]`.
4. **Workbench builds per-effect controls**: selecting `rush_fx` yields one ▶ Replay button per
   effect plus the knob slider rows (assert button/slider counts by node name).
5. **Live forwarding**: `explore_rush` passes the resolved knob values (assert via a lightweight
   seam or source-contains check that each call site reads `RushFx.knob(_fx, …)`).

Run `make test-grove` (and `make test-fast` for the engine `fx`/`rush` slices) after each step;
full `make test` before merge.

## Risks

- Changing `rush_fx.gd` effect signatures touches both the workbench and `explore_rush.gd`. The
  compiler (parse errors) + tests catch any missed call site.
- `fx.gd` `squash_pop`/`tick` are shared by the whole game; the new params default to current
  behavior, and existing FX tests guard against regressions.
