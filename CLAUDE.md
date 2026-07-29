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

## Matching a concept mock — read the method first

**Before claiming a UI element matches the mock it was drawn from** (or measuring anything off
`games/grove/assets/_concepts/`), read `docs/design/verifying-against-a-mock.md`. It is the rule set
for a like-for-like comparison and the guide to the rig that makes one: `make shot-mock` puts our
element and the mock's own pixels on ONE flat field at ONE scale, and
`games/grove/tools/mock_profile.py` reads the sheet back. Measuring our element on our screen against
the mock's on its screen is not evidence — it was done five times running before anyone noticed.
Which mock, which rect of it, and how much of the ground beside it is REAL is judgement, and lives in
`games/grove/tools/mock_targets.json`; the scripts never guess.

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
`grove_ftue_tests`, `grove_rush_ftue_tests`, `grove_cascade_tests`, `grove_improvements_tests`) sharing `games/grove/tests/grove_test_base.gd`
— edit a slice, run that slice with `make test-grove`. The authoritative list is
`GROVE_TESTS` in the Makefile. This line no longer relies on anyone remembering to update
it: `engine/tests/suite_registry_tests.gd` fails if the Makefile, this file and the README
name different sets (membership, not order).

`make test` also runs `make test-config` — the non-Godot python/bash guards (`PY_TESTS` /
`SH_TESTS`). The same suite asserts those lists cover every `test_*.py` / `*_tests.py` and
`test_*.sh` on disk, so a new one cannot sit unrun behind its own target.
Engine FX motion checks include `engine/tests/fx_config_tests.gd` and
`engine/tests/fx_flight_tests.gd`; run the latter when changing wallet or piece flight feedback.
