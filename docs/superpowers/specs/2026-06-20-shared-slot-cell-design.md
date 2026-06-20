# Shared slot cell (bag + board) — design

Date: 2026-06-20
Branch: `worktree-bag-board-cell`

## Goal

Unify the bag cell and the merge-board cell into ONE component, on the board's cream-well art, and
wire the board to render through it. Add the states the board needs (unlockable highlight, a level
badge), reusing the HUD's level badge.

## Background

- **Board cells** (`engine/scripts/scenes/board.gd` + `engine/scripts/ui/piece_view.gd`): square cream
  wells. `_make_slot` → `slot_tile.png` (empty); `make_bramble` → `slot_locked.png` (the same well with
  a BAKED gold padlock) for gates, with a gold border + glow for `unlockable`, a receded alpha for deep
  (non-frontier) locks, and `_frontier_number_badge` docking `Look.make_level_badge` lower-right. Pieces
  and generators float as separate overlays ON the empty well.
- **Level badge** (`engine/scripts/ui/skin.gd::make_level_badge(level, px)`): the evolving medal. ONE
  builder powers the HUD top-left AND the board's locked-cell lower-right — already shared.
- **Bag cell** (`games/grove/tools/ui_workbench_kit.gd::bag_card`): its own art (`bag_card_empty.png` +
  the dynamic sparkle for "next"); states filled / empty / next / locked with a cost overlay.

## The component

Generalize `bag_card` into `Kit.slot_cell(d, opts)` (keep `bag_card` as a thin alias so the bag's
config key, workbench item, and tests don't churn). It renders the **background slot layer** on the
board's nine-patch well art; content (pieces) floats on top — the board's model.

`d.state`:
- `empty` (seen / unlocked) — bare `slot_tile.png`.
- `locked` (unseen) — `slot_locked.png` (baked padlock); optional `dim` alpha (deep, non-frontier).
- `unlockable` — `slot_tile.png` + the SHARED highlight (gold border + glow + dynamic sparkle). The
  bag's "next" maps here too (so bag-next and board-unlockable are the same highlighted state).
- `filled` — `slot_tile.png` + the piece on top (`make_content(size)` / `content` / `icon`).

Optional overlays (a cell shows one or neither):
- `cost` (int) → the acorn cost cluster (bag locked/next), below centre.
- `level` (int) → `Look.make_level_badge(level, …)` docked lower-right (board locked/unlockable) — the
  exact HUD badge.

`d.on_tap` (Callable) fires for `filled` (retrieve) / `unlockable` (buy or open). `empty`/`locked` inert.

`opts` (from `slot_cell_opts_from_config`, the renamed `bag_card_opts_from_config`): cell size, art
toggle, content/cost/lock metrics, `next_glow`/`next_twinkle` (the shared highlight's sparkle),
`level_frac` (the badge size as a % of the cell), `dim_alpha`.

### State mapping

| | empty | filled | unlockable | locked |
|---|---|---|---|---|
| Bag | owned-empty | owned + piece | "next" + cost | future + cost |
| Board | open ground | occupied (piece overlay) | frontier-openable + level | frontier gate + level; deep = dimmed, no level |

## Board rewire (point 2)

`board.gd::_make_slot` and `_make_bramble` / `PieceView.make_bramble` build their cell background via
`Kit.slot_cell(...)` instead of the bespoke panels. Pieces & generators stay the separate overlays they
already are (added on top of, or beside, the slot). The cell's `state` + `dim` + `level` come from the
board model exactly as today (`G`/`board_model` frontier + unlockable + required-level), so the board
renders IDENTICALLY:
- open empty → `empty`
- occupied → `empty` slot under the existing piece overlay (unchanged)
- frontier unlockable gate → `unlockable` + `level`
- frontier locked gate → `locked` + `level`
- deep (non-frontier) locked → `locked` + `dim`, no level

## Where it lives

The kit (`ui_workbench_kit.gd`). The engine already imports the kit (hud/vault/settings/bag_overlay).
`make_level_badge` (skin.gd) and piece/generator rendering are unchanged.

## Testing

- Kit cell (`grove_workbench_tests.gd`): each state builds a non-null Control; `unlockable` carries the
  highlight (a GPUParticles2D sparkle + a gold border); a `level` overlay docks a level badge
  (`lv_num` present) lower-right; a `cost` overlay shows the number; `empty`/`locked` are inert,
  `filled`/`unlockable` tappable; `bag_card` alias still builds every state.
- Bag suites (`grove_workbench_tests`, `bag_overlay_tests`) stay green — the bag now renders on the
  cream wells; the dialog structure (banner / grid / pill / footer) is unchanged.
- Board suites (`grove_placement_tests`, plus any board smoke) stay green — assert the cell counts /
  classification still hold; the board still builds its grid, frontier locks, and level badges.
- Visual: capture the bag screen AND the in-game board BEFORE and AFTER; the board must read the same
  (deep-dim, frontier lock, unlockable highlight, lower-right level badge). Deliver the captures; do
  not eyeball from a thumbnail.

## Out of scope

- No gameplay / economy / level-curve changes.
- Piece & generator sprites/rendering unchanged (they remain overlays).
- The level-badge component itself unchanged.

## Files

- `games/grove/tools/ui_workbench_kit.gd` — `slot_cell` (+ `bag_card` alias), states + level/cost/dim,
  the unified highlight; `slot_cell_opts_from_config`.
- `games/grove/tools/ui_workbench_view.gd` — the workbench item gains the new states/knobs (preview:
  empty/filled/unlockable/locked; level + dim toggles).
- `engine/scripts/scenes/board.gd`, `engine/scripts/ui/piece_view.gd` — render cells via `slot_cell`.
- `games/grove/tests/grove_workbench_tests.gd`, board/placement test deltas.
