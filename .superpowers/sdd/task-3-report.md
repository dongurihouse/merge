# Task 3 report — workbench `action_button` component (replace `home_button`)

## Summary

Registered the `action_button` gallery component in `games/grove/tools/ui_workbench_view.gd` and
removed the `home_button` gallery component (id, column entry, dependents entry, test-keys entry,
caption, shadow-wired entry, on-by-default entry, config-block default, `_make_element` case,
preview builder, and sidebar case). The `Kit.home_button` FUNCTION in `ui_workbench_kit.gd` was left
untouched — it is still the live builder `engine/scripts/scenes/map.gd` calls for its bottom-nav
tiles and back button, and `engine/scripts/scenes/board.gd` references for its Home/Bag well sizing.

## Deviations from the brief (and why)

1. **`DEFAULTS` access form.** The brief's Step 1 assumed `DEFAULTS` was either a `const` dict or a
   `func`. Neither is true: the schema lives in the **instance method** `_default_params()`,
   declared on the shared base `workbench_view.gd` and overridden in `ui_workbench_view.gd` (line
   194). `IDS` IS a top-level `const` on `ui_workbench_view.gd`, so `View.IDS` works directly on the
   loaded script with no instance. For the config-block check, the test instantiates
   `View.new()._default_params()`. `.new()` alone (no `add_child`) never enters the SceneTree, so
   `_ready()` — which builds the entire two-column gallery UI, loads the settings JSON, etc. — never
   runs; only `_init()` runs, which just calls `_default_params()`/`_default_selected()`. Confirmed
   cheap and safe headlessly (the full suite run is ~1s for this file).

2. **Preview-builder name collision.** The brief's Step 4 names the new preview builder
   `_action_bar_preview(p: Dictionary)`. That name was already taken: line 738 (pre-edit: line 756)
   already defines `func _action_bar_preview() -> Control:` — the **`info_bar`** component's own
   preview (the bottom action bar with Home/ⓘ/selected-item/Bag). Two funcs with the same name is a
   GDScript parse error (no overloading). Renamed the new one to `_action_button_row_preview(p)`
   throughout (declaration + the `_make_element` case).

3. **Fallout from removing the `"home_button"` config key.** `info_bar`'s own preview
   (`_action_bar_preview()`) built its placeholder Home/Bag well buttons by reading
   `_params["home_button"]` (to call `Kit.home_button_opts_from_config`). Once the `"home_button"`
   key is gone from `_params` entirely (Step 3), that lookup would error at runtime (missing
   dictionary key) every time the `info_bar` component or its dependents render. Fixed by dropping
   the `"home_button": _params["home_button"]` entry from the cfg dict passed to
   `Kit.home_button_opts_from_config` — the function's own `cfg.get("home_button", {})` fallback
   then supplies its built-in defaults (which is what that block's values mirrored anyway), while
   `"badge"` and `"shadow"` still come from the shared params as before. This is a workbench-only
   preview accessory (the info_bar's own Home/Bag placeholders); `Kit.home_button` and
   `Kit.home_button_opts_from_config` themselves are untouched and still the live map.gd/board.gd
   path. Also confirmed the on-disk `games/grove/tools/ui_workbench_settings.json` still contains a
   stale `"home_button"` block from before — harmless: `_load_settings()` only iterates
   `_params.keys()` (the schema) when merging the saved file, so the orphaned key is silently
   ignored and never resurrected.

4. **Removed `HOME_ICONS` const** (line ~62-64, pre-edit). It was only referenced by the removed
   `home_button` sidebar case's `_option_row("Icon", "icon", HOME_ICONS)`; grepped the whole repo —
   no other reference — so it's genuine dead code now and was deleted rather than left orphaned.

## Signatures verified against real definitions (not just brief text)

- `_cut_paper_section(target: String) -> void` (ui_workbench_view.gd:1784, pre-edit) — matches
  `_cut_paper_section("action_button")` call.
- `_option_row(label: String, key: String, options: Array, rebuild_sidebar := false, target := "") -> Control`
  (workbench_view.gd:580) — matches the 3-arg calls used (tint rows + the spotlight-role row), which
  default `target` to `_selected` (== `"action_button"` when this component is selected).
- `_slider_row(spec: Array, target := "") -> Control` (workbench_view.gd:452) — matches.
- `_toggle_row(label: String, key: String, rebuild_sidebar := false, target := "") -> Control`
  (workbench_view.gd:561) — matches `_toggle_row("Shadow", "shadow")`.
- `_group_header(title: String, saved: bool) -> void` / `_section_header(title: String) -> void`
  (workbench_view.gd:435/444) — match.
- `Kit.PAPER_SURFACES.keys()` (ui_workbench_kit.gd:40) yields the role-name list for the tint
  dropdowns; `Kit.ACTION_ROLES` (ui_workbench_kit.gd:55) is `["map", "residents", "daily", "vault",
  "mail", "play", "home", "bag"]` — used both for the tint-row loop and the preview row/spotlight
  dropdown.
- `Kit.action_button(role, size, action, opts)` and `Kit.action_button_opts_from_config(cfg)`
  (ui_workbench_kit.gd:316, 2145) — signatures match the preview builder's calls exactly.

## TDD evidence

**RED** (`make test-one SUITE=engine/tests/action_button_tests`, before the view edits):
```
  PASS  action_button returns a Button
  ... (8 pre-existing PASSes for Kit.action_button/action_button_opts_from_config)
  FAIL  the workbench registers the action_button component
  FAIL  the workbench no longer registers the home_button component
  FAIL  action_button ships a saved config block
  FAIL  the home_button config block is gone
== 9 passed, 4 failed ==
```

**GREEN** (same command, after all edits):
```
== 13 passed, 0 failed ==
```

## Visual verification

`make shot-workbench OUT=/tmp/action_button.png EL=action_button` rendered a horizontal row of 8
tiles (map, residents/hat, daily/gift, vault/piggy, mail/envelope, play/arrow, home/house,
bag/satchel). Read the PNG directly:

- Every tile shares the same rugged, hand-torn cream deckled edge (irregular border, not a clean
  rounded rect) — the shared `CutPaperPanel` surface.
- Each tile's glyph sits centered, fully opaque, correctly sized (~50% of the tile) — no blank or
  stretched tiles.
- All 8 tiles use the calm "cream" paper fill, matching the `DEFAULTS` block's flattened
  `tint_<role>: "cream"` for every role.
- Every tile casts a soft drop shadow (visible bottom-right offset against the blue gallery
  background).
- Even spacing (12px separation) between tiles, consistent with the `HBoxContainer` separation set
  in the preview builder.

No defects found — nothing to fix before commit.

## Fast/full test sweeps

- `make test-fast`: 21 suites, 810 passed, 0 failed.
- `make test`: 26 suites, 1449 passed, 0 failed (includes the grove suites, unaffected by this
  workbench-only change).

## Files changed

- `games/grove/tools/ui_workbench_view.gd` — component swap (see Deviations above for the exact
  edit list); net -20 lines (140 changed: fewer lines because the removed `home_button` sidebar case
  and `HOME_BAR_TILES`/`_home_bar_preview` were larger than their `action_button` replacements).
- `engine/tests/action_button_tests.gd` — added the 4 new assertions (component-swap check) as
  assertions 10-13, adapted to the real `_default_params()` access form.

## Self-review

- Confirmed no other file references the removed identifiers: grepped the repo for `HOME_ICONS`,
  `HOME_BAR_TILES`, `_home_bar_preview` — all clear (only the deleted declarations/call site
  existed).
- Confirmed `Kit.home_button`, `Kit.home_button_opts_from_config`, and `Kit.home_bar_tile_opts`
  (the live map.gd/board.gd path) are untouched in `ui_workbench_kit.gd` — grep shows the same call
  sites in `engine/scripts/scenes/map.gd` (lines 2321, 2439, 2570) and `board.gd` (a comment
  reference at line 75) as before this change.
- Confirmed the leftover `"home_button"` block in the on-disk `ui_workbench_settings.json` is
  inert under `_load_settings()`'s schema-driven merge loop (iterates `_params.keys()`, not
  `data.keys()`).

## Concerns

- None blocking. The one open, out-of-scope item: `ui_workbench_settings.json` still carries a
  stale `"home_button"` block on disk. It's harmless (ignored by the loader) but could be trimmed
  in a future housekeeping pass; not touched here since the brief didn't ask for a settings-file
  migration and the merge-only loader makes it inert either way.
