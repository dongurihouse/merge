# Acorn Forest: Merge! (Donguri Merge) — project notes

## Art & assets — read the guide first

**Before generating OR processing any asset** (item tiers, icons, generators, characters, scenes,
textures), read `docs/design/art-style-guide.md` — the single source of truth for art direction,
palette, canvas contracts, prompt scaffolds, cutting/keying, intake workflow, and the review checklist.
Do not hand-roll a keyer or a prompt; the guide points at the owned deterministic tools.

Raw art lands in `games/grove/assets/_new/`. When asked to process intake or "pick up the new art,"
follow the guide's intake workflow: open and **classify** each drop, author a `plan.json`, run
`make intake`, verify, archive. The split is load-bearing: **scripts are deterministic** (every pixel
op + every file move); **all judgment — classification, naming, params — goes in the plan**, authored
by the agent. Scripts never guess. Raws are archived, never deleted. Map scenes are handed off to the
scene pipeline in the guide, not auto-processed.

## Seeing a change — headless first, then ONE batched capture

Screenshots are the expensive last resort. Every capture is a real-renderer Godot launch on the
owner's machine, and the owner is at the keyboard.

1. **Assert it headlessly.** The suites build the real node tree with no window at all — a size, a
   position, an order, a count, a colour is a test, not a screenshot. Reach for `make test-grove`
   (or a new assertion in the matching suite) before reaching for a PNG.
2. **When you must LOOK, batch it.** Write a plan and take every shot you need in one launch:

   ```bash
   printf '%s\n' 'grove hud /tmp/hud.png' 'grove played /tmp/played.png' 'map fresh /tmp/map.png' > /tmp/p.txt
   make shot-batch PLAN=/tmp/p.txt
   ```

   Batchable tools: `grove`, `map`, `widget`. One launch instead of N (~1.3 s of boot each), and one
   interruption instead of N. `make shot-grove` / `-map` / `-widget` / `shot` stay for the single
   capture you did not plan for.
3. **Compare like with like.** A batched capture and a single-process capture agree for a static
   fixture, but a mode still ANIMATING at the capture instant can land on a different phase in a warm
   process (measured: `grove ladder`). Take both halves of a before/after the same way.

`make test` / `test-fast` / `test-grove` / `import` are headless: no window, no focus, run them freely.

## Matching a concept mock — read the method first

**Before claiming a UI element matches the mock it was drawn from** (or measuring anything off
`games/grove/assets/_concepts/`), read `docs/design/verifying-against-a-mock.md`. It is the rule set
for a like-for-like comparison and the guide to the rig that makes one: `make shot-mock` puts our
element and the mock's own pixels on ONE flat field at ONE scale, and
`games/grove/tools/mock_profile.py` reads the sheet back. Measuring our element on our screen against
the mock's on its screen is not evidence — it was done five times running before anyone noticed.
Which mock, which rect of it, and how much of the ground beside it is REAL is judgement, and lives in
`games/grove/tools/mock_targets.json`; the scripts never guess.

## Changing the shop screen — the hit regions are measured

The shop screen IS the concept painting with transparent hit rects over it. **Before touching the
storefront art, its regions, or adding a shop element**, read `docs/design/shop-hit-regions.md`: it is the
mock → measure → registry → overlay loop (`measure_shop_screen.py`, the regions JSON, then
`make shot-map MODE=shophits` to SEE which purchase each tap resolves to, per the engine's own picker).
The overlay is a capture tool (`engine/tools/shop_hit_overlay.gd`) and ships with nothing — the export
excludes `engine/tools/**`, and `engine/tests/layering_tests.gd` fails if shipped code ever names it. The
metas it reads (`shop_slot` / `shop_offer` / `shop_close` / `shop_close_drawn`) DO stay in the game; they
are what makes the loop re-runnable.

## Testing — run `make test-fast` first

After **every change**, run the fast inner-loop check before anything else:

```bash
make test-fast      # engine suites only, parallel — a few seconds
```

Run the **full sweep only before committing or handing off** (it adds the grove game
suites, which instantiate scenes and take longer):

```bash
make test           # every suite (engine + grove), parallel + per-suite timing table
```

Both run headless and in parallel via `engine/tools/run_suites.py` (`JOBS=4` default).
The runner prints a per-suite timing table and fails on any FAIL or crash — it never
trusts a zero exit code alone. The grove suite is split into focused suites
(`grove_board_actions_tests`, `grove_explore_tests`, `grove_sky_tests`, `grove_shop_tests`,
`grove_ui_workbench_tests`, `grove_scene_workbench_tests`, `grove_scene_covers_tests`,
`grove_ftue_tests`, `grove_rush_ftue_tests`, `grove_cascade_tests`, `grove_improvements_tests`, `grove_gating_tests`) sharing `games/grove/tests/grove_test_base.gd`
— edit a slice, run that slice with `make test-grove`. The authoritative list is
`GROVE_TESTS` in the Makefile. This line no longer relies on anyone remembering to update
it: `engine/tests/suite_registry_tests.gd` fails if the Makefile, this file and the README
name different sets (membership, not order).

`make test` also runs `make test-config` — the non-Godot python/bash guards (`PY_TESTS` /
`SH_TESTS`). The same suite asserts those lists cover every `test_*.py` / `*_tests.py` and
`test_*.sh` on disk, so a new one cannot sit unrun behind its own target.
Engine FX motion checks include `engine/tests/fx_config_tests.gd` and
`engine/tests/fx_flight_tests.gd`; run the latter when changing wallet or piece flight feedback.

`engine/tests/kit_bake_freshness_tests.gd` re-bakes every sprite the kit dialogs polish and
fails if a committed mirror under `games/grove/assets/baked/` differs from that fresh bake.
It is the slowest engine suite (~10s — it re-runs the per-pixel polish the bake exists to
avoid). It fires after an art change AND after an `.import` re-tune, since the bake's input is
the imported decode; the fix is always `make bake-textures` then `make import`.
