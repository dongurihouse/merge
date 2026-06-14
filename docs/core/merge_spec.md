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

**Tier readability law:** tiers must step in **size and silhouette**, not just detail — readable at small icon size (~100 px). A freshly debuted line eases in at low tier for its debut zone.

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

## 8 · The Spend Surface

The spend surface is **one large free-pan top-down map**. Zones are point-of-interest sprites placed at authored normalized coords; **locked zones render greyed-out (desaturated) in place** and **unlock sequentially** (a zone opens only when the previous one is fully restored). Tapping an unlocked zone walks **inside a full-screen interior room** where the unlock spots live as floor-standing furniture (`interior_view`).

Each zone has a fixed set of **spots**, each priced **3–5★**:

- **Buyable spots.** A spot shows a greyed **"Lv N"** pin until your level is high enough (§7), then an **"★ N"** buy pin; once bought it draws its furniture sprite in place. Empty slots may **ghost-preview** the furniture; a bought piece **settles into place** with a burst, completing a zone plays a fuller **flourish**, and restored zones get **crowded with ambient life**.
- **Restoration → premium currency.** Buying a spot grants EXP toward your **level**. **Fully restoring a zone grants a premium-currency reward** with a celebration; restored zones also drive ambient life (more wandering spirits) and unlock that zone's wayside cosmetic plots.

*(The grove's instances — the zones, their spot counts & star totals, the interior furniture: see `grove_spec`.)*

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
| **Stars ★** (progress) | quests only (1–3★) | restoration spots (3–5★) | The **progress** currency. Never inflates; soft-gated. |
| **Coins 🪙** (expression) | merge drops (~10%) · selling t1–t7 · shop pack | cosmetics · variants · treats · basket buy-back | The **expression** currency — cosmetic/utility only; never gates progression or grants advantage. |
| **Diamonds 💎** (premium) | level-ups · zone restore · selling a t8 (+1) · cash packs (test-only) | energy refill · bag slot · cosmetic variants | Premium-**shaped**, **earned-only** at launch; IAP socket dark. **Buys speed, never possibility.** |

### Sink > faucet (coins)

**Every live coin sink is cosmetic or a no-gain utility — none gate progression or grant any gameplay advantage** (cosmetic map plots, furniture-tint variants, repeatable spirit treats, net-zero basket buy-back). The lifetime coin **faucet** (merge drops + selling, "cleanup never income") is deliberately **exceeded by the cosmetic sinks**, so coins always have somewhere to go. A shop button sells energy, coins, and cash→premium packs (test popups). *(The grove's instances — sink capacities, variant pricing: see `grove_spec`.)*

> **Standing tension (engine-level):** because coin sinks are cosmetic-only, the *motivation* to spend coins can be thin. A game instance should consider a collection/progress hook for decorating, a functional coin use that stays off the "premium buys speed" line, or making the decorated surface *matter*.

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

Intended feel: **"floaty, breezy, settling"** — pieces drift and overshoot rather than snap; ambient life keeps the scene gently in motion when idle. **Alive systems:** ambient figures wander each scene (count = 1 + restored zones, cap 5; tap → hop); a porter drifts in for the basket; weather runs hourly; bursts/floaters fire on merges/buys/restores. **Calm mode** (Settings) halves particles and disables `breathe` — quiets the screen without losing function.

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
