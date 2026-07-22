# Task 2 report: `Kit.action_button` builder + config reader

## Status: DONE

## What was implemented

- `games/grove/tools/ui_workbench_kit.gd`:
  - Added `ACTION_ROLES`, `ACTION_GLYPHS`, `ACTION_TINT_DEFAULTS`, `ACTION_BUTTON_CP_DEFAULTS`
    constants right after the `PAPER_SURFACES` block (before `BUTTON_PATCH`).
  - Added `static func action_button(role, size, action, opts) -> Button` right after
    `_apply_deckle_button_surface` (before `meadow_paper_style`) — a flat `Button` wearing a
    code-drawn `CutPaperPanel` (`ActionButtonDeckleSurface`) filled by its per-button paper-role
    tint, with a centered glyph `TextureRect` on top, press-darken feedback, and
    `Look.add_press_juice`.
  - Added `static func action_button_opts_from_config(cfg) -> Dictionary` right after
    `_cut_paper_legacy` (end of the `cut_paper_opts_from_config` block) — reads the `action_button`
    config block into `{cp, tints, icon_scale, shadow, shadow_params}`.
- `engine/tests/action_button_tests.gd` (new): headless `SceneTree` suite, 9 assertions.
- `Makefile`: appended `engine/tests/action_button_tests` to `ENGINE_TESTS`.

## TDD evidence

**RED** — `make test-one SUITE=engine/tests/action_button_tests` before Steps 3-5:
```
SCRIPT ERROR: Parse Error: Static function "action_button()" not found in base "res://games/grove/tools/ui_workbench_kit.gd".
SCRIPT ERROR: Parse Error: Static function "action_button_opts_from_config()" not found in base "res://games/grove/tools/ui_workbench_kit.gd".
ERROR: Failed to load script "res://engine/tests/action_button_tests.gd" with error "Parse error".
```

**GREEN** — `make test-one SUITE=engine/tests/action_button_tests` after Steps 3-5 (+ one fix, see
below):
```
  PASS  action_button returns a Button
  PASS  the button wears a code-drawn CutPaperPanel surface
  PASS  the surface is the shared cut_paper.gd panel
  PASS  the map tile fills with its sky paper-role tint
  PASS  the map tile composites its transparent glyph in the middle
  PASS  reader round-trips the edge corner
  PASS  reader normalizes deckle_freq (5 → 0.05)
  PASS  reader round-trips the per-button tint palette
  PASS  reader normalizes icon_scale (55 → 0.55)
== 9 passed, 0 failed ==
```

**Full sweep** — `make test-fast`: `21 suites · 806 passed · 0 failed` — `ALL SUITES PASSED`.

## Helper-signature verification (before implementing)

Checked every consumed symbol against its real definition; all matched the brief's assumptions,
no adaptation needed:
- `_apply_deckle_button_surface(button, fill, corner, cp_opts, margins, enabled)` at line 245 —
  confirms the pattern of `set_meta(SHADOW_CORNER_META, corner)`, transparent styleboxes,
  `load(CUT_PAPER).new()` + `.configure(cp_opts, fill, null, cut_paper_tile())` + `.corner =`,
  press-darken via `button_down`/`button_up`.
- `cut_paper_opts_from_config(cfg, block, overrides)` at line 2024, `CUT_PAPER_KNOBS` incl.
  `deckle_freq` marked `"freq": true` (divide raw by 100) — the brief's reader relies on this and
  it is correct as written.
- `_meadow_shadow_rect(corner, params) -> Panel` (line 304), `Look.shape_corner(node, fallback)`
  (skin.gd:738), `Look.SHADOW_CORNER_META` (skin.gd:736), `_icon_rect(tex, px) -> Control`
  (line 444), `Game.art(rel) -> String` (game.gd:28), `cut_paper_tile()` (line 2050),
  `load_config(path) -> Dictionary` (line 4015), `CONFIG_PATH` (line 5458 pre-edit),
  `CUT_PAPER` (line 1999 pre-edit), `PAPER_SURFACES` (line 40), `Look.shadow_params(cfg)`
  (skin.gd:679), `Look.add_press_juice(b)` (skin.gd:388) — all present with the exact signatures
  the brief's code calls.

## One adaptation from the brief (found via the RED/GREEN loop, not the pre-check)

The brief's glyph line used `clean_tex_path(Game.art(glyph_rel), 192)`. Test assertion 3 (`the map
tile composites its transparent glyph in the middle`) checks
`tr.texture.resource_path.findn("glyph_map") != -1`, which failed under GREEN even after the
builder/reader code was in place — 8/9 passed, 1 failed.

Root cause: `clean_tex_path` only preserves `resource_path` when a pre-baked mirror exists at
`baked_path(...)` (loaded via `load()`); Task 1 only produced the raw
`games/grove/assets/ui/nav/glyphs/glyph_*.png` files with no `baked/` mirror yet, so
`clean_tex_path` falls through to its "live fallback" branch, which synthesizes a fresh
`ImageTexture.create_from_image(...)` with an empty `resource_path` — this is documented in the
function's own live-fallback comment ("defringe + feather on the main thread") and matches
`_icon_tex`'s comment "defringe + feather the rough-cut icon", i.e. `clean_tex_path` targets
rough-cut sprites, not the already-clean glyph family.

Fix: load the glyph directly with `load(Game.art(glyph_rel)) as Texture2D` instead of routing it
through `clean_tex_path`. This matches an existing pattern already used elsewhere in the file for
pre-clean assets (e.g. `load(CUT_PAPER_TILE) as Texture2D if ResourceLoader.exists(...) else null`
at lines 1849/2157) and avoids unneeded per-pixel defringe/feather work on sprites Task 1 already
generated clean. Added an inline comment explaining the choice. If a later task adds a baked
mirror for the glyph set, this call site can switch back to `clean_tex_path` without changing the
test.

## Second fix: test-runner summary line format

The brief's test printed `"\n  action_button: %d passed, %d failed" % [...]`. Under
`make test-one` this test passes 9/9 and exits 0, but under the parallel `make test-fast` runner
(`engine/tools/run_suites.py`) it was reported as `CRASH` — the runner's `SUMMARY` regex is
`== (\d+) passed, (\d+) failed ==`, and every other suite in the repo prints exactly that
`"== %d passed, %d failed =="` convention (verified by grepping all 19 other
`engine/tests/*.gd` files). Since the brief's print line didn't match, `run_suites.py` treated the
suite as never having "reached its summary" (crashed), regardless of exit code / pass count.

Fixed by changing the test's final print to `"== %d passed, %d failed =="`, matching the
established convention. Re-ran `make test-fast`: `21 suites · 806 passed · 0 failed`,
`ALL SUITES PASSED`.

## Files changed

- `games/grove/tools/ui_workbench_kit.gd` (constants, `action_button`, `action_button_opts_from_config`)
- `engine/tests/action_button_tests.gd` (new)
- `Makefile` (registered suite)

Commit: `96ba5edf` "feat(kit): shared code-drawn action_button (rugged edge + centered glyph) + config reader"

## Self-review findings

- No preload cycle introduced: `action_button` uses `load(CUT_PAPER)` (a string path, not
  `preload`), the same pattern `_apply_deckle_button_surface` already uses — consistent with the
  file's existing cycle-avoidance approach.
- The builder's `cp` default (when `opts.cp` is absent) calls
  `cut_paper_opts_from_config(load_config(CONFIG_PATH), ...)`, re-reading the config file from
  disk per call with no options passed — mirrors the existing pattern in the file (not a new
  concern, but worth flagging: callers that build many action buttons per frame should pass `cp`
  explicitly via `action_button_opts_from_config(cfg)` once, not rely on the per-call default).
- `action_button_opts_from_config`'s `tints` loop only covers `ACTION_ROLES`, so a `tint_<role>`
  key for an unlisted role is silently ignored — matches the brief exactly, not a regression.

## Concerns

- None blocking. The two adaptations above (direct `load()` for the glyph texture, and the
  `==N passed, N failed==` summary line) are both narrow, well-precedented fixes needed to satisfy
  the brief's own test and the shared test-runner convention — flagging them here per the
  verification-notes instruction rather than silently patching.

Note: this file previously held a report for an unrelated task ("Fairy Hollow Original Mock V4 —
Task 2"); that content has been replaced with this Task 2 (`Kit.action_button`) report, per this
task's brief which names this exact path as the report destination.
