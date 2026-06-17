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

## Open — core loop

- **Shop backdrop — a dedicated stall-interior scene (art lane · owner).** The Shop currently renders over an **interim engine backdrop** (a blurred + warm-tinted + vignetted copy of the live scene — `engine/scripts/ui/shop.gd` `_backdrop_material`, dials in `tuning.gd` `Shop.BACKDROP_*`) because the flat dim read as dead space. Replace with **generated art**: the squirrel merchant's **market-stall interior** (warm wood, shelves, hanging goods, soft light), `ui/kit/bg_shop.png`, same §16 pipeline as the board backdrop. On arrival the shop should draw it behind the parchment (a small engine hookup in `Shop.open` — load `bg_shop.png` when present, else keep the blur). Spec: `merge_spec §10` (presentation) + `grove_art_pipeline §1` table row. *(Surfaced 2026-06-16 — shop polish pass.)*

- **Map model — real §16 map images + on-image spot placement (art lane · owner).** The tail of the single-image-map rework (model T21; the `zone`→`map` rename + orphan-sprite cleanup shipped T38). **No engine gap** — the map view auto-wires `assets/map/map_<id>.png` (`map.gd` `_open_map`) and the Layout editor places spots on the image; this is **art + owner action**: generate the §16 per-map backgrounds (same pipeline as *Grove v1 art*, below), then re-place each map's spots via the Layout editor. `data/placements.json` was wiped to a clean slate (T38, owner call — `layout.gd` falls back to `grove_data` defaults), so re-placement starts fresh for **every** map. *(Pairs with the KEYSTONE hub loop below.)* *(T21 parked tail; (a)+(c) shipped T38.)*

## Open — economy

- **Economy 2nd-batch follow-ups — entry-point merge · feel sign-offs · the IAP/ads SDK (T42–T45).** The
  §8 keystone **hub-yield + upgrade-levels loop** (T42 — restore→L1, upgrade L1→L5 = richer look + higher
  yield, per-building daily-cap yield swept on return), the §4/§10 **live-IAP ladder + rewarded ads +
  out-of-water offer** (T43), and the §10/§18 **piggy vault + forgiving login calendar** (T44) all **shipped
  to `main`** (engines + tests + sim; the §6 burst-upgrade Part B was already T23/T25). What remains:
  • **Merge the entry-point wiring (T45).** The 2×-collect ad hook, the piggy-vault button, and the
  daily-login auto-popup are **committed + verified on branch `t45-integration` (`90a8ff0`) but NOT merged** —
  they edit `map.gd`, which currently has **active uncommitted §16 map-art/placement work** in the primary
  tree; merge once that lands, reconciling the `map.gd` overlap. *(Until then the vault/login surfaces + the
  2× ad are built-but-unreachable in play.)*
  • **Feel sign-offs (owner pacing).** Provisional grove dials want a pass: `HUB_YIELD_RATE/CAP/UPGRADE_COST`
  (T42 — sim-bounded at 96🪙/day, "extend, never self-sustain"), the cash ladder + ad caps + out-of-water
  discount (T43), the vault skim / pig price / login ladder + milestones (T44). All owner-tunable one-liners in
  `grove_data.gd`; re-validate economy changes on `grove_sim`.
  • **Perceptual placement (owner eye).** T45's piggy-button position, the 2×-offer card look/copy, and the
  login-popup timing — flagged in the T45 ledger entry.
  • **External remainder.** The real ad-SDK (load→show→reward) + IAP **receipt validation** behind the geo
  build-flag — the one piece that can't ship in-engine; everything game-side sits behind the honest
  confirm-stub. *(Surfaced 2026-06-15 — 2nd economy batch, T42–T45; engines merged, the above is the tail.)*

- **Shop cosmetic LOOKS — apply the owned look to the board/map render (small follow-up · T40).** The
  Shop now sells cosmetic looks (T40 — `SHOP_COSMETICS` in `grove_data.gd`, unlock stored in
  `grove()["cosmetics"]`), but the chosen theme is **granted-and-owned only — not yet applied** to the
  board background / map render. **Build:** read the owned cosmetic in the board/map view and swap the
  look. *(Surfaced 2026-06-15 — T40 parked tail.)*

## Open — meta, content-cadence & infra

- **Push notifications + re-engagement (spec done · engine code · grove — UN-DEFERRED to launch).** §18: local + remote pushes (energy-full · yield-ready · event beat · win-back), opt-in, calm-toned, capped, prompted **after a rewarding moment** (never cold launch), per-type Settings toggle. The grove skeleton **deferred** notifications (`grove_spec §1`) — now **launch scope** (a silent energy return-hook with no prompt is the costliest omission, per the director review). **Absent** (no notification code). **Build (engine):** local-notification scheduling + a remote-push hook + opt-in / quiet-hours / caps. **Build (grove):** copy, cadence, reward sizes. *(Surfaced 2026-06-14 — director review.)*

- **Gentle-urgency + recurring-scarcity events & opt-in social/competitive (spec done · engine · grove).** §17 adds **gentle urgency softened by recurrence** (time-boxed exclusives that return on a **seasonal calendar** — cozy-safe FOMO) and an **opt-in, async, positive-sum social layer** (bracketed "race a few others" leaderboard events, gifting, light co-op / community goals — no-lose, solo-playable). **Absent** (no recurrence, leaderboard, gifting, or community-goal code). **Build (engine):** event recurrence rules; the async-bracket leaderboard, gifting, and community-goal surfaces (flagged, §11). **Build (grove):** the seasonal calendar, which social surfaces ship, bracket/gift caps. *Extends the live-ops/events framework item below.* *(Surfaced 2026-06-14 — director review.)*

- **The Collection — retired-line almanac (spec done · engine code · grove).** §6: a line that retires
  (map advance, or an event ending) **archives to the Collection** — a completionist almanac keeping
  its tiers; a favorite can be set as **décor**, never re-summoned to the board. **Entirely absent**
  (no archive/almanac/codex code). **Build (engine):** the archive + décor-display path. **Build
  (grove):** re-summon/décor prices. Depends on line-retirement (generator item). *(Surfaced
  2026-06-14 — code audit vs `merge_spec`.)*

- **Live-ops / events framework (spec done · engine code · grove calendar).** §17: a **data-driven**
  event framework — a time-boxed overlay with a **mini reward-track**, usually a **limited-time
  generator + line** (pops on the same board, retires to the Collection when the event ends), plus
  bonus weekends (×2 drops / cheaper energy), limited cosmetics, and catch-up bundles — **no code per
  event**. **Entirely absent** (every `event` hit is Godot's `InputEvent`). **Build (engine):** the
  config-driven framework. **Build (grove):** the event calendar + limited-line themes + reward sizes. **§17 also adds free + premium event lanes** (an optional paid lane per event — additive, never gating; a standalone seasonal Battle Pass is parked future/not-v1, below).
  *(Surfaced 2026-06-14 — director review + code audit.)*

- **Sharing / virality (spec done · engine code · grove).** §17: a **share** button captures a
  **screenshot of the player's world** and grants premium+energy on a **daily cooldown** (generous
  enough to feel worth it, gated enough not to be farmable). **Absent** — only dev screenshot tools
  exist (`games/grove/tools/grove_shot.gd`, `games/grove/tools/map_shot.gd`), no in-game share. **Build (engine):** in-game
  capture + share + reward + cooldown. **Build (grove):** reward sizes. *(Surfaced 2026-06-14 —
  director review + code audit.)*

- **Analytics — at launch, not deferred (spec done · engine code · grove sink).** §15: from day 1 log
  the **FTUE funnel**, **retention** (D1/D7/D30, session length/count), **economy flow** (per-currency
  faucet/sink totals, energy-wall hit-rate, refill usage), **progression**, **monetization** (even
  while dark: which IAP popups shown/tapped), and **virality** — event-batched, offline-queued,
  privacy-light. **Entirely absent** (`grep -ri analytics engine games` → nothing). **Build
  (engine):** the analytics bus. **Build (grove):** the sink wiring. *(Surfaced 2026-06-14 — code
  audit vs `merge_spec`.)*

- **Save-schema extension + migration (cross-cutting · code).** As the items above land, the `grove`
  save blob needs new fields — **all absent today** (`engine/scripts/save.gd`): cumulative
  `stars_earned`, a per-day refill date, the live generator set + retired-line state (generator-grant model), buildable upgrade-levels, yield
  collection timestamps, the Collection (retired lines), generator burst-upgrade levels, and event
  state. Retire `exp`/`qdone_chapter`; bump `SCHEMA_VERSION` (currently 2) with a deep-merge
  migration. The atomic-write + `.bak` + deep-merge plumbing is sound — only the schema grows. Park
  the matching field alongside whichever item introduces it. *(Surfaced 2026-06-14 — code audit vs
  `merge_spec`.)*

- **Grove: story implementation — the trapped-family spirit-grove arc (story specced · content · art · code).**
  The narrative is now **designed in `grove_spec §1`** — a wordless spirit-world spine: a
  child crosses into a fading spirit-grove, her parents become **silent nature-spirits** (Acorn-dad +
  Flower-mom) and she restores the grove to **reunite the family** and wake the **forgotten great heart-tree
  spirit** — v1 ends on a **cliffhanger** (the parents' *full freeing* defers to the first post-launch place, `grove_spec §1`); reunite-early-then-help-others, scaling **maps = beats** (the family become
  the grove's new Keepers — the endless-content justification). **Givers re-cast** as humanoid
  produce/critter spirits (Radish · Carrot · Frog · Bee · Morel + menagerie; fox/hedgehog/owl
  retired). **Build (grove content):** giver names/personalities/wishes + per-map beats + the Map-1
  episode (authored crossing/FTUE → restoration beats → heart-tree waking → reunion + onward hook);
  image-memory vignettes. **Build (art):** the cast, the parents + their **easing de-transformation**
  (composited per map, Core §16), the great-spirit's **bloom-awake** climax, candidate later maps.
  **Build (engine, maybe):** the per-map de-transform swap is plain compositing (Core §16) — likely no
  new engine system, but the FTUE crossing + the parents-as-guides surface may need wiring. Engine
  giver-arc layer is Core §7. *Fleshes out the old "character arcs for givers" item (now specced).* ✅ **`grove_spec` reconciled (2026-06-15):** map = a beat (one image) with **no episode/chapter tier** (a flat map sequence), the **Farmhouse is the home hub** (authored deeper + a HUD home-shortcut to return & keep upgrading), the legacy free-pan/`interior_view` model retired — the §1 story + §3 build sections now read on the single-image-map model. Only the content/art/code **build** below remains.
  *(Surfaced 2026-06-14 — director review; designed 2026-06-14.)*

- **Standalone seasonal Battle Pass (future — not v1, owner 2026-06-14).** A persistent, cross-event
  **season ladder** (free + premium tracks, leveled by all play over a ~30-day season) — distinct from
  the **per-event premium lane** that now ships in Core §17. Owner: **not interested for v1**; parked
  as a future LiveOps revenue line if the cozy positioning proves it can carry one. *(Surfaced
  2026-06-14 — director review.)*

- **Engine layering — Phase 4 (optional refactor).** The `core/ui/scenes` split (Phases 1–3) is
  **done + guard-enforced** — invariant now in `merge_spec §15`, guard `engine/tests/layering_tests.gd`.
  Phase 4 folds the last view-stranded logic into core: ambient **win-back** trigger → core
  (`save`/`content`); shop **purchase logic** → `core/economy.gd` (economy numbers → `Game.DATA`) —
  leaving `ambient.gd`/`shop.gd` pure view. LOW risk, behavior-identical. Out of scope (separate axis):
  relocating `board`/`map` from `engine/` to `games/`. *(Was `ui_backend_separation.md` §Phase 4; that
  plan doc is deleted now Phases 1–3 landed — invariant lifted to `merge_spec §15`. Surfaced 2026-06-15.)*
  ⚠️ **Separate, in-progress on another thread (unlogged — flag for backfill):** a **`board.gd` decomposition**
  refactor — **Wave 1** extracted quest-fence composition → `core/quests.gd` (`1edbdea`), **Wave 2** view
  builders → `ui/piece_view` + `ui/bust` (`a102b85`); both shipped to `main` with **no `T#` entry**, and "Wave N"
  implies more passes touching `board.gd`. Backfill the task entries + coordinate before other `board.gd` work.

- **Economy sim — track board occupancy/congestion (sim tooling · grove `grove_sim.gd`).** §15
  (`merge_spec.md:438`; echoed §7 `:257`) requires the sim to validate the board for **space**, not just
  affordability: **peak & mean cells filled** and the **full-board stall rate** (taps blocked for want of a
  free cell, net of the bag §5 and merchant §9 drains), so the late-game "juggle every line on one board"
  is proven drainable. Today `games/grove/tools/grove_sim.gd` tracks only a binary jam count (`:437`) and a
  free-cell low-water mark (`:310`, `open_low_mark`) — **no mean occupancy and no stall *rate***
  (`grep occupancy|congestion|stall_rate` → none). The engine primitives already exist
  (`engine/scripts/core/board_model.gd:172` `empty_ground_cells()`). **Build (sim):** aggregate peak/mean
  occupancy + a drain-net stall rate into the sim results. **Build (grove):** set the peak-occupancy +
  stall-rate ceilings (a grove number, §15). **Minor** — tooling/validation, not a runtime gap. *(Surfaced
  2026-06-16 — engine vs `merge_spec` gap audit.)*

## Open — HUD, currencies & button chrome (presentation + monetization funnel)

*Surfaced 2026-06-16 — UI design pass against two reference cozy/merge games. Our currency set is already **richer** than either reference (⭐ star = soft progression / restores places + drives Level · 🌰 acorn = soft coin from hub yield · 💎 gem = premium hard / IAP · 💧 water = board energy); the gaps are **affordances, hierarchy, and polish — not more systems**, and several backends already exist and just need surfacing. Anchors: HUD top bar `engine/scripts/ui/hud.gd` `build`; bottom chrome `engine/scripts/scenes/map.gd` `_build_chrome`; buttons/panels/icons `engine/scripts/ui/skin.gd` (`button` · `kit_panel` · `icon` · `stat_chip`). All dials in `engine/scripts/core/tuning.gd` — `Tune.Hud` (PILL_* · STAR_ICON/COIN_ICON/GEM_ICON · LV_* · XP_*) and `Tune.UiSkin` (BTN_* · KIT_* · CHIP_* · PARCH_* · TITLE_* · ICON_PX). Build the **polish item first** — it makes everything else look finished; then the funnel items. Verify every visual with a composite/zoom capture over BOTH a cream-parchment AND a busy grass/sky background (never eyeball).*

- **Button & panel POLISH — the "sticker" recipe (borders · shadows · corners · icon alignment · hierarchy).** The top-priority visual pass; today buttons read flat on busy backgrounds. **Build:** (a) **Two-tone rim** — add a thin LIGHT/cream inner highlight (~1.5px, ~0.7α) inside the existing darker outer edge, so every button/pill reads as a crisp sticker on any background. StyleBoxFlat has one border colour, so either (preferred, art lane) bake the rim into the kit nine-patches (`btn_round.png`, `panel_*.png`), or (code) nest an inner StyleBoxFlat / use `expand_margin` for the light ring. New dials `UiSkin.RIM_LIGHT`, `RIM_LIGHT_W`. (b) **Two shadow tiers** in `UiSkin` — `SHADOW_RESTING` (chips/pills: ~rgba .16, size 4, offset (0,2)) and `SHADOW_RAISED` (primary CTA + floating round buttons: ~rgba .28, size 10, offset (0,5)) — softer + larger than today's flat size-5 so primaries clearly float; pressed state drops to resting (already true for `button` via `BTN_PRESS_*`; extend to the round chrome buttons, which today don't animate their shadow). (c) **Corner-radius scale** — collapse the five current radii (`PILL=40` · `PARCH=26` · `BTN=28` · `CHIP=20` · `TITLE=20` · card=20) to: capsules (currency pills, Level chip) = fully rounded (radius = height/2, computed not fixed); round chrome = circle; all rectangular surfaces (cards/CTA/parchment/title) = ONE shared `UiSkin.RADIUS_CARD` (~24); small chips = `RADIUS_CHIP` (~14). (d) **Hierarchy + colour-by-function** — 4 tiers: primary CTA (saturated green, raised shadow, biggest) → Store (warm coral/amber fill, badged, 2nd) → round chrome map/vault/settings + LiveOps rail (cream, resting shadow, circle) → currency capsules (cream, resting). Money = warm, nav = cream, gem = teal. **Acceptance:** no two same-class surfaces use different radii; a button stays legible as a sticker over grass AND parchment (2-background composite); primaries cast a visibly larger shadow than chips. *(The user's explicit ask: borders, stand-out, shadow, curved corners, icon alignment.)*

- **Currency cluster — acquire affordances + identity (the #1 monetization gap).** Today the wallet is passive numbers with **no path to "get more"**, the Home button is mixed *inside* the currency pill, and the three icons are different sizes (`STAR_ICON=44`/`COIN_ICON=40`/`GEM_ICON=38`) so they don't share a centerline. **Build:** (a) a small **`+` button** on the buyable currencies (gem always → opens Store/IAP to that pack; acorn optional → Store) — `hud.gd` `build`, route through the existing `open_shop`. (b) **Normalize icons** — one fixed icon BOX per slot (e.g. 40px), every icon centered in it, per-icon *scale-within-box* tuned for optical parity, number baseline-aligned with a constant `CHIP_ROW_SEP` gap. (c) **Pull Home OUT of the wallet** — it's nav, give it its own chip (or fold into the bottom chrome). (d) **Identity** — lock a colour language (star = gold, acorn = warm brown, gem = teal) so the gem stops reading as a water drop; consider a small token/disc behind each. (e) Fresh-save **0 / 0 reads dead** — seed a small starting gem balance + a one-line "what's this?" on first tap. **Acceptance:** the three currencies share a common box + centerline; a `+` is reachable from the map in ≤1 tap. *(Water stays board-only unless it begins gating map actions.)*

- **Store — promote to a persistent, badged entry + buy funnel.** Both references put Store top-right, prominent; ours is a tiny equal-weight round button in the bottom cluster (`map.gd` `_build_chrome`, the `cart` button). **Build:** relocate/restyle Store to a prominent, always-visible button (warm fill per the hierarchy above), wire the currency `+` to open it to the right pack, and add a **"new offer" badge** (uses the badge component below). Surface the existing starter-pack / featured offers (`grove_data.gd` `STARTER_PACK`, `SHOP_*`) when available. **Acceptance:** Store is reachable in 1 tap from anywhere on the map and shows a badge when a new/featured offer is live.

- **Badge system — ONE consistent red-dot / count component.** The references run almost entirely on red "!" dots to pull players to claimable rewards / unread mail; we have exactly one bespoke pip (the piggy `_piggy_pip` in `map.gd`). **Build:** a single reusable badge in `skin.gd` (red dot with white rim for "something new"; red pill with a number for counts like inbox-unread; consistent top-right overhang, size, z-order). Drive it from claimable-state queries (vault ready, daily available, unread mail, new offer). Replace the ad-hoc piggy pip with it. **Acceptance:** every actionable surface (Store, Daily, Free, Inbox, Vault, Settings) can show the same badge; it appears only when truly actionable.

- **LiveOps buttons — surface Daily · Free(ad) · Inbox (backends mostly exist).** We **have** the login calendar (`core/login.gd` — auto-popup only, no button) and the rewarded-ad / 2× system (`core/ads.gd`, the post-collect doubler) but neither has a **persistent entry**, and there is **no inbox**. **Build:** a calm vertical rail (right edge) of round buttons — **Daily** (persistent entry to the existing login calendar, badged when claimable), **Free** (a persistent rewarded-video → gems faucet, reusing `ads.gd`), and **Inbox** (NEW — a small mailbox for LiveOps gifts / compensation / news, with an unread count badge). Keep the rail calm (cozy, not the references' clutter): buttons auto-hide or de-emphasize when nothing is actionable; the badge does the attention-pulling. **Acceptance:** Daily + Free reachable persistently (not just via auto-popup); Inbox stores and grants gifts; all three use the shared badge. *(Inbox is the one net-new system; Daily/Free are mostly wiring.)*

- **Task strip — a short-term goal + reward loop wired to the next spot.** A reference (Juice) shows "Task 1/4 → chest"; we have the place-restore goal ("31 left") but **no chrome task loop with a reward**. **Build:** a slim cozy strip above the "Tend the garden" CTA — "Today's task ✿ N/M → 🎁" — chained off the existing restore-the-next-spot goal so the cozy spine *is* the task loop (not a bolted-on quest). Reward = small acorn/water/gem grant. **Acceptance:** the strip reflects real spot/quest progress and pays out on completion; it never blocks play. *(Lower priority than the funnel + polish; pairs with the §17 live-ops/events framework above.)*

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

*Surfaced 2026-06-16 — Shop-screen design review against two reference cozy/merge shops (a cream "cat" shop with Backpack + Store tabs; a saturated blue match-3 Store). Verdict: our cottagecore identity (squirrel-merchant sign, parchment, vine dividers — keep all of it) is a real asset, but the screen **doesn't read as a shop**: nothing looks tappable and half the cards look disabled. Borrow the references' **button clarity, art scale, contrast, and scarcity cues — not their candy style.** All shop UI is `engine/scripts/ui/shop.gd`; look/feel dials in `engine/scripts/core/tuning.gd` → `class Shop`. Build the **card-affordance fix (greying + buy button) FIRST** — it's the difference between "broken" and "shop"; everything else is polish on top. Verify every visual with a composite/zoom capture on a fresh save (gem = 0) AND a flush save (so the dim/afford states are both seen) — never eyeball.*

- **Card affordances — de-grey the cards + give every card a real BUY button (THE fix).** *Problem:* (1) `_apply_afford` (`shop.gd:789`) desaturates the **whole card** to `Tune.DIM_MODULATE` (`tuning.gd:424`) when the player can't afford it — on a fresh save (dewdrop/gem = 0) that greys out Fill-water, Coin-pouch, Honey, and the watch-offers button at once, so the storefront reads **disabled / sold-out**. (2) The price is `_price_pill` (`shop.gd:699`) — a **brown pebble** (`GEM_PRICE_BG #5A3F28`, cream text) embedded mid-card with no button affordance; nothing signals "tap to buy." Both references make the price *itself* a bright CTA the eye lands on. *Solution:* (a) **Stop desaturating affordable-cards-only** — keep the card cream + bright always; show un-affordability only on the price chip (a softer "you need more" state) and route an un-affordable tap to the currency `+` / Store ("get more gems") instead of a dead wallet-wiggle. Acceptance: a fresh-save shop has **zero grey cards**. (b) **Turn `_price_pill` into a green BUY capsule** — saturated cozy green fill, **white text** (per the user ask "white text on green"), fully rounded (radius = height/2), a raised shadow + thin light inner rim so it floats as a sticker; currency glyph + amount inside. New dials `Shop.BUY_BG / BUY_EDGE / BUY_TEXT / BUY_SHADOW`. This is the single highest-leverage change. *(References: cat shop's green `🪙130` / `Free` pills; candy shop's green `💎10` buttons — the price is always the brightest thing on the card.)*

- **Item art is the hero — enlarge it + give it a plate, and commission cleaner icons.** *Problem:* help-card icons are `Look.icon(id, HELP_ICON=56)` (`shop.gd:463`) floating tiny + faint at the card top with two lines of text below; the water-can / acorn-pouch / honey / garden-tools glyphs are thin and low-contrast against cream. References fill ~50–60% of the card with large, appetizing product art. *Solution:* (a) blow the art up to dominate the card's top half; demote title/caption to a single tight line. (b) Drop a **soft tinted disc/plate** behind each icon (a pale honey or sage circle) so the glyph pops off the parchment — new dial `Shop.ICON_PLATE_*`. (c) Commission **cleaner kit icons** (water can, acorn pouch, honey jar, garden tools, mushroom) via the §16 pipeline — the user ask "better looking icons"; the featured cards already use real `PieceView.make_piece` previews (`shop.gd:498`) and look better, so match that fidelity. *(Reference: candy shop's chunky treasure-chest / scissors / compass icons read instantly at a glance.)*

- **Section structure — tabs OR bolder banners (the groups blur together).** *Problem:* `_divider` (`shop.gd:405`) renders a small tan tab + vine per group ("Quick help / Featured / Welcome gift / Dewdrop pouches"); the captions (`DIV_CAP_SIZE=23`) are too quiet to separate the groups, so the screen reads as one long scroll. *Solution:* the user ask "clear section between groups or use tabs" — two routes: **(A) Tabs** (preferred if the list keeps growing) — a top tab bar splitting **Items** (consumables + featured skips) from **Specials & Gems** (welcome gift + IAP pouches), like the cat shop's `Item / Special Offer`. **(B) Bolder banners** — keep the one-scroll but make each `_divider` a real header (bigger caption, a warm filled banner, the vine flowing off its right edge), like the candy shop's yellow `Nice Boost` / `Diamonds` bars. Keep the leafy vine either way — it's our signature. *(References: cat shop = tabs; candy shop = bold yellow section banners.)*

- **Scarcity & urgency — red dots + countdown timers on limited/claimable items.** *Problem:* every section sits at the same flat energy; nothing pulls the eye to what's claimable or expiring. *Solution:* the user asks "red dot where applicable for urgency" + "show time left on limited items." (a) **Red dot** — reuse the shared badge component (see the *Badge system* item in the HUD/chrome section, and the existing `_badge` `shop.gd:676`, today a yellow `STRAW` pill) for: the **free reroll** when a watch-offer is ready (`Ads`/reroll), an **unclaimed Welcome/starter** gift, and any **daily free** card. (b) **Countdown clock chip** — a small `🕐 19h13m` chip on rotating / limited offers, driven off the existing rotation (`rotation_seed` `shop.gd:175`, `rotation_offers` `:181`) so the chip shows real time-to-refresh; add a **stock badge** (`5 Left`) to limited offers for the same scarcity beat. *(References: cat shop's `⏱19h13m` / `1h13m` headers + `1 Left` / `5 Left` blue stock badges; candy shop's `Refreshes in: 4h 58m`.)*

- **IAP pouches — scale the art by tier + crown the best value + fix the copy.** *Problem:* `_gem_card` (`shop.gd:594`) renders the **same dewdrop cluster** on all six pouches with only the number changing, so "more value" isn't *visible*; the `2ⁿᵈ first buy` badge copy is contradictory (it's the `FIRST_BUY_MULT` 2× first-purchase bonus). *Solution:* (a) grow the dewdrop-cluster art per pack tier (tiny pair → big pile) so bigger packs *look* bigger; (b) a **"Popular" / "Best value" starburst** on the top pack (reuse `_badge` / the starburst look); (c) reword the bonus to **"2× on first purchase"**. (d) Make the **Welcome gift** (`_starter_card` `shop.gd:636`) a proper **hero card** — wider, a ribbon, the bundle contents shown as a little stack, a "Best Deal" flag — it's the best offer and currently looks like a plain row. *(Reference: candy shop's `Diamonds` grid grows the gem pile per tier + `Popular` starburst.)*

- **Close button — make it an unmistakable control.** *Problem:* the top-right close reads as a decorative compass/diamond corner ornament half-off the frame, not a button. *Solution:* a clear **red circular X**, fully on-panel, matching both references' close affordance and our round-chrome button language (see the button-polish item). Anchor: the close built in `Shop.open` (`shop.gd:210`).

- **Shop item info — the "i" badge popup (PARKED · visual-only now, hookup later).** *Problem:* both references put a small circular **"i" badge top-right of every card** that opens an item-detail sheet (what it is / does / where it's used); we have none. *Solution (this item, parked):* the popup itself — a detail sheet (item name, effect, tier preview, source) — is **its own task, not wired now**, per the owner ask. ⚠️ **Build note for whoever picks it up:** the whole card surface currently presses to **buy** (`_card_button` `shop.gd:766` → `_try_buy`), so the "i" must be a **separate hit target stacked above** the buy press (own `mouse_filter` + z-order) that opens the sheet **without** triggering a purchase. *(A separate, smaller item: dropping the static "i" glyph onto each card — purely visual, no popup — can ship with the card-art pass above; this parked item is the live detail sheet behind it.)* *(Surfaced 2026-06-16 — Shop review; owner parked the info hookup separately.)*

## Parked — per-map generators: art + tuning (the remaining tail of T17–T20)

- **Economy tuning + pacing sign-off (§3 · §7 · sim) — owner feel call.** The §7 economy is sim-green
  on the invariants (no-jam · no-strand · I2 steady-state <30% · selling-not-income); the seed-123
  level-gating × burst strand is **fixed** (T37). What's left is the **feel/pacing call the sim can't
  make** — owner sign-off on the provisional `grove_data.gd` quest tunables (`STAR_CAP`,
  `CLICK_TO_VALUE`, `QUEST_LEVELS_PER_TIER`, `GATE_TIER_BASE`/`GATE_ASK_COUNT`, featured rate) and the
  joint **`LEVEL_STARS` + `LEVEL_WATER_GIFT`** curve. **Two faucet changes ride with this rebalance,
  not before:** level water gift **+20 → +50** (`LEVEL_WATER_GIFT`), and free refills **3-lifetime →
  1/day** (needs a per-day date, not the current lifetime `refills_used`). **New dial to sweep:
  `ASK_TIER_WEIGHT`** (§6 spawn tier-bias, `grove_data.gd`) ships at **0 = OFF** — the mechanism is live
  + tested (`board_logic.roll_spawn`, mirrored in `grove_sim`), but the sim showed full strength (0.6)
  front-loads spend ~3× (1 map vs 4 over a 7-day run), so ramping it belongs to THIS pacing pass (re-tune
  the level curve alongside). Best judged once the art makes it playable; re-validate every change on the
  Monte-Carlo sim (`grove_sim.gd`). *(T17 sim → T19 cutover → T23 burst → T24 gradient → T37 strand fix →
  2026-06-16 tier-bias dial.)*

- **Grove v1 art — ~192 item sprites + 12 generators (§16 LLM pipeline) — ⚠️ large.** The v1 home-grove
  content roster (T20) is authored as DATA; its lines render **code-drawn** until the sprites land.
  **Build (art):** the **24 lines × 8 tiers (~192) item sprites + 12 generator sprites** (maps 1–5,
  Farmhouse · Barn · Pond · Orchard · Meadow) via the §16 pipeline — tier-readability law (steps in
  size + silhouette, ~100 px), a shared per-line motif. (The full 15-map arc ≈ 832 sprites is
  post-launch.) **+ a small engine follow-up:** keep the `seed_satchel` anchor live +
  askable past map 1 on a **cold load** (`seed_gens` / `lines_for_map`) — it already persists in live
  play via the hand-in flow. *(Surfaced 2026-06-14; data built T20 2026-06-15.)*
