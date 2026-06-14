# Merge Core

> The game-agnostic engine spec for a **merge-to-restore** game: a single persistent merge board, a one-friction energy economy, themed item lines, a quest fence, a sequential-unlock spend surface, a 4-currency economy, and the alive/save/build patterns that carry them. This is the reusable engine; a game instantiates it with names, art, and content-tied numbers (the reference instantiation is the Ghibli Grove — see `grove_spec`).

---

## 1 · Concept, Pillars & Core Loop

A **merge-to-restore** game: the player tends **one persistent merge board**, feeds it from an **energy-gated generator**, and consumes their harvests into a **progress currency** that **visibly restores** a multi-zone spend surface. The board is a saved *workplace*, not a puzzle to win — there is no level select, no board-clear, no undo.

The governing reframe is **"merging is building."** Merge-game nouns map onto whatever the theme is: the board is a *working clearing*; item families are *growth/production lines*; generators are *theme objects that emit them*; energy is a *themed resource*; locked cells are *themed obstacles*; quest-givers are *themed characters*. Unlocks make ambient life and content **appear and stay** — progress is earned, never decorative. *(The grove's instances: see `grove_spec`.)*

### Pillars

| Pillar | Meaning |
|---|---|
| **Zero-learning** | No instruction; the merge verb is discovered, not taught. |
| **Wordless** | Asks, gates, tutorials communicate through silhouettes/icons, not text. |
| **Juice** | Every beat is felt — pop juice, tier-scaled bursts, giver cheer, completions that *land*. |
| **Families** | Items merge only within their line; lines arrive *with* their generators. |
| **Adjacent-unlock** | A merge *adjacent* to a locked cell opens it — expansion as a side effect of play. |
| **Visible progress** | Progress you can *see* — the spend surface restores in place. The core differentiator vs. generic merge-meta. |

### The core loop

```
TAP generator (1 energy → item pops) → MERGE up the tier ladder → DELIVER to a giver
(items fly off → progress ★) → RESTORE a spend-surface spot (spend ★) → next chapter's quests arrive
```

Around that spine: clearing obstacles is **expansion, not the goal** (the board outlasts the content); selling to the merchant and shelving in the bag keep the board drainable, so the only real friction is **energy**.

### Why it works — the merge is the chore, the world is the game

The merge board is a **simple, easy friction engine — deliberately *not* the hook.** It can't be lost and asks little; it is the *effort* you spend, not the reason you play. **What drives play and return is building a world that's yours** — the pull of a life-sim like Animal Crossing (tending a place you own, growing a village), ported onto a mobile-merge effort loop.

- **Why it's fun:** the merge gives a steady, legible micro-reward (two things → one better, with juice); but the *deep* payoff is the **before→after** of a world you turn from empty/overgrown into something finished, alive, and *yours*. No-lose comfort + constant small discoveries keep it relaxing and fresh.
- **What drives merging (moment-to-moment):** a giver's ask (a concrete tier to reach) · the tier ladder (see the next one) · the reward chain (every merge is a visible step toward building) · scarcity (energy is finite; clearing obstacles buys room).
- **What drives the comeback:** energy refills (the soft wall = the return hook) · **an unfinished, evolving world** (the strongest pull — *"my world isn't done and I have an idea for it"*) · **yields to collect** (built things produce over time, §8) · new content always a few steps ahead.

> **Design line (locked):** unlocks are **never a laundry list of names that pop after payment.** Every buildable is *teased, charming, aspirational* — the player should *want* it before they can afford it. Desire is the engine; visual appeal and discovery do the work.

### North-star pattern

**The single emotional target:** *the player reaches their first visible restoration feeling they earned it* — everything is sequenced to reach that as early as is responsible, then breadth layers onto a loop that already works. **Definition of done:** a brand-new player on a fresh save learns the merge verb wordlessly, delivers harvests to givers for progress, spends it to restore the surface spot-by-spot, and reaches a **zone-restored reveal that feels earned** — on economy numbers validated by a headless pacing sim, with corruption-safe save, all strings via `tr()`, a calm mode from launch, and audio that degrades gracefully.

---

## 2 · Board & Merge Rule

A single persistent merge board fed by energy-gated generators. Terrain + items + quest/wallet state persist across sessions.

### Board defaults (engine constants)

| Property | Default |
|---|---|
| Grid | **7 columns × 9 rows = 63 cells** (`COLS=7`, `ROWS=9`) |
| Open at start | the **center 3×3** around the starting generator; everything else is an obstacle |
| Top tier per line | **8** (`TOP_TIER`) |
| Cell size | fills screen width: `csz = min(width-fit, height-fit)`, `GAP`, `MARGIN` tunable |
| Persistence | terrain + items + quest/wallet state saved across sessions |

### The merge rule

- **Drag an unlocked item onto a matching item** (same line *and* tier) → it bumps a tier: source cell empties, target holds the next tier (net −1 occupied). Legal only when both cells hold the same code and the item is below the line's top tier (`can_merge`).
- **Drag onto empty ground** → moves the piece (free rearrange). **Drag onto a non-matching occupied cell** → swaps the two (`drag_swap`). An invalid drop snaps back with a soft wobble.
- There is **no slide/rook routing** — placement is direct drag. Drop targets get a generous catch radius; the bag tray and the merchant's cart are also drop targets.
- **Idle hint:** after ~4.5 s idle the engine rocks one mergeable pair gently (±6°, 3 cycles) and re-nudges ~every 4 s; obstacles a merge would open pulse; deliverable givers bob.

*(Codebase pattern: a pure rules engine (`board.gd`) backs tests; a persistent board model (`grove_board.gd`) and the live board controller drive the loop. An older sliding-merge engine may be retained for tests only and is **not** the shipping model.)*

---

## 3 · Energy — The Only Friction

Merging, moving, delivering, selling, collecting, and decorating are **always free**. **Only popping a generator costs energy.** This single chokepoint is deliberate: it is the **monetization socket** — the one wall everything else routes around.

### Energy defaults (engine constants)

| | Default |
|---|---|
| Cap | **100** (`WATER_CAP`) |
| Pop cost | **1** per generator pop (`POP_COST`) |
| Regen | **+1 every 120 s** (offline included) |
| Level-up gift | **+20** |
| Free refills | **3 lifetime** on first empties (a "refill" button at 0) |
| Paid refill | **25 premium → full** (after free refills) |
| Win-back | away **≥48 h** → full cap |
| Reward ceiling | a chapter's energy rewards stay **< 30%** of that chapter's energy cost |

### The monetization-socket philosophy

The economy is **earned-only** at launch; a premium-currency IAP socket exists but is **dark** — cash packs appear only as confirm-only test popups that grant directly, so real IAP later replaces only the grant call. The design line is **premium buys *speed*, never *possibility***: every wall is passable for free (slower), never purchase-only.

**Energy friction is intentional and must not be designed away** — it is the later monetization hook. The load-bearing invariant: **a chapter's energy rewards stay < 30% of its energy cost** (sessions extend, never self-sustain). A fallback hedge: if energy-resentment plays badly, swap to energy-free with daily quest caps — the rest of the spec survives intact.

### FTUE free pops

The **first 10 pops cost no energy and are uncounted** (`ftue_free_pops`); the energy HUD stays hidden until they're spent, so the opening minute is pure frictionless merging.

---

## 4 · Generators & Item Lines

### Generators

A generator occupies its cell permanently. **Tap → spend 1 energy → one item pops** to a near-empty cell. Pop tier is random with decaying odds (`TIER_ODDS = [0.65, 0.25, 0.09, 0.01]` for t1–t4), weighted toward what current givers want (`ASK_WEIGHT = 0.6`). A full board dims the generator (popping is free while dimmed).

**Generators are the complexity curve** — they reveal at scripted chapters (1 chapter = 1 spot bought), each debuting its line(s). The starting generator is live at chapter 0; later generators appear at authored chapter thresholds (`chapter ≥ appears_at`). *(The grove's instances — which generators, which cells, which chapters: see `grove_spec`.)*

### Item lines

Generators emit **themed item lines** — N lines across the game, each an **exponential tier ladder of M tiers** (engine default top tier **8**; t8 ≈ 128 t1-equivalents, a rare trophy). Codes are `line*100 + tier`; art auto-loads `assets/items/<base>_<tier>.png`.

**Tier readability law:** tiers must step in **size and silhouette**, not just detail — readable at small icon size (~100 px). A freshly debuted line eases in at low tier for its debut zone. *(Each tier is generated once and reused; the shared-motif requirement keeps a line readable as one line — §16.)*

### The coin pseudo-line

**Coins** are a pseudo-line (code `9xx`, 3 tiers worth **1 / 5 / 25**) — tapped to collect, never popped or asked. ~**10%** of merges drop a `c1` (`COIN_DROP_RATE`). It rides the same item/merge plumbing but is economy, not content.

*(The grove's instances — N lines, their names/bases/colors: see `grove_spec`.)*

---

## 5 · Friction Systems

Three systems keep the board drainable so energy stays the only real friction.

### Obstacles (expansion, not the goal)

Every non-center cell is an obstacle encoding a gate `line*16 + tier`. It clears when an **adjacent merge** produces an item meeting the gate (`openable_brambles`). Gates **scale by ring** so the board's difficulty radiates outward:

| Ring | Gate pattern |
|---|---|
| ≤2 (FTUE frontier) | any line, **tier 2** |
| 3 (mid board) | any line, **tier 4** |
| 4 (edge = endgame) | **tier 5** of a late line (split by board half) |

The obstacle field **outlasts the content** (the progress track completes with obstacles still on the edges as tail content); because the board is persistent, clearing obstacles is **pure expansion, never an objective**. *(The grove's instances — exact gates per ring/half: see `grove_spec`.)*

### The bag (the swap-out valve)

An edge tray to shelve items — **no timers, no cost**. **2 slots free; the 3rd costs a small premium fee.** Appears a chapter or two in. It is a drop target for drags.

### The merchant — see §9.

---

## 6 · Quests, Stars & the Soft Gate

### The givers (the fence)

Themed characters pop up over a full-width **fence** above the grid — **up to 5 stands at once**, plus the **merchant** pinned at the right. Tapping a giver whose asked items are all on the board delivers them (**all-or-nothing** — they fly into the giver's hands) and pays progress stars.

A quest is `{asks: [{line, tier, count}], stars}` — **1 to 3 asks**:

| Asks | Meaning | Stars |
|---|---|---|
| 1, floor tier, count 1 | the easy single | 1★ |
| 1, above floor OR count ≥2 | a harder single | 2★ |
| 2 (multi-line "stretch") | cross-generator | 2★ |
| 3 (multi-line "stretch") | cross-generator | 3★ |

### The difficulty ramp (deterministic, no RNG)

Quests are **fixed arithmetic over the chapter index**, drawn from a per-zone ramp (tier band · quests/chapter · slack · 2-count cadence · stretch additions · energy-on-spot-buy). The **required single-ask path** is the byte-for-byte affordability-proven curve; **multi-line stretch quests are pure additions** (slack grows to cover them) — always visible on the first giver slots, always skippable, paying 2–3★ for cross-generator asks. **The top tier never appears as a quest ask** (it is the sold-only premium pinnacle). The ramp shape: bands climb and stretch density grows zone over zone, so the late game is **juggling multiple production lines on one board**. *(The grove's instances — the per-zone ramp table: see `grove_spec`.)*

### Stars & the soft gate

**Stars come from quests only** (1–3★) and are spent **only** on spend-surface restoration spots. Prices **never inflate**; pacing comes from quest depth, not rising costs — stars are pure **progress**, not a balanced economy.

The **soft star-gate** (`gate_pause`): the player may **bank stars past the requirement** — no affordability pause, no early-stop. Givers serve the whole chapter pool, which exhausts on its own; the board stays fully playable when the fence is empty. The one hard rule (**no-strand**): **level-gated spots are never counted as the affordable frontier**. A greedy "just merge and do every quest" player still finishes (sim-proven: all spots, multi-day runway, 0 jams).

---

## 7 · Progression — Chapters vs. Levels

Two counters track progress, and they are **not the same thing.** Both advance only when you **buy a spend-surface spot**, but one *counts spots* and the other *accumulates EXP*, and they drive different systems.

| | **Chapter** | **Level** |
|---|---|---|
| **What it is** | a **count** of spots bought | a **player rank** 1–10 from accumulated EXP |
| **How it's computed** | `chapter = unlocks.size()` — **+1 per spot bought** | `level_for_exp(exp)` over thresholds `LEVEL_XP = [0, 60, 140, 240, 360, 500, 660, 840, 1040, 1260]`; each spot grants `cost × 10` EXP (`EXP_PER_STAR`) |
| **Where it shows** | the "Chapter N" title over the board | the **Lv** chip, top-left |
| **What it drives** | **content pacing** — which generators are live, which **quest pool** the givers serve, chrome staging | **rewards + gating** — each level-up gifts energy + premium (`LEVEL_WATER_GIFT` / `LEVEL_DIAMONDS`); and every spot carries a **level gate** `level_for_exp(rank-scaled EXP)` |
| **In one line** | *how far through the authored script you are* | *your earned rank — the steady energy/premium drip, and which spots you may buy* |

### The level gate & the pigeonhole guarantee

Same trigger (buying a spot), different arithmetic: chapter ticks 1, 2, 3… while level crosses EXP thresholds. The level gate is keyed to a spot's global **rank** (its index across all zones); the curve is set so the *worst-case* player — buying cheapest-first at minimum EXP per spot — is always at least the level some still-unbought spot requires. **By pigeonhole this can never strand the player**: there is always a spot you can both afford *and* are high-enough level to buy (test-proven). So the two stay in lockstep enough that neither locks the other out — but they remain distinct: **chapter is *content*, level is *reward + gate*.** *(The grove's instances — spot count, the per-zone rank/level table: see `grove_spec`.)*

---

## 8 · Building & the World

The spend surface is not a checklist — **it is the game** (§1: *the merge is the chore, the world is the game*). It is a **visible, partly-veiled horizon** the player builds, styles, and upgrades; merging is only the mechanism that funds it. It renders as one large free-pan top-down map of point-of-interest sites; locked sites are veiled/greyed and **unlock in sequence**; tapping an unlocked site walks **inside** it (`interior_view`), where the buildables live.

- **The horizon — visible *and* veiled (desire + discovery).** The world ahead is *shown*, so the player sees what's possible and *wants* it; but parts sit **behind clouds/fog** — reaching them is a *discovery / reveal*, not a line item ticked. The player always sees there's *more* and feels they're *uncovering* it. (A game tunes how much is shown vs veiled.)
- **Build — with agency.** The player **chooses what to build** and stays **in control**; the merge loop earns the means, the player decides where it goes — making the world theirs, not auto-filling fixed slots. A buildable is gated by **progress (Stars)** + **level** (§7), shown as a pin (greyed "Lv N" until the level is met, then an "★ N" buy).
- **Customize — the look is mine.** Each built thing can be **styled** (themes / looks / sets) — expression through appearance.
- **Upgrade — levels that look better *and* pay back.** Each built thing has **levels** (the same thing, L1→Lⁿ): higher levels **look better** *and* **produce better rewards** — so building is **functional, not decorative**, and leveling is a real investment the player owns. This is the keystone that turns "a nicer laundry list" into the Animal-Crossing drive.
- **The yield (reward model A — passive).** Built/upgraded things **produce soft currency over time**, collected on return; higher level → **more / faster**. It **closes the loop** (merge → earn → build & upgrade → the world yields more → fund more building), **gives soft currency real power** (§10), and **makes "open it tomorrow" concrete**. **Capped by the same discipline as energy: the yield *extends* sessions, never self-sustains them** — a reason to return, not an idle game that plays itself.

Build reveals stay juicy: empty slots may **ghost-preview** the buildable; a placed/upgraded thing **settles in** with a burst; finishing a region plays a fuller **flourish**; and a restored region fills with **ambient life** (§12) — the "look what I made" beat.

> **Future / undecided (reward model B):** upgrades *also* buffing the **active merge loop** (a leveled generator pops better tiers / cheaper energy; a leveled stand pays more). Parked, not v1; if added it folds into the same upgrade system.

**Generation (§16):** buildables are floor-standing cut-outs; build-states, upgrades, customization, and the crowd are *composited*, never re-rendered.

*(The grove's instances — the world & its sites, the buildables, and the upgrade/yield instantiation: see `grove_spec`.)*

---

## 9 · Selling & the Merchant

One merchant runs a stall reached on the board — **cleanup, not income.**

- **Sell anything** — drag any item onto the stall (the cleanup verb). While dragging, the stall brightens and a live "+N coin / +1 premium" shoulder tag shows the sale value.
- **Tap-sell** the highest top-tier item present.

### The anti-arbitrage invariant

| Tier | Reward |
|---|---|
| t1–t7 | tier coins (1 … 7 coins) |
| t8 (top) | **1 premium, no coins** — the premium pinnacle |

The energy↔premium round trip is **provably un-abusable**: earning 1 premium (one t8) costs ~2⁷ = **128 energy** of pops, while 1 premium buys only `cap/refill-cost = 4` energy — a **32× loss** (asserted in test/sim). **Selling is cleanup, never income.** The top tier exists to be *sold* (it's never a quest ask, §6) — it's the premium pinnacle.

### The buy-back basket + porter

Sold items fly into a **basket** at the merchant's feet holding the last **3 sales** (`BASKET_CAP = 3`), each tappable to **buy back for the exact currency granted** (return the same coins/premium, get the item back to a free cell). Blocked (wobble) if the board is full or the granted currency was already spent — **no arbitrage**. It is **not storage**: a 4th sale overflows and summons a **porter**, who also collects the basket every ~3 min (`PORTER_SECS = 180`), closing the window for good. The basket is **never persisted**.

---

## 10 · The Economy

The canonical **4-currency model**. The governing law is **sink > faucet** (currencies always have somewhere to go), **earned-only** at launch with a **dark IAP socket**.

| Currency | Earned from | Spent on | Role |
|---|---|---|---|
| **Water 💧** (energy) | regen (+1/2 min, cap 100, offline) · level-ups (+20) · 3 free refills · win-back · some spot-buys · premium refill | 1 per pop | **THE pacing friction** — the monetization socket. Everything else is free. |
| **Stars ★** (progress) | quests only (1–3★) | building / unlocks (§8) | The **progress** currency that gates *what you can build*. Never inflates; soft-gated. |
| **Coins 🪙** (soft) | merge drops (~10%) · selling t1–t7 · **building yields (§8)** · shop pack | **building upgrades (§8)** · customization · basket buy-back | The **soft-economy** currency — it funds the build/upgrade loop, so it finally has real power (not dead cosmetics). |
| **Diamonds 💎** (premium) | level-ups · zone restore · selling a t8 (+1) · cash packs (test-only) | energy refill · bag slot · cosmetic variants | Premium-**shaped**, **earned-only** at launch; IAP socket dark. **Buys speed, never possibility.** |

### The soft-currency loop (coins)

Soft currency **flows in** from the world's **yields** (§8) plus merge drops + selling, and **flows out** into **building upgrades** + customization. This is the engine: *the world pays you, you reinvest in the world.* The governing law still holds — **sinks (upgrades, endless by level) exceed the faucet**, so coins always have somewhere worth going — but the sink is now **functional, not cosmetic**: spending makes the world better *and* pay back more. A shop button also sells energy, coins, and cash→premium packs (test popups). *(The grove's instances — yield/upgrade rates, customization pricing: see `grove_spec`.)*

> **Resolved (was a standing tension):** earlier, coin sinks were cosmetic-only, so the *motivation* to spend coins was thin ("coins have no power"). The build/upgrade **yield loop** (§8) is the fix — coins fund upgrades that pay back, off the "premium buys speed" line. Keep the invariant: the soft loop stays **earned and capped** (it extends sessions, never self-sustains), and upgrades buy *yield + look*, never the energy friction itself.

---

## 11 · Feature-Flag System

This is the canonical **feature index**. Every player-facing alive/juice/assist/onboarding behavior ships behind a **code-level flag** in `scripts/features.gd` (a `static var` bool; **unknown id → `true` + warning**, so a typo can't silently kill a feature). Player toggles (music/sfx/calm) live in Settings, not here. **All flags default ON.** Each flag records *Lives in* (the code site) and *Eval* (the owner's playtest verdict — **keep / improve / cut** — filled during testing).

Flag **groups**: `assist` (idle hint, discovery ladder, ready-✓ badge, sell hints, generator previews), `juice` (breathe-CTA, press juice, wallet tick, fly-to-wallet, scatter-in, floaters, celebrate bursts, tap-hop, giver bob, porter collect), `ambient` (win-back beat, ambient spirits, ambient weather), `feature` (cosmetic sinks, variants, item backing, drag-swap), `ftue` (free pops, staged chrome).

### Core — indexed for visibility, NOT flaggable

Removing one is a design change, not a toggle:

| Name | What |
|---|---|
| `interior_view` | zone interiors (closed building → full-screen room); spot-buying builds on it |
| `bramble_line_gates` | edge obstacles demand late-line tiers (the endgame arc) |
| `gate_pause` | the soft star gate — givers pause at frontier-affordable |
| `spot_level_gates` | spots unlock by player level (rank-derived, strand-proof — §7) |

### Numeric tuning dials (no bool)

`TIER_ODDS` · `ASK_WEIGHT` · `COIN_DROP_RATE` · `POP_COST` · idle-hint / re-nudge timings — all in content/board scripts. *(The grove's instances — the specific 25 flags and their code sites: see `grove_spec`.)*

---

## 12 · Juice Vocabulary

Motion is a **single shared vocabulary, not improvisation** — the same verbs everywhere, and that sameness *is* the visual cohesion. Implemented once in `FX` / `Look` and called by name:

| Verb | Motion |
|---|---|
| `press` | scale 0.96 in / 1.03 overshoot out (0.09 s) |
| `pop_in` | scale 0.92→1 + fade (0.12 s) — overlays |
| `scatter_in` | per-item 0.3→1, stagger 0.04 s — groups |
| `fly_to_wallet` | icon arcs to the HUD chip, which ticks |
| `tick` | wallet number counts ~0.4 s + chip pulse |
| `wiggle` | ±6° ×3 — idle hint and refusals |
| `breathe` | scale 1↔1.04 loop — the ONE suggested action |
| `hop` | quick squash-stretch — tapped ambient life |
| `ambient_bob` | slow 1–3 px float + ±2° tilt — wandering ambient life |
| `floater` | outlined text drift-up + fade |

Intended feel: **"floaty, breezy, settling"** — pieces drift and overshoot rather than snap; ambient life keeps the scene gently in motion when idle. **Alive systems:** ambient figures wander each scene (count = 1 + restored zones, cap 5; tap → hop); a porter drifts in for the basket; weather runs hourly; bursts/floaters fire on merges/buys/restores. *(All of it is **composited sprites/particles** over the scene, never a dense single render — §16.)* **Calm mode** (Settings) halves particles and disables `breathe` — quiets the screen without losing function.

---

## 13 · UX Principles

One holistic kit (`scripts/skin.gd`, "Look") serves every screen, with code-drawn fallbacks so the game is always playable before art lands.

1. **Diegetic first, chrome second** — anything that can live in the world does; true overlays (Shop, Settings, ladder, confirms) are world objects, never flat lists.
2. **One kit, every screen** — all panels/buttons/chips/icons come from `Look`.
3. **Art carries shape & texture; the engine carries every letter and number** — generated images contain **no text and no numerals, ever** (localization + crispness).
4. **Everything ships twice** — kit-art + code-drawn fallback, identical metrics.
5. **Juice is a vocabulary** (§12).

**Surfaces** — three nine-patch elevations: a Ground band, a Card, a Chip; shadows/glows/accents stay code so elevation is tunable without re-art. **Text law** — every label/number/name is engine text in one bundled rounded font; outline = text over the world, no outline = text on a panel (never both). Numbers always sit beside an icon. **Icon kit** — every glyph is a sprite via `Look.icon(id, px)`; no emoji glyphs in shipped UI (the "emoji purge"). **HUD law** — base canvas **portrait, portrait-locked**; the top bar (wallet + Store) is the only top-right authority, the scene chip (Lv/energy) top-left, nothing else in the top safe band; the primary CTA is bottom-center; safe areas only via `Look.safe_top/safe_bottom`. The board fills phone width edge-to-edge and height-binds + centers on tablet. **The Shop is a storefront, not a list** — a stall with a banner, wallet strip, and a card grid; unaffordable cards are desaturated but still pressable (→ wiggle + "Need N more"). *(The grove's instances — palette, exact font, type sizes, icon meanings: see `grove_spec`.)*

---

## 14 · FTUE Pattern

Onboarding is **staged** so the screen reveals mechanics in step with the player — no tutorial wall:

- **`ftue_free_pops`** — the first 10 pops cost no energy and are uncounted; the energy meter (1/pop) appears only after, so the opening minute is pure frictionless merging.
- **`ftue_staged_chrome`** — chrome arrives in chapters: merchant early, bag a chapter later, energy chip after the intro pops.

Assist features (idle hint, discovery ladder, ready-✓, sell hints, generator previews) teach the **merge → sell → spend** loop wordlessly.

---

## 15 · Tech, Build & Save

**Engine:** Godot **4.6**, all logic in GDScript, mobile renderer (ETC2/ASTC), viewport **portrait**, orientation locked portrait, touch-from-mouse on for dev. **No autoloads** — shared systems are `RefCounted` static singletons (`Save.*`, `Audio.*`, `Features.*`, `Econ.*`, `Layout.*`, …) so pure-data modules need no scene presence and headless `-s` test runs resolve them. Target **iOS**; desktop is the dev/test surface.

**Save** (`scripts/save.gd`): versioned **JSON at `user://save.json`** (`SCHEMA_VERSION`), atomic writes (`.tmp` → verify → rename) with a `.bak` last-good fallback; loads **deep-merge over defaults** (never drop unknown keys). Persists `currencies`, board/bag/quest-done/`unlocks`(=chapter)/variants/hints/pops/rng, and `settings`. **Spend-and-grant is one `save_now()`** so a crash can't take currency without the goods.

**Build & test:** a `Makefile` wraps `run`/`editor`/`test`/`test-one`/`smoke`/`import`/`shot-*`/`ios`/`clean`. **Headless suites** run as SceneTree scripts with no window (core/board/layout/map/quest/save + smoke). **Visual checks** use a `quiet_godot.sh` wrapper — a transient `override.cfg` makes the window born **minimized + unfocusable** so captures never steal focus, render at full res, and self-clean. An **economy sim bot** (default + greedy modes) is the load-bearing **affordability/jam safety net** — never eyeball economy; composite/measure. iOS export via an `export_presets.cfg` "iOS" preset.

**Code-map pattern:** a pure rules engine for tests · a persistent board model · a live board controller + a spend-surface controller drive the loop · a content module holds item lines, generator policy, quest script, and zone/sink data · static singletons for save/features/econ/layout/hud/shop/skin/audio/music/ambient/fx. *(The grove's instances — exact file names, sizes, current state: see `grove_spec`.)*

---

## 16 · Designing for LLM Asset Generation

The game's art is **LLM-generated**, so generation is a **design input, not a downstream step**: the design must be something an LLM can reliably produce, keep consistent across separate renders, and let us iterate fast. A design that fights the generator (e.g. a picture frame skewed to "hang" on a wall) is a bug in the *design*, not the prompt.

**The LLM limits that drive the rules:** it can't generate one large *consistent* world; separate generations **drift** in style/shape/lighting/scale; it is **bad at precise perspective/skew** on placed objects; it **garbles text/numerals**; each generation is a slow round-trip.

### Design rules

1. **Discrete, self-contained scenes — no seamless world.** Maps/zones are separate images positioned as distinct "islands/screens" that never need to align edge-to-edge. Interiors too — each is its own render, *not* perspective-continuous with the map.
2. **Floor-standing objects only.** Everything sits flat on the ground with a soft contact shadow — never wall-hung, leaning, or perspective-skewed onto a surface.
3. **Composite, don't regenerate — the scaling law.** Generate **O(assets), recombine in-engine to O(states).** A scene = one empty background + N object cut-outs; the engine renders every state (empty→built, crowded, weather) by **compositing**. So **upgrades** = swap to a higher-level cut-out (each gen'd once) or a tint; **customization** = tint/swap; **crowding** = composited sprites — *never* regenerate the scene with the new thing.
4. **Scenes are composed for clean cut-out.** Generate objects **clearly separated** (breathing room, no overlap, soft contact shadows) so each cuts cleanly — you can't slice a *packed* render apart. "Busy/alive" comes from compositing, not a dense render.
5. **Generate once, reuse forever; re-roll per object.** A bad asset re-rolls *just that object*, never the whole scene.
6. **No text or numerals in art** — the engine draws all text (a UX law *and* an LLM-gen limit).
7. **Aspect/resolution tolerance.** Placement is **normalized coords + crop-to-aspect**, never absolute pixels (LLM output size ≠ game canvas).
8. **One locked style suffix on every prompt + same-batch generation** for cross-asset consistency.

> **The meta-rule:** *design O(assets), never O(combinations) — generate the pieces, compose the game.* Any feature needing a combinatorial pile of renders is a design red flag; restructure it to compose from a small asset set.

### The production method — the zone-gen pipeline

*(Merged from the former `ZONE_GEN_PIPELINE.md`; this is the runbook that executes the rules above.)*

**The idea:** generate **one coherent render** with every object already placed (lit/scaled/styled consistently), then **harvest three things** from that single image: (1) the **empty background** (objects removed), (2) **each object as a clean transparent cut-out**, (3) **each object's placement box** (the box you cut from *is* its position). Paste the cut-outs back at their boxes and you reconstruct the original — that **round-trip is the built-in correctness check**. `[STYLE LOCK]` = the game's locked style suffix, pasted verbatim into every prompt (for the grove, `grove_spec §8`).

The seven phases (per scene; ids must match the content's spot ids so the result feeds the game):

1. **Generate the full scene** — all objects placed, **clearly separated**, soft contact shadows only, `[STYLE LOCK]`. *(P1: "…fully furnished with these N distinct objects, each clearly separated with empty space around it, sitting on the floor… soft even lighting, a small soft contact shadow under each, no overlapping.")* If two objects touch, regenerate.
2. **Detect → manifest** — ask the vision model for a **tight pixel box per object** (including its contact shadow), output as JSON `{id, bbox_px}`. **Verify the boxes by overlaying them** — never trust raw vision output (often a few % off). The manifest is the source of truth.
3. **Cut each object** — crop from the full render (pure pixel copy), then **LLM background-removal** to transparent alpha. *(P3: "…return the SAME object on a fully transparent background; keep its soft contact shadow; do NOT change colors/outline/shape/size; do NOT invent parts.")* **Check the alpha over magenta** for halos/scraps; re-roll just that object if it got resized/redrawn.
4. **Build the empty background** — **masked inpaint of *only* the object regions** (everything else stays byte-identical) is the high-fidelity variant; a whole-image "remove everything" pass is the simpler, noisier one. *(P4: "…repaint ONLY the masked regions as plausible bare floor/wall continuing the room; leave everything outside the mask exactly as-is.")* Pad the mask ~12 px to swallow shadows.
5. **Recompose** — paste each cut-out onto the empty bg at its box's top-left.
6. **Verify (human)** — a diff map (darker = more identical) + a full-vs-reconstructed side-by-side; bright diff = a bad box (2), a dirty cut-out (3), or empty-bg drift (4).
7. **Feed into the game** — boxes → placement format: `pos = box-centre / canvas` (normalized 0–1), `fsize = box-width × (game-canvas-width / render-width)`. Aspect must match the game's ratio or the y-mapping drifts; final tuning is nudged live in the placement sandbox. *(Engine gotcha: the importer can flatten a transparent PNG's alpha — decode at runtime or set the import to preserve alpha.)*

**Gotchas:** objects separated (not touching) · boxes verified by overlay, not trusted raw · boxes include the contact shadow · P3 must not resize/redraw · cut-outs checked over magenta · the inpaint mask padded · canvas **aspect** matches the game · alpha preserved on import.
