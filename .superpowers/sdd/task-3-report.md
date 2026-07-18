# Task 3 report: Shared Meadow Sky UI component integration

Status: complete

Implementation commit:

- `df6a4db0 feat(grove): integrate Meadow shared UI components`

Implemented:

- Routed the shared primary, secondary, and danger `pill_button` roles to canonical Meadow shells by default, with explicit nine-slice margins, native `Button` text/input behavior, disabled/pressed states, and compatibility for explicit legacy art overrides.
- Routed the shared dialog panel and title banner to Meadow art; Level uses the same title-ribbon atom, and Daily, Settings, Mail, Vault, Expedition, Gift, and News roles consume compatible Meadow icons.
- Replaced layered level-badge composition with 25 stable complete 256 x 256 variants while retaining the public constructor signature and native `lv_num` label. Removed stale layered-part controls from the resolver, saved defaults, and workbench sidebar.
- Routed board frames and live/workbench action-bar frames to the Meadow board frame with explicit slices. Routed open, locked, and unlockable slot states to their authored shells without layering stale bevel/inset tuning over them.
- Normalized component runtime shadows to exact structural slate `#294654` at no more than 20% alpha.
- Built the Vault jar from its plate, proportionally clipped acorn fill, and shell layers. The production Vault CTA inherits the canonical primary button.
- Replaced the Rush polygon telegraph with the direct Meadow danger-chevron texture while preserving the separate bottom-hint asset and targeting behavior.
- Kept public component signatures and native interaction nodes intact; existing explicit code/gold frame modes remain compatibility options.
- Ran bake discovery after implementation and checked in the seven new Meadow icon mirrors plus refreshed mirrors affected by the canonical source updates. No `bake_targets.gd` change was required because existing discovery already reaches the routed dialogs and chrome.

TDD and review evidence:

- Initial RED, active shared-component guard: `145 passed, 30 failed` on legacy button, board, slot, and level-badge paths.
- Initial RED, parked UI suite: all 12 new Task 3 assertions failed before that suite reached its known unrelated baseline failures.
- Default-button RED: `187 passed, 1 failed`; GREEN after making canonical art the default: `188 passed, 0 failed`.
- Rush regression was proven by temporarily routing to the wrong bottom-hint asset: `226 passed, 1 failed`; restored danger-chevron route: `227 passed, 0 failed`.
- Independent review found no critical issues. Its three important findings were resolved: the active engine badge contract was rewritten for complete variants, the real Vault CTA was covered, and live/preview action bars gained an explicit Meadow branch.
- Action-bar review RED: workbench `639 passed, 2 failed`; GREEN: `641 passed, 0 failed`.
- Engine badge review RED: old suite produced 12 failures and a null-instance error at its obsolete `lv_circle` dereference; updated contract: `41 passed, 0 failed`.
- Bake-contract RED: `kit_bake_tests` had 4 stale legacy-icon expectations; after tracing discovered sources to the new semantic routes: `16 passed, 0 failed`.

Final verification:

- `make bake-textures` -> exit 0, 0 failed, all discovered Meadow icon mirrors generated.
- `make test-one SUITE=engine/tests/level_badge_tests` -> `41 passed, 0 failed`.
- `make test-one SUITE=engine/tests/kit_bake_tests` -> `16 passed, 0 failed` and 0 un-baked discovered sprites.
- `make test-fast` -> 40 suites, `1297 passed, 0 failed`.
- `make test-grove` -> 11 suites, `1801 passed, 0 failed`.
- `git diff --cached --check` -> clean before the implementation commit.

Concerns / scope notes:

- `grove_ui_tests` remains outside the active Grove test list and still reaches known unrelated baseline failures/obsolete `_unlock_btn` access. Its Task 3 component assertions pass before that point; equivalent dialog, Level, Vault, icon, button, board, slot, and badge coverage was placed in active suites.
- Nine unrelated import-generated `.gd.uid` files under engine bucket/home paths remain untracked and were deliberately excluded from the Task 3 commit.
- Rush coverage asserts the direct chevron texture contract; existing targeting code remains responsible for resize/clamp positioning.
