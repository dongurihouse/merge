# FTUE — hand hints for the Rush panel (first merge, treefall dodge) — design

Date: 2026-07-23
Branch: `ftue-rush-hand-hint`
Status: approved, ready for an implementation plan.

## Goal

Two one-time hand-gesture teaches inside the Explore · Rush panel (`engine/scripts/scenes/explore_rush.gd`),
shown to a brand-new player the first time each situation arises:

1. **`rush_merge`** — the first time a mergeable pair exists on the Rush board, a hand bobs on one tile
   of that pair, until the player performs their first Rush merge.
2. **`rush_treefall`** — once a treefall is telegraphed, a hand bobs on the **bottom tile of the doomed
   column**, teaching the dodge — tap that tile to fling it out — until the player flings a tile out of
   the doomed column.

This is the Rush-panel counterpart of the board FTUE
(`docs/superpowers/specs/2026-07-23-ftue-hand-hint-design.md`). It **reuses that overlay unchanged**
(`engine/scripts/ui/hand_hint.gd`) and the same seen-once ledger; it adds only Rush-specific eligibility
logic and the wiring inside the Rush scene.

## Decisions (confirmed with the user)

- **Presentation: reuse the overlay as-is — hand + the soft 0.35 dim, one cutout for the taught tile.**
  Both Rush teaches use the overlay's **`tap`** gesture (the hand rests on the target and bobs
  down/up), because Rush both merges *and* flings on a **tap** — you never drag in Rush. The board's
  merge teach is a drag; the Rush merge teach is a tap on one tile of the pair, matching the real input.
- **Lifetime: once ever, per hint.** Two ids in the existing `ftue_seen` ledger, `"rush_merge"` and
  `"rush_treefall"`. Each shows until its action is performed once, then never again. Carries across runs
  (a player who never gets a pair or a treefall in run 1 is still taught later). No new save plumbing —
  `Save.ftue_seen(id)` / `Save.mark_ftue_seen(id)` already exist and deep-merge over defaults.
- **Treefall completion: only a real dodge marks it seen.** The hand shows on every telegraph until the
  player actually **flings a tile out of the doomed column**. Letting the tree fall does *not* count; the
  hand simply vanishes with the telegraph and returns on the next one — the same "loops until the action
  is done" rule as the board teaches.
- **Priority: treefall wins during a telegraph.** If a telegraph starts while the merge teach is still up
  (both unseen), the hand jumps to the doomed column for the few seconds the telegraph lasts, then
  returns to the merge pair. The treefall teach is time-critical and self-expiring; the merge pair is
  still there afterwards.
- **Persistence: loops until the action is done.** The hand never self-dismisses and is never dismissed
  by an unrelated tap. It ends only when the taught action is actually performed (or the flag flips off).
- **Art: none new.** The overlay already loads `ui/kit/hand.png` with its code-drawn fallback.

## The overlay — reused unchanged

`engine/scripts/ui/hand_hint.gd` needs **no edits**. Its public surface is enough:

```gdscript
static func present(host: Control, gesture_id: String, source_rect: Rect2, target_rect: Rect2) -> Control
func retarget(source_rect: Rect2, target_rect: Rect2) -> void
func dismiss() -> void
```

- Both Rush teaches pass `gesture_id = HandHint.GESTURE_TAP`; a `tap` uses `target_rect` only, so
  `source_rect` is passed equal to it.
- `present` returns `null` and does nothing when its own `ftue_hand_hint` flag is off. Rush additionally
  gates on a **new** `ftue_rush_hint` flag (below) before ever calling `present`, so the Rush teaches can
  be toggled independently. Both flags default ON.
- The overlay is fully input-transparent (every node `MOUSE_FILTER_IGNORE`), so the player taps the tile
  straight through the veil — the timed run is never blocked. Its `z_index` (500) is below
  `Overlay.MODAL_Z` (2048), so the Rush how-to-play popup (`TutorialImage`) always renders over it.
- Rects are in the host's (the Rush scene's) coordinate space.

## The pure logic — `engine/scripts/core/explore.gd`

Three new pure static functions, no scene state, tested headlessly in `grove_explore_tests.gd`:

```gdscript
## First cell (row-major) that has a same-kind/same-tier orthogonal neighbour and is below MAX_TIER,
## or (-1,-1) when the board holds no mergeable pair. Reuses neighbor_match.
static func first_mergeable(grid: Array) -> Vector2i

## The lowest filled row in column `col` (the bottom tile the treefall teach points at), or -1 when
## the column is empty. Gravity packs columns to the bottom, so this is normally ROWS-1.
static func bottom_filled(grid: Array, col: int) -> int

## WHICH Rush teach should be live right now. "" = none. Treefall wins during a telegraph:
##   if tele_active and not treefall_seen and has_doomed_tile -> "rush_treefall"
##   if not merge_seen and has_pair                            -> "rush_merge"
##   else                                                       -> ""
static func rush_hint_id(merge_seen: bool, treefall_seen: bool, tele_active: bool,
        has_pair: bool, has_doomed_tile: bool) -> String
```

`first_mergeable` respects `MAX_TIER` (a maxed tile cannot merge — mirror the `_on_tile` guard
`int(cell.tier) < Explore.MAX_TIER`).

## The wiring — `engine/scripts/scenes/explore_rush.gd`

Mirrors `board.gd`'s hand-hint block, with two simplifications: rects come from **cell geometry** (not
live node rects), and there is **no `await process_frame`** (cell geometry is valid synchronously after
`_layout`, and is stable while a tile's fall/fling tween runs).

**Members**

```gdscript
var _hand_hint: Control = null   # the live Rush teach overlay (at most one), or null
var _hand_hint_id := ""          # which teach it is ("rush_merge" / "rush_treefall")
```

**`_refresh_hand_hint()`** — the single entry point:

1. If `ftue_rush_hint` is off → `_dismiss_hand_hint()` and return (the flag can flip off mid-run).
2. If not `_running` → dismiss and return (no teach on a frozen / ended board).
3. Resolve the eligible id:
   ```gdscript
   var tele := String(_tf.get("ph", "idle")) == "tele"
   var pair := Explore.first_mergeable(_grid)
   var doomed_row := Explore.bottom_filled(_grid, int(_tf.get("col", 0))) if tele else -1
   var want := Explore.rush_hint_id(
       Save.ftue_seen("rush_merge"), Save.ftue_seen("rush_treefall"),
       tele, pair.x >= 0, doomed_row >= 0)
   ```
4. `want == ""` → dismiss and return.
5. Resolve the taught cell for `want` (the `pair` cell for merge; `(doomed_row, _tf.col)` for treefall)
   into a self-space `Rect2` via `_hand_hint_cell_rect(r, c)` and present/retarget/dismiss:
   - same id already live → `retarget(rect, rect)`;
   - otherwise `_dismiss_hand_hint()` then `_hand_hint = HandHint.present(self, HandHint.GESTURE_TAP, rect, rect)`.

**`_hand_hint_cell_rect(r, c) -> Rect2`** — the taught cell in the scene's coordinate space, from stable
layout math (no node lookup):

```gdscript
return Rect2(_board.position + _cell_rest(r, c), Vector2(_tile_px(), _tile_px()))
```

**`_dismiss_hand_hint()`** and **`_end_hand_hint(id)`** — copied from `board.gd`:

- `_dismiss_hand_hint()` dismisses any live overlay and clears the members.
- `_end_hand_hint(id)`: if the flag is off, tear down any live hint and return (no ledger write).
  Otherwise, if the live id matches, dismiss it; then if `id` is not already seen, `mark_ftue_seen(id)`
  and `_refresh_hand_hint()` to hand off to the next teach.

**Call sites** (each followed by `_refresh_hand_hint()`, guarded inside on `_running`):

- end of `_layout` — a relayout moved every cell rect;
- end of `_spawn` — a new tile may have created the first mergeable pair;
- end of `_merge` — after `_end_hand_hint("rush_merge")` (the merge changed the board);
- end of `_fling` — after the conditional `_end_hand_hint("rush_treefall")` (the fling changed the board);
- end of `_start_timber` — a telegraph began (treefall teach may now win);
- end of `_drop_timber` — the telegraph ended and its column cleared (back to the merge teach).

**Completion triggers**

- In `_merge`, after the board settles: `_end_hand_hint("rush_merge")`.
- In `_fling`, mark the dodge **only when the flung tile came out of the telegraphed danger column**:
  ```gdscript
  var danger := int(_tf.col) if String(_tf.ph) == "tele" else -1
  # ... existing fling body, which reads rc.y as the source column ...
  if rc.y == danger:
      _end_hand_hint("rush_treefall")
  ```
  (`_fling` already computes `danger`; reuse it. `rc.y` is the tile's source column.)

**Interaction with the how-to-play popup.** No special-casing. The popup is an `Overlay` modal above the
hint's z, so a live hand is simply covered while the popup is up, and is already correctly placed when it
closes. `_refresh_hand_hint` is driven by discrete game events, which resume once the player dismisses
the popup and play continues.

**Interaction with `_start` / run end.** `_start` does not call `_refresh_hand_hint` (the board is empty
— nothing to teach yet); the first call comes from the first `_spawn`. `_end` sets `_running = false`; the
next `_refresh_hand_hint` (or any `_end_hand_hint`) then dismisses a live hint.

## The flag — `engine/scripts/core/features.gd`

Add `"ftue_rush_hint": true` (rule N4: every new FTUE feature ships behind a flag). Independent of the
board's `ftue_hand_hint`, so the Rush teaches can be toggled without affecting the board teaches. Rush
gates on **both** — its own `ftue_rush_hint` in `_refresh_hand_hint`, and the overlay's own
`ftue_hand_hint` inside `HandHint.present`.

## Verification

- **Headless, pure** (`grove_explore_tests.gd`, an active suite):
  - `first_mergeable` finds a pair, respects `MAX_TIER`, and returns `(-1,-1)` on a no-pair board;
  - `bottom_filled` returns the lowest filled row and `-1` on an empty column;
  - `rush_hint_id` ordering: treefall wins during a telegraph; merge otherwise; `""` when the relevant
    thing is absent (no pair / no doomed tile) or the id is already seen.
- **Headless, scene wiring** (a focused suite modeled on `grove_ftue_tests.gd` — instantiate ExploreRush
  in-tree, seed `_grid` directly):
  - flag off → `_refresh_hand_hint` adds no overlay;
  - a seeded mergeable pair → `_refresh_hand_hint` presents a live `rush_merge` hint; `_end_hand_hint(
    "rush_merge")` clears it and marks it seen; a second refresh does not re-present;
  - a seeded telegraph over a filled column → `rush_treefall` presents even while `rush_merge` is unseen
    (priority); flinging out of the danger column (or a direct `_end_hand_hint("rush_treefall")`) clears
    and banks it;
  - the taught cell rect lines up with the real board cell (measure the node tree, do not eyeball).
- **Visual:** capture the Rush board with each hint through the quiet-godot shot path
  (`games/grove/tools/rush_shot.gd`) and look at the results before calling this done — confirm the hand
  sits on the mergeable tile, and on the bottom tile of the doomed column during a telegraph.
- `make test` green before merging.

## Out of scope

- No overlay changes. If a Rush-specific look (e.g. lighter dim) is ever wanted, that is a separate change
  to `hand_hint.gd`, parked.
- No teach for the general fling verb outside a telegraph — the bottom info bar already reads
  "Tap again to fling"; the treefall teach is specifically the *dodge*.
