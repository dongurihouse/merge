# Merge Core

> The game-agnostic engine spec for a **merge-to-restore** game: a single persistent merge board, a one-friction energy economy, themed item lines, a quest fence, a sequential-unlock spend surface, a 4-currency economy, a live-ops event framework, and the alive/save/build patterns that carry them. This is the reusable engine; a game instantiates it with names, art, and content-tied numbers (the reference instantiation is the Ghibli Grove — see `grove_spec`).

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
(items fly off → progress ★) → RESTORE a spend-surface spot (spend ★) → the next quests arrive
```

Around that spine: clearing obstacles is **expansion, not the goal** (it's the early-game workspace); selling to the merchant and shelving in the bag keep the board drainable, so the only real friction is **energy**.

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
- **Drag onto empty ground** → moves the piece (free rearrange). **Drag onto a non-matching occupied cell** → swaps the two (`drag_swap`). An invalid drop snaps back with a soft `wiggle` (§12).
- There is **no slide/rook routing** — placement is direct drag. Drop targets get a generous catch radius; the bag tray (§5) and the merchant's stall (§9) are also drop targets.
- **Idle hint:** after ~4.5 s idle the engine rocks one mergeable pair gently (±6°, 3 cycles) and re-nudges ~every 4 s; obstacles a merge would open pulse; deliverable givers bob.

*(Codebase pattern: a pure rules engine (`board.gd`) backs tests; a persistent board model (`grove_board.gd`) and the live board controller drive the loop. An older sliding-merge engine may be retained for tests only and is **not** the shipping model.)*

---

## 3 · Progression — Level (the one clock)

There is **one progression counter: level** (the old *chapter* counter is gone — note below), and it is **uncapped** — it climbs forever. Level is driven by **stars earned from quests** — cross a `LEVEL_STARS` threshold, level up — and **level gates restoration spots** (§8) **and board cells** (§4). **Generators arrive per zone** (§6) and **zones unlock by completing the previous one** (§8) — *neither is level-gated*, so new zones (with fresh generators/lines) can ship anytime. The whole loop in one line: *do quests → earn stars → level up → spots unlock → spend stars to restore the zone → the next zone (and its generators) opens.*

Stars do **double duty**: **earned** (cumulative — drives level, never decreases) and **spent** (a balance, on restoration spots §8). Level tracks *lifetime* stars; the wallet holds what's left to spend.

| | **Level** |
|---|---|
| **What it is** | the single player rank (1 → ∞, **uncapped**) |
| **Driven by** | **total stars earned** — `level_for_stars(stars_earned)` over `LEVEL_STARS`; each quest pays ~1–3★ (§7), so **level ≈ quests done** |
| **Shows as** | the **Lv** chip, top-left |
| **Gates** | **restoration spots** (§8) · **board cells** (§4) — *(generators arrive by **zone** §6; zones by **completion** §8 — neither level-gated)* |
| **Grants** | each level-up gifts energy + premium (`LEVEL_WATER_GIFT` / `LEVEL_DIAMONDS`) |

### Level curve & expected clicks

A level's effort is the **generator-clicks** (energy ≈ pops) to complete the quests that earn its stars. Clicks per level ramp fast early — multiple level-ups in the first session (feedback) — then settle to a **flat, uncapped tail**:

| Levels | Clicks / level | Cumulative |
|---|---|---|
| L2 | 25 | 25 |
| L3 | 50 | 75 |
| L4–L10 | 100 | 775 |
| L11–L20 | 200 | 2,775 |
| L21–L30 | 400 | 6,775 |
| L31–L40 | 800 | 14,775 |
| L41–L50 | 1,600 | 30,775 |
| **L51+** | **3,200 (flat, no cap)** | +3,200 / level |

At ~900 f2p clicks/day: early levels are minutes–hours apart; past L50 each level is a steady **~3.6 days** f2p (or ~16–32 min for a premium player). Waypoints: **L50 ≈ 30,775**, **~L103 ≈ 200k**, L150 ≈ 351k — **open-ended** (the "endgame" is *all shipped zones restored*, not a level). **Generators arrive per zone** (§6), not by level; past the early ramp the new content is **zones** (completion-chained, §8) — each shipping fresh generators/lines + spots + scaling quests. *(Clicks-per-level is the tunable curve; the per-quest split that spends it is §7, validated by the Monte-Carlo sim. Clicks count generator pops — the merges that consume them roughly double real actions/time.)*

### No-strand (now statistical, not proven)

The player must never be **stranded** — always able to reach the next unlock. The old guarantee was a **pigeonhole proof** over a deterministic quest curve; **generated** quests (§7) retire that proof, so no-strand now rests on **guardrails** (a spot's level-gate is reachable by the stars earnable before it; the metered fence §7 always supplies the next unlock; **every zone's spots are all reachable so the zone can be completed → the next zone unlocks, §8**) **verified by a Monte-Carlo sim** (worst-case across seeds). Hard rule unchanged: **level-gated content is never the affordable frontier.** *(The grove's instances — `LEVEL_STARS`, spot ranks, the per-level unlock map: see `grove_spec`.)*

> **Removed — the *chapter* counter.** Progression once split *chapter* (spots bought) from *level* (EXP rank); they are now **one thing: level.** `unlocks.size()` still counts spots in code but drives no separate clock; the `chapter` / `EXP` rename is the parked cleanup (`BACKLOG.md`).

---

## 4 · Friction — Energy & the Drainable Board

Merging, moving, delivering, selling, collecting, and decorating are **always free**. **Only popping a generator costs energy.** This single chokepoint is deliberate: it is the **monetization socket** — the one wall everything else routes around.

### Energy defaults (engine constants)

| | Default |
|---|---|
| Cap | **100** (`WATER_CAP`) |
| Pop cost | **1 per item**; a tap pops a small **burst** of 1–3 (`BURST_ODDS`, §6) — fewer taps, same energy/item |
| Regen | **+1 every 120 s** (offline included) |
| Level-up gift | **+50** |
| Free refills | **1 per day** (a "refill" button at 0) |
| Paid refill | **25 premium → full** (after free refills) |
| Win-back | away **≥48 h** → full cap |
| Reward ceiling | **past the early ramp**, a level's energy rewards stay **< 30%** of that level's energy cost |

### The monetization-socket philosophy

The economy is **earned-only** at launch; a premium-currency IAP socket exists but is **dark** — cash packs appear only as confirm-only test popups that grant directly, so real IAP later replaces only the grant call. The design line is **premium buys *speed* and *looks*, never *possibility***: every wall is passable for free (slower), never purchase-only; cosmetics/customization are a fair premium sink (they change the look, not the progression).

**Energy friction is intentional and must not be designed away** — it is the later monetization hook. The load-bearing invariant: **past the early ramp** (deliberately generous — the flat +50 gift can exceed a cheap early level's cost), **a level's energy rewards stay < 30% of its energy cost** (sessions extend, never self-sustain). A fallback hedge: if energy-resentment plays badly, swap to energy-free with daily quest caps — the rest of the spec survives intact.

### FTUE free pops

The **first 10 pops cost no energy and are uncounted** (`ftue_free_pops`); the energy HUD stays hidden until they're spent, so the opening minute is pure frictionless merging.

### Keeping the board drainable

Three systems keep the board drainable so energy stays the only real friction — **obstacles** (below), **the bag** (§5), and **the merchant** (§9, the sell valve).

### Obstacles (expansion, not the goal)

Every non-center cell is an obstacle. The **default 7×9 board** and the gate at each cell (`COLS=7`, `ROWS=9`):

```
        c0   c1   c2   c3   c4   c5   c6
  r0    L12   L8   L6   L6   L6   L8  L12     ← outermost cells (open ~L12)
  r1    L10   L6   L4   L4   L4   L6  L10
  r2     L8   L6   L2   L2   L2   L6   L8
  r3     L6   L3    ·    ·    ·   L3   L6
  r4     L4   L3    ·    G    ·   L3   L4     ← starting generator (G)
  r5     L6   L3    ·    ·    ·   L3   L6
  r6     L8   L6   L2   L2   L2   L6   L8
  r7    L10   L6   L4   L4   L4   L6  L10
  r8    L12   L8   L6   L6   L6   L8  L12     ← outermost cells (open ~L12)
```

| Gate | Meaning |
|---|---|
| `·` / `G` | **Open at start** — the center **3×3** around the starting generator (9 cells). |
| `L2`…`L12` | **Level-gated** — the cell stays sealed until the player reaches that level, then opens on the next **adjacent merge** (adjacent-unlock preserved: you still merge to open, the level only gates *when*). Levels **radiate outward in a diamond** — `L2`/`L3` at the frontier (reached early, where the merge verb is taught), rising to `L12` at the four outer corners. |

*(Levels are a **hand-tuned gradient** — tunable, an **owner's-eye** call on feel; the `L10`–`L12` corners are the **last cells to open** (~L12 — still early in a 150-level run; the board is the early-game *workspace*, not the long tail), pending sim re-validation that the level curve gates the *reachable* board without stranding it. Forward design: `min_level` cell-gating is **not yet in code** — `openable_brambles` is tier-only today.)*

The board **fully opens early** — every cell by ~L12 — so it is the early-game *workspace*; the long game is **zones** (§8, completion-chained) and **quests** (§7), not board-clearing. Because the board is persistent, clearing obstacles is **pure expansion, never an objective**. *(The grove's instances — exact gates per ring/half: see `grove_spec`.)*

### The merchant — see §9.

---

## 5 · The Bag (the swap-out valve)

An edge tray to **shelve items off the board** — the board's pressure-relief valve, so the only real friction stays energy (§4). Shelving and retrieving are **always free**: no timers, no per-use cost. The bag is a **drop target for drags** (drag a board item onto the tray to stow it, drag it back to place it) and **persists** across sessions (saved with the board). It appears **a level or two in** (`ftue_staged_chrome`), not at the very start, so the opening stays uncluttered.

### Capacity

| | Default |
|---|---|
| Starting slots | **6** |
| Expansion | **+1 slot at a time**, bought with **premium currency** (💎) |
| Max slots | **18** (12 purchasable expansions) |

Each expansion is a premium fee (exact prices a game instance — see `grove_spec`). Buying slots is **convenience, never possibility** — it speeds board drainage but is never the only way past a wall (the §4 "premium buys *speed*, never *possibility*" line).

---

## 6 · Generators & Item Lines

### Generators

A generator emits **two item lines**. **Tap → a small burst pops** — items to free cells, **1 energy each**. Burst size stacks three ways: a **random base** (`BURST_ODDS`), a **free scale-up by zone** (later generators pop bigger), and a **player upgrade** (a coin/premium **sink** — pay to grow a generator's burst, §8/§10). All of it cuts **taps**, not the per-item energy economy, so the §3 pacing curve is unchanged. Each item is from **one of its two lines** at a tier with decaying odds (`TIER_ODDS = [0.65, 0.25, 0.09, 0.01]` for t1–t4); line and tier are **weighted toward what current givers want** (`ASK_WEIGHT = 0.6`). A full board dims the generator (popping is free while dimmed). A generator is **never sold**, and you never merge your *working* producer away; it **can be moved** (dragged / swapped like any piece, §2). The one place generators merge is the **evolve-merge** below.

**Generators arrive per zone, not by level.** Each zone introduces a **fresh set**: **zone 1 → 2 generators (4 lines)**, **zones 2–3 → 3 (6 lines)**, **zone 4+ → 4 (8 lines)** — so every new zone (even one shipped post-launch) brings up to **4 new generators / 8 new lines**. Only the **current zone's set (~2–4) is ever live** — old sets evolve away, so the board never accumulates generators.

**Unlocking — the merge-to-evolve gate.** A zone is opened by a **gate quest** asking a **t8** (top tier) of a *previous-zone* line — the capstone proving you mastered that zone (the **only** place t8 is asked, §7). Its generators then arrive from **N quests** (N = the zone's generator count), **spread through the zone, not all upfront**: each grants a generator that the player **merges with a previous-zone generator to upgrade it** into a new-zone producer (`old + grant → new`). The upgrade **consumes the old generator**, so **old lines retire** (nothing asks a retired line) and the live count stays ~2–4. When a zone has **more** generators than the last, the **surplus** are **granted outright** (no predecessor to upgrade). *(Zone 1 has no previous zone — its 2 generators are granted outright: start + an early quest, no t8 gate.)*

**Retired lines → the Collection.** A line that retires (zone advance, or an event ending §17) is **archived to the Collection** — a **completionist almanac** of every line you've grown, with its tiers. Retirement is **archival, not loss**: you keep the *record*, not board clutter. A favorite can be **set as décor** somewhere in your world (a cosmetic display, coins/premium §10) — but **never re-summoned to the board** (that would only crowd it and fight your current quests). Freshness (new lines each zone) and attachment (a kept gallery + showable favorites) both win, without touching the live board.

**Later zones are worth more** — items from a later zone's generators **sell for more coins** (a per-zone **coin band** on t1–t7; **t8 stays the flat 1💎 pinnacle** so §9's 32× proof holds), so each zone is a real economic step-up, not just new art.

### Item lines

Generators emit **themed item lines** — **2 lines per generator** (each line arrives *with* its generator — the Families pillar). A zone runs on its **2–4 generators' 4–8 lines**; retired lines (above) keep the *live* set small even as the lifetime roster grows zone by zone. Each line is an **exponential tier ladder of M tiers** (engine default top tier **8**; t8 ≈ 128 t1-equivalents — the capstone: sold for a premium, or spent on a zone gate). Codes are `line*100 + tier`; art auto-loads `assets/items/<base>_<tier>.png`.

**Tier readability law:** tiers must step in **size and silhouette**, not just detail — readable at small icon size (~100 px). A freshly debuted line eases in at low tier when its generator unlocks. *(Each tier is generated once and reused; a **shared motif** across the ladder keeps a line readable as one object growing.)*

### The coin pseudo-line

**Coins** are a pseudo-line (code `9xx`, 3 tiers worth **1 / 5 / 25**) — tapped to collect, never popped or asked. ~**10%** of merges drop a tier-1 coin (`901`, `COIN_DROP_RATE`). It rides the same item/merge plumbing but is economy, not content.

*(The grove's instances — N lines, their names/bases/colors: see `grove_spec`.)*

---

## 7 · Quests, Stars & the Soft Gate

### The givers (the fence)

Themed characters pop up over a full-width **fence** above the grid — **up to 5 stands** (the active count is metered to the next unlock — see the soft gate), plus the **merchant** pinned at the right. Tapping a giver whose asked items are all on the board delivers them (**all-or-nothing** — they fly into the giver's hands) and pays the quest reward (stars + coins — below).

Givers can carry an optional **narrative arc** — a name, a personality, and dialogue that unfolds as the world restores. Cozy and low-pressure, but it's the genre's **emotional-retention** hook (the *who* and *why* behind the asks), so a game should use it. *(The grove's givers + their story: see `grove_spec`.)*

A **regular** quest is `{asks: [{line, tier, count}], reward: {stars, coins}}` — **1 to 3 asks**, **generated** (the authored zone-gate / generator quests are the exception, below):

### Generating the asks

- Each ask draws a `{line, tier, count}` from the **currently-available generators' lines** (the current zone's — old lines retire, §6), **weighted toward the newest / highest-value** ones, so the fence keeps pointing at the player's richest content.
- **Difficulty rises with player level:** as level climbs, quests shift toward **more asks (→3)** and **higher tiers** — early quests are a single low-tier ask; late quests are 2–3 higher-tier, cross-generator asks (the "juggle every line on one board" endgame).
- **The top tier (t8) is asked _only_ at a zone gate** (the scripted first quest of a zone, below) — never in a regular generated quest.
- **Zone-gate + generator quests are _authored_, not generated.** A zone's **gate** asks a **t8 of a _previous-zone_ line** (the capstone) and opens the zone; then **N quests spread through the zone** each grant a generator that **upgrades a previous-zone one** (`old + grant → new`) — or is **granted outright** for a surplus generator (§6 merge-to-evolve). The generated stream fills everything between. *(Zone 1 excepted — generators granted outright, no t8 gate.)*

### Reward — calculated from expected clicks

The reward is **computed from the quest's expected generator-clicks** — the pops (energy) it takes to produce the asked items: `expected_clicks ≈ Σ asks (count × ~2^(tier−1))`, adjusted for pop-tier odds (`TIER_ODDS`). That value is paid **stars-first, capped, then coins**:

- **`stars = min(value, STAR_CAP)`** — held to **~1–3★**, so **level progression is gated by quest *count*** (each quest pays roughly constant ★ → predictable pacing, §3).
- **`coins = the value above the cap`** — **absorbs the click-variance**: a longer quest pays the *same* ★ but proportionally **more 🪙**, so deep asks never feel under-rewarded.

So stars-per-quest stays roughly constant (**level ∝ quests done**), while **clicks-per-quest range wider** and coins compensate the difference.

### Stars & the soft gate

**Stars** are spent **only** on restoration spots (§8) and drive level (stars earned, §3); prices **never inflate** — stars are pure **progress**, not a balanced economy. **The fence meters quests to the next unlock** (`gate_pause`): the number of active givers tracks **how many stars you still need for the next item** — about `ceil((next_spot_cost − banked_stars) / stars-per-quest)`, capped at the 5 slots. The count **shrinks as you bank stars**, and once you can **afford the next unlock the fence empties** — a wordless **"go restore / upgrade"** signal (never a wall: the board stays fully playable; buying the spot sets a new target and the fence refills for it). The one hard rule (**no-strand**): **level-gated spots are never the affordable frontier**, so the fence never meters toward something your level can't yet reach.

> **Safety-model change (was deterministic).** Quests used to be a **fixed, byte-for-byte affordability-proven curve** — that no-strand proof relied on *no RNG*. Generated asks replace it, so the guarantee now rests on **(a) guardrails** — every ask must be **producible on the current board/generators**, plus an **affordability floor** so a run of unlucky quests can't starve progress — and **(b) a Monte-Carlo sim** (statistical worst-case across seeds), not one deterministic run. *(The grove's instances — generator weights, the level→asks/tier distribution, `STAR_CAP` and the click→value rate: see `grove_spec`. The old per-zone ramp table is retired.)*

---

## 8 · Building & the World

The spend surface is not a checklist — **it is the game** (§1: *the merge is the chore, the world is the game*). It is a **visible, partly-veiled horizon** the player builds, styles, and upgrades; merging is only the mechanism that funds it. It renders as one large free-pan top-down map of **zones** (point-of-interest sites); locked zones are veiled/greyed and **unlock in sequence**; tapping an unlocked zone walks **inside** it (`interior_view`), where its **restoration spots** hold the **buildables** you place. **A zone is *complete* when all its spots are restored — and completing a zone is what unlocks the next** (the completion chain that paces the game, §3); the next zone then opens with its **gate quest**, a t8 of the zone you just finished (§6/§7).

- **The horizon — visible *and* veiled (desire + discovery).** The world ahead is *shown*, so the player sees what's possible and *wants* it; but parts sit **behind clouds/fog** — reaching them is a *discovery / reveal*, not a line item ticked. The player always sees there's *more* and feels they're *uncovering* it. (A game tunes how much is shown vs veiled.)
- **Build — with agency.** The player **chooses what to build** and stays **in control**; the merge loop earns the means, the player decides where it goes — making the world theirs, not auto-filling fixed slots. A **spot** is gated by **progress (Stars)** + **level** (§3), shown as a pin (greyed "Lv N" until the level is met, then an "★ N" buy); buying it places the **buildable**.
- **Customize — the look is mine.** Each built thing can be **styled** (themes / looks / sets) — expression through appearance.
- **Upgrade — levels that look better *and* pay back.** Each built thing has **levels** (the same thing, L1→Lⁿ): higher levels **look better** *and* **produce better rewards** — so building is **functional, not decorative**, and leveling is a real investment the player owns. This is the keystone that turns "a nicer laundry list" into the Animal-Crossing drive.
- **The yield (reward model A — passive).** Built/upgraded things **produce soft currency over time**, collected on return; higher level → **more / faster**. It **closes the loop** (merge → earn → build & upgrade → the world yields more → fund more building), **gives soft currency real power** (§10), and **makes "open it tomorrow" concrete**. **Capped by the same discipline as energy: the yield *extends* sessions, never self-sustains them** — a reason to return, not an idle game that plays itself.

Build reveals stay juicy: empty slots may **ghost-preview** the buildable; a placed/upgraded thing **settles in** with a burst; finishing a **zone** plays a fuller **flourish**; and a restored **zone** fills with **ambient life** (§12) — the "look what I made" beat.

> **Reward model B (partially live).** The active-loop-buff family — upgrades that improve *merging*, not just the world — now has its **first piece live: generator burst-upgrades** (§6 — pay coins/premium to pop more per tap). The rest (a leveled generator pops better tiers / cheaper energy; a leveled stand pays more) stays **parked, not v1**; if added it folds into the same upgrade system.

**Generation (§16):** buildables are floor-standing cut-outs; build-states, upgrades, customization, and the crowd are *composited*, never re-rendered.

*(The grove's instances — the world & its sites, the buildables, and the upgrade/yield instantiation: see `grove_spec`.)*

---

## 9 · Selling & the Merchant

One merchant runs a stall reached on the board — **cleanup, not income.**

- **Sell anything** — **drag** any item onto the stall; dragging is the **only** sell verb (no tap-sell). While dragging, the stall brightens and a live "+N coin / +1 premium" shoulder tag shows the sale value.

### The anti-arbitrage invariant

| Tier | Reward |
|---|---|
| t1–t7 | tier coins (1 … 7) **× per-zone band** — later zones sell for more (§6) |
| t8 (top) | **1 premium, no coins** — the premium pinnacle |

The energy↔premium round trip is **provably un-abusable**: earning 1 premium (one t8) costs ~2⁷ = **128 energy** of pops, while 1 premium buys only `cap/refill-cost = 4` energy — a **32× loss** (asserted in test/sim). *(The per-zone value band scales only t1–t7 **coins**; **t8→premium stays flat at 1**, so this round-trip proof is unaffected.)* **Selling is cleanup, never income.** The top tier is the **capstone**: *sold* for a premium here, or **spent on a zone gate** (the only quest that asks t8, §6/§7) — never in a regular quest.

### The buy-back basket + porter

Sold items fly into a **basket** at the merchant's feet holding the last **3 sales** (`BASKET_CAP = 3`), each tappable to **buy back for the exact currency granted** (return the same coins/premium, get the item back to a free cell). Blocked (`wiggle`) if the board is full or the granted currency was already spent — **no arbitrage**. It is **not storage**: a 4th sale overflows and summons a **porter**, who also collects the basket every ~3 min (`PORTER_SECS = 180`), closing the window for good. The basket is **never persisted**.

---

## 10 · The Economy

The canonical **4-currency model** (engine names — a game may re-skin them; energy is "Water" in the grove). The governing law is **sink > faucet** (currencies always have somewhere to go), **earned-only** at launch with a **dark IAP socket**.

```
THE SPINE — the loop the economy spins on
  ⚡ ENERGY ─1/pop─► generator → items → merge↑ → high tier ─┬─ deliver ─► ★ STARS
       ▲  refill: regen · level-up · daily · 💎              └─ sell ────► 🪙 / 💎 (merchant)
       │
  ★ STARS ─┬─ earned → ▲ LEVEL   (each level grants ⚡ + 💎)
           └─ spent  → restore spots = BUILD the world → built things YIELD 🪙 over time
                                                                    │
  🪙 COINS ◄──────────────────────────────────────────────────────┘
       └─ spent → upgrade builds (↑ yield) · cosmetics      (reinvest → more yield)

  💎 DIAMONDS — premium, earned-only at launch · buys speed, never possibility
```

| Currency | Earned from | Spent on | Role |
|---|---|---|---|
| **Energy ⚡** | regen (+1/2 min, cap 100, offline) · level-ups (+50) · 1 free refill/day · win-back · some spot-buys · premium refill | 1 per pop | **THE pacing friction** — the monetization socket. Everything else is free. |
| **Stars ★** (progress) | quests only (1–3★) | building / unlocks (§8) | The **progress** currency that gates *what you can build*. Never inflates; soft-gated. |
| **Coins 🪙** (soft) | merge drops (~10%) · selling t1–t7 · **building yields (§8)** · shop pack | **building upgrades (§8)** · **generator burst-upgrades (§6)** · customization · basket buy-back | The **soft-economy** currency — it funds the build/upgrade loop, so it finally has real power (not dead cosmetics). |
| **Diamonds 💎** (premium) | level-ups · zone restore · selling a t8 (+1) · cash packs (test-only) | energy refill · bag slot · cosmetic variants | Premium-**shaped**, **earned-only** at launch; IAP socket dark. **Buys speed + looks, never possibility.** |

### The soft-currency loop (coins)

Soft currency **flows in** from the world's **yields** (§8) plus merge drops + selling, and **flows out** into **building upgrades** + customization. This is the engine: *the world pays you, you reinvest in the world.* The governing law still holds — **sinks (upgrades, endless by level) exceed the faucet**, so coins always have somewhere worth going — but the sink is now **functional, not cosmetic**: spending makes the world better *and* pay back more. *(The grove's instances — yield/upgrade rates, customization pricing: see `grove_spec`.)*

> **Resolved (was a standing tension):** earlier, coin sinks were cosmetic-only, so the *motivation* to spend coins was thin ("coins have no power"). The build/upgrade **yield loop** (§8) is the fix — coins fund upgrades that pay back, off the "premium buys speed" line. Keep the invariant: the soft loop stays **earned and capped** (it extends sessions, never self-sustains), and upgrades buy *yield + look*, never the energy friction itself.

### The Shop (the buy-side sink)

The **Shop** (distinct from the merchant's sell-stall, §9) is the **buy-side** — a currency sink and a deliberate **progress shortcut**. It sells:
- **energy** and **coins** (for premium), and **cash → premium packs** (dark IAP, test popups);
- **specific items** — buy a mid-tier piece (coins for low tiers, premium for higher) to **skip the grind** to it; a real shortcut a player can pay for, never the *only* path (on the "buys speed" line);
- **cosmetics / looks** — skins and variants (**coins** for base looks, **premium** for exclusive ones — the "buys looks" sink).

Offers **rotate** (a few at a time) so there's always a fresh, optional reason to spend. *(The grove's instances — shop stock, item-shortcut prices, cosmetic catalogue: see `grove_spec`.)*

---

## 11 · Feature-Flag System

A **registry of everything we add** — so when something breaks, we can flip features off one at a time and find the culprit. Every player-facing alive/juice/assist/onboarding behavior ships behind a **code-level flag** (a `static var` bool in `features.gd`; **unknown id → `true` + warning** so a typo can't silently kill a feature; **all default ON**). Each flag notes *Lives in* (code site) + *Eval* (owner's **keep / improve / cut** verdict). Player toggles (music/sfx/calm) live in Settings, not here.

Flags group as **`assist` · `juice` · `ambient` · `feature` · `ftue`**. A handful of behaviors are **core — indexed but *not* flaggable** (removing one is a design change, not a toggle): `interior_view`, `gate_pause`, `spot_level_gates`. Numeric **tuning dials** (`TIER_ODDS`, `ASK_WEIGHT`, `COIN_DROP_RATE`, `POP_COST`, idle timings) are values, not bools. *(The grove's specific flag list + code sites: see `grove_spec`.)*

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

1. **Diegetic first, chrome second** — anything that can live in the world does; true overlays (Shop, Settings, discovery ladder, confirms) are world objects, never flat lists.
2. **One kit, every screen** — all panels/buttons/chips/icons come from `Look`.
3. **Art carries shape & texture; the engine carries every letter and number** — generated images contain **no text and no numerals, ever** (localization + crispness).
4. **Everything ships twice** — kit-art + code-drawn fallback, identical metrics.
5. **Juice is a vocabulary** (§12).

**Surfaces** — three nine-patch elevations: a Ground band, a Card, a Chip; shadows/glows/accents stay code so elevation is tunable without re-art. **Text law** — every label/number/name is engine text in one bundled rounded font; outline = text over the world, no outline = text on a panel (never both). Numbers always sit beside an icon. **Icon kit** — every glyph is a sprite via `Look.icon(id, px)`; no emoji glyphs in shipped UI (the "emoji purge"). **HUD law** — base canvas **portrait, portrait-locked**; the top bar (wallet + Shop) is the only top-right authority, the Lv + energy chips top-left, and nothing else in the top safe band; the primary CTA is bottom-center; safe areas only via `Look.safe_top/safe_bottom`. The board fills phone width edge-to-edge and height-binds + centers on tablet. **The Shop is a storefront, not a list** — a stall with a banner, wallet strip, and a card grid; unaffordable cards are desaturated but still pressable (→ wiggle + "Need N more"). *(The grove's instances — palette, exact font, type sizes, icon meanings: see `grove_spec`.)*

---

## 14 · FTUE Pattern

Onboarding is **staged** so the screen reveals mechanics in step with the player — no tutorial wall:

- **`ftue_free_pops`** — the first 10 pops cost no energy and are uncounted; the energy meter (1/pop) appears only after, so the opening minute is pure frictionless merging.
- **`ftue_staged_chrome`** — chrome arrives in stages: merchant early, bag a bit later, energy chip after the intro pops.
- **`ftue_feature_spotlight`** — features unlock **one at a time over the early levels** (bag, shop/merchant, …), never all at once. The instant a feature first appears, the game **highlights it** (spotlight + pulse) and plays a **hand-gesture guide** — a mimed **tap or drag** showing exactly how to use it — so the player tries it immediately, learns it, and moves on. **No feature appears unannounced.**

Assist features (idle hint, discovery ladder, ready-✓, sell hints, generator previews) teach the **merge → deliver → spend** loop wordlessly.

---

## 15 · Tech, Build & Save

**Engine:** Godot **4.6**, all logic in GDScript, mobile renderer (ETC2/ASTC), viewport **portrait**, orientation locked portrait, touch-from-mouse on for dev. **No autoloads** — shared systems are `RefCounted` static singletons (`Save.*`, `Audio.*`, `Features.*`, `Econ.*`, `Layout.*`, …) so pure-data modules need no scene presence and headless `-s` test runs resolve them. Target **iOS**; desktop is the dev/test surface.

**Save** (`scripts/save.gd`): versioned **JSON at `user://save.json`** (`SCHEMA_VERSION`), atomic writes (`.tmp` → verify → rename) with a `.bak` last-good fallback; loads **deep-merge over defaults** (never drop unknown keys). Persists `currencies`, board/bag/quest-done/`unlocks`(= spots bought)/variants/hints/pops/rng, and `settings`. **Spend-and-grant is one `save_now()`** so a crash can't take currency without the goods.

**Build & test:** a `Makefile` wraps `run`/`editor`/`test`/`test-one`/`smoke`/`import`/`shot-*`/`ios`/`clean`. **Headless suites** run as SceneTree scripts with no window (core/board/layout/map/quest/save + smoke). **Visual checks** use a `quiet_godot.sh` wrapper — a transient `override.cfg` makes the window born **minimized + unfocusable** so captures never steal focus, render at full res, and self-clean. An **economy sim** (default + greedy bot strategies, extended to a **Monte-Carlo seed-sweep** for the generated-quest model, §7) is the load-bearing **affordability/jam safety net** — never eyeball economy; composite/measure. iOS export via an `export_presets.cfg` "iOS" preset.

**Code-map pattern:** a pure rules engine for tests · a persistent board model · a live board controller + a spend-surface controller drive the loop · a content module holds item lines, generator policy, the quest-generation policy (+ authored gate/milestone quests), and zone/sink data · static singletons for save/features/econ/layout/hud/shop/skin/audio/music/ambient/fx. *(The grove's instances — exact file names, sizes, current state: see `grove_spec`.)*

**Analytics (at launch, not deferred).** You can't tune retention or economy blind, so from day 1 log: the **FTUE funnel** (install → first merge → first delivery → first restoration → D1 return), **retention** (D1/D7/D30, session length & count), **economy flow** (per-currency faucet/sink totals, energy-wall hit-rate, refill usage), **progression** (level/zone reached, quest completion, time-to-first-restoration), **monetization** (even while dark: which IAP popups are shown/tapped), and **virality** (share rate, share→install). Event-batched, offline-queued, privacy-light. *(The grove wires these to its analytics sink — see `grove_spec`.)*

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

---

## 17 · Live-Ops, Events & Sharing

Finite content churns; the genre **retains on a content cadence**, not a one-time campaign. The engine ships an **event framework** so a small team runs recurring beats from **data**, with no new code per event.

### Events — the cadence

An **event** is a time-boxed overlay with its own **mini-track** (a short reward ladder) and, usually, a **limited line**:

- **Limited-time line** — a special generator + item line live **only during the event** (a themed ladder: a holiday bloom, a seasonal harvest). It pops on the same board, its items feed the event's quests, and when the event ends it **retires to the Collection** (§6). A fresh thing to grow that week.
- **Mini-track** — a handful of event goals (deliver N event items · reach event-tier T) paying **event rewards**: premium, energy, and **event-exclusive cosmetics** (the keepsake that proves you were there).
- **Other types, same framework (tuned knobs):** **bonus weekends** (×2 coin drops / cheaper energy), **limited cosmetics** (event-only skins in the Shop, §10), **catch-up bundles** (a discounted spot pack for returning players).
- **Data-driven & additive.** An event is a config — limited-line art + quests + rewards + window — so adding one needs **no engine change**. Events are **additive, never gating**: skipping one costs nothing on the core track (the no-FOMO line); the pull is *desire and novelty*, not punishment.

### Sharing — organic virality

A **"share"** button captures a **screenshot of the player's current world** (their progress at its best) and shares it out; sharing grants a **generous reward** (premium + energy) on a **cooldown** (e.g. once/day) — generous enough to feel worth doing, gated enough not to be farmable. The hook is *show off the world you built* — which only lands if the art earns the screenshot (§16), so sharing and the art bet reinforce each other.

*(The grove's instances — the event calendar, limited-line themes, share-reward sizes: see `grove_spec`.)*
