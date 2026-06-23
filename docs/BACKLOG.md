# Backlog — parking lot

Deferred / discovered work, parked as one-liners with enough context to pick up cold. This is a
**parking lot, not a worklist**: the Dev decides what's pulled next; nothing here is "in progress."
On pickup, an item becomes a `T#` task in [`TASKS.md`](TASKS.md). Format + rules:
`~/.claude/docs/engineer.md`.

Most items trace to the **engine-wide `merge_spec` audit (2026-06-14)**. Since shipped and dropped
from here: the generator + quest core (T17–T20), the map model + `zone`→`map` sweep (T21, T38), the
burst sink + level-gating (T23–T25, T37), the **selling bands + Shop buy-sinks + bag 6→18 model
(T39–T41)**, and the **2nd economy batch — keystone hub-yield (T42) · live-IAP + rewarded ads +
out-of-water offer (T43) · piggy vault + forgiving login calendar (T44)** (parallel worktree batches,
2026-06-15; the T45 entry-point wiring is committed on `t45-integration`, **held** behind the active §16
map work — see the economy item below); and the **4 `merge_spec`-audit gap fixes** — gate-quest
randomization (§7), generator-grant scheduling (§6/§7), the spawn tier-bias dial (§6, off by default),
and the shop-reroll button (§10) — shipped 2026-06-16 (`d492d67`). Code anchors are `file:line` and **drift** — after the
`core/ui/scenes` layering split many paths moved (`content.gd`→`core/content.gd`, `board.gd`→
`scenes/board.gd`, `shop.gd`→`ui/shop.gd`); trust the symbol name over the line number.

---

## Open — UI language & colour redesign (2026-06-17)

Systematic UI-language + colour-scheme redesign — a **light warm-neutral `#EDE6D2`** board so items pop, a three-plane depth ladder (Sunk/Rest/Float), and de-overloaded green (reclaimed as the CTA/growth signal). Full spec: [`superpowers/specs/2026-06-17-ui-language-redesign-design.md`](superpowers/specs/2026-06-17-ui-language-redesign-design.md).

**SHIPPED (2026-06-17).** Phase 1 palette foundation (**T50**, merge `186bdc0`) + Phases 2–4 (**T51**, merge `daf6f2f`): semantic role tiers in `grove_palette.gd`; the **Sunk** elevation tier; board field → flat `SURFACE`, empty cells → `CELL_EMPTY`, **locked cells recede** (light `LOCKED` well + quiet glyph, dark bramble overlay + chip gone); **de-greened honey level token**; **light quest band** + bigger giver busts; **light bottom nav** (home icon); shop/overlay coherence pass; and the **12-icon chrome kit** (`ui/kit/icon_*`, + new `bag`/`map`/`sprout`). The board reads light top-to-bottom, locks recede, green = CTA only. Full headless gate green (palette 25/0, grove 489/0) + three adversarial verify passes. Dead `bramble_*` + `fence_grove` art removed.

**Parked tails (follow-ups — NOT regressions):**

- **Textured garden-bed backdrop (§2, content-art).** The field ships as a flat `SURFACE` fill; spec §2 wants a subtle hand-painted tilled-soil mat. Process a soil tile (`assets/llm/llm_dirt`/`llm_board`) → swap behind the cells (`board.gd` `_field_backdrop`). `bg_grove_board.png` is now unreferenced — reuse or replace.
- **Item grounding + `ITEM_BOX` optical scale (§4, ux-feel).** Items still render via `PieceView.make_piece` without contact-shadow grounding or a normalized per-item optical scale (mirror HUD `CHIP_ICON_BOX`/`*_OPTICAL`) so a big item doesn't dwarf a small one. *(Lower impact — items already read fine.)*
- **Map-page chrome (ux-feel).** The map view (painted-art context, not the light `SURFACE` board) keeps dark borders/chests/power-pill (`map.gd` `#2A1C11`/`#2A2620`/`#4A4F46`) — evaluate against the map art separately; not a board clash.
- **Colour-token consolidation (tech, success-criterion 6).** Pre-existing hardcoded `#33402F`→`Pal.INK` (board/giver/merchant labels) + the gem-FX reward tints (`#A9C7E8`/`#BFE6F2`, ~10 sites) want shared tokens. No visual change; a clean sweep. *(Pre-existing, not a redesign regression.)*

## Open — HUD, currencies & button chrome (presentation + monetization funnel)

*Surfaced 2026-06-16 — UI design pass against two reference cozy/merge games. Our currency set is already **richer** than either reference (⭐ star = soft progression / restores places + drives Level · 🌰 acorn = soft coin from hub yield · 💎 gem = premium hard / IAP · 💧 water = board energy); the gaps are **affordances, hierarchy, and polish — not more systems**, and several backends already exist and just need surfacing. Anchors: HUD top bar `engine/scripts/ui/hud.gd` `build`; bottom chrome `engine/scripts/scenes/map.gd` `_build_chrome`; buttons/panels/icons `engine/scripts/ui/skin.gd` (`button` · `kit_panel` · `icon`; the old `stat_chip` pill is **removed**, T48 — see the rebuild item below). All dials in `engine/scripts/core/tuning.gd` — `Tune.Hud` (PILL_* · STAR_ICON/COIN_ICON/GEM_ICON · LV_* · XP_*) and `Tune.UiSkin` (BTN_* · KIT_* · CHIP_* · PARCH_* · TITLE_* · ICON_PX). Build the **polish item first** — it makes everything else look finished; then the funnel items. Verify every visual with a composite/zoom capture over BOTH a cream-parchment AND a busy grass/sky background (never eyeball).*

- **Reintroduce the burst-upgrade buy UI in the new UI styles (T48 follow-up — Dev-requested, tracked).** The on-board "Burst L#" buy pill was the dark `stat_chip`/`panel_chip` capsule, **removed in T48** (2026-06-17) ahead of this redesign. The §6/§10 burst **coin sink is fully intact in code** — `board.gd` `_gen_burst_level` + `_upgrade_gen_burst` (spend + cap rules), cost ladder `BURST_UPGRADE_COSTS` + `burst_count` in `content.gd`, level persisted as `grove()["burst_lvl"]`, all still unit-tested. **What's missing is only the buy affordance.** **Build:** a burst-upgrade buy chip in the **new Rest-plane cream-chip language** (per the redesign §6/§8 — one corner-radius/elevation family, Micro-size "Burst L#" label), wired to the existing `_upgrade_gen_burst` (it already owns broke/maxed refusal + feedback hooks). **Design call to settle on pickup:** where it anchors — back on the primary generator (where it was), or relocated to the home hub (the sink is GLOBAL — one `burst_lvl` sizes every generator, so a hub home is arguably cleaner than a board-cell pill). **Asset:** `panel_chip.png` is deleted; the new chip is code-built (StyleBoxFlat in the new palette) or a freshly generated nine-patch on the redesign's chip recipe — not the old art. **Acceptance:** tapping it raises `burst_lvl` (bigger pop) and spends the ladder cost; refuses cleanly when broke/maxed; reads as one consistent chip with the rest of the new HUD. *(Surfaced 2026-06-17 — T48 removal; pairs with the two reads below + the polish item.)*

- **Restore the other two reads blanked by the retired dark pill (T48) — vault gem-balance · merchant sell-value.** The same `stat_chip` removal also blanked two number-reads (the burst buy is its own item, above): **(a) vault gem balance** (`vault.gd`) — the jar still conveys balance visually; restore the explicit number read in the new chip. **(b) merchant sell-value** (`merchant_stand.gd`) — the stall still brightens on drag (`board.gd` `_show_sell_affordance`), but the live "+N🪙/💎" value tag is gone; bring it back as a new-language chip (a real affordance, not decoration). **Orphaned dials to fold into the `tuning.gd` rework:** `UiSkin.CHIP_PAD_X/Y`, `CHIP_ALPHA`, `STAT_NUM_SIZE`, `UiSkin.CHIP_ROW_SEP` are now unused (left in place, harmless); `RADIUS_CHIP` stays (this redesign's radius scale uses it). Spec: the redesign's "Precursor" note in `docs/superpowers/specs/2026-06-17-ui-language-redesign-design.md`. *(Surfaced 2026-06-17 — T48 removal.)*

- **Button & panel POLISH — the "sticker" recipe (borders · shadows · corners · icon alignment · hierarchy).** The top-priority visual pass; today buttons read flat on busy backgrounds. **Build:** (a) **Two-tone rim** — add a thin LIGHT/cream inner highlight (~1.5px, ~0.7α) inside the existing darker outer edge, so every button/pill reads as a crisp sticker on any background. StyleBoxFlat has one border colour, so either (preferred, art lane) bake the rim into the kit nine-patches (`btn_round.png`, `panel_*.png`), or (code) nest an inner StyleBoxFlat / use `expand_margin` for the light ring. New dials `UiSkin.RIM_LIGHT`, `RIM_LIGHT_W`. (b) **Two shadow tiers** in `UiSkin` — `SHADOW_RESTING` (chips/pills: ~rgba .16, size 4, offset (0,2)) and `SHADOW_RAISED` (primary CTA + floating round buttons: ~rgba .28, size 10, offset (0,5)) — softer + larger than today's flat size-5 so primaries clearly float; pressed state drops to resting (already true for `button` via `BTN_PRESS_*`; extend to the round chrome buttons, which today don't animate their shadow). (c) **Corner-radius scale** — collapse the five current radii (`PILL=40` · `PARCH=26` · `BTN=28` · `CHIP=20` · `TITLE=20` · card=20) to: capsules (currency pills, Level chip) = fully rounded (radius = height/2, computed not fixed); round chrome = circle; all rectangular surfaces (cards/CTA/parchment/title) = ONE shared `UiSkin.RADIUS_CARD` (~24); small chips = `RADIUS_CHIP` (~14). (d) **Hierarchy + colour-by-function** — 4 tiers: primary CTA (saturated green, raised shadow, biggest) → Store (warm coral/amber fill, badged, 2nd) → round chrome map/vault/settings + LiveOps rail (cream, resting shadow, circle) → currency capsules (cream, resting). Money = warm, nav = cream, gem = teal. **Acceptance:** no two same-class surfaces use different radii; a button stays legible as a sticker over grass AND parchment (2-background composite); primaries cast a visibly larger shadow than chips. *(The user's explicit ask: borders, stand-out, shadow, curved corners, icon alignment.)*

- **Currency cluster — acquire affordances + identity (the #1 monetization gap).** Today the wallet is passive numbers with **no path to "get more"**, the Home button is mixed *inside* the currency pill, and the three icons are different sizes (`STAR_ICON=44`/`COIN_ICON=40`/`GEM_ICON=38`) so they don't share a centerline. **Build:** (a) a small **`+` button** on the buyable currencies (gem always → opens Store/IAP to that pack; acorn optional → Store) — `hud.gd` `build`, route through the existing `open_shop`. (b) **Normalize icons** — one fixed icon BOX per slot (e.g. 40px), every icon centered in it, per-icon *scale-within-box* tuned for optical parity, number baseline-aligned with a constant `CHIP_ROW_SEP` gap. (c) **Pull Home OUT of the wallet** — it's nav, give it its own chip (or fold into the bottom chrome). (d) **Identity** — lock a colour language (star = gold, acorn = warm brown, gem = teal) so the gem stops reading as a water drop; consider a small token/disc behind each. (e) Fresh-save **0 / 0 reads dead** — seed a small starting gem balance + a one-line "what's this?" on first tap. **Acceptance:** the three currencies share a common box + centerline; a `+` is reachable from the map in ≤1 tap. *(Water stays board-only unless it begins gating map actions.)*

- **Store — promote to a persistent, badged entry + buy funnel.** Both references put Store top-right, prominent; ours is a tiny equal-weight round button in the bottom cluster (`map.gd` `_build_chrome`, the `cart` button). **Build:** relocate/restyle Store to a prominent, always-visible button (warm fill per the hierarchy above), wire the currency `+` to open it to the right pack, and add a **"new offer" badge** (uses the badge component below). Surface the existing starter-pack / featured offers (`grove_data.gd` `STARTER_PACK`, `SHOP_*`) when available. **Acceptance:** Store is reachable in 1 tap from anywhere on the map and shows a badge when a new/featured offer is live.

- **Badge system — ONE consistent red-dot / count component.** The references run almost entirely on red "!" dots to pull players to claimable rewards / unread mail; we have exactly one bespoke pip (the piggy `_piggy_pip` in `map.gd`). **Build:** a single reusable badge in `skin.gd` (red dot with white rim for "something new"; red pill with a number for counts like inbox-unread; consistent top-right overhang, size, z-order). Drive it from claimable-state queries (vault ready, daily available, unread mail, new offer). Replace the ad-hoc piggy pip with it. **Acceptance:** every actionable surface (Store, Daily, Free, Inbox, Vault, Settings) can show the same badge; it appears only when truly actionable.

- **LiveOps buttons — surface Daily · Free(ad) · Inbox (backends mostly exist).** We **have** the login calendar (`core/login.gd` — auto-popup only, no button) and the rewarded-ad / 2× system (`core/ads.gd`, the post-collect doubler) but neither has a **persistent entry**, and there is **no inbox**. **Build:** a calm vertical rail (right edge) of round buttons — **Daily** (persistent entry to the existing login calendar, badged when claimable), **Free** (a persistent rewarded-video → gems faucet, reusing `ads.gd`), and **Inbox** (NEW — a small mailbox for LiveOps gifts / compensation / news, with an unread count badge). Keep the rail calm (cozy, not the references' clutter): buttons auto-hide or de-emphasize when nothing is actionable; the badge does the attention-pulling. **Acceptance:** Daily + Free reachable persistently (not just via auto-popup); Inbox stores and grants gifts; all three use the shared badge. *(Inbox is the one net-new system; Daily/Free are mostly wiring.)*

- **Task strip — a short-term goal + reward loop wired to the next spot.** A reference (Juice) shows "Task 1/4 → chest"; we have the place-restore goal ("31 left") but **no chrome task loop with a reward**. **Build:** a slim cozy strip above the "Tend the garden" CTA — "Today's task ✿ N/M → 🎁" — chained off the existing restore-the-next-spot goal so the cozy spine *is* the task loop (not a bolted-on quest). Reward = small acorn/water/gem grant. **Acceptance:** the strip reflects real spot/quest progress and pays out on completion; it never blocks play. *(Lower priority than the funnel + polish; pairs with the §17 live-ops/events framework above.)*

## Open — Home-screen (map) chrome → the `farm_ui` mockup (2026-06-18)

*Surfaced 2026-06-18 — owner UI review of the home/map screen against the authored mockup [`assets/_originals/unref/farm/farm_ui.png`](../assets/_originals/unref/farm/farm_ui.png) and its sliced component sheet [`assets/farm/farm_icons.png`](../assets/farm/farm_icons.png). The mockup is the target: a standalone gold **level ring** top-left (no home chip beside it), a cream **currency pill** top-right, round **unlock-cost badges** on buildings, ONE cream **"N to the next place" progress pill** with a green bar, and a clean **bottom nav row** of round buttons. This section is the map-scene counterpart to the sibling "HUD, currencies & button chrome" section above and **supersedes that section's "Map-page chrome (ux-feel)" parked tail** (the map's dark borders/plank/scattered chrome). Anchors: top bar `engine/scripts/ui/hud.gd`; map chrome `engine/scripts/scenes/map.gd` (`_build_hud`/`_build_chrome`/`_map_title_plank`/`_home_badge`/`_build_task_strip`); board nav `engine/scripts/scenes/board.gd` (`_make_nav_button`). The mockup pieces are NOT sliced yet — do the **slice item below first** (it is the art source for items 1/3/4/5). Verify every visual with a quiet capture (`make shot-map`) — never eyeball.*

- **0 · Slice `farm_icons.png` into kit assets (art-prep · do first).** The mockup components live in one sheet ([`assets/farm/farm_icons.png`](../assets/farm/farm_icons.png)): the empty + locked **round badges**, the **"+" / star** glyphs, the wide **progress-pill** background + its **green fill + sprout** caps, the **level ring** ("15"), and the **bottom nav round buttons** (gear · market · leaf/garden · map · potion-piggy). **Build:** slice into `games/grove/assets/ui/kit/` PNGs (or AtlasTexture regions) following the existing pattern — `games/grove/tools/slice_badges.gd` already slices `assets/board/lvls.png` → `kit/badges/badge_NN.png`, driven by a small JSON region map (`data/level_badges.json`). Name the new pieces so the items below can `Look.kit(...)` them (e.g. `badge_cost.png`, `badge_locked.png`, `pill_progress.png` + `pill_progress_fill.png`, `nav_garden.png`/`nav_map.png`/`nav_piggy.png`/`nav_market.png`). **Acceptance:** each piece loads via `Look.kit` and reimports cleanly (no stale `.ctex` → no checkerboard). *Blocks 1/3/4/5.*

- **1 · Level badge — kill the "white grid", render the standalone ring (`hud.gd`).** *Problem:* the level chip's frame `TextureRect` draws Godot's **missing-texture checkerboard** ("white grid") when the imported badge `.ctex` is stale — `_safe_tex` (`hud.gd:349`) only rejects a *null* `load()`, so a non-null editor-placeholder slips through and fills the square frame rect (`hud.gd:128-134`); in the quiet build it instead falls all the way to the flat honey token, confirming the art isn't loading cleanly. *Direction:* (a) harden the load — verify the loaded texture is a **real image, not the placeholder** (e.g. check `get_size()`/format against the placeholder, or force-reimport), so the honey-token fallback (`hud.gd:135-141`, round, warm) is the *only* fallback and a checkerboard can never show; (b) render the clean standalone gold ring from the mockup (cream center, INK number) — reuse the evolving `kit/badges/badge_NN.png` system (`hud.gd:357` `_frame_tex`, `data/level_badges.json`) but on the freshly sliced ring from item 0. *Refs:* `hud.gd:103-149` (avatar/disc/frame), `hud.gd:349` `_safe_tex`, `hud.gd:357` `_frame_tex`; mockup top-left "15".

- **2 · Remove the home chip on the home/map screen (`hud.gd` + `map.gd`).** *Problem:* a separate cream home-pill renders to the right of the level ring (`hud.gd:306-335` `_build_home_chip`) because `map.gd:1375-1380` passes a `home` callback — but on the home screen that nav is redundant (you're already home) and the mockup shows the level ring **alone**. *Direction:* don't render the home chip on the hub/map scene — drop the `home` opt in `map.gd`'s `Hud.build` (or gate the chip off when the scene is the hub). The board still passes `home` (its nav legitimately returns to the map). *Note:* dovetails with the sibling section's "Currency cluster … (c) Pull Home OUT of the wallet" — that split already happened; this removes it on the home screen specifically. *Refs:* `hud.gd:306` `_build_home_chip`, `map.gd:1375-1380`.

- **3 · Unlock-cost badges — round dashed "+ / ★N" badge + locked variant (`map.gd`).** *Problem:* `_home_badge` (`map.gd:487-512`) draws a plain disc (`assets/farm/badge.png`) with brown "★N" text — not the mockup's badge. *Direction:* rebuild it from the sliced art (item 0): a **round dashed cream badge** with a "+" and "★ N" stacked on a second line for an affordable/unlockable spot, and a **locked variant** (lock glyph + sprout, the darker disc) for a still-gated spot — pick the variant from the spot's gate/affordability state. Keep it centered on the building and mouse-ignored (decoration; the spot hit-area is separate). *Refs:* `map.gd:487-512` `_home_badge`; sliced `badge_cost.png`/`badge_locked.png`; mockup "+ ✿20" badges + the bottom-left locked disc.

- **4 · Bottom row — extract ONE reusable parameterized nav component, reuse on board + map.** *Problem:* the board has a clean even nav row (`board.gd:260-310` via `_make_nav_button` `:1191` + `_nav_spacer` `:1185`) but the map's bottom is **scattered** — a "Tend the garden" CTA (`map.gd:1399`), a gear bottom-right (`map.gd:1413`), a store sticker bottom-left (`map.gd:1460`), plus the atlas/piggy cluster — all in `_build_chrome` (`map.gd:1396`). *Direction:* extract the nav-row builder into a **shared component** (e.g. `engine/scripts/ui/nav_bar.gd`) that takes a list of button specs `{icon, action, enabled/visible, label}` and lays them out evenly; have **both** board and map build their row through it. The home row = **Enter Garden** (`_on_board` — the green CTA, center) · **Shop** (`_open_shop`) · **Piggy bank** (`VaultUI.open`, `map.gd:22-23`) · **Map** (`_open_select`, `map.gd:270`) · **Settings** (`_open_settings`). All five entry points already exist — this consolidates the scattered stickers into the row; the piggy "claimable" pip (`_piggy_pip`, `map.gd:102`) rides its button. The board keeps its own set (Home·Shop·Leaf·Gear·Bag) via the same component. *Refs:* `board.gd:1185-1213` (component to generalize), `map.gd:1396+` `_build_chrome` (chrome to replace); mockup bottom row; sliced `nav_*` from item 0.

- **5 · Progress pill replaces the top plank; drop the map name; keep the Today strip (`map.gd`).** *Problem:* the dark wood **"The Farmhouse / N left"** plank (`map.gd:638-675` `_map_title_plank`, star row `:1038` `_stars_left_row`) doesn't match the mockup. *Direction (owner choice — option 2):* replace the plank with the mockup's **cream progress pill** — gold star + "**N to the next place**" + a **green progress bar** (sliced `pill_progress*` from item 0), wired to the stars-remaining-to-next-place metric (reuse `map_stars_left` / the next-place value; confirm which on pickup). **Drop the map name entirely** (mockup shows no name plank). **Keep** the existing bottom **"Today N/M → 🎁"** task strip (`map.gd:1736` `_build_task_strip`) — it stays as the daily-restore loop. *Placement:* the pill takes the **plank's top-center slot** so it doesn't collide with the Today strip at the bottom (the mockup shows the pill at the bottom, but that mockup has no Today strip — keeping both means pill-top / strip-bottom; flag for an owner eye-call on the composite). *Refs:* `map.gd:638-675` `_map_title_plank`, `map.gd:1038` `_stars_left_row`, `map.gd:1736` `_build_task_strip` (KEPT); mockup bottom "✿ 12 to the next place" pill.

## Open — board & quest visual/UX polish (owner review 2026-06-16)

A board+quest readability/feel pass from the owner's review against two reference merge games — the
board reads as a debug grid (ugly brambles + per-cell "Lv N" text, givers blending into the fence, a
flat fence↔board seam, ad-hoc badges, an under-used bottom). **Scope = the board + quest surfaces only.**
The **currency pills, Store, HUD top bar, red-dot/count badges, and LiveOps/bottom-map chrome are the
sibling *"HUD, currencies & button chrome"* section above** ("coin pills are worked on separately") — out
of scope here; where a shared primitive is needed (the "sticker" badge), reuse the one being built there.
**Coordinate before pickup — overlapping work is IN FLIGHT (uncommitted worktrees):** `board-polish`
already reworks the **board background** (a raised wooden planter + tilled-soil bed), the **fence↔board
joint** (the planter rim replaces the "glass-bar" margin; drifting clouds in the sky band), and adds a
**parchment sign-board plaque** behind each giver; `agent-a7a4921469ea92722` (`skin.gd`/`tuning.gd`) is
building the shared two-tone **"sticker" badge recipe** (`_RimOverlay`, `Tune.UiSkin.RIM_LIGHT`) that
items 1/4/5 should consume. Each item notes the overlap.

- **1 · Brambles + the Lv gate badge — kill the debug-grid look (NOT in board-polish).** *Problem:* the
  level-gated obstacle tiles are ugly and the white "Lv N" text is hard to read on them; the **frontier
  cells (Lv1/2/3) fall back to a flat panel** because `ring := mini(lvl/2 - 1, 3)` yields `-1/0/0` and only
  `bramble_{1,2,3}.png` exist; and "Lv N" is stamped on **all ~30 locked cells** (text-heavy, against
  no-required-reading). *Direction:* either a **simple, calm obstacle treatment** OR drop the bramble
  texture on the near cells for a **nicely styled "Lv" badge** (reuse the sticker recipe, item 5 —
  high-contrast cream-on-bark). Fix the ring so every gate maps into `bramble_1..3` (e.g.
  `clampi(lvl/4 + 1, 1, 3)`). Cut text load: show the Lv badge only on the **next-openable frontier** (or
  on tap), a small lock glyph elsewhere. *Refs:* `engine/scripts/ui/piece_view.gd:233` `make_bramble`
  (ring + the `Lv%d` badge at :267–293); assets `games/grove/assets/ui/bramble_{1,2,3}.png` (no `bramble_0`).

- **2 · Quest row — givers sit into the fence (board-polish IN FLIGHT — extend, don't duplicate).**
  *Problem:* the frameless chest-up giver cutouts blend into the painted fence; the row doesn't read as
  distinct quest cards. *Direction:* a **bordered / high-contrast plaque or sign-board behind each giver**
  so it pops off the rail and "falls right on the background." **board-polish already adds a parchment
  wooden sign-board** (`giver_stand.gd`, the `plaque` Panel) — review and tune its contrast/border/shadow
  so the bust + ask read clearly on the fence; add more only if needed. *Refs:*
  `engine/scripts/ui/giver_stand.gd:30` `make()` (board-polish plaque); `engine/scripts/scenes/board.gd:761`
  the fence wall.

- **3 · Fence↔board joint / transition (board-polish IN FLIGHT — extend).** *Problem:* the seam between
  the quest row/fence and the board reads as a flat "glass bar"; no nice transition. *Direction:* a
  deliberate transition — a painted **joint strip** (a ledge / hedgerow) and/or **FX** (soft shadow
  gradient, sky-band clouds). **board-polish already replaces the glass-bar margin with the raised-planter
  rim and adds drifting clouds** — review whether the seam now reads well; add an explicit painted joint
  only if the rim alone is thin. *Refs:* `piece_view.gd:166` `make_board_mat` (board-polish planter);
  `board.gd:146` clouds (board-polish); `board.gd:761` fence.

- **4 · Quest ask internals — star/item/progress layout + a "satisfied" state (NOT in board-polish).**
  *Problem:* within a giver the **star reward, asked-item icon(s), and the `n/m` progress aren't
  well-placed/sized** relative to the bust, and there's **no clear visual for an ask already satisfied**
  (enough of it is on the board). *Direction:* define the ask layout — star reward position/size, item-icon
  size, and the progress as a **count badge ON the item** (the sticker badge, item 5 — not a detached
  `%d/%d`) relative to the bust/plaque; add a per-ask **satisfied state** (a green check on the item /
  desaturate the met ask) so a glance reads "this one's ready." Drive it from the deliverable test that
  already computes `have >= need`. *Refs:* `giver_stand.gd:79–119` (ask icon + prog + `+N★` + featured
  ribbon); `board.gd:959` `_refresh_giver_lights` (per-ask `have>=need` → the ✓ source).

- **5 · One consistent badge — reuse the shared sticker recipe on board+quest (DEPENDS on the HUD lane).**
  *Problem:* badges/counts across board+quest (Lv gate, ask `n/m`, star reward, featured) are styled
  ad-hoc. *Direction:* the board/quest badges should reuse the **same** badge component the sibling HUD lane
  is building — the two-tone die-cut "sticker" (`skin.gd` `_RimOverlay`) and the shared count/red-dot badge
  — for the Lv gate badge (item 1), the ask count (item 4), the star reward, etc. **This item is the
  board+quest *consumer* of that primitive; coordinate with the HUD "Button & panel POLISH" + "Badge
  system" items, don't re-implement.** *Refs:* `engine/scripts/ui/skin.gd` `_RimOverlay` (agent worktree);
  `Tune.UiSkin.RIM_LIGHT`/`RADIUS_CARD` in `engine/scripts/core/tuning.gd`.

- **6 · Board background colour — comfortable + calm (board-polish IN FLIGHT — colour sign-off).**
  *Problem:* the board has no real background; it's simpler and looks good, but wants a nice, comfortable
  colour. *Direction:* pick a **calm, comfortable** board surface. **board-polish replaces the see-through
  mat with a warm wooden planter + tilled-soil bed** (`#86603A` wood / `#5E4828` soil) — this item is
  largely a **colour/feel sign-off** on that; soften if it reads too dark/heavy. *Refs:* `piece_view.gd:166`
  `make_board_mat` (board-polish planter colours).

- **7 · Cell border — soft + tight (cells already bordered — a tune).** *Problem:* each cell should have a
  **nice soft border, little margin/padding**; spacing tight and consistent. *Direction:* keep but soften
  the per-cell border (today radius 16, 2 px, `GROUND_EDGE@50%`), make **both slot-creation paths match**,
  and **reduce `GAP`/`BOARD_MARGIN`** so cells sit tight. *Refs:* `board.gd:1029` and `board.gd:1460` slot
  `StyleBoxFlat` (bg `GROUND@0.38`, radius 16, 2 px `GROUND_EDGE@0.5`); `board.gd:41` `GAP := 10.0`, `:42`
  `BOARD_MARGIN := 12.0`.

- **8 · Shading as an affordance — show what's clickable/important.** *Problem:* nothing uses shading to
  signal interactivity/importance; everything reads at one level. *Direction:* use **shading/dimming** as
  the affordance — shade the inert/locked/satisfied, leave the **clickable/important UN-shaded (or
  brighter)**: dim a satisfied or locked element, keep the generator / deliverable bright. Extend the
  existing modulate-based dim systems. *Refs:* `board.gd:993` `_refresh_giver_lights`,
  `_refresh_generator_dim` (existing modulate dimming to build on).

- **9 · Board bottom bar — use the empty space (CONFIRM-FIRST; the BOARD scene, not the map chrome).**
  *Problem:* the bottom is under-used; the owner asked to confirm before designing. *Confirmed:* on the
  **board scene** the bottom holds only a **bottom-LEFT `[◀ Home][🛒]`** cluster; **bottom-center and
  bottom-right are empty**, and **no in-flight change moves a primary button there** (the sibling HUD lane
  reworks the **map scene** `_build_chrome`, a different scene). *Direction:* decide what useful element
  fills the board's empty bottom — per §13 HUD law the **primary CTA belongs bottom-center** (e.g. a
  contextual "tap to grow / deliver / restore-ready" prompt). *Refs:* `board.gd:249–300` `bottom_bar`
  (Home+Shop, bottom-left); `docs/design/merge_spec.md` §13 ("primary CTA stays bottom-center").

*(Surfaced 2026-06-16 — owner board+quest review vs two reference merge games.)*

## Open — Shop screen (storefront UX + buy funnel)

*Surfaced 2026-06-16 — Shop-screen design review against two reference cozy/merge shops. ✅ **Storefront UX pass SHIPPED as T46** (green BUY pills, de-grey, hero art, banners, scarcity, IAP scaling, red close). ✅ **T47 (2026-06-17) shipped the info-popup + badge-consolidation tails** (`tasks/ux-feel.md`): the "i" now opens a real detail sheet without buying; the claimable red dots use the shared `Look.badge`, the "i" the shared `rim_overlay`. Only the icon-art tail remains — and it's Dev-channel (prompts authored, awaiting generation).*

- **Shop / currency icons — generate from the authored prompts (Dev-channel · art lane).** ✅ Ready-to-paste prompts authored in [`docs/design/shop_icon_prompts.md`](design/shop_icon_prompts.md); the Engineer hooks them up + verifies once images return (`grove_art_pipeline §2`). ⚠️ **Finding:** the shop's icons are the **shared currency/utility canon** (acorn `icon_coin` · dewdrop `icon_gem` · `icon_water` · the watering-can `icon_rain`) — they render in the HUD wallet + every price pill, not just the shop, so this **is** the **§8 icon-canon / emoji-purge** work; do the set as one batch and coordinate so it isn't redone twice. The shop's **featured** cards use `PieceView` previews (already on-style — no icon art needed). *(T46 tail → T47: prompts done, generation pending.)*

## Parked — per-map generators: art + tuning (the remaining tail of T17–T20)

- **Economy balance pass — level-based reward curve + pacing sign-off (§3 · §7 · sim) — owner feel call.**
  The quest/generator simplification (2026-06-18) replaced the expected-clicks reward with a **level-based**
  one: `quest_reward(level) = {stars: min(level, STAR_CAP=3), coins: max(0, level-STAR_CAP), gems: QUEST_PREMIUM_GEMS when level >= QUEST_PREMIUM_MIN_LEVEL (10)}`.
  All these numbers are **provisional**. What's left is the owner feel/pacing call plus a real sweep:
  - **Reward curve.** Linear coins likely **under-price deep asks** (a t12 take is far more merges than a t4 but
    pays only `12-3=9` coins). Decide the real coin curve (and whether the premium-gem level/amount is right),
    and re-tune `STAR_CAP` / `QUEST_TIER_BASE` / `QUEST_LEVELS_PER_TIER` / featured rate.
  - **grove_sim tripwires are RED and clearing them is the sign-off gate.** `grove_sim.gd` runs the new model
    end-to-end but FAILs **I2** (per-map water-gift ratio, maps 3–4) and **Y** (sell-coins income pump, 52.7 ≥ 25).
    Both are the expected un-tuned signals (I1 no-jam · no-strand · P1 · P2 pass).
  - **New gen-grant dial:** `GEN_GRANT_REMAINING_STARS` (when the next-generator quest surfaces near map end) —
    invariant: keep it below each non-final map's cheapest final-spot cost (today 4 < 5; preserve on roster changes).
  - **Faucet changes ride with this rebalance, not before:** level water gift **+20 → +50** (`LEVEL_WATER_GIFT`),
    free refills **3-lifetime → 1/day** (needs a per-day date, not lifetime `refills_used`), and the joint
    **`LEVEL_STARS` + `LEVEL_WATER_GIFT`** curve.
  - **`ASK_TIER_WEIGHT`** (§6 spawn tier-bias, `grove_data.gd`) ships at **0 = OFF** — live + tested
    (`board_logic.roll_spawn`, mirrored in `grove_sim`); full strength (0.6) front-loads spend ~3×, so ramping it
    belongs to THIS pass (re-tune the level curve alongside).
  Best judged once the art makes it playable; re-validate every change on the Monte-Carlo sim (`grove_sim.gd`).
  *(T17 sim → T19 cutover → T23 burst → T24 gradient → T37 strand fix → 2026-06-16 tier-bias dial →
  2026-06-18 level-based reward + one-generator-per-map.)*

- **Grove v1 art — ~192 item sprites + 12 generators (§16 LLM pipeline) — ⚠️ large.** The v1 home-grove
  content roster (T20) is authored as DATA; its lines render **code-drawn** until the sprites land.
  **Build (art):** the **24 lines × 8 tiers (~192) item sprites + 12 generator sprites** (maps 1–5,
  Farmhouse · Barn · Pond · Orchard · Meadow) via the §16 pipeline — tier-readability law (steps in
  size + silhouette, ~100 px), a shared per-line motif. (The full 15-map arc ≈ 832 sprites is
  post-launch.) **+ a small engine follow-up:** keep the `seed_satchel` anchor live +
  askable past map 1 on a **cold load** (`seed_gens` / `lines_for_map`) — it already persists in live
  play via the hand-in flow. *(Surfaced 2026-06-14; data built T20 2026-06-15.)*

<!-- ============================================================================ -->
<!-- EVERYTHING ABOVE THIS LINE IS THE OLD BACKLOG — to be DELETED once the review -->
<!-- below is complete. The reviewed/revised backlog is the single section below.  -->
<!-- ============================================================================ -->

# Reviewed backlog (revision in progress — 2026-06-23)

Built up section-by-section as we review the old backlog above with owner input. When the review
is complete, everything above the divider is deleted and only this section remains. New owner-driven
buckets cut across the old per-surface sections: **Active** (build now), **Tuning** (owner feel/pacing
calls), **Testing** (re-enable / add coverage), and others as they emerge.

## High priority — build now

_(The mystery-reward dialog shipped as **T53**, 2026-06-23 — see `tasks/ux-feel.md`.)_

- **FTUE system — redesign as ONE reusable hand-gesture spotlight (replaces the 3 removed §14
  spotlights).** Build a single reusable FTUE overlay used at every tutorial site, then wire each site
  with an explicit trigger. Replaces the old "restore the removed merchant/bag/shop spotlights" framing
  — instead of restoring the bespoke presentation, redesign it around a hand icon that mimes the gesture
  over a dimmed page. Pieces:
  - **Hand icon + gesture animation.** Create a hand-cursor icon asset; animate it for two gesture types —
    *drag* (hand travels from the source location to the target, loops) and *tap* (hand taps the target,
    loops).
  - **Dim-except-two-locations overlay.** Dim the whole page except the hand and the highlighted
    location(s): two cutouts for a drag (source + target), one for a tap (target). Build on / replace the
    existing `engine/scripts/ui/spotlight_overlay.gd`. Keep the seen-once gate + registry as the data
    source — `core/spotlight.gd` (`should_spotlight` / `mark_spotlit`) and `grove_data.gd:SPOTLIGHTS`
    (the per-feature gesture + label rows).
  - **Reuse across all sites.** The three registered sites today are **merchant** (drag a top-tier spare →
    sell), **bag** (drag a board piece → stash), **shop** (tap → open the store). All three drive the same
    component; a future site = one registry row + one call.
  - **Clear trigger rules — define + enforce per site:**
    - *merchant:* show only when a **top-tier spare exists to sell** — gate on the has-spares state that
      brightens the sell well (`board.gd` `_show_sell_affordance` / the merchant `SHADE_LIT` rule).
    - *bag:* show only when the player has a **piece worth stowing AND free bag space**.
    - *shop:* show on first home-screen open, **coordinated with the daily-login popup** so the two never
      stack on the same frame — restore the don't-collide guard that was removed with the old shop
      spotlight (without it the login popup would be permanently suppressed). Spec: `merge_spec §14` + §18.
  - *Note:* the gesture targets are the **current** bag / merchant / shop surfaces — the Section-2 bag &
    merchant "circle" redesign was cut. *(merges old core-loop items 3.1 + 3.2.)*

- **Merge the T45 entry-point wiring.** The 2×-collect ad hook, the piggy-vault button, and the
  daily-login auto-popup are committed + verified on branch `t45-integration` (`90a8ff0`) but NOT
  merged — they edit `map.gd`, which had active §16 map-art/placement work. Merge once that lands,
  reconciling the `map.gd` overlap. Until then the vault / login surfaces + the 2× ad are
  built-but-unreachable in play. *(from old economy 4.2 — kept here for routing; cut if not wanted.)*

- **Rip out the superseded hub-yield loop (T42).** The §8 keystone changed from hub-yield to the
  population/residents loop, so remove the T42 hub-yield + upgrade-levels code / tests + `HUB_*` dials
  (restoration spots become unlock-once; the resident roster replaces yield state). Pairs with the
  population/residents loop — the new §8 keystone (`grove_spec §3`). *(from old economy 4.2 — kept here
  for routing; cut if not wanted.)*

- **Server-driven mail + Apple identity/IAP (Game Center · StoreKit) — backend + Apple hookup.** The
  client side is built, guarded, and inert (flags off); what's left is backend + Apple work. This is the
  **consolidation point for the IAP/StoreKit external remainder** referenced across the economy items
  (old 4.1c / 4.2 / 4.3). Pieces:
  - **Mail-feed server.** Implement `GET <url>?since=<cursor>&limit=<n>` → `{messages:[{seq,id,title,
    body,icon,reward}]}` (live-only, ascending, ≤ limit; contract in `core/inbox_sync.gd`). A Cloudflare
    Worker + KV fits. Then set `FEED_URL` (`inbox_sync.gd:29`) + flip `mail_sync` on.
  - **Game Center identity verification.** Server verifies `Identity.verification()` (Apple GKLocalPlayer
    signature) before trusting `X-Player-Id`, then issues a short-lived session token. Until then ship
    broadcast (no id).
  - **StoreKit 2 receipt/transaction verification — for ALL SKUs** (the vault crack
    `com.tidyup.piggybank` + the shop gem packs / starter pack). Grant ONLY on a confirmed purchase.
  - **Apple / native (needs Xcode + Apple account).** Install GodotApplePlugins into the iOS export;
    App Store Connect: enable Game Center, register the IAP products, add entitlements; confirm the two
    undocumented StoreKit specifics with a sandbox buy. ⚠️ shipping the plugin makes purchases real-charge.
  - **Wire the shop's real-money SKUs through StoreKit (doable in-repo now).** The vault crack is wired;
    the shop gem packs / starter still grant directly — apply the same `store.purchase(id, func(okay):
    if okay: <grant>)` pattern.
  - **On-device verification.** Sign-in / purchase / restore must be tested on a real device.
  *(from old meta 5.1 + the IAP remainder consolidated from economy 4.1/4.2/4.3.)*

- **Analytics — at launch, not deferred (§15).** From day 1 log the FTUE funnel, retention (D1/D7/D30,
  session length/count), economy flow (per-currency faucet/sink totals, energy-wall hit-rate, refill
  usage), progression, monetization (even while dark: which IAP popups shown/tapped), and virality —
  event-batched, offline-queued, privacy-light. Nothing exists today. Build the engine analytics bus +
  the grove sink wiring. *(from old meta 5.9.)*

## Low priority — parking lot

- **Push notifications + re-engagement (§18).** Local + remote pushes (energy-full, yield-ready, event
  beat, win-back) — opt-in, calm, capped, prompted after a rewarding moment (never cold launch), per-type
  Settings toggle. No code today. Build engine scheduling + a remote hook + opt-in/quiet-hours/caps;
  grove copy/cadence/reward sizes. *(from old meta 5.3 — was "un-deferred to launch"; owner re-parked to
  low priority 2026-06-23.)*

- **Gentle-urgency + recurring-scarcity events & opt-in social/competitive (§17).** Time-boxed exclusives
  on a seasonal calendar (cozy FOMO) + an opt-in async positive-sum social layer (bracketed leaderboards,
  gifting, light co-op / community goals — no-lose, solo-playable). No code. **Extends the live-ops
  framework below.** *(from old meta 5.4.)*

- **Featured quests — give featured-ness a real choice (§7/§17/§18).** The featured flag pays out
  silently; the board badge was removed because quests aren't skippable (flagging is noise). Build a "do a
  featured quest" daily/event objective so the highlight has a target, then a fence highlight wired to it.
  **Depends on the live-ops framework.** *(from old meta 5.5.)*

- **The Collection — retired-line almanac (§6).** A line that retires (map advance / event end) archives
  into a completionist almanac keeping its tiers; a favorite can be set as décor (never re-summoned). No
  code. **Depends on line-retirement (generator work).** *(from old meta 5.6.)*

- **Live-ops / events framework (§17).** A data-driven event framework — a time-boxed overlay with a mini
  reward track, usually a limited-time generator + line (retires to the Collection), plus bonus weekends,
  limited cosmetics, catch-up bundles, and free + premium event lanes — **no code per event.** No code
  today. **Underpins the events / featured / Collection / sharing items above.** *(from old meta 5.7.)*

- **Sharing / virality (§17).** A share button captures a screenshot of the player's world and grants
  premium + energy on a daily cooldown (generous but not farmable). Only dev screenshot tools exist. Build
  engine capture + share + reward + cooldown; grove reward sizes. *(from old meta 5.8.)*

- **Premium diamond surprise-capsule — "gachapon" (post-v1, gated).** A diamond capsule yielding special
  resident characters; ships **post-v1**, gated on (a) the resident loop proven healthy + (b) a
  special-character art library, and must carry all seven cozy guardrails — cosmetic-only, no-loss
  (dupes auto-convert), no rarity tiers, no pity timer, evergreen, transparent pricing with a free/earned
  path, diegetic framing (never the word "gacha"). Build the engine capsule mechanism behind a flag +
  the grove library/pricing. *(from old meta 5.13.)*

## Features

- **Ad-reward (2× doubler) — real implementation.** Mature the rewarded-ad doubler from a stub into a
  finished, compelling offer:
  - **Real ad SDK.** `core/ads.gd` `can_show` / `claim` / `consume_2x` are stubs (instant "watch");
    implement the load→show→reward callback behind the geo build-flag. *(Shared external remainder with
    the IAP SDK — to be consolidated at the meta Apple/StoreKit item.)*
  - **Make the bonus worth more (owner directive 2026-06-20).** Replace the flat coin-for-coin ×2 with a
    bigger payout — a larger coin multiplier and/or a 💎 (or vault-skim) bonus on accept; update the card
    copy + reward icon. *(Dial values → Tuning.)*
  - **Offer frequency + trigger coverage.** It already fires on every regular quest delivery (drop any
    implicit top-tier gating). Decide whether to also offer it on the **gate-quest's big coin lump** (the
    strongest 2× moment) and on generator-grant deliveries. *(Cap/frequency dials → Tuning.)*
  - **Rename the ad id.** `collect_2x` is a misnomer (it doubles a quest reward, not a hub collect) —
    rename in `ads.gd` + its cap/cooldown config + the call sites. Spec: `merge_spec §10/§18`.
    *(from old economy 4.3.)*

## Tuning (owner feel / pacing calls)

- **Mystery reward pools.** Re-tune the pools in **`games/grove/login_rewards.json`** (the reward config is
  now data — `LOGIN_*` consts removed from `grove_data.gd` in T53) — day-4 to a mid-week reward tier, day-7
  to a milestone tier, against the wider coin/gem economy; keep every `water` entry ≤ `water_safe_max`
  (= 15, the §4/§10 faucet guard, asserted by tests). *(was follow-up 1.1.)*
- **Mystery spin pacing (day-7 length).** The deceleration *curve* reads right (measured 0.035s→0.17s ramp,
  visible card-to-card slowdown) so T53 left `_spin` untouched. The one open feel call: a 2-winner day (slot 7)
  runs ~3.6s of spin (vs ~1.6s for the 1-winner slot 4) because each extra winner appends a full ~2s segment,
  then a 1.5s "You won!" hold → ~5s total before auto-dismiss. If that reads long for a weekly-repeating reward,
  shorten the per-winner step counts in `login_mystery.gd:_spin` (`steps = 14 + wi*5` → e.g. `10 + wi*4`) and/or
  the 1.5s finish hold. Owner eyeball — captures shared with the T53 handoff.

- **Economy feel sign-offs (T43/T44).** Owner pacing pass on the cash → 💎 price ladder, rewarded-ad
  caps, the out-of-water discount (T43), and the vault skim rate / pig price / login ladder + milestones
  (T44). All owner-tunable one-liners in `grove_data.gd`; re-validate on `grove_sim`. *(from old economy 4.2.)*

- **2× ad-reward frequency + payout.** The `collect_2x` (rename pending) daily cap + cooldown, the offer
  frequency, and the new payout size (bigger coin multiplier and/or 💎 bonus) — keep it a treat, not a
  nag; it's a faucet, so sim the rate + payout on `grove_sim`. *(from old economy 4.3.)*

- **Board occupancy / congestion ceilings (§15).** Extend `games/grove/tools/grove_sim.gd` to aggregate
  **peak + mean board occupancy** and a **drain-net full-board stall rate** (today it tracks only a binary
  jam count + a free-cell low-water mark), then set the peak-occupancy + stall-rate **ceilings** (grove
  numbers) so the late-game "juggle every line on one board" is proven drainable. Engine primitive exists
  (`board_model.empty_ground_cells()`). Minor — tooling/validation. *(from old meta 5.15.)*

## Testing (re-enable / add coverage)

- **Re-enable the login UI test suite.** `engine/tests/login_tests.gd` (15 assertions, passes today)
  sits in the Makefile's `ENGINE_TESTS_DISABLED`; fold it back into `ENGINE_TESTS`. It covers: (1)
  claim-feedback z-order — the daily-reward celebration renders ABOVE the z=100 calendar modal, not
  behind the veil; (2) mystery-chest wiring — a mystery slot is the claimable "today" rung, wears the
  "?" chest, and opens the spin (not an instant grant); (3) mystery reveal grant — opening a day-7
  reveal claims the day, bumps the streak by 1, fires `on_done`; (4) reveal cards show concrete reward
  amounts, not icon-only. *(was follow-up 1.2.)*

- **IAP / StoreKit purchase flow (generic).** Coverage for the IAP purchase → grant → (receipt-validate)
  path across every SKU — the vault crack (`com.tidyup.piggybank`) and the shop gem packs / starter pack.
  Assert the grant happens ONLY on a confirmed purchase (`okay == true`); extend as the real StoreKit SDK
  + receipt validation land. Seed: `engine/tests/store_tests.gd`. *(from old economy 4.1c.)*

- **Ad-reward (2× doubler) flow.** Cover offer → accept → grant: the offer fires on the right trigger(s),
  respects the cap / cooldown, and the accept credits the new (>1×) payout. Seed: `grove_tests`
  `_test_2x_doubler_rehome`. *(from old economy 4.3.)*

- **Re-enable the parked UI + economy/liveops suites (pre-launch hardening).** The Makefile keeps only the
  core-logic suites active (`save`, `mechanics`, `quest`, `quest_fence`, `anchor`, `layering`); the rest
  sit in `*_DISABLED`. Parked — UI: `mapfx`, `palette`, `level_badge`, `bag_overlay`, `switch`, `calm`,
  `floater`, `hint`, `gendim`, `spotlight`, `grove_ui`, `grove_placement`. Economy/liveops: `inbox`,
  `featured`, `grove_economy`, `grove_shop_ads`. Grove model: `grove_model`. Re-enabling = moving names
  from `*_DISABLED` back into `ENGINE_TESTS` / `GROVE_TESTS`; do it once board/UI + economy stabilise,
  and expect some to need updating to match by-then-current behavior. *(from old meta 5.2.)*
