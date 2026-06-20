# Bag screen in the UI workbench — design

Date: 2026-06-20
Branch: `worktree-bag-workbench`

## Goal

Add the **Bag** screen to the UI workbench as a first-class gallery item, built from the
shared kit so the game reads the same transform. Concretely:

1. A new **`bag_card`** building-block component (one slot tile, state-driven).
2. A new **`bag`** dialog that **reuses the shared `dialog_frame`** and the **`currency_pill`**.
3. Extend `currency_pill` so it can render a **single acorn** balance (not just the ★🪙💎 wallet).
4. **Rewire the in-game bag overlay** (`engine/scripts/ui/bag_overlay.gd`) to consume the new
   kit builders, so the game and the workbench share one transform (matching `vault`, `settings`,
   `daily`, `shop`, `hud`).

Visual target: `games/grove/assets/_originals/ui/bag.png` — a parchment frame titled "Bag",
an acorn balance pill top-right, a 6-wide grid of slot tiles (filled / empty / next / locked),
and a footer caption flanked by leaf sprigs.

## Background — current state

- The game already renders this exact screen via `BagOverlay.open(host, cfg)`
  (`engine/scripts/ui/bag_overlay.gd`), invoked from `board.gd:_open_bag_overlay()` (~line 1234).
  But it hand-builds bespoke chrome (`Look.kit_panel("parchment")`, `Look.banner_title`,
  `Look.close_button`, `Look.card_button` on `shop_card` art, an emoji `🔒` lock) — it does **not**
  go through the kit's `dialog_frame` or `currency_pill`, and it ignores the imported bag-specific art.
- The bag art is imported and currently **unused** in `games/grove/assets/ui/kit/`:
  `bag_card.png` (filled tile), `bag_card_empty.png` (empty tile), `bag_card_gold.png` (gold +
  sparkles = the "next" buyable tile), `bag_lock.png` (padlock), `bag_acorn.png` (acorn), plus
  `bag_leaf_l/r.png` (footer sprigs).
- In Grove the **"gem"/diamond currency icon is the golden acorn** (`ui/currency/icon_gem.png`).
  So the "🌰 132" balance and the "10🌰" slot costs are the gem currency. The cell costs and the
  balance pill use `make_icon("gem", …)`.
- The kit is loaded by the game at runtime: `var Kit = load(Kit.KIT_PATH)`,
  `Kit.load_config(Kit.CONFIG_PATH)` → a config dict → `Kit.<x>_opts_from_config(cfg)` →
  `Kit.<x>_dialog(...)`. `CONFIG_PATH = res://games/grove/tools/ui_workbench_settings.json`.

## Components

### 1. `currency_pill` — single-acorn mode (kit)

Extend `currency_pill(opts, counts)` with an optional **`opts["icons"]`** override:

- Default = the existing `CUR_PILL_ICONS` (`[["star",38],["coin",40],["gem",40]]`) → the wallet,
  unchanged. The HUD and `grove_ui_tests` never pass `icons`, so the live wallet is byte-identical.
- The bag passes `opts["icons"] = [["gem", 40.0]]` and `counts = {"gem": <balance>}` → a single
  acorn + number in the same cream capsule (`currency_pill_style`). The inter-pair spacer logic
  already no-ops for a single entry.

This is the truest reuse: same builder, same style, same `make_icon`.

### 2. `bag_card` — slot tile component (kit)

`static func bag_card(d: Dictionary, opts: Dictionary) -> Control`

`d` (data, content-agnostic so the kit stays free of game deps):

- `kind`: `"filled" | "empty" | "next" | "locked"`
- `content`: optional pre-built `Control` (the game passes `PieceView.make_piece(...)`); wins over…
- `icon`: optional icon id (the workbench demo passes `"leaf"` etc. → `make_icon`)
- `cost`: int — the acorn price shown inside `next` / below `locked`
- `on_tap`: optional `Callable` — fired on `filled` (retrieve) and `next` (buy); empty/locked inert

Rendering per `kind`, using the bag art (with code-drawn fallback when art is absent, per the kit law):

| kind   | card art            | centred content                | extra |
|--------|---------------------|--------------------------------|-------|
| filled | `bag_card.png`      | the piece (`content`/`icon`)   | tap → retrieve |
| empty  | `bag_card_empty.png`| —                              | inert |
| next   | `bag_card_gold.png` | acorn cost row (`N` + acorn)   | tap → buy; gold frame + sparkles read as "buyable" |
| locked | `bag_card.png` dim  | `bag_lock.png` padlock         | acorn cost row **below** the tile |

The tile is a press-juicing button surface (like `Look.card_button` / the daily card's button),
sized `cell_w × cell_h`. A `locked` tile reserves the same below-tile strip height as the others so
grid rows stay aligned (mirrors `bag_overlay._slot_cell`).

`bag_card_opts_from_config(cfg)` reads a `"bag_card"` config block → saved STYLE:
`cell_w, cell_h, cell_slice, cell_art, cost_font, cost_icon, lock_frac, content_frac`.

### 3. `bag` — dialog (kit)

`static func bag_dialog(entries: Array, balance: int, width: float, opts: Dictionary) -> Control`

Builds the **content** then wraps it in the shared `dialog_frame(content, width, opts)`:

- A top row, right-aligned, holding the **reused `currency_pill`** in single-acorn mode (`balance`).
- A `GridContainer` (`cols`, default 6) of `bag_card`s, one per `entries` item.
- A footer caption (e.g. "Open a slot with acorns.") flanked by `bag_leaf_l/r.png` sprigs.

`entries` is an `Array` of `bag_card` `d` dicts (already classified). The frame supplies the gold
"Bag" banner, the parchment panel, the docked red ✕ (wired to `opts["on_close"]`), and the scroll.

`bag_opts_from_config(cfg)` = `dialog_opts_from_config(cfg)` (shared frame) merged with
`bag_card_opts_from_config(cfg)` plus the dialog's own `width_pct`, `cols`, `row_gap`, `list_max_h`,
and `cost_*` style — same construction as `daily_opts_from_config` / `settings_opts_from_config`.

## Workbench wiring (`ui_workbench_view.gd`)

Register both ids following the existing `tiers_card` / `tiers` pattern:

- `IDS` += `"bag_card"`, `"bag"`.
- `COLUMNS`: add `["bag_card"]` to the building-blocks column; `["bag"]` to the dialogs column.
- `DEPENDENTS`: `"frame"` gains `"bag"`; add `"bag_card": ["bag"]` and `"currency_pill": ["bag"]`
  (editing the frame, the cell, or the pill rebuilds the bag dialog live).
- `TEST_KEYS`: `"bag_card": ["preview"]`; `"bag": ["balance", "owned", "filled"]` (preview-only state).
- `CAPTIONS`: `"bag_card"` and `"bag"`.
- `_params`: defaults for both (style keys mirror the kit defaults; preview keys for the state).
- `_make_element`: `"bag_card"` builds one cell at 2× preview zoom (like `tiers_card`) in the chosen
  `preview` state; `"bag"` builds `DEMO_BAG` entries → `Kit.bag_dialog(...)`.
- Sidebar `match`: a `bag_card` case (cell size/art, cost font, lock/content scale + a `preview`
  state `_option_row`) and a `bag` case (`width_pct`, `cols`, `row_gap`, preview `balance`/counts).
- A sidebar note for `bag` ("reuses the shared Frame + the Currency pill; the tile is on the Bag cell
  item") and for `bag_card`, matching the existing notes.

`DEMO_BAG`: a constant array of descriptor dicts (kind + demo `icon` + `cost`) composed to look like
`bag.png` (filled, empty, one `next`, several `locked`).

## Game rewire (`engine/scripts/ui/bag_overlay.gd`)

- Keep the pure `slot_plan(...)` / `_price_at(...)` classification (tests depend on it) and the modal
  scaffolding in `open(host, cfg)`: the dimmed veil, the `dismiss` seam, `FX.pop_in`, and dismissal
  on backdrop tap / retrieve / buy.
- Replace the hand-built card body (the parchment panel + banner + grid + counter chip + footer + the
  separately-docked ✕) with: load the kit, `cfg2 = Kit.load_config(Kit.CONFIG_PATH)`,
  `opts = Kit.bag_opts_from_config(cfg2)`, set `opts["banner_text"] = host.tr("Bag")` and
  `opts["on_close"] = dismiss`, map `slot_plan(...)` → `entries` (filled entries carry
  `PieceView.make_piece(bag[i], size)` as `content`; `next`/`locked` carry `cost`; `on_tap` wired to
  `on_retrieve` / `on_buy_slot`), then `Kit.bag_dialog(entries, balance, width, opts)` and add it
  under the veil.
- The kit frame owns the ✕ now (wired to `dismiss`), so drop the overlay's separate `Look.close_button`.
- The **generator section** (an optional row of generator tiles) has no analogue in `bag.png` and is
  game-only. Keep it appended **below** the kit dialog's content via a small extra path, OR fold it
  into the entries — decision in the plan; default: keep it as a game-only addendum so the kit stays
  bag-grid-only. `board.gd`'s cfg is unchanged.
- `width`: from the saved `bag` `width_pct` (× the live viewport), matching the other overlays.

## Art

All bag art already imported under `ui/kit/`. Resolution via `Look.kit("kit/bag_card.png")` etc.
Every art load is guarded by `ResourceLoader.exists` with a code-drawn fallback (kit law), so a
missing sprite degrades gracefully rather than crashing — and headless tests (no art import) still pass.

## Testing

- `grove_workbench_tests.gd`: `bag_card` builds a non-null Control in each of the 4 states;
  `bag_dialog` builds with the demo entries and contains a banner + a grid with the expected cell
  count; `currency_pill` with `icons=[["gem",…]]` renders exactly one icon+number pair (and the
  default call still renders three — pins the backward-compat contract).
- `bag_overlay_tests.gd`: keep all `slot_plan` classification + price-ladder assertions unchanged.
  Update the build-smoke test to the new structure: `open()` returns a live Control whose tree
  contains the kit dialog (a banner node + a grid with `max_slots` cells) and frees cleanly.
- Run `make test-fast` after each change; `make test` (incl. grove suites) before handoff.
- Visual verification: screenshot the workbench `bag` item and the in-game overlay (headless can't
  capture; use the `override.cfg` minimized-window pattern from the global CLAUDE.md) and compare to
  `bag.png` — do not eyeball from a thumbnail alone; deliver the capture.

## Out of scope

- No change to bag economics (`G.BAG_*`, prices, `Save.bag_slots()`), `board.gd`'s cfg, or the
  generator-bag behaviour.
- No new art; only wiring the already-imported sprites.

## Files touched

- `games/grove/tools/ui_workbench_kit.gd` — `currency_pill` icons override; `bag_card`,
  `bag_card_opts_from_config`, `bag_dialog`, `bag_opts_from_config`; `DEMO_BAG`.
- `games/grove/tools/ui_workbench_view.gd` — register `bag_card` + `bag` (params, columns,
  dependents, captions, make_element, sidebar).
- `engine/scripts/ui/bag_overlay.gd` — rewire the body onto the kit builders.
- `games/grove/tests/grove_workbench_tests.gd`, `engine/tests/bag_overlay_tests.gd` — coverage.
