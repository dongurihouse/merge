# Acorn & Bloom: Merge!

> **Acorn & Bloom** (working title) — the **grove instantiation** of `merge_core`, the cozy "merge-to-restore" engine dressed as a hand-painted anime pastoral. This doc carries *only* the grove's specifics (names, content-tied numbers, theme, look) and references the core pattern each one instantiates. Read alongside `merge_spec.md`; where this doc and the code disagreed, the **code won** (verified against `main`, 2026-06-14). **Naming (2026-06-15):** the spec now uses **map** for the single-image world unit (Core §8) — **the only structural unit, no episode/chapter tier**; the **code still uses `zone`/`ZONE_*`/`zone_reveal` identifiers** pending the `zone`→`map` rename (`BACKLOG.md`).

---

## 1 · The Grove Fantasy & Story

*Instantiates Core §1 (Concept, Pillars & Core Loop) and Core §7 (giver narrative arcs).*

**Acorn & Bloom: Merge!** (working title; *Acorn & Bloom* for short — the convention is *[Brand]: [hook]*, as in *Travel Town: Merge & Story*) dresses the core merge-to-restore loop into a cozy long-term **cultivation companion** — the **Grove** — wrapped in a **wordless spirit-world story** (*The story*, below). The player tends one persistent **garden clearing**, feeds it from a **water-gated seed satchel**, and the grove's **spirit-folk** consume their harvests into **Stars** that visibly restore a **homestead** — the first **place** of a wider spirit-world (farmhouse, barn, pond, orchard, meadow… **map count is a tuning call**, §3).

> **One-sentence fantasy:** a child crosses into a fading spirit-grove where her parents are turned into silent nature-spirits; she tends one persistent merge board — feeding a water-gated generator, delivering harvests to the grove's spirit-folk for Stars — to visibly restore the homestead, **free her parents**, and wake the great spirit whose grief dimmed it.

The core reframe **"merging is building"** instantiates here as **"merging is *growing*."** The grove's noun map onto the core's abstract slots:

| Core abstraction | Grove instance |
|---|---|
| working clearing (board) | a **garden clearing** |
| themed resource (energy) | **Water 💧** |
| theme objects that emit lines (generators) | **seed satchel · compost bin · beehive** |
| growth/production lines | **Wildflower · Berry · Mushroom · Honey** — the **starting** lines (the lifetime roster is **per-map**, §2, with **Wildflower the permanent anchor that never retires**) — each grows seed → sprout → … → harvest |
| themed obstacles | **bramble patches** |
| themed quest-givers | **humanoid produce/critter spirits** — Radish · Carrot · Frog · Bee · Morel (+ a rotating menagerie) |
| the spend surface | the **maps** — the **home grove** first, then a wider spirit-world; the **Farmhouse** is the home hub |
| ambient life | **tiny seed-sprites** wandering each scene |

The core pillars carry verbatim, and the grove **adds Cozy** of its own — "a relaxing *renovation* companion" (resentment lives only on Water). It also names **Visible progress** as **Visible *renovation*** — the homestead restores in place.

### The story (the spine — Core §7's giver-arc layer, made first-class)

A **wordless spirit-world** story carries the grove; per the **No-required-reading** pillar it is told entirely in **faces, gesture, image, and before→after** — never required prose.

**Premise.** A **child and her parents** stray across a mossy threshold into the grove — a **spirit-world** gone grey and quiet. The crossing **transforms** the parents into **silent humanoid nature-spirits**: **Acorn-dad** (sturdy, gruff-cozy) and **Flower-mom** (warm, expressive). They guide by gesture but **cannot speak**. To bring them back, the child **tends the grove to life**.

**World logic.** The grove greyed because the **great heart-tree spirit** at its centre — *forgotten* by the keepers who once tended it — slipped into a **grieving sleep**, and its dreaming magic gently *holds* whoever wanders in (no malice; a lonely, sleeping god). So **restoration is care made visible**: tending the grove tells the great-spirit it is loved again, and healing its grief is what **wakes** it.

**The progress bar made of love.** As each map restores, the **parents' transformation visibly eases** — Dad's shell cracks further open, Mom's bloom parts toward a human face — in **five big stage-changes, one per map**, under a **finer "thaw"** that stirs with every few spots restored, so the strongest signal is *always* visibly responding to play, not only five times. The home grove eases them to **nearly-whole and reunites the family** (the heart-tree waking is its payoff); their **full restoration is the pull onward** — the v1 cliffhanger (Scope, below). *(The rhyme: the currency **is** the acorn and the first line **is** the wildflower — the parents are made of the game's own materials, and the wildflower is the one line that **never retires** (§2) — the **title itself**, *Acorn & Bloom*, *is* the two of them, always with you.)*

### The cast

| Role | Who | Note |
|---|---|---|
| **The child** | you, the player | stays herself — the one who can still *work* (merge · deliver · restore) |
| **The guides** | **Acorn-dad** · **Flower-mom** | silent; teach the FTUE by gesture; their **easing transformation** is the emotional progress bar |
| **The givers** | the **named leads** — **Radish** (farmhouse) · **Carrot** (barn) · **Frog** (pond) · **Bee** (orchard) · **Morel** (meadow), one anchoring each map — **plus a rotating menagerie** of one-wish walk-ons (snail sage, dragonfly courier, plum-granny, a paper-lantern wanderer…) | one giver class (Core §7): all hand out quests at the fence — a named lead carries a map-long **wish**; the menagerie adds warmth + novelty (refreshed per map/event). Some quests are **featured** (highlighted) and pay a **bonus** |
| **The merchant** | **Market Squirrel** | the acorn-hoarder — runs the sell-stall (§5) **and keeps your acorn hoard-jar** (the piggy-bank vault, §5 / Core §10); fits the currency |
| **The peddler** | a **traveling peddler spirit** | the wandering outsider — brings **premium wares** (the Shop's rotating stock, Core §10) and passes by with a **waterskin** when you run dry (the triggered out-of-Water offer); distinct from the local Squirrel — **buying, not selling** |
| **The great-spirit** | the **heart-tree** | the sleeping, grieving guardian — and the **gatekeeper**: each map's **last** quest is its offering (a randomized handful of that map's top-tier harvest) that **unlocks the next map** (Core §7); waking it fully is the home grove's climax |
| **Ambient** | **tiny seed-sprites** | the spirit-folk that wake and crowd the grove as it heals (grove §7) |

### The commerce, dressed (diegetic — Core §13)

Monetization wears the world, never naked chrome (Core §13's diegetic law) — the buy-side surfaces are spirits and objects in the grove, so the cozy spell holds and the *gentle, non-predatory* positioning (below) reads true in the fiction, not just the tuning:

| Surface (engine) | Grove frame |
|---|---|
| **Shop** — packs · cosmetics · item-shortcuts (Core §10) | the **traveling peddler spirit's** pack — rotating wares |
| **Piggy bank** — accrual vault (Core §10) | the **Market Squirrel's acorn hoard-jar** — your savings, visibly filling |
| **Triggered out-of-Water offer** (Core §10) | the **peddler passing by with a waterskin** — help at the dry moment |
| **Daily login** (Core §18) | a **dawn-gift** a seed-sprite leaves at the gate each morning |
| **Share** (Core §17) | already diegetic — *capture the world you built* |

*(Rewarded ads (Core §10) stay a **plain, optional opt-in** — geo-flagged, deliberately not dressed into the fiction.)*

### The narrative architecture (built to extend)

Map-count **agnostic** — it scales to any amount of shipped content (the single-image-map model, Core §8). **The only structural unit is the map** — there is no episode/chapter tier; the story is simply a **sequence of maps**:

- **Map = a story beat.** One self-contained image (Core §8) — one lead giver's **wish** eased, one before→after reveal; its **last quest is the great-spirit's gate**, which opens the next map (Core §7).
- **The home hub.** The family's home map (the **Farmhouse**, Core §8) is the **permanent hub** — **authored with more depth than a finish-once map** (an ongoing upgrade + décor surface) and reachable any time via a **home shortcut** on the HUD, so the player keeps improving it for the life of the save.
- **Spine = the family.** The **home grove** — the first stretch of maps — **wakes the heart-tree and reunites the family** (together, safe, lucid — the heart-tree waking is the payoff), but eases the parents only to **nearly-whole**: the grove **releases its hold**, yet their **full restoration and the way home** wait on the road onward. Then the reunited family travels on, **each new place a community to help**, paying forward what was done for them — and the parents' final freeing lands in the **first place beyond the home grove** (the v1 cliffhanger, Scope below).
- **The long-horizon pull (the loop home).** Reunited but changed, the family can **pass between worlds** and takes up the role the **vanished keepers** left empty — becoming the grove's **new Keepers, a bridge between worlds.** This *permanently heals the great-spirit's wound* (being forgotten), justifies an **endless world that always needs keeping**, and closes the loop back to the "Keeper's grove" origin.

### The home grove — the first maps (a flexible skeleton, **not** a fixed count)

1. **Crossing** (wordless cold-open + FTUE) — dusk at a tired homestead; a drifting **wisp** lures the child through the threshold; the grove takes them; the parents **transform**; **Radish** takes the lost child in at the hearth. The parents wordlessly hand over the first **pop → merge → deliver**.
2. **Restoration beats** — each map a beat: that map wakes, the lead giver's **wish** is eased, the **parents look a little freer**, and **image-memories** (shown, never written) drip the mystery of the keepers and the sleeping spirit.
3. **The waking** — the final beat reaches the **heart-tree**; the last restoration **blooms it awake** (the home grove's big reveal).
4. **Reunion + onward hook** — the heart-tree wakes and **releases its hold**; the family is **reunited and safe**, the parents **nearly-whole** — but not yet fully restored, and **the way home runs deep**. Their full freeing waits onward (the v1 cliffhanger). Onward.

**The home grove, map-by-map** (the current five-map scaffold, §3 — the beats re-spread if the map count is tuned; **Map 1 / the Farmhouse is the home hub**, Core §8):

| Map | Lead + their wish | The wordless beat | Parents |
|---|---|---|---|
| **1 · Farmhouse** | **Radish** — warmth back in the cold, dark house | The crossing lands here: lost and alone, the child is taken in at the hearth by the big serene Radish; the parents appear **transformed** and wordlessly teach the first **pop → merge → deliver**. Restoring the farmhouse **warms it**. | first ease — a hairline crack in Dad's shell, a first petal-stir on Mom |
| **2 · Barn** | **Carrot** — the empty barn & bare fields alive again | The child finds a **playmate her own size**; together they coax animals and green back. An image-memory shows the old keepers tending this barn. | ease — limbs loosen; a face beneath, just barely |
| **3 · Pond** | **Frog** — the dry, silent pond full and singing | The turning point: restoring the pond brings back **water and song**, and an image-memory reveals the **sleeping heart-tree** — **the wisp was its dream all along** — and that the grove is *holding* the parents. | half-human — features clear; they can almost smile |
| **4 · Orchard** | **Bee** — the failed orchard in blossom so her hive can hum | The orchard blooms and the hive returns — and the **heart-tree stirs** in the meadow beyond as the grove wakes. The stakes peak; the parents are **nearly free**. | nearly whole — only a shell-seam, a few petals remain |
| **5 · Meadow** | **Morel** — to glow again, and light the way | **Climax:** Morel relights and leads the path to the **heart-tree**; the last restoration **blooms it awake**. No longer forgotten, the great-spirit **releases its hold and reunites the family** — **reunion** — then gestures to the wider spirit-world: their full restoration and the way home run onward, and the family takes up the **Keepers'** role. | **reunited & released** — together and safe, yet still part-spirit; the final seam + petals wait on the road home (the v1 cliffhanger) |

**The two boundary beats (Core §6/§7), threaded through the home grove.** Each map ends with an **act of care**, not a toll: when the map is restored, the **wisp** — the great-spirit's dreaming reach — returns, and you give it an **offering of your best harvest** (the gate quest). The offering doesn't *buy* passage; it **stirs the sleeping spirit and loosens its hold**, and that release **blooms the map's culminating reveal** and opens the way onward. The wisp **escalates**: gentle at the **Farmhouse** (post-FTUE, your harvest is still modest), larger at the **Barn**; at the **Pond** a memory reveals **the wisp was the heart-tree's dream all along**; at the **Orchard** the offering visibly **stirs the tree**; at the **Meadow** it **wakes** it. And crossing into each new map, its lead's **first wish is for one of your old tools** — you hand a finished map's generator on (all **but the seed satchel**, your anchor — the Wildflower stays, §2) and it **graduates** into the new line (the old line kept in the **Collection**, never lost), so even your producers carry forward rather than being abandoned.

### The story shape + the places it visits

Every **place** reuses one shape, so live-ops (Core §17) ships new places from **content, not new code**:
> *a sleeping local spirit + a produce/critter community + one trapped soul (a family, in the home grove) who **de-transforms** as you restore + a resolution that frees them and points onward* — except the **home grove reunites but defers the parents' full freeing to the next place** (the v1 cliffhanger).

**Candidate places (illustrative — nothing locked):** ① **Home Grove** → ② a faded **Spirit Market / Lantern Town** → ③ a **Drowned Valley** with a river-spirit who lost its name → ④ a misty **Mountain Shrine** → ⑤ the **Forgotten Station** at the world's edge (the threshold home). Each a distinct spirit-world **place — one or more maps**, self-contained, shape-reused.

### Wordless delivery (the No-required-reading pillar, honoured)

Every beat lands without a word: the **parents' faces + gestures**; the **easing transformation**; **before→after** map reveals (Core §8); **image-memory** vignette cards; the **heart-tree's bloom-awake**; the giver **wishes** read as pictures (a dim lantern, a dry pond). Optional names/flavour ride on top — a reader gets more texture; a non-reader misses **nothing required** (Core §7).

**North-star (Core §1) — grove definition of done (v1):** a brand-new player learns the merge verb wordlessly, delivers harvests to **forest neighbours** for Stars, restores the **homestead** spot-by-spot, and reaches a **map-restored reveal feeling earned** — on sim-validated numbers, corruption-safe save, all strings via `tr()`, Calm Mode from launch, audio that degrades gracefully.

**Scope (v1) = the home grove** — the **first maps** (a sequence, **count is a tuning call**, §3; the Farmhouse is the home hub) served by **one** persistent board; later **places** (the §1 story) are post-launch. **v1 ends on a cliffhanger** (§1): the home grove wakes the heart-tree and **reunites the family** — a complete, warm v1 payoff — but eases the parents only to **nearly-whole**; their **full freeing is the first post-launch place**, so the strongest hook is *preserved, not spent*. **The home-hub upgrade→yield loop is v1** — the keystone that gives coins real power (§3 *The Farmhouse hub*, §5; Core §8/§10): hub spots restore with Stars, then **upgrade with Coins for look + passive coin yield**, the soft-currency sink that finally exceeds the faucet. **Permanently cut (tone):** gacha/mystery crates, booster-forfeits-star, and the Bomb/×2/Producer/Countdown toys (only the Wild piece ships). **Deferred backlog:** all "lux" juice (dissolve/iris/morph shaders, pets beyond earned animals, tilt parallax, time-of-day, seasons, photo mode, XL fanfares, combo ladders), idle/offline income, runtime solver, endless/expert tracks, stars-as-currency, cloud-save. *(Moved to **launch:** analytics (Core §15), **push notifications + re-engagement** (Core §18), and the director-review surfaces — gentle-urgency/recurring/social events (Core §17), piggy bank / triggered offers / login calendar (Core §10/§18).)*

**Positioning — the spine (owner pick, 2026-06-14; story + retention pass, 2026-06-14).** A **cozy, gentle f2p** merge-to-restore. Monetization comes from **lowering friction** (energy refills / speed), **customization** (cosmetics), and **gentle accrual offers** (piggy bank, triggered top-ups, login calendar — Core §10/§18) — **no pay-to-win** (every wall passable for free) and **no _predatory_ FOMO**: scarcity is **gentle and recurring** (seasonal beats return — Core §17), social is **opt-in and no-lose** (Core §17). A **wordless, first-class story** (§1) carries the givers and the world (the genre's emotional-retention engine). The hook is the **hand-painted world you build, restore, and show off** (the screenshot-share, Core §17). The engine's commercial + live-ops systems all serve that cozy spine — tuned gentle, additive, never punishing. **The commercial bet, named:** cutting gacha/loot and pay-to-win (Scope, above) is a deliberate **lower-ARPU** choice — it pencils out on **scale + strong retention**, not high per-user spend, so the plan must be sized for **cozy-genre ARPU, not merge-gacha ARPU**. And the hook above rests on one thing — the **art being screenshot-worthy** — a **single point of failure** for the whole thesis, gated at launch (§9 share-gate).

---

## 2 · Item Lines & Generators

*Instantiates Core §6 (Generators & Item Lines).*

The grove runs on an **open-ended roster of themed lines** — each the core's exponential **8-tier** ladder (t8 ≈ 128 t1-equivalents, a rare trophy). The **home grove (v1) seeds it with 24 lines across 12 generators**; the roster then grows **without a cap** — every post-launch *place* adds its set, and live-ops events add limited-time lines (Core §17). Codes `line*100 + tier`; art auto-loads `assets/items/<base>_<tier>.png`. **Map 1's lines** (the first four — with art bases + palette; later lines get bases as each map is built):

| Line | Name | Base | Color |
|---|---|---|---|
| 1 | Wildflower | `flower` | `#D98BA3` |
| 2 | Berry | `berry` | `#7FB4D9` |
| 3 | Mushroom | `mushroom` | `#C9A66B` |
| 4 | Honey | `honey` | `#E3B23C` |

The tier ladder reads as the growth metaphor: **seed → sprout → sapling → bloom → harvest** up the line. Tier-readability law (Core §6) holds: tiers step in size + silhouette, readable at ~100 px.

### The roster — open-ended, seeded by the home grove

Generators (and their lines) arrive **per map** (Core §6): map 1 → 2 generators / 4 lines · maps 2–3 → 3/6 · map 4+ → 4/8. Only **~2–4 are live at once** — old generators are **handed in at a map boundary** (a generator-grant quest, Core §6/§7) and their lines retire to the **Collection**. **v1 ships the home grove (maps 1–5); the full 15-map arc is designed, places ②–⑤ post-launch.**

| Place | Maps | Theme | Status |
|---|---|---|---|
| **① Home Grove** | 1–5 · Farmhouse · Barn · Pond · Orchard · Meadow | cozy pastoral; the parents' arc → cliffhanger at map 5 (§1) | **v1** |
| **② Lantern Town** | 6–8 · Market Row · Tea House · Festival Square | a faded spirit market; the parents are **fully freed** here (pays off the §1 cliffhanger) | post-launch |
| **③ Drowned Valley** | 9–11 · Flooded Fields · River Bend · Sunken Shrine | a river-spirit who lost its name | post-launch |
| **④ Mountain Shrine** | 12–13 · Cloud Steps · Shrine Gate | a misty sky-shrine | post-launch |
| **⑤ Forgotten Station** | 14–15 · Platform · The Crossing | the threshold home; the Keepers' crossing | post-launch |

*(Places ②–⑤ instantiate §1's candidate places — themed + map-counted here, **nothing locked**.)*

**v1 roster — maps 1–5 (concrete, sim-tunable):**

| Map | New generators (2 lines each) | Lines introduced | Live |
|---|---|---|---|
| **1 Farmhouse** | **Seed satchel** *(anchor)* · **Pantry crock** | Wildflower · Berry · Mushroom · Honey | 2 |
| **2 Barn** | **Hen coop** · **Dairy stall** | Egg · Feather · Milk · Wool | 3 |
| **3 Pond** | **Reed bed** · **Creel** | Reed · Lotus · Fish · Snail | 3 |
| **4 Orchard** | **Orchard basket** · **Stone-fruit bough** · **Nut-&-blossom** | Apple · Pear · Plum · Cherry · Walnut · Blossom | 4 |
| **5 Meadow** | **Glow-cap ring** · **Meadow tuft** · **Lantern bloom** | Glowcap · Spore · Clover · Dandelion · Poppy · Firefly | 4 |

**Maps 6–15 — themed line sets** (illustrative, 4 generators / 8 lines each, filled when each place is built):
- **6 Market Row** — Lantern · Paper · Ribbon · Bell · Coin-charm · Silk · Spice · Inkbrush
- **7 Tea House** — Teacup · Leaf · Dumpling · Steam · Mochi · Bamboo · Saucer · Kettle
- **8 Festival Square** — Kite · Fan · Firework · Mask · Drum · Streamer · Sweet · Coin
- **9 Flooded Fields** — Rush · Driftwood · Koi · Pebble · Silt · Heron-feather · Caltrop · Mooring
- **10 River Bend** — Current · Foam · Eel · Shell · Net · Oar · Minnow · Willow-root
- **11 Sunken Shrine** — Sea-bell · Pearl · Algae · Coral · Sunken-coin · Anemone · Urn · Glass-float
- **12 Cloud Steps** — Pine · Cone · Snowbell · Mist · Lichen · Edelweiss · Crag-moss · Hailstone
- **13 Shrine Gate** — Incense · Charm · Ember · Stone-lantern · Prayer-tag · Bell-rope · Cinder · Torii-chip
- **14 Platform** — Ticket · Clock · Steam-puff · Rail · Lamp · Kerchief · Timetable · Coal
- **15 The Crossing** — Wisp · Star · Doorway · Key · Threshold-moss · Map-scrap · Compass · Lantern-spark

**The counts (a floor, never a cap).** v1 (maps 1–5) = **12 generators / 24 lines** (~192 item sprites + 12 gens). The full 15-map arc ≈ **52 generators / 104 lines** (~832 sprites lifetime, almost all post-launch). Beyond 15 the roster stays **uncapped** — more places + live-ops lines keep adding; the Collection archives all of it.

### Generators (Core §6 — the grove's instances)

Each generator emits **2 lines**, popped in a small burst (1 energy/item). Generators **arrive per map, never by level**; only the current map's ~2–4 are live. At each boundary the **generator-grant quest** hands an old generator in for a new one (a hand-in, *not* a merge — the previously-shipped T17 evolve-merge is retired); the boundary's **gate quest** (the **great-spirit**) asks a randomized handful of the finished map's **top-tier harvest** to unlock the next map (Core §6/§7). Later-map lines **sell for more** (per-map coin band, §5).

**Burst + burst-upgrades (the second functional coin sink).** A generator tap pops a **burst** of items (Core §6 `BURST_ODDS`), stacking three ways: a random base · a **free per-map scale-up** (later maps' generators pop bigger) · a **paid burst-upgrade** — spend **coins** to raise a generator's burst (a few levels, L1→~L3, escalating). This is the grove's **second functional coin sink** (with the hub loop, §3): a board-level spend that **scales as maps add generators**, so coins always have somewhere to go. It cuts **taps, not the per-item energy cost** — the energy monetization socket (Core §4) and the level-pacing curve (Core §3) stay **untouched** (Core §6). *(Per-generator levels, costs, burst sizes — sim-tuned.)*

**The anchor (Core §6's exemption).** The **Seed satchel — both its lines, Wildflower + Berry — never retires** across the home grove, permanently holding one of the ~2–4 live slots while the others rotate, so "Mom's line" is always on the board (§1). At the home-grove boundary (**map 5 → 6**) the satchel **graduates to the Collection** too — the parents are freed, so it becomes a keepsake (displayable at the Farmhouse hub, §3) and maps 6+ rotate fully.

### Design-for-more — new maps + events are content, not code

- **Codespace headroom.** `line*100 + tier` with `9xx` reserved for coins → **skip line index 9**; lines 1–8 and 10–104+ map to `100…10408` with no collision. Room for the whole arc and well beyond — no re-encoding.
- **Base-name namespace.** Each line a unique `<base>` (`assets/items/<base>_<tier>.png`); **event lines namespaced** (`winterbloom_*`) so seasonal content never collides with the permanent roster.
- **Self-contained art batches.** Each map (and each event) is its own §16 generation batch — adding a place or event is **art + data, no engine change**.
- **The Collection is unbounded** — it archives every retired line for the life of the save.

The **coin pseudo-line** (Core §6): the currency *is* the **acorn** — code `9xx`, 3 tiers worth 1 / 5 / 25, tapped to collect, ~10% merge-drop rate (engine `COIN_DROP_RATE` default).

All board, water, FTUE-free-pop, and pop-odds constants are **core defaults** (board 7×9 with the center 3×3 open around the satchel at (4,3); `WATER_CAP 100` / `POP_COST 1` / +1·120 s regen; first 10 pops free; `TIER_ODDS [0.65,0.25,0.09,0.01]`, `ASK_WEIGHT 0.6`) — see Core §2–4. Grove cell size defaults to **86 px** (`GAP 10`, `MARGIN 12`).

---

## 3 · Maps — the world you build

*Instantiates Core §8 (Building & the World).*

**Design target (Core §8):** the world is a **sequence of self-contained maps** — each one painted image (an open space with a few buildings + props), restored **in place**; the **Farmhouse map is the home hub** (the permanent, coin-fed anchor — authored deeper than a finish-once map, reached any time via a **home shortcut** on the HUD). **No free-pan overworld, no walk-inside interiors** — navigation is a simple **map-select** of discrete maps. **Current code (the OLD model, pre-Core §8 rewrite):** a `MAP_SIZE = 2160×2880` free-pan top-down map of greyed sites, each tapping into a full-screen `interior_view` room of floor-standing furniture — **superseded by Core §8**; the single-image-map rebuild (drop the overworld + `interior_view`) is parked (`BACKLOG.md`). *(Map-art canvas + the harvest pipeline: §9.)*

> **Build vs the design target.** The *current* grove implements only the **build** half (unlock fixed spots with ★) + **customize** (style variants, §5). The core §8 **home-hub upgrade → passive-yield** loop is now **v1 — the keystone**, specified concretely below (*The Farmhouse hub*: the two-axis Stars-restore / Coins-upgrade design); the **veiled horizon (clouds / discovery)** remains design-direction, not yet in code. The hub yield loop is what turns the homestead from a build-and-decorate surface into the **retention engine** — wiring it is the economy pass the bare-skeleton rebuild enables.

The five maps below are **the home grove** — the first maps in the §1 story (**the only structural unit is the map**, Core §8 — no episode/chapter tier). The **count is a tuning call**, not canon — more maps, and further places, are expected (§1). Current code-verified scaffold — **five maps, 8 spots each, each spot 3–5★ — 176★ across 40 spots**:

| Map | Map id | Spots | ★ total | Restoration spots (examples) |
|---|---|---|---|---|
| 1 Farmhouse | `farmhouse` | 8 | 31★ | **4 yield** (Hearth · Kitchen garden · Well · Larder) + **4 décor** (Porch · Flower boxes · Lantern post · Garden fence) — the hub roster below |
| 2 Barn | `barn` | 8 | 34★ | Hay bales, Milk churns, Hen coop, Old plow |
| 3 Pond | `pond` | 8 | 36★ | Little dock, Lily pads, Rowboat, Willow, Firefly jar |
| 4 Orchard | `orchard` | 8 | 37★ | Apple rows, Cider press, Beehives, Scarecrow |
| 5 Meadow | `meadow` | 8 | 38★ | Wildflower path, Kite, Brook bridge, Stargazer, Rose arch |

**The completion chain (Core §7/§8 — the pacing spine).** A map is **complete** when all its spots are restored; that **unveils the great-spirit's gate** (its **last quest** — an offering of a randomized handful of the map's **top-tier harvest**), and delivering it **unlocks the next map** for a large reward. The next map opens with a **generator-grant quest** (hand an old generator in → a new line, §2). Completing a map also grants **+10💎** (`ZONE_DIAMONDS`) with a celebration and unlocks that map's **wayside plots** (§5).

### The Farmhouse hub — restore · upgrade · yield (the coin loop, v1 keystone)

*Instantiates Core §8's home-hub loop + Core §10's soft-currency loop.* The **Farmhouse (Map 1)** is the **permanent hub** — the one map authored to keep improving for the life of the save (a HUD **home shortcut** returns here from anywhere). Its 8 spots run on **two axes**:

- **Restore — Stars (one-time).** Bring a ruined spot to life at **L1** (the Stars-restore spend; progression, §4). A restored **yield building** immediately drips a small base coin yield.
- **Upgrade — Coins (repeatable).** Raise a yield building **L1→L5** — each level a richer composited look (Core §16 swap) **and** a higher coin yield. The **coin sink with teeth.**

The 8 Farmhouse spots split **4 yield buildings + 4 décor**:

| Spot | Type | Restore | Upgrade | Role |
|---|---|---|---|---|
| **Hearth** | yield | ★ → L1 | coins, L1→L5 | base coin yield ↑ per level; also pays off Radish's "warmth" wish |
| **Kitchen garden** | yield | ★ → L1 | coins, L1→L5 | coin yield ↑ per level |
| **Well** | yield | ★ → L1 | coins, L1→L5 | coin yield ↑ per level |
| **Larder** | yield | ★ → L1 | coins, L1→L5 | coin yield ↑ per level |
| **Porch** | décor | ★ → L1 | — | style variants only (`customize_variants`) |
| **Flower boxes** | décor | ★ → L1 | — | style variants only |
| **Lantern post** | décor | ★ → L1 | — | style variants only |
| **Garden fence** | décor | ★ → L1 | — | style variants only |

*(The roster recasts Map 1's legacy interior furniture — chest/bed/table, superseded with the open-space-map model (§3 above) — into open-space homestead features. Exact props, the per-level yield rates, the L1→L5 upgrade price ladder, and the accrual cap are **grove tuning, sim-validated** — like every other number.)*

**Yield collection — one beat.** Tap the farmhouse and all ready coins sweep to the wallet (`fly_to_wallet`); **never per-building taps**. Each yield building accrues to a **per-building cap (≈ a day's worth)**, so returning ~daily collects meaningfully while a missed day never piles up or punishes. Pairs with the **"yield ready" push** (Core §18).

**Invariants (the teeth + safety).** The **coin sink** (the upgrade ladder + the §5 décor sinks) **exceeds the lifetime coin faucet** (merge drops + selling + quest-overflow coins + hub yield); hub yield is **capped below self-funding** (it extends sessions, never self-sustains — sim-validated, the coin analogue of the energy <30% rule); upgrades buy **yield + look, never Water / the wall**.

---

## 4 · Givers, Quests & Progression

*Instantiates Core §7 (Quests & the fence) and Core §3 (level/rank).*

### The per-map difficulty ramp (instantiates Core §7's deterministic ramp)

> ⚠️ **Superseded by Core §7 (generated quests).** Core §7 now **generates** quests (asks weighted by generator + scaling with level; reward **calculated from expected clicks**, capped to ★ + coin overflow) instead of this fixed per-map curve. The table below is kept as **tuning reference** for the generated model's weights/distribution, but it is **no longer the live ramp** — pending the quest-model rework (see `BACKLOG.md`).

The required single-ask path is the byte-for-byte affordability-proven curve; **multi-line stretch quests are pure additions** (slack grows to cover them), always skippable, paying 2–3★. A freshly debuted line eases in at **≤ t3** for its debut map; **t8 is never a *regular* quest ask** — the map's top tier is reserved for the **great-spirit's gate** (the offering that unlocks the next map, Core §7):

| Map | Tier band | Quests/ch | Slack | 2-count cadence | Stretch | 💧 on spot-buy |
|---|---|---|---|---|---|---|
| 1 Farmhouse | t2–t4 | 5 | 1 | — | 0 | 0 |
| 2 Barn | t3–t5 | 5 | 1 | — | 0 | 0 |
| 3 Pond | t3–t5 | 5 | 1 | every 3 | 1 (2-line) | 0 |
| 4 Orchard | t4–t6 | 5 | 1 | every 2 | 1 (3-line) | 4💧 |
| 5 Meadow | t5–t7 | 6 | 2 | every 2 | 2 (2-line + 3-line) | 5💧 |

Bands climb and stretch density grows map over map, so the late game is **juggling all production lines on one board** (Core §7).

### The givers (instantiate Core §7's fence)

Grove quest-givers are one class (the §1 cast): the **named leads** — **Radish, Carrot, Frog, Bee, Morel** (one anchoring each map, each a map-long **wish**) — **plus a rotating menagerie** of one-wish walk-ons (the old fox/hedgehog/owl naming is **retired**), over the full-width **fence**, up to 5 stands at once, with the **Market Squirrel** (the merchant) pinned at the right. The quest shape (1–3 asks → 1–3★, all-or-nothing delivery) and the **soft star-gate** (`gate_pause`) are core; some quests are **featured** (highlighted, a **bonus** reward — Core §7). Off the fence, the **great-spirit (heart-tree)** is the **gatekeeper** — its end-of-map gate quest is the **completion chain** that unlocks the next map (§3, Core §7). The grove keeps the one hard rule (no-strand: level-gated spots never count as the affordable frontier).

### Level / rank (instantiate Core §3)

The grove's **40 spots run rank 0…39** across the five maps; **level comes from stars earned** (Core §3 `LEVEL_STARS`), and every unlock — generators, maps, spots, board cells — gates on level. Each level-up gifts the core energy gift (Core §4) plus **+3💎** (`LEVEL_DIAMONDS`). Map completion — the **+10💎** (`ZONE_DIAMONDS`) grant and the great-spirit's gate that opens the next map — is the **completion chain** (§3). *(`LEVEL_STARS` thresholds + the per-level unlock map: pending the progression rework — `BACKLOG.md`.)*

---

## 5 · Grove Economy Specifics

*Instantiates Core §10 (The Economy) and Core §9 (Selling & the Merchant).*

The 4-currency model (Water / Stars / Coins / Diamonds) and **sink > faucet** law are core. Grove faucet/sink details:

| Currency | Grove earn additions | Grove spend |
|---|---|---|
| **Water 💧** | the **Rain ☔** button (the daily free refill, Core §4), win-back ("it rained"), map 4–5 spot-buys (4–5💧) | 1 per pop; refill **25💎 → full** |
| **Stars ★** | quests only (1–3★) | restoration spots (3–5★) |
| **Coins 🪙 (acorns)** | merge drops (~10%) · selling t1–t7 · Shop **5💎→150🪙** | waysides · spot variants · spirit treats · basket buy-back |
| **Diamonds 💎** | level-ups (+3) · map restore (+10) · selling a t8 (+1) · cash packs (**live IAP from launch**, Core §4/§10) — the ladder $0.99→80💎 / $4.99→450💎 / $9.99→1000💎 is a **placeholder**; the real ladder adds **high-end tiers ($49.99/$99.99-class)** + a **starter pack** (`BACKLOG.md`) | Water refill (25💎) · Bag slots 7–18 (premium each, Core §5) · gem variants (2–4💎) |

### The Merchant (instantiates Core §9)

The **Market Squirrel** runs the stall. Sell reward and the **32× no-arbitrage invariant** are core (t1–t7 → 1…7🪙; t8 → 1💎, no coins). The grove's buy-back valve is a **wicker basket** at the squirrel's feet (`BASKET_CAP = 3`); a 4th sale overflows and summons the **porter spirit**, who also sweeps the basket every `PORTER_SECS = 180`. Basket never persisted. The Squirrel also keeps the **acorn hoard-jar** — the **piggy-bank vault** (Core §10): it skims a slice of earned 💎, visibly filling, cracked for one fixed real-money price (the §1 commerce-dressed frame).

### Coin sinks (the live grove — Core §10 instantiation)

**Two functional sinks** — hub upgrades (§3) and generator burst (§2) — give coins real power; the rest are cosmetic / net-zero:

| Sink | Cost | Capacity | Flag | Value |
|---|---|---|---|---|
| **Hub upgrades** | coin ladder per level (escalating) | 4 yield buildings × L1→L5 | — (core loop) | **functional** — look + passive coin yield (§3 hub) |
| **Generator burst** | coin ladder per level | each live generator × L1→~L3 | — (core loop) | **functional** — pop more per tap (cuts taps, not energy; §2) |
| **Wayside plots** | 40🪙 + index·6 → **40–154🪙** | 20 plots (4/map) ≈ **1,940🪙** | `wayside_decor` | pure cosmetic — map decoration |
| **Spot variants** | 25🪙 + map·15 + (k%3)·5 → **25–95🪙** | 40 spots ≈ **2,375🪙** | `customize_variants` | pure cosmetic — furniture tint |
| **Spirit treats** | **10🪙** (an acorn treat) | endlessly repeatable | `spirit_treats` | pure cosmetic — a spirit hops |
| **Basket buy-back** | the exact 1–8🪙 paid | per sale | — | utility — recover a mis-sold item (net zero) |

A plot is dormant (greyed) until its map is fully restored, then shows a coin-cost pin; buying is **coin-only, never level-gated, in no unlock chain**. **Faucet vs sink:** the lifetime coin faucet is merge drops + selling + **quest-overflow coins** (Core §7) + **hub yield** (§3); the sinks — the **functional** hub-upgrade ladder (§3) + generator-burst ladder (§2) on top of the cosmetic waysides (~1.9 k) + variants (~2.4 k) — **exceed it** (sink > faucet, *with teeth*). Exact totals are sim-validated.

> **The "coins have no power" tension — resolved by the v1 hub loop (§3, Core §8/§10).** The *legacy* grove sinks (waysides, variants, treats) were all cosmetic / net-zero, so motivation to spend was thin — a decorator pull only. The fix is now **v1**: two functional sinks — the **Farmhouse hub upgrade→yield loop** (§3, paying back in passive coin yield) and **generator burst-upgrades** (§2, fewer taps per item) — give coins real power, off the "premium buys speed" line; the cosmetic sinks stay as the **décor layer** on top. *(Exact yield/upgrade rates + the price ladder are sim-validated, §3. The legacy coin-gated bedroom-decor sink — 663🪙 in `districts.gd`/`room.gd` — is retired with the open-space-map model.)*

The grove's **brambles** are its instance of Core §4's obstacles — the **gating model** (the level-gated board map) lives in **Core §4**, not restated here. The 14 outermost cells stay un-cleared unless the player wants the extra room (optional expansion).

---

## 6 · The 25 Feature Flags

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
| `ambient_spirits` | ambient | spirit folk wander; count = 1 + restored maps (cap 5) | `ambient.gd` |
| `ambient_weather` | ambient | hourly clear/breeze/rain/snow; respects calm | `ambient.gd` |
| `wayside_decor` | feature | coin-priced cosmetic map plots (the structural coin sink) | `home.gd:_make_wayside` |
| `spirit_treats` | feature | a 10🪙 acorn treat at the stall; a spirit scurries + hops | `grove.gd:_buy_treat` |
| `customize_variants` | feature | owned spots offer coin/gem looks via a swatch strip | `home.gd:_apply_variant` |
| `item_backing` | feature | a soft warm contact shadow under each board piece | `grove.gd:_make_piece` |
| `drag_swap` | feature | drop on another occupied cell → swap (merge keeps precedence) | `grove.gd` / `board_model.swap` |
| `ftue_free_pops` | ftue | first 10 pops free + uncounted; Water meter appears after | `grove.gd:_pop_seed` |
| `ftue_staged_chrome` | ftue | merchant from ch1, bag from ch2, water chip after intro | `grove.gd` |

**Core (indexed, NOT flaggable — Core §11):** `gate_pause` (`grove.gd:_active_quest_idx`) · `spot_level_gates` (`G.spot_level_req`). *(`interior_view` (`home.gd:_open_interior`) is **retired** per Core §11 — the open-space-map model has no walk-inside interiors; legacy code pending removal, `BACKLOG.md`.)* **Numeric dials** (`TIER_ODDS`, `ASK_WEIGHT`, `COIN_DROP_RATE 0.10`, `POP_COST`, idle/re-nudge 4.5/4.0 s) live in `grove_content.gd` / `grove.gd`.

*(The T14 flags — `slot_ghost`, `place_pop`, `zone_reveal`, `zone_crowd` — live on `feat/farmhouse-alive`, not yet on `main`; see §11.)*

**Removed / retired** (history, so we don't re-litigate): on-map open-state scatter → map interiors; map-chest "lid opens in place" + scattered price pins → map interiors; centered customize modal → inline swatch strip; emoji-glyph UI → the sprite icon kit (the "emoji purge").

---

## 7 · The Alive Layer

*Instantiates Core §12 (Juice Vocabulary).* The juice **verbs** are core (`press`, `pop_in`, `scatter_in`, `fly_to_wallet`, `tick`, `wiggle`, `breathe`, `hop`, `ambient_bob`, `floater`) — implemented once in `FX` / `Look`. The grove dresses the **alive systems**:

- **Spirit-folk** are the grove's ambient figures — count = 1 + restored maps (cap 5); tap → `hop`.
- **The porter spirit** drifts in for the sell basket (Core §9 / §12).
- **Weather** runs hourly (clear / breeze / rain / snow), respecting Calm Mode.
- **Win-back** is the "it rained" beat (≥48 h → full Water + a one-time minute).

Intended feel (core): **"floaty, breezy, settling."** **Calm Mode** (Settings) halves particles and disables `breathe`.

---

## 8 · Look & Feel — the Grove UI Kit

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

**The storefront (Core §13):** the Shop is the **traveling peddler spirit's stall** (§1 commerce-dressed) with a banner, wallet strip, and a 3-up card grid; unaffordable cards desaturate but stay pressable (→ wiggle + "Need N more"). It sells Water (25💎), Coins (5💎→150🪙), and cash→diamond packs (test popups).

**FTUE (Core §14):** staged — `ftue_free_pops` (first 10 pops free/uncounted, Water meter after) + `ftue_staged_chrome` (merchant ch1, bag ch2, water chip after intro).

---

## 9 · Art Direction (Direction F — Acorn & Bloom)

A hand-painted anime pastoral; the style is the hook (visible handcraft against the genre's glossy-3D baseline). Hard requirements: tiny-icon readability (tiers read at ~100 px), pipeline-reproducibility (fixed style suffix + locked palette), cozy warmth, **and the share-gate** — *would a player screenshot this?* Because the commercial thesis rests on the screenshot-share (§1 Positioning), **share-worthy map art is a launch-gate criterion**, not a nice-to-have: a map that doesn't earn the screenshot doesn't ship. Never name a style or IP — the look lives in ingredients.

**Style core (locked, appended verbatim to every prompt):**

> hand-painted anime film background style, soft gouache and watercolor texture with visible brushwork, gentle diffuse summer daylight, warm nostalgic pastoral palette of meadow green, straw gold and clear sky blue, towering soft cumulus clouds, atmospheric haze in the distance, wind-blown grass, painterly cel-shaded subjects with clean simple line work, no photorealism, no glossy 3D render, no text

Saturation lever: if it reads "digital anime wallpaper," add `muted vintage film colors, slightly faded`.

**Per-asset-class:** *Items* 512² on solid white, chunky silhouette, one warm rim light, shared soil/pot motif per line, tiers step in size+silhouette. *Generators* like items but "openable/giving," larger presence. *Brambles* read as board texture (no rim light, low saturation), 3 densities. *Giver busts* are the **humanoid produce/critter spirits** (§1 cast) — "friendly round [vegetable/critter] spirit from the chest up," **one accessory + one expression that reads the wish** (a dim lantern, a wilted leaf), a **distinct silhouette per species** (Radish round & broad · Carrot tall & leafy · Frog wide & wet · Bee fuzzy & winged · Morel small & cap-shy). *Parents* (Acorn-dad · Flower-mom) are **full-figure guide characters** generated as a **de-transformation ladder** — N once-generated stages each, "mostly spirit → mostly human" (shell cracking open; bloom parting to a face), the engine **swapping the stage per map restored** (Core §16 — composited, never re-rendered), with a **finer "thaw" shimmer** (tint/scale, no new art) easing between stages as smaller progress accrues (§1). *Great-spirit* (the heart-tree) is the **large climactic figure**, generated **sleeping/grieving → bloom-awake** (composited swap). *Seed-sprites* (the ambient spirit-folk) are **tiny, simple, soft-glowing**, 2–3 shapes. *Scenes* opaque — vistas wide with haze, board backdrops tall portrait with a calm low-contrast center (under a 60% scrim). *Maps* are **open-space painted scenes** (Core §8) — a locale (yard / grounds / waterside) with its buildings + props **floor-standing** on it (the §16 floor-standing rule), **surroundings painted in**, never a plain-white bleed. *(The legacy 3:4 walk-inside interior rooms are **retired** — Core §8; the open-space-map rebuild is parked, `BACKLOG.md`.)* *Unlock layers* same-canvas transparent cutouts at identical position/scale.

**Juice restyle:** every effect becomes a meadow thing, palette-only — petal/leaf/pollen puffs (not rainbow dots), sun-dapple bloom (not gold flash), ink-brush lettering on cream chips (not neon shouts), water ripple rings, hand-painted wobbly straw-gold stars. Motion is *floaty, breezy, settling*.

> **Map-art pipeline:** a single coherent render harvests the empty background, each object as a clean transparent cutout, **and** each object's placement box in one pass (the box you cut from *is* its position; round-trip reconstruction is the correctness check). Object ids match the `scripts/grove_content.gd` spot ids; in-game map canvas **1084×1451** (≈ 3:4). Full runbook: **Core §16** (Designing for LLM Asset Generation).

---

## 10 · Audio Direction

**A small acoustic ensemble in a sunlit field** — nylon guitar, felt piano, wooden flute, light strings, brushes; birdsong and leaves under everything. Pentatonic, **one shared key (C / A-minor pentatonic)** across music *and* SFX so no cue sounds sour over the bed. **Water sounds for water verbs, wood for UI.** Nothing electronic, nothing casino.

- **Music is near-ambience, not songs:** one continuous bed at the edge of hearing — slow, sparse, one instrument (+ a faint pad), long silences, **no beat, no melody, no build-ups**. The game alternates two interchangeable takes (`amb_grove1/2`) forever. *Acceptance:* at low volume, if you can tap a foot, hum a tune, or count >1 instrument, re-roll.
- **SFX** are forest one-shots — leaf-brush flicks, moss thumps, a water *plip* for pops, twig-snap for bramble clears, songbird trills for cheers. Mono 44.1 kHz `.wav`, ≤0.6 s, peak ≈ −3 dBFS. Music is stereo `.ogg`, seamless, −16 to −14 LUFS, under the SFX.

Engine file names are unchanged (`merge_soft.wav`, `level_complete.wav`, `amb_grove*.ogg`…) — new takes drop in with zero code changes.

---

## 11 · Current State & the T14 Branch

*Instantiates Core §15 (Tech, Build & Save).* Engine constants and patterns (Godot 4.6, no autoloads, JSON save with deep-merge + atomic write, the Makefile/headless-suite/quiet-godot/economy-sim infra) are core. Grove specifics:

**Code map.** `board.gd` = pure rules engine (tests) · `board_model.gd` = persistent board model · `grove.gd` (~86 KB, the live board) + `home.gd` (~63 KB, the homestead map) drive the loop · `grove_content.gd` = item lines, generator policy, quest script, map/wayside/sell data · static singletons `save.gd`/`features.gd`/`econ.gd`/`layout.gd`/`hud.gd`/`shop.gd`/`skin.gd`/`audio.gd`/`music.gd`/`ambient.gd`/`fx.gd` · legacy `districts.gd`/`levels.gd`/`jobs.gd`/`room.gd`/`main.gd` from an earlier "rooms" prototype framing (not the live grove loop; unrelated to the separate **Tidy Up** game — `tidyup_spec.md`). Main scene `scenes/Home.tscn`. Save `SCHEMA_VERSION = 2`; the `grove` save blob persists board · bag · `qdone` · `unlocks`(= spots bought) · `custom` variants · `seen` hints · `pops` · `waysides` · rng. iOS bundle `com.dongurihouse.dongurimerge`. Headless suites: `core_tests`, `grove_tests` (~297 asserts), `layout_tests`, `map_tests`, `quest_tests`, `save_tests`, + `smoke`; economy bot `games/grove/tools/grove_sim.gd` (default + greedy). The Makefile also wraps the grove art-processing targets `decor` / `icon` (raw → processed sprite) alongside the core-generic run/test/import/shot/ios targets (Core §15).

**Built and verified** (headless asserts + the economy sim, never eyeball): the persistent board with drag-any-to-any merging + the tap-the-satchel generator; the soft star-gate; multi-line stretch quests scaling per map (t8 never asked); the selling economy (t1–t7 → coins, t8 → 1💎, the 32× no-arbitrage invariant, the 3-slot buy-back basket + porter); 2+ coin sinks (20 waysides, spot variants, the 10🪙 treat); and **all five (legacy) map-interiors wired and rendered** (32/32 furniture sprites, hole-punched clean) — the pre-Core §8 interior model, **superseded** by the open-space-map rebuild (`BACKLOG.md`). The sim passes **40/40 spots, 0 jams** in both default (day-4) and greedy (day-7) bot modes.

**Open / owner's judgment** (perceptual calls the asserts can't make): the difficulty *feel* of stretch quests; on-map wayside + interior furniture placements are **provisional** pending the drag-to-place editor (notably the meadow bridge `md_brook`, which renders on grass, not on the baked brook); the motion/feel of the porter drift, sell tags, and spirit treats.

> **In flight — branch `feat/farmhouse-alive` (T14, not yet on `main`).** The unlock *moment* is reworked: empty slots **ghost-preview** the furniture (`slot_ghost`), a bought piece **settles into place** with the burst on the object + its style strip auto-opens (`place_pop`), completing a map plays a fuller **flourish** (`zone_reveal`), and restored maps get **crowded with spirit-folk** in the yard + inside the room (`zone_crowd`). Also fixes a one-buy-per-visit bug (`spot_hits` cleared after the interior rebuilt). Awaiting the owner's eye on feel. The working tree also carries uncommitted experiments around a frame/cutout pipeline (`tools/cutout_frames.gd`, `scenes/frame_test.*`, `scenes/place_test.*`), not yet landed.
