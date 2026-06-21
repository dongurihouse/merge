# Placement Workbench — design

Date: 2026-06-20
Status: approved (brainstorm), pending implementation plan
Worktree/branch: `placement-workbench`

## Problem

The existing **UI Workbench** (`games/grove/tools/ui_workbench*.gd`) tunes UI-component
*parameters* (sizes, fonts, nine-slice) and persists them to `ui_workbench_settings.json`.
It does **not** let a designer position the large elements on a screen. Today, placement
is hand-edited:

- **Home (the farmhouse hub):** each restore "unlock button" (cost badge) sits at a spot's
  normalized position stored in `games/grove/assets/map/farm/farm_home.json`
  (`buildings[].pos`, a `[x_frac, y_frac]` fraction of the fitted map rect). Read at runtime
  by `map.gd:_home_badge` / `_home_buildings`.
- **Board:** the quest bar (`giver_bar`, height `FENCE_H`) and the merge board sit in a
  top-pinned `VBoxContainer` in `board.gd`. Their vertical placement is governed by code
  constants; there is no data file.

We want a sibling tool that boots the *real* screen, lets the designer **drag** the major
items, and **saves their location back into source data**.

## Scope

Draggable items (confirmed):

- **Home:** the unlock buttons only (the farmhouse-hub restore-cost badges). Free 2D drag.
- **Board:** the quest bar and the board. **Vertical offset only.**

Save model (confirmed): **write back into source data** — no override-layer indirection.

- Home → rewrite `farm_home.json` `buildings[].pos`.
- Board → new `board_layout.json` read by `board.gd` (board has no existing data file).

Out of scope (YAGNI):

- Other maps' unlock buttons (their positions live in `grove_data.gd` `MAPS`, a GDScript
  const, not a writable data file). "Home" here means the farmhouse hub that ships
  `farm_home.json`.
- Resize (changing `FENCE_H` / board size), horizontal board drag, editing owned-building
  art/masks, and any new override-layer file.

## Approach

Chosen: **thin authoring hooks in the real scenes (approach A).** The tool boots the actual
`Map.tscn` / `Board.tscn`, and the scenes expose their draggable nodes + accept a live
position so dragging moves the *actual* item. Rationale: best drag feel, single source of
truth for layout math, and `board.gd` must change for consumption anyway (it has to read the
saved offsets). Consistent with the board's existing `Debug.mount(self)` authoring panel
precedent. Rejected: a fully decoupled overlay that recomputes geometry and drags proxy
handles (worse feel, duplicates layout math).

**Critical difference from the UI Workbench:** this tool keeps the game's content scaling
ON (portrait base 1080×1920, `canvas_items`), so positions are authored in the exact space
the game renders in. (The UI Workbench disables content scaling because it shows isolated
components in a wide window.)

## Components

### 1. `games/grove/tools/ui_placement.gd` — runner
`SceneTree` runner, sibling of `ui_workbench.gd`.
- Reads `SCREEN=home|board` from `OS.get_cmdline_user_args()` (default `home`).
- Configures the root for the game's content scale (portrait base), instantiates the real
  scene (`res://engine/scenes/Map.tscn` or `Board.tscn`), lets `_ready()` run.
- Seeds **in-memory** edit state so the targets are visible (see "State seeding").
- Mounts `placement_overlay.gd`.
- Quiet/screenshot path identical to `ui_workbench.gd` (born minimized via `override.cfg`,
  `WINDOW_FLAG_NO_FOCUS`, save PNG to the user-arg path, then `quit()`).

### 2. `games/grove/tools/placement_overlay.gd` — editing surface
A `Control` (or `CanvasLayer`) on top of the scene.
- Pulls draggable targets from the scene's authoring hook.
- Hit-tests on press; drags the selected target (home = free 2D, board = Y-only); repositions
  live via the scene's authoring setter.
- On-screen controls: **Save**, **Reset** (revert to last-saved source data), **Home/Board**
  reload toggle, and a live coordinate readout for the selected item.
- Owns the source-data writers (below).

### 3. Source-data writers
- **Home →** load `farm_home.json`, update `buildings[].pos` for changed spots only,
  preserving `cost`/`mask`/`spot` and the file's existing format
  (`JSON.stringify(data, "\t", true)` → sorted keys, tab indent — match the current file).
- **Board →** write `games/grove/assets/board/board_layout.json` =
  `{ "fence_dy": <frac>, "board_dy": <frac> }`, both normalized fractions of viewport height.

### 4. Game consumption + authoring hooks (minimal, guarded; default behavior unchanged)
- **`map.gd`:** keep a dict of seated badge nodes keyed by spot id during the home build;
  expose `authoring_home_targets()` (→ `[{id, node, center_px}]`) and a live reseat so a
  drag moves the real badge. Consumption already exists (reads `farm_home.json`).
- **`board.gd`:** read `board_layout.json`; apply `fence_dy` / `board_dy` as Y offsets inside
  **thin per-band offset wrappers** (a wrapper `Control` is the `VBoxContainer` child at its
  natural min size; the band sits inside with `position.y = offset`, so siblings don't move
  and the responsive layout is preserved). Default missing/`0` = today's layout exactly.
  Expose `authoring_board_targets()` (→ the two bands) and a live offset setter.

## Coordinates

- **Home:** normalized fraction of `map.gd:_map_rect` (the same basis `farm_home.json` uses).
  Drag px → fraction: `(badge_center_px - _map_rect.position) / _map_rect.size`.
- **Board:** normalized fraction of viewport height. Drag px → fraction: `delta_y / view.y`.
  Applied inside the offset wrapper as `wrapper_child.position.y = frac * view.y`.

## Data flow

1. **Load:** scene reads its source data exactly as in-game (`farm_home.json` /
   `board_layout.json`) → renders.
2. **Edit:** overlay drags a target → live position via the scene's authoring setter →
   coordinate readout updates.
3. **Save:** writer serializes current values to source data.
4. **Confirm:** reload (Home/Board toggle or relaunch) → the game-path render reflects the
   saved data.

## Non-destructive state seeding

- **Home:** force the farmhouse-hub map with **all spots unowned** in memory so every unlock
  button is visible. Mutate the in-memory `Save.grove()` dict only — **never call
  `grove_write()`**, so the player's on-disk save is untouched.
- **Board:** seed one giver + a few pieces in memory so both bands render with content.

## Testing

- **Headless logic suite** (`games/grove/tests/grove_placement_tests.gd`, sharing
  `grove_test_base.gd`; wired into `make test-grove`):
  - `farm_home.json` writer round-trip: updating one spot's `pos` preserves every other
    field and the key order/format.
  - `board_layout.json` read/apply: missing file → zero offsets (unchanged layout); present
    file → bands offset by the expected px.
  - Coordinate conversions: home px↔normalized against a known `_map_rect`; board
    delta↔fraction against a known viewport.
- **Visual verification (not eyeballed):** `make shot-place SCREEN=home` and
  `SCREEN=board` before/after a scripted drag; composite/measure the badge / band positions.

## Make targets

- `place`: `make place SCREEN=home|board` — interactive window (mnemonic `p`).
- `shot-place`: `make shot-place SCREEN=home|board [OUT=/tmp/place.png]` — quiet
  born-minimized screenshot (reuses the `$(QUIET)` recipe like `shot-workbench`).

## Risks / notes

- `map.gd` and `board.gd` are large (1.5k / 2.2k lines). Hooks must be small, additive, and
  guarded so the production render path is byte-for-byte unchanged when no tool/data is present.
- The board offset wrapper must not change any band's min size, or it will perturb the
  responsive `csz` computation. Verify the no-offset case renders identically to `main`.
- Do not persist seeded edit state to the real save (`grove_write`).
