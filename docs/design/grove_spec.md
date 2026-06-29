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
- **The population loop *is* the Keepers fiction made playable (§3/§5).** Restoring a place doesn't just refurnish it — **its spirit-folk return to live there.** A *completed* map opens its **population layer**: the player **welcomes spirit-folk home** (the soft-currency sink; premium residents on Diamonds), and two of a kind **find each other and become one a tier up** (the silent auto-merge, Core §6/§8). The resident "buy" is diegetically **welcoming a spirit home**, never a "buy spirit" store (Core §13, the commerce-dressed law) — care made visible, the same fiction as restoration itself. A world the Keepers tend is a world **filling back up with the folk who belong there.**

### The home grove — the first maps (a flexible skeleton, **not** a fixed count)

1. **Crossing** (wordless cold-open + FTUE) — dusk at a tired homestead; a drifting **wisp** lures the child through the threshold; the grove takes them; the parents **transform**; **Radish** takes the lost child in at the hearth. The parents wordlessly hand over the first **pop → merge → deliver**.
2. **Restoration beats** — each map a beat: that map wakes, the lead giver's **wish** is eased, the **parents look a little freer**, and **image-memories** (shown, never written) drip the mystery of the keepers and the sleeping spirit.
3. **The waking** — the final beat reaches the **heart-tree**; the last restoration **blooms it awake** (the home grove's big reveal).
4. **Reunion + onward hook** — the heart-tree wakes and **releases its hold**; the family is **reunited and safe**, the parents **nearly-whole** — but not yet fully restored, and **the way home runs deep**. Their full freeing waits onward (the v1 cliffhanger). Onward.

**The home grove, map-by-map** (the current five-map scaffold, §3 — the beats re-spread if the map count is tuned; **Map 1 / the Farmhouse is the home hub**, Core §8):

> ⚠ **Place set REWORKED (§3 "The reworked journey").** The **Barn is cut** and the home grove is now **Act I (the Vale)** — Farmhouse · Orchard · Old Mill & Brook · Wildflower Meadow · Vale Gate — of a **20-place, 4-act journey**; the **Pond turning-point reveal** and the **heart-tree climax** re-spread to later acts. The emotional-beat rows **below still describe the OLD 5-map set** and need a re-pass to the new arc.

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

**Scope (v1) = the home grove** — the **first maps** (a sequence, **count is a tuning call**, §3; the Farmhouse is the home hub) served by **one** persistent board; later **places** (the §1 story) are post-launch. **v1 ends on a cliffhanger** (§1): the home grove wakes the heart-tree and **reunites the family** — a complete, warm v1 payoff — but eases the parents only to **nearly-whole**; their **full freeing is the first post-launch place**, so the strongest hook is *preserved, not spent*. **[Superseded — see `residents_spec.md`: residents now carry an economic role + capacity.]** **The population/residents loop is the v1 keystone** — the endless coin sink that gives coins real power (§3 *The population loop*, §5; Core §8/§10): a **completed** map opens a population layer where the player **welcomes spirit-folk residents home** (Coins for base, Diamonds for premium), and **two same-kind residents auto-merge** into one a tier up — an open-ended sink that finally exceeds the faucet (it *replaces* the cut home-hub coin-upgrade→passive-yield loop). **Permanently cut (tone):** booster-forfeits-star, and the Bomb/×2/Producer/Countdown toys (only the Wild piece ships). **The premium surprise-capsule is *reversed but backlogged* (post-v1):** a **no-loss premium surprise-capsule** yielding special characters is now part of the design — but ships **post-v1 behind a readiness gate** (the deterministic resident loop proven healthy + a special-character library exists), and **only under seven locked cozy guardrails** (cosmetic-only · no-loss/dupes auto-convert · no rarity tiers · no pity timer · evergreen/no-FOMO · soft transparent pricing with a free/earned path · diegetic framing, never the word "gacha", not bolted onto the peddler) — Core §4, `BACKLOG.md`. **Deferred backlog:** all "lux" juice (dissolve/iris/morph shaders, pets beyond earned animals, tilt parallax, time-of-day, seasons, photo mode, XL fanfares, combo ladders), idle/offline income, runtime solver, endless/expert tracks, stars-as-currency, cloud-save. *(Moved to **launch:** analytics (Core §15), **push notifications + re-engagement** (Core §18), and the director-review surfaces — gentle-urgency/recurring/social events (Core §17), piggy bank / triggered offers / login calendar (Core §10/§18).)*

**Positioning — the spine (owner pick, 2026-06-14; story + retention pass, 2026-06-14).** A **cozy, gentle f2p** merge-to-restore. Monetization comes from **lowering friction** (energy refills / speed), **customization** (cosmetics), a **gentle, guardrailed cozy gem sink** (welcoming **premium residents** — **[Superseded — see `residents_spec.md`: residents now carry an economic role + capacity.]** deterministic special characters, cosmetic-only — §3/§5), and **gentle accrual offers** (piggy bank, triggered top-ups, login calendar — Core §10/§18) — **no pay-to-win** (every wall passable for free) and **no _predatory_ FOMO**: scarcity is **gentle and recurring** (seasonal beats return — Core §17), social is **opt-in and no-lose** (Core §17). A **wordless, first-class story** (§1) carries the givers and the world (the genre's emotional-retention engine). The hook is the **hand-painted world you build, restore, and show off** (the screenshot-share, Core §17). The engine's commercial + live-ops systems all serve that cozy spine — tuned gentle, additive, never punishing. **The commercial bet, named (ARPU posture — conscious decision):** cutting pay-to-win (Scope, above) is a deliberate **lower-ARPU** choice — it pencils out on **scale + strong retention**, not high per-user spend, so the plan must be sized for **cozy-genre ARPU, not merge-gacha ARPU**. The gem sink is therefore a **gentle, guardrailed cozy sink** (premium residents now; the no-loss surprise-capsule post-v1, behind its readiness gate + seven guardrails — Scope above, Core §4) — **not an open whale-chase**; reversing the capsule cut adds a measured premium sink *without* abandoning the cozy posture. And the hook above rests on one thing — the **art being screenshot-worthy** — a **single point of failure** for the whole thesis, gated at launch (§9 share-gate).

---

## 2 · Item Lines & Generators

*Instantiates Core §6 (Generators & Item Lines).*

> **⚠ REDESIGN (2026-06-28) — read FIRST; the grove build of the new Core §6 box.** Supersedes the
> 2026-06-26 as-built below.
>
> **16 base lines become their own generator (v1 scale).** Sixteen of the grove's content lines (a subset
> of the 31 that have item art — exact picks chosen in the per-line-generator task) each get **one
> generator** that pops **only** that line (Core §6.A), introduced **one per zone**, ~3 active at once via
> `LINE_WINDOW` (Core §6.C). The rest stay shelved for later. The **5 painted maps** (`map1–map5.png`) are
> **reused as backdrops**, decoupled from zone progression — **no new map art**.
>
> **Zone ↔ spot (v1 scale = 23).** The run is **23 zones = 16 base + 7 special**, sized to **match the ~23
> existing restoration spots** so a zone IS a spot — one line/generator introduced as each spot is restored
> (fuses content-unlock with world-restoration §3, no parallel axis). *(Confirmed 2026-06-28 — drives the §3 rewrite.)*
>
> **Bonus generators.** `ACCUMULATORS` (water · coin · acorn · exp) drop their `habitat` real-time accrual
> and become **limited-use side-spawn generators** (Core §6.F). Treat lines **71–75** and the treat-gen are
> **shelved** (kept in `LINES`, out of every pool).
>
> **Special recipe lines.** Rhythm = **base · base · special** (every 3rd zone): the special = the **two
> base lines just before it** at the same tier (Core §6.G). **16 base → 7 specials** (zones 3·6·9·12·15·18·21).
> Art: the 5 shelved treat lines (71–75) seed the first specials; **~2 new 12-tier special sets** to author.
>
> **Quests:** `MAX_GIVERS` **8**, with at most **4 quests per line**. **Curve:** front-loaded — zone 2
> in minutes, zone 3 by ~10 min (≈30 taps/min), sim-validated.
>
> **Assets (Core §6 #5).** Item tier art for all 31 base lines **already exists**. Generator icons: **16
> exist** — 4 are accumulators (→ bonus gens); 12 are line generators (`gen_` wildflowers, wildflowerarch,
> twig_nest, cattails, apples, applepress, beehive, honeycomb, glowcaps, porcini, lilyfountain, seedcart).
> **~4 new generator icons** are needed (16 base − 12 existing icons); the exact per-line assignment is the
> first step of the per-line-generator task. Base-line **item art is complete**; **special-line item art**:
> 5 sets ready (the shelved 71–75), **~2 new 12-tier sets** to author. ~6 new art assets total.

> **⚠ AS-BUILT (2026-06-26) — read first.** The "24 lines / 12 generators / 2 lines per generator" roster
> below is superseded. The Core §6 model (A–E, **all SHIPPED**) is authoritative; this is its grove build.
>
> **Regular lines — SHIPPED (Core §6.A + E).** A **single persistent generator** (the seed satchel) pops
> **every opened line**; lines never retire. Map 0 opens with **one** lead line (the FTUE anchor); maps
> 1–4 each carry **several** (the §6.E multi-line expansion), gated in by `min_level` so a line can debut
> mid-map. Lead line per map (the full roster lives in `grove_data.GENERATORS` / `LINES`):
> | Map (display) | Lead line | base | extra lines on the map (codes) |
> |---|---|---|---|
> | The Farm | Wildflower | `flower` | — (single FTUE line) |
> | The Orchard | Feather | `feather` | fruits · tools · seeds · scarecrows (21–24) |
> | The Garden | Garden tools | `tools` | juice · kites · stones · trinkets · charms · birds · critters · veg (31–38) |
> | The Mill | Honey | `honey` | small fish · small animals · water plants · gears (41–44) |
> | The Gate | Mushroom | `mushroom` | glowcaps · bells · arch tokens · star pebbles (51–54) |
>
> **Per-map SPECIAL "treasure" lines — SHIPPED (Core §6.D).** One luminous **12-tier** fruit chain per map
> (`MAP_TREAT_LINE`), popped only by the temporary treat generator and sold at a premium band
> (`TREAT_SELL_BAND`):
> | Map | Special line | base |
> |---|---|---|
> | The Farm | **Prize pumpkin** | `special_pumpkin` |
> | The Orchard | **Golden banana** | `special_banana` |
> | The Garden | **Jewel avocado** | `special_avacado` |
> | The Mill | **Ruby cherry** | `special_cherry` |
> | The Gate | **Sugar melon** | `special_watermelon` |
> *(The Farm lines 61–66 — hearth embers … flower boxes — are reserve premium treat content, art-ready,
> assigned to a map when the world grows past map 4.)*
>
> **Special drop items — SHIPPED (Core §6.B):** chest · key (drag a key onto a chest → coins+acorns) ·
> water · acorn · exp (tap-collect) · wildcard (a **full 12-tier** line — self-merge + same-tier
> substitute) · coins. *(The brainstorm's tool item was cut.)* **Utility accumulators — SHIPPED (Core
> §6.C):** water · coin · exp · acorn — capped accumulators, no energy cost, tap-collect, bag-stowable.
>
> Art: the special items, the 4 accumulator + 5 treat-generator icons, the 5 treasure lines (incl. the
> 12-tier wildcard), and the multi-line-per-map regular sets all shipped via the intake pipeline; a line
> still renders code-drawn from its `color` until its tier sprites land.

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
| **2 Barn** | **Hen coop** · **Dairy stall** | Feather · Milk | 3 |
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

Each generator emits its authored line, popped in a small burst (1 energy/item). Base-line generators are **owed by the farther of restored-zone progress and level-reached quest progress**, then born on tap if the player lacks the tool; this lets newer level-based quest asks appear and stay playable even when the player delays claiming an affordable restore spot. At each boundary the **gate quest** (the **great-spirit**) asks a randomized handful of the finished map's **top-tier harvest** to unlock the next map (Core §6/§7). Later-map lines **sell for more** (per-map coin band, §5).

**Burst + burst-upgrades (the second functional coin sink).** A generator tap pops a **burst** of items (Core §6 `BURST_ODDS`), stacking three ways: a random base · a **free per-map scale-up** (later maps' generators pop bigger) · a **paid burst-upgrade** — spend **coins** to raise a generator's burst (a few levels, L1→~L3, escalating). This is the grove's **second functional coin sink** (alongside the population loop, §3): a board-level spend that **scales as maps add generators**, so coins always have somewhere to go. It cuts **taps, not the per-item energy cost** — the energy monetization socket (Core §4) and the level-pacing curve (Core §3) stay **untouched** (Core §6). *(Per-generator levels, costs, burst sizes — sim-tuned.)*

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

**Design target (Core §8):** the world is a **sequence of self-contained maps** — each one painted image (an open space with a few buildings + props), restored **in place**; the **Farmhouse map is the home hub** (the permanent, coin-fed anchor — authored deeper than a finish-once map, reached any time via a **home shortcut** on the HUD). **No free-pan overworld, no walk-inside interiors** — navigation is a simple **map-select**: a **list view with a preview card per map** (not a pannable world). **Locked spots show in place** — as a **build-pin** or a **broken/covered image** (the before-state of the before→after restore); the grove uses this in-place reveal **instead of fog / a veiled horizon** (maps are small and the player **moves on to the next map**, not into a hidden expanse — so Core §8's fog idea is not used here). **Current code (the OLD model, pre-Core §8 rewrite):** a `MAP_SIZE = 2160×2880` free-pan top-down map of greyed sites, each tapping into a full-screen `interior_view` room of floor-standing furniture — **superseded by Core §8**; the single-image-map rebuild (drop the overworld + `interior_view`) is parked (`BACKLOG.md`). *(Map-art canvas + the harvest pipeline: §9.)*

> **Build vs the design target.** The *current* grove implements only the **build** half (unlock fixed spots at **exp thresholds**). The core §8 **population/residents** loop is now **v1 — the keystone**, specified concretely below (*The population loop*): restoration spots are **unlock-once** (claimed **free** the moment exp crosses the spot's threshold — no spend; ruined→restored, no coin-upgrade axis), and a **completed** map opens a population layer where the player welcomes residents (Coins / Diamonds) that wander and **auto-merge**. The population loop is what turns a finished homestead from a static decorate-surface into the **retention engine** — wiring it is the economy pass the bare-skeleton rebuild enables. *(This **replaces** the previously-planned home-hub Coins-upgrade→passive-yield loop, now cut — §1 Scope.)*

The five maps below are **the home grove** — now **Act I (the Vale)** of the reworked 20-place journey (see *The reworked journey*, below) and the first maps in the §1 story (**the only structural unit is the map**, Core §8 — no episode/chapter tier). The **count is a tuning call**, not canon — more maps, and further places, are expected (§1). Current scaffold — **five maps** whose spots are derived from each map's vine art mask; all spots are **unlock-once**, **claimed free at a cumulative exp threshold** (§4 — no spend, no level gate, no second coin-upgrade axis):

> **⚠️ Reconcile note (parked — world-narrative, not economy).** The shipped economy (`economy_model.html` + the unlock ladder) is tuned to the **live `[7,4,7,4,1] = 23`-spot** layout from the vine masks, and the build's map slots are ids `farmhouse / barn / pond / orchard / meadow` shown as **The Farm / The Orchard / The Garden / The Mill / The Gate**. The table below keeps the **older world-narrative names + the 8-spot-per-map scaffold + the legacy per-spot `cost` (3–5★) fields** — these are **out of sync with the build** and are a separate **§3 world-design reconcile** (map roster + journey), parked here so this economy pass doesn't half-rewrite the narrative. Economy facts (exp-threshold claim, 23 spots, no spend) are reconciled in §4/§5; the names/counts below are not yet.

| Map | Map id | Spots | The 8 unlock spots (all distinct) |
|---|---|---|---|
| 1 Farmhouse | `farmhouse` | 8 | Hearth · Kitchen garden · Well · Larder · Porch · Flower boxes · Lantern post · Garden fence |
| 2 Orchard | `orchard` | 8 | Apple rows · Picker's ladder · Fruit baskets · Cider press · Beehives · Tree swing · Scarecrow · Apple wagon |
| 3 Old Mill & Brook | `mill` | 8 | Water wheel · Millstone · Flour sacks · Mill bridge · Otter holt · Fishing jetty · Lily eddy · Miller's cart |
| 4 Wildflower Meadow | `meadow` | 8 | Wildflower path · Picnic blanket · Kite · Lemonade stand · Secret garden · Maypole · Hammock · Rose arch |
| 5 Vale Gate | `vale_gate` | 8 | Hedge arch · Wisp shrine · Cobbled lane · Signpost · Lantern gateposts · Stone wall & stile · Welcome bell · Flower urns |

*(The per-map ★ totals are **incidental** — 8 spots × ~3–5★ — not a designed economic ramp; the real per-map effort ramp is the difficulty band (§4) + generator count (§2), rising steeply, so later maps take **multiples longer per ★**. **The old yield/décor split and the 31★ / 176★ figures are RETIRED** with the hub-yield cut: every spot is now a single unlock-once restore, so the per-map and grand ★ totals **change and are TBD / sim-tuned** — re-derive them in the §10 economy re-author. Scaffold numbers — sim-validate the cadence isn't a grind wall.)*

#### The reworked journey — 20 places in 4 acts (supersedes the Barn/Pond/Orchard/Meadow set)

**Why:** the old map-2 **Barn** read as a near-repeat of the **Farmhouse** (another building-in-a-yard). The world now moves through **four regions**, the biome changing each act, as the player journeys **outward from home, then inward and downward toward the sleeping heart-tree** — each map **frees one bound spirit** (who stays on as that map's giver) and **reseeds the place with residents**, and each **act of 5 crosses one big threshold in the parents' release** until the heart-tree wakes and the family is reunited. Two wordless signals build across the whole arc: the **parents easing** (one big stage per act) and the **residents filling in** (every map). **v1 scope cut = TBD** (Act I, or Acts I–II); the rest is the post-launch roadmap.

| Act (region) | Maps | Story threshold |
|---|---|---|
| **I — The Homestead Vale** (lowland) | 1 Farmhouse · 2 Orchard · 3 Old Mill & Brook · 4 Wildflower Meadow · 5 Vale Gate | the wisp returns; **Mom's bloom parts** (first big ease) |
| **II — The Deep Forest** | 6 Woodland Glade · 7 Fern Dell · 8 Lantern Path · 9 Mirror Lake · 10 Great Hollow Tree | the **Pond-style reveal** (the wisp is the heart-tree's dream) lands at the Mirror Lake; **Dad's shell cracks** |
| **III — The High Reaches** (mountain) | 11 Stone Steps · 12 Cliffside Falls · 13 Cloud Bridge · 14 Snowline Tarn · 15 Star Peak Shrine | the ascent; **both parents nearly whole — faces clear** |
| **IV — The Hidden Heart** (cave → eden) | 16 Crystal Cavern · 17 Root Halls · 18 Memory Springs · 19 Heart-Tree Clearing · 20 Secret Eden | descent into the dream; the **heart-tree wakes**, parents freed, family reunited; the Secret Eden bloom + onward hook |

**Act I — the home grove, the unlock spots per map** (all distinct, all unlock-once, **claimed free at cumulative exp thresholds** — no spend; the live layout is `[7,4,7,4,1]`, sim-tuned in the §10 economy pass; names below are the parked world-narrative set, see the §3 reconcile note above):

| Map | id | Lead freed | The 8 spots (★) |
|---|---|---|---|
| 1 Farmhouse | `farmhouse` | Radish | Hearth 3 · Kitchen garden 3 · Well 3 · Larder 4 · Porch 4 · Flower boxes 4 · Lantern post 5 · Garden fence 5 |
| 2 Orchard | `orchard` | Bee | Apple rows 3 · Picker's ladder 4 · Fruit baskets 4 · Cider press 5 · Beehives 5 · Tree swing 4 · Scarecrow 5 · Apple wagon 5 |
| 3 Old Mill & Brook | `mill` | river-otter spirit | Water wheel 3 · Millstone 4 · Flour sacks 4 · Mill bridge 5 · Otter holt 5 · Fishing jetty 4 · Lily eddy 5 · Miller's cart 5 |
| 4 Wildflower Meadow | `meadow` | Carrot | Wildflower path 3 · Picnic blanket 4 · Kite 4 · Lemonade stand 5 · Secret garden 5 · Maypole 4 · Hammock 5 · Rose arch 5 |
| 5 Vale Gate | `vale_gate` | gatekeeper lantern-spirit | Hedge arch 4 · Wisp shrine 5 · Cobbled lane 4 · Signpost 4 · Lantern gateposts 5 · Stone wall & stile 5 · Welcome bell 5 · Flower urns 5 |

Map-art generation prompts (top-down, restored hero) for maps 2–5 are authored to this list; each map renders as a full-bleed 9:16 painted scene with the 8 spots placed, plus a **broken/overgrown pass + per-spot reveal masks** (§9 / §16), output to `games/grove/assets/map/<id>/map_<id>.png`. **Code delta (not yet applied):** `grove_data.gd` `MAPS` still holds the old Barn/Pond/Orchard/Meadow rows — re-point it to this set when the rework lands.

**The completion chain (Core §7/§8 — the pacing spine).** A map is **complete** when all its spots are restored; that **unveils the great-spirit's gate** (its **last quest** — an offering of a randomized handful of the map's **top-tier harvest**), and delivering it **unlocks the next map** for a large reward. The next map opens with a **generator-grant quest** (hand an old generator in → a new line, §2). Completing a map also grants **+5💎** (`MAP_DIAMONDS`; acorns, T58 cut it 10→5 to keep them precious) with a celebration and unlocks that map's **wayside plots** (§5).

### The population loop — welcome spirit-folk home (the coin sink, v1 keystone)

*Instantiates Core §8's population/residents loop + Core §10's soft-currency loop.* **This replaces the cut home-hub Coins-upgrade→passive-yield loop** (§1 Scope) — there is **no yield faucet** and **no L1→L5 coin-upgrade axis** any more; spots simply restore ruined→**restored** once (Stars + level, §4), and the coin sink moves to the *populace*. The loop works on **every fully-restored map**, not just the hub:

- **Welcome (the buy).** **[Superseded — see `residents_spec.md`: residents now carry an economic role + capacity.]** A **completed** map (all spots restored) opens its **population layer**. The player **welcomes spirit-folk residents home** — **base/core residents on Coins** (the primary, *endless* coin sink — repeatable), **premium residents on Diamonds** (deterministic special characters — the v1 gem sink). Framed diegetically as *inviting a spirit home* (§1, Core §13), never a "buy spirit" store.
- **Wander + auto-merge.** Welcomed residents join the **ambient spirit-folk** (§7) and wander the scene. **Two of the same type *and* tier auto-merge — silently, no tap** (the engine pairs them; a **meet-and-poof**) into one resident a tier up. Merge tiers run a **full 12-step ladder** (`RESIDENT_MAX_TIER`). Reuses the merge verb on the populace — **no second board, no second merge surface** (Core §6/§8; the passive-merge variant flagged in Core §2).
- **The roster is the source of truth.** Membership is a **persisted per-map roster** in the save — *not* the on-screen crowd (the wandering sprites are a *render* of the roster). Residents now have a **per-map capacity** (superseded — see `residents_spec.md`); **tier-compression** (each auto-merge removes two, adds one a tier up) still keeps the *visible* count sparse under the §7 / Core §16 density budget.

**The resident rosters (Core §8 — map-specific kin; art §9).** Each map draws its own kin — a small **shared core** reused across all maps, plus **map-signature specials**:

- **Shared core (~3 recolorable wanderers)** — reuse the existing ambient seed-sprites (**moss · acorn · lantern** shapes, §7/§9), recolored per map, on every map.
- **~2 map-signature specials per map** — echoing each place's §1 leads + the rotating menagerie: **Farmhouse** hearth-mice / radish-sprites · **Pond** frog-kin · **Orchard** orchard-bees · **Meadow** meadow-flutterers · (later places: lantern-moths, river-otters…). These are what make **maps distinct from each other** (variety).

> **Variety ≠ hub-specialness (important).** Map-specific rosters make maps **distinct from one another** — they do **NOT** by themselves make the Farmhouse "special." The hub stays special only through its **narrative + functional anchors**: the **HUD home shortcut** (returns here from anywhere), **deeper authoring** (a richer scene + the densest story beats), and the **parents' de-transformation spine** sited here (§1/§9) — **not** a unique mechanic. **Caveat:** the parents (Acorn-dad · Flower-mom) are **authored full-figure de-transformation guides** (§9), **NOT** ambient residents — they are never folded into the wander/merge system.

**Premium residents (the v1 gem sink).** A handful of **deterministic** special characters welcomed on **Diamonds** — *you pick and get exactly that one*, no randomness (the no-loss surprise-capsule that *is* random is **post-v1**, behind its readiness gate — §1 Scope, Core §4). *(Resident economic role superseded — see `residents_spec.md`.)* This is the grove's **recurring gem sink** alongside bag slots + gem variants (§5).

**Décor depth still grows.** The home grove's décor surface keeps deepening for the life of the save — **Collection favorites set as décor** (a line you grew, Core §6), **seasonal décor** from events (Core §17) — on top of the living populace.

**Invariants — superseded by the Residents expansion (`residents_spec.md`).** The base game treated residents as a pure, open-ended **coin sink** — cosmetic-only (no yield, no power, no roster cap), with no passive faucet to outrun. The Residents expansion **reverses this**: residents take on an economic + progression role (a faucet, with per-map capacity and rarity), defined in `residents_spec.md`, which owns the new model. **The §10 economy must be re-authored around that expansion**, not this paragraph; until then the base-game economy here may read inconsistent (acceptable, per the expansion plan). Economy dials remain **sim-validated** on `grove_sim` (§10).

### Keeping finished maps alive (anti-abandonment)

*Instantiates Core §8's anti-abandonment.* A completed map must never feel spent. The population loop (above) **realizes** the "restored maps stay inhabited" promise — it is the primary anti-abandonment system, with events as the refresh layer on top (a single inhabited world, not two competing ones):

- **Restored maps stay inhabited — the population loop *is* this.** A completed map opens its **population layer** (above): the player keeps **welcoming and merging spirit-folk residents** there for the life of the save, so an old map is a **living place that keeps growing**, not a spent level — its **persisted roster** (§7) is who lives there. This is the Keepers fiction (§1) made playable: tend a place → its folk come home.
- **Old maps are the live-ops stage — the refresh layer.** Seasonal / limited **events** (Core §17) are **sited in already-restored maps** — a spring bloom fills the Orchard you finished months ago — and bring **ephemeral resident *visitors*** (a time-boxed guest that wanders the population layer during the event, then leaves — never permanently growing the roster), so revisiting is **content, not collection**. The family tend a world that always needs keeping.

**Reveal juice:** a locked spot shows its **before-state** (build-pin or broken/covered image, above); restoring it **settles the finished thing in** with a burst (the before→after); completing a **map** plays a **flourish** — the prime **screenshot-share** moment (§1 hook, Core §17).

---

## 4 · Givers, Quests & Progression

*Instantiates Core §7 (Quests & the fence) and Core §3 (level/rank).*

> **⚠ 2026-06-28:** `MAX_GIVERS` **8** with **4-per-line** fence layout; recipe-quest asks (§2 REDESIGN box);
> the curve front-loads — zone 2 in minutes, zone 3 by ~10 min. See §2.

### Quests — the live generated model (Core §7, shipped T19)

The deterministic per-map ramp is **retired**; the grove runs Core §7's **generated** quest stream (built + cut over live, `T19`):

- **The ask** draws `{line, tier, count}` from the **level-reached quest-line window** (§2), not restored-zone count, weighted to the **newest / highest-value** and **steered off the lines already on the fence** (distinct concurrent stands). A regular quest is a **single ask** (one item type, count ≥ 1 → a ×N badge); **difficulty rises with level** via **higher tiers + more frequent quests** (reward is effort-priced, so level tracks total effort — §4 Reward), *not* more asks. The late-game "juggle" is **several distinct single-line stands on the fence at once**, with the multi-line **co-assembly reserved for the gate quest**. A map's **ceiling (up to t8) is asked _only_ by the gate quest**, never a regular one.
- **Reward = effort exp + scaled coins** (Core §7, the §exp economy — T58): `exp = round(clicks / QUEST_CLICKS_PER_EXP)` — **flat across maps and uncapped** (the old `STAR_CAP` cap is retired; deeper quests now level you faster *and* pay more coins); `coins = round(clicks / QUEST_CLICKS_PER_COIN[map] × QUEST_COIN_DEPTH^(tier−QUEST_TIER_BASE))` — later maps + deeper merges pay more 🪙 (the **quest coin faucet**, §5). **Acorns are never a quest reward** (milestone/IAP only, §5).
- **Authored boundary quests** (§2): the **great-spirit's gate** (a top-tier handful → unlocks the next map for a large reward) + the **generator-grant** hand-in opening each map.
- **Metered fence** (`gate_pause`): active givers ≈ exp-left-to-finish-the-map (cap = `MAX_GIVERS`) — the fence stays full through the map and tapers only at the end; the **"go restore" cue is the breathing Home button** (it pulses once your exp reaches the cheapest unclaimed spot's threshold, `gate_ready`), not an emptied fence. **No-strand** rests on **guardrails + a Monte-Carlo sim** (green: no-jam · no-strand · steady-state <30% · selling-not-income), not the retired pigeonhole proof.

**Featured quests** — a small random share (`QUEST_FEATURED_RATE` ≈ **15%**, a grove dial) pay a **flat coin bonus** (`QUEST_FEATURED_COIN_BONUS`) on top — **coins only, never exp and never acorns** (since T58; the progression clock and the precious-acorn economy stay untouched); they make stream standouts + a **"do a featured quest" daily/event hook** (Core §17/§18).

### Pacing tunables — pending the owner's sign-off

The whole economy is anchored to the **`ENDGAME_CLICKS` = 100K-click budget** and re-tuned in `docs/economy_model.html` (the live calculator — the single source of truth for the curve numbers). What's unsigned is the **feel** — which *is* a monetization dial (it sets how fast exp arrives and how hard the per-map gate-walls push refills). The grove's provisional knobs (`grove_data.gd`):

| Knob | Sets | Provisional value / intent |
|---|---|---|
| `QUEST_CLICKS_PER_EXP` | clicks → exp (flat across maps) | **7** — the effort price of one exp (the progression clock) |
| `QUEST_CLICKS_PER_COIN` (per map) | clicks → coins, by map | **[8,7,6,5,4]** — later maps pay more coins/click (economic step-up) |
| `QUEST_COIN_DEPTH` | per-tier coin multiplier | **1.05** — deeper merges pay slightly better per click (no per-click trap) |
| `QUEST_LEVELS_PER_TIER` | how fast the single ask climbs in tier | the difficulty slope |
| `QUEST_NEWEST_BIAS` / `QUEST_REPEAT_PENALTY` | line pick: newest-lean + fence diversity | distinct concurrent stands (anti-monotony) |
| `QUEST_2COUNT_RATE` | chance the ask wants 2 (the ×N badge) | the only in-ask effort knob once asks=1 |
| `GATE_TIER_BASE` / `GATE_ASK_COUNT` | gate-quest hardness | ≈ a map's peak output at once |
| `QUEST_FEATURED_RATE` / `QUEST_FEATURED_COIN_BONUS` | % featured + the flat coin bonus | ~15%, coins only |
| `LEVEL_BASE_EXP` / `LEVEL_STEP_EXP` (Core §3) | exp → level | **420 / 0** — a **flat** ~420-exp level (≈ L35 at the 100K-click endgame); `STEP=0` is even, raise it for a ramp |
| `GATE_CAP_FRACTION` (Core §8) | the spot-unlock ladder shape | **0.25** — the last map (the Gate finale) is a small cap; the other four split the exp budget evenly (Option C) |

*(Retired reference — the old deterministic ramp, kept only for band intent: **t2–4 early → t5–7 late**, stretch density growing map over map. No longer the live curve. **Also retired:** the per-quest `#asks` ramp (`QUEST_2ASK_LEVEL`/`QUEST_3ASK_LEVEL` — regular quests are a **single ask** now), the `STAR_CAP`/`CLICK_TO_VALUE` cap-and-spill reward, and the geometric `LEVEL_STARS` curve — all superseded by the §exp economy rework, T58/T60.)*

**Open balance follow-up (sim-tuning, post-§exp-rework).** Two effort levers interact: collapsing quests to one ask (T52) shifts value through **selling** (fewer items consumed per delivery → more surplus → more sell-coins), and the §exp rework (T58) re-derived the whole coin/exp/unlock curve. The reworked `grove_sim` (T61) now reaches the designed endgame and re-validates the invariants — **hard invariants green** (no-strand, zero jams, sink > faucet) and the soft **Y "selling-is-income" tripwire** back under the line (sell-coins/100💧 well below 25). Remaining FINDINGS parked for the owner's tuning pass: an **early-game coin pile** before the first map completes (only the boost sink to spend on), and the sim reaching the endgame exp in **~64K water-clicks vs the 100K nominal budget** (the budget is conservative). *(Levers: a level-scaled **count** curve, a modest `SELL_MAP_BAND` trim, the early coin-sink gap — all PROVISIONAL, owned by the Monte-Carlo tuning pass.)*

### The givers (instantiate Core §7's fence)

Grove quest-givers are one class (the §1 cast): the **named leads** — **Radish, Carrot, Frog, Bee, Morel** (one anchoring each home-grove map, each a map-long **wish**) — **plus a rotating menagerie** of one-wish walk-ons (the old fox/hedgehog/owl naming is **retired**), over the full-width **fence**, up to 8 stands at once and no more than 4 from one item line, with the **Market Squirrel** (the merchant) pinned at the right. Quest shape (a **single ask** → effort exp + coins, all-or-nothing; the **gate is the multi-line exception**) and the **soft exp-gate** (`gate_pause`) are core. Off the fence, the **great-spirit (heart-tree)** is the **gatekeeper** — its end-of-map gate quest is the **completion chain** (§3); the one hard rule is **no-strand** (spots are exp-threshold-gated and claimed free, so the cheapest unclaimed spot is always reachable as exp climbs). The **lead roster extends per place** — maps 6–15 each get their place's spirit (§1's river-spirit, lantern-keeper…); the **menagerie refreshes per map / event** (a few walk-ons at a time — the warmth + novelty layer).

### Level / rank (instantiate Core §3)

The home grove's **23 spots** ([7,4,7,4,1] across the five maps) run in a global unlock order, each with a cumulative **exp threshold** on the Option C ladder (§8). **Level** is a **flat function of exp** (`LEVEL_BASE_EXP=420`, `LEVEL_STEP_EXP=0`; ≈ L35 at the 100K-click endgame). The gates: **board cells** gate on **level** (§4, the `MIN_LEVEL` diamond — and level is a function of exp, so it's an exp gate); **spots** gate on **exp thresholds** (claimed free, no spend); **maps** gate on **completion** of the previous (§8); **generators** arrive **per map** (§6). Each level-up gifts the core energy gift (`LEVEL_WATER_GIFT=20`💧) and grants acorns **only at milestones** — **+3💎** every `LEVEL_DIAMOND_EVERY=10`th level (`LEVEL_DIAMONDS`); **map completion** grants **+5💎** (`MAP_DIAMONDS`) and opens the gate (the completion chain, §3). *(The flat level curve + the spot-threshold ladder are pending the owner's pacing sign-off — see the tunables table above + `economy_model.html`.)*

---

## 5 · Grove Economy Specifics

*Instantiates Core §10 (The Economy) and Core §9 (Selling & the Merchant).*

> **⚠ 2026-06-28:** the water/coin/acorn/exp **accumulators are retired** — replaced by limited-use
> **bonus generators** (§2 / Core §6.F). The faucet/sink tables below that lean on real-time accrual must
> be re-derived in the `grove_sim` pass.

The 4-currency model (Water / **Exp** / Coins / Diamonds) and **sink > faucet** law are core. **Naming note:** the grove's premium currency is **acorns** — that's the player-facing name for the engine's *diamonds* (💎, `add_diamonds`/`LEVEL_DIAMONDS`/`MAP_DIAMONDS` in code); **coins are coins** (the soft currency), *not* acorns. Grove faucet/sink details:

| Currency | Grove earn additions | Grove spend |
|---|---|---|
| **Water 💧** | the **Rain ☔** button (the daily free refill, Core §4), win-back ("it rained"), **rewarded-ad refill** (below) | 1 per pop; refill **25💎 → full** |
| **Exp ✦** | quests only — `round(clicks / QUEST_CLICKS_PER_EXP)`, flat across maps, **uncapped** | **nothing** (never spent) — it *unlocks* restoration spots at thresholds (§3/§4) and drives level |
| **Coins 🪙** | merge drops (~10%) · selling **every tier** (§9) · **quest coins** (§4) · Shop **5💎→150🪙** | **[Superseded — see `residents_spec.md`: residents now carry an economic role + capacity.]** **welcoming base residents on completed maps** (§3 — the primary, *endless* coin sink) · **generator burst-boost** (§2) · waysides · spirit treats · basket buy-back |
| **Diamonds 💎 (acorns)** | **earned-only & precious** (1 acorn = `COINS_PER_ACORN`=1024🪙): level **milestones** (+3 every 10) · map complete (+5) · **piggy crack** (cash) · **cash packs** (live IAP) — *never* quests, *never* selling | Water refill (25💎) · Bag slots 7–18 (premium each, Core §5) · gem variants (2–4💎) · **premium residents** (§3 — deterministic specials, the v1 gem sink) · (post-v1) **the surprise-capsule** (§1, Core §4) · **Shop item-shortcuts / exclusive cosmetics** (below) |

### The Merchant (instantiates Core §9)

The **Market Squirrel** runs the stall. **Every tier sells for `round(tier × per-map band)` coins** — there is **no premium pinnacle** (selling never mints acorns; the old t8 → 1💎 "32× no-arbitrage" invariant is **retired**, T58, now that acorns are milestone/IAP only). **Later-map items sell for more** — a **per-map coin band** (`SELL_MAP_BAND = [1.0, 1.3, 1.7, 2.2, 2.8]`) scales the whole curve up by map (each map an economic step-up). *(The per-map bands are a grove number — sim-tuned across the arc.)* The grove's buy-back valve is a **wicker basket** at the squirrel's feet (`BASKET_CAP = 3`); a 4th sale overflows and summons the **porter spirit**, who also sweeps the basket every `PORTER_SECS = 180`. Basket never persisted. The Squirrel also keeps the **acorn hoard-jar** — the **piggy-bank vault** (Core §10): it skims a slice of earned 💎, visibly filling, cracked for one fixed real-money price (the §1 commerce-dressed frame).

### Bag slots — the 💎 sink (instantiates Core §5)

The bag opens at **6 owned slots** and expands **+1 at a time with 💎**, hard-capped at **18** (12 purchasable expansions); shelving and retrieving are always free, no timers, persisted. Expansion is **convenience, never possibility** (the §10 "premium buys speed, never the wall" line) — a refusal (broke or maxed) never blocks progress. The per-slot price is a **grove number** (`BAG_SLOT_PRICES` in `grove_data.gd`, one entry per slot 7…18) — **owner-tunable**. The shipped schedule is **escalating bands of 3**, so early expansion stays gentle and the late slots are an earned premium:

| Slots | Per-slot 💎 |
|---|---|
| 7 – 9 | **10** |
| 10 – 12 | **15** |
| 13 – 15 | **20** |
| 16 – 18 | **25** |

Total **210💎** to go 6 → 18. The 7th slot keeps the old single-slot price (10💎) for continuity. This is a **💎 sink** only — the coin economy and the selling formula (§9 — every tier → coins, no premium) are untouched.

### Coin sinks (the live grove — Core §10 instantiation)

**The primary sink — welcoming base residents on completed maps (§3) — gives coins real power**; generator burst (§2) is the second functional sink; the rest are cosmetic / net-zero:

| Sink | Cost | Capacity | Flag | Value |
|---|---|---|---|---|
| **Base residents** (welcome) | coin price per welcome (escalating; sim-tuned) | **[Superseded — see `residents_spec.md`: residents now carry an economic role + capacity.]** **endless** — no roster cap, tier-compressed (§3) | — (core loop) | **functional + endless** — a living, merging populace on every completed map (§3 keystone) |
| **Generator burst** | coin ladder per level | each live generator × L1→~L3 | — (core loop) | **functional** — pop more per tap (cuts taps, not energy; §2) |
| **Wayside plots** | 40🪙 + index·6 → **40–154🪙** | 20 plots (4/map) ≈ **1,940🪙** | `wayside_decor` *(pending — §3 rebuild)* | pure cosmetic — map decoration |
| **Spirit treats** | **10🪙** (an acorn treat) | endlessly repeatable | `spirit_treats` | pure cosmetic — a spirit hops |
| **Basket buy-back** | the exact 1–8🪙 paid | per sale | — | utility — recover a mis-sold item (net zero) |

A plot is dormant (greyed) until its map is fully restored, then shows a coin-cost pin; buying is **coin-only, never level-gated, in no unlock chain**. **Faucet vs sink:** the lifetime coin faucet is merge drops + selling + **quest coins** (Core §7) — **no hub yield any more** (the passive coin faucet is cut, §3); the sinks — the **endless** base-resident welcome (§3) + the generator-burst ladder (§2) on top of the cosmetic waysides (~1.9 k) — **exceed it** (sink > faucet, *with teeth*), and because the resident sink is **open-ended** (no cap) there is no finite ceiling for the faucet to catch. Exact prices are **sim-tuned** in the §10 economy re-author. *(Premium residents are a separate **diamond** sink, §3 — not coins.)*

> **[Superseded — see `residents_spec.md`: residents now carry an economic role + capacity.]** **The "coins have no power" tension — resolved by the v1 population loop (§3, Core §8/§10).** The *legacy* grove sinks (waysides, treats) were all cosmetic / net-zero, so motivation to spend was thin — a decorator pull only. The fix is now **v1**: **welcoming base residents on completed maps** (§3 — the primary, *endless* coin sink: a living, auto-merging populace) plus **generator burst-upgrades** (§2, fewer taps per item) give coins real power, off the "premium buys speed" line; the cosmetic sinks stay as the **décor layer** on top. Residents are **cosmetic-only** (no yield, no power — Core §4) — the sink is functional *as a sink*, not as a payback faucet (there is no coin payback now). *(Resident welcome/merge rates are sim-validated in the §10 re-author, §3. The earlier home-hub upgrade→passive-yield loop is **removed** — §1 Scope. The legacy coin-gated bedroom-decor sink — 663🪙 in `districts.gd`/`room.gd` — was retired with the open-space-map model.)*

> **The economy is REOPENED (a fresh balance pass, not a tweak).** Cutting the hub loop deletes both a keystone coin sink (~8,600🪙 ladder) **and** the passive coin faucet (96🪙/day), and moves the sink onto the population loop — so the §10 numbers need re-authoring, not adjusting. The open work: **(1)** re-author `grove_sim` around the resident sink (welcome-price curve + tier-compression) instead of the hub faucet/ladder; **(2)** model the **diamond economy** (premium residents are now a recurring gem sink alongside bag slots + gem variants — size it against the gentle cozy-ARPU posture, §1); **(3)** cover the **early-game window** — the population loop only opens once the **first map completes**, so pre-first-completion coins have only burst-upgrades + cosmetics to spend on; verify coins aren't dead in that window; **(4)** re-derive the **★ scaffold** (the retired 31★/176★ figures, §3) on the unlock-once spots. All hard invariants stay (no-strand, no-jam, selling-not-income) — re-validate every dial on `grove_sim`.

### Monetization surfaces (the buy-side — provisional, pending sign-off)

The revenue surfaces ship **IAP-live from launch** (Core §10); their diegetic frames are §1 (the **peddler** = Shop, the Squirrel's **hoard-jar** = piggy, the **dawn-gift** = login). Core §10 defers the **numbers** to here — the grove's provisional instances, a **commercial sign-off checklist** for the owner (like the §4 pacing tunables). Engine build is parked (`BACKLOG.md`); the calls below are what's open:

| Surface | Grove instance (provisional) |
|---|---|
| **IAP ladder** | a full ladder — entry $0.99 → … → **$49.99 / $99.99 whale tiers**; a one-time **starter pack** (high-value, low-price — the top-converting IAP) + a **first-purchase doubler** |
| **Shop stock** | Water (25💎) · coins (5💎→150🪙) · **item-shortcuts** (a mid-tier piece — coins low / 💎 high) · **cosmetics** (coins base / 💎 exclusive); **a few rotate at a time** |
| **Rewarded ads** (opt-in, geo-flagged) | refill Water · a discount/doubler on one resident **welcome** (§3) · free Shop reroll · event top-up — each **capped + cooldowned**; reward sizes TBD |
| **Piggy bank** (hoard-jar) | skim **~X%** of earned 💎 → crack for **one fixed cash price** (longer play = better deal; resets on crack) |
| **Triggered out-of-Water offer** | at 0💧 → one **gently-discounted** Water + a little 💎, **low cap + cooldown**, no countdown / fail-shaming (reads as *help*) |
| **Login calendar** (dawn-gift, Core §18) | forgiving streak (no day-1 reset), energy modest, milestones lean cosmetic / 💎 |

All ride the **"buys speed + looks, never possibility"** line (Core §4) — every wall passable for free, scarcity gentle + recurring. The **numbers are the open commercial decision**; the cozy guardrails (no forced ads, no FOMO countdowns, no pay-to-win) are **locked**.

The grove's **brambles** are its instance of Core §4's obstacles — the **gating model** (the level-gated board map) lives in **Core §4**, not restated here. The 14 outermost cells stay un-cleared unless the player wants the extra room (optional expansion).

---

## 6 · Feature Flags

*Instantiates Core §11 (the feature-flag system).* Every flag is a `static var` bool in `engine/scripts/core/features.gd`, checked via `Features.on(id)` (unknown id → `true` + warning); **all default ON**. **23 flags today — a *growing* registry** (new v1 systems add more, below). *Eval* = the owner's **keep / improve / cut** verdict, filled during testing.

| Flag | Group | What it does | Lives in | Eval |
|---|---|---|---|---|
| `idle_hint` | assist | ~7 s idle → a mergeable pair wiggles (±6°); re-nudges | `scenes/board.gd:_hint_pair` (search `core/board_logic.gd`) | — |
| `discovery_ladder` | assist | tap an item → upgrade-path card; unseen tiers show "?" | `scenes/board.gd:_open_ladder` | — |
| `quest_ready_check` | assist | green ✓ badge on a giver's ask when payable | `scenes/board.gd:_refresh_giver_lights` | — |
| `sell_hints` | assist | drag → stall brightens + "+N🪙" tag; first max-tier sell hint | `scenes/board.gd:_show_sell_affordance` | — |
| `breathe_cta` | juice | the ONE suggested next action breathes (max one on screen) | `ui/fx.gd:breathe_once` sites | — |
| `press_juice` | juice | buttons squash 0.96 in / overshoot 1.03 out | `ui/skin.gd:add_press_juice` | — |
| `wallet_tick` | juice | wallet numbers count up + chip pulse | `ui/hud.gd` / `ui/fx.gd:tick` | — |
| `fly_to_wallet` | juice | a grant arcs an icon to the wallet chip | `ui/fx.gd:fly_to_wallet` | — |
| `scatter_in` | juice | staggered pop-in for card/section groups | `ui/fx.gd:scatter_in` | — |
| `floaters` | juice | outlined drift-up feedback text | `ui/fx.gd:floating_text` | — |
| `celebrate_bursts` | juice | particle bursts on merges/buys/restores | `ui/fx.gd:burst` / `celebrate_at` | — |
| `spirit_tap_hop` | juice | tapping a map spirit hops it | `ui/ambient.gd` | — |
| `porter_collect` | juice | a porter spirit drifts in to clear the sell basket | `scenes/board.gd:_porter_collect` | — |
| `spirit_treats` | juice | a 10🪙 acorn treat at the stall; a spirit nibbles + hops | `scenes/board.gd:_buy_treat` | — |
| `giver_bob` | juice | frameless fence givers idle-bob (±3 px, ~3 s) | `scenes/board.gd` (fence) | — |
| `gen_preview` | juice | locked generators show a greyed silhouette + "after N spots" | `scenes/board.gd` (gen cells) | — |
| `winback_rain_beat` | ambient | ≥48 h away → full Water + a one-time "it rained" minute | `scenes/board.gd:_load_state` | — |
| `ambient_characters` | ambient | spirit-folk wander; **legacy** count = 1 + restored maps (cap 5) — **superseded on completed maps** by the persisted-roster population model (no cap, tier-compressed; §3/§7) | `ui/ambient.gd` | — |
| `ambient_weather` | ambient | hourly clear/breeze/rain/snow; respects Calm | `ui/ambient.gd` | — |
| `item_backing` | feature | a soft warm contact shadow under each board piece | `scenes/board.gd:_make_piece` | — |
| `drag_swap` | feature | drop on another occupied cell → swap (merge keeps precedence) | `scenes/board.gd` / `core/board_model.gd:swap` | — |
| `ftue_free_pops` | ftue | first 10 pops free + uncounted; Water meter appears after | `scenes/board.gd:_pop_seed` | — |
| `ftue_staged_chrome` | ftue | merchant early, bag a bit later, Water chip after intro | `scenes/board.gd` | — |

**Core (indexed, NOT flaggable — Core §11):** `gate_pause` (`scenes/board.gd:_active_quest_idx`). *(`spot_level_gates` is **retired** — restoration spots are gated by **stars alone** now, not by level; `spot_level_req` no longer exists. `interior_view` is **retired** too — the open-space-map model has no walk-inside interiors; no `_open_interior` remains in code.)* **Numeric dials** (`TIER_ODDS`, `ASK_WEIGHT`, `COIN_DROP_RATE`, `POP_COST`, the §4 quest tunables, idle timing) live in `core/content.gd` / `games/grove/grove_data.gd`.

**Incoming flags** (v1 systems still to land — Core §11/§18 require a flag each): the **monetization / retention surfaces** (login calendar · triggered offer · piggy · rewarded ads — ads + offers **geo-flagged** for staged soft-launch, Core §10/§18); the **build-reveal juice** (ghost-preview / settle-in burst / map flourish / ambient crowd — the former `slot_ghost`/`place_pop`/`zone_reveal`/`zone_crowd`, **not on `main`**; that branch is gone, re-flagged with the map-model rebuild, §3); and the **de-transformation "thaw"** (§1).

**Removed / retired** (history, so we don't re-litigate): **`wayside_decor`** — the wayside coin sink isn't in live code (it rides the open-space-map rebuild, §3/§5); **`ambient_spirits` → renamed `ambient_characters`**; the legacy interior beats (on-map open-state scatter, map-chest "lid opens in place", scattered price pins — gone with interiors); **all customization code** (the per-spot `customize_variants` look strip + the Shop's `SHOP_COSMETICS` "grove theme" looks) — **cut from v1, code removed** (restored spots are inert; the Shop sells item-shortcuts + acorn pouches only). Customization (item + map looks) is **deferred as a whole future feature** — see the **"Item & map customization"** item in `BACKLOG.md`; the design vision still lives in `merge_spec §4/§10/§16`. Emoji-glyph UI → the sprite icon kit (the "emoji purge").

---

## 7 · The Alive Layer

*Instantiates Core §12 (Juice Vocabulary).* The juice **verbs** are core (`press`, `pop_in`, `scatter_in`, `fly_to_wallet`, `tick`, `wiggle`, `breathe`, `hop`, `ambient_bob`, `floater`) — implemented once in `FX` / `Look`. The grove dresses the **alive systems**:

- **Spirit-folk** are the grove's ambient figures — and on a **completed** map they *are* its population **residents** (§3 population loop, Core §8). Membership is the **persisted per-map roster** (in the save), **not** a fixed `1 + restored maps` count and **[Superseded — see `residents_spec.md`: residents now carry an economic role + capacity.]** **no roster cap** — residents are unbounded; **tier-compression** (same-kind pairs **auto-merging** into one a tier up, §3/Core §6) keeps the *visible* count sparse, so small maps never clutter without needing a hard ceiling. Tap → `hop`. The **"crowd as it heals"** payoff (§1) now comes from the **welcome-and-merge loop** plus **per-place variety** — the **map-specific rosters** (§3: a shared core of ~3 recolorable wanderers + ~2 map-signature specials each), echoing §1's per-place leads + rotating menagerie. On an un-completed map a simpler ambient count applies (pre-completion the population layer isn't open yet). They're the **"restored maps stay inhabited"** life (§3 anti-abandonment) and the build-reveal **crowd** (a §6 incoming flag). *(`ambient_characters` flag §6 — its `1 + restored maps (cap 5)` rule is **superseded** by the roster model for completed maps; re-spec on the population build.)*
- **The porter spirit** drifts in for the sell basket (Core §9 / §12).
- **Weather** runs hourly (clear / breeze / rain / snow), respecting Calm Mode.
- **Win-back** is the "it rained" beat (≥48 h → full Water + a one-time minute).

Intended feel (core): **"floaty, breezy, settling."** **Calm Mode** (Settings) halves particles and disables `breathe` — a cozy / accessibility + battery lever that reinforces the *relaxing* positioning (§1), not just a toggle.

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

**Per-asset-class:** *Items* 512² on solid white, chunky silhouette, one warm rim light, shared soil/pot motif per line, tiers step in size+silhouette. *Generators* like items but "openable/giving," larger presence. *Brambles* read as board texture (no rim light, low saturation), 3 densities. *Giver busts* are the **humanoid produce/critter spirits** (§1 cast) — "friendly round [vegetable/critter] spirit from the chest up," **one accessory + one expression that reads the wish** (a dim lantern, a wilted leaf), a **distinct silhouette per species** (Radish round & broad · Carrot tall & leafy · Frog wide & wet · Bee fuzzy & winged · Morel small & cap-shy). *Parents* (Acorn-dad · Flower-mom) are **full-figure guide characters** generated as a **de-transformation ladder** — N once-generated stages each, "mostly spirit → mostly human" (shell cracking open; bloom parting to a face), the engine **swapping the stage per map restored** (Core §16 — composited, never re-rendered), with a **finer "thaw" shimmer** (tint/scale, no new art) easing between stages as smaller progress accrues (§1). *Great-spirit* (the heart-tree) is the **large climactic figure**, generated **sleeping/grieving → bloom-awake** (composited swap). *Seed-sprites / residents* (the ambient spirit-folk — the population layer, §3/§7) are **tiny, simple, soft-glowing**, honoring the **"2–3 shapes" ambient-art law**. The resident art has a fixed structure: a **shared core of ~3 recolorable wanderer shapes** (the existing **moss · acorn · lantern**) reused on **every** map (recolored per map), plus **~2 map-signature specials per map** (Pond frog-kin · Orchard bees · Meadow flutterers · Farmhouse hearth-mice…, §3). **Merge tiers run a full 12-step ladder** (`RESIDENT_MAX_TIER`) — at that depth each tier carries **its own art** (a per-tier ladder like the produce lines), so the old shallow-2–3 "recolor/scale, no new silhouette per tier" rule is **retired** for residents. The **"2–3 shapes" budget now caps distinct base *kinds*, not tiers** — each kind still reads as one family across its 12 steps (size + restyle keep the silhouette legible), but the steps are now authored art, not pure recolors. **Caveat — the parents are NOT residents:** Acorn-dad · Flower-mom are **authored full-figure de-transformation guides** (below), generated as their own ladder and swapped per map — never part of the wander/merge resident system. *Scenes* opaque — vistas wide with haze, board backdrops tall portrait with a calm low-contrast center (under a 60% scrim). *Maps* are **open-space painted scenes** (Core §8) — a locale (yard / grounds / waterside) with its buildings + props **floor-standing** on it (the §16 floor-standing rule), **surroundings painted in**, never a plain-white bleed. *(The legacy 3:4 walk-inside interior rooms are **retired** — Core §8; the open-space-map rebuild is parked, `BACKLOG.md`.)* *Unlock layers* same-canvas transparent cutouts at identical position/scale.

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

> **⚠️ This section is a legacy T14-branch snapshot** — broadly superseded by T17–T61 (the code map, `SCHEMA_VERSION`, spot counts, and the economy below have all moved on). Kept for history; the live model is §3–§5 + `economy_model.html`. Reconciling §11 to current state is a separate **tech/current-state** task (parked).

**Built and verified** (headless asserts + the economy sim, never eyeball): the persistent board with drag-any-to-any merging + the tap-the-satchel generator; the soft progress-gate; multi-line stretch quests scaling per map (t8 never asked); the selling economy (**since reworked** — every tier → coins per the per-map band, the old t8 → 1💎 "32×" pinnacle **retired**, §9; the 3-slot buy-back basket + porter); 2+ coin sinks (20 waysides, spot variants, the 10🪙 treat); and **all five (legacy) map-interiors wired and rendered** (32/32 furniture sprites, hole-punched clean) — the pre-Core §8 interior model, **superseded** by the open-space-map rebuild (`BACKLOG.md`). The sim passes **40/40 spots, 0 jams** in both default (day-4) and greedy (day-7) bot modes.

**Open / owner's judgment** (perceptual calls the asserts can't make): the difficulty *feel* of stretch quests; on-map wayside + interior furniture placements are **provisional** pending the drag-to-place editor (notably the meadow bridge `md_brook`, which renders on grass, not on the baked brook); the motion/feel of the porter drift, sell tags, and spirit treats.

> **In flight — branch `feat/farmhouse-alive` (T14, not yet on `main`).** The unlock *moment* is reworked: empty slots **ghost-preview** the furniture (`slot_ghost`), a bought piece **settles into place** with the burst on the object + its style strip auto-opens (`place_pop`), completing a map plays a fuller **flourish** (`zone_reveal`), and restored maps get **crowded with spirit-folk** in the yard + inside the room (`zone_crowd`). Also fixes a one-buy-per-visit bug (`spot_hits` cleared after the interior rebuilt). Awaiting the owner's eye on feel. The working tree also carries uncommitted experiments around a frame/cutout pipeline (`tools/cutout_frames.gd`, `scenes/frame_test.*`, `scenes/place_test.*`), not yet landed.
