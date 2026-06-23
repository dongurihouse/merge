# Gold Badge Godot Workbench Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Godot code-drawn port of the HTML gold rounded badge and expose it as a Workbench component.

**Architecture:** `ui_workbench_kit.gd` owns a reusable `gold_badge(px)` builder that returns a `Control` wrapping an `ImageTexture` generated from CSS-equivalent math. `ui_workbench_view.gd` registers `gold_badge` as a left-column workbench test component. `grove_workbench_tests.gd` verifies registration and that the generated component has a visible texture control.

**Tech Stack:** Godot 4 GDScript, `Image`, `ImageTexture`, `TextureRect`, existing Workbench gallery/test harness.

## Global Constraints

- Do not use a baked PNG for this badge.
- Keep the component test-only in the workbench unless the user later asks to wire it into game UI.
- Preserve existing workbench component registration patterns: `IDS`, `COLUMNS`, `CAPTIONS`, `_params`, and `_make_element`.
- Follow TDD: add failing Godot tests before production code.

---

### Task 1: Test And Register The Gold Badge Component

**Files:**
- Modify: `games/grove/tests/grove_workbench_tests.gd`
- Modify: `games/grove/tools/ui_workbench_kit.gd`
- Modify: `games/grove/tools/ui_workbench_view.gd`

**Interfaces:**
- Produces: `Kit.gold_badge(px: float = 270.0) -> Control`
- Produces: workbench section id `gold_badge`

- [x] **Step 1: Write failing tests**

Add assertions in `games/grove/tests/grove_workbench_tests.gd`:

```gdscript
ok(view._sections.has("gold_badge"), "the CSS-port gold badge is a registered gallery item")
var gb := Kit.gold_badge(270.0)
ok(gb is Control and gb.custom_minimum_size == Vector2(270, 270), "gold_badge builds at the requested size")
ok(gb.find_children("*", "TextureRect", true, false).size() == 1, "gold_badge exposes one generated texture rect")
```

- [x] **Step 2: Verify red**

Run: `make test-one SUITE=games/grove/tests/grove_workbench_tests`

Expected: fail because `Kit.gold_badge` and `gold_badge` registration do not exist.

- [x] **Step 3: Add `Kit.gold_badge(px)`**

Add a code-drawn badge builder to `games/grove/tools/ui_workbench_kit.gd` near other code-drawn UI helpers. It generates a transparent `Image`, draws a soft shadow and rounded badge face, and wraps it in a centered `TextureRect`.

- [x] **Step 4: Register `gold_badge` in the workbench**

Update `IDS`, `COLUMNS`, `CAPTIONS`, `_params`, `TEST_KEYS`, and `_make_element` in `games/grove/tools/ui_workbench_view.gd`.

- [x] **Step 5: Verify green**

Run: `make test-one SUITE=games/grove/tests/grove_workbench_tests`

Expected: all workbench tests pass.

- [x] **Step 6: Run project fast tests**

Run: `make test-fast`

Expected: all active engine suites pass.

- [x] **Step 7: Capture the workbench**

Run: `make shot-workbench OUT=/tmp/gold_badge_workbench.png`

Expected: screenshot file is written and includes the new Workbench gallery item.
