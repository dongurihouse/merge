# Backlog — parking lot

Deferred / discovered work, parked as one-liners with enough context to pick up cold. This is a
**parking lot, not a worklist**: the Dev decides what's pulled next; nothing here is "in progress."
On pickup, an item becomes a `T#` task in [`TASKS.md`](TASKS.md). Format + rules:
`~/.claude/docs/engineer.md`.

The items below come from an **engine-wide audit against `merge_spec` (2026-06-14)**. Since then the
**generator + quest core has shipped** — per-zone generators, the generator-grant hand-in, the §7
generated-quest economy, and the v1 content roster (`T17`–`T20`, see [`TASKS.md`](TASKS.md)) — so those
**completed items are removed from here** (only their parked **art + tuning** tail remains, at the bottom).
What's left below is the **remaining** *replace* / *fix* / *greenfield* work; code anchors are `file:line`
at audit time (some now stale where the code moved).

---

## Open — core loop

- **Map model — one image = one map (collapse map/zone; open space + props; no interiors) (spec done · code · grove). Owner 2026-06-15.** §8 rewritten: a **map is one self-contained LLM image** (§16) — an **open space** with a few buildings + placed **props**, **no walk-inside interior** and **no seamless overworld** (discrete maps reached via a **map-select**). Restoration spots = the buildings/prop-clusters on that one image (Stars+level gated, as before); restoring all a map's spots **unveils its great-spirit gate quest** (a randomized top-tier offering, §7) and delivering that unlocks the next map; **maps are small → a faster map→map cadence**. Anti-abandonment = the **home hub** (the permanent, coin-fed customization anchor — the keystone item) **+ live-ops events staged in already-restored maps** (§17); the **growing-vista** and **per-map yield/feed-forward** ideas were **rejected/parked** (the vista fights §16's no-seamless-world rule; per-map yield is a chore). **Spec renamed `zone`→`map` throughout `merge_spec`** — this BACKLOG and the **code still say `zone`** (e.g. `map.gd`, `ZONE_RAMP`, `appears_at`, `interior_view`) pending the code rework. **Code is the OLD model:** an overworld-of-zones + walk-inside `interior_view` interiors + per-spot binary own + cosmetic-only coin sinks. **Build (engine):** the single-scene map render + map-select; a **persistent home-shortcut on the HUD** (jump to the hub from anywhere to collect/upgrade) + the hub's **deeper, ongoing upgrade/décor surface** (the hub map is authored differently from a finish-once map); **remove `interior_view`** + the per-map env-unlock/coin-sink code; the `zone`→`map` symbol rename. **No episode/chapter tier — a flat map sequence.** **Build (grove):** designate the hub map (the homestead), the maps & their props, spots-per-map. *(Surfaced 2026-06-15 — owner call.)*

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

- ✅ **Level-gated obstacle cells — DONE (T21, 2026-06-15).** Per-cell `min_level` shipped: `grove_data.MIN_LEVEL`
  (the §4 diamond) → `cell_min_level`; `openable_brambles(cell, player_level)` opens a sealed neighbour on any
  adjacent merge once the player's Level reaches it (the tier-ring `bramble_gate`/`gate_line_of`/`gate_req_of` are
  gone; terrain stays a 0/≠0 sealed flag, gate reads the static table → no save migration). Open sub-Q resolved in
  spec §4 (merge-openable). **no-strand sim-PASS** (seeds 42/7/123/999); `make test` 436/436. Committed on
  `feat/level-gated-cells` — **merge to `main` pending the tree clearing** (other agents' uncommitted edits span all
  6 of this task's files). **Residual PARKED → the Economy tuning item (below):** the shipped gradient ~halves pace +
  cramps the FTUE (2 free cells until L2); softening recovers pace but breaks I2, so the gradient is tuned jointly with
  the level curve + water gift, not in isolation.

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

## Parked — per-zone generators: art + tuning (the remaining tail of T17–T20)

- **Economy tuning + pacing sign-off (§3 · §7 · sim).** The §7 generated-quest economy is **live and
  sim-green on the invariants** (T19: no-jam · no-strand · I2 steady-state <30% · selling-not-income).
  What remains is the **feel/pacing call the sim can't make:** the provisional `grove_data.gd` quest
  tunables (`STAR_CAP`, `CLICK_TO_VALUE`, `QUEST_LEVELS_PER_TIER`, `GATE_TIER_BASE`/`GATE_ASK_COUNT`,
  featured rate) await the **owner's pacing sign-off**, and the §3 `LEVEL_STARS` curve is **untouched +
  available to recalibrate** (steady-state I2 was carried by the §7 tier knob, so §3 didn't need to move
  — but it's the lever if leveling should be faster/slower). Best judged once the art (below) makes it
  playable; re-validate any change through the Monte-Carlo sim (`games/grove/tools/grove_sim.gd`). **+ The §4
  `MIN_LEVEL` gradient (T21, 2026-06-15):** the shipped table is strand-safe + I2-clean, but level-gating **~halves
  pace** vs the old tier-ring (30d sim: stars ~halved, maps 4–5/5 → 2/5) and caps the early FTUE at **2 free cells
  until L2** (at L1 nothing is openable). A softer gradient (inner ring → L1) recovers the pace (sim-validated) but
  **over-feeds the water gift → breaks I2** — so tune the gradient **jointly with `LEVEL_STARS` + `LEVEL_WATER_GIFT`**
  here (after the burst-pop item settles the +20→+50 water faucet), re-validating **both no-strand AND I2** on the sim.
  *(Was
  the "Economy rebalance under per-zone generators / #4" item — it folded into §7's tuning. Surfaced
  2026-06-15 — T17 sim findings; §7 cutover T19.)*

- **Grove v1 art — ~192 item sprites + 12 generators (§16 LLM pipeline) — ⚠️ large.** The v1 home-grove
  content roster (T20) is authored as DATA; its lines render **code-drawn** until the sprites land.
  **Build (art):** the **24 lines × 8 tiers (~192) item sprites + 12 generator sprites** (maps 1–5,
  Farmhouse · Barn · Pond · Orchard · Meadow) via the §16 pipeline — tier-readability law (steps in
  size + silhouette, ~100 px), a shared per-line motif. (The full 15-map arc ≈ 832 sprites is
  post-launch.) **+ a small engine follow-up** (per-zone item #3): keep the `seed_satchel` anchor live +
  askable past map 1 on a **cold load** (`seed_gens` / `lines_for_zone`) — it already persists in live
  play via the hand-in flow. *(Surfaced 2026-06-14; data built T20 2026-06-15.)*
