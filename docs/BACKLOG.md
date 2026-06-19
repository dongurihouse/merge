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

## Open — board screen UI overhaul (owner pass · 2026-06-18)

A focused **board-screen-only** redesign (the merge grid scene, `engine/scripts/scenes/board.gd` +
its `ui/` builders). Map/home untouched this pass. **Owner decisions are baked in below** (resolved
2026-06-18). Code anchors are `file:symbol` (line numbers drift). Seven changes:

- **1 · Quests sit directly above the grid (kill the dead band).** The grid is wrapped in a
  `CenterContainer` (`board.gd:_ready`, `center := CenterContainer.new()`) with `SIZE_EXPAND_FILL`,
  so it vertically-centres in the leftover space and a tall gap opens between the quest fence
  (`giver_bar`, `FENCE_H = 196`) and the grid. **Change:** stop vertical-centring the grid — pin it
  just under the fence (drop the expand/centre, or top-align the VBox so no empty band sits between
  fence and grid). Removing the inline bag row (item 6) reclaims more height. **Why:** the white gap
  reads as broken layout; quests should anchor to the board they feed.

- **2 · One big checkmark on a ready quest, not two.** A completed ask shows BOTH a small per-ask
  ✓ on the item's corner (`giver_stand.gd:_ask_met_check`, placed ~L109-116) AND a stand-level ✓ at
  the card's bottom-right (`giver_stand.gd:_ready_check`, placed ~L141-143; toggled by
  `board.gd:_refresh_giver_lights` via `e.check`). **Change:** delete the bottom-right `_ready_check`
  (and its `check` ref wiring); enlarge the per-ask ✓ into a **big, obvious mark centred over the
  asked item** (overlapping it), driven by the existing per-ask `met` toggle in
  `_giver_is_payable`. Multi-ask quests get one big ✓ per satisfied item. **Why:** two checks are
  redundant and small; one bold mark reads "ready" at a glance.

- **3 · Locked cells use the numbered atlas; number only on the frontier; highlight what's
  unlockable now.** Art is **`assets/_originals/board/locked_cells.png`** — a **5×5 atlas of 25
  cream padlock tiles, each with a baked-in number 1-25** (bottom-right, sprout motif). First import
  it into the kit (e.g. `ui/kit/locked_cells.png`) and load via `AtlasTexture` regioned by number
  (5 cols × 5 rows; tile index = the cell's gate level, `content.gd:cell_min_level`, clamped 1-25).
  Rendering lives in `piece_view.gd:make_bramble` / `_locked_style` / `_locked_art` /
  `_lv_num_badge` / `FRONTIER_LV`. **Changes:**
  - **Numbered tile only when the locked cell is immediately adjacent to an OPEN cell** (a 4-neighbour
    is `board.is_open`). Replaces the current level-≤`FRONTIER_LV` rule. Deeper (non-adjacent) cells
    show a **numberless** lock (reuse `slot_locked.png`, or a numberless variant) so ~30 locks stay calm.
  - **Highlight "unlockable now" cells** — a glow/bright border on a locked cell that is adjacent to an
    open cell **AND** the player's level has reached its gate (`cell_min_level <= _quest_level()`), i.e.
    a merge beside it would open it (`board_model.openable_brambles` is the authority). Needs a live
    refresh: re-evaluate after every board change (pop/merge/move/sell/retrieve), alongside
    `_refresh_generator_dim`. **Why:** teach the player exactly where the next unlock is, without a wall
    of numbered padlocks.
  - *Open detail to confirm on build:* atlas number = gate level (the diamond runs ~L2→L12, within 1-25).
    If the owner means number = unlock ORDER instead, swap the index source.

- **4 · Generators + items are slightly smaller (no cell overflow).** `piece_view.gd:make_piece`
  insets the item art by `size * 0.12`; `piece_view.gd:make_generator` draws the art **full-cell with
  NO inset** (so generators bleed past the cell). **Change:** add an inset to `make_generator`
  (≈`csz * 0.12-0.16`) and nudge the item inset up a touch, so every piece sits comfortably inside
  its cell with a little margin. **Why:** art currently overflows the cell frame.

- **5 · Bottom bar = Home (centre) · Shop · Settings · Bag · Merchant — drop the Leaf.** Today the row
  is `[Home · Shop · Leaf · Gear · Bag]` (`board.gd:_ready`, built via `_make_nav_button`; `home_btn`
  →Map, `leaf_btn` is a no-op "you are here", `bag_btn` bounces the row). **Change:** remove the Leaf
  entirely; make **Home the centre, prominent button** (the larger centerpiece slot the Leaf held) that
  still navigates to the Map/decorate hub. Suggested arrangement: `Shop · Settings · [Home] · Bag ·
  Merchant` (tap-only openers left, drag-target circles right, Home dead-centre). **Why:** Home + Leaf
  read as two "home" affordances; one centred Home is unambiguous.

- **6 · Bag becomes a single circle icon (drag in / out), not an always-present row.** Remove the inline
  `bag_bar` HBox + label (`board.gd:_ready`, `_build_bag_bar`, `_rebuild_bag`, `ui/bag_view.gd`).
  **New Bag bottom-bar button:** an **empty circle with a small bag badge near the corner**; **tap →
  open the full bag** (a NEW overlay/panel listing all owned slots + the buy-a-slot affordance — none
  exists today, build it). **Drag a board item onto the circle → stash** (reuse `board.gd:_stash`); when
  the bag holds items the **circle shows the (most-recent) stashed item's icon** (+ a count badge if >1).
  **Drag/tap from the circle → return to the board** (reuse the drag-back path: `_on_bag_slot_input` /
  `_input` / `_end_bag_drag` / `_retrieve_from_bag`, re-pointed at the single icon). **Why:** the
  persistent row eats space; a single self-describing icon is cleaner.

- **7 · Merchant becomes a bottom-bar drag-to-sell circle; the fence stall is removed completely.**
  Keep the existing **Shop (currency store) button as-is** (`_open_shop` → `ui/shop.gd`). **Remove the
  squirrel sell-stall from the fence entirely:** `board.gd:_make_merchant_stand`, `ui/merchant_stand.gd`,
  `merchant_chip`, and — **parked/removed for now** — the buy-back **basket** (`basket`, `basket_chip`,
  `_rebuild_basket`, `_record_sale`, `_buy_back`, porter `_porter_tick`/`_porter_collect`) and the acorn
  **treat** (`_buy_treat`, `TREAT_COST`). **New Merchant bottom-bar button** (same circle pattern as the
  bag): a **drag-to-sell drop target**. Reuse the sell transaction `board.gd:_sell_item` → `_grant_sale`
  (drop the basket fly-target; fly the piece into the merchant circle / wallet instead). **While a spare
  is dragged over the circle, show its payout** — `G.sell_reward(code)` returns `(coins, acorns)`, so
  render e.g. **"+1 🪙"** (coin) or the acorn for a top-tier spare, so the player sees the exact reward
  before dropping. Re-point `_show_sell_affordance` / `_hide_sell_affordance` and the drop-target hit
  test (`board.gd:_on_release`, currently checks `merchant_chip.get_global_rect`) at the new icon. **Why:**
  the fence stall is clutter; a single labelled drop target makes selling clear and consistent with the bag.

**Tests / verify (per item).** Logic-testable (headless): locked-cell frontier/unlockable predicate
(adjacency + level), generator inset math, sell-payout preview value. Visual (composite/measure, never
eyeball): quests-above-grid gap = 0 dead band, single big ✓ centred on the item, bottom-bar 5-button
layout with Home centred, bag/merchant circles showing stashed-icon / payout. *(Surfaced 2026-06-18 —
owner board-UI pass; decisions resolved same day. Scope: board scene only.)*

## Open — core loop

- **Restore the sell + bag FTUEs — re-wire the §14 merchant + bag spotlights (engine · grove).** The
  "Drag a top item here to sell" and "Drag a piece here to tuck it away" feature-spotlights were both
  **removed for now** (2026-06-18) — they presented poorly (mistargeted / fired before the action was
  meaningful: before the player had a top-tier spare to sell, or a piece worth stowing). The §14 spotlight
  MECHANISM is fully intact (engine readers `core/spotlight.gd` + tests `engine/tests/spotlight_tests.gd`
  still cover all features); only the **merchant** and **bag** presentation branches were pulled from the
  board's flow (`board.gd` `_maybe_spotlight_chrome` + `_spotlight_chrome_deferred`). *(The **shop**
  spotlight was also removed — see the next item; right now NO spotlight presents.)* The registry entries
  are left in place as the gesture/label source (`grove_data.gd` `SPOTLIGHTS` → the `merchant` and `bag`
  rows). **Build:** re-add each branch (a `Spotlight.should_spotlight("merchant")` / `("bag")` guard in
  board.gd's `_spotlight_chrome_deferred`, staged merchant→bag, plus restoring the gate in
  `_maybe_spotlight_chrome`), but only after fixing the **trigger condition** so each announces when its
  well is actually actionable — merchant when a top-tier spare exists to sell (gate on the has-spares state
  that brightens the well, `board.gd` `_show_sell_affordance` / the merchant `SHADE_LIT` rule); bag when the
  player has a piece worth stowing (and free bag space). Confirm the overlays target the new bottom-bar
  merchant + bag circles (board-UI overhaul items 6/7) and mime the drag onto them. Spec: `merge_spec §14`.
  *(Surfaced 2026-06-18 — owner: the sell + bag FTUEs were broken; removed for now, restore once the
  triggers are right.)*

- **Restore the shop FTUE — re-wire the §14 shop spotlight on the home screen (engine · grove).** The
  "Tap to visit the shop" feature-spotlight over the home-screen Store button was **removed for now**
  (2026-06-18, with the sell + bag FTUEs above). The §14 MECHANISM + the `shop` registry entry
  (`grove_data.gd` `SPOTLIGHTS`) + the engine tests are untouched; what was pulled is the **presentation**
  on both surfaces — `map.gd`'s `_spotlight_shop_deferred` (the home-screen presenter; the trigger in
  `_open` and the function itself are deleted) and the `shop` branch in `board.gd`'s
  `_spotlight_chrome_deferred`. **Load-bearing side effect handled:** `map.gd` `_maybe_login_popup_deferred`
  used to skip the daily-login calendar while `should_spotlight("shop")` was true (never stack two
  overlays) and used a `_spotlight_overlay_live()` check + an extra defer frame to coordinate; with no shop
  spotlight that guard would have **permanently suppressed the login popup** (shop stays unseen forever), so
  it was removed along with `_spotlight_overlay_live` and the now-unused `Spotlight`/`SpotlightOverlay`
  imports in map.gd. **Build:** re-add the shop spotlight presenter (map.gd, and/or the board branch),
  staged after merchant/bag, AND **restore the login-popup don't-collide guard** so the calendar and the
  shop spotlight never stack on the same first-hub-open frame (the removed code is the reference). Decide
  whether the shop FTUE lives on the map, the board, or both (it is shared seen-state — whichever shows
  first marks it seen). Spec: `merge_spec §14` + §18 (login-popup coordination). *(Surfaced 2026-06-18 —
  owner: remove the home-screen shop FTUE for now.)*

- **Shop backdrop — a dedicated stall-interior scene (art lane · owner).** The Shop currently renders over an **interim engine backdrop** (a blurred + warm-tinted + vignetted copy of the live scene — `engine/scripts/ui/shop.gd` `_backdrop_material`, dials in `tuning.gd` `Shop.BACKDROP_*`) because the flat dim read as dead space. Replace with **generated art**: the squirrel merchant's **market-stall interior** (warm wood, shelves, hanging goods, soft light), `ui/kit/bg_shop.png`, same §16 pipeline as the board backdrop. On arrival the shop should draw it behind the parchment (a small engine hookup in `Shop.open` — load `bg_shop.png` when present, else keep the blur). Spec: `merge_spec §10` (presentation) + `grove_art_pipeline §1` table row. *(Surfaced 2026-06-16 — shop polish pass.)*

- **Map model — real §16 map images + on-image spot placement (art lane · owner).** The tail of the single-image-map rework (model T21; the `zone`→`map` rename + orphan-sprite cleanup shipped T38). **No engine gap** — the map view auto-wires `assets/map/map_<id>.png` (`map.gd` `_open_map`) and the Layout editor places spots on the image; this is **art + owner action**: generate the §16 per-map backgrounds (same pipeline as *Grove v1 art*, below), then re-place each map's spots via the Layout editor. `data/placements.json` was wiped to a clean slate (T38, owner call — `layout.gd` falls back to `grove_data` defaults), so re-placement starts fresh for **every** map. *(Pairs with the KEYSTONE hub loop below.)* *(T21 parked tail; (a)+(c) shipped T38.)*

## Open — economy

- **Economy 2nd-batch follow-ups — entry-point merge · feel sign-offs · the IAP/ads SDK (T42–T45).**
  ⚠️ **SUPERSEDED IN PART by the population/residents design change (2026-06-17):** the **hub-yield +
  upgrade-levels loop (T42)** is being **REMOVED** — the §8 keystone is now the **population/residents loop**
  (welcome residents on completed maps; Coins base / Diamonds premium; same-kind auto-merge), restoration
  spots become **unlock-once** (no Coins-upgrade axis), and the §10 economy is **reopened** (re-author
  `grove_sim` around the resident sink; the 96🪙/day faucet + ~8,600🪙 hub ladder are deleted). See
  `merge_spec §8`, `grove_spec §3/§5/§10`. The **T42 hub-yield code/tests/`HUB_*` dials below are now
  the thing to RIP OUT**, not sign off; T43/T44/T45 (IAP/ads/vault/login) are **unaffected** and still apply.
  Below records the shipped state for the rip-out, not a live keystone. — The
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

- **2× rewarded-ad doubler — flush out the full workflow (engine SDK + trigger coverage + tuning · grove/engine).**
  The 2× "double your coins" card was **re-homed** from the removed hub yield-collect to the **quest coin overflow**
  (`board.gd` `_on_giver_tap` → `_maybe_offer_2x(sp_coins, …)` after `Save.add_coins`; card + `_accept_2x_offer`/
  `_dismiss_2x_offer` now live in `board.gd`; the ad id is still `collect_2x`). It works end-to-end against the
  honest stub (`grove_tests` `_test_2x_doubler_rehome`), but the workflow is **not finished**:
  • **Real ad SDK.** `ads.gd` `can_show`/`claim`/`consume_2x` are stubs (instant "watch"); the load→show→reward
  callback behind the geo build-flag is the **external remainder** (shared with the T43 ads tail above) — until it
  lands, accepting credits the bonus on a confirm-stub, no actual video.
  • **Trigger coverage.** It fires only on **regular** quest deliveries. The **gate quest's large coin reward**
  (`board.gd` `_deliver_gate`) is an infrequent big lump and the strongest 2× moment — decide whether to extend it
  there (and to generator-grant deliveries). Currently those pay coins with no doubler offer.
  • **Rename the ad id.** `collect_2x` is now a misnomer (it doubles a quest reward, not a hub collect) — rename in
  `ads.gd` + its cap/cooldown config and the call sites for clarity.
  • **Owner tuning (perceptual).** The `collect_2x` daily cap + cooldown, the card copy ("Watch a cloud → double
  it!") + its board placement, and the **offer frequency** — quest deliveries are frequent, so confirm the cap keeps
  the card a treat, not a nag (observe / sim the offer rate vs. the cap). Was flagged as T45 "perceptual placement."
  Spec: `merge_spec §10/§18`, `grove_spec §10`. *(Surfaced 2026-06-18 — re-home shipped (`6ff5b01`); this is the maturation tail.)*

- **Shop cosmetic LOOKS — apply the owned look to the board/map render (small follow-up · T40).** The
  Shop now sells cosmetic looks (T40 — `SHOP_COSMETICS` in `grove_data.gd`, unlock stored in
  `grove()["cosmetics"]`), but the chosen theme is **granted-and-owned only — not yet applied** to the
  board background / map render. **Build:** read the owned cosmetic in the board/map view and swap the
  look. *(Surfaced 2026-06-15 — T40 parked tail.)*

## Open — meta, content-cadence & infra

- **Push notifications + re-engagement (spec done · engine code · grove — UN-DEFERRED to launch).** §18: local + remote pushes (energy-full · yield-ready · event beat · win-back), opt-in, calm-toned, capped, prompted **after a rewarding moment** (never cold launch), per-type Settings toggle. The grove skeleton **deferred** notifications (`grove_spec §1`) — now **launch scope** (a silent energy return-hook with no prompt is the costliest omission, per the director review). **Absent** (no notification code). **Build (engine):** local-notification scheduling + a remote-push hook + opt-in / quiet-hours / caps. **Build (grove):** copy, cadence, reward sizes. *(Surfaced 2026-06-14 — director review.)*

- **Gentle-urgency + recurring-scarcity events & opt-in social/competitive (spec done · engine · grove).** §17 adds **gentle urgency softened by recurrence** (time-boxed exclusives that return on a **seasonal calendar** — cozy-safe FOMO) and an **opt-in, async, positive-sum social layer** (bracketed "race a few others" leaderboard events, gifting, light co-op / community goals — no-lose, solo-playable). **Absent** (no recurrence, leaderboard, gifting, or community-goal code). **Build (engine):** event recurrence rules; the async-bracket leaderboard, gifting, and community-goal surfaces (flagged, §11). **Build (grove):** the seasonal calendar, which social surfaces ship, bracket/gift caps. *Extends the live-ops/events framework item below.* *(Surfaced 2026-06-14 — director review.)*

- **Featured quests — flesh out a surface where featured-ness is actually a CHOICE (engine flag exists; board UI removed).** The §7 `featured` flag + its coins/premium bonus are live in the quest data (`content.gd` `gen_quest`; rate/bonus dials in `grove_data.gd` `QUEST_FEATURED_*`) and still pay out silently on hand-in (`board.gd`). **The board badge was removed** (the gold "Featured" ribbon + the `+N💎` shoulder on the giver stand, `giver_stand.gd`) because **quests aren't skippable** — flagging one as special on the fence is noise the player can't act on, so it added nothing. Featured-ness only earns a surface when it drives a *decision*: the spec's **"do a featured quest" daily/event hook** (§17/§18) — an objective that points the player at a featured quest, so the highlight finally has a target. **Build:** a featured-quest daily/event objective (rides the live-ops/events framework + task strip), and only then a fence highlight wired to it. Until that lands, featured is a silent bonus — correct, just invisible. *(Surfaced 2026-06-18 — owner call: drop the board badge, keep the mechanic.)*

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
  `stars_earned`, a per-day refill date, the live generator set + retired-line state (generator-grant model),
  the **per-map resident roster** (the population loop's source of truth — type+tier counts per completed map,
  Core §8 / `grove_spec §3` — this is the persisted-roster the on-screen wanderers render from),
  the Collection (retired lines), generator burst-upgrade levels, and event
  state. **(The old buildable upgrade-levels + yield-collection timestamps are NO LONGER needed — the
  hub-yield loop is removed; spots are unlock-once and the roster replaces yield state, 2026-06-17.)**
  Retire `exp`/`qdone_chapter`; bump `SCHEMA_VERSION` (currently 2) with a deep-merge
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

- **Premium diamond surprise-capsule — special-character "gachapon" (post-v1, behind a readiness gate;
  REVERSED from cut, owner 2026-06-17).** A diamond surprise-capsule yielding **special characters** for the
  population/residents loop (Core §8 / `grove_spec §3`). Previously **permanently cut (tone)** — that
  `grove_spec §1` line is now **amended** (gacha/mystery crates removed from it; the bounded reversal
  recorded). **It is part of the design but ships POST-V1**, gated on a **readiness condition: the
  deterministic resident loop is proven healthy** (the v1 base/premium-resident welcome + auto-merge
  economy is sim-validated and live) **AND a special-character library exists** (enough premium-resident art
  to fill a non-disappointing pull). It must carry all **seven locked cozy guardrails** (Core §4's
  bounded-surprise-capsule clause — absent any one, it does not ship): **(a)** cosmetic-only forever (no
  yield, no power); **(b)** no-loss randomness — every pull is *wanted*, dupes **auto-convert** to
  merge-fuel / soft-currency, never wasted; **(c)** no dangled rarity tiers; **(d)** no pity timer; **(e)**
  evergreen — no time-limited / FOMO capsules; **(f)** soft, transparent pricing with a **free/earned path**
  to the same collection; **(g)** diegetic framing — **never the word "gacha"**, and **not bolted onto the
  peddler** (its no-predatory role is already set). **Build (engine):** the capsule mechanism (pull,
  dupe-auto-convert, the earned-path faucet) behind a flag. **Build (grove):** the premium-resident
  library + diegetic frame + pricing. Spec: `merge_spec §4` (the clause), `grove_spec §1` (Scope — the
  reversal). *(Surfaced 2026-06-17 — owner reversal of the §1 "permanently cut" gacha line.)*

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
