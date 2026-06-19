# Home hub re-skin + home_asset intake — design

Date: 2026-06-18
Worktree: `.claude/worktrees/home-reskin` (branch `worktree-home-reskin`)

## Goal

Process the artist's `home_asset.png` UI kit and re-skin the hub screen to match
`home.png` (the composed reference), plus three specific changes:

1. Add the piggy bank to the bottom bar.
2. Move the side rail (Daily / Free / Inbox) to the top-right and restyle it with the
   kit's circular badges + caption tabs.
3. Make the level display slightly (~15%) larger.

## Source material

- `games/grove/assets/_new/home.png` — composed reference (the hub layout). Not shipped.
- `games/grove/assets/_new/home_asset.png` — the UI kit sheet on a transparent background.
  Sections: (1) currency pill 9-slice, (2) slim progress strip 9-slice, (3) green CTA shell
  9-slice, (4) small caption tab 9-slice, (5) generic rounded panel 9-slice,
  (6) progress-bar fill, (7) progress-bar track, (8) standalone circular shells + lock badge
  + red dot + gold star, (9) icons (flower/daisy, acorn, water drop, gift, faucet, mail,
  plus, lock, gear, shop, map, **piggy-bank jar**), (10) assembled examples (PREVIEW ONLY —
  not extracted).

## Target surfaces (existing code)

- `engine/scripts/scenes/map.gd` — the hub scene: `_build_chrome` (bottom nav + rail),
  `_build_liveops_rail` / `_rail_button` / `_place_rail`.
- `engine/scripts/ui/hud.gd` — top bar: currency pill + the top-left level badge.
- `engine/scripts/ui/nav_bar.gd` — shared bottom navigation row.
- `engine/scripts/ui/skin.gd` (`Look`) — `kit()`, `icon()`, `badge()`, `attach_badge()`,
  `make_level_badge()`. Drives art resolution for all of the above.

Key fact that keeps the diff small: `Look.icon(id)` resolves `ui/shared/icon_<id>.png`
(currency: `ui/currency/icon_<id>.png`) and falls back to a glyph; `nav_bar`/`hud` already
prefer kit art over a fallback. So **correctly-named PNGs re-skin most surfaces with no code
change.** Code changes are limited to the three tasks.

## Part A — Asset intake (`docs/design/asset-intake.md`)

`home_asset.png` is transparent-background irregular UI pieces → **`sheet`** category
(`games/tools/slice_islands.gd`, no chroma key).

1. Slice to scratch and read indices:
   `godot --headless --path . -s res://games/tools/slice_islands.gd -- \
     games/grove/assets/_new/home_asset.png /tmp/peek/cell_`
2. Open `/tmp/peek/cell_<n>.png`, map each kept island → name/path. **Skip** the baked
   section-label text islands and every section-10 "assembled example" island.
3. Author `games/grove/assets/_new/home.plan.json`.
4. `make intake PLAN=home.plan.json` (or `make intake`). Verify outputs landed, raw archived
   to `_originals/ui/`, plan moved to `_new/_processed/`, reimport ran.

### Output mapping (final island→path decided after the scratch slice)

| Kit piece | Output path | Consumer |
|---|---|---|
| Currency pill 9-slice | `ui/shared/panel_pill.png` (replace) | `hud._pill_style()` |
| Progress strip frame | `ui/kit/strip_frame.png` | map progress pill |
| Progress-bar fill / track | `ui/kit/strip_fill.png` / `ui/kit/strip_track.png` | map progress pill |
| Green CTA shell 9-slice | `ui/kit/cta_green.png` | sliced for availability (not wired — see decisions) |
| Caption tab 9-slice | `ui/kit/tab_caption.png` | rail labels |
| Rounded panel 9-slice | `ui/shared/panel_parchment.png` (replace) | generic panels |
| Circular shell | `ui/shared/btn_round.png` (replace) | rail + chrome round buttons |
| Lock badge | `ui/shared/icon_lock.png` | locked-cell gate |
| Currency icons: acorn, honey, water | `ui/currency/icon_<id>.png` | wallet `_pair` |
| Chrome icons: gear, shop, map, gift, faucet, mail, plus, piggy | `ui/shared/icon_<id>.png` and/or `ui/nav/nav_<id>.png` | nav + rail |

Existing currency code ids are `star` / `coin` / `gem` mapped to roles (see `skin.gd`
ICON_GLYPHS note). Re-skin updates the **art** behind those ids; ids/roles are unchanged.

## Part B — The three tasks (code)

### 1. Piggy → bottom bar
- Remove the piggy entry from `_build_liveops_rail` (`map.gd:1488`).
- Add a 5th `NavBar` spec in `_build_chrome` (rightmost): `nav_piggy.png` → `_open_vault`.
- Move the claimable ready-pip (`_piggy_pip`, driven by `_refresh_piggy_pip` →
  `Vault.claimable()`) onto the new nav button via `Look.attach_badge`.

### 1b. Bottom bar realigned + resized to match the board
The board (`board.gd:220`) sizes its shared nav at **px 140** for side buttons and **184**
for the centered primary (Home). The map currently uses 96 (sides) / 140 (Play) — too small
and the primary sits off-centre. Bring the map's bottom bar to the **same sizing and
alignment as the board**:
- Side buttons → **px 140**; the primary Play (leaf) → **px 184**.
- Reorder so the primary is **centred** (3rd of 5), mirroring the board's centred Home:
  `gear · shop · Play(leaf) · map · piggy`. This is the "realign" — Play was 2nd of 4 and
  would be 2nd of 5 after adding piggy; centring it matches both the board and `home.png`.
- The `_shop_btn` / Store-badge anchor index is updated for the new order.

### 2. Side rail → top-right + kit badges
- `_place_rail`: anchor **top-right**, stack **downward** from below the currency pill
  (instead of bottom-right stacking up). First slot sits clear of the wallet pill's bottom.
- `_rail_button`: build a framed circular badge using the circular shell art + a real kit
  icon (gift / faucet / mail as the reference shows) + a small caption tab ("Daily" /
  "Free" / "Inbox") beneath. Keep `Look.badge` for the actionable cue — the calm rule
  (badge pulls, not the button) is preserved.
- **Rail button size = the bottom-bar side-button size (px 140)** — the rail buttons match
  the bottom bar (and the board), per `home.png`. (Up from the current 72.) The downward
  stack and caption tabs are sized to this.
- **Mail/Inbox badge shows the unread number** (like the reference's red "3"): the Inbox
  badge is `Look.badge("pill", n)` — a red disc with the white count — pinned to the icon's
  top-right corner and driven by `_refresh_liveops_badges` (`inbox.unread_count()`).
- Rail entries after the move: Daily, Free, Inbox (Inbox still guarded by `_has_inbox`).

### 3. Level display ~15% larger
- `hud.gd`: bump `lv_px` 88 → ~100.
- Scale the level number proportionally: bump `_lv_font_size` returns (36/28/22) ~15%
  (→ ~41/32/25) so the digits stay centered in the larger medal.

## Decisions made

- **Scope:** full hub re-skin (apply the whole kit), not targeted-only.
- **"size rail" = the LiveOps side rail** (Daily/Free/Inbox), confirmed.
- **Level display:** ~15% larger.
- **Garden CTA:** keep the current round leaf Play button (a deliberate recent change);
  the wide green "enter garden" CTA shell is sliced for availability but **not** wired.

## Testing / verification

- `make test-fast` after each change (inner loop); `make test` before handoff.
- Fresh worktree needs a warm import first (`godot --headless --import`) or grove suites
  crash on empty const chains.
- Visual: `GAME=grove make shot-map` and compare against `home.png` (brighten any
  FTUE-dimmed capture). Confirm: piggy in bottom bar, rail top-right with caption tabs,
  larger level badge, re-skinned pill/icons.

## Out of scope

- Non-hub map scenes (§16 art pipeline, handled separately).
- Reverting the round-leaf Play decision.
- The board (merge) screen — only the hub.
- Processing `vault_asset.png` (also pending in `_new/`, but not requested here).
