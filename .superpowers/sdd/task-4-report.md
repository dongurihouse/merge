# Task 4 report: swap home bottom bar to `Kit.action_button`

## Summary

Swapped the live home bottom bar (`engine/scripts/scenes/map.gd::_build_bottom_bar`) from baked
`nav_<x>.png` `SpriteButton` tiles to the shared code-drawn `Kit.action_button` (rugged
`CutPaperPanel` edge + centered transparent glyph), and updated the `grove_explore_tests.gd`
bottom-bar assertions to match. Commit: `1ff9febc`.

## Files changed

- `engine/scripts/scenes/map.gd`
- `games/grove/tests/grove_explore_tests.gd`

## map.gd changes

1. Removed the now-dead `NAV_SPRITE` map (was only consulted by the branch removed in step 3;
   `SpriteButton` itself stays — it's still used by the Back button, the gear, and a container
   button elsewhere in the file).
2. Added `NAV_ROLE`, mapping bottom-bar node names to `Kit.action_button` roles:
   ```gdscript
   const NAV_ROLE := {
       "HomeTile": "home", "MapTile": "map", "ResidentsTile": "residents",
       "DailyTile": "daily", "VaultTile": "vault", "MailTile": "mail", "BoardTile": "play",
   }
   ```
   Verified these keys against `_bottom_bar_specs` (~map.gd:2396-2433): the live specs use exactly
   `HomeTile, MapTile, ResidentsTile, DailyTile, VaultTile, MailTile, BoardTile` — no mismatch.
   Verified the role strings against `ui_workbench_kit.gd`'s `ACTION_GLYPHS` /
   `ACTION_TINT_DEFAULTS` keys (`map, residents, daily, vault, mail, play, home, bag`) — exact match.
3. In `_build_bottom_bar`, replaced the `opts`/`SpriteButton`/`Kit.home_button` branch with:
   ```gdscript
   var action_opts: Dictionary = Kit.action_button_opts_from_config(Kit.load_config(Kit.CONFIG_PATH)) if Kit != null else {}
   for i in specs.size():
       var spec: Dictionary = specs[i]
       var b: Button
       var role := String(NAV_ROLE.get(String(spec.name), ""))
       if Kit != null and role != "":
           var o := action_opts.duplicate(true)
           o["name"] = String(spec.name)
           o["tooltip"] = String(spec.caption)
           b = Kit.action_button(role, Vector2(tile_w, tile_w), spec.action, o)
       else:
           b = Button.new()                          # defensive fallback (kit absent): a bare tile
           b.focus_mode = Control.FOCUS_NONE
           b.text = String(spec.caption)
           b.custom_minimum_size = Vector2(tile_w, tile_w)
           b.pressed.connect(spec.action)
   ```
   `action_opts` is built ONCE outside the loop and `.duplicate(true)`'d per tile, per the review
   note in the task — no per-button config re-read.
   Left the `b.name = …`, positioning (`b.position`, `b.size`), `_chrome_nodes` tracking, and
   `out[…]` lines below unchanged, as instructed.

Note: the per-spec `"surface"` field (`sky/green/gold/purple/kraft/coral`) is no longer read by
the tile-build path — `Kit.action_button`'s tint comes from `ACTION_TINT_DEFAULTS`/config instead,
and every role currently defaults to `"cream"` (see `ui_workbench_kit.gd:66-71`, "Calm default
paper role per button ... the glyph carries the identity" — an established Task 1-3 decision, not
something I introduced). The rendered bar reads as one calm cream family, matching that intent and
the task's "calm paper fills" verification bullet. The `spec.surface` field itself is left in
`_bottom_bar_specs` (harmless, unread) since the brief didn't ask to touch spec construction.

## Test-assertion changes (grove_explore_tests.gd, ~line 287-304)

Replaced the baked-sprite assertion block with the code-drawn assertion block exactly as given in
the brief (asserts `find_child("ActionButtonDeckleSurface", ...)` exists, and a `TextureRect` whose
texture path contains the tile's `glyph_<x>` name). No other assertions in the suite depended on
the baked sprite specifically — the remaining ones (Board right-most, Board same tile size as
neighbour, gear position, row-fill-width) are purely size/position-based and needed no changes.

## TDD evidence

**RED** (before the map.gd change, with only the test edit applied):
```
FAIL  MapTile wears the shared code-drawn rugged edge
FAIL  MapTile composites its transparent glyph in the middle
FAIL  ResidentsTile wears the shared code-drawn rugged edge
FAIL  ResidentsTile composites its transparent glyph in the middle
FAIL  DailyTile wears the shared code-drawn rugged edge
FAIL  DailyTile composites its transparent glyph in the middle
FAIL  BoardTile wears the shared code-drawn rugged edge
FAIL  BoardTile composites its transparent glyph in the middle
== 213 passed, 8 failed ==
```
Exactly the 4 tiles x 2 assertions expected to fail against the still-baked bar.

**GREEN** (after the map.gd swap):
```
== 221 passed, 0 failed ==
```

## Full verification

- `make test-fast`: 21 suites, 810 passed, 0 failed.
- `make test` (full sweep, includes grove suites): 26 suites, 1449 passed, 0 failed — including
  `games/grove/tests/grove_explore_tests` (221 passed) and the other grove suites
  (board_actions, scene_workbench, shop, zone_workbench).

## Real-path visual verification

Read `games/grove/tools/map_shot.gd` first: its `hub` mode seeds a representative wallet + claims
today's login (so no popup covers the screen) and opens the real `Map.tscn` scene — the actual live
home screen, not the workbench preview. Ran:
```bash
make shot TOOL=games/grove/tools/map_shot ARGS="hub <scratchpad>/home_bar.png"
```
then read the resulting 1080x1920 PNG, and a 3x-zoomed crop of the bottom-bar row
(`home_bar_crop.png`, y=1780..1920).

**Observed:** 5 tiles render (Map, Residents, Daily, Mail, Board — Vault absent because the
`piggy_vault` feature flag is off, matching `Features.on("piggy_vault")` gating and the test's
"the parked Vault carries no bottom-bar tile" assertion). Every tile shares one cream, deckle-edged
cut-paper surface — the rugged edge reads identically across all five. The glyphs read as one
family (a folded map with a pin, a house/hat icon for Residents, a gift-wrapped calendar for Daily,
an envelope with a wax seal for Mail, a play-arrow-plus-blocks for Board) — consistent line weight
and palette. The Mail tile's unread-count pill badge ("5") sits correctly in its top-right corner.
The Daily "unclaimed" dot is absent, which is correct: `hub` mode calls
`login.gd.claim_today()` before capture, so `_refresh_liveops_badges` hides it (`visible = not
Login.claimed_today()`) — this is the same badge-hides-when-claimed behavior the suite already
covers, not a regression from this task.

## Self-review / concerns

- The `SpriteButton` const stays in map.gd (used by Back button + settings gear + one container
  button, per grep) — only the `NAV_SPRITE` dict was dead and removed.
- Confirmed `Kit.action_button_opts_from_config` and `Kit.action_button` signatures directly from
  `games/grove/tools/ui_workbench_kit.gd` before wiring the call — matches the brief's snippet
  exactly.
- No other call sites reference `NAV_SPRITE` or the removed `opts`/`Kit.home_button` bottom-bar
  branch (`grep -n "NAV_SPRITE" engine/scripts/scenes/map.gd` now returns nothing).
- One judgment call beyond the brief: I removed the dead `NAV_SPRITE` dict entirely rather than
  leaving it unused, since the brief listed it as a file to "modify" and dead config maps invite
  drift. If the team prefers keeping it (e.g. as a documented historical reference or for a future
  fallback), that's a one-line revert.
- Did not touch `_bottom_bar_specs`'s `"surface"` field — it's now inert dead data on each spec
  dict; flagging it here rather than silently deleting it, since removing it is a slightly larger
  edit than the brief scoped and touches a shared spec-building function used by both the home
  screen and the maps gallery.
- Note: `task-4-report.md` at this path previously held an unrelated stale report ("Meadow Sky
  whole-UI visual and regression verification") from a different task-numbering scheme in this
  worktree's history. It has been overwritten with this task's report as instructed.
