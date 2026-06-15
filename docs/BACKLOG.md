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

- **Map model — one image = one map.** ✅ **Shipped as T21** (2026-06-15, `tasks/mechanics.md`): single-image maps + a discrete **map-select** + a persistent **home-hub shortcut**; the free-pan overworld, walk-inside `interior_view`, and on-map wayside coin-sink are removed; the Farmhouse is designated the hub (recast to the §3 roster + a `kind` yield/décor seam). Verified `make test` 404/404 + captures. **Parked follow-ups:** (a) the **`zone`→`map` symbol rename** — deferred (T21 Decisions #1): a now-collision-free, suite-verifiable mechanical sweep across the (committed) §6/§7 code + tests + sim; (b) the hub **upgrade→yield loop** = the KEYSTONE economy item (below); (c) real §16 map images + on-image spot placement (owner re-places via the Layout editor) = art lane. Orphaned old-id `furn_fh_*.png` sprites are now unused (asset cleanup, minor).

- ✅ **Level-gated obstacle cells — DONE (T24, 2026-06-15).** Per-cell `min_level` shipped: `grove_data.MIN_LEVEL`
  (the §4 diamond) → `cell_min_level`; `openable_brambles(cell, player_level)` opens a sealed neighbour on any
  adjacent merge once the player's Level reaches it (the tier-ring `bramble_gate`/`gate_line_of`/`gate_req_of` are
  gone; terrain stays a 0/≠0 sealed flag, gate reads the static table → no save migration). Open sub-Q resolved in
  spec §4 (merge-openable). **no-strand sim-PASS** (seeds 42/7/123/999); `make test` 436/436. Committed on
  `feat/level-gated-cells` — **merged to `main` 2026-06-15 (`ab7e23f`, T24)** (the tree cleared once the parallel
  threads committed). **Residual PARKED → the Economy tuning item (below):** the shipped gradient ~halves pace +
  cramps the FTUE (2 free cells until L2); softening recovers pace but breaks I2, so the gradient is tuned jointly with
  the level curve + water gift, not in isolation.

## Open — economy

- **⭐ [P0] Home-hub yield + upgrade-levels loop — "coins get power" (spec done · Part B DONE · Part A: A1 merged, A2–A9 = next pickup · sim). KEYSTONE.**
  §8/§10: built things have **upgrade levels** (L1→Lⁿ — look better **and** pay back more) and
  **produce coins over time** (passive yield, collected on return, scaling with level, **capped** so
  it extends sessions, never self-sustains); coins then **sink** into those upgrades + generator
  burst-upgrades. **Today:** hub spots are **binary owned/unowned** — restore = `Save.spend_stars` →
  `unlocks[id]=true` (`engine/scripts/scenes/map.gd` `_on_spot_tap` `:654`; `spot_owned()` `:158` —
  re-verified 2026-06-15, T25; earlier `~:957`/`:181` and the audit's `:977`/`:187` are stale), nothing accrues over time,
  and the only owned-spot coin sink is a **cosmetic variant** (`_apply_variant`, net-zero). *(Waysides —
  the old structural sink — are **removed** by the map-model rework (T21); variants + treats remain, still
  cosmetic, so the "coins have no power" tension stands.)* **Two coin-sink subsystems, split + sequenced:**
  • **Part A — hub buildable yield + upgrade-levels = the v1 KEYSTONE.** Per-spot level (restore→L1,
  coin-upgrade L1→Lⁿ = richer look + higher yield); yield buildings accrue coins to a **per-building daily
  cap**, swept in **one collect-on-return** beat (never a per-building tap chore). Reads the
  `kind:"yield"/"decor"` + `hub:true` seam that **ships with the map-model rework (T21)** — so Part A is
  **unblocked once T21 merges**. **Build (engine):** `content.gd` rate/cap/accrual + `spot_is_yield`;
  restore→L1 + the coin upgrade-spend + the hub-collect beat (`map.gd`/`hud.gd`). **Build (grove):**
  yield/upgrade rates, per-building cap (≈ a day), prices. **Status:** **A1 (save schema — `levels{spot_id}`
  + `hub_collected_at` + accessors + rename-migration in `save.gd`) DONE + MERGED to `main`** (T22, `a4168d4`),
  `save_tests` 32/0. **T21 is now merged (`6f9faf9`), so A2–A9 are UNBLOCKED — this is the keystone's next pickup.**
  • **Part B — generator burst-upgrade (§6 board sink) — ✅ DONE (T23 mechanic + T25 UI, 2026-06-15).** A coin
  sink to pop more per tap. T23 built the **burst-popping** mechanic + spend path (`board.gd`
  `_upgrade_gen_burst()`/`_gen_burst_level()` + the `BURST_UPGRADE_COSTS` ladder). **T25 wired the trigger UI**
  — an **on-board buy pill** on the primary generator (`_rebuild_burst_chip`/`_try_buy_burst`/`_on_burst_chip_input`),
  **not** the hub: the affordance lives on the board per spec §8 ("board-level… *independent of the hub*"),
  reachable on every map. The backlog's earlier "hub surface" wording is **superseded** (board placement, owner
  call 2026-06-15). `make test` 430/0 (grove +6 pill assertions); chip composited-verified on the live board.
  **Burst tuning — ✅ DONE (T25, 2026-06-15).** The cap-collision is fixed: the free portion (base + per-map
  gift) is capped on its own at `BURST_FREE_MAX=4`, the paid level adds **on top** (`burst_count` decoupled), so
  each bought level always gives +1; `BURST_MAX` 6→8, ladder re-priced + lengthened 60/180/480 → **120/360/840/1800**
  (4 levels, total 3120 > faucet so coins keep a target). Sim-validated (seeds 42/7/999, 30d): no-strand · I2
  steady-state hold; the burst sink now absorbs **64–76%** of the coin faucet (was 34–50%). Remaining parked: burst
  stays GLOBAL (per-generator parked). **⚠️ surfaced during re-validation → see the Economy-tuning item:** the
  integrated `main` JAMS on seed 123 (burst × level-gating, map 1) — pre-existing, not from this change.
  *This closes the soft-currency loop the rest of the economy hinges on — pair with the quest coin faucet +
  the shop sinks.* **Reworked 2026-06-15 (owner):** hub-concentrated (the hub carries the loop, **not every
  building on every map**). **Parked (owner 2026-06-15):** **per-map yield** + **cross-map feed-forward** — a
  collect-across-~10-maps chore; home hub + live-ops in old maps (§17) carry anti-abandonment. *(Surfaced
  2026-06-14 — code audit; anchors re-verified + A/B split + deps added 2026-06-15, T22 pickup; Part B burst
  mechanic merged 2026-06-15, T23.)*

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

## Open — second-pass spec audit (2026-06-15) — un-parked engine gaps

A second pass over `merge_spec` (engine re-read §2–§15 by parallel auditors) found gaps the
**first audit (2026-06-14) missed** — engine mechanisms the spec calls for that are absent or
half-built, none already parked above. Grouped by severity (Tier 1 functional · Tier 2 polish ·
Tier 3 spec↔code drift). Anchors are `file:line` at 2026-06-15.

### Tier 1 — functional gaps (missing or wrong engine behavior)

- **FTUE feature-spotlight + hand-gesture guide — ABSENT (spec done · engine code · grove).** §14/§11:
  every feature, on first appearance, gets a spotlight + pulse **and a mimed tap/drag guide** ("no
  feature appears unannounced") — the load-bearing wordless-teach surface for the §1 zero-learning
  pillar. **Code:** the `ftue_feature_spotlight` flag isn't in `engine/scripts/core/features.gd` (only
  `ftue_free_pops` + `ftue_staged_chrome`); no spotlight/pulse/gesture code anywhere (grep-clean).
  **Build (engine):** the spotlight overlay + pulse + a mimed-gesture (tap/drag) player + a per-feature
  first-appearance trigger. **Build (grove):** which features spotlight, in what order. *The largest
  single gap in the audit.* *(Surfaced 2026-06-15 — second-pass audit §14.)*

- **Featured quests are invisible — fence flag + premium bonus missing (spec done · engine code).** §7:
  a random share of quests are "featured — **flagged on the fence**," paying a bonus (extra coins,
  *occasionally a premium*), never extra ★. **Code:** `gen_quest` computes `featured` and adds the coin
  bonus (`engine/scripts/core/content.gd:293`) but the `featured` key is **read nowhere** — the fence
  (`board.gd:708`) never renders it, so a featured quest looks identical; no premium-bonus branch
  exists. **Build (engine):** render the featured flag on the giver stand + add the occasional-premium
  bonus. *(The featured **rate** is already parked as an economy-tuning number — this is the missing
  surface, not the rate.)* *(Surfaced 2026-06-15 — second-pass audit §7.)*

- **Anchor-line exemption is half-built — anchor lines un-askable past map 1 (spec done · engine code).**
  §6: the anchor line "permanently holds one of the live slots" — its lines stay live **and askable**
  for the life of the save. **Code:** the anchor generator persists (never a `grant_from`) and keeps
  popping lines 1/2, but quest/gate generation draws from `lines_for_zone` (the **zone roster**) not
  `gen_live_lines` (the **live board set**) — `board.gd:437` — so past map 1 no quest ever asks the
  anchor's lines (dead output). **Build (engine):** feed quest/gate generation the live board lines
  (anchor ∪ current zone), not the zone roster. *(The "Grove v1 art" engine follow-up #3 below parks
  only the cold-load slice + asserts live-play "already persists" — true of the generator, false of its
  askability; this is the un-parked half.)* *(Surfaced 2026-06-15 — second-pass audit §6.)*

- **Calm mode doesn't disable `breathe` (spec done · engine code).** §12: calm "halves particles **AND
  disables breathe**." **Code:** particle-halving works (`engine/scripts/ui/fx.gd:21`); `breathe` /
  `breathe_once` (`fx.gd:60`, `:100`) have no calm guard, so the one-suggested-action pulse still runs
  in calm mode (refill/gate buttons, generators, quest chips, spot cards). **Build:** gate `breathe` /
  `breathe_once` on `FX.calm()`. *(Surfaced 2026-06-15 — second-pass audit §12.)*

- **Emoji-purge violated in runtime floaters/tags (spec done · engine code).** §13: "no emoji glyphs in
  shipped UI; every glyph a sprite via `Look.icon()`; numbers sit beside an icon." **Code:** currency
  floaters/tags bake emoji into `Label.text` unconditionally — `tr("+%d★")` / `tr("+%d🪙")` /
  `tr("+%d💧")` / `tr("+%d💎")` (`board.gd:1940`–`:2069`, `map.gd:688`) — bypassing `Look.icon` with **no
  art-swap path**, so they keep showing emoji after kit art lands. **Build:** a floater/tag variant that
  composites an icon sprite + number. *(Distinct from the sanctioned `ICON_GLYPHS` **fallback** dict in
  `skin.gd:87` and the gear/shop/✕ fallback branches.)* *(Surfaced 2026-06-15 — second-pass audit §13.)*

- **FTUE free pops × burst — the 10-pop intro is consumed by burst (spec done · engine code · decision).**
  §4: "first 10 pops… uncounted; the opening minute is pure frictionless merging." **Code:** burst
  applies during the free phase and each item increments the same `pops` odometer (`board.gd:1639`), so
  a 3-item tap spends 3 of the 10 free pops (the intro can end in ~4 taps; the boundary can overshoot
  mid-burst). **Decide + build:** suppress burst during FTUE, or count taps not items, or raise the free
  budget. *(Surfaced 2026-06-15 — second-pass audit §4.)*

### Tier 2 — polish deviations

- **Idle hint doesn't pulse the obstacle a merge would open (spec done · engine code).** §2: the idle
  hint should pulse "obstacles a merge would open." **Code:** the rock-pair + ~4.5 s / 4 s re-nudge
  cadence is correct, but `board_model.openable_brambles` is never called during the hint
  (`board.gd:311`) — the "this merge unseals that cell" teach-signal is missing. **Build:** pulse the
  cell(s) the hinted pair's merge would open. *(Surfaced 2026-06-15 — second-pass audit §2.)*

- **Giver bob fires on every giver, not only deliverable ones (spec done · engine code).** §2:
  "deliverable givers bob." **Code:** `_giver_bob` is called unconditionally (`board.gd:715`) with no
  payable check, so the bob carries no "ready" information (the green ✓ check is the only ready cue).
  **Build:** gate the bob on quest-payable. *(Surfaced 2026-06-15 — second-pass audit §2.)*

- **Full board doesn't dim the generator (spec done · engine code).** §6: "a full board dims the
  generator (popping is free while dimmed)." **Code:** a blocked tap wobbles + plays the invalid sound
  (`board.gd:1612`) but applies no standing dim; the free-while-full economics work, only the dim cue is
  missing. **Build:** modulate the generator dim while the board has no free cell. *(Surfaced 2026-06-15
  — second-pass audit §6.)*

- **No fog / veiled horizon on the map-select (spec done · engine code · grove art).** §8: "parts of a
  map sit behind fog… the next map shows **veiled** on the select." **Code:** locked maps render as
  plainly-greyed-but-legible cards (`map.gd:557`) with a "✿ after X" line — desaturated, not
  veiled/teased; no fog layer, no on-map fogged regions. **Build (engine):** a fog/veil treatment for
  locked-map cards (+ optionally fogged on-map regions). **Build (grove):** the veil art. *Pairs with
  ghost-preview below — the §8 desire/discovery build-juice layer T21 didn't cover.* *(Surfaced
  2026-06-15 — second-pass audit §8.)*

- **No ghost-preview of empty restoration spots (spec done · engine code).** §8: "an empty spot may
  ghost-preview the buildable." **Code:** unowned spots show only a price-pin + name (`map.gd:323`); the
  buildable sprite renders only in the debug Layout editor, never for players. **Build:** an optional
  ghosted preview of the buildable on an unowned spot. *(Surfaced 2026-06-15 — second-pass audit §8.)*

- **Gate-quest unveil is silent across screens (spec done · engine code).** §8: completing a map
  "unveils its gate quest." **Code:** the mechanism is correct (map-complete → gate quest becomes the
  lone fence stand → unlock chain), but map-completion fires only a flourish on the map screen
  (`map.gd:684`) and never points the player to the gate quest now waiting on the board — a silent
  cross-screen handoff (against the no-required-reading pillar). **Build:** a wordless map→board pointer
  on completion. *(Surfaced 2026-06-15 — second-pass audit §8.)*

### Tier 3 — spec↔code drift (likely reconcile the SPEC)

- **HUD law drift — Shop moved out of the top-right bar (decision).** §13 HUD law: the top bar is
  "wallet + Shop" top-right, primary CTA bottom-center. **Code:** the Shop was deliberately moved to the
  bottom bar (owner 2026-06-13, `engine/scripts/ui/hud.gd:69`); the board shows `[◀ Home][🛒]`
  bottom-left, the map a bottom-right Shop beside the gear. **Decide:** update §13's HUD law to the
  shipped bottom-bar decision (recommended), or move Shop back. *(Surfaced 2026-06-15 — second-pass
  audit §13.)*

- **Flag registry index missing — `FEATURES.md` absent, flags lack Eval (spec done · process).** §11:
  every flag notes *Lives-in* (code site) + an *Eval* (keep/improve/cut verdict); the registry is the
  index of everything added. **Code:** `features.gd:2` points to a `FEATURES.md` that doesn't exist
  (find-clean); flags carry one-line comments but no structured Lives-in / Eval, and the
  core-non-flaggable set (`gate_pause`, `spot_level_gates`) isn't indexed. **Build:** create
  `FEATURES.md` (Lives-in + Eval per flag + the core list), or fix the stale header. *(Surfaced
  2026-06-15 — second-pass audit §11.)*

- **Juice verb-name drift (spec done · doc reconciliation).** §12 names the verbs "called by name," but
  the engine implements the motions under different names: `wiggle`→`FX.wobble`, `floater`→
  `FX.floating_text`, `press`→`skin.add_press_juice` (not FX), `hop`/`ambient_bob` in `ambient.gd` (bob
  inlined at `ambient.gd:69`, no callable verb). The motions all exist; only the named-verb surface
  deviates. **Build:** reconcile the §12 vocabulary table to the actual call names (or rename in code).
  *(Surfaced 2026-06-15 — second-pass audit §12.)*

## Parked — per-zone generators: art + tuning (the remaining tail of T17–T20)

- **Economy tuning + pacing sign-off (§3 · §7 · sim).** The §7 generated-quest economy is **live and
  sim-green on the invariants** (T19: no-jam · no-strand · I2 steady-state <30% · selling-not-income).
  What remains is the **feel/pacing call the sim can't make:** the provisional `grove_data.gd` quest
  tunables (`STAR_CAP`, `CLICK_TO_VALUE`, `QUEST_LEVELS_PER_TIER`, `GATE_TIER_BASE`/`GATE_ASK_COUNT`,
  featured rate) await the **owner's pacing sign-off**, and the §3 `LEVEL_STARS` curve is **untouched +
  available to recalibrate** (steady-state I2 was carried by the §7 tier knob, so §3 didn't need to move
  — but it's the lever if leveling should be faster/slower). Best judged once the art (below) makes it
  playable; re-validate any change through the Monte-Carlo sim (`games/grove/tools/grove_sim.gd`).
  **Folded in here (owner 1a, 2026-06-15):** the two energy-faucet code-changes from the (now-built)
  burst item — **level water gift +20 → +50** (`grove_data.gd` `LEVEL_WATER_GIFT`, applied on level-up)
  and **free refills 3-lifetime → 1/day** (today a monotonic `refills_used` vs `FREE_REFILLS`; needs a
  per-day date, not a lifetime int) — both tension the energy faucet against the <30% self-sustain rule,
  so they ship **with** this rebalance, not before. **Burst front-loading (T23, 2026-06-15):** burst-pop
  **front-loads energy spend** into the first map (a tap throws a whole burst, so the bot over-pops when
  starved), leaving low-volume early maps a high fixed-gift ratio on some seeds — so the sim now treats
  **maps 1–2 as WARN** and hard-checks **maps 3+** (was map-1-only); this pass must rebalance the gift
  cadence against burst's front-loaded spend **and** the +50 change above. **The §4 `MIN_LEVEL` gradient
  (T24, 2026-06-15):** the shipped table is strand-safe + I2-clean, but level-gating **~halves pace** vs
  the old tier-ring (30d sim: stars ~halved, maps 4–5/5 → 2/5) and caps the early FTUE at **2 free cells
  until L2** (at L1 nothing is openable). A softer gradient (inner ring → L1) recovers the pace
  (sim-validated) but **over-feeds the water gift → breaks I2** — so tune the gradient **jointly with
  `LEVEL_STARS` + `LEVEL_WATER_GIFT`** here, re-validating **both no-strand AND I2** on the sim. **⚠️ NEW — integrated
  `main` JAMS on seed 123 (surfaced 2026-06-15, T25 re-validation):** burst × level-gating combine to a HARD jam
  (not just slow pace) — the bot earns 5★ on day 1 then is stuck at L1 on the 9-cell board (nothing openable until
  L2), burst floods it, and it never recovers (90 jams / 30d, faucet 0). **Each branch passed in isolation; the
  parallel-merge reconcile (`c0a3acd`) never re-ran the sim on the combined `main`**, so it slipped in. This is the
  same gradient-vs-faucet tension above, now a strand — it is the strongest argument for opening the inner ring at
  **L1** (T24's recommendation). Fix belongs to THIS joint pass, not the burst-reprice (T25, which is neutral to it —
  map-1 burst is unchanged by the decouple). *(Was the
  "Economy rebalance under per-zone generators / #4" item — it folded into §7's tuning. Surfaced
  2026-06-15 — T17 sim findings; §7 cutover T19; faucet + burst front-loading folded in T23; the §4
  MIN_LEVEL gradient added T24.)*

- **Grove v1 art — ~192 item sprites + 12 generators (§16 LLM pipeline) — ⚠️ large.** The v1 home-grove
  content roster (T20) is authored as DATA; its lines render **code-drawn** until the sprites land.
  **Build (art):** the **24 lines × 8 tiers (~192) item sprites + 12 generator sprites** (maps 1–5,
  Farmhouse · Barn · Pond · Orchard · Meadow) via the §16 pipeline — tier-readability law (steps in
  size + silhouette, ~100 px), a shared per-line motif. (The full 15-map arc ≈ 832 sprites is
  post-launch.) **+ a small engine follow-up** (per-zone item #3): keep the `seed_satchel` anchor live +
  askable past map 1 on a **cold load** (`seed_gens` / `lines_for_zone`) — it already persists in live
  play via the hand-in flow. *(Surfaced 2026-06-14; data built T20 2026-06-15.)*
