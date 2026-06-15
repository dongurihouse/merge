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

- **⭐ [P0] Home-hub yield + upgrade-levels loop — "coins get power" (spec done · code in progress (T22, Part A) · sim). KEYSTONE.**
  §8/§10: built things have **upgrade levels** (L1→Lⁿ — look better **and** pay back more) and
  **produce coins over time** (passive yield, collected on return, scaling with level, **capped** so
  it extends sessions, never self-sustains); coins then **sink** into those upgrades + generator
  burst-upgrades. **Today:** hub spots are **binary owned/unowned** — restore = `Save.spend_stars` →
  `unlocks[id]=true` (`engine/scripts/scenes/map.gd` `_on_spot_tap` ~`:957`; `spot_owned()` `:181` —
  the audit's `map.gd:977`/`:187` anchors are **stale** post layering-split), nothing accrues over time,
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
  + `hub_collected_at` + accessors + rename-migration in `save.gd`) DONE** on branch `feat/hub-yield` (T22),
  `save_tests` 32/0; A2–A9 queued behind T21.
  • **Part B — generator burst-upgrade (§6 board sink) — MECHANIC BUILT (T23, 2026-06-15).** A coin sink to
  pop more per tap. The **burst-popping** mechanic + its burst-upgrade spend path are now live (merged from
  `feat/burst-pop`): `board.gd` `_upgrade_gen_burst()`/`_gen_burst_level()` + the `BURST_UPGRADE_COSTS`
  ladder — a working coin sink, sim-modelled. **Remaining:** wire the **trigger UI** (a buy affordance on
  the hub surface), not the logic.
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
  so they ship **with** this rebalance, not before. **New input (T21, 2026-06-15):** burst-pop
  **front-loads energy spend** into the first map (a tap throws a whole burst, so the bot over-pops when
  starved), leaving low-volume early maps a high fixed-gift ratio on some seeds — so the sim now treats
  **maps 1–2 as WARN** and hard-checks **maps 3+** (was map-1-only); this pass must rebalance the gift
  cadence against burst's front-loaded spend **and** the +50 change above. *(Was the "Economy rebalance
  under per-zone generators / #4" item — it folded into §7's tuning. Surfaced 2026-06-15 — T17 sim
  findings; §7 cutover T19; faucet + burst-front-loading folded in T21.)*

- **Grove v1 art — ~192 item sprites + 12 generators (§16 LLM pipeline) — ⚠️ large.** The v1 home-grove
  content roster (T20) is authored as DATA; its lines render **code-drawn** until the sprites land.
  **Build (art):** the **24 lines × 8 tiers (~192) item sprites + 12 generator sprites** (maps 1–5,
  Farmhouse · Barn · Pond · Orchard · Meadow) via the §16 pipeline — tier-readability law (steps in
  size + silhouette, ~100 px), a shared per-line motif. (The full 15-map arc ≈ 832 sprites is
  post-launch.) **+ a small engine follow-up** (per-zone item #3): keep the `seed_satchel` anchor live +
  askable past map 1 on a **cold load** (`seed_gens` / `lines_for_zone`) — it already persists in live
  play via the hand-in flow. *(Surfaced 2026-06-14; data built T20 2026-06-15.)*
