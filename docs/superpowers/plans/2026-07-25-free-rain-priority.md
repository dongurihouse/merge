# Free Rain Priority Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prefer one daily free rain over paid refills and remove the three introductory refills.

**Architecture:** Keep the claim ledger authoritative. The board checks claim availability and routes free refill taps to the stall; the shop conditionally exposes the paid water card only after the free claim is unavailable.

**Tech Stack:** Godot 4, GDScript, Grove scene tests

## Global Constraints

- Preserve the existing 25-acorn paid refill and unaffordable shop-routing behavior.
- Ignore legacy `refills_used` save data without requiring migration.
- Keep the change narrow.

---

### Task 1: Lock the refill behavior with tests

**Files:**
- Modify: `games/grove/tests/grove_shop_tests.gd`

**Interfaces:**
- Consumes: `Claims.can_show("refill_water")`, `Shop._sections(refs)`, board `_on_refill()`
- Produces: regression coverage for the approved player-visible flow

- [ ] **Step 1: Update the claim test**

Assert that one successful claim exhausts the daily allowance even after its timestamp is backdated, and that a new day restores it.

- [ ] **Step 2: Add board priority coverage**

At zero water with a ready free claim and enough acorns, assert that the board labels the action free, opens the stall, spends no acorns, and grants no water directly.

- [ ] **Step 3: Add shop priority coverage**

Assert that the paid water card is absent while the free claim is ready and present after the daily claim is consumed.

- [ ] **Step 4: Run the focused suite and verify RED**

Run: `make test-one SUITE=games/grove/tests/grove_shop_tests`

Expected: failures showing the current three-per-day cap, introductory direct refill, and always-visible paid card.

### Task 2: Implement the minimum production change

**Files:**
- Modify: `games/grove/grove_data.gd`
- Modify: `engine/scripts/core/content.gd`
- Modify: `engine/scripts/scenes/board.gd`
- Modify: `engine/scripts/ui/shop.gd`
- Modify: `games/grove/tools/grove_shot.gd`

**Interfaces:**
- Consumes: `Claims.can_show("refill_water")`, existing `_open_water` callable
- Produces: one authoritative daily free refill path

- [ ] **Step 1: Set the daily claim cap to one**

Change the `refill_water` claim cap from `3` to `1`.

- [ ] **Step 2: Remove introductory refill state**

Delete `FREE_REFILLS`, `refills_used`, its load/save handling, and tool setup that mutates it.

- [ ] **Step 3: Prioritize free rain on the board**

When `Claims.can_show("refill_water")` is true, render the free label and route `_on_refill()` to `_open_water` before any acorn-spend branch.

- [ ] **Step 4: Prioritize free rain in the shop**

Build the quick-help card list without the paid water card while the free claim is available.

- [ ] **Step 5: Run the focused suite and verify GREEN**

Run: `make test-one SUITE=games/grove/tests/grove_shop_tests`

Expected: all assertions pass.

### Task 3: Verify and integrate

**Files:**
- Review all modified files

**Interfaces:**
- Consumes: completed behavior and tests
- Produces: verified change on `main`

- [ ] **Step 1: Run fast tests**

Run: `make test-fast`

Expected: all suites pass.

- [ ] **Step 2: Run full tests**

Run: `make test`

Expected: all suites pass.

- [ ] **Step 3: Review the diff**

Confirm the change is limited to the documented refill behavior and carries no unrelated edits.

- [ ] **Step 4: Commit, merge, and clean up**

Commit the implementation, fast-forward `main`, rerun the full suite on merged `main`, remove the worktree, and delete the merged branch.
