# Expedition moves into the Residents dialog — design

Date: 2026-07-18
Branch: `expedition-to-residents`

## Goal

Retire every current Expedition entry point on home and retire the bucket dock surface with
them. The Residents dialog becomes the single spirit-management surface: it absorbs the dock's
place / merge / unplace actions and gains the Expedition (Load out) entry.

## Why

Today the acquire loop is spread across three surfaces:

- the home side-rail **Expedition** tile (`map.gd::_build_liveops_rail`), which actually navigates
  to the dock rather than opening a dialog;
- the **spirit dock** (`map.gd::_build_select` → `_build_hand_panel`), whose green Expedition chip
  opens the Load out overlay (`_open_expedition`);
- the maps-page bottom nav **EXPEDITION** tile, a third route into the same dock.

The Residents dialog (`ui/residents.gd`) already duplicates most of the dock — resource banks
(richer than the dock's line rows: it reads "FULL IN 2H 18M"), Collect all, habitat cells, the
on-hand grid, and an inspector with the tier ladder and Sell. The dock's only unique capability is
its drag layer: `map.gd:1551-1610` is the sole call site in the game for `Bucket.place`,
`place_merge`, `hand_merge`, and `unplace`.

So the dock cannot simply be deleted — its mutations must land in the Residents dialog first.

## Interaction model: tap-select, then tap-target

The dialog already carries session state `view.sel = {src: "hand"|"placed", idx: int}` and repaints
the whole body on every change. Extend that rather than porting the dock's drag machinery — the
drag is welded to the map scene's single-input-surface hit-testing (`_end_drag`, `_hand_orbs`,
`_placed_orbs`, `_hand_scroll`) and does not transplant into a container-laid-out `ui/` module.

Given current selection **S** and tapped target **T**:

| S | T | Result |
|---|---|---|
| none | any spirit | select T |
| hand | free cell | `Bucket.place(S.idx)`, clear selection |
| hand | placed spirit | `Bucket.place_merge(S.idx, T.idx)`; on `false` → select T |
| hand | other hand spirit | `Bucket.hand_merge(T.idx, S.idx)` — drop target first, so T climbs; on `false` → select T |
| placed | hand spirit | `Bucket.place_merge(T.idx, S.idx)`; on `false` → select T |
| placed | placed spirit | select T (the model has no placed↔placed merge) |
| any | itself | deselect |
| any | locked cell | no-op |

Rules:

- A successful mutation clears the selection and repaints; `repaint` already calls the host's
  `refresh` callback, so the wallet and rail badges re-read.
- A refused merge falls back to plain selection — never a silent no-op.
- Free habitat cells become tap targets. `Kit.slot_cell` only wires `on_tap` for the `filled`
  state, so an empty cell is wrapped in a transparent, focus-less `Button` sized to the cell.

## Inspector: one contextual pill

The inspector row stays `portrait · name · info · [contextual] · Sell`. The new pill sits left of
Sell and depends on the selection source:

- **hand** selection → `ResidentsPlaceButton` ("Place"), disabled when `Bucket.is_full()`
- **placed** selection → `ResidentsBringOutButton` ("Bring out") → `Bucket.unplace(idx)`

Unplace gets a pill rather than a tap-target: a container layout offers no unambiguous "drop into
the hand" region.

Both wear the cream/ink pill face already used for Sell, with the green accent instead of coral, so
the destructive Sell stays visually distinct.

## Expedition entry

A new action row below the inspector holds a single green pill, `ResidentsExpeditionButton`
("Expedition"), matching the Load out dialog's own `Kit.pill_button` green face.

- Built only when `opts.on_expedition` is a valid `Callable`.
- Gated on `Bucket.cells_total() > 0` — the same gate the dock chip used (`exped_open`): the acquire
  loop opens once any home building has granted a cell.
- On press: close the Residents overlay, then call `opts.on_expedition`.

`map.gd::_open_residents` supplies the callback as
`func() -> void: _open_expedition(_frontier_map())`, the exact behaviour the dock chip had.
`_open_expedition` itself is unchanged and stays in `map.gd`.

## Habitat cells wrap

`HABITAT_SLOTS_SHOWN = 5` currently renders every cell in one row, so a late-game cell count
squeezes them to slivers. Once this is the only habitat surface, the row becomes a
`GridContainer` of 5 columns; cell size is computed from 5 columns regardless of total, and rows
wrap. Node names (`HabitatCell_%02d`, `HabitatCellFree_%02d`, `HabitatCellLocked_%02d`) are
unchanged so existing assertions keep resolving.

## Removals

In `map.gd`:

- the rail Expedition tile `_residents_btn`, `_refresh_residents_btn`, and its rail slot in
  `_layout_liveops_rail` (remaining tiles close the gap);
- the maps-page nav third tile — the row becomes HOME · BOARD;
- the whole dock surface: `_open_select`, `_build_select`, `_build_hand_panel`,
  `_dock_chip_button`, `_dock_label`, `_inhand_info_bar`, `_on_dock_collect`, the drag layer, and
  the `_view == "select"` branches in nav / input / scroll handlers;
- the dock-only state: `_hand_panel`, `_cells_grid`, `_sel_orb`, `_hand_orbs`, `_placed_orbs`,
  `_hand_scroll`, `_hand_scroll_max`, `_select_scroll`, `_select_scroll_max`, `_select_back`.

Helpers shared with other surfaces (`_spirit_cell`, `_empty_cell`, `_force_ignore`, `_line_icon`)
are checked for other call sites before deletion — several are shared, and GDScript self-calls to a
missing method are parse errors, so the dead set is removed in one pass and smoke-tested.

In `games/grove/strings.json`: `map.page.nav_expedition` retires.

`ICON_EXPEDITION` stays declared in `home_chrome.gd` — the icon is still referenced by the
info-bar icon roster test and costs nothing.

## Tests

`games/grove/tests/grove_residents_tests.gd` (new cases, headless, through the real dialog):

- tap a hand spirit then a free cell → placed count climbs, hand shrinks;
- tap a hand spirit then a matching hand spirit → one spirit at tier+1;
- tap a hand spirit then a matching placed spirit → placed tier climbs;
- a refused merge (mismatched line/tier) selects the target instead of mutating;
- Place is disabled when the habitat is full;
- Bring out returns a placed spirit to hand;
- `ResidentsExpeditionButton` exists with a callback and is absent when `cells_total == 0`;
- pressing it closes the overlay and fires `on_expedition`.

Updated suites:

- `grove_explore_tests.gd` — the home-rail Expedition assertions invert to "no Expedition rail
  tile"; dock-node assertions (`BucketExpeditionButton`, `BucketCollectChip`, dock cells) retire;
  the `_open_expedition` overlay tests stay as-is.
- `grove_maps_page_tests.gd` — the nav row is HOME · BOARD.
- `grove_ui_tests.gd` / `grove_info_bar_tests.gd` — dock info-bar cases retire.

## Phasing

Two green commits, `make test` clean at each:

1. **Additive.** `residents.gd` gains the tap-target mutations, the contextual pill, the wrapped
   habitat grid, and the Expedition pill; `map.gd::_open_residents` passes `on_expedition`. Every
   existing surface still works — the dock and both nav tiles are untouched. New tests land here.
2. **Flip.** The removals above, plus the test updates.

Verification is not eyeballed: the headless suites assert the mutations through the real dialog,
and the final state is rendered via `games/grove/tools/residents_dialog_shot.gd` and looked at
before the work is called done.
