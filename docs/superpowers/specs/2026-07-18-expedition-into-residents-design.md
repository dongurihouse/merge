# Home chrome rework: Expedition into Residents, side rail into the bottom bar — design

Date: 2026-07-18
Branch: `expedition-to-residents`

Two changes that share one seam — both retire parts of the home side rail, so they land together.

- **Part A** — every Expedition entry point on home retires along with the bucket dock surface;
  the Residents dialog absorbs the dock's place / merge / unplace and gains the Expedition entry.
- **Part B** — the side rail moves to a full-width bottom row of textured tiles, mock-styled
  (`home_screen_meadow_sky_v2_working_farm`), with Board kept at the bottom-right corner.

Part A's removal of the Expedition rail tile is subsumed by Part B removing the rail entirely.

## Part A goal

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

---

# Part B: the side rail becomes the bottom bar

## Goal

Replace the top-right LiveOps rail and the two-button bottom nav with a single full-width bottom
row of textured tiles, reading like the mock's Home · Board · Maps · Bag · Shop strip.

## The row

Seven tiles, left to right, spanning the full width inside the safe-area insets. The side rail is
removed entirely — nothing stays pinned top-right except the wallet and the Lv chip.

| # | Tile | Opens | Paper texture |
|---|---|---|---|
| 1 | Map | `_open_maps` (gallery) | `sky` |
| 2 | Residents | `_open_residents` | `green` (action) |
| 3 | Daily | `_open_daily` | `reward_gold` |
| 4 | Vault | `_open_vault` | `supporting_purple` |
| 5 | Mail | `_open_inbox` | `warm_kraft` |
| 6 | Settings | `_open_settings` | `structural_slate` |
| 7 | Board | `_on_board` | `coral` |

Grouping runs navigation → liveops → utility → primary, and Board sits in the bottom-right corner
as required.

`PAPER_SURFACES` in `ui_workbench_kit.gd` registers only `cream`, `sky`, `green`, `purple` today.
The textures for the rest already ship in `games/grove/assets/ui/meadow_v2/`
(`texture_coral.png`, `texture_reward_gold.png`, `texture_warm_kraft.png`,
`texture_structural_slate.png`), so this is four new `PAPER_SURFACES` entries with their fill
colours, not new art.

## Tile form

Each tile is the shared `Kit.home_button` in `shape: "rect"` form — the same recipe the rail and
the maps-page nav already use — with:

- `surface_role` per the table above;
- a caption under the icon (`RESIDENTS`, `DAILY`, `VAULT`, `MAIL`, `SETTINGS`, `MAP`, `BOARD`), as
  the mock reads. Captions come from `Strings.t`, with new keys under `map.nav.*` for the tiles
  that lack them;
- `shadow: true`, matching the current rail and nav treatment.

Sizing: tile width is `(view.x - 2*side_inset - 6*gap) / 7`, so the row fills the width exactly.
Height follows the tile width, capped so a tall caption never pushes the row into the map art.

**Honest note on density:** seven tiles across a 1080-wide design leaves each ~135px wide before
gaps. That is materially narrower than the mock's five, and the captions will be small. If it reads
badly in the render, the fallback is dropping captions on the narrowest tiles or moving Settings
back off the row — decided from the screenshot, not predicted here.

## Board keeps breathing, loses the disc

The Board tile is no longer the large circular orange disc. It takes the same rect tile geometry
and size as its six neighbours, on the coral texture, and keeps `FX.breathe_once(_play_btn)` so the
primary action still pulses. The merged Play↔Restore behaviour (`_refresh_play_cta` swapping icon
and action when the next spot is affordable) is preserved — only the shape and size change.

## Badges

Daily's unclaimed dot and Vault's ready-pip attach at the tile's **top-right**, the same relative
placement they hold on the rail discs. The rail's workbench-tuned offsets (`badge_dx`, `badge_dy`)
are re-tuned for the rect tile since they were tuned against a circular disc's transparent margin.
Mail's unread count-pill follows the same placement.

## Variable tile count

The row is built from a live spec list, not a fixed seven:

- the Mail tile is built only when `_has_inbox` (already a runtime `load()` guard);
- the Residents tile keeps its existing visibility gate
  (`Bucket.cells_total() > 0 or not Bucket.hand().is_empty()`).

Tile width is computed from the number of tiles actually built, so a 5- or 6-tile row still fills
the width.

## Removals (Part B)

- `_build_liveops_rail`, `_layout_liveops_rail`, `_rail_button`, `_place_rail`, and the rail
  geometry state (`_rail_px`, `_rail_margin_px`, `_rail_disc_px`, `_rail_opts`, `_rail_step_px`,
  `_rail_top_px`, `_wallet_bottom_y` if it has no other caller);
- `_make_map_button` and `_make_play_button` fold into the shared tile builder;
- the `NavBar.build` two-button row is replaced by the new bottom-bar builder.

`_refresh_liveops_badges`, `_refresh_piggy_pip`, and `_refresh_play_cta` survive — they are
re-pointed at the new tiles.

## Tests (Part B)

- `grove_ui_tests.gd` — the bottom row builds every expected tile in order; each tile carries a
  distinct `surface_role`; Board is the last tile and is not a disc; no rail node remains on `self`.
- `grove_info_bar_tests.gd` — the icon roster still resolves for every tile icon.
- `grove_explore_tests.gd` — home-chrome button lookups move from the rail to the bottom row.
- Badge tests assert Daily's dot and Vault's pip attach to their tiles and light on the same
  conditions as before.

---

## Phasing

Four green commits, `make test` clean at each:

1. **A-additive.** `residents.gd` gains the tap-target mutations, the contextual pill, the wrapped
   habitat grid, and the Expedition pill; `map.gd::_open_residents` passes `on_expedition`. Every
   existing surface still works — the dock and both nav tiles are untouched. New tests land here.
2. **A-flip.** The Part A removals, plus the test updates.
3. **B-additive.** The four new `PAPER_SURFACES` roles and the bottom-bar builder, built beside the
   existing rail so both render; the new tiles are asserted headlessly.
4. **B-flip.** Delete the rail and the old two-button nav; re-point the badge and CTA refreshers.

Verification is not eyeballed: the headless suites assert structure and mutations through the real
dialog and the real chrome, and the final home screen is rendered via
`games/grove/tools/map_shot.gd` (and the dialog via `residents_dialog_shot.gd`) and looked at
before the work is called done.
