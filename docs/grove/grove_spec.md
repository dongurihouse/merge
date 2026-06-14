# Ghibli Grove

> The **grove instantiation** of `merge_core` — the cozy "merge-to-restore" engine dressed as a hand-painted anime pastoral. This doc carries *only* the grove's specifics (names, content-tied numbers, theme, look) and references the core pattern each one instantiates. Read alongside `../core/merge_spec.md`; where this doc and the code disagreed, the **code won** (verified against `main`, 2026-06-14).

---

## 1 · The Grove Fantasy

*Instantiates Core §1 (Concept, Pillars & Core Loop).*

**Tidy Up** (working title; *Donguri Merge* is the brand pass) dresses the core merge-to-restore loop as **"Ghibli Grove"** — a cozy long-term **cultivation companion**. The player tends one persistent **garden clearing**, feeds it from a **water-gated seed satchel**, and forest neighbors consume their harvests into **Stars** that visibly restore a five-zone **homestead** — farmhouse, barn, pond, orchard, meadow.

> **One-sentence fantasy:** one persistent merge board, fed by a water-gated generator, where forest neighbors consume your harvests into Stars that visibly restore the homestead.

The core reframe **"merging is building"** instantiates here as **"merging is *growing*."** The grove's noun map onto the core's abstract slots:

| Core abstraction | Grove instance |
|---|---|
| working clearing (board) | a **garden clearing** |
| themed resource (energy) | **Water 💧** |
| theme objects that emit lines (generators) | **seed satchel · compost bin · beehive** |
| growth/production lines | **Wildflower · Berry · Mushroom · Honey** (seed → sprout → … → harvest) |
| themed obstacles | **bramble patches** |
| themed quest-givers | **forest animals** — fox, hedgehog, owl |
| the spend surface | the **homestead map** (5 sequential zones) |
| ambient life | **spirit-folk** wandering each scene |

The core pillars carry verbatim, and the grove **adds Cozy** of its own — "a relaxing *renovation* companion" (resentment lives only on Water). It also names **Visible progress** as **Visible *renovation*** — the homestead restores in place.

**North-star (Core §1) — grove definition of done (v1):** a brand-new player learns the merge verb wordlessly, delivers harvests to **forest neighbours** for Stars, restores the **homestead** spot-by-spot, and reaches a **zone-restored reveal feeling earned** — on sim-validated numbers, corruption-safe save, all strings via `tr()`, Calm Mode from launch, audio that degrades gracefully.

**Scope (v1) = Map 1 only** — the Grove's five sequential zones served by **one** persistent board; the next map comes only after this one is fully restored. **Permanently cut (tone):** gacha/mystery crates, booster-forfeits-star, and the Bomb/×2/Producer/Countdown toys (only the Wild piece ships). **Deferred backlog:** all "lux" juice (dissolve/iris/morph shaders, pets beyond earned animals, tilt parallax, time-of-day, seasons, photo mode, XL fanfares, combo ladders), idle/offline income, runtime solver, endless/expert tracks, stars-as-currency, cloud-save + analytics, notifications.

---

## 2 · Item Lines & Generators

*Instantiates Core §4 (Generators & Item Lines).*

**Four lines**, the core's exponential **8-tier** ladder each (t8 ≈ 128 t1-equivalents, a rare trophy). Codes `line*100 + tier`; art auto-loads `assets/items/<base>_<tier>.png`:

| Line | Name | Base | Color |
|---|---|---|---|
| 1 | Wildflower | `flower` | `#D98BA3` |
| 2 | Berry | `berry` | `#7FB4D9` |
| 3 | Mushroom | `mushroom` | `#C9A66B` |
| 4 | Honey | `honey` | `#E3B23C` |

The tier ladder reads as the growth metaphor: **seed → sprout → sapling → bloom → harvest** up the line. Tier-readability law (Core §4) holds: tiers step in size + silhouette, readable at ~100 px.

**Generators** (Core §4 — the complexity curve, revealing at scripted chapters, `chapter ≥ appears_at`):

| Generator | Cell | Lines emitted | Appears at chapter |
|---|---|---|---|
| **Seed satchel** | (4,3) | 1 Wildflower, 2 Berry | 0 (start) |
| **Compost bin** | (2,1) | 3 Mushroom | 16 |
| **Beehive** | (6,5) | 4 Honey | 26 |

The **coin pseudo-line** (Core §4): the currency *is* the **acorn** — code `9xx`, 3 tiers worth 1 / 5 / 25, tapped to collect, ~10% merge-drop rate (engine `COIN_DROP_RATE` default).

All board, water, FTUE-free-pop, and pop-odds constants are **core defaults** (board 7×9 with the center 3×3 open around the satchel at (4,3); `WATER_CAP 100` / `POP_COST 1` / +1·120 s regen; first 10 pops free; `TIER_ODDS [0.65,0.25,0.09,0.01]`, `ASK_WEIGHT 0.6`) — see Core §2–4. Grove cell size defaults to **86 px** (`GAP 10`, `MARGIN 12`).

---

## 3 · The Five Zones (the spend surface)

*Instantiates Core §8 (The Spend Surface) and Core §7 (the chapter/level/rank tables).*

The homestead is the core's **one large free-pan top-down map** — grove size `MAP_SIZE = 2160×2880` (2× the portrait viewport per axis). Locked zones render greyed-out in place and **unlock sequentially**; tapping an unlocked zone walks **inside a full-screen interior room** (the core `interior_view`) where spots live as **floor-standing furniture**.

**Five zones, 8 spots each, each spot 3–5★ — 176★ across 40 spots** (code-verified per-zone totals):

| Zone | Map id | Spots | ★ total | Interior unlocks (examples) |
|---|---|---|---|---|
| 1 Farmhouse | `farmhouse` | 8 | 31★ | Storage chest, Quilted bed, Oak table, Braided rug, Framed painting |
| 2 Barn | `barn` | 8 | 34★ | Hay bales, Milk churns, Hen coop, Old plow |
| 3 Pond | `pond` | 8 | 36★ | Little dock, Lily pads, Rowboat, Willow, Firefly jar |
| 4 Orchard | `orchard` | 8 | 37★ | Apple rows, Cider press, Beehives, Scarecrow |
| 5 Meadow | `meadow` | 8 | 38★ | Wildflower path, Kite, Brook bridge, Stargazer, Rose arch |

### The per-zone difficulty ramp (instantiates Core §6's deterministic ramp)

The required single-ask path is the byte-for-byte affordability-proven curve; **multi-line stretch quests are pure additions** (slack grows to cover them), always skippable, paying 2–3★. A freshly debuted line eases in at **≤ t3** for its debut zone; **t8 is never a quest ask** (the sold-only diamond pinnacle):

| Zone | Tier band | Quests/ch | Slack | 2-count cadence | Stretch | 💧 on spot-buy |
|---|---|---|---|---|---|---|
| 1 Farmhouse | t2–t4 | 5 | 1 | — | 0 | 0 |
| 2 Barn | t3–t5 | 5 | 1 | — | 0 | 0 |
| 3 Pond | t3–t5 | 5 | 1 | every 3 | 1 (2-line) | 0 |
| 4 Orchard | t4–t6 | 5 | 1 | every 2 | 1 (3-line) | 4💧 |
| 5 Meadow | t5–t7 | 6 | 2 | every 2 | 2 (2-line + 3-line) | 5💧 |

Bands climb and stretch density grows zone over zone, so the late game is **juggling all production lines on one board** (Core §6).

### The givers (instantiate Core §6's fence)

Grove quest-givers are **forest animals** (fox, hedgehog, owl) over the full-width **fence** — up to 5 stands at once, plus the **Market Squirrel** (the merchant) pinned at the right. The quest shape (1–3 asks → 1–3★, all-or-nothing delivery) and the **soft star-gate** (`gate_pause`) are core; the grove keeps the one hard rule (no-strand: level-gated spots never count as the affordable frontier).

### Chapter / level / rank (instantiate Core §7)

`chapter = unlocks.size()` (+1 per spot bought); EXP per spot is `cost × 10` (`EXP_PER_STAR`), i.e. **+30–50 EXP per spot** over the core thresholds `LEVEL_XP = [0,60,140,240,360,500,660,840,1040,1260]`. The level gate is `level_for_exp(30 × rank)` — the grove's spots run rank 0…39 across the five zones, and the pigeonhole guarantee (Core §7) holds (sim-proven, 0 strands). Each level-up gifts the core energy gift (**+20💧**, Core §3) plus **+3💎** (`LEVEL_DIAMONDS`); **fully restoring a zone grants +10💎** (`ZONE_DIAMONDS`) with a celebration and unlocks that zone's wayside plots.

---

## 4 · Grove Economy Specifics

*Instantiates Core §10 (The Economy) and Core §9 (Selling & the Merchant).*

The 4-currency model (Water / Stars / Coins / Diamonds) and **sink > faucet** law are core. Grove faucet/sink details:

| Currency | Grove earn additions | Grove spend |
|---|---|---|
| **Water 💧** | the **Rain ☔** button (3 free refills), win-back ("it rained"), zone 4–5 spot-buys (4–5💧) | 1 per pop; refill **25💎 → full** |
| **Stars ★** | quests only (1–3★) | restoration spots (3–5★) |
| **Coins 🪙 (acorns)** | merge drops (~10%) · selling t1–t7 · Shop **5💎→150🪙** | waysides · spot variants · spirit treats · basket buy-back |
| **Diamonds 💎** | level-ups (+3) · zone restore (+10) · selling a t8 (+1) · cash packs (test-only: $0.99→80💎 / $4.99→450💎 / $9.99→1000💎) | Water refill (25💎) · Bag slot 3 (10💎) · gem variants (2–4💎) |

### The Merchant (instantiates Core §9)

The **Market Squirrel** runs the stall. Sell reward and the **32× no-arbitrage invariant** are core (t1–t7 → 1…7🪙; t8 → 1💎, no coins). The grove's buy-back valve is a **wicker basket** at the squirrel's feet (`BASKET_CAP = 3`); a 4th sale overflows and summons the **porter spirit**, who also sweeps the basket every `PORTER_SECS = 180`. Basket never persisted.

### Coin sinks (the live grove — Core §10 instantiation)

Every live coin sink is cosmetic or net-zero utility:

| Sink | Cost | Capacity | Flag | Value |
|---|---|---|---|---|
| **Wayside plots** | 40🪙 + index·6 → **40–154🪙** | 20 plots (4/zone) ≈ **1,940🪙** | `wayside_decor` | pure cosmetic — map decoration |
| **Spot variants** | 25🪙 + zone·15 + (k%3)·5 → **25–95🪙** | 40 spots ≈ **2,375🪙** | `customize_variants` | pure cosmetic — furniture tint |
| **Spirit treats** | **10🪙** (an acorn treat) | endlessly repeatable | `spirit_treats` | pure cosmetic — a spirit hops |
| **Basket buy-back** | the exact 1–8🪙 paid | per sale | — | utility — recover a mis-sold item (net zero) |

A plot is dormant (greyed) until its zone is fully restored, then shows a coin-cost pin; buying is **coin-only, never level-gated, in no unlock chain**. **Faucet vs sink:** lifetime coin faucet ≈ **1.5–2.2 k** (merge drops + selling); the cosmetic sinks (~1.9 k waysides + ~2.4 k variants) exceed it.

> **The grove's instance of the core "coins have no power" tension (Core §10).** Every live coin sink is cosmetic or net-zero — the numeric sink exceeds the faucet so coins don't visibly overflow, but the **motivation to spend is thin**: a player buys waysides only as a decorator/completionist, and the plots sit at provisional, low-visibility map positions. A real soft spot worth a design pass (a collection/progress hook, a functional-but-not-speed coin use, or making the decorated map *matter*). *(A coin-gated progression sink — bedroom decor, 663🪙 — exists only in the **legacy** `districts.gd`/`room.gd` "Tidy Up rooms" code, not the live grove loop.)*

The grove's **brambles** instantiate Core §5's ring-scaled obstacles; the late-line edge gates (Core `bramble_line_gates`) are: ring ≤2 → any line t2, ring 3 → any line t4, ring 4 (edge = endgame) → **t5 of Mushroom (top half) / Honey (bottom half)**. The star track completes with ~14 edge brambles left as tail content.

---

## 5 · The 25 Feature Flags

*Instantiates Core §11 (the feature-flag system).* Every flag is a `static var` bool in `scripts/features.gd` (unknown id → `true` + warning); **all 25 default ON**. *Eval* = the owner's keep/improve/cut verdict, filled during testing.

| Flag | Group | What it does | Lives in |
|---|---|---|---|
| `idle_hint` | assist | ~4.5 s idle → a mergeable pair rocks (±6°); re-nudges ~4 s | `grove.gd:_hint_pair` |
| `discovery_ladder` | assist | tap an item → upgrade-path card; unseen tiers show "?" | `grove.gd:_open_ladder` |
| `quest_ready_check` | assist | green ✓ badge on a giver's ask when payable | `grove.gd:_refresh_giver_lights` |
| `sell_hints` | assist | drag → stall brightens + "+N🪙" tag; first max-tier one-time sell hint | `grove.gd:_show_sell_affordance` |
| `gen_preview` | assist | locked generators show a greyed silhouette + "after N spots" | `grove.gd` (gen cells) |
| `breathe_cta` | juice | the ONE suggested next action breathes (max one on screen) | `FX.breathe_once` sites |
| `press_juice` | juice | buttons squash 0.96 in / overshoot 1.03 out | `Look.add_press_juice` |
| `wallet_tick` | juice | wallet numbers count up + chip pulse | `hud.gd` / `FX.tick` |
| `fly_to_wallet` | juice | a grant arcs an icon to the wallet chip | `FX.fly_to_wallet` |
| `scatter_in` | juice | staggered pop-in for card/section groups | `FX.scatter_in` |
| `floaters` | juice | outlined drift-up feedback text | `FX.floating_text` |
| `celebrate_bursts` | juice | particle bursts on merges/buys/restores | `FX.burst` / `celebrate_at` |
| `spirit_tap_hop` | juice | tapping a map spirit hops it | `ambient.gd` |
| `giver_bob` | juice | frameless fence givers idle-bob (±3 px, ~3 s) | `grove.gd` (fence) |
| `porter_collect` | juice | a porter spirit drifts in to clear the sell basket | `grove.gd:_porter_collect` |
| `winback_rain_beat` | ambient | ≥48 h away → full Water + a one-time "it rained" minute | `grove.gd:_load_state` |
| `ambient_spirits` | ambient | spirit folk wander; count = 1 + restored zones (cap 5) | `ambient.gd` |
| `ambient_weather` | ambient | hourly clear/breeze/rain/snow; respects calm | `ambient.gd` |
| `wayside_decor` | feature | coin-priced cosmetic map plots (the structural coin sink) | `home.gd:_make_wayside` |
| `spirit_treats` | feature | a 10🪙 acorn treat at the stall; a spirit scurries + hops | `grove.gd:_buy_treat` |
| `customize_variants` | feature | owned spots offer coin/gem looks via a swatch strip | `home.gd:_apply_variant` |
| `item_backing` | feature | a soft warm contact shadow under each board piece | `grove.gd:_make_piece` |
| `drag_swap` | feature | drop on another occupied cell → swap (merge keeps precedence) | `grove.gd` / `grove_board.swap` |
| `ftue_free_pops` | ftue | first 10 pops free + uncounted; Water meter appears after | `grove.gd:_pop_seed` |
| `ftue_staged_chrome` | ftue | merchant from ch1, bag from ch2, water chip after intro | `grove.gd` |

**Core (indexed, NOT flaggable — Core §11):** `interior_view` (`home.gd:_open_interior`) · `bramble_line_gates` (`grove_content.bramble_gate`) · `gate_pause` (`grove.gd:_active_quest_idx`) · `spot_level_gates` (`G.spot_level_req`). **Numeric dials** (`TIER_ODDS`, `ASK_WEIGHT`, `COIN_DROP_RATE 0.10`, `POP_COST`, idle/re-nudge 4.5/4.0 s) live in `grove_content.gd` / `grove.gd`.

*(The T14 flags — `slot_ghost`, `place_pop`, `zone_reveal`, `zone_crowd` — live on `feat/farmhouse-alive`, not yet on `main`; see §10.)*

**Removed / retired** (history, so we don't re-litigate): on-map open-state scatter → zone interiors; zone-chest "lid opens in place" + scattered price pins → zone interiors; centered customize modal → inline swatch strip; emoji-glyph UI → the sprite icon kit (the "emoji purge").

---

## 6 · The Alive Layer

*Instantiates Core §12 (Juice Vocabulary).* The juice **verbs** are core (`press`, `pop_in`, `scatter_in`, `fly_to_wallet`, `tick`, `wiggle`, `breathe`, `hop`, `ambient_bob`, `floater`) — implemented once in `FX` / `Look`. The grove dresses the **alive systems**:

- **Spirit-folk** are the grove's ambient figures — count = 1 + restored zones (cap 5); tap → `hop`.
- **The porter spirit** drifts in for the sell basket (Core §9 / §12).
- **Weather** runs hourly (clear / breeze / rain / snow), respecting Calm Mode.
- **Win-back** is the "it rained" beat (≥48 h → full Water + a one-time minute).

Intended feel (core): **"floaty, breezy, settling."** **Calm Mode** (Settings) halves particles and disables `breathe`.

---

## 7 · Look & Feel — the Grove UI Kit

*Instantiates Core §13 (UX Principles).* One holistic kit (`scripts/skin.gd`, "Look"), code-drawn fallbacks, the five UX laws (diegetic-first, one kit, art-carries-shape/engine-carries-text, ships-twice, juice-is-vocabulary) — all core. The grove's specifics:

**Diegetic surfaces** are grove materials: true overlays are **parchment, planks, leaves** (never flat lists). Three nine-patch elevations: Ground band `panel_plank`, Card `panel_parchment`, Chip `panel_chip`.

**Text law (grove font):** one bundled rounded font `assets/fonts/ui.ttf` (**Baloo 2 SemiBold**); outline = text over the world, no outline = text on a panel (never both). Sizes at the 1080-wide base: titles 40–44, body 26–30, numbers 30–34 (always beside an icon), captions 21–24, floaters 30–38.

**The icon canon (the emoji purge)** — every glyph a 256 px sprite via `Look.icon(id, px)`:

| Icon | Grove form |
|---|---|
| `icon_star` | a five-petal **Bloomstar** |
| `icon_coin` | a golden **acorn** — the currency *is* the acorn, no metal disc |
| `icon_gem` | a **dewdrop** |
| plus | water / rain / cart / gear / check / lock / home / back / level |

**Palette:** Meadow `#7FA65A` · Deep leaf `#3F6B43` · Straw gold `#E3B23C` · Sky `#9CCDE8` · Cream `#FBF3EA` · Warm bark `#8A5A3B` · Clay red `#C96F4A` (sparingly) · Ink `#33402F`. Board chrome is cream-on-leaf with bark borders.

**HUD law (grove canvas):** the core HUD law (Core §13) on a base **1080×1920 portrait, portrait-locked** canvas — the top bar sits at `safe_top+16`, the scene chip is Lv / 💧, nothing else in the top **160 px** band; safe areas via `Look.safe_top/safe_bottom`. The board fills phone width edge-to-edge and height-binds + centers on iPad (side terrain is correct).

**The storefront (Core §13):** the Shop is a **market stall** with a banner, wallet strip, and a 3-up card grid; unaffordable cards desaturate but stay pressable (→ wiggle + "Need N more"). It sells Water (25💎), Coins (5💎→150🪙), and cash→diamond packs (test popups).

**FTUE (Core §14):** staged — `ftue_free_pops` (first 10 pops free/uncounted, Water meter after) + `ftue_staged_chrome` (merchant ch1, bag ch2, water chip after intro).

---

## 8 · Art Direction (Direction F — "Ghibli Grove")

A hand-painted anime pastoral; the style is the hook (visible handcraft against the genre's glossy-3D baseline). Hard requirements: tiny-icon readability (tiers read at ~100 px), pipeline-reproducibility (fixed style suffix + locked palette), cozy warmth. Never name a style or IP — the look lives in ingredients.

**Style core (locked, appended verbatim to every prompt):**

> hand-painted anime film background style, soft gouache and watercolor texture with visible brushwork, gentle diffuse summer daylight, warm nostalgic pastoral palette of meadow green, straw gold and clear sky blue, towering soft cumulus clouds, atmospheric haze in the distance, wind-blown grass, painterly cel-shaded subjects with clean simple line work, no photorealism, no glossy 3D render, no text

Saturation lever: if it reads "digital anime wallpaper," add `muted vintage film colors, slightly faded`.

**Per-asset-class:** *Items* 512² on solid white, chunky silhouette, one warm rim light, shared soil/pot motif per line, tiers step in size+silhouette. *Generators* like items but "openable/giving," larger presence. *Brambles* read as board texture (no rim light, low saturation), 3 densities. *Busts* "friendly round [animal] from the chest up," one accessory each. *Scenes* opaque — vistas wide with haze, board backdrops tall portrait with a calm low-contrast center (under a 60% scrim). *Zone interiors* are 3:4 painted rooms with their **surroundings painted in** (garden/grounds — never a plain-white bleed); furnishings are **floor-standing**, with **at most ONE flat wall picture** per room (no shelves, sills, or wall-hung clutter). *Unlock layers* same-canvas transparent cutouts at identical position/scale.

**Juice restyle:** every effect becomes a meadow thing, palette-only — petal/leaf/pollen puffs (not rainbow dots), sun-dapple bloom (not gold flash), ink-brush lettering on cream chips (not neon shouts), water ripple rings, hand-painted wobbly straw-gold stars. Motion is *floaty, breezy, settling*.

> **Zone-art pipeline:** a single coherent render harvests the empty background, each object as a clean transparent cutout, **and** each object's placement box in one pass (the box you cut from *is* its position; round-trip reconstruction is the correctness check). Object ids match the `scripts/grove_content.gd` spot ids; in-game zone canvas **1084×1451** (≈ 3:4). Full runbook: the reusable `../core/ZONE_GEN_PIPELINE.md` (a core production method).

---

## 9 · Audio Direction

**A small acoustic ensemble in a sunlit field** — nylon guitar, felt piano, wooden flute, light strings, brushes; birdsong and leaves under everything. Pentatonic, **one shared key (C / A-minor pentatonic)** across music *and* SFX so no cue sounds sour over the bed. **Water sounds for water verbs, wood for UI.** Nothing electronic, nothing casino.

- **Music is near-ambience, not songs:** one continuous bed at the edge of hearing — slow, sparse, one instrument (+ a faint pad), long silences, **no beat, no melody, no build-ups**. The game alternates two interchangeable takes (`amb_grove1/2`) forever. *Acceptance:* at low volume, if you can tap a foot, hum a tune, or count >1 instrument, re-roll.
- **SFX** are forest one-shots — leaf-brush flicks, moss thumps, a water *plip* for pops, twig-snap for bramble clears, songbird trills for cheers. Mono 44.1 kHz `.wav`, ≤0.6 s, peak ≈ −3 dBFS. Music is stereo `.ogg`, seamless, −16 to −14 LUFS, under the SFX.

Engine file names are unchanged (`merge_soft.wav`, `level_complete.wav`, `amb_grove*.ogg`…) — new takes drop in with zero code changes.

---

## 10 · Current State & the T14 Branch

*Instantiates Core §15 (Tech, Build & Save).* Engine constants and patterns (Godot 4.6, no autoloads, JSON save with deep-merge + atomic write, the Makefile/headless-suite/quiet-godot/economy-sim infra) are core. Grove specifics:

**Code map.** `board.gd` = pure rules engine (tests) · `grove_board.gd` = persistent board model · `grove.gd` (~86 KB, the live board) + `home.gd` (~63 KB, the homestead map) drive the loop · `grove_content.gd` = item lines, generator policy, quest script, zone/wayside/sell data · static singletons `save.gd`/`features.gd`/`econ.gd`/`layout.gd`/`hud.gd`/`shop.gd`/`skin.gd`/`audio.gd`/`music.gd`/`ambient.gd`/`fx.gd` · legacy `districts.gd`/`levels.gd`/`jobs.gd`/`room.gd`/`main.gd` from the earlier "Tidy Up rooms" framing (not the live grove loop). Main scene `scenes/Home.tscn`. Save `SCHEMA_VERSION = 2`; the `grove` save blob persists board · bag · `qdone` · `unlocks`(=chapter) · `custom` variants · `seen` hints · `pops` · `waysides` · rng/chapter. iOS bundle `com.dongurihouse.dongurimerge`. Headless suites: `core_tests`, `grove_tests` (~297 asserts), `layout_tests`, `map_tests`, `quest_tests`, `save_tests`, + `smoke`; economy bot `tools/grove_sim.gd` (default + greedy). The Makefile also wraps the grove art-processing targets `decor` / `icon` (raw → processed sprite) alongside the core-generic run/test/import/shot/ios targets (Core §15).

**Built and verified** (headless asserts + the economy sim, never eyeball): the persistent board with drag-any-to-any merging + the tap-the-satchel generator; the soft star-gate; multi-line stretch quests scaling per zone (t8 never asked); the selling economy (t1–t7 → coins, t8 → 1💎, the 32× no-arbitrage invariant, the 3-slot buy-back basket + porter); 2+ coin sinks (20 waysides, spot variants, the 10🪙 treat); and **all five zone interiors wired and rendered** (32/32 furniture sprites, hole-punched clean). The sim passes **40/40 spots, 0 jams** in both default (day-4) and greedy (day-7) bot modes.

**Open / owner's judgment** (perceptual calls the asserts can't make): the difficulty *feel* of stretch quests; on-map wayside + interior furniture placements are **provisional** pending the drag-to-place editor (notably the meadow bridge `md_brook`, which renders on grass, not on the baked brook); the motion/feel of the porter drift, sell tags, and spirit treats.

> **In flight — branch `feat/farmhouse-alive` (T14, not yet on `main`).** The unlock *moment* is reworked: empty slots **ghost-preview** the furniture (`slot_ghost`), a bought piece **settles into place** with the burst on the object + its style strip auto-opens (`place_pop`), completing a zone plays a fuller **flourish** (`zone_reveal`), and restored zones get **crowded with spirit-folk** in the yard + inside the room (`zone_crowd`). Also fixes a one-buy-per-visit bug (`spot_hits` cleared after the interior rebuilt). Awaiting the owner's eye on feel. The working tree also carries uncommitted experiments around a frame/cutout pipeline (`tools/cutout_frames.gd`, `scenes/frame_test.*`, `scenes/place_test.*`) and `../core/ZONE_GEN_PIPELINE.md`, not yet landed.
