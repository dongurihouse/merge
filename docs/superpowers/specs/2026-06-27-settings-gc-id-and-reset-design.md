# Settings: Game Center id + reset save (debug-gated) — design

Date: 2026-06-27
Branch: `settings-gc-id-reset` (proposed)
Status: pending user review of spec

## Goal

Add two **debug-only** rows to the bottom of the Settings dialog:

1. A **read-only Game Center id** line, so the owner can see the signed-in
   pseudonymous player id on a device (useful for support and for confirming
   sign-in actually happened).
2. A **Reset save** action that wipes progress back to a fresh install, with a
   confirmation step, then reloads to a clean home.

Both are visible **only when `Debug.authoring()` is true** — the same explicit gate
(`TU_DEBUG=1`, `-- debug`, or `Debug.force`) that drives the on-screen state-jump
panel. Production players, headless logic suites, and quiet capture runs see the
unchanged toggle list.

## Non-goals

- **Not player-facing.** The reset is destructive and the raw GC id is not something
  shipped players should see; the debug gate keeps both out of release builds.
- **No new dialog scene.** The confirmation is an inline two-tap on the action row,
  not a separate modal.
- **The row does not trigger sign-in.** It only *displays* `Identity.player_id()`.
  Sign-in is already kicked off automatically at home open (`Identity.boot` from
  `map.gd`); see `core/identity.gd`.
- **No change to the existing toggle flags** (music/sfx/calm/haptics) or the
  workbench-authored look of the dialog.

## Architecture

The Settings face is built from the shared MAIL KIT: `settings.gd` maps a `FLAGS`
list to kit entries, and `Kit.settings_dialog(entries, width, opts)`
(`games/grove/tools/ui_workbench_kit.gd:2107`) stacks one `toggle_card` per entry.
Today every entry is assumed to be a toggle.

### 1. Kit: render entries by `kind`

Teach `settings_dialog` to branch on an entry field `kind`, defaulting to `"toggle"`
so existing flags and the workbench preview are byte-for-byte unchanged:

- `kind == "toggle"` → existing `toggle_card(e, to)`.
- `kind == "info"` → a read-only row: left `label`, right `value` text. Reuses the
  same card art / label-font styling as `toggle_card`, with the switch slot replaced
  by a right-aligned value `Label`. A small `info_card(entry, opts)` helper alongside
  `toggle_card`.
- `kind == "action"` → a tappable card-styled button (`action_card(entry, opts)`).
  Supports an optional destructive tint and a mutable label (for the two-tap confirm).
  Calls `entry.on_action` when pressed.

`info_card` / `action_card` live next to `toggle_card` and share its parchment/cream
card construction so the three row types are visually one family.

### 2. Settings: append the debug rows

In `settings.gd::_entries`, after the FLAGS loop, append the two rows **only when the
debug gate is on**:

```
if Debug.authoring():
    out.append({"kind": "info", "label": "Game Center", "value": _gc_id_text()})
    out.append({"kind": "action", "label": "Reset save", "destructive": true,
                "on_action": <two-tap reset>})
```

- `settings.gd` is in `engine/scripts/ui/` so it may import `core/identity.gd` and
  `ui/debug.gd` directly (layering: ui/ → core/ + ui/).
- `_gc_id_text()` returns `Identity.player_id()`, or the placeholder
  **"not signed in"** when it is `""` (off iOS, plugin absent, or sign-in not yet
  complete).

### 3. Reset flow (two-tap confirm)

The action row's `on_action` implements an inline confirm:

1. First tap: morph the row label to **"Tap again to wipe"** (destructive tint) and
   arm a short timer (~3 s) that reverts the label if not confirmed.
2. Second tap while armed: `Save.reset()` then
   `host.get_tree().reload_current_scene()` — the same wipe-and-reflect pattern as
   `Debug._act_reset` (`engine/scripts/ui/debug.gd:264`), landing on a fresh home.

The arming state is local to the row closure; it does not persist across the reload.

## Data flow

- GC id: `Save.grove()["gc_player_id"]` ← cached by `Identity._on_auth`; read via
  `Identity.player_id()`. No new persistence.
- Reset: `Save.reset()` already rebuilds `_default()` and writes the save.

## Gating

`Debug.authoring()` is false in headless (`DisplayServer.get_name() == "headless"`)
and on by `force` / `TU_DEBUG` / `-- debug`. The new rows therefore never appear in
logic suites or quiet captures, and never in a release build.

## Testing

Headless, extending the grove UI suite (`games/grove/tests/grove_ui_tests.gd`) or a
focused settings test:

- With `Debug.force = true`, `settings._entries(host)` includes an `info` row whose
  value is the placeholder when `Identity.player_id() == ""`, and an `action` row
  labelled "Reset save".
- With the gate off (default headless), neither row is present — only the FLAGS rows.
- The action's confirmed path calls `Save.reset()` (assert the save returns to
  defaults). Reset the `Debug.force` flag after the test.

Run `make test-fast` during the loop, `make test` before handoff.

## Open items

None — entry copy ("Game Center" / "not signed in" / "Reset save") and the two-tap
confirm were confirmed during brainstorming.
