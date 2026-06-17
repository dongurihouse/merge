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
