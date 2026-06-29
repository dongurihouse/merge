# Currency Tier Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add playable coin and acorn tiers 4-12, generated from one 3 column x 6 row source sheet and wired into existing board rendering and collection behavior.

**Architecture:** Keep the runtime paths unchanged: board coins still render from `items/coin/coin_<tier>.png`, and acorn specials still render through `G.item_tex_path(1300 + tier)`. Add a deterministic slicer for the combined source sheet, then update the data tables and tests.

**Tech Stack:** Godot 4.6 GDScript, Python 3 with PIL/numpy/scipy for asset slicing, existing `make import` and `make test-one` targets.

## Global Constraints

- Work in branch `codex/currency-tiers`.
- Preserve existing tiers 1-3 values and art.
- Only coins and acorns gain 12-tier ceilings.
- Source sheet is 3 columns x 6 rows, row-major: coin tiers 4-12, then acorn tiers 4-12.
- Use flat solid `#FF00FF` source background and transparent shipped PNGs.

---

### Task 1: Gameplay Tests

**Files:**
- Modify: `engine/tests/mechanics_tests.gd`

**Interfaces:**
- Consumes: `G.COIN_TOP`, `G.coin_value(code)`, `G.merge_top(code)`, `G.special_collect(code)`, `G.item_tex_path(code)`
- Produces: failing coverage for coin/acorn tier 12 values and art paths

- [ ] **Step 1: Write the failing test**

Add assertions near the existing special item tests:

```gdscript
ok(G.merge_top(901) == 12, "coins now merge through tier 12")
ok(G.coin_value(912) == 50000, "coin t12 collects for the tuned high-tier value")
ok(G.merge_top(13 * 100 + 1) == 12, "acorn drops now merge through tier 12")
ok(G.special_collect(13 * 100 + 12) == {"kind": "acorn", "amount": 5000}, "acorn t12 tap-collects its tuned premium amount")
ok(G.item_tex_path(13 * 100 + 12).ends_with("items/acorn/acorn_12.png"), "acorn t12 resolves its wired art path")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-one SUITE=engine/tests/mechanics_tests`

Expected: FAIL because coin/acorn ceilings and values still stop at tier 3.

- [ ] **Step 3: Implement minimal data changes**

Modify `games/grove/grove_data.gd` with the explicit tier-1-through-12 tables from the design.

- [ ] **Step 4: Run test to verify gameplay passes before art existence**

Run: `make test-one SUITE=engine/tests/mechanics_tests`

Expected: Gameplay assertions pass. Asset existence should wait until the generated PNGs are imported.

### Task 2: Combined Currency Sheet Slicer

**Files:**
- Create: `games/tools/slice_currency_tiers.py`

**Interfaces:**
- Consumes: `games/grove/assets/_new/currency_tiers_v1/currency_tiers_3x6_raw.png`
- Produces: target PNGs in `games/grove/assets/items/coin/` and `games/grove/assets/items/acorn/`

- [ ] **Step 1: Write deterministic slicer**

Create a small script based on the connected-component logic in `games/tools/slice_item_lines.py`, fixed to 6 rows x 3 cols and output names `coin_4..12` then `acorn_4..12`.

- [ ] **Step 2: Generate and save raw sheet**

Use built-in `image_gen` with the project prompt, then copy the selected PNG to `games/grove/assets/_new/currency_tiers_v1/currency_tiers_3x6_raw.png`.

- [ ] **Step 3: Slice**

Run: `python3 games/tools/slice_currency_tiers.py --montage`

Expected: 18 transparent target sprites and `tmp/currency_tiers/currency_tiers_montage.png`.

- [ ] **Step 4: Import**

Run: `make import`

Expected: `.import` sidecars exist for the 18 new target PNGs.

### Task 3: Verification

**Files:**
- Modify: generated PNGs and `.import` sidecars only as produced by Task 2

**Interfaces:**
- Consumes: all Task 1 and Task 2 outputs
- Produces: verified branch ready for merge

- [ ] **Step 1: Run targeted tests**

Run:

```bash
make test-one SUITE=engine/tests/mechanics_tests
make test-one SUITE=games/grove/tests/grove_info_bar_tests
```

Expected: both pass. `grove_info_bar_tests` may emit the baseline `board.gd:1134` script error while still passing.

- [ ] **Step 2: Run fast suite**

Run: `make test-fast`

Expected: all active engine tests pass.

- [ ] **Step 3: Inspect status**

Run: `git status --short`

Expected: docs, data, tests, slicer, generated currency assets, and import sidecars only.
