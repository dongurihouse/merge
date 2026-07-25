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
(`grove_board_actions_tests`, `grove_explore_tests`, `grove_shop_tests`,
`grove_ui_workbench_tests`, `grove_scene_workbench_tests`, `grove_scene_covers_tests`,
`grove_ftue_tests`, `grove_rush_ftue_tests`) sharing `games/grove/tests/grove_test_base.gd`
— edit a slice, run that slice with `make test-grove`. The authoritative list is
`GROVE_TESTS` in the Makefile; keep this line in step with it.
