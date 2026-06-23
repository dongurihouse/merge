# Layered level badge + workbench tuner

Date: 2026-06-23
Status: proposed (awaiting review)

## Goal

Replace the single pre-baked level medal with a **layered emblem** composed of five
independently-positioned art parts — **circle, leaf (wreath), flower, acorn, gem** — plus a
centered level number. Build a workbench component to compose and tune it, and wire the tuned
result into the live game (HUD chip, locked-cell gates, level dialog) through the existing
config path so "tune in workbench" and "ship in game" are one code path.

Source art (already committed):
- `games/grove/assets/_originals/ui/lvls_asset.png` — 6 rows × 5 columns
  (col 1 circle/coin, col 2 wreath **[discard]**, col 3 flower, col 4 acorn, col 5 gem).
- `games/grove/assets/_originals/ui/lvls_leafs.png` — 6 laurel wreaths (the leaf part).

## Key facts grounding the design

- **Config path is production.** The shipping game reads `games/grove/tools/ui_workbench_settings.json`
  at runtime: `Kit.load_config(Kit.CONFIG_PATH)` → `Kit.<component>_opts_from_config(cfg)` →
  `Kit.<component>(opts)`. The workbench previews the *same* builder. (Pattern reference:
  `gold_currency_pill` in `games/grove/tools/ui_workbench_kit.gd`.)
- **Existing badge.** `Look.make_level_badge(level, px, num_font)` in
  `engine/scripts/ui/skin.gd` builds a panel + cream disc + `lv_frame` TextureRect + `lv_num`
  Label. Callers: HUD top-left chip (`engine/scripts/ui/hud.gd`), locked-cell gate
  (`Kit.slot_cell`), and the level dialog uses a *separate* `level_medallion` /`level_dialog`
  in the kit. Level→badge index today is banded data in `data/level_badges.json` via
  `Look.level_badge_index(level)`.
- **Intake.** `make intake` slices via `plan.json`. `grid` category → row-major tiles. The
  `icon` post-op trims + **centers** in a square (wrong anchor for this feature).

## Decisions (from the user)

1. Number drives stage; **per-layer x/y AND scale**; wire into the real badge.
2. Level→stage mapping reuses the existing pacing (12 tiers @1 level, 12 @3, 12 @6 = 36 tiers
   over levels 1–120). **The art has only 6 stages, so 6 tiers collapse into 1 art stage.**
3. Switch the level **dialog medallion** to the layered badge in this pass too.

### ⚠️ Open point for review — 6 art stages vs 36 tiers

The art provides **6** stages per part, but the requested pacing describes **36** tiers. This
spec collapses 6 tiers → 1 art stage (table below). The badge art therefore changes **6 times**
across levels 1–120, with the exact level number always printed in the center. *36 visually
distinct badges is not achievable from 6 art frames.* If the intent was 36 distinct looks, stop
and rethink before implementation.

| Art stage | Tier range | Level range |
|---|---|---|
| 1 | 0–5 | 1–6 |
| 2 | 6–11 | 7–12 |
| 3 | 12–17 | 13–30 |
| 4 | 18–23 | 31–48 |
| 5 | 24–29 | 49–84 |
| 6 | 30–35 | 85+ |

## Architecture

```
ui_workbench_settings.json  ──load_config──▶  Kit.level_badge_opts_from_config(cfg)
                                                        │  opts (per-layer x/y/scale, num_*, size)
        ┌───────────────────────────────────────────────┤
        ▼                                                ▼
 ui_workbench_view (preview + sidebar)          Look.make_level_badge(level, px)
        │ test-only: level slider                        │ level→stage (banded)
        ▼                                                ▼
              Kit.level_badge(opts, stage, level, px, num_font)  ── shared builder ──▶ Control
                                                                 (5 bottom-anchored TextureRects + lv_num)
```

### Part A — Extraction (intake)

Add a **bottom-anchor / tight-trim** option to the icon post-op so cut parts share a baseline:
- `games/tools/process_icon.gd`: accept an `anchor` arg (`center` default, `bottom`); when
  `bottom`, place the resized crop at `y = th - nh - pad` instead of `(th - nh)/2`. Keep
  existing default behavior untouched.
- `games/tools/intake_apply.py`: extend `parse_post` to accept `icon:<size>:bottom` (and pass
  the anchor through `icon_args`). New grammar is additive; `icon:512` unchanged.

Two `grid` plans authored in `games/grove/assets/_new/` (copy the two PNGs there first; archive
back to their current `_originals/ui/` paths):
- `lvls.plan.json` (source `_new/lvls_asset.png`): keep tiles in columns 1,3,4,5 across all 6
  rows (24 tiles), each `post: "icon:512:bottom"`. Discard column-2 tiles. Output to
  `ui/lvl_parts/{circle,flower,acorn,gem}_{1..6}.png`.
- `lvls_leafs.plan.json` (source `_new/lvls_leafs.png`): 6 tiles → `ui/lvl_parts/leaf_{1..6}.png`,
  `post: "icon:512:bottom"`.

Tile→name mapping is verified by a scratch slice first (read indices before naming, per
`docs/design/asset-intake.md`). Result: **30 sprites** in `ui/lvl_parts/`.

### Part B — Shared builder (`ui_workbench_kit.gd`)

- `level_badge_opts_from_config(cfg) -> Dictionary` reads `cfg["level_badge"]` with defaults:
  - per layer L in {circle, leaf, flower, acorn, gem}: `L_x`, `L_y` (px offsets), `L_scale`
    (percent of the common box).
  - `size` (the common layer box as a percent of `px`, default 100), `num_size` (level font),
    `num_x`, `num_y` (the number's "side and margin").
- `level_badge(opts, stage, level, px, num_font := -1) -> Control`:
  - Root `Control` sized `px`×`px`, mouse-ignored.
  - For each layer in fixed z-order **circle → leaf → flower → acorn → gem**: a `TextureRect`
    of `ui/lvl_parts/<layer>_<stage>.png`, `STRETCH_KEEP_ASPECT_CENTERED`, fitted into the
    common box, **bottom-aligned**, then offset by `(L_x, L_y)` and sized by `L_scale`.
    Name them `lv_<layer>` for live refresh.
  - Centered `lv_num` Label on top: text `str(level)`, font `num_font` if > 0 else `num_size`
    (auto-stepped by digit count, mirroring `_lv_badge_font`), offset by `(num_x, num_y)`.
  - Missing-art fallback: honey-token coin + number (reuse existing fallback look).

### Part C — Workbench component (`ui_workbench_view.gd`)

New id `"level_badge"` (distinct from `"level"`, `"tiers"`).
- Register in `IDS`, `COLUMNS`, `CAPTIONS`, `_params` defaults.
- `_make_element("level_badge")`: resolve opts from `_params`, build via `Kit.level_badge` at a
  preview `px`, using the **real** `level→stage` function on the test level.
- Sidebar:
  - **Layer** `_option_row` (circle/leaf/flower/acorn/gem) → sets a test-only `_edit_layer`,
    rebuilds the sidebar so the next sliders bind to that layer's keys.
  - `_slider_row` X, Y, Scale for the selected layer (`<layer>_x`, `<layer>_y`, `<layer>_scale`).
  - **Number** group: `num_size`, `num_x`, `num_y`.
  - **Global**: `size`.
  - **Test only** (in `TEST_KEYS`, not saved): `level` slider (1–120) and `_edit_layer`.
- Saved config keys: all per-layer x/y/scale, `num_size`, `num_x`, `num_y`, `size`.

### Part D — Wire into the game

- `engine/scripts/ui/skin.gd`:
  - Add `level_stage(level) -> int` returning 1–6 (derived from `level_badge_index` ÷ 6 + 1,
    clamped), backed by `data/level_badges.json` (retune `badge_count`/bands so the index spans
    0–35 as today; the divide-by-6 yields 6 stages). The 36 `badge_NN.png` become unused.
  - Rewrite `make_level_badge(level, px, num_font)` to: load cfg, resolve opts, compute stage,
    return `Kit.level_badge(opts, stage, level, px, num_font)`. **Signature unchanged**, so HUD
    chip and locked-cell gate keep working.
- `engine/scripts/ui/hud.gd`: the live level-up path currently swaps a single `lv_frame` when
  the tier flips (`level_badge_index`). Change it to rebuild the layered badge (or refresh all
  `lv_<layer>` textures) when **stage** flips, and keep updating `lv_num`.
- Level dialog: point `level_medallion` / `level_dialog` at `Kit.level_badge` so the dialog
  shows the same layered emblem.

### Part E — Tests

- `engine/tests/level_badge_tests.gd` (extend): 30 `ui/lvl_parts/*` sprites exist, resolve, and
  are alpha-cut; `level_stage` is monotonic and clamps at 6 with the table above.
- `engine/tests/` (resolver/builder): `level_badge_opts_from_config({})` returns every key with
  defaults; `Kit.level_badge(...)` yields a node tree with the 5 `lv_<layer>` TextureRects + a
  `lv_num` Label; bottom-anchoring math places content on the baseline.
- Grove UI suite: HUD chip + slot cell + level dialog still build without error using the new
  badge.

## Out of scope

- Per-layer visibility toggles (scale→0 hides) and configurable z-order (fixed order).
- Deleting the legacy `ui/lvl/badge_NN.png` art (left unused; cleanup is a separate task).
- Animation/transition when the stage flips.

## Risks

- **6-vs-36 mismatch** (see open point) — the one thing that could invalidate the approach.
- HUD live-update assumes a single frame; rebuilding the layered badge on stage flip must not
  leak nodes or drop the tap handler.
- Bottom-anchored fit across parts of different aspect ratios needs the common-box math right so
  parts don't drift off-baseline; covered by a test.
