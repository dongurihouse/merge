# Cascade visual guide — one derived state

## The model

The guide has ONE state: an ordered array of marks, rebuilt from the board by one pure function and
handed to the renderer in one call. There are no per-channel arrays and no second writer.

`mode` is DERIVED at publish time, never stored:

| mode | condition |
|---|---|
| `RUN` | `chain_running()` |
| `DRAG` | not RUN, a non-generator piece is held |
| `REST` | otherwise |

A mark:

```
{
  role:   "chain" | "runway" | "target" | "stage",
  run:    Array[Vector2i],   # cells the contour light follows; empty for target/stage
  cell:   Vector2i,          # the pad cell; Vector2i(-1,-1) for chain/runway
  line:   int,
  n:      int,               # run length; 0 where the role has none
  weight: float,             # 0..1 — alpha strength
  reach:  float,             # halo tightness
  tag:    bool,              # this mark carries the ×n chip
}
```

`weight` and `reach` are the renderer's ONLY strength inputs. No loudness is derived from `role` in
the renderer.

## Knobs

```
REST_MAX       := 3      # resting marks drawn at once, chains first
DRAG_DIM       := 0.35   # weight of every non-winning mark during a drag
RUNWAY_WEIGHT  := 0.50   # today's runway strength
RUNWAY_REACH   := 0.78   # today's runway reach
MERGE_WEIGHT   := 0.55   # today's plain-merge target strength
```

`CHAIN_MIN_N` and `RUNWAY_MIN_N` stay in `board.gd`.

## Builder rules — `engine/scripts/core/cascade_marks.gd`, static and pure

### REST

1. Chains: `BoardLogic.ready_ladders(board)` where `n >= CHAIN_MIN_N`. Sort `n` descending; tie
   breaks on row-major `top_cell`.
2. Runways: `BoardLogic.runways(board, RUNWAY_MIN_N)`, row-major on first cell, appended after ALL
   chains.
3. Truncate the combined list to `REST_MAX`.
4. Chains: `weight 1.0`, `reach 1.0`, `tag true`. Runways: `RUNWAY_WEIGHT`, `RUNWAY_REACH`,
   `tag false`.

### DRAG

Marks depend on the held piece only, never on pointer position, so they are built ONCE at pickup.

Merge targets: every occupied cell where `board.can_merge(from, cell)`, each with
`n = 1 + chain_path(board, from, cell).size()`.

The winner is the target with the greatest `n` where `n >= CHAIN_MIN_N`; tie breaks on row-major cell.

Winner exists:

1. Winner target: `role target`, `weight 1.0`, `tag true`, `n`.
2. Winner run (`[winner cell] + chain_path`): `role chain`, `weight 1.0`, `tag false`.
3. Every other merge target: `role target`, `weight DRAG_DIM`, `tag false`.
4. Every REST chain and runway whose run is not the winner's: emitted at `weight DRAG_DIM`,
   `tag false`. The `REST_MAX` cap applies to these as at rest.
5. No stage marks.

No winner:

1. No `chain` and no `runway` marks.
2. Merge targets: `role target`, `weight MERGE_WEIGHT`, `tag false`.
3. Stage marks: today's three generators unchanged — `BoardLogic.chain_placements`,
   `_cascade_extension_pads`, `_single_neighbor_seed_pads` — `role stage`, `tag false`.

### RUN

Exactly one mark: `role chain`, `run = [head cell] + remaining run cells`, `weight 1.0`,
`reach 1.0`, `tag true`, `n = total run length`. Nothing else is emitted in this mode, and the mark
is republished at every step until `_finish_chain`.

### Tags

One tag per cell; the FIRST mark in list order claiming a cell wins. The list is already in
precedence order, so no separate precedence pass exists.

## Renderer — `engine/scripts/ui/cascade_outline.gd`

Keeps: `RAILS` and the solved edge profile, `lit_rails()`, `lit_crack()`, the contour walk, the
geometry cache, the travelling wave, `forced_phase`, `forced_level`, `LEVELS`.

New API: `set_marks(marks: Array)`. It replaces `set_ladders`, `set_runways`, `set_drag_ladders`,
`set_ghost_pads` and `clear_guides`.

`_draw` iterates `marks` in order and dispatches on `role` to one function each. `_sync_process`
runs the wave when any mark with `weight > 0` is present.

Deleted: `ladders`, `runways`, `drag_ladders`, `ghost_pads`, `_active_ladders()`, every
`if drag_ladders.is_empty()` precedence test, two of the three loops in `_rebuild_tags`,
`_mark_thickness`, `_thickness_for_n`, `_alpha_for_n`, `_edge_key`, `RUNWAY_WIDTH_SCALE`,
`MERGE_WIDTH_SCALE`, `STAGE_WIDTH_SCALE`, and the `inset_frac` / `thickness_frac` / `fill_pct` /
`jitter_frac` exports with their four setters.

## `board.gd`

`_publish_guide()` is the only writer. It derives the mode, calls the builder, calls `set_marks`,
and fixes the stack index. Call sites: `_rebuild_all`, `_after_board_change`, `_begin_drag`,
`_clear_drag_feel`, `_prepare_chain`, `_show_chain_preroll`, `_run_chain_step`, `_finish_chain`.

Deleted: `_refresh_cascade_outline`, `_show_cascade_drag_guides`, `_clear_cascade_drag_guides`,
`_armed_cascade_marks`, and the `set_ladders` write inside `_show_chain_preroll`.

Stack order: `_guide_stack_index()` returns the target child index, accounting for whether the
outline currently sits below the first item node. The invariant is `slots_max < outline_index <
item_min` and it holds in REST, DRAG and RUN.

Pre-roll pulse: the `modulate:a` tween stays, and `_publish_guide` kills it and resets
`modulate.a = 1.0` whenever the mode is not RUN.

## Tests

`engine/tests/cascade_marks_tests.gd` — new, pure, no scene:

- REST ranks longest first and truncates at `REST_MAX`.
- REST tie-breaks row-major on `top_cell`.
- Runways rank after every chain and share the cap.
- DRAG picks the longest chain target; every other mark carries `DRAG_DIM`.
- DRAG with no chain emits no `chain` and no `runway` mark, and still emits stage marks.
- RUN emits exactly one mark covering head plus remaining cells.
- One tag per cell, first mark wins.

`games/grove/tests/grove_cascade_tests.gd` — ported, plus:

- The stack invariant asserted in REST, DRAG and RUN.
- The run's glow survives every step: a mark with `weight > 0` covering the run exists on every
  frame from the drop until `chain_running()` goes false. This test MUST fail at the parent commit.
- At rest at most `REST_MAX` marks, longest first.
- The runway-weight assert reads the `weight` the renderer draws, not `_mark_thickness`.

Registration: add the new suite to `ENGINE_TESTS` in the Makefile, to `CLAUDE.md` and to the README
so `engine/tests/suite_registry_tests.gd` passes.

Evidence: one batched capture — rest, drag with a winner, drag with no chain, mid-run.

## Sequencing

1. Builder + its pure suite, unused by the game. Green.
2. Renderer gains `set_marks` and the role dispatch alongside the old setters. Green.
3. Flip `board.gd` to `_publish_guide`, delete the old channels and the dead renderer code, port the
   grove suite. Green.

Stage 3 lands after the peer worktree's `grove_cascade_tests.gd` change.
