# Layered level badge + workbench tuner

Date: 2026-06-23
Status: implemented (v2, 30-tier scheme) — all 21 gated suites pass (853 tests); verified in the
live HUD chip + level dialog. Tune the composition in the workbench (`make workbench` → Level badge).

## Goal

Replace the single pre-baked level medal with a **layered emblem** built from cut art parts —
**circle, leaf (wreath), flower, acorn, gem** — plus a centered level number. Build a workbench
component to position/scale the parts and preview the progression, and wire the tuned result into
the live game (HUD chip, locked-cell gates, level dialog) through the existing config path so
"tune in workbench" and "ship in game" are one code path.

Source art (already committed):
- `games/grove/assets/_originals/ui/lvls_asset.png` — 6 rows × 5 columns
  (col 1 circle/coin, col 2 wreath **[discard]**, col 3 flower, col 4 acorn, col 5 gem).
- `games/grove/assets/_originals/ui/lvls_leafs.png` — 6 laurel wreaths (the leaf part).

## The progression — 30 tiers (5 groups × 6 stages)

A tier is `(group, stage)` with `group = tier ÷ 6` (0–4) and `stage = tier mod 6 + 1` (1–6).
Each part present in a group is drawn at the group's current `stage` frame. *Tier is 0-based
internally (0–29, like the existing `level_badge_index`); the tables below show 1–30 for
readability.*

| Group | Tiers | Parts shown (each at stage 1→6) |
|---|---|---|
| 0 | 1–6  | leaf |
| 1 | 7–12 | leaf + flower (bottom) |
| 2 | 13–18 | leaf + acorn (bottom) |
| 3 | 19–24 | leaf + flower (bottom) + gem (top) |
| 4 | 25–30 | leaf + acorn (bottom) + gem (top) |

### Level → tier (banded pacing)

`data/level_badges.json` bands: `[{tiers:10, levels_per_tier:1}, {tiers:10, levels_per_tier:3},
{tiers:10, levels_per_tier:6}]`, `tier_count: 30`.

| Band | Tiers | Levels |
|---|---|---|
| 1 | 1–10 | 1–10 |
| 2 | 11–20 | 11–40 |
| 3 | 21–30 | 41–100 |

Past level 100 the tier clamps at 30. The **exact level number** is always printed in the center.

### Decisions baked in (override at review)

1. **Circle/coin is NOT in any group**, so it is extracted (req 1) and positionable in the
   workbench (req 4) but not shown by the default progression. (Can be added as an always-on
   base if wanted.)
2. **Within a group, all its parts grow together** (share the group's stage 1→6). Consequence:
   the wreath restarts at its small frame when a new group begins. (Literal reading of the tier
   list. Alternative: hold earlier parts at full frame.)
3. **Bands 2 and 3 are 10 tiers each** (only band 1's count was given): levels 11–40 then 41–100.

## Key facts grounding the design

- **Config path is production.** The shipping game reads
  `games/grove/tools/ui_workbench_settings.json` at runtime: `Kit.load_config(Kit.CONFIG_PATH)`
  → `Kit.<component>_opts_from_config(cfg)` → `Kit.<component>(opts)`. The workbench previews the
  *same* builder. (Pattern reference: `gold_currency_pill`.)
- **Existing badge.** `Look.make_level_badge(level, px, num_font)` in `engine/scripts/ui/skin.gd`
  builds panel + cream disc + `lv_frame` TextureRect + `lv_num` Label. Callers: HUD top-left chip
  (`engine/scripts/ui/hud.gd`), locked-cell gate (`Kit.slot_cell`), and the level dialog uses a
  *separate* `level_medallion`/`level_dialog`. Level→index is banded data in
  `data/level_badges.json` via `Look.level_badge_index(level)`.
- **Intake.** `make intake` slices via `plan.json`; `grid` → row-major tiles; the `icon` post-op
  trims + **centers** in a square (wrong anchor — extended below).

## Architecture

```
ui_workbench_settings.json ─load_config─▶ Kit.level_badge_opts_from_config(cfg)
                                                  │ opts: per-part x/y/scale, num_*, size
        ┌──────────────────────────────────────────┤
        ▼                                           ▼
 ui_workbench_view (preview + sidebar)      Look.make_level_badge(level, px)
   test-only: level slider, layer pick           │ level→tier (banded)
        ▼                                           ▼
          Kit.level_badge(opts, tier, level, px, num_font)  ── shared builder ──▶ Control
                                  group=tier÷6, stage=tier%6+1; draws the group's parts at `stage`,
                                  bottom-anchored, each at its global offset/scale, + lv_num on top
```

### Part A — Extraction (intake) → 30 sprites

Add a **bottom anchor** to the icon post-op so cut parts share a baseline:
- `games/tools/process_icon.gd`: accept an `anchor` arg (`center` default, `bottom`); when
  `bottom`, place the resized crop at `y = th - nh - pad` instead of `(th - nh)/2`. Default
  behavior unchanged.
- `games/tools/intake_apply.py`: extend `parse_post` to accept `icon:<size>:bottom`, passing the
  anchor through `icon_args`. Additive grammar; `icon:512` unchanged.

Two `grid` plans in `games/grove/assets/_new/` (copy the two PNGs there; archive back to their
current `_originals/ui/` paths). Verify tile indices with a scratch slice before naming.
- `lvls.plan.json` (`_new/lvls_asset.png`): keep columns 1,3,4,5 across all 6 rows (24 tiles),
  each `post: "icon:512:bottom"`. Discard column-2 (wreath) tiles. →
  `ui/lvl_parts/{circle,flower,acorn,gem}_{1..6}.png`.
- `lvls_leafs.plan.json` (`_new/lvls_leafs.png`): 6 tiles → `ui/lvl_parts/leaf_{1..6}.png`,
  `post: "icon:512:bottom"`.

Result: **30 sprites** in `ui/lvl_parts/` (circle included per req 1, though unused by the
default progression).

### Part B — Shared builder (`ui_workbench_kit.gd`)

- Constant `LEVEL_BADGE_GROUPS := [["leaf"], ["leaf","flower"], ["leaf","acorn"],
  ["leaf","flower","gem"], ["leaf","acorn","gem"]]` — the 5 groups above. Easy to edit.
- `level_badge_opts_from_config(cfg) -> Dictionary` reads `cfg["level_badge"]` with defaults:
  per part P in {circle,leaf,flower,acorn,gem}: `P_x`, `P_y`, `P_scale`; plus `size` (common box
  as % of `px`, default 100), `num_size`, `num_x`, `num_y`.
- `level_badge(opts, tier, level, px, num_font := -1) -> Control`:
  - Root `Control` px×px, mouse-ignored. `group = tier÷6`, `stage = tier mod 6 + 1`.
  - Render order leaf → flower → acorn → gem (→ circle if ever added), then `lv_num` on top.
    For each part in `LEVEL_BADGE_GROUPS[group]`: a `TextureRect` of
    `ui/lvl_parts/<part>_<stage>.png`, `STRETCH_KEEP_ASPECT_CENTERED`, fitted into the common box
    **bottom-aligned**, offset by `(P_x, P_y)`, sized by `P_scale`. Named `lv_<part>`.
  - Centered `lv_num` Label: `str(level)`, font `num_font>0 ? num_font : num_size` (digit-stepped
    like `_lv_badge_font`), offset `(num_x, num_y)`.
  - Missing-art fallback: honey-token coin + number (reuse existing look).

### Part C — Workbench component (`ui_workbench_view.gd`)

New id `"level_badge"` (distinct from `"level"`, `"tiers"`). Register in `IDS`, `COLUMNS`,
`CAPTIONS`, `_params`.
- `_make_element`: resolve opts, compute tier via the real `Look.level_tier(level)`, build via
  `Kit.level_badge`. **Selected part is force-shown** on top of the current composite (at the
  current stage) so any part — including the otherwise-hidden circle — can be positioned.
- Sidebar:
  - **Part** `_option_row` (circle/leaf/flower/acorn/gem) → test-only `_edit_part`; rebuilds the
    sidebar so X/Y/Scale bind to that part's keys.
  - `_slider_row` X, Y, Scale for the selected part (`<part>_x/_y/_scale`).
  - **Number** group: `num_size`, `num_x`, `num_y`.
  - **Global**: `size`.
  - **Test only** (`TEST_KEYS`, not saved): `level` slider (1–110) + a small readout of the
    resulting tier/group/stage; `_edit_part`.
- Saved keys: per-part x/y/scale, `num_size`, `num_x`, `num_y`, `size`.

### Part D — Wire into the game

- `engine/scripts/ui/skin.gd`:
  - `level_tier(level) -> int` (1–30) from `data/level_badges.json` bands (reuse the existing
    banded walk; rename/keep `level_badge_index` returning 0–29).
  - Rewrite `make_level_badge(level, px, num_font)` to load cfg, resolve opts, compute tier,
    return `Kit.level_badge(opts, tier, level, px, num_font)`. **Signature unchanged** so HUD chip
    and locked-cell gate keep working.
- `engine/scripts/ui/hud.gd`: live level-up path currently swaps one `lv_frame` on tier flip;
  change to rebuild the layered badge when the **tier** flips, still updating `lv_num`.
- Level dialog: point `level_medallion`/`level_dialog` at `Kit.level_badge`.

### Part E — Tests

- `engine/tests/level_badge_tests.gd` (extend): the 24 used + circle parts exist in
  `ui/lvl_parts/`, resolve, and are alpha-cut; `level_tier` monotonic, banded 10/10/10, clamps
  at 30; tier→(group,stage) decomposition correct.
- Resolver/builder: `level_badge_opts_from_config({})` returns every key with defaults;
  `Kit.level_badge(opts, tier, level, px)` yields the group's `lv_<part>` TextureRects + `lv_num`;
  bottom-anchor math places content on the baseline.
- Grove UI suite: HUD chip + slot cell + level dialog still build with the new badge.

## Out of scope

- Workbench-authored tier schedule (groups are a code constant), per-part visibility toggles
  (scale→0 hides), configurable z-order, stage-flip animation.
- Deleting legacy `ui/lvl/badge_NN.png` (left unused; separate cleanup task).

## Risks

- HUD live-update assumes a single frame; rebuilding the layered badge on tier flip must not leak
  nodes or drop the tap handler.
- Bottom-anchored fit across parts of different aspect ratios needs the common-box math right so
  parts stay on-baseline; covered by a test.
- The three baked-in decisions above (circle hidden, grow-together resets, 10/10/10 split) — easy
  to flip, but confirm at review.
