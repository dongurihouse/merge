# Backlog — Acorn Forest: Merge!

Reviewed + reorganized **2026-06-23** (owner pass — old per-surface sections collapsed into the
owner-driven buckets below). On pickup an item becomes a `T#` task in [`TASKS.md`](TASKS.md); format +
workflow in `~/.claude/docs/engineer.md`. Code anchors (`file:symbol`) drift — trust the symbol name
over the line number.

Buckets:
- **High priority — build now** — the do-now worklist.
- **Low priority — parking lot** — designed/known but deferred; not pulled until promoted up.
- **Features** — larger feature builds.
- **Tuning** — owner feel / pacing calls (numbers; re-validate on `grove_sim`).
- **Testing** — re-enable / add coverage.

## High priority — build now

_(The mystery-reward dialog shipped as **T53**, 2026-06-23 — see `tasks/ux-feel.md`.)_

- **FTUE system — redesign as ONE reusable hand-gesture spotlight. [SPECCED · PARKED · old code
  removed]** Full design: `docs/superpowers/specs/2026-06-23-ftue-hand-gesture-spotlight-design.md`.
  One reusable overlay — a hand icon that mimes the gesture over a dimmed page — driven by a seen-once
  gate + a `{id, gesture, label}` registry, wired per site with an explicit trigger. **Implementation is
  parked**; the dormant feature-spotlight subsystem was **removed** (clean slate — see the spec's
  *Removed code* section) so the rebuild starts fresh against the spec. Summary of the locked design:
  - **Two live sites, both `drag`** (merchant + shop sites were dropped):
    - *merge* — taught the very first time on the board: drag one piece onto its match
      (`BoardLogic.find_mergeable_pair`). **This now spotlights the merge verb** — reverses the old
      `merge_spec §14` "idle hint teaches merge" rule; the idle hint becomes the post-teach re-nudge.
    - *bag* — taught the first time the board is full (`board.empty_ground_cells().is_empty()`) AND the
      bag has room AND a stashable piece exists: drag a board piece → the bag well.
  - **Dropped:** *merchant* (selling moved to the info-bar trashcan — `merchant_btn` is unassigned; the
    "drag → sell well" gesture has no target) and *shop* (the store opens from the gem-`+` pill and the
    info-bar delete icon covers the teach; this also removes the daily-login-popup collision concern).
  - **Overlay (`engine/scripts/ui/spotlight_overlay.gd`):** dim-except-cutouts (two cutouts for a drag:
    source + target; one for a tap), a pulsing ring per cutout, and a hand that travels source → target
    (drag) or taps in place (tap), on a loop. Built from a real `ui/kit/hand.png` art asset (intake
    pipeline) with the code-drawn `_HandDraw` as the §13 fallback.
  - **Tests:** re-enable `engine/tests/spotlight_tests` in the active `ENGINE_TESTS`; retarget it to the
    merge/bag registry. *(merges old core-loop items 3.1 + 3.2.)*

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

- ✅ **Reintroduce the burst-upgrade buy UI — SHIPPED as T54** (2026-06-23, `tasks/ux-feel.md`). Dev
  design call: the buy lives on TWO surfaces — the board **info bar** when the generator is tapped (a
  green "Boost / 🪙cost" chip in the slot the sell button leaves empty for generators;
  affordable/dimmed/hidden-at-max) + a coin-priced **water-shop** card ("Boost" under a "Bigger bursts"
  section). One shared seam `G.try_upgrade_burst()` (content.gd) drives both surfaces; `board.gd`
  `_upgrade_gen_burst` delegates to it. Code-built chip (StyleBoxFlat, the redesign's cream/Rest-plane
  language). *(was old HUD 7.1.)*

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

- **Buy an item from the board's item info bar (replaces the shop item-shortcuts).** The shop's
  item-shortcut catalogue (buy a mid-tier piece to skip the grind) was removed 2026-06-23 — owner
  call: item-buying belongs on the board, not in the store. Rebuild it as a **Buy** action in the
  item info bar that opens when a board/bag item is tapped: show the piece + a price, and on confirm
  spend the currency and **place the bought piece on the board** (not the old map→bag drain queue).
  Gone with the removal: `SHOP_ITEM_OFFERS` / `SHOP_FEATURED_COUNT` (`grove_data.gd`), the shop's
  `buy_item_offer` / `offers_for` / `drain_pending` / `pending_pieces` + the board's `shop_pending`
  drain (`engine/scripts/ui/shop.gd`, `engine/scripts/scenes/board.gd`), and the `offer` / `flow`
  strings + featured captions (`games/grove/strings.json`). Keep the §4 law: a shortcut is a
  grind-skip to a piece already reachable by merging, never a gate. *(owner directive 2026-06-23.)*

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

- **Economy balance pass — level-based reward curve + pacing sign-off (§3/§7/sim).** The 2026-06-18
  simplification made quest rewards level-based (`stars = min(level, STAR_CAP=3)`, `coins = max(0,
  level-STAR_CAP)`, gems when `level >= QUEST_PREMIUM_MIN_LEVEL=10`); all numbers are provisional. The
  owner feel/pacing call + a real sim sweep:
  - **Reward curve** — linear coins under-price deep asks (a t12 take pays only `12-3=9` coins); decide the
    real coin curve + whether the premium-gem level/amount is right; re-tune `STAR_CAP` / `QUEST_TIER_BASE`
    / `QUEST_LEVELS_PER_TIER` / featured rate.
  - **`grove_sim` tripwires are RED** (I2 per-map water-gift ratio maps 3–4; Y sell-coins income pump,
    52.7 ≥ 25) — clearing them is the sign-off gate (I1 no-jam · no-strand · P1 · P2 pass).
  - **`GEN_GRANT_REMAINING_STARS`** (when the next-generator quest surfaces near map end) — keep it below
    each non-final map's cheapest final-spot cost (today 4 < 5; preserve on roster changes).
  - **Faucet changes ride with this rebalance, not before:** level water gift +20→+50 (`LEVEL_WATER_GIFT`),
    free refills 3-lifetime→1/day (needs a per-day date, not lifetime `refills_used`), and the joint
    `LEVEL_STARS` + `LEVEL_WATER_GIFT` curve.
  - **`ASK_TIER_WEIGHT`** (§6 spawn tier-bias, `grove_data.gd`) ships at 0=OFF; full strength (0.6)
    front-loads spend ~3×, so ramping it belongs to this pass (re-tune the level curve alongside).
  Best judged once the art makes it playable; re-validate every change on the Monte-Carlo sim
  (`grove_sim.gd`). *(from old per-map-generators 11.1.)*

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
