# Scene Workbench JSON Feather Fix

- Regression: `sourceCropFeatherBottom` supplied by JSON as `2.0` was ignored by the live workbench because only `int` values were accepted.
- Red: `make test-one SUITE=games/grove/tests/grove_scene_workbench_tests` produced `95 passed, 1 failed` after the focused test began using `2.0`.
- Green: numeric JSON values are rounded to a nonnegative whole-pixel feather value; non-numeric and negative values remain inert.
- Verification: focused suite now reports `96 passed, 0 failed`; `make shot-sw` saved `/tmp/fairy_hollow_v4_feather_fix.png` with the forest-band bottom softly feathered into the scene rather than ending in a hard horizontal strip.
