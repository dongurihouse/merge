# Backlog — parking lot

Deferred / discovered work, parked as one-liners with enough context to pick up cold. This is a
**parking lot, not a worklist**: the Dev decides what's pulled next; nothing here is "in progress."
On pickup, an item becomes a `T#` task in [`TASKS.md`](TASKS.md). Format + rules:
`~/.claude/docs/engineer.md`.

The mechanics/economy items below were **code-verified against `merge_spec` on 2026-06-14** (an
engine-wide audit): the spec was rewritten that day and the code is still the **pre-rewrite model**
end-to-end. Code anchors are `file:line` at audit time. The one fully spec-correct system is the
**zone completion-chain** (`map.gd:193`); everything else is *replace*, *fix*, or *greenfield*.

---

## Open — core loop

- **Map model — one image = one map (collapse map/zone; open space + props; no interiors) (spec done · code · grove). Owner 2026-06-15.** §8 rewritten: a **map is one self-contained LLM image** (§16) — an **open space** with a few buildings + placed **props**, **no walk-inside interior** and **no seamless overworld** (discrete maps reached via a **map-select**). Restoration spots = the buildings/prop-clusters on that one image (Stars+level gated, as before); restoring all a map's spots **unveils its great-spirit gate quest** (a randomized top-tier offering, §7) and delivering that unlocks the next map; **maps are small → a faster map→map cadence**. Anti-abandonment = the **home hub** (the permanent, coin-fed customization anchor — the keystone item) **+ live-ops events staged in already-restored maps** (§17); the **growing-vista** and **per-map yield/feed-forward** ideas were **rejected/parked** (the vista fights §16's no-seamless-world rule; per-map yield is a chore). **Spec renamed `zone`→`map` throughout `merge_spec`** — this BACKLOG and the **code still say `zone`** (e.g. `map.gd`, `ZONE_RAMP`, `appears_at`, `interior_view`) pending the code rework. **Code is the OLD model:** an overworld-of-zones + walk-inside `interior_view` interiors + per-spot binary own + cosmetic-only coin sinks. **Build (engine):** the single-scene map render + map-select; a **persistent home-shortcut on the HUD** (jump to the hub from anywhere to collect/upgrade) + the hub's **deeper, ongoing upgrade/décor surface** (the hub map is authored differently from a finish-once map); **remove `interior_view`** + the per-map env-unlock/coin-sink code; the `zone`→`map` symbol rename. **No episode/chapter tier — a flat map sequence.** **Build (grove):** designate the hub map (the homestead), the maps & their props, spots-per-map. *(Surfaced 2026-06-15 — owner call.)*

- **Per-zone generators — the grove content map + the art (content · art).** **[Engine mechanic
  shipped 2026-06-15 as `T17` (`df23351`); the T17 evolve-merge was then **retired in code and
  replaced by the generator-grant hand-in scaffold** (`T18` 2026-06-15, `docs/tasks/mechanics.md`):
  `board_model.grant_gen` + `board.gd:_deliver_grant` fire on a `{grant}` quest, `content.gd:grant_quests_for_zone`
  authors them, and the data field `evolves_from`→`grant_from`. The §7 grant-quest **scheduling** (firing
  those authored quests in the live script) and the #4 economy rebalance are their own items below. What
  remains in THIS item is just the grove DATA + ART that dress the now-shipped mechanic.]** §6 target: the **open-ended line/generator arc** — now **designed as 15 maps in `grove_spec §2`** (v1 = the home grove, maps 1–5; ≈52 gens / 104 lines across the arc, uncapped beyond) —
  generators arrive **per zone** (z1→2 gens/4 lines · z2–3→3/6 · z4+→4/8, ~2–4 live), **2 lines
  each**, each arriving as a **generator-grant quest reward** (hand an older generator in → receive a new line; old lines retire) or granted as a surplus. **✅ Build (grove content) — DONE (T20, 2026-06-15):** the **v1 home-grove roster** is authored in `grove_data.gd` — **12 generators / 24 lines** across maps 1–5 (the `grove_spec §2` table: real names, the 2-lines-per-generator split, the hand-in lineage + surpluses, the `seed_satchel` anchor). The placeholder roster + `ZONE_RAMP` are gone (the §7 sim tunes the live model, not a ramp table); lines render **code-drawn** until the art lands.
  **⏸ Parked — art + the anchor:** **v1 ~192 item sprites + 12 generators** (maps 1–5) via the §16 LLM pipeline — ⚠️ **large art** (the full 15-map arc ≈ 832 sprites, post-launch); plus the **anchor's cold-load persistence** — the `seed_satchel` (Wildflower + Berry) persists in live play via the hand-in flow, but `seed_gens` on a fresh cold load and `lines_for_zone` (quest asks) don't yet include it past map 1 — a small engine follow-up.
  **⏸ Parked — economy feel (the items below):** the §7 **pacing sign-off** (the provisional `grove_data.gd` quest tunables) and the **§3 `LEVEL_STARS` recalibration** (#4 economy item) — both await the owner's pacing call, best made once the art makes it playable.
  *(Surfaced 2026-06-14 — spec review + code audit; engine split T17, hand-in T18, §7 cutover T19, content T20 — all 2026-06-15.)*

- **✅ DONE — T19 (2026-06-15) · Generated quests + calculated reward (§7).** §7 replaced the deterministic
  per-zone ramp with **generated** quests (asks drawn from live generator lines, weighted to the
  newest/highest-value, asks/tier scaling with **level**) and a reward **calculated from expected
  clicks** → `stars = min(value, STAR_CAP)` (~1–3★, level ∝ quest count) **+ coins** for the overflow;
  the map's top tier asked **only** by the **gate quest** — the gatekeeper's **end-of-map** capstone (a randomized top-tier offering, up to t8) that **unlocks the next map** for a large reward (the grove's gatekeeper = the **great-spirit**); **generator-grant quests** dispense the next map's producers (deliver an old generator → receive a new line — a **hand-in, not a merge**; the T17 evolve-merge is retired); plus **featured quests** (a random share highlighted, paying a coins/premium **bonus**, no extra ★). Gate + generator-grant quests are **authored**, the rest generated. **Code is the OLD
  fixed script.** **Built + cut over live (engine-side), T19:** the live game now runs the generated
  metered stream (`gen_quest`/`active_giver_count`), the capped-★ + coin-overflow reward (`quest_reward`),
  the authored **great-spirit gate quest** (gate-gated map unlock) and the **generator hand-in** opening
  each new map; `chapters()`/`ZONE_RAMP`/`_quest_stars`/`_stretch`/`lines_debuted` + the per-spot water
  gift are retired. The **quest coin faucet** (§10) is on. A **Monte-Carlo no-strand sim**
  (`games/grove/tools/grove_sim.gd`) replaces the pigeonhole proof and is **green across seeds**
  (I1 no-jam · no-strand · I2 steady-state <30% · Y selling-not-income). **Remaining:** the
  **PROVISIONAL tunables** (`STAR_CAP`, `CLICK_TO_VALUE`, `QUEST_LEVELS_PER_TIER`, `GATE_TIER_BASE`/
  `GATE_ASK_COUNT`, featured rate — all in `grove_data.gd`) await the owner's **pacing sign-off**; the
  #4 economy rebalance folds in here (steady-state I2 was carried by the §7 tier knob, so the §3
  `LEVEL_STARS` curve is untouched + available to recalibrate). *(Surfaced 2026-06-14; built 2026-06-15.)*

- **Economy rebalance under per-zone generators (sim · §3 · §7) — surfaced by T17.** The per-zone
  generator mechanic landed (T17), but the **economy sim cannot be balanced** under the interim
  `chapters()`/`ZONE_RAMP` quest model: per-zone-fresh lines mean **steep tier bands jam** the board
  (can't climb a just-granted line), **shallow bands strand** (low ★ income → level lags → the frontier
  spot is affordable-but-level-locked), and **low-uniform bands break I2** (zones too cheap → the fixed
  +20/level water gift exceeds 30% of spend) **and clear day-1**. Proven across 4 sim runs (see T17 in
  `tasks/mechanics.md`). `grove_sim` is left **RED** at uniform `t2–4` (no jam / no strand, but I2 fail +
  day-1 clear). **Fix:** balance is inseparable from **§7** (metered, level-scaled, expected-clicks
  rewards) + **§3** (`LEVEL_STARS` recalibration, already flagged provisional), re-run through the
  Monte-Carlo sim. **Likely folds into the §7 item above** (do it as the recalibration pass there) rather
  than standalone. *(Surfaced 2026-06-15 — T17 sim findings.)*

- **Burst popping + the energy-faucet code changes (spec done · code · sim).** §4/§6: a generator tap
  pops a **burst of 1–3 items** (`BURST_ODDS`), 1 energy each — base × a **per-zone free scale-up** ×
  a player **burst-upgrade** (§8). **Code pops exactly ONE item per tap** (`_pop_seed`,
  `engine/scripts/board.gd:1585`); no `BURST_ODDS` anywhere. Two faucet code-changes the spec also
  raised: **level gift +20 → +50** (`grove_data.gd:141`, applied `map.gd:1044`) and **free refills
  3-lifetime → 1/day** (today a monotonic `refills_used` vs `FREE_REFILLS=3`, `board.gd:497` — needs a
  per-day date, not a lifetime int). **Build:** the burst-pop loop + odds + per-zone scale-up; the two
  energy changes; then **economy-sim re-validation** (`games/grove/tools/grove_sim.gd` default + greedy) that a
  level's energy rewards stay **< 30%** of its cost and "sessions extend, never self-sustain" — the
  daily full refill (≈100💧/day) is a large recurring grant tensioning the monetization socket, so
  this check decides whether +50/daily is shippable. *(Surfaced 2026-06-14 — spec review + code
  audit.)*

- **Level-gated obstacle cells (spec done · code · sim).** §4 reworked obstacle gating: each cell
  carries a **`min_level`** (diamond gradient — L2/L3 frontier radiating out to **L12** at the
  corners) that unseals in waves as the player levels, then still opens on an **adjacent merge**.
  **Code is tier-ring only:** `bramble_gate` → `openable_brambles` (`engine/scripts/content.gd:90`,
  `engine/scripts/board_model.gd:114`) — no `min_level` exists. **Build:** the per-cell level gate
  against the §4 board map + **sim re-validation of no-strand** (proven against tier-gating;
  level-gating the frontier can re-strand it, and the L10–L12 corners must be reachable or
  intentionally tail). Open sub-Q: reaching `min_level` makes the cell *merge-openable* (chosen,
  preserves adjacent-unlock) or *auto-open*? *(Surfaced 2026-06-14 — spec review + code audit.)*

## Open — economy

- **⭐ [P0] Home-hub yield + upgrade-levels loop — "coins get power" (spec done · code · sim). KEYSTONE.**
  §8/§10: built things have **upgrade levels** (L1→Lⁿ — look better **and** pay back more) and
  **produce coins over time** (passive yield, collected on return, scaling with level, **capped** so
  it extends sessions, never self-sustains); coins then **sink** into those upgrades + generator
  burst-upgrades. **Entirely absent:** spots are binary owned/unowned (`engine/scripts/map.gd:977`,
  `spot_owned()` boolean `map.gd:187`), nothing accrues over time, and coins sink **only** into
  cosmetic waysides/variants/treats (net-zero — the "coins have no power" tension the spec says this
  loop resolves). **Build (engine):** per-buildable level state, yield timers + collect-on-return, the
  upgrade + generator-burst-upgrade spend paths. **Build (grove):** yield/upgrade rates + prices.
  *This closes the soft-currency loop the rest of the economy hinges on — pair with the quest coin
  faucet and the shop sinks.* **Reworked 2026-06-15 (owner):** yield/upgrade is now **home-hub-concentrated** — the hub (the first map) carries the upgrade/décor→yield loop, **not every building on every map** — so the engine build is the hub's per-buildable level + yield + spend paths (+ burst-upgrades §6), and the grove designates the hub (the homestead). **Parked (owner 2026-06-15):** **per-map yield** + **cross-map feed-forward** — rejected for v1 as a collect/grind-across-~10-maps chore; **home hub + live-ops events staged in old maps** (§17) carry anti-abandonment instead. See the map-model item (core-loop). *(Surfaced 2026-06-14 — code audit vs `merge_spec`.)*

- **Selling — per-zone coin bands + drag-only verb (spec done · content · code).** §6/§9: t1–t7 sell
  for **tier coins × a per-zone band** (later zones worth more); t8 stays flat **1💎** so the 32×
  anti-arbitrage proof holds. **Code sells flat:** `sell_reward` is tier-coins with no zone band
  (`engine/scripts/content.gd:272`), plus a stale flat `MERCHANT_COINS=25` stall pill
  (`grove_data.gd:61`, `board.gd:873`). Also: **tap-sell still exists** (`_on_merchant_tap`,
  `board.gd:1927`) but §9 says **drag is the only sell verb** — remove tap-sell. **Build:** the
  per-zone band (re-derive 32× per zone) + drop tap-sell. **Grove:** the per-zone sell-value bands.
  *(Surfaced 2026-06-14 — code audit vs `merge_spec`.)*

- **The Shop — buy-side sinks (spec done · engine code · grove stock).** §10: the Shop sells
  **item-shortcuts** (buy a mid-tier piece to skip the grind — coins low / premium high),
  **cosmetics/looks**, energy/coins-for-premium, and dark-IAP cash packs — with **rotating offers** (a
  few at a time). **Code has only** a water buy + one coin pouch + 3 cash→💎 packs, a **fixed** static
  layout with **no rotation, no item-shortcuts, no cosmetics** (`engine/scripts/shop.gd:33,47`), and a
  stale "no IAP wired" header that contradicts the live confirm-grant cash packs (`shop.gd:191`).
  **Build (engine):** the item-shortcut + cosmetic offer types + offer rotation. **Build (grove):**
  the stock list, item-shortcut prices, cosmetic catalogue. *(Surfaced 2026-06-14 — code audit vs
  `merge_spec`.)*

- **Bag capacity model (spec done · code).** §5: **6 starting slots**, **+1 at a time bought with
  premium 💎**, **max 18** (12 expansions); shelving free, no timers, persisted. **Code is the OLD
  model:** `BAG_SLOTS=2` + a single `BAG3_DIAMOND_COST=10` "3rd slot" (`games/grove/grove_data.gd:67,146`),
  a hard-coded 3-slot UI loop (`engine/scripts/board.gd:213`), and bag items **retrieved by tap**
  vs the spec's drag-back (`board.gd:1814`). **Build:** the 6→18 model, the save-blob `bag` + slot-buy
  path, drag-back retrieve, and the per-slot 💎 price schedule (flat or escalating — a grove number,
  not yet set). *(Surfaced 2026-06-14 — spec review + code audit.)*

- **Rewarded ads + the live-IAP surfaces (spec done · engine code · grove).** Core §4/§10 now:
  **IAP is live from launch** (real cash→💎, geo-flagged — supersedes the old "dark / earned-only"
  language; the stale `shop.gd:191` "no IAP wired" header must go), plus **rewarded ads**
  (rewarded-only, capped, geo-flagged: refill energy / 2× build-yield collect / free shop reroll /
  event top-up), a **starter pack + first-purchase doubler**, and a **full price ladder incl.
  $49.99/$99.99-class tiers** (replace the placeholder $0.99/$4.99/$9.99 set). **Build (engine):** an
  ad-SDK + the rewarded surfaces + caps; live-IAP store + receipt validation behind the geo flag.
  **Build (grove):** the real pack ladder + starter pack, ad caps/cooldowns/reward sizes. *Pairs with
  the Shop item above; also retire "even while dark" in the analytics item.* *(Surfaced 2026-06-14 —
  director review.)*

- **Monetization surfaces — piggy bank, triggered offers, daily login calendar (spec done · engine code · grove).** §10/§18: a **piggy-bank accrual vault** (skims earned premium → crack for one fixed cash price), **triggered "out-of-Water" offers** (state-fired at the energy wall, distinct from the rotating Shop), and a **forgiving daily login calendar** (escalating streak, no day-1 reset). **All absent** — Shop is static-rotating only (`engine/scripts/shop.gd`); no vault / trigger / login-calendar code. **Build (engine):** the vault skim+claim path; the state-triggered offer hook (keyed off §15 analytics); the login-streak model (respecting the §4 self-sustain invariant). **Build (grove):** skim rate + pig price, offer discount/caps, the streak ladder + milestones. *(Surfaced 2026-06-14 — director review.)*

## Open — meta, content-cadence & infra

- **Push notifications + re-engagement (spec done · engine code · grove — UN-DEFERRED to launch).** §18: local + remote pushes (energy-full · yield-ready · event beat · win-back), opt-in, calm-toned, capped, prompted **after a rewarding moment** (never cold launch), per-type Settings toggle. The grove skeleton **deferred** notifications (`grove_spec §1`) — now **launch scope** (a silent energy return-hook with no prompt is the costliest omission, per the director review). **Absent** (no notification code). **Build (engine):** local-notification scheduling + a remote-push hook + opt-in / quiet-hours / caps. **Build (grove):** copy, cadence, reward sizes. *(Surfaced 2026-06-14 — director review.)*

- **Gentle-urgency + recurring-scarcity events & opt-in social/competitive (spec done · engine · grove).** §17 adds **gentle urgency softened by recurrence** (time-boxed exclusives that return on a **seasonal calendar** — cozy-safe FOMO) and an **opt-in, async, positive-sum social layer** (bracketed "race a few others" leaderboard events, gifting, light co-op / community goals — no-lose, solo-playable). **Absent** (no recurrence, leaderboard, gifting, or community-goal code). **Build (engine):** event recurrence rules; the async-bracket leaderboard, gifting, and community-goal surfaces (flagged, §11). **Build (grove):** the seasonal calendar, which social surfaces ship, bracket/gift caps. *Extends the live-ops/events framework item below.* *(Surfaced 2026-06-14 — director review.)*

- **The Collection — retired-line almanac (spec done · engine code · grove).** §6: a line that retires
  (zone advance, or an event ending) **archives to the Collection** — a completionist almanac keeping
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
  retired). **Build (grove content):** giver names/personalities/wishes + per-zone beats + the Map-1
  episode (authored crossing/FTUE → restoration beats → heart-tree waking → reunion + onward hook);
  image-memory vignettes. **Build (art):** the cast, the parents + their **easing de-transformation**
  (composited per zone, Core §16), the great-spirit's **bloom-awake** climax, candidate later maps.
  **Build (engine, maybe):** the per-zone de-transform swap is plain compositing (Core §16) — likely no
  new engine system, but the FTUE crossing + the parents-as-guides surface may need wiring. Engine
  giver-arc layer is Core §7. *Fleshes out the old "character arcs for givers" item (now specced).* ✅ **`grove_spec` reconciled (2026-06-15):** map = a beat (one image) with **no episode/chapter tier** (a flat map sequence), the **Farmhouse is the home hub** (authored deeper + a HUD home-shortcut to return & keep upgrading), the legacy free-pan/`interior_view` model retired — the §1 story + §3 build sections now read on the single-image-map model. Only the content/art/code **build** below remains (the `zone`→`map` code rename rides with the map-model item, core-loop).
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
