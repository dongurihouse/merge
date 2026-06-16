# Backlog — parking lot

Deferred / discovered work, parked as one-liners with enough context to pick up cold. This is a
**parking lot, not a worklist**: the Dev decides what's pulled next; nothing here is "in progress."
On pickup, an item becomes a `T#` task in [`TASKS.md`](TASKS.md). Format + rules:
`~/.claude/docs/engineer.md`.

Most items trace to the **engine-wide `merge_spec` audit (2026-06-14)**. Since shipped and dropped
from here: the generator + quest core (T17–T20), the map model + `zone`→`map` sweep (T21, T38), the
burst sink + level-gating (T23–T25, T37), and the **selling bands + Shop buy-sinks + bag 6→18 model
(T39–T41, parallel worktree batch 2026-06-15)**. Code anchors are `file:line` and **drift** — after the
`core/ui/scenes` layering split many paths moved (`content.gd`→`core/content.gd`, `board.gd`→
`scenes/board.gd`, `shop.gd`→`ui/shop.gd`); trust the symbol name over the line number.

---

## Open — core loop

- **Map model — real §16 map images + on-image spot placement (art lane · owner).** The tail of the single-image-map rework (model T21; the `zone`→`map` rename + orphan-sprite cleanup shipped T38). **No engine gap** — the map view auto-wires `assets/map/map_<id>.png` (`map.gd` `_open_map`) and the Layout editor places spots on the image; this is **art + owner action**: generate the §16 per-map backgrounds (same pipeline as *Grove v1 art*, below), then re-place each map's spots via the Layout editor. `data/placements.json` was wiped to a clean slate (T38, owner call — `layout.gd` falls back to `grove_data` defaults), so re-placement starts fresh for **every** map. *(Pairs with the KEYSTONE hub loop below.)* *(T21 parked tail; (a)+(c) shipped T38.)*

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
  • **Part B — generator burst-upgrade (§6 board sink) — ✅ DONE (T23 mechanic + T25 on-board buy-pill UI +
  reprice/free-paid decouple).** A coin sink to pop more per tap; now absorbs **64–76%** of the coin faucet.
  *(Burst stays GLOBAL — per-generator parked. The seed-123 burst × level-gating jam it surfaced was **fixed in
  T37** — see the Economy-tuning item below.)*
  *This closes the soft-currency loop the rest of the economy hinges on — pair with the quest coin faucet +
  the shop sinks.* **Reworked 2026-06-15 (owner):** hub-concentrated (the hub carries the loop, **not every
  building on every map**). **Parked (owner 2026-06-15):** **per-map yield** + **cross-map feed-forward** — a
  collect-across-~10-maps chore; home hub + live-ops in old maps (§17) carry anti-abandonment. *(Surfaced
  2026-06-14 — code audit; anchors re-verified + A/B split + deps added 2026-06-15, T22 pickup; Part B burst
  mechanic merged 2026-06-15, T23.)*

- **Shop cosmetic LOOKS — apply the owned look to the board/map render (small follow-up · T40).** The
  Shop now sells cosmetic looks (T40 — `SHOP_COSMETICS` in `grove_data.gd`, unlock stored in
  `grove()["cosmetics"]`), but the chosen theme is **granted-and-owned only — not yet applied** to the
  board background / map render. **Build:** read the owned cosmetic in the board/map view and swap the
  look. *(Surfaced 2026-06-15 — T40 parked tail.)*

- **Rewarded ads + the live-IAP surfaces (spec done · engine code · grove).** Core §4/§10 now:
  **IAP is live from launch** (real cash→💎, geo-flagged — supersedes the old "dark / earned-only"
  language; the stale "no IAP wired" header was corrected in T40), plus **rewarded ads**
  (rewarded-only, capped, geo-flagged: refill energy / 2× build-yield collect / free shop reroll /
  event top-up), a **starter pack + first-purchase doubler**, and a **full price ladder incl.
  $49.99/$99.99-class tiers** (replace the placeholder $0.99/$4.99/$9.99 set). **Build (engine):** an
  ad-SDK + the rewarded surfaces + caps; live-IAP store + receipt validation behind the geo flag.
  **Build (grove):** the real pack ladder + starter pack, ad caps/cooldowns/reward sizes. *Pairs with
  the shipped Shop sinks (T40); also retire "even while dark" in the analytics item.* *(Surfaced 2026-06-14 —
  director review.)*

- **Monetization surfaces — piggy bank, triggered offers, daily login calendar (spec done · engine code · grove).** §10/§18: a **piggy-bank accrual vault** (skims earned premium → crack for one fixed cash price), **triggered "out-of-Water" offers** (state-fired at the energy wall, distinct from the rotating Shop), and a **forgiving daily login calendar** (escalating streak, no day-1 reset). **Vault / trigger / login all absent** — the Shop now *rotates* offers (T40) but has no accrual vault, no state-triggered offer (also waits on §15 analytics — absent), no login calendar. **Build (engine):** the vault skim+claim path; the state-triggered offer hook (keyed off §15 analytics); the login-streak model (respecting the §4 self-sustain invariant). **Build (grove):** skim rate + pig price, offer discount/caps, the streak ladder + milestones. *(Surfaced 2026-06-14 — director review.)*

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

## Parked — per-map generators: art + tuning (the remaining tail of T17–T20)

- **Economy tuning + pacing sign-off (§3 · §7 · sim) — owner feel call.** The §7 economy is sim-green
  on the invariants (no-jam · no-strand · I2 steady-state <30% · selling-not-income); the seed-123
  level-gating × burst strand is **fixed** (T37). What's left is the **feel/pacing call the sim can't
  make** — owner sign-off on the provisional `grove_data.gd` quest tunables (`STAR_CAP`,
  `CLICK_TO_VALUE`, `QUEST_LEVELS_PER_TIER`, `GATE_TIER_BASE`/`GATE_ASK_COUNT`, featured rate) and the
  joint **`LEVEL_STARS` + `LEVEL_WATER_GIFT`** curve. **Two faucet changes ride with this rebalance,
  not before:** level water gift **+20 → +50** (`LEVEL_WATER_GIFT`), and free refills **3-lifetime →
  1/day** (needs a per-day date, not the current lifetime `refills_used`). Best judged once the art
  makes it playable; re-validate every change on the Monte-Carlo sim (`grove_sim.gd`). *(T17 sim → T19
  cutover → T23 burst → T24 gradient → T37 strand fix.)*

- **Grove v1 art — ~192 item sprites + 12 generators (§16 LLM pipeline) — ⚠️ large.** The v1 home-grove
  content roster (T20) is authored as DATA; its lines render **code-drawn** until the sprites land.
  **Build (art):** the **24 lines × 8 tiers (~192) item sprites + 12 generator sprites** (maps 1–5,
  Farmhouse · Barn · Pond · Orchard · Meadow) via the §16 pipeline — tier-readability law (steps in
  size + silhouette, ~100 px), a shared per-line motif. (The full 15-map arc ≈ 832 sprites is
  post-launch.) **+ a small engine follow-up:** keep the `seed_satchel` anchor live +
  askable past map 1 on a **cold load** (`seed_gens` / `lines_for_map`) — it already persists in live
  play via the hand-in flow. *(Surfaced 2026-06-14; data built T20 2026-06-15.)*
