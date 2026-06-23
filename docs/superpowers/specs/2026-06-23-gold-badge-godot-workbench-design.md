# Gold Badge Godot Workbench Design

## Goal

Port the standalone HTML/CSS gold rounded badge into a Godot code-drawn component and expose it as a new UI Workbench test component.

## Scope

- Add a new kit builder in `games/grove/tools/ui_workbench_kit.gd` that draws the badge with code, not with a baked PNG.
- Register a new workbench item named `gold_badge` in `games/grove/tools/ui_workbench_view.gd`.
- Add tests in `games/grove/tests/grove_workbench_tests.gd` for registration and basic generated control structure.

## Visual Mapping

- Badge size: default `270px`, matching the HTML `--badge-size` cap.
- Outer corner radius: `0.215 * size`.
- Inner groove inset: `0.040 * size`.
- Inner groove radius: `0.78 * outer radius`.
- Draw cream/gold diagonal fill, top-left radial highlight, 1px outer rim, 1px inner groove, inset groove highlight/shadow, and soft cast shadow.

## Verification

- Add a failing Godot test first.
- Run the workbench test slice, then `make test-fast`.
- Capture `make shot-workbench` so the new component can be visually inspected.
