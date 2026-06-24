# Acorn Forest: Merge! — Game Design Spec

> **Acorn Forest: Merge!** is a free-to-play mobile puzzle (iOS/Android) that inverts the merge genre: instead of building a pile, you *slide* glittering shards together to craft luxury jewels and looks, and you **win by clearing the board to perfectly empty**. The signature idea is "empty is the win" — merge solitaire. The core verb is deliberately spatial: a piece slides through empty cells only and merges with a matching piece only when brought orthogonally adjacent, which turns merging into a genuine sliding-tile puzzle (proven non-confluent: order and routing decide whether a board reaches zero). The brand pillar is fairness — no lives, no energy, never blocked, unlimited undo and restart; you can only solve, never lose. Monetization is cosmetic-led and convenience-only, never pay-to-win.

## At a glance

| Facet | Decision |
|---|---|
| **Working title** | Acorn Forest: Merge! |
| **Platform / model** | iOS + Android, free-to-play |
| **Genre** | Merge solitaire — a spatial **sliding-merge** puzzle ("merge meets the sliding-tile puzzle") |
| **Core verb** | **Drag a piece so it SLIDES through empty cells (rook-style, no jumping, no gravity) onto a cell orthogonally ADJACENT to a matching piece (same `familyId` AND same `tier`); they merge into tier+1 on the target cell, the source cell empties (net −1 occupied cell). NOT "merge anywhere."** |
| **Win condition** | Board perfectly empty → "ZERO — collection complete" |
| **Signature hook** | Goal inversion: every successful action *removes* occupancy; emptiness is the terminal state |
| **Central challenge** | Spatial sequencing on a shrinking board; **free cells are a scarce, load-bearing resource**; bad routing/order can strand a board |
| **Theme** | High-gloss "visual candy" fashion & jewels (gems→rings→…→crowns; threads→bags→…→looks) |
| **Fairness** | No lives, no energy, never blocked; unlimited undo + restart; cannot lose, only solve |
| **Mastery** | 3-star system — 1★ cleared / 2★ no wild used / 3★ no wild + no undo + no restart (hints allowed) |
| **Rescue tool** | **Wild Gem** — a joker that merges with any one adjacent piece (limited parity/space rescue; never required) |
| **Structure** | Authored campaign of **~150 levels (10 worlds × 15)**, gated by level **completion** (not stars); **+30 levels/quarter** |
| **Content pipeline** | Reverse-construction generator → two-engine spatial solver verification → auto-grade → human curation |
| **Meta** | Collection Vault (jewelry-vault / sticker-album); showcased items fill themed Sets → unlock themes & cosmetics |
| **Monetization** | Cosmetics + season pass + cosmetic-QoL subscription (ARPU backbone) + opt-in rewarded ads + convenience packs; **no pay-to-win, no forced interstitials, no energy** |
| **Currencies** | **Glint** (soft) + **Lumen** (premium) + utility tokens (Wild Gem, Hint, Reset Token) |
| **Sessions** | Short, high-frequency: median 4–6 min, 3–5 sessions/day; levels 45–120s at par |
| **Strategy** | Re-founded organic-first: paid UA gated behind a proven LTV:CPI; simplicity + a sharp hook is the wedge |

---

## Table of Contents

1. [Vision, Positioning & Audience](#1-vision-positioning--audience)
2. [Core Mechanics & Rules](#2-core-mechanics--rules)
3. [Difficulty, Level Design & Content Pipeline](#3-difficulty-level-design--content-pipeline)
4. [Meta Progression & Economy](#4-meta-progression--economy)
5. [Monetization & LiveOps](#5-monetization--liveops)
6. [Game Feel, Art Direction, Audio & UX](#6-game-feel-art-direction-audio--ux)
7. [Success Metrics & KPIs](#7-success-metrics--kpis)
8. [Risk Register (consolidated)](#8-risk-register-consolidated)
9. [Open Questions for Pre-Production (consolidated)](#9-open-questions-for-pre-production-consolidated)

> **Canonical references used throughout this document (single source of truth):**
> - **Star rule** → §2.7 (UI restatement in §6.4 defers to it).
> - **Parity law** → §2.2 (general `2^T` form).
> - **Campaign size** → ~150 levels, 10 worlds × 15 (§3.4, §4.5).
> - **KPI targets** → §7.2 Canonical KPI Table (all other sections reference it).
> - **Currencies** → Glint (soft) / Lumen (premium) everywhere (§4.2).
> - **Family roster** → §2.3 Canonical Family Table.
> - **Economy/SKUs** → §4 and §5 are merged into one economy; §4 owns currencies/faucets/sinks, §5 owns the spend catalog and references §4's prices verbatim.

---

# 1. Vision, Positioning & Audience

## 1.1 One-liner

> **Acorn Forest: Merge!** — a no-fail mobile puzzle where you *slide* glittering shards together to craft luxury jewels and looks, and **win by clearing the board to perfectly empty.** Merge solitaire: empty is the win.

Elevator pitch (App Store subtitle length, ≤30 chars each line):

- **Line 1:** "Slide. Merge. Acorn Forest: Merge!."
- **Line 2:** "Empty the board. Never lose."

Long-form pitch (store description opener):

> Every other merge game wants you to *build a pile*. Acorn Forest: Merge! flips it: the board starts full of raw gems and threads, and your job is to craft them into finished jewels and outfits until **nothing is left**. But there's a catch — pieces only **slide** through empty space, so every clear cell is precious. Route matching pieces together, showcase your masterpiece, and chase the perfect "ZERO." No lives. No energy. We never block you. You can only solve it.

## 1.2 The core inversion: "empty is the win"

The signature idea is a **goal inversion** on the merge genre. In conventional merge games the loop is *accumulate* — you spawn pieces, combine them up a ladder, and grow a collection that never really "ends." Acorn Forest: Merge! reframes the identical merge verb as **subtraction toward zero**:

| Dimension | Conventional merge (Merge-2 incumbents) | **Acorn Forest: Merge! (merge solitaire)** |
|---|---|---|
| Win state | Open-ended; fill an order book / grow a collection | **Board perfectly empty → "ZERO — collection complete"** |
| Board over time | Grows (spawners, generators add pieces) | **Only ever shrinks** (no in-level spawning, no gravity) |
| Top of ladder | A trophy item that sits on the board | **Showcase + vaporize** — the item *leaves* the board (net board reduction) |
| Player emotion | Hoarding, "more" | Tidying, mastery, "clean" — the satisfaction of an emptied tray |
| Failure | Run out of space / energy / moves | **Impossible to lose** — only "stranded," recoverable by undo/restart |

**Why this is novel.** "Clear the board" puzzles exist (match-3 collapse, mahjong solitaire), and merge puzzles exist — but the *combination* of (a) a merge verb whose every successful action **removes** occupancy and whose terminal state is **emptiness**, with (b) a no-fail fairness frame, is not a shape the market currently ships. The merge-up motion is universally legible to casual players, yet pointing it at zero instead of infinity produces a fundamentally different, finite, puzzle-shaped experience. **The inversion is the hook; everything else is craft on top of it.**

Merging **two top-tier pieces** of a family triggers the **showcase** animation and the masterpiece sparkles off the board — both the dopamine beat *and* the mechanical engine of "reach zero," because showcasing is the only way occupancy actually drops to nothing rather than just consolidating.

> **Honest design note (where the depth actually lives).** Because no merge can be "wasted" (illegal pairings are simply rejected) and the merge count to clear a board is invariant (§2.5), 100% of the genuine decision-making lives in **which empty cells you route through and in what order**. The merge step is the satisfying *resolution* of a sliding-tile routing puzzle, not the decision itself. We embrace this: the marketed "merge" fantasy is the skin; the depth is spatial routing. §6.2 re-keys the juice signals so they reward the behavior the puzzle actually wants (lane-opening), not just rapid chaining.

## 1.3 This is a SPATIAL sliding-merge puzzle (not "merge anywhere")

This is the most important design truth in the document and it is **load-bearing for the entire product**: Acorn Forest: Merge!'s core is **adjacency + sliding**, *not* a non-spatial "drag any item onto any matching item anywhere."

**The locked rule:**

- A piece merges with another **only** when they are the **same family AND same tier** AND brought **orthogonally adjacent**.
- Pieces **move by sliding through empty cells only.** They cannot pass through or jump over occupied or blocked cells. **There is no gravity** — a piece stays exactly where you leave it.
- A drag of piece A onto matching piece B is a **legal merge iff** A can reach a cell orthogonally adjacent to B via a **clear orthogonal path of empty cells.** The merged result (tier+1) lands on **B's cell**; A's origin cell empties. **Net: −1 occupied cell.**
- **No auto-cascade. No in-level spawning.** Each level is a finite, only-ever-shrinking board.

**Why the spatial rule must never be regressed.** A pure non-spatial "merge anything with any matching thing, anywhere" ruleset is **mathematically confluent** — the order in which you merge does not change whether you can reach zero (it reduces to per-family parity, which is order-independent), so there is no decision, no planning, and therefore **no puzzle**. The adjacency+sliding constraint is the **deliberate fix** that creates the puzzle:

- **Free cells are a scarce, load-bearing resource.** On a tight board, pieces wall each other off; a piece can be sealed away from its only viable partner.
- **Order and routing matter.** Because movement is blocked by occupied cells, a greedy merge order can paint you into a **reachable "stranded" state** from which zero is no longer attainable (recoverable only via undo/restart — never a loss). This non-confluence is proven by the worked example in §2.11.
- The genre fusion is **"merge meets the sliding-tile puzzle."**

Tiny illustration of why path matters (`.` empty, letters = pieces, two `a`'s are same family+tier):

```
Board (4x4):                A wants to merge onto B (the other 'a').
. . . .                     A is at (1,0). B is at (1,3).
a b . a   <- A=left a, B=right a
. c . .                     Adjacent-to-B empty cell = (1,2) or (0,3)/(2,3).
. . . .                     Path A->(1,2): (1,0)->? blocked by b at (1,1). NO direct row slide.
                            A must route: (1,0)->(0,0)->(0,1)->(0,2)->(0,3) [adj to B]. LEGAL.
                            Result: tier+1 lands on B's cell (1,3); (1,0) empties. Net -1.
```

If instead `b` and `c` filled the only routes, A would be **stranded** — a legal-looking position that cannot reach zero. That is the puzzle. **No screen, system, or later section may describe the core as "merge anywhere."**

The **Wild Gem** (a joker that merges with any *one* adjacent piece) is the limited **parity/space-rescue and elegant-solve** tool — the pressure-release valve for exactly the parity and blocking traps the spatial rule creates.

## 1.4 Design pillars

Five pillars. Every feature decision must serve at least one and contradict none.

| # | Pillar | What it means concretely | What it forbids |
|---|---|---|---|
| **P1** | **Empty is the win** | The goal, UI, and reward FX all point at zero; showcasing/vaporizing is the hero beat. | Any "fill / hoard / collect more on the board" framing. |
| **P2** | **Space is the puzzle** | Difficulty comes from free-cell scarcity, sliding-path blocking, and parity — not from timers or RNG. | Regressing to "merge anywhere"; in-level spawning; gravity; auto-cascade. |
| **P3** | **We never block you** | No lives, no energy, never gated by failure. Unlimited undo + restart. You can only solve, never lose. | Energy walls, forced interstitials, fail-states, pay-to-progress. |
| **P4** | **Expensive to the touch** | High-gloss gems/fashion, satisfying merge "click" with rising sparkle pitch, the showcase "poof," gentle haptics, calm aspirational UI. | Cluttered, noisy, "cheap free-to-play" presentation. |
| **P5** | **Mastery you can chase** | 3-star system + a proven-solvable, auto-graded, human-curated campaign so replay rewards skill. | Unfair or unsolvable boards; difficulty by luck; grind without skill expression. |

## 1.5 Target audience

**Primary segment.** Broad casual puzzle players — the people who already play merge and collapse games on commute and couch — **with a deliberate skew toward the fashion / jewelry aesthetic.** This is a **high-LTV, cosmetic-spending** audience: players who convert on *vanity and collection*, not on power.

| | Profile |
|---|---|
| **Demographic** | Skews female 25–55, but the mechanic is gender-neutral; "glossy fashion & jewels" widens the top of funnel rather than narrowing it. |
| **Psychographic** | Tidy/completionist satisfaction seekers; collectors; aesthetic-driven; comfort-game players who value being **relaxed, not stressed**. |
| **Session shape** | Short, high-frequency (see §7.2 for canonical numbers). Levels designed to finish in **45–120s** at par. |
| **Skill spread** | Casuals get the no-fail safety net (undo/restart); the spatial puzzle + 3-star perfect-solve gives depth for the puzzle-hungry minority who drive word-of-mouth. |
| **Monetization disposition** | Spends on **cosmetics, collection completion, and convenience** — never on "winning." Fairness is a *feature* to this segment, not a concession. |

**Why fashion/jewels fits the money model.** The theme maps cleanly onto **showcase value** and **collection sets**: gems → rings → necklaces → crowns; threads → bags → outfits → looks. The aesthetic naturally motivates cosmetic purchases (board themes, gem skins, showcase FX) and a Collection Vault meta — i.e., the **art is the store**. A high-gloss "expensive" presentation signals premium and licenses premium-feeling cosmetic price points without ever touching gameplay fairness.

> **Design response — the "cosmetic with no audience" risk (high severity).** A solo puzzle has no avatar, no browsable profile, no PvP, so a purchased theme is normally seen only by the buyer. Self-expression with no audience collapses to thin completionism, and *cosmetic-only* ARPPU cannot reach the levels social games achieve. We address this two ways: (1) **a visible social surface for cosmetics** — shareable "ZERO" clips that render with your equipped board theme + showcase FX, a browsable friend Vault, and async daily-challenge ghost replays (so the cosmetic *is* seen); and (2) **a cosmetic-QoL subscription promoted to the ARPU backbone** (§5.2), since a relaxed daily-habit comfort audience monetizes better on a predictable subscription than on one-off cosmetics. We have correspondingly **lowered cosmetic ARPPU/conversion assumptions to defensible cosmetic-only-casual levels** (§7.2) rather than planning against social-game numbers.

## 1.6 2026 market positioning

Acorn Forest: Merge! sits **between two giant casual categories** and borrows the legibility of both while owning a gap neither fills.

```
                         MERGE-2 INCUMBENTS                COLLAPSE / BLAST INCUMBENTS
                    (Gossip Harbor, Merge Mansion,        (Block Blast, Toon Blast)
                       Travel Town)
                    --------------------------            ---------------------------
   Verb             merge up a ladder                     place / pop / clear
   Goal             FILL: orders, collections, story      CLEAR a board (but refilled / endless)
   Failure          energy / generators / soft walls      run out of space; lose & retry
   Hook for us      borrow the merge verb's legibility    borrow "clear the board" satisfaction

                                  v   v
                           +----------------------+
                           | ACORN FOREST: MERGE! |
                           +----------------------+
                    Verb : SLIDE pieces, merge adjacent matches
                    Goal : reach ZERO (board perfectly empty), finite levels
                    Fail : none — undo/restart, "we never block you"
                    Edge : spatial sliding-merge puzzle + gloss + no-fail brand
```

**Vs. Merge-2 incumbents.** They win on **content depth, narrative, and meta-economies** built around *accumulation* and energy-gated sessions. We deliberately do **not** compete on story-content tonnage. We compete on a **cleaner, more honest core**: a *finite, solvable, no-energy* puzzle with a novel goal. Our generator-plus-curation pipeline keeps authoring cost low so a long campaign is affordable.

**Vs. collapse/blast incumbents.** They own **dead-simple, instantly-grasped "clear the grid"** mechanics with enormous reach. We share their *clarity* and "tidy the board" payoff but add **planning depth** (sliding-path sequencing + parity) and a **no-fail** frame, wearing a **premium fashion skin** versus their toy/abstract look — lifting us into a higher-LTV cosmetic-spending audience.

**The 2026 wedge.** The macro climate punishes hostile monetization (energy walls, forced interstitials) and rewards trust. "We never block you" is both a brand pillar and a positioning weapon.

> **Design response — discovery / CPI (high severity, accepted with a hard gate).** Our differentiating mechanic is subtractive, planning-heavy, and cerebral — the *opposite* of the dopamine-forward creatives that win cheap installs. Two honest consequences: (a) the differentiator may **raise** CPI rather than lower it, and (b) the "empty the board" reveal is harder to convey thumb-stopping in 6 seconds than a match-3 explosion. We do **not** assert the reveal is a scroll-stopper on faith. Before greenlight we **IPM-test 8–12 real creatives** of the empty-the-board hook against control match/merge creatives and treat measured IPM/CPI as a **hard gate, not a hypothesis**. Fallback creatives lead with the **showcase poof** (the one instantly legible dopamine beat). If the reach-zero creative cannot beat category-median CPI, the simplicity-plus-sharp-hook wedge is invalidated and the project does not proceed at planned scale. See also §1.7 and the re-founded economics in §7.

## 1.7 The 3-part distinctiveness moat (and an honest caveat)

| # | Moat | Strength | Honest read |
|---|---|---|---|
| **M1** | **The merge-solitaire "reach zero" mechanic — now a *spatial sliding* puzzle** | **Strongest.** Goal inversion + adjacency/sliding constraint = a genuinely rare, defensible core. | Mechanics can be cloned, but being first + tuned + branded buys a real lead. |
| **M2** | **Visual gloss** | High-gloss gems/fashion, escalating sparkle pitch, the showcase "poof" — best-in-class feel. | Reproducible with budget; durable only when paired with M1 + M3. |
| **M3** | **The no-fail fairness brand** | "We never block you" — unlimited undo/restart, no lives/energy, no forced interstitials. | A stance, not IP; competitors *could* copy it but rarely do because it caps short-term ARPU. |

**The honest caveat (do not paper over this):** **the fashion/jewels THEME is crowded.** It buys us *fit* (high-LTV cosmetic audience, clean showcase/collection mapping) and *gloss*, nothing more. **The MECHANIC (M1) and the gloss (M2) carry the novelty; the theme is a multiplier, not the differentiator.** Incumbents beat us on content depth and ad spend, so our only viable strategy is **simplicity plus a razor-sharp hook**: ship the cleanest possible expression of "slide to reach zero," make it feel expensive, and never block the player.

> **Design response — the moat is invisible to most players (high severity, partially mitigated).** The spatial depth (M1) only bites for the ~18% who chase 3 stars; the 1-star majority, if handed the game's own dead-end oracle, would experience a glossy non-puzzle competing on exactly the theme we admit is crowded. This is a *real* tension and we confront it in §2.8 (non-proactive stuck-detector by default) and §3.3 (a casual-facing "clean clear" badge so the planning payoff is visible to everyone, not gated behind the hardcore tier). We do not claim it is fully solved; it is a soft-launch trip-wire (§3.7).

---

# 2. Core Mechanics & Rules

This section is the authoritative, build-from-this ruleset. Engineering, level-generation, and the solver all derive from the definitions here. The core verb is **ADJACENCY + SLIDING**: a piece is dragged through empty cells and merges with a matching piece only when brought orthogonally adjacent. This is a deliberate, locked design choice — the alternative "drag any piece onto any matching piece anywhere" rule is mathematically confluent (merge order is irrelevant, so there is no puzzle). The adjacency+sliding rule below is the fix and must not be regressed anywhere.

## 2.1 The Board

| Attribute | Value | Notes |
|---|---|---|
| Grid | Rectangular orthogonal lattice of unit cells | Cells addressed `(row, col)`, row 0 at top |
| Standard sizes | `4×4`, `5×5`, `6×6`, `6×7`, `7×7` | Generator picks per target difficulty; **6×6 is the default** |
| Tutorial sizes | `3×3`, `3×4`, `4×4` | Used in worked example below |
| Max size | `7×7` on phone (8×8 reserved for tablet/future) | Hard ceiling for mobile legibility |
| Cell states | `EMPTY` or `OCCUPIED` (holds exactly one piece) | No stacking, ever |
| Inert cells (optional) | `BLOCKED` (permanent wall) | A topology lever; never passable, never fillable |

A level ships with a fixed set of placed pieces and a fixed set of `BLOCKED` cells (often zero). The count of `EMPTY` cells at level start is the **free-cell budget** — the single most important difficulty dial in the game. **Free cells are a scarce, load-bearing resource:** they are the only space pieces can slide through, so a tight budget makes pieces wall each other off.

## 2.2 Item Families & Tier Ladders

Every piece has a `familyId` and a `tier` (an integer `1…T`, where `T` is the family's top/showcase tier). A piece can only ever merge with another piece sharing **both** the same `familyId` **and** the same `tier`. Production families are **5-tier ladders** (T5 = showcase). The compact tutorial in §2.11 uses a **3-tier** ladder (top/showcase tier `T3`) purely for diagram compactness; the parity law below is stated generally so both are first-class.

**Canonical Family Table (single source of truth; §6.1 conforms verbatim).** Two families ship at launch; the third launches as a campaign-curriculum unlock in W7; two more are reserve/expansion. Each family owns four independent identifiers — hue, material, silhouette, and a tier-shape progression — so it is colorblind-safe (§6.6).

| Family | Status | Hue band | Material | Silhouette | Ladder (T1→T5 showcase) | Base weight by tier |
|---|---|---|---|---|---|---|
| **Gems** | Launch | Cool blue / cyan | Faceted glass | Round / brilliant | Raw Shard → Cut Gem → Ring → Necklace → **Crown** ✦ | 1,2,4,8,16 |
| **Threads** | Launch | Magenta / rose | Soft satin cloth | Rounded, draped | Loose Thread → Swatch → Bag → Outfit → **Runway Look** ✦ | 1,2,4,8,16 |
| **Charms** | W7 unlock | Warm gold / amber | Polished metal & leather | Hard geometric | Clasp → Charm → Bracelet → Handbag → **Statement Piece** ✦ | 1,2,4,8,16 |
| Florals | Reserve | Emerald green | Lacquer / enamel | Floral / organic | Petal → Bloom → Corsage → Bouquet → **Centerpiece** ✦ | 1,2,4,8,16 |
| Pearls | Reserve | Violet / orchid | Iridescent pearl | Spherical / orb | Pearl → Strand → Choker → Tiara → **Pearl Set** ✦ | 1,2,4,8,16 |

> The launch cloth ladder is named **Threads** everywhere; the third family is named **Charms** everywhere. Earlier draft inconsistencies ("Looks", "Accessories") are resolved to these two names. Additional families are introduced gradually across the campaign (§3.4). Multiple families may co-exist on a single board; each is solved independently but all compete for the same shared free cells.

**Weight model (critical for parity and the solver).** A tier-`k` piece is worth `2^(k-1)` *base-equivalents*. A merge is strictly `2→1`: two tier-`k` pieces become one tier-`(k+1)` piece, conserving weight (`2·2^(k-1) = 2^k`). A **showcase** is the merge of two top-tier pieces; for a family whose top tier is `T`, it consumes `2^(T-1) + 2^(T-1) = 2^T` base-equivalents and removes them from the board.

> **Parity law (per family, general form).** A family whose top/showcase tier is `T` can be cleared to zero **iff its total weight is an exact multiple of `2^T`** (the cost of one showcase). For the **production 5-tier ladder, `2^5 = 32`**; for the **3-tier tutorial ladder, `2^3 = 8`**. Any family whose total weight is not a multiple of `2^T` contains a permanent parity orphan and can never reach zero. The generator must guarantee `weight(family) ≡ 0 (mod 2^T)` for every family on every shipped board, using that family's actual `T`. (This generalizes the earlier "mod 32" statement so the §2.11 tutorial board — weight 16, `T=3`, i.e. `16 = 2 × 2^3` → two showcases — is consistent with the law rather than an admitted exception.)

## 2.3 Movement Rule — Slide Through Empty Cells

Pieces move by **sliding**, rook-style, along a single orthogonal direction:

1. A drag begins on an occupied source cell `A`.
2. From `A`, the piece may travel up, down, left, or right.
3. It passes **only through `EMPTY` cells.** It **cannot pass through or jump over** any `OCCUPIED` or `BLOCKED` cell, and cannot leave the grid.
4. It may **stop on any empty cell** along that clear path (it is not forced to slide to the wall).
5. **There is NO gravity.** A piece stays exactly where the player releases it. Nothing settles, falls, or auto-arranges.

A pure slide (releasing on an empty cell, not onto a partner) is legal and changes nothing but position. It is the player's primary tool for clearing paths.

```
Reachable cells (·) for the piece P sliding orthogonally; X = blocker, . = empty
  . · · X        P slides right until X; up to the top edge; down one cell.
  · P · ·        It CANNOT reach the cell past X, nor any diagonal cell.
  · · X .
```

## 2.4 Merge Rule — Adjacency (stated precisely)

> A drag of piece `A` toward a matching piece `B` (same `familyId`, same `tier`) is a **LEGAL MERGE** if and only if `A` can reach a cell **orthogonally adjacent** to `B` via a clear orthogonal sliding path of empty cells (per §2.3). "Reach" includes the degenerate case where `A` is **already** orthogonally adjacent to `B` (zero-distance slide).

On a legal merge:

- `A` slides to the chosen empty cell orthogonally adjacent to `B` (or is already there).
- The two pieces combine. The **result lands on `B`'s cell** at tier `tier+1`.
- **`A`'s source cell becomes `EMPTY`.** (`A`'s transient adjacent landing cell is also empty afterward — only `B`'s cell stays occupied.)
- **Net effect: exactly one fewer occupied cell** (`2→1`).

Hard constraints, all locked:

- **NO gravity** (pieces never move on their own).
- **NO cascade / NO chain reaction.** One drag = one merge. The new tier-`(k+1)` piece does **not** auto-merge with a neighbor even if one matches; the player must drag again.
- **NO in-level spawning.** No new pieces ever appear mid-level. Occupied-cell count is monotonically non-increasing.
- A merge **of two top-tier (`TT`) pieces** triggers the **showcase** (§2.6): no higher tier exists, so instead of combining, both pieces vaporize — net `2→0` for that one merge.

If a target is selected but no clear adjacent path exists, the drag is **rejected** (no state change, gentle "no" haptic + shimmer). The UI previews legality during drag (highlights reachable cells and valid partners, §6.4).

**Two valid landing cells adjacent to the same partner.** If a slide could stop at more than one empty cell adjacent to `B`, the result is identical (lands on `B`) regardless of which adjacent cell `A` passes through; the engine picks the shortest path for animation. No ambiguity in outcome.

## 2.5 Move Counting & Par — why par is on DRAGS, not merges

This is the load-bearing definition the star system, the solver, and the HUD all derive from. Read it carefully.

- **The merge count to clear a fully-clearable board is INVARIANT.** Each merge removes exactly one occupied cell, and the target (empty board) is fixed, so the number of merges is determined entirely by the board, independent of order or routing. The exact count is:

  > `merges = startingPieceCount − showcaseCount`, where `showcaseCount = Σ_family weight(family) / 2^T_family`.
  > **Proof:** if `P` pieces are placed and `s` showcases occur, the non-showcase merges number `merges − s` (each is `2→1`) and the showcase merges number `s` (each consumes 2 top-tier pieces). Total pieces consumed = `(merges − s)·1 produced + … ` resolves to `P = (merges − s) + 2s`, hence `merges = P − s`. ∎

  *(There is no "W/2 merges" rule — that earlier formula was wrong. Example: a 5-tier family `{T5,T4,T3,T2,T1,T1}` has `W=32` but clears in 5 merges, not 16; an all-T1 family of `W=32` is 32 pieces and clears in 31 merges. Only `merges = P − s` is correct.)*

- **Because merge count is invariant, par-on-merges carries zero scoring information** — every completed clear hits it. It therefore **cannot** discriminate skill and is **not** used as a star gate anywhere.
- **The meaningful efficiency axis is DRAGS (slides + merging-drags).** Sloppy play wastes *repositioning slides* shuffling pieces around to open paths; optimal play minimizes them. The solver computes `par_drags` = minimum total drag actions to reach zero. Internally we still log slides for analytics and difficulty grading.

> **Par = `par_drags`** (the solver-minimum total drag count). The star gates (§2.7) use `par_drags` for the efficiency star, never merge count. This keeps the mastery chase honest: the challenge is *sequencing and routing*, not grinding extra moves.

## 2.6 Showcase / Vaporize

When **two top-tier (`TT`) pieces are merged** — no higher tier exists, so instead of combining they are *showcased*:

1. The finished masterpiece plays the **showcase animation** (the hero "poof" — sparkle pitch peaks, the piece rises, glints, vaporizes).
2. **Both top-tier pieces leave the board** (both cells become `EMPTY`; net `2→0`).
3. The showcased masterpiece is recorded into the **Collection Vault** (§4) and pays out soft currency.

Showcase is the only exit pieces have. A board reaches zero precisely when every family has been fully showcased away.

**Showcase → Vault item mapping (so a board can be known to feed a given Vault slot).** Each authored top-tier item is a **named variant** (e.g. "Marquise Crown"). A board declares, at curation time, which named showcase variant(s) it produces for each family; `showcaseCount` per family (from §2.5) tells exactly how many. The curator assigns boards to Vault Sets so that early Gem boards produce exactly the Crown variants the early Sets need (§4.1). Generic "any Crown fills any open Gem slot" is **not** used — slots are specific, and the board→slot feed is an explicit curation field.

## 2.7 Win Condition & Mastery — the LOCKED star rule

- **Win (per level):** the board is **perfectly empty** — every cell `EMPTY` (or `BLOCKED`). On the final showcase the game declares **"ZERO — collection complete."** There is no other win state and no partial-credit clear.

**3-star mastery (this is the single canonical definition; §3.3 and §6.4 defer to it verbatim):**

| Stars | Condition (all must hold) |
|---|---|
| **★** | Board reached perfectly empty (the win). Always achievable; never blocked. |
| **★★** | 1★ **AND** `wilds_used == 0` **AND** `drags_used ≤ par_drags + max(2, ceil(0.15 × par_drags))` (efficient — see tolerance note) |
| **★★★** | 2★ **AND** `wilds_used == 0` **AND** `undo_count == 0` **AND** `restarts_this_attempt == 0` **AND** `drags_used ≤ par_drags` (optimal routing, clean, unaided) |

- **Hints are allowed at all star tiers.** Only wild gems, undo, and restart gate the higher stars. (A hint reveals one next safe move; it teaches, it does not solve — §6.4.)
- **Efficiency tolerance (fixes the "15% rounds to zero" problem).** The 2★ drag budget uses an **absolute-plus-relative** band: `par_drags + max(2, ceil(0.15 × par_drags))`, guaranteeing **≥ 2 slack drags on any board size**. A bare `×1.15` collapses to zero slack on small/tight boards (par 4 → 4.6 → 4 → 0 slack) exactly where one repositioning mistake should still earn 2 stars; the `max(2, …)` floor prevents that.

Rationale: merge count is fixed (§2.5), so the meaningful skill axes are *solving the spatial routing efficiently* (drag-par), *solving it unaided* (no wild), and *solving it without backtracking* (no undo/restart). ★★★ is a genuine "I saw the whole clean line" achievement and drives replay.

> **Edge case — wild-required levels:** on a level where a wild is *required* to reach zero, ★★ and ★★★ are unattainable by the "no wild" rule **by design**. We mark these with a distinct **★-max crest** ("Best: ★ — wild-locked") so the cap reads as intentional, and keep them to **< 8% of campaign levels** (§3.4).

## 2.8 No-Fail Contract (brand pillar)

- **NO lives, NO energy, NO timers, NEVER blocked.** Any unlocked level is always immediately playable.
- **UNLIMITED undo** — zero cost. Undo reverses exactly one prior step (merge or slide), restoring the precise prior board state, including un-showcasing a piece if the undone step was a showcase (§2.9). Undo stack depth is the full move history of the current attempt.
- **UNLIMITED restart** — zero cost. Restart resets the board to its authored starting state.
- **The player cannot LOSE — only solve.** A board can reach a **stranded** state (§2.9) from which zero is unreachable, but stranded is **never a loss**: it is fully recoverable via undo or restart. There is no "game over," no failure screen, no penalty beyond forfeiting a clean star tier if the player chooses to undo.

> **Design response — does no-fail + unlimited undo + a stuck-detector collapse the puzzle? (high severity).** The danger: the optimal 1-star strategy becomes "merge anything; when the game warns you're stuck, undo and pick differently" — the game supplying its own dead-end-pruning oracle, so zero lookahead is needed. **Resolution (locked):** the shipped stranded-detector is **non-proactive by default** — it does **not** auto-prompt "looks stuck." Strandedness is surfaced only via an **opt-in "Am I stuck?" button** (resolving Open Question §9). This forces casual players to notice strandedness themselves, restoring a gentle real consequence loop. Additionally, every player (not just 3-star chasers) can earn a lightweight, persistent **"clean clear" badge** (cleared with no undo) per level, so the planning payoff is visible to casuals and not gated behind the prestige tier (§3.3). Soft-launch trip-wire: if median undos/cleared-level > 8 **and** 3-star attempt rate stays low, players are brute-forcing and the undo/stuck affordances tighten (§3.7, R6). We accept that undo *remains unlimited* (brand-locked); consequence is relocated to mastery and to self-noticed strandedness, not to a fail state.

## 2.9 Edge Cases (exhaustive)

**Orphan.** A piece is an **orphan** if it can *never* be brought into a legal merge for the rest of the level. Two causes:

1. **Parity orphan** — its family's remaining total weight is not a multiple of `2^T` (§2.2). Parity is invariant under **normal** merges, so a board that started parity-clearable stays parity-clearable; parity orphans therefore exist only on malformed boards and are a generator/QA assertion, not a play state. **Wild caveat:** a wild merge *adds* `2^(j-1)` weight to a family (§2.10), so wild use *can* shift a family's parity — the solver must account for this explicitly; see §2.10 and §3.4.
2. **Spatial orphan** — its family parity is fine, but the piece can never be slid to a cell adjacent to any current-or-future viable partner because occupied/blocked cells wall off every path. This is the *real, reachable* hazard and the heart of the puzzle.

**Stranded state.** A board is **stranded** if it is non-empty and **no legal merge exists** *and no sequence of slides can create one that leads toward zero*. Authoritative detection is the offline solver's reachability check. The shipped runtime detector is **best-effort only** (see Design response below) and never auto-declares failure.

**Can a showcase be undone?** **Yes.** A showcase is just the merge that produced the top tier; undo reverses it, returning both top-tier pieces to the board and removing the *provisional* Vault credit and soft-currency payout (they re-grant on re-showcase). The Vault treats per-attempt showcase credits as provisional until the level is completed/abandoned, avoiding double-counting via undo.

**What does restart reset?** Restart restores the **authored starting board** (piece positions, tiers, blocked cells, free-cell budget) and clears the current attempt's move history, undo stack, provisional Vault credits, and provisional soft currency. A wild consumed within the attempt is **refunded** on restart (the attempt is voided). Restart does **not** touch permanent Vault contents from previously completed levels, owned cosmetics, the wild inventory carried in, or campaign star records. Using restart forfeits ★★★ for that clear.

**Drag that touches a non-matching piece.** Rejected; no state change.

**Single piece of a tier with no current partner.** Not (yet) an orphan if a partner can be *built* from lower tiers (e.g. one lone T3 with two T2s that can become a T3). The solver accounts for future-built partners. It is only a spatial orphan if no built-or-existing partner can ever be reached.

> **Design response — the runtime stuck-detector cannot prove global strandedness (medium severity).** A depth-3 local lookahead (§3.5) cannot distinguish a truly stranded board from one whose solution needs 4+ setup slides — exactly the `D≥4` late/boss boards. We therefore state plainly: **the runtime detector is best-effort and does NOT guarantee detecting all stranded states.** This is acceptable because **undo/restart always recover**, so a missed detection costs the player nothing. The shipped per-level **stranded signature** (bloom-filter style, ~16 KB) stores only **minimal stranded states within K=6 moves of the start** (an explicit, bounded coverage contract engineering can build to); it is not, and is not claimed to be, complete. §2.9, §3.5, §6.2(g), and §7.3 all use this single "best-effort, recovery-guaranteed" framing.

## 2.10 The Wild Gem (joker / parity & space rescue)

The **Wild Gem** is the single deliberate rescue and elegant-solve tool.

- **What it does:** a Wild Gem merges with **any one orthogonally adjacent piece**, regardless of family or tier. It obeys the **same adjacency+sliding movement rule** as every other piece — it must be slid to a cell orthogonally adjacent to its target via a clear empty path.
- **Result:** the wild "becomes" a second copy of the adjacent target and performs that merge — the target advances one tier (`Tk → T(k+1)`) on the target's cell, and the wild's source cell empties. If the wild merges with a top-tier piece, it triggers a showcase. Net `2→1` (or `2→0` on showcase).
- **Weight effect (must be modeled — the parity-invariance claim of §2.9 holds only for normal merges):** applying a wild to a tier-`k` target **adds `2^(k-1)` base-equivalents** to that family (the wild contributes a "free" copy). A wild used on a top-tier piece therefore triggers a showcase that removes only `2^(T-1)` of *real* weight (one real top-tier piece), not the full `2^T` a normal showcase removes. The solver must treat wild merges as weight-adding events, not weight-neutral ones.
- **One-shot per use:** each Wild Gem is consumed on use.
- **How earned (never required):** boards are always free-solvable *without* any wild, so wilds are pure convenience. Sources: daily reward/streak, rewarded ad, convenience pack (IAP). Wild gems do **not** in-level spawn — they are an inventory item placed at the start of, or during, an attempt from owned stock.
- **Limits:** a soft cap of **9 owned** at once (overflow converts to soft currency). Using **any** wild forfeits ★★ and ★★★ (§2.7).

**Wild-required level specification (so these boards are buildable and the "only path" guarantee is real).** A wild-required family must have weight `= 2^T·k − 2^(j-1)` for some tier `j` and integer `k≥1`, where a buildable/reachable tier-`j` partner exists so that applying the provided wild at tier `j` raises the family's weight to the next multiple of `2^T`. The two-engine solver (§3.5, §8 R4) must verify the board is clearable **only** via the intended wild application and **not** trivially clearable by misapplying the wild on another family/tier (which could push a *different* family off-parity). **Par on wild-required boards is recomputed from the actual wild-assisted solution** (the uniform `2^T`-chunk exit assumption no longer holds once a wild is spent).

## 2.11 Fully-Gridded, Verified Worked Example

A single `3×3` board, **one family**, **3-tier ladder** (`T=3`; the top tier `T3` is the showcase tier — merging two `T3` pieces showcases them, per §2.2), with one **wall** (a "display-case" fixture, `#`). Total piece weight = 16 base-equivalents = `2 × 2^3` → two showcases' worth, clearable per the parity law (`16 ≡ 0 (mod 2^3 = 8)`).

> **Verification status (honest).** Every claim below was checked by **exhaustively enumerating the board's entire reachable state space (1,709 states)** with a slides+merges engine — not by inspection. An earlier draft of this section used a *loose, wall-free* board and asserted a "stranded" position that is in fact fully solvable; that was wrong, and it taught a lesson now baked into §3.1: **open boards (many free cells, no walls) are effectively confluent — they cannot strand and so are not yet a puzzle.** Genuine stranding requires *tightness and/or walls*. This example uses a wall precisely so the stranding is real and reachable.

**Notation.** `(r,c)` = row, col, 0-indexed, top-left `(0,0)`. Digits = tiers; `#` = wall; `.` = empty.

**START** (7 pieces — four `T1`, three `T3`; one empty cell at `(1,0)`):
```
        col0 col1 col2
row0      1    3    3
row1      .    #    1
row2      1    1    3
```
`showcaseCount = 16 / 2^3 = 2`, so the **merge count is fixed at `7 − 2 = 5`** for any clear (§2.5). The verified optimal clear below uses **6 drags** — 5 merges **plus one pure repositioning slide** — so **`par_drags = 6`**. That extra slide is the whole point: *routing*, not merging, is the skill.

### A. A correct order → ZERO (6 drags, verified)

1. **Showcase.** `T3 (0,1)` + `T3 (0,2)` are adjacent → **SHOWCASE** (both vaporize).
```
1 . .
. # 1
1 1 3
```
2. **Merge.** Slide `T1 (2,0)` right onto `T1 (2,1)` → **T2 on (2,1)**.
```
1 . .
. # 1
. 2 3
```
3. **Repositioning slide (no merge — the routing move).** Slide `T1 (1,2)` up into the empty `(0,2)`.
```
1 . 1
. # .
. 2 3
```
4. **Merge.** Slide `T1 (0,2)` left onto `T1 (0,0)` → **T2 on (0,0)**.
```
2 . .
. # .
. 2 3
```
5. **Merge.** Slide `T2 (0,0)` down the left column to `(2,0)`, adjacent to `T2 (2,1)` → **T3 on (2,1)**.
```
. . .
. # .
. 3 3
```
6. **Showcase.** `T3 (2,1)` + `T3 (2,2)` adjacent → **SHOWCASE** → board empty → **"ZERO — collection complete."**
```
. . .
. # .
. . .
```
5 merges + 1 routing slide = **6 drags = `par_drags`**, no undo, no wild → **★★★**.

### B. A greedy order → STRANDED in one move (verified)

From START, the obvious move is to merge the two left-column `T1`s. Slide `T1 (2,0)` **up** through the empty `(1,0)` onto `T1 (0,0)` → **T2 on (0,0)**:
```
2 3 3
. # 1
. 1 3
```
This board is **stranded** — **exhaustive search of all 448 reachable continuations finds none that reaches ZERO.** Parity is still fine (weight 16); the failure is purely *spatial*: that one merge spends the left-column maneuvering room, and the central wall then makes it impossible to route the survivors (the lone `T2`, the two stray `T1`s, and three `T3`s) into the adjacencies a clear needs.

> **Stranded ≠ lost.** One free **undo** (or **restart**) returns to START, where Order A still clears. The player simply made the greedy merge instead of the routing slide (step 3 of Order A). **Same board, same pieces — order and routing decide everything.** This is the non-confluence the whole design rests on, and — unlike the earlier draft — it is now exhaustively verified.

### C. Arithmetic & parity checks (self-checked)

- **This board:** four `T1` + three `T3` → weight `4·1 + 3·4 = 16`. `T=3` ⇒ clears iff weight `≡ 0 (mod 2^3 = 8)`; `16 = 2 × 8` ✓. Two showcases; merges `= 7 − 2 = 5`; `par_drags = 6` (one routing slide). ✓
- **Production 5-tier ladder:** tier weights `1,2,4,8,16`; one showcase = two `T5` = `32 = 2^5`. A 5-tier family clears iff total weight `≡ 0 (mod 32)`. ✓
- **Clearable 5-tier inventory:** `T5,T4,T3,T2,T1,T1 = 16+8+4+2+1+1 = 32` → one showcase; merges `= 6 − 1 = 5`. ✓
- **Parity orphan (rejected by generator):** weight `30 = T5,T4,T3,T1,T1` is not a multiple of 32 → can never reach zero regardless of space. ✓

---

# 3. Difficulty, Level Design & Content Pipeline

This section defines *what makes a level hard*, *how we measure it*, *exactly how stars are earned* (deferring to §2.7), and *how we manufacture levels cheaply at campaign scale*. Everything rests on the locked core verb (adjacency + sliding, no gravity, no jumping, no auto-cascade, no in-level spawning). Difficulty is **not** reflexes or pattern-spotting speed; it is **spatial sequencing on a shrinking board where free cells are the scarce resource.**

> Non-negotiable framing reminder: pure "drag any item onto any matching item anywhere" was proven confluent (order-independent ⇒ no puzzle; §2.11 proves the spatial rule is non-confluent). Nothing here may quietly assume teleport-merge.

## 3.1 The Theory of Difficulty (Adjacency + Sliding)

A level is a tuple: a grid (with optional walls), placed pieces (each `familyId` + tier), a free-cell budget, and 0+ wild gems. Every merge is `2→1` (net −1) and a top-tier merge vaporizes (net −1, no replacement), so the board can *only ever shrink*. The difficulty question is therefore never "can it shrink?" but **"can it shrink all the way to zero given that movement is blocked by occupancy and a bad order can strand pieces?"**

Eight levers, roughly descending impact:

#### Lever 1 — Free-cell tightness (PRIMARY)

`F = playable_cells − pieces`; occupancy density `ρ = pieces / playable_cells`. `F` is the load-bearing dial.

| Tightness | `F` | Typical `ρ` | Feel | Used in |
|---|---|---|---|---|
| Open | `F ≥ 8` | ≤ 0.55 | Almost confluent; teaches the verb | Tutorial / early |
| Comfortable | `F = 5–7` | 0.55–0.68 | Light lookahead | Early-mid |
| Tight | `F = 3–4` | 0.68–0.80 | Real sequencing; first strandings | Mid |
| Knife-edge | `F = 2` | 0.80–0.88 | Most paths fail; one solution-shape | Late |
| Pinhole | `F = 1` | > 0.88 | Sliding-tile-puzzle hard; rare, marquee | Boss / hard-mode |

`F` **increases** as you play (every merge frees a cell), so a tight board *opens up* once the right first moves are made. `F = 0` is illegal at generation (no slides possible).

> **Design response — the tension curve runs backwards (high severity).** Because `F` grows as you play, naive levels peak at the *opening* then "breathe out" to an autopilot cleanup tail — every level ends easy, with the only late juice being the showcase FX (a reward, not a cognitive payoff). Good puzzles climax. **Fix (locked as a generator + grading constraint):** engineer a *meaningful late decision*. We add an explicit auto-grade metric **"decision recency"** = the move-index of the last forced/uniquely-correct move as a fraction of solution length; a level whose last 60% is all safe moves is **down-ranked**. Concretely, the generator biases topology so at least one parity/spatial fork re-tightens `F` late (e.g. an early showcase frees cells, but a late choke forces one last held breath), and on multi-family boards we **stagger** difficulty peaks so clearing family A's showcase re-opens lanes that create family B's hardest fork. This converts "breathe out" into "breathe out, then one last held breath."

#### Lever 2 — Blocking topology

Two boards with identical `F` differ wildly by *where* empties/walls sit and how pieces partition the grid into **sliding regions**. Hardness-increasing: corridors / 1-wide channels; choke points (one cell whose occupancy splits the board); walled cells (themed "display cases"); interleaved families (A walls in B); corner pinning.

```
  Easy topology (F=4, open)        Hard topology (F=4, corridor+choke)
  . . r . g                        # . r . #
  . . . . .                        r . # . g
  g . . r .                        . . o . .   <- 'o' choke: occupied => splits board
  . . . . .                        # . # . g
                                   r . . . #
```

#### Lever 3 — Spatial sequencing / lookahead depth `D`

`D` = the longest prefix of the shortest solution where the set of "safe" moves (zero still reachable) is a small strict subset of legal moves. `D=0–1` open; `D=2–3` mid; `D=4–6` late; `D≥7` expert/boss. `F` is the lever; `D` is what players *feel*.

#### Lever 4 — Parity traps

Per family, propagate counts up the ladder; a family is *parity-clean* iff every tier's `(n_t + carry)` is even and the top tier yields ≥1 clean showcase. A **parity trap** is count-solvable but a family is not parity-clean by itself. Two flavors: **Honest parity** (early/most levels — every family clean, no wild) and **Wild-required parity** (selected mid+ levels — exactly one family short by a wild-repairable amount per §2.10; the level ships with exactly one wild and the only zero-path uses it). We never ship a level that is parity-impossible even with provided wilds (§3.5).

#### Lever 5 — Family count

Default ceiling **3 concurrent families** in normal campaign levels, **4** on boss/daily.

#### Lever 6 — Board size

Bigger ≠ harder (often adds free cells). Used for session length and topology room.

| Context | Grid | Playable cells (after walls) |
|---|---|---|
| Tutorial | 4×4 | 12–16 |
| Early campaign | 5×5 | 18–25 |
| Mid campaign | 6×6 | 26–34 |
| Late / boss | 7×7 (rarely 8×6) | 36–44 |

Cap 49 cells (7×7 on phone).

#### Lever 7 — Wild-gem scarcity

0 wilds (default for clean honest puzzles, most of the campaign); 1 wild (wild-required levels or a generous training wheel); 2 wilds (rare, hardest bosses — one required, one slack).

#### Lever 8 — Par-drag targets

Each level ships `par_drags` (§2.5). Tighter par raises perceived difficulty by removing "wasteful but safe" lines.

## 3.2 How the Levers Combine

`F` sets the floor; topology + family count set the shape; `D` is what you feel; parity + par + wild-scarcity are the seasoning. The auto-grader (§3.7) folds all eight (plus decision-recency from §3.1) into one number.

## 3.3 Star Definition (defers to §2.7) + casual-facing planning hook

The canonical star rule lives in **§2.7** and is not restated with different numbers here. To summarize the engineering contract:

- **Par is on DRAGS** (`par_drags`), never merges (merge count is invariant, §2.5). This is the only metric that discriminates skill, and it does **not** make the game a "slide-minimization puzzle" because slides are only *minimized at the optimal-routing tier* (3★); the 2★ band gives generous absolute-plus-relative slack (`+max(2, ceil(0.15·par_drags))`).
- **1★** = cleared. **2★** = cleared, 0 wild, drags ≤ `par_drags + max(2, ceil(0.15·par_drags))`. **3★** = 2★ conditions + drags ≤ `par_drags` + 0 undo + 0 restart. Hints allowed at all tiers.

> **Design response — make planning visible to the 1-star majority (high severity).** The 3-star chase is invisible to casuals. We add a separate, lightweight **"Clean Clear" badge** any player earns by clearing a level with **0 undo** (independent of drag-par and wilds). It is a small, persistent per-level crest (and a campaign-wide "clean-clear streak") shown on the level node — *not* the prestige 3-star tier. This gives the casual a concrete, achievable reason to plan rather than brute-force, surfacing the spatial depth (M1) to the audience that decides commercial outcomes, without changing the star math.

> **Design response — replay depth is one-attempt-thin (medium severity).** Once a player has *found* the clean line (often during the undo-assisted 1-star clear), re-inputting it for 3★ is muscle memory, not a puzzle. **Mitigation (chosen): variant-seed 3★.** Earning the prestige 3★ on a level can be done on the level's authored layout *or* on a **procedurally generated same-band variant seed** of that level (same difficulty grade, different layout) — re-derivation, not re-input, leveraging the pipeline we already run. This multiplies replay depth at near-zero authored-content cost. We also explicitly **downgrade "3★-replay" from sole core retention loop to one of several**, leaning D30 on the Vault + dailies + variant-seed chase (§4.6, §7).

## 3.4 Difficulty Curve & Family-Introduction Schedule

The campaign ships at launch as **~150 levels across 10 themed Worlds (Collections) of 15 levels each**, with **+30 levels per quarter** via LiveOps. Worlds are gated by **level completion** (clear 12 of a world's 15 levels to open the next), **not** by stars — see §4.5 for why a star gate was removed (it would hard-wall the 1-star majority and break the no-fail brand).

#### Macro curve

```
Difficulty score (0–100, see §3.7)
100 |                                          . . *  (boss spikes)
 80 |                              . . *     *
 60 |                    . . * . *     . . *
 40 |          . . * . *
 20 |  . . * .                  ^ each world ends on a +spike "boss" level
  0 +----------------------------------------------------------
     W1   W2   W3   W4   W5   W6   W7   W8   W9   W10
```

Within each 15-level world: a gentle 1→11 ramp, a brief dip at 12–13 (breather), then a two-level spike (14 = hard, 15 = boss). World-to-world the baseline rises (tighten `F`, add topology, then family count), but every new world opens its first 2 levels back up (`F` generous) to re-onboard.

#### Family-introduction schedule

| World | New family / mechanic | Concurrent-family cap | Dominant levers | Typical `F` |
|---|---|---|---|---|
| W1 — First Sparkle | **Gems** | 1 | Verb tutorial; sliding; adjacency; **early blocked-path lesson (see §6.5)** | 8+ → 6 |
| W2 — The Setting | (deepen Gems) | 1 | First real tightness; par intro | 6 → 5 |
| W3 — Thread & Cloth | **Threads** | 2 | Two families; interleaving | 6 → 5 |
| W4 — Tight Quarters | (none) | 2 | `F=3–4`; corridors; first strandings | 4–5 |
| W5 — The Wild Gem | **Wild gem** | 2 | Wild as rescue; first wild-required | 4–5 |
| W6 — Display Cases | **Walls** (fixtures) | 2 | Walled topology; choke points | 4 |
| W7 — The Trinity | **Charms** (3rd family) | 3 | Family count = 3; lookahead `D≥4` | 3–4 |
| W8 — Parity Lessons | (none) | 3 | Parity traps; wild-required cluster | 3–4 |
| W9 — Knife-Edge | (none) | 3 | `F=2` knife-edge; tight par | 2–3 |
| W10 — The Atelier | **Mixed-ladder showpieces** | 3 (4 on boss) | All levers; pinhole boss; late-decision forks | 2–3 (1 on boss) |

New mechanics always debut on an open board (`F≥6`) with a guided first instance, then immediately re-used under tightening. Wild-required levels stay **< 8% of the campaign** and are ★-max-crested (§2.7).

## 3.5 Procedural Generation + Solver Validation + Curation Pipeline

```
[1 GENERATE] --boards--> [2 SOLVE/VALIDATE] --solvable+metrics--> [3 AUTO-GRADE] --score--> [4 HUMAN-CURATE]
   reverse                two-engine spatial          single 0-100             pick & order into
   construction           state-space search          difficulty score         campaign slots; theme
        ^                          |
        |__________ reject & resample if unsolvable/out-of-band ___|
```

#### Stage 1 — Generation by REVERSE CONSTRUCTION

We build boards *backwards from the empty win state* so a zero-path is guaranteed by construction:

1. Choose the spec (grid, wall mask, target `F`, family set, ladders, wild count, difficulty band).
2. Start empty (the win state).
3. Apply inverse operations (time-reverses of legal forward moves): **inverse-merge** (split a tier-`t` piece into a tier-`t−1` in place plus a second on an adjacent empty cell, then inverse-slide that second piece back along a clear corridor — guaranteeing the forward merge had a clear path); **inverse-slide** (move a piece backward along a clear corridor, used to scramble starts and carve corridors/chokes). Top-tier showcase inverse-merges lay down two tier-`(T−1)` pieces from "nothing."
4. Stop when piece count hits `playable_cells − F` and the requested mix is present.
5. **Topology shaping** for the requested band (1-wide channels, corner pins, interleavings for harder; dispersed empties for easier), **and bias for the §3.1 late-decision metric.**
6. **Parity/wild wiring** for wild-required boards (one inverse op consuming a "wild," per the §2.10 weight constraint).

Because every step reverses a *legal* forward move, the forward sequence is a valid zero-path — solvability is guaranteed **by construction**, before the solver runs.

#### Stage 2 — TWO-ENGINE SPATIAL SOLVER (correctness-critical)

This is the canonical home of the verification requirement (no longer only in the risk register). The solver searches the **true spatial state space** (board config + wild inventory; edges = slides, merges, wild-merges). It is emphatically **not** a parity/count check.

- **Engine A (generation-side):** A* over states, cost = drags, admissible heuristic = per-family ladder-collapse distance + a displacement term (pieces not yet adjacent to a viable partner). Produces `par_drags`, `D`, count of distinct optimal lines, decision-recency.
- **Engine B (independent re-verification):** IDA* with a symmetry-canonical transposition table (up to 8 dihedral × family-label permutation symmetries collapsed, 8–40× cut). **Every shipped board is independently re-verified by Engine B; a board ships only if both engines certify a zero-path, and the witness solution is stored.**
- **Mandatory full independent verification is required for any board that bypasses the construction guarantee:** resampled boards, human-tweaked boards, and any board whose `par`/tolerance was hand-edited. (Per §3.4 curation, humans may tune; those edits void the by-construction guarantee and force re-proof.)
- **Golden-set regression:** a fixed corpus of hand-verified boards re-runs on every solver change.
- **Stranded-state enumeration (for the runtime signature):** Engine B enumerates **minimal stranded states within K=6 moves of start** to build the per-level ~16 KB bloom-style signature (the bounded coverage contract of §2.9).

**Offline search bounds:** depth cap 2× construction-path length; node cap 2,000,000/board; time cap 3 s/board/core. Over-cap boards are rejected and resampled. Typical 6×6/3-family boards solve in 20–200 ms; 7×7 knife-edge in 0.5–2 s.

> Reconciliation note: §3.5's "by construction ⇒ existence search unnecessary" applies only to *unedited* generated boards. Because curation tweaks and resampling exist, the two-engine cross-check (formerly only in R4) is part of the **canonical pipeline**, and the worst-case "certified-but-unsolvable" failure mode is real for edited boards — which is exactly why both engines must certify.

#### Stage 3 — AUTO-GRADE → §3.7.

#### Stage 4 — HUMAN-CURATION

The generator emits a graded candidate pool (thousands, each tagged with score, `F`, `D`, families, `par_drags`, wild count, topology + decision-recency flags). Humans **filter** to the band a slot needs, **pick** by taste (visual balance, clean read, elegant aha), **theme** (assign families to fashion ladders, board skin, level name, **and the board→Vault-slot feed field of §2.6**), **sequence-check** on device, and **tune par tolerance** if needed (which forces Engine-B re-proof). Human time per shipped level ≈ **5–15 min** — the cost win that makes a campaign viable.

#### Runtime stuck-detector (in the shipped game, not the pipeline)

Per the §2.8/§2.9 Design responses: **best-effort, non-proactive, recovery-guaranteed.** It tracks moves since the last merge and matches against the shipped bounded stranded signature, plus a 50 ms depth-3 local lookahead throttled to ~once/few-seconds. It surfaces strandedness **only when the player taps "Am I stuck?"** (no auto-prompt by default). It never auto-declares failure; undo/restart remain unlimited.

## 3.6 Performance & Scaling

- **State-space blow-up:** tight boards (`F=1–2`) are exponentially harder; worst case is the pinhole boss. Mitigations: by-construction removes existence search; symmetry-canonical transposition tables (8–40×); admissible-heuristic A*; hard node/time caps + resample.
- **Throughput:** on a 16-core build agent, ≥ 5,000 candidates/hour at mid difficulty, ≥ 800/hour at knife-edge. A full +30-level drop with ~10× overgeneration grades in well under an hour of compute — negligible.
- **Memory:** IDA* flat; A* bounded by transposition table (cap 512 MB/worker; LRU evict).
- **Determinism:** deterministic given a seed; we store seed + spec + both engines' witness solutions + metrics with each shipped level so any board is reproducible and re-gradeable.
- **Runtime on device:** zero full-solver work — only the best-effort depth-3 check + the bounded signature. Hint replays the stored offline solution; it does not solve live.

## 3.7 Auto-Grading: the single difficulty score

| Metric | Symbol | Weight | Why |
|---|---|---|---|
| Free-cell tightness | `1 − F/F_max` | **0.28** | Primary lever |
| Lookahead depth | `D` | **0.20** | What players feel |
| **Decision recency** | last-forced-move index / solution length | **0.08** | Prevents back-loaded "breathe-out" autopilot (§3.1) |
| Blocking topology index | corridor/choke/wall + region-fragmentation | **0.14** | Shape of the trap |
| Stranded-state density | reachable-stranded / reachable-states | **0.12** | How punishing missteps are |
| Family count | concurrent families | **0.08** | Interaction load |
| Par tightness | `1 − (#distinct optimal lines)/(legal opening moves)` | **0.06** | How forgiving the line is |
| Parity/wild requirement | wild-required flag | **0.02** | Adds a constraint |
| Board size | playable cells | **0.02** | Session length |

`score = 100 × Σ(weightᵢ × normalized_metricᵢ)`. Bands → slots: **0–25 tutorial, 25–45 early, 45–65 mid, 65–85 late, 85–100 boss/daily.** Weights are **recalibrated quarterly** against live telemetry (clear/undo/abandon rates) so the score predicts *real* difficulty.

**Telemetry → grader feedback loop:**

| KPI | Target | Action if off-target |
|---|---|---|
| First-attempt clear rate (★) | 70–85% early; 35–55% boss | Reweight grader / reslot |
| 2-star achieve rate | 55–70% | Adjust par tolerance |
| 3-star achieve rate (lifetime) | per §7.2 | Tune wild/undo prevalence / variant-seed availability |
| Median undos per level | < 2 mid; < 5 boss; **alarm > 8** | High undo ⇒ topology too cruel or players brute-forcing (R6) ⇒ regrade |
| Level abandon rate | < 8% | > 8% ⇒ reslot to easier band |
| Decision-recency (median) | last forced move at ≥ 40% of solution length | Low ⇒ levels front-loaded ⇒ re-curate |

## 3.8 Worked Micro-Example (engineering validation)

```
5×5, F=3, 1 family (gem ladder t1→t5), no walls, 0 wild.  '.'=empty  (toy fragment)
   g . g .            g = gem t1
   . . . .            R = gem t2 already present
   . . R .
   . . . .
```

Forward solve: slide left `g` right until adjacent to right `g` along the clear top corridor → merge → gem t2 on right `g`'s cell; slide it down the clear column adjacent to `R` → merge → gem t3; … up the ladder to t5 → **showcase, board empty → ZERO.** Engine A returns `par_drags`, confirms no shorter line, computes `D` (low — open), decision-recency; Engine B re-certifies. Grader scores tutorial-band. Curator themes `g`→Raw Shard, `R`→Cut Gem, showcase = Crown. Ship.

## 3.9 The Content-Treadmill Cost (honest assessment)

A campaign format is a content treadmill. The **biggest ongoing cost is not levels** — it is the cosmetic-VFX pipeline (see §5.6 Design response). For the campaign itself:

- **Incumbents win on content depth + ad spend; we cannot out-volume them.** The campaign *frames* the mechanic; it does not compete on a 5,000-level back-catalog. This is why launch is **~150 levels, not 600** — a 600-level launch would flatly contradict the "small, sharp, high-quality" thesis and the 5–15 min/level curation budget.
- **The pipeline is the mitigation.** Reverse-construction + two-engine solver + auto-grade drives marginal level cost to ~5–15 min human curation + negligible compute, making **+30 levels/quarter** affordable with **1–2 part-time curators.**
- **Where the treadmill still bites (honest):** *verb novelty fatigue* (pure tightening eventually feels samey → mitigate with new mechanics gated across worlds, which need real design + solver-support work — budget *that* as the expensive part, not the boards); *grader drift* (quarterly recalibration is mandatory upkeep); *curation taste doesn't scale infinitely* (keep a human in the loop for the main campaign; fully-auto is fine only for daily challenges).
- **Hedge via LiveOps & meta:** the procedural daily challenge + weekly events absorb the "fresh content" pressure off the authored campaign; the Collection Vault gives long-tail progression that consumes no new levels.

---

# 4. Meta Progression & Economy

This section defines the out-of-board game and the closed-loop economy. Every system obeys **"we never block you"** — no energy, no lives, no failure, no sink that walls a player off from the next level. Progression is paced by content and craving, not gates.

> **Economy authority:** §4 is the canonical home for **currencies, faucets, sinks, and prices**. §5 owns the spend-catalog *presentation* and references §4's numbers verbatim — there is exactly one IAP ladder, one wild price, one season pass, one subscription. Earlier draft divergences (Glint/Lumen vs Sparkle/Gems; 120 vs 200 per wild; 5-tier vs 6-tier IAP) are resolved here.

The mental model is a **dual-phase loop:**

```
   PHASE A: SOLVE                         PHASE B: COLLECT
   (the board, §2–3)                      (the vault, this section)
 ┌───────────────────────────┐         ┌────────────────────────────┐
 │  Drag → slide → merge →    │  ────>  │  Showcased items "drop"     │
 │  showcase (item vaporizes) │  Sparkle│  into a themed Set slot     │
 │  Board reaches ZERO        │  payout │  + Glint (soft currency)    │
 │  → 1–3 stars               │         │  Set completes → unlocks    │
 └───────────────────────────┘         │  theme/cosmetic             │
            ^                           └────────────────────────────┘
            │                                        │
            └──────── "I want THAT crown for my vault" ◄┘
```

A level is a 60–180 s sprint; a Set is a multi-day arc; the Vault is the months-long meta. This staggering is the retention engine that replaces an energy gate.

## 4.1 The Collection Vault

The **Collection Vault** is the home screen between levels — a glossy "jewelry-vault / sticker-album" surface, three-level hierarchy:

| Level | Name | Example | Count target (launch) |
|---|---|---|---|
| Top | **Collection** | "Heritage Diamonds", "Atelier Spring", "Midnight Gala" | 8 Collections |
| Middle | **Set** | "The Solitaire Ring Set", "The Eveningwear Set" | 3–5 Sets per Collection (~30) |
| Bottom | **Showcase Slot** | one named top-tier item, e.g. "Marquise Crown" | 6–9 slots per Set (~210) |

A **Showcase Slot** fills when the player produces the matching **named top-tier item** (§2.6 mapping) for the first time, or the Nth time for multi-copy slots. The vaporized item **flies into the Vault** and snaps into its slot with the hero "poof" — the literal bridge between phases, reusing the game's best animation.

**Slot fill rules.** Each slot has a target count (1–5 copies). Producing an already-banked item still pays **Glint + Set Progress %** (over-production never wasted — critical for the no-fail promise). Some slots are **theme-locked** (fill only while a matching board theme/family is in rotation — how LiveOps injects fresh chase targets without new code).

**Set completion** pays a Set Reward bundle (§4.4), contributes to its parent Collection, and a full Collection grants a **prestige cosmetic** (animated vault backdrop + profile badge).

## 4.2 Currencies

Exactly **two currencies plus three consumable tools** (minimal count is a deliberate simplicity moat).

| Currency / Item | Type | Premium? | Role |
|---|---|---|---|
| **Glint** ✨ | Soft currency | Earnable | Everyday economy: tools, cosmetics-on-sale, Set "rush" fills, cosmetic gacha |
| **Lumen** 💎 | Premium / hard | IAP (+ small earn) | Premium cosmetics, FX, theme bundles, season pass, subscription, large tool bundles |
| **Wild Gem** | Consumable tool | Earnable + buyable | Joker piece (§2.10) |
| **Hint** | Consumable tool | Earnable + buyable | Highlights the next safe move on the solver's known zero-path |
| **Reset Token** | Consumable tool | Mostly free | "Soft restart" preserving move history for a 3★ retry; pure convenience (full restart is always free/unlimited) |

Guardrails: **Lumen is never required to progress** (every cosmetic/tool has a Glint or earnable path). **Wild Gem and Hint are convenience by contract** (every board is solver-proven free-solvable, §3.5). **No third "gacha-only" currency** — Vault sets fill by *playing*, not pulling.

## 4.3 Economy: all sources and sinks

#### 4.3.1 Glint — sources

| Source | Amount | Cadence / cap |
|---|---|---|
| Level clear (1★) | **10 Glint** | First clear |
| Level 2★ bonus | **+10** (20 total) | First time efficient |
| Level 3★ bonus | **+25** (45 total) | First time perfect |
| Replay of a beaten level | **3 Glint** | Soft cap 60/day from replays |
| Showcase item produced | **2 Glint** each | Uncapped |
| Daily Challenge clear | **30 Glint** | 1/day |
| Daily login streak (d1→d7) | **5 → 50 Glint** ramp | 1/day; 1 free skip/week |
| Set completion bundle | **75–150 Glint** | Per Set |
| Rewarded ad ("Glint dig") | **15 Glint** | 5/day cap |
| Season pass free track nodes | **20–60 Glint** | Per tier |

#### 4.3.2 Glint — sinks

| Sink | Cost | Notes |
|---|---|---|
| Buy 1 Hint | **40 Glint** (or 1 rewarded ad) | |
| Buy 1 Wild Gem | **120 Glint** (or 1 rewarded ad) | **Canonical wild soft-currency price = 120 Glint each.** |
| Set "Rush" fill | **60 Glint / remaining slot copy** | Only buys *duplicates* — you must *earn* the first of every showcase item |
| Cosmetic (Glint-tier) | **400–1,500 Glint** | Rotating earnable cosmetics |
| Cosmetic gacha "Velvet Box" | **250 Glint / pull** | Cosmetic-only; duplicate→Glint refund; NEVER tools or progression |
| Reset Token | **15 Glint** | Star-chasing convenience |

> **Key invariant:** no Glint sink is *required* to advance the campaign. Every sink is a tool, cosmetic, or time-saver. The campaign door is opened only by **stars**, which cost nothing but skill.

#### 4.3.3 Lumen — sources

IAP packs (see §4.7 / §5.4); season pass premium track (~150 Lumen across it); first-clear of each Collection (**25 Lumen**, ≈200 over launch); achievement milestones (5–50 Lumen); rare long-streak login (day 30/60: 30 Lumen). A F2P player accumulates roughly **300–500 Lumen in month one** — enough to taste a premium cosmetic or the pass.

#### 4.3.4 Lumen — sinks

| Sink | Cost | Notes |
|---|---|---|
| Season Pass | **900 Lumen** (or $9.99 SKU) | Cosmetic + collection track |
| Premium board theme | **600–1,800 Lumen** | High-gloss showpieces |
| Showcase FX pack | **300–900 Lumen** | "Expensive" vaporize effects |
| Tool bundle (10 Wild Gems) | **400 Lumen** | Convenience |
| Remove Ads (one-time) | **600 Lumen** / $4.99 direct | Removes rewarded-ad *prompts* and auto-grants the daily reward free (so buyers lose no value) |
| Convert Lumen → Glint | 1 Lumen : 10 Glint | One-way; never Glint → Lumen |

#### 4.3.5 Tool economy (Wild Gem / Hint)

- **Starting grant:** 5 Wild Gems + 5 Hints in the tutorial arc.
- **Earned faucet:** ~1 Wild + ~2 Hints/day realistically free (rewarded ads + login + Set rewards), so an engaged free player is rarely *out*. Target free-earn supply ≈ **1.5×** average consumption.
- **3-star tension is the built-in sink:** using a wild forfeits ★★/★★★ (§2.7), so spending a wild has an opportunity cost unrelated to money — a "give me the 1★ and move on" lever for casuals, an avoid-at-all-costs item for masters.

## 4.4 Set rewards & the unlock spine

Set completion is content gating that doesn't feel like a gate — you unlock toys and looks, not the ability to keep playing.

| Reward type | Example | Where granted |
|---|---|---|
| **New board theme** | "Midnight Gala" board skin | Completing a Collection's anchor Set |
| **Cosmetic** | gem skin, showcase FX, Vault backdrop | Most Set completions |
| **Glint bundle** | 75–150 Glint | Every Set |
| **Lumen trickle** | 25 Lumen | Per Collection completion |
| **Prestige badge + animated Vault** | profile flex | Full Collection completion |

> New piece **families** are introduced by the **campaign curriculum** (§3.4), never purchased; the Vault only themes/decorates them. A player can never be Set-gated out of a family they need.

## 4.5 Campaign map & progression gating (reconciled)

The campaign is a vertically-scrolling **map** of **~150 hand-curated launch levels**, grouped into **10 Worlds of 15** (the map and Vault are visually parallel; "World" and "District" are unified to **World**). Max stars at launch = **150 × 3 = 450**.

**Progression gate = level COMPLETION, not stars (this corrects a real no-fail contradiction in an earlier draft).**

- Advancing the campaign requires only **clearing levels** (reaching ZERO), which is *always achievable* under the no-fail contract (§2.8): every board is solver-proven free-solvable, with unlimited free undo/restart.
- **World N+1 opens when the player has cleared 12 of World N's 15 levels** — a light completion gate with 3 levels of slack, so a stubborn board never blocks forward motion; the player skips it and returns anytime.
- **Stars are pure prestige and NEVER a gate.** They unlock cosmetic/Vault rewards and the "Master Atelier" track (§4.6) but never block progression.
- **Why this changed (the fix):** an earlier draft gated on holding **60% of available stars**. That hard-walls the **1-star-majority** segment — a 1★-only player holds just **33%** of stars (`1/3`), well under any star threshold — i.e. it would block exactly the audience §7.2 names as the commercial core, breaking the no-fail brand. A *completion* gate (always reachable, never paid) removes the wall for 1-star and 3-star players alike.

```
World 1  [15 lvls]  ─ gate: clear 12 of 15 to open World 2   (stars are optional, rewards only)
World 2  [15 lvls]  ─ gate: clear 12 of 15 to open World 3
...
   Stuck on a board? Skip it (within the 3-level slack), keep playing, return anytime.
```

> **No-fail guarantee at the map level:** the gate is *completion* (always reachable by play, never by payment) and stars are decoupled prestige, so **no player — 1-star or 3-star — is ever walled.** **There is no "buy stars" SKU and no "buy progression" SKU — ever** (hard rule, protects the fairness brand).

## 4.6 Long-term goals beyond the last level

The campaign is finite; the meta is not. D30+ retention is carried by evergreen systems that don't require shipping new levels weekly:

1. **The 3-Star + Clean-Clear chase.** 150 levels × 3 stars = **450 stars**, plus the variant-seed 3★ option (§3.3) and per-level Clean-Clear badges. A "Master Atelier" track rewards 3-starring whole Worlds.
2. **Vault 100%.** Filling every Showcase Slot (multi-copy + theme-locked) is a months-long arc with prestige Collection backdrops as the carrot.
3. **Daily Challenge (evergreen, procedural).** One fresh solver-verified board/day with a friends leaderboard (par-relative shareable score). Infinite by construction, no authoring cost.
4. **Weekly Themed Collection Events** (§5.6). Limited-time Sets with exclusive cosmetics.
5. **Async social hooks (per §1.5 Design response):** shareable equipped-cosmetic ZERO clips, browsable friend Vaults, daily-challenge ghost replays — a mass-casual D14–D30 hook independent of puzzle mastery.
6. **Endless / "Marathon Vault" mode (post-launch).** Procedurally escalating tightness; a personal-best ladder for campaign-finishers.

> **Design response — D30 mass-casual coverage (medium severity).** Evergreen mastery (Marathon, 3★ completionism, Vault 100%) serves the hardcore minority; the median fashion-skew relaxer needs a non-mastery reason to return. We therefore add at least one **mass-casual D14–D30 hook**: async friend comparison on the daily challenge (ghost/score) plus a light Vault-decoration meta the casual tends without 3-starring, and we **instrument a separate D30 sub-target for the non-mastery segment** rather than assuming mastery loops carry the whole D30 population (§7.2).

## 4.7 Pricing (canonical) & worked progression

**IAP ladder (USD; canonical — one ladder, used by both §4 and §5):**

| SKU | Price | Lumen | Bonus |
|---|---|---|---|
| Sparkle | $0.99 | 100 | — |
| Pouch | $4.99 | 550 | +10% |
| Vault | $9.99 | 1,200 | +20% |
| Treasury | $19.99 | 2,600 | +30% |
| Heirloom | $49.99 | 7,000 | +40% |
| Royal | $99.99 | 15,500 | +55% |
| **Season Pass** | $9.99 | (track, not currency; or 900 Lumen) | — |
| **Showcase Pass +10** | $14.99 | pass + 10 tier skips | — |
| **Remove Ads** | $4.99 | one-time | — |
| **Glow Membership (subscription)** | $7.99/mo | see §5.2 | ARPU backbone |
| **Starter Bundle** (one-time, first 72h) | $2.99 | 300 Lumen + 10 Wilds + a theme | high-value hook |

### Worked example: early-game progression (moderate F2P player → first Set)

First Collection = **Heritage Diamonds**; anchor Set = **The Solitaire Ring Set** (6 slots, 1 copy each of a named Crown variant the early Gem boards produce). Tutorial grants **5 Wilds + 5 Hints + 50 Glint.**

| Session | Levels | Stars | New slots filled | Glint this session | Cumulative | Set |
|---|---|---|---|---|---|---|
| **D0 #1** (tutorial) | L1–L5 | 8★ (three 2★, two 1★) | slots 1–2 | clears 50, ★bonus +30 (3×+10), showcase 4, login 5 → **89** | 139 | 2/6 |
| **D0 #2** | L6–L9 | 8★ | slot 3 | clears 40, ★ +40, showcase 6, daily 30 → **116** | 255 | 3/6 |
| **D1** | L10–L13 + daily | 7★ | slot 4 | clears 40, ★ +35, showcase 8, daily 30, login 10 → **123** | 378 | 4/6 |
| **D2** | L14–L17 | 6★ | (dupes only) | clears 40, ★ +30, showcase 8, login 15 → **93** | 471 | 4/6 |
| **D3** | L18–L22 + daily | 8★ | slot 5 | clears 50, ★ +40, showcase 10, daily 30, login 20 → **150** | 621 | 5/6 |
| **D4** | L23–L26 | 7★ | **slot 6 — Set fills!** | clears 40, ★ +35, showcase 8, **Set bundle +100**, login 25 → **208** | 829 | **6/6 ✅** |

At D4 first Set completion: **+100 Glint** (in table) → ~**829 Glint**; **Heritage Diamonds board theme** unlocked; a gem skin ("First Carat"); vault-door "click" + Collection meter to ~20%. With ~829 Glint the player can buy ~6 Wilds (120 each), ~20 Hints (40 each), ~3 Velvet Box pulls (250), or bank toward a Glint-tier cosmetic. The curve never stalls; retention cliffs at D1/D3/D7 each meet a concrete earnable payoff — **no energy timer ever appears.**

**Pacing across 30 days (moderate player):**

| Day | Levels cleared (cum.) | Sets done | Collections | Beat |
|---|---|---|---|---|
| D1 | ~13 | 0 | 0 | habit forming; daily unlocked |
| D4 | ~26 | 1 | 0 | first Set → first theme |
| D7 | ~45 | 3 | 1 | first **Collection** → +25 Lumen, prestige backdrop, first weekly event |
| D14 | ~90 | 7 | 2 | Charms family in full rotation; async social hooks live |
| D30 | ~130 | 12 | 4 | Vault ~half full; variant-seed 3★ + Marathon become the long tail |

*(D14/D30 level counts revised down from the earlier 600-level draft to be consistent with the ~150-level launch; the campaign is "small, sharp," and D30+ leans on Vault + dailies + variant-seed mastery + LiveOps rather than raw level volume.)*

## 4.8 Sustaining D7/D30 WITHOUT an energy gate

Replacement levers for an energy economy: (1) **daily login streak** (forgiving, 1 free skip/week); (2) **Daily Challenge** (a fresh shareable board — a reason to open the app even off-campaign); (3) **Set arcs as the real retention currency** — tuned so a moderately active player completes their first Set ~D3–D4 and first Collection ~D7–D8, landing reward beats exactly on the retention cliffs; (4) **weekly events** on a 7-day clock; (5) **Vault + variant-seed long tail** so finishing the campaign doesn't trigger churn; (6) **async social hooks** for the mass-casual segment. A binge player is never throttled (they progress the Vault faster, may hit only the soft replay-Glint cap which dampens *grinding* not *playing*); a 5-minutes-a-day player always has a fresh daily and a Set inching forward.

---

# 5. Monetization & LiveOps

## 5.1 Philosophy: Monetize Delight, Never Friction

Acorn Forest: Merge! monetizes the **glow**, not the **gate**. Every offer is either **Aspiration** (make the board/gem/poof look *more expensive* — cosmetics, season pass, Vault flair) or **Convenience** (skip a moment of thinking — hint/wild packs). Because the core promise is no lives, no energy, never blocked, unlimited undo/restart, and every board provably free-solvable, **there is nothing to sell that the player strictly needs** — that is the brand.

**Hard rules (locked):**

- **No pay-to-win.** Hints and wilds are also free-earnable; a wallet can **never** buy a star (★★/★★★ require no wild; ★★★ requires no undo/restart). Mastery is uncorrupted by spend.
- **No forced interstitials.** Every ad is **rewarded and opt-in**. We never show an unskippable full-screen ad. (We exception only the optional, value-positive "watch to claim a bonus cosmetic shard" on the natural clear screen — see §5.5.)
- **No energy economy.**

## 5.2 Why this still makes money — and the ARPU backbone

Energy-gated incumbents convert by manufacturing scarcity. We removed that lever on purpose, so revenue comes from identity, completion, and a subscription — **not** from inflated one-off cosmetic numbers.

> **Design response — the headline economics, re-founded (high severity, accepted with corrected numbers).** Two pillars (no-energy, no-fail) suppress the two biggest casual levers (session-frequency throttling; loss-pressure spend). Cosmetic-only ARPPU cannot reach social-game levels for a solo puzzle with no avatar/profile/PvP. We therefore **do not** plan against $14–22/mo cosmetic ARPPU at 3–4.5% conversion. The corrected, defensible model:
> - **Lower cosmetic-only inputs:** 1.5–2.5% cosmetic conversion, $8–12 cosmetic ARPPU.
> - **A cosmetic-QoL subscription (Glow Membership) promoted to the ARPU backbone** — a relaxed daily-habit comfort audience monetizes better on a predictable subscription than on lumpy one-off cosmetics, and it smooths revenue against the cosmetic-drop cadence.
> - **A visible social surface for cosmetics** (shareable equipped-FX ZERO clips, friend Vault, ghost replays) so a purchased look is actually *seen*, lifting cosmetic willingness-to-pay back toward the lower-bound assumptions rather than collapsing to pure completionism.
> - **Conservative ad inputs** ($8–12 eCPM rewarded, 25–30% daily opt-in — *not* $12–18 / 35–45%).
> - **Organic-first growth:** paid UA is gated behind a proven LTV:CPI and is **not** treated as the growth engine (§7, R5).
>
> The resulting blended ARPDAU planning band is **$0.05–0.08** (not $0.10–0.18). The business is sized to *that* number with a small team and long runway; see §7.2 for the canonical KPI table and the honest "paid UA may never open" gate.

**Revenue mix target (steady state, corrected):**

```
  Cosmetics / skins / FX (direct IAP) ............ ~32%
  Glow Membership (subscription, ARPU backbone) .. ~26%
  Season pass (Showcase Pass) .................... ~18%
  Rewarded ads (conservative eCPM × volume) ...... ~12%
  Convenience packs (hints / wilds) .............. ~8%
  Premium / Remove-Ads + Starter bundle .......... ~4%
```

**Brand-health gauge:** the **cosmetic:convenience revenue ratio must stay ≥ 2:1.** If convenience packs ever rival cosmetics, the game is being experienced as too hard / paywalled-by-frustration — a red flag that violates the brand (§7).

## 5.3 Currency & utility (defers to §4.2)

Two currencies (**Glint** soft, **Lumen** premium) + utility tokens (**Wild Gem**, **Hint**, **Reset Token**). Names, prices, and faucets are canonical in §4 and not redefined here. Wilds/hints are convenience by contract (every board is free-solvable, §3.5); using a wild forfeits ★★/★★★, so the skill community has zero incentive to buy them and the convenience line targets *casual relaxers*, not competitors.

## 5.4 Spend Catalog (presentation; prices per §4.7)

#### A. Premium Currency (Lumen 💎) — IAP
Exactly the canonical ladder in **§4.7** (Sparkle $0.99 / Pouch $4.99 / Vault $9.99 / Treasury $19.99 / Heirloom $49.99 / Royal $99.99). No separate or conflicting ladder.

#### B. Cosmetics — Board Themes, Item Skins, Showcase FX
Three families, three rarity tiers. Glint buys commons/uncommons; Lumen buys rares/exclusives; LiveOps drops are Lumen/real-money and time-limited.

| Type | Example | Rarity | Price |
|---|---|---|---|
| Board Theme | Velvet Atelier | Common | 1,200 Glint |
| Board Theme | Art Deco Gold | Uncommon | 3,500 Glint |
| Board Theme | Aurora Glass | Rare | 450 Lumen |
| Board Theme | Midnight Couture (animated) | Exclusive | 900 Lumen / LiveOps |
| Item Skin | Rose-Gold Ring Line | Common | 900 Glint |
| Item Skin | Prism Gem Line (shader) | Rare | 400 Lumen |
| Item Skin | Celestial Set (full-board) | Exclusive | 1,100 Lumen |
| Showcase FX | Sparkle Burst | Common | 1,500 Glint |
| Showcase FX | Diamond Fireworks | Rare | 550 Lumen |
| Showcase FX | Supernova Showcase (screen-wide) | Exclusive | 1,200 Lumen / seasonal |

**Bundles:** Glow-Up Starter ($2.99 one-time = 1 theme + 1 skin + 1 FX + 300 Lumen + 5 wilds); Art Deco Collection ($9.99 matched set, ~25% off); Couture Vault ($24.99 = 3 exclusives + 1,500 Lumen).

#### C. Convenience Packs — Hints & Wild Gems (never required)
Every storefront for these carries the persistent label **"Boards are always solvable for free — these just save you a few taps."** Canonical single price for a wild = **120 Glint each** (§4.3.2) or in bundles:

| Pack | Price | Contents |
|---|---|---|
| Wild Gem ×3 | 360 Glint or 90 Lumen | 3 wilds (matches 120/each soft) |
| Wild Gem ×10 | 400 Lumen | 10 wilds (~bundle discount) |
| Hint ×5 | 200 Glint or 60 Lumen | 5 hints |
| Hint ×15 | 150 Lumen | 15 hints |
| Helper Combo | $1.99 | 10 wilds + 15 hints |

#### D. Season Pass — "The Showcase Pass" (cosmetic + collection track)
A **6-week** dual-track pass; **both tracks are 100% cosmetic + collection — no power, no required wilds.** Progress via **Showcase Points** (1 SP/showcase + level/daily bonuses) — rewards *playing the core loop*, not paying. **Free Track** ($0): Glint, occasional tools, a finale theme, a free Set frame. **Showcase Pass** ($9.99 or 900 Lumen): ~50 reward tiers (themes, skins, FX, vault frames, a season-exclusive showcase FX), bonus Glint/Lumen. **Showcase Pass +10** ($14.99): pass + 10 tier skips. Converts via collection-completion psychology + the **season-exclusive finale FX** (never re-sold, only re-themed) — *aspirational* scarcity, not punitive.

#### E. Premium / Subscription / One-Time

| Offer | Price | Effect |
|---|---|---|
| Remove Ads | $4.99 one-time | Removes the opt-in rewarded *prompts* and **auto-grants the daily reward free** (buyer keeps the upside) + a Premium vault badge |
| **Glow Membership (ARPU backbone)** | **$7.99/mo** | 2× daily Glint, **one monthly exclusive cosmetic drop**, ad-free, premium vault frame, +1 free daily wild. **Strictly cosmetic + QoL — never affects solvability or stars.** Target attach: see §7.2. Surfaced non-coercively on positive moments (post-3★, near-Set-completion). |

> **Design response — subscription as a first-class pillar (medium severity).** The earlier draft buried the subscription in a footnote with no attach target or funnel. It is now the **ARPU backbone** (§5.2), with a clear value stack (above), an explicit attach-rate target (§7.2), and prominent non-coercive surfacing. It smooths revenue against lumpy cosmetic drops and converts the no-energy daily habit into recurring cash without violating fairness.

## 5.5 Rewarded Ads — Opt-In Only (conservative)

| Placement | Trigger | Reward | Daily cap |
|---|---|---|---|
| Free Wild | "Watch for a free Wild Gem" (HUD) | +1 Wild | 3 |
| Free Hint | "Stuck? Watch for a Hint" (only after ~45s idle) | +1 Hint | 3 |
| Glint Top-up | "Watch to double this level's Glint" (clear screen) | 2× Glint | 2 |
| Daily Chest boost | "Watch to upgrade today's login chest" | Chest +1 | 1 |
| **Bonus cosmetic shard** | "Watch to claim a bonus cosmetic shard" (natural clear screen — value-positive, optional) | 1 cosmetic shard | 1 |

- The Hint ad surfaces only after a genuine idle pause and reveals one move from the solver's **proven zero-path** (never misleads, never trivializes).
- **Per-placement caps sum to 10; the global daily cap is 10** (caps are reconciled — global overrides if a future placement is added). Past the cap: "come back tomorrow," never nagging.
- **Conservative assumptions:** rewarded eCPM **$8–12**, **25–30%** daily opt-in, **2.5–3.5** ads/viewer/day (single canonical figure used in §7.2). The model is required to close at *these* inputs — if it only works at stretch ad numbers, it does not work.

## 5.6 LiveOps Calendar — light cadence for a no-energy game

```
  Daily   ── Daily Challenge board (new each 00:00 UTC, shareable score, friend ghosts)
          └─ Daily Login chest (escalating 7-day streak, forgiving reset)
  Weekly  ── Themed Collection Event (Mon–Sun, vault-set sprint + cosmetic-only leaderboard)
  Biweekly ─ Limited Cosmetic Drop (rotating exclusive, ~10-day window, then vaulted)
  Seasonal ─ Showcase Pass (6 weeks) + season-finale community goal
```

- **Daily Challenge:** one curated, deterministic-seed board/day, same pipeline + spot-check, "medium-spicy." Shareable **Daily Showcase Score** (par-efficiency, no-undo, wild-free) with a glossy auto-generated share card and **async friend ghost replays**. Rewards: Glint + 1 Wild + Showcase Points; 7-day streak grants an exclusive vault frame. Yesterday's board is replayable from an archive (no streak credit). No miss-penalty.
- **Weekly Collection Event:** themed 8–12 piece set sprint; completing it unlocks a board theme + FX free; a deluxe variant is purchasable (the event *advertises* the cosmetic). Leaderboard is **cosmetic/bragging-only** (no power rewards) — protects no-pay-to-win.
- **Limited Cosmetic Drop:** a single spotlighted exclusive for a window, then vaulted (re-released only via throwback events) — *aspirational, not punitive* scarcity. Always Lumen/bundle; one-tap "preview on your board."
- **Seasonal:** new Showcase Pass + a community goal (e.g. "showcase 50M crowns this season") with a free cosmetic for everyone on completion.

> **Design response — the real LiveOps cost is the cosmetic-VFX pipeline (high severity).** The earlier draft celebrated cheap procedural levels while ~70% of revenue (cosmetics + pass + subscription drops) depends on a relentless stream of expensive high-gloss VFX art — board themes, refraction/shader skins, screen-wide showcase FX — roughly **~50 distinct premium cosmetic assets per quarter** feeding biweekly drops, weekly events, two seasonal passes, and the monthly subscription drop. **This is the true content treadmill and the primary LiveOps line item**, and for a game whose "expensive-to-the-touch" gloss *is* the moat, under-resourcing it kills both the moat and the revenue engine. **Fix (locked):** (1) the cosmetic-VFX pipeline is budgeted as the **primary LiveOps line item** with explicit assets-per-quarter (~50) and named senior tech-artist/VFX headcount + cost, and the corrected lower revenue (§5.2) is pressure-tested to fund it; (2) we build a **modular/parametric cosmetic system** — palette- and shader-param-driven theme variants from a shared rig — to get variety at *sub-linear* art cost, mirroring what the level pipeline does for boards.

## 5.7 Storefront & Offer Surfacing (non-intrusive)

- **One persistent "Boutique" tab**, never a pop-up wall on level entry.
- Contextual *positive-moment* offers only: after a 3★, at Set-near-completion, at season-pass tier-up, and a gentle subscription nudge on these same beats. **Never on a fail (there is none) and never blocking play.**
- Starter Bundle ($2.99) surfaced once after ~15 cleared levels + engagement.
- All convenience SKUs carry the standing "boards are always free-solvable" disclaimer.

---

# 6. Game Feel, Art Direction, Audio & UX

Gloss and juice are the experiential moat; the readability of the *sliding-puzzle* core is the usability moat. The bar: someone who has never heard of us watches a 6-second clip of one merge run ending in a showcase and feels the dopamine through the screen. The single most important UX job is making **two invisible things visible in real time: which targets are legal, and whether a clear sliding path actually reaches them** (because the core verb is drag-to-slide-into-adjacency, §2.4).

## 6.1 Art direction — "visual candy"

**Creative brief:** *expensive, edible, calm.* Reference luxury e-commerce hero-shot lighting, not saturated cartoon match-3.

**Three pillars:** (1) **High-gloss premium materials** — faceted glass gems with refraction + moving specular highlight; warm anisotropic metals; satin-rim-lit fabrics; nothing flat-shaded. (2) **Aspirational calm** — deep low-saturation jeweler's-velvet backgrounds (midnight navy, oxblood, charcoal, cream), soft vignette, faint bokeh; the board is the jewel; negative space is a *feature* (and here it is *the resource* — sliding lanes). (3) **Restraint until reward** — the resting board is matte-calm; energy is spent on the slide+merge and exploded on the showcase.

**Rendering targets (mobile):**

| Aspect | Spec |
|---|---|
| Item rendering | 2.5D pre-baked hero sprites (3D-DCC at parallax angles) + runtime specular-sweep shader; reads 3D without real-time 3D cost |
| Per-item highlight | A specular streak loops every ~2.2s at rest (the "breathing shine") |
| Frame rate | 60fps on reference devices (iPhone 12 / Pixel 6 class); 30fps fallback drops particles, never clarity |
| Resolution | Assets @3x (1242px hero) with @1x/@2x mips |
| Palette | P3 wide-gamut velvet where supported; gems use extra gamut for "impossible" saturated OLED highlights |
| Empty-cell render | A recessed velvet **socket** with faint inner shadow — reads as "open lane / room" (emptiness = progress *and* maneuvering space) |

**Family identity** conforms verbatim to the **Canonical Family Table (§2.2)** — Gems (cool blue, faceted glass, round), Threads (magenta/rose, satin, draped), Charms (warm gold, metal/leather, geometric), + Florals/Pearls reserve. Rule: **never put two families with adjacent hue bands on the same board.** **Tier legibility:** higher tier = larger footprint + more facets + brighter idle shine + a **tier pip (1–5 dots)** doubling as a colorblind-safe readout.

```
 T1        T2         T3          T4            T5 (showcase)
 •         ••         •••         ••••          •••••
 ▫ dim     ◇ cut      ◈ set       ❖ ornate      ✦ radiant (about to vaporize)
small ───────────────────────────────────────► large + glowing
```

## 6.2 The juice spec (the heart of the feel)

Juice is layered: **visual + audio + haptic fire together on every interaction**, tuned to one shared envelope so a slide-then-merge feels like one continuous physical event. The travel is part of the satisfaction.

**(a) Pickup / lift.** Touch-down: item scales to 110%, lifts with a soft shadow, idle shine tracks the finger. The board immediately telegraphs the rules of motion (the load-bearing moment for sliding): **legal + reachable** targets get a bright pulse + halo; **legal-by-type-but-unreachable** targets get a dimmer desaturated **"ghost halo"** (right match, blocked path); the **slide lanes** the lifted piece can enter glow as recessed channels. Audio: soft "lift" tick. Haptic: light selection tap. Source cell shows a ghost outline of the cell about to free up.

**(b) The slide (the motion that makes this a puzzle).** As the finger drags, the piece slides cell-to-cell **through empty cells only**, snapping along grid lanes — it visibly cannot enter an occupied cell. Telegraphs: a thin **path trail** (comet streak in the family hue) behind the moving piece; when dragged toward a wall of occupied cells the piece **firmly stops at the last empty cell** with a rubber-band nudge + soft "tick" (unmistakable "blocked here", no penalty, no move counted). Audio: a quiet glassy glide whose pitch rises subtly with distance. Haptic: faint continuous texture + a soft tick per cell boundary.

```
Dragging the left gem RIGHT — slides only through empty cells, STOPS adjacent to its match.
 ┌────┬────┬────┬────┐          ┌────┬────┬────┬────┐
 │ ◇  │    │    │ ◇  │          │    │    │ ◇  │ ◈  │  ← T2 lands on TARGET cell;
 │drag│ →  │ →  │match│   ==►    │    │    │    │new │     SOURCE cell empties. Net −1.
 └────┴────┴────┴────┘          └────┴────┴────┴────┘
```

**(c) Merge snap / click — the workhorse.** On landing adjacent to its match: both items rush to the target center (60ms ease-out), squash-and-stretch, the next-tier item pops 120%→100% with a 180ms overshoot spring **on the target cell** (source cell empties, net −1). A radial shine-burst (~12 motes, 400ms). The vacated cell does a "vacuum" shimmer morphing into the recessed-socket look — telegraphing "a new sliding path may have opened." Audio: the signature **crisp glassy *tink*** with a pitched sine tail. Haptic: `impactOccurred(.medium)`, < 16ms from visual contact.

**(d) Escalating sparkle pitch up a run — re-keyed to the real skill.** A **run** = consecutive merges within a rolling 2.5s window. Each merge raises the click's pitch a semitone up a **pentatonic scale (C-D-E-G-A-C…)**, capping after 8 steps; sparkle motes and ring brightness scale (12 → ~30 by step 6); haptic intensity steps up; a soft descending "settle" chord on lapse.

> **Design response — juice must reward the behavior the puzzle wants (medium severity).** The puzzle rewards good *lane-opening*, which often means deliberately **not** merging immediately — so a run-reward keyed purely to rapid chaining pulls *against* the actual skill. **Resolution:** the escalating audio-visual reward is keyed to **efficient lane-clearing sequences** (a measured "good-routing streak": consecutive merges that each occurred at or below the routing the solver would use), not to mere merge-immediacy. Where it remains pure juice, we no longer claim "run-chaining is where the run feel and strategic depth reinforce each other" — chain-now and set-up-lanes-first are reconciled by making the juice fire for *clean routing*, not *haste*.

**(e) Showcase "poof" — the hero moment.** The single most important ~1200ms (board interactive again at ~400ms so flow is never blocked): **0–150ms anticipation** (board dims ~70%, spotlight irises, slight time-dilation, near-silent); **150–500ms reveal** (item rises ~12px, rotates for a big specular sweep, peak 130%); **500–800ms poof** (gold/diamond glitter + bloom flash; hero sparkles streak toward the Vault icon); **800–1200ms afterglow** (board un-dims with a ripple; both freed cells do their vacuum shimmer — visibly opening lanes). Audio: rising glassy swell → bright "champagne pop" + sparkle arpeggio resolving on the family's chord (the only "big" sound). Haptic: a distinct **double-pulse** (soft build + crisp `.heavy` pop). Purchased **showcase FX cosmetics** re-skin it (monetization hook, §5).

**(f) Board-clear "ZERO".** Final showcase → full-screen shimmer sweep over empty velvet → **"ZERO"** in elegant thin-serif + "collection complete" subline → 1–3 stars (and the **Clean-Clear crest** if earned, §3.3) stamp in with a chime each → earned ✨ + pieces fly to the Vault. Win haptic: three ascending soft pulses ending in a warm sustained one.

**(g) Blocked / stranded feedback (no fail, ever).** Per §2.8/§2.9: never a fail screen, never a scary alarm. The stuck-detector is **non-proactive by default** — strandedness is surfaced only when the player taps the opt-in **"Am I stuck?"** button, which then softly glows **Undo** and **Restart** with a one-line whisper: *"Out of room — undo or restart, you can't lose."* No red, no buzzer, no penalty.

**(h) Screen treatment.** Subtle dynamic depth-of-field (active target sharpens; far edges hair-blurred); an almost-subliminal slow drift of light across the velvet. Reduced/disabled under "Reduce Motion" or battery-saver.

**(i) Haptics summary.**

| Event | iOS | Android | Feel |
|---|---|---|---|
| Pickup | `selectionChanged` | light click | tiny tap |
| Slide (per cell) | light tick | light click | gliding texture |
| Slide blocked | soft `.warning` | tick-tick | gentle "stop" |
| Invalid drop | soft warning | tick-tick | gentle "nope" |
| Merge | `impactOccurred(.medium)` | medium click | satisfying thunk |
| Good-routing run | medium, rising | scaled clicks | building |
| Showcase poof | build + `.heavy` pop | heavy click | the signature |
| "Am I stuck?" surfaced | single soft pulse | single soft click | "undo me" |
| Win (ZERO) | 3 ascending + sustained | pattern | triumphant-calm |

All haptics are globally toggleable and respect the OS "system haptics off" setting. Every cue (legal target, reachable path, block, merge, win) is **also** visual and audible — haptics are never the sole carrier.

## 6.3 Audio direction

**Tone:** calm, aspirational, "spa-meets-jeweler" — a late-night decompression game. **Music:** ambient, slow, major/lydian beds (soft mallet, harp, felt piano, airy pads), low BPM, no driving percussion; one bed per board *theme* (unlocking themes refreshes the soundscape — a real reward); ducks ~6dB under the showcase swell. **SFX philosophy:** dry, glassy, expensive — the **crystal merge "tink"** + the **champagne showcase pop** + the **glassy slide-glide** are the ownable mnemonics; no boings, no slot-machine clatter. The slide-glide pitch (rising with distance) and the run-pitch are the two melodic SFX layers, both keyed to the current bed. The 150ms showcase anticipation is near-silent so the swell hits harder. **No-headphones case:** fully playable and satisfying muted — audio is never load-bearing for clarity, legal-target reading, or path-blocking feedback. Independent Music / SFX / Haptics sliders.

## 6.4 UX — readability and layout

**3-second-readable board (hard requirement):** within 3 seconds parse how many **families** are present, which items **pair**, which cells are **empty (= sliding room)**, and — once a piece is lifted — which targets are **reachable** vs merely matching.

- **Default board 6×6 (36 cells)** (per §2.1) with a 6–10% inter-cell margin so lanes read; range `4×4` (tutorial) → `6×6` (standard) → `7×7` (hard/rare); **never larger than 7×7 on phone.** Early boards 8–16 items (~45% fill); late approach ~30 items (~80%) but **never literally full**. Max 3 families standard (4 only on hardest), respecting the non-adjacent-hue rule.

**Persistent HUD (minimal, one-handed-aware):**

```
┌─────────────────────────────────────┐
│  ◀ Levels      Level 42      ⚙        │
│                              ★★☆      │
│           [   6×6 BOARD   ]           │   center-low: thumb zone
│   drags: 14 / par 16      🪄 Wild ×1  │
│  ┌──────────────────────────────┐    │
│  │  ↶ Undo    ↺ Restart    💡 Hint│    │
│  └──────────────────────────────┘    │
└─────────────────────────────────────┘
```

- Board biased to the lower 2/3 for thumb reach (dragging is a sustained gesture).
- **The counter shows drags vs `par_drags`** (not merges — §2.5), turning subtly amber near par, soft red just past — informational, never punishing (you can never lose). (Merge-par is *not* shown; it carries no information.)
- Top bar non-interactive during a drag/merge to avoid mis-taps.

### Teaching & telegraphing the slide-to-merge gesture (central UX problem)

| Cue | When | Visual |
|---|---|---|
| **Legal + reachable** | On pickup | Bright pulsing halo. "Complete this merge now." |
| **Legal but unreachable** | On pickup | Dim desaturated **ghost halo**. "Right match, no path — open a lane first." |
| **Slide lanes** | On pickup | Empty cells the piece can enter glow as recessed channels. |
| **Path trail** | During drag | Comet streak along traversed cells. |
| **Hard stop** | At a wall | Rubber-band nudge + tick at the last empty cell. |
| **Adjacency snap** | Reaching a cell next to a match | Target halo flares; the piece magnetizes the last few px. |

The **bright vs ghost halo asymmetry** is the single most important wordless teaching device: it shows that *space and order are the puzzle.* Introduced in onboarding **W1 (early), not W1-late** (§6.5).

### Undo / Restart UI (must feel generous)
- **Undo (↶):** always present, never greyed, **unlimited**, no cost, no confirm. Reverses one logged action with a smooth *reverse* animation (the merged item splits and the source piece slides back along its original path) + soft "rewind" whoosh + light haptic. Long-press = rapid multi-undo.
- **Restart (↺):** one-tap; a lightweight confirm only if > 3 merges made; ~500ms slide-back to authored start. No penalty.
- A non-judgmental "undos used: N" (and Clean-Clear status) appears only on the **post-level summary**, never as live pressure.

### Hint (💡)
Highlights **one** correct next move: pulses the source, draws a glowing arc **along the actual slide path** to its correct target, flares the target. Reveals the next *safe* move (keeps the board solvable), never the whole solution. **First hint per level free;** further hints draw from balance (rewarded ad or pack — never required). **Hints do NOT forfeit any star** (§2.7) — only wild/undo/restart do.

### Wild Gem (🪄)
Shown as a count. A prismatic rainbow-iridescent gem, visibly distinct from every family. It **slides like any other piece** and merges with **any** adjacent item (§2.10). Distinct chime + extra-sparkly poof so its use feels special and precious (it costs ★★/★★★).

### Star rule (UI restatement — canonical values in §2.7)
- ★ = cleared. ★★ = cleared, no wild, drags ≤ `par_drags + max(2, ceil(0.15·par_drags))`. ★★★ = ★★ + drags ≤ `par_drags` + no undo + no restart. **Hints allowed at all tiers.** The post-level summary frames any miss as a replay invitation ("Solved in 18 / par 16 — 2 over"), never as failure, and shows the Clean-Clear crest for any undo-free clear.

## 6.5 Onboarding — teach by hand-built boards, not text walls

**The first ~6 levels ARE the tutorial**, authored by hand so the correct action is the only obvious one. Text is ~4-word coach-marks max. Crucially, the slide-and-block behavior is taught **physically**, by board geometry — and **the blocking rule is taught EARLY**, not deferred.

> **Design response — drop the "3-second wordless grasp" overclaim; teach blocking first (high severity).** The casual mental model from match/merge/blast is teleport-merge; a rook-slide-blocked-by-occupancy-no-gravity rule is a 15-puzzle rule, which is *not* instantly legible — and R7 rates slide friction as a HIGH-severity D1 risk. Teaching the teleport model first (L0–L3 all "generous lanes") would make players learn the *wrong* model, then churn at the first real blocking board. **Fix:** the **ghost halo appears in L1** and a gentle, forgiving **blocked-path moment lands in L1**, so the player's *first* learned model is "pieces slide and get stopped by other pieces." We re-baseline the FTUE gate to **L1–L2 completion** (where boards can be gentle), not a deferred cliff. The "3-second grasp" claim is replaced by "the *correct* model is learned within the first two levels."

| Level | Teaches | How (near-zero text) |
|---|---|---|
| **0** | Drag = slide → merge | Two identical T1 gems on 4×4 with a clear lane; finger-trail arcs one *sliding* into the other. |
| **1** | Slide is blocked by pieces; space is the rule | A gentle, forgiving board where one matching pair is briefly walled — the **ghost halo** appears; the fix is one easy slide to open the lane. First correct mental model, early. |
| **2** | Build a ladder | Open lanes; slides climb T1→T3. |
| **3** | The showcase poof + "empty = win" | Funnels to a `T5+T5` a slide apart → first **poof** + first piece to the Vault; board clears to ZERO; celebration is the lesson. |
| **4** | Real spatial sequencing | A board where a greedy order strands an orphan — surfaced gently via free Hint + Undo ("Try again — you can't lose"). The real game, safely. |
| **5** | The Wild Gem | The wild (which also slides) as the elegant rescue for a deliberate parity-and-space trap; teaches *when* to save it. |

Coach-marks are diegetic (pointing sparkle, finger-trail showing the *slide path*), dismiss on action, never modal-block more than one beat. **No interstitial tutorials, no forced video, no account gate** — the player is sliding within ~5s of first launch (cold open into L0).

## 6.6 Accessibility

A feature, consistent with "we never block you."

- **Colorblind-safe by construction.** Family identity is encoded **four** redundant ways (hue + silhouette + material + tier-shape, §2.2/§6.1) and tier by size + pips + shine. Optional **"Symbols" mode** adds a distinct glyph per family base. Validated against deuteranopia/protanopia/tritanopia in QA.
- **Path & legality cues are not color-only.** Reachable/unreachable is carried by **halo brightness + animation** (bright pulsing vs dim static ghost), slide lanes by **shape** (recessed channels).
- **One-handed reach.** Board biased to the lower-center thumb arc; actions in the bottom bar; optional left/right-hand toggle mirrors the action bar. Slide gesture is forgiving (snaps to nearest lane within ~0.5 cell of a valid adjacency).
- **Motor / drag assist.** Min 44pt targets, path snapping, and an optional **tap-to-tap merge** (tap source, tap a *reachable* target).

> **Design response — tap-to-tap must not become stealth "merge-anywhere" (low severity).** Auto-routing a tapped merge would remove the choice of *which empty cell to stop on and how to route* — the entire puzzle — quietly reintroducing the confluent game the whole design rejects. **Constraint (locked):** tap-to-tap auto-slides **only when there is a unique non-stranding route**; if multiple routes exist (a genuine routing decision), it **prompts the player to choose the stop cell** rather than auto-resolving. It is documented as an **input-method accommodation, NOT a difficulty reduction.** QA verifies tap-to-tap players hit the **same stranded-rate and 3★-rate distribution** as drag players (a delta means the mode is solving the puzzle for them).

- **Reduce Motion** (honors OS): cuts background drift, depth-of-field, and the slide *animation* (piece jumps to destination instead of gliding), trims the showcase to a quick fade — keeps full clarity and the spatial rules.
- **Text & contrast:** Dynamic Type, ≥ AA contrast on UI text against velvet, scalable fonts.
- **Audio + haptic independence:** fully solvable and satisfying with sound off, haptics off, or both. No information (including path-blocking and legal-target cues) is conveyed *only* by sound or *only* by haptic.
- **No timers, no fail states, unlimited undo/restart** — inherently accessible.

## 6.7 The ideal first 60-second session

```
0:00  App opens. Velvet field, a soft light sweep, "Acorn Forest: Merge!" breathes in/out 1.5s. No login wall,
      no splash ad. One tap: "Play".
0:03  Cold-open into hand-built L0. Two glossy blue gems on a 4×4 velvet board, a clear empty lane
      between them. A sparkle finger-trail arcs one toward the other along the lane.
0:06  Player drags the left gem. It SLIDES through empty cells (glassy glide, a light tick per cell)
      and STOPS next to its match — SNAP. Crystal "tink," medium haptic, sparkle burst, a brighter
      T2 pops on the target cell; the source cell shimmers empty. (~6s in, the slide is understood.)
0:12  L1. A matching pair is briefly walled — the GHOST HALO appears. One easy slide opens the lane,
      then the merge fires. The CORRECT model — "pieces slide and get stopped" — is learned early.
0:20  L3. The board funnels to a final T5+T5 a slide apart. Player drags...
0:23  ★ SHOWCASE POOF ★ — board dims, spotlight irises, the crown catches a big glint, BURSTS into
      gold glitter with a champagne pop and heavy double-haptic. Hero sparkles streak up — the
      Collection Vault icon lights for the first time, catching one piece. (The hook lands.)
0:30  A no-modal whisper: "Empty the board to win." Board clears to ZERO. Slow shimmer sweep.
0:45  "ZERO — collection complete." Stars stamp in with chimes; the Clean-Clear crest lights.
      ✨ + the piece float up into the Vault, which pulses "1/8 — Debut Set."
0:55  A calm "Next." Player taps. Already chasing the set.
1:00  On L4 — the first real spatial-sequencing puzzle — relaxed, confident, emotionally invested in
      filling that Vault. No wall of text, no paywall, no ad, no possible loss.
```

**Must have delivered in 60s:** ≥6 satisfying slide-then-merge clicks, one taste of the good-routing run, one full showcase poof, one ZERO win with stars + Clean-Clear crest, one glimpse of the Vault, and one *early* wordless lesson that *pieces slide and space matters*. If the player feels the slide-glide, the merge click, and the showcase poof in their hands within 30s, the game has done its only truly critical job.

## 6.8 Feel & UX KPI targets (defers to §7.2 for shared retention/economy numbers)

| KPI | Target | Why |
|---|---|---|
| Time-to-first-merge (fresh install) | < 10s median | Cold-open + zero-friction onboarding |
| First-session showcase reached | > 90% of new users | The hero moment must be near-universal |
| **L1 (first blocked-path) completion** | > 85% | The make-or-break gesture-legibility gate (moved here from L4) |
| Tutorial (L0–L3) completion | > 85% | Hand-built teaching is clear |
| L4 (first stranding) completion | > 75% | Proves the slide/space rule is taught, not just stated |
| Input → slide/merge animation latency | < 50ms | The slide must feel instant |
| Haptic / visual sync error | < 16ms (1 frame) | Slide + merge feel like one event |
| Sustained frame rate (ref devices) | 60fps, < 1% dropped | Gloss + smooth slide require smoothness |
| "Satisfying" / "premium" sentiment (survey) | top-2-box > 70% | The feel is the moat |
| Showcase-FX cosmetic attach rate | > 8% of payers | Validates juice-as-monetization |
| Reduce-Motion / colorblind / tap-to-tap adoption | tracked; no completion-rate delta vs default | Accessibility is real, not decorative |

---

# 7. Success Metrics & KPIs

All numeric targets are **launch-quarter targets for a soft-launch geo (CA/AU/NZ/PH) at ~25k DAU**, unless stated. They are concrete so the team can build, instrument, and A/B against them — and each carries a kill/pivot reading in §8.

## 7.1 North-Star Metric

> **North Star: Weekly Solved-and-Satisfied Sessions per Active User (WSS).**
> A "solved-and-satisfied" session = one in which the player **reaches ZERO on at least one level** *and* either (a) earns a new star or Clean-Clear crest, (b) advances a collection set, or (c) returns within 24h.

WSS fuses engagement (they played), the core fantasy (they reached zero), and forward pull (a star/set/return). It resists the two failure modes a no-fail game is prone to (empty grinding sessions; passive completes with no mastery hook).

**WSS target: ≥ 9 solved-and-satisfied sessions / weekly-active user.**

```
                         NORTH STAR (WSS)
        +-------------------+-------------------+
   DO THEY RETURN?     DO THEY ENGAGE?     DO THEY PAY?
   D1/D7/D30           sessions/day        ARPDAU (corrected)
   resurrection        % 3-starred         cosmetic + sub conversion
   churn cohort        set-completion      season-pass + sub attach
                       Clean-Clear rate    rewarded-ad opt-in
```

## 7.2 Canonical KPI Table (single source of truth; all other sections reference this)

The earlier draft scattered conflicting numbers (ARPDAU stated four ways, conversion three ways, etc.). This table supersedes them all. The revenue numbers are the **corrected, re-founded** figures of §5.2 (lower cosmetic ARPPU/conversion, conservative ads, subscription-led).

#### Retention

| KPI | Target | Stretch | Floor |
|---|---|---|---|
| **D1 retention** | **45%** | 52% | 38% |
| **D7 retention** | **22%** | 28% | 16% |
| **D30 retention** | **9%** | 13% | 6% |
| **D30, non-mastery segment** (sub-target, per §4.6) | **6%** | 9% | 4% |
| Resurrection (dormant 7d → active / 30d) | 6% | 9% | — |
| Median lifetime (active days) | 5.5 | 8 | 3.5 |

#### Engagement & mastery

| KPI | Target |
|---|---|
| Sessions / day (active) | **3–5** |
| Median session length | **4–6 min** |
| Levels cleared / session | 2–4 |
| % attempted levels 3-starred (lifetime) | **18%** (early 30%+, taper to 20–25% deep) |
| **Clean-Clear (undo-free) rate, casual-facing** | **≥ 45%** of cleared levels (the planning hook is landing, §3.3) |
| % levels ever replayed | 25% |
| Undo-uses per cleared level | 1–4 early; **alarm > 8** (brute-forcing, R6) |
| Stranded-encounter rate on tight boards | **8–15%** healthy; > 30% on a level = mis-graded |
| Wild-gem usage rate | < 35% of clears |

#### Collection / meta

| KPI | Target |
|---|---|
| Set-progress rate (≥1 set advanced / week) | 70% |
| Set-completion rate (lifetime) | 40% |
| First-set completion time | ≤ 6 sessions |
| Theme/cosmetic unlock by D7 | 55% |
| Vault open rate (% sessions) | 30% |

#### Monetization (corrected, re-founded — §5.2)

| KPI | Target |
|---|---|
| **ARPDAU (blended)** | **$0.05–0.08** |
| — IAP + subscription portion | $0.035–0.06 |
| — Rewarded-ad portion (conservative) | $0.015–0.025 |
| Cosmetic conversion % (lifetime) | **1.5–2.5%** |
| Cosmetic ARPPU (monthly) | **$8–12** |
| **Glow Membership attach (% of MAU)** | **1.5–3%** (ARPU backbone) |
| Season-pass attach (% of MAU) | 1.5–2.5% |
| Convenience-pack conversion % | ≤ 1.5% (must stay *secondary* — cosmetic:convenience revenue ≥ 2:1) |
| Rewarded-ad opt-in rate (% DAU/day) | **25–30%** |
| Rewarded ads / viewer / day | **2.5–3.5** (single canonical figure; per-placement caps sum to 10, global cap 10) |
| ARPPU (all payers, monthly) | $10–16 |
| **D180 projected LTV / installer** | **$0.45–0.75** (corrected; see §8 R5 — paid UA gated, organic-first) |

**Revenue-mix intent (locked):** cosmetics + season pass + subscription are the **majority** of revenue (≥ 65%); convenience packs a minority. If convenience ever exceeds cosmetics, that is a brand-health red flag (the game is being experienced as too hard).

## 7.3 Analytics Event Spec

Events fire client-side with a shared envelope. The spatial core means we log *moves and topology*, not just outcomes — otherwise we cannot diagnose difficulty or detect a broken board.

**Shared envelope:** `user_id, session_id, device_id, platform, app_version, client_ts, server_ts, country, ab_buckets[], is_payer`.

**Lifecycle/funnel:** `app_open` (`source, cold_start_bool`), `session_start`/`session_end` (`duration_sec, levels_attempted, levels_cleared`), `tutorial_step` (`step_id, result, time_on_step_sec`), `ftue_complete`.

**Core gameplay (load-bearing):**

| Event | Key properties |
|---|---|
| `level_start` | `level_id, attempt_index, board_w, board_h, free_cell_count, piece_count, family_count, par_drags, generator_seed, difficulty_grade` |
| `piece_drag` | `level_id, family_id, tier, from_cell, to_cell, path_len, slide_distance, result` (merged / moved_only / **illegal_no_path** / **illegal_no_match**) |
| `merge` | `family_id, result_tier, is_showcase_bool, run_length, occupied_before, occupied_after` |
| `showcase` | `family_id, item_id (named variant), top_tier` |
| `undo` | `level_id, move_index, undo_depth_this_attempt` |
| `restart` | `level_id, moves_before_restart` |
| `wild_used` | `level_id, target_family_id, target_tier, source` |
| `hint_used` | `level_id, source` |
| `am_i_stuck_tapped` | `level_id, move_index, occupied_remaining, client_detector_result` *(best-effort; full proof is offline — §2.9)* |
| `level_complete` | `level_id, drags_used, par_drags, stars, clean_clear_bool, undos_used, wilds_used, hints_used, duration_sec` |
| `level_abandon` | `level_id, drags_used, occupied_remaining` |

> The `illegal_no_path` vs `illegal_no_match` split on `piece_drag` separates *"player doesn't understand sliding"* from *"player picked a non-match"* — the two failure stories behind the slide-friction risk (R7).

**Meta:** `vault_open`, `set_progress`, `set_complete`, `theme_unlock`, `cosmetic_equip`.
**Monetization/LiveOps:** `store_view`, `iap_purchase` (`sku_id, price_usd, revenue, placement`), `subscription_start`/`subscription_renew`/`subscription_cancel`, `rewarded_ad_offer`/`start`/`complete` (`placement, fill_bool`), `season_pass_purchase`, `season_tier_claim`, `daily_challenge_play`/`share`, `live_event_join`/`complete`, `social_share` (`type: zero_clip / friend_vault / ghost_replay`).
**Pipeline/tech:** `gen_board_served` (`seed, engineA_verified, engineB_verified, min_solution_len, par_drags, gen_time_ms`), `solver_timeout`, `perf_frame_drop`, `drag_gesture_fail` (`attempted_path_len, fail_reason`), `crash`/`anr`.

---

# 8. Risk Register (consolidated)

| # | Risk | Severity | Mitigation (and Design response where accepted) |
|---|---|---|---|
| **R1** | Crowded fashion/jewelry theme — looks like a clone in store + first 10s | High | Market the **mechanic inversion** ("the merge game where EMPTY is the win"), never a filling collection; FTUE teaches a *blocking* moment early (§6.5). Trip-wire: store CTR vs category median; "reach zero" creative must beat "merge jewels" on D1 by ≥3 pts. |
| **R2** | No-fail/fairness caps ARPU | High | Monetize identity + completion + **subscription backbone**, not friction; deep Vault cosmetic sink; conservative corrected targets (§5.2, §7.2). Trip-wire: ARPDAU < $0.04 sustained 3 wks at healthy retention → escalate cosmetic/sub cadence, **never add friction**; cosmetic:convenience < 1.5:1 → audit difficulty. |
| **R3** | Puzzle sameness / fatigue (D7→D30 sag) | High | Vary the eight load-bearing levers + **decision-recency** (§3.1/§3.7), not reskins; new-mechanic beats every world; human-curated easy-easy-hard-novel rhythm; variant-seed 3★. Trip-wire: any 10-level band > 1.4× median churn → regrade. |
| **R4** | Spatial solver correctness/cost; a "solvable" board that isn't = breaks the brand | Critical / High | **Two-engine cross-check is canonical pipeline** (§3.5): every shipped board certified by Engine A *and* Engine B; witness stored; mandatory full re-proof for resampled/hand-tweaked/par-tuned boards; golden-set regression; offline-first; node/time caps + resample; runtime undo/restart safety net. Trip-wire: any certified board with a reachable no-zero-path = **P0**; `solver_timeout` > 5% of seeds → tighten constraints. |
| **R5** | Paid UA structurally underwater at realistic CPI | High | **Accepted; organic-or-bust, stated honestly.** Corrected D180 LTV is **$0.45–0.75**, so an LTV:CPI ≥ 1.3 gate needs **CPI ≤ ~$0.35–0.58** — but realistic tier-1 puzzle CPI is **$2.50–5+**, so **paid UA never opens at scale and is not budgeted.** (An earlier draft's "kill if CPI can't be held under ~$1.00" line was internally incoherent: at this LTV, a $1.00 CPI already fails the 1.3 gate — ratio 0.45–0.75. Removed.) Viability is therefore an **organic** bet: organic + influencer + the daily-challenge / ZERO-clip **share loop**. **Organic kill-gate (the real go/no-go):** soft-launch must show a self-sustaining install loop (measurable k-factor / share-driven installs holding the DAU target); if it can't, this is not a viable F2P and must become a **premium paid app ($2.99–4.99)** or be killed. Open paid spend in a geo only if its measured CPI ever falls to **≤ ~$0.50** (LTV:CPI ≥ 1.3). |
| **R6** | Unlimited undo + stuck-detector removes all tension; 1-star majority brute-forces | High | **Stuck-detector non-proactive by default** (opt-in "Am I stuck?", §2.8); casual-facing **Clean-Clear badge** surfaces planning to everyone (§3.3); mastery (no-undo/no-wild/drag-par) is where consequence lives; live drag-vs-par + undo counters. Trip-wire: median undos/cleared > 8 **and** low 3★-attempt rate → tighten affordances. |
| **R7** | Slide-gesture friction on mobile (D1) | High | Path affordances (reachable cells + literal lane highlight; dim/lock illegal targets); valid-merge telegraph; generous snap; **distinct** "no path" vs "no match" feedback; **teach blocking in L1** (§6.5); FTUE gate moved to **L1–L2 completion**. Trip-wire: `drag_gesture_fail` > 12%, or `illegal_no_path` >> `illegal_no_match` in FTUE → rework affordances. |
| **R8** | Differentiating mechanic raises CPI (cerebral, hard to convey in 6s) | High | **Accepted; hard creative gate.** IPM-test 8–12 real "empty-the-board" creatives vs control match/merge before greenlight; fallback creatives lead with the **showcase poof**; treat measured IPM/CPI as a gate, not a hypothesis. If reach-zero creative can't beat category-median CPI, the wedge is invalidated and the project doesn't proceed at scale (§1.6). |
| **R9** | Cosmetic-VFX pipeline is the real (under-budgeted) treadmill | High | Budget the cosmetic-VFX pipeline as the **primary LiveOps line item** (~50 premium assets/quarter, named senior tech-artist/VFX headcount + cost); build a **modular/parametric** cosmetic rig (palette + shader-param variants) for sub-linear art cost (§5.6). Pressure-test that corrected revenue funds it. |
| **R10** | Cosmetic with no audience can't hit ARPPU; D30 leans on hardcore-only loops | High / Med | **Add a visible social surface** (equipped-FX ZERO clips, friend Vault, ghost replays); **subscription backbone**; lower ARPPU assumptions (§5.2). Add a **mass-casual D14–D30 hook** + a separate non-mastery D30 sub-target (§4.6, §7.2). |
| **R11** | Hint/wild dependency drift | Med | Wild scarce by default; ★ disqualification on wild; soft cap 9; solver verifies a no-wild zero-path always exists. Trip-wire: `wild_used` > 35% of clears, or convenience revenue overtaking cosmetics. |
| **R12** | Runtime stuck-detector can't prove global strandedness | Med | **Accepted as best-effort.** Stated explicitly that it does not guarantee detection; undo/restart always recover so a miss costs nothing; bounded signature stores only minimal stranded states within K=6 moves (§2.9). |
| **R13** | Ad-revenue overestimated | Med | Re-forecast at $8–12 eCPM / 25–30% opt-in (§5.5/§7.2); add one value-positive non-rewarded format (watch-to-claim cosmetic shard on natural clear). Model must close at conservative inputs. |
| **R14** | Wild-required parity boards underspecified/unbuildable | Med | Precise weight constraint `2^T·k − 2^(j-1)` with a reachable tier-`j` partner; two-engine solver verifies "only via intended wild," par recomputed from the wild-assisted solution; §2.9 parity-invariance amended to "normal merges only" (§2.10, §3.4). |

---

# 9. Open Questions for Pre-Production (consolidated)

Genuinely unresolved decisions that gate the build. Each names the decision, the tension, and a proposed default to test against. (Items the skeptic panel flagged as outright contradictions — star rule, parity law, campaign size, KPI/currency/economy duplication, family naming — have been **resolved in-spec** and are *not* listed here; what remains are real design unknowns.)

1. **Variant-seed 3★ rollout (§3.3).** Should prestige 3★ on a level accept the authored layout, a procedural same-band variant, *or both*? Default: **both** at launch; measure whether variant-3★ meaningfully lifts replay depth before deciding to make it the only path.

2. **Casual planning hook calibration (§3.3, §2.8).** Is the Clean-Clear badge + opt-in stuck-detector enough to make the 1-star majority plan, or do we need a gentler always-visible "moves left to a clean clear" nudge? Default: ship badge + opt-in detector; soft-launch the R6 trip-wire; add the nudge only if undos/cleared > 8 with low 3★-attempt.

3. **Decision-recency tuning (§3.1).** What's the right minimum decision-recency for shipped levels, and does forcing a late fork ever feel artificial? Default: last forced move at ≥ 40% of solution length; playtest for "feels engineered" and relax per-band if so.

4. **Board-size & free-cell envelope (§2.1, §3.1).** Exact shipped sizes (irregular/carved shapes?) and the tightest *fun-tight* (not fiddly-cruel) `F`. Default: 5×5–6×6 early, up to 7×7 with holes late; never below ~2 free cells on curated boards.

5. **Multi-family showcase interaction & parity surfacing (§2.2, §2.10).** How do we make a parity trap feel *fair and learnable* rather than arbitrary across 2–3 families? Do we ever ship a board clearable *only* via a wild for parity (elegant) or never (purist)? Default: wild-required ≤ 8% of campaign, always ★-max-crested; playtest legibility.

6. **Wild-gem acquisition rates & cap (§2.10, §4.3.5).** Earn cadence that keeps the puzzle intact (R11) without feeling stingy (R6). Default: small earned trickle + rewarded-ad source + optional pack; hard cap 9.

7. **Stranded-state UX depth (§2.8).** Beyond the opt-in "Am I stuck?" button, do we ever offer a "smart undo to last solvable state"? Default: no auto-prompt; the opt-in button only; revisit if playtests show frustration.

8. **Daily-challenge scoring & anti-spoiling (§4.6, §5.6).** What score function makes a no-fail solvable board competitive and shareable (moves-under-par? composite?) and how do we prevent optimal-line spoiling? Default: par-relative composite; ghost replays reveal *a* clean line only after you clear it yourself.

9. **Hint depth (§6.4).** One reachable merge pair vs the next move toward a known zero-path vs a full step? Default: surface one *safe* reachable move (path shown), never the optimal sequence.

10. **Per-level target solve-time as a generator constraint (§3.1, §7.2).** Deep spatial puzzles can run long against the 4–6 min session target. Cap single-level complexity to a solve-time band? Default: add per-level target solve-time as an explicit generator constraint; tune in soft-launch.

11. **Run-length economy tie-in (§6.2d).** Does the (re-keyed, lane-clearing) run grant any scoring/economy value, or stay pure juice? Default: pure juice at launch — tying it to score complicates the honest par/3★ math; revisit only if telemetry shows players want a chaining incentive.

12. **Social-surface scope at launch (§1.5, §4.6).** Which of {equipped-FX ZERO clips, friend Vault, daily-ghost replays} ship at launch vs fast-follow? Default: ship shareable ZERO clips + daily ghosts at launch (cheapest virality + the cosmetic-visibility lever R10 needs); friend Vault as fast-follow.

13. **Subscription value-stack & price (§5.2, §5.4E).** Is $7.99/mo right for the ARPU-backbone role, and is the value stack generous enough to drive 1.5–3% attach without cannibalizing one-off cosmetics? Default: test $5.99 vs $7.99 price cohorts in soft-launch.

14. **Greenlight gates (§1.6, §8 R5/R8).** Two hard pre-greenlight gates: (a) reach-zero creative beats category-median CPI in IPM testing; (b) soft-launch demonstrates a **self-sustaining organic install loop** (measurable k-factor / share-driven installs holding DAU). Note: at the corrected $0.45–0.75 LTV, paid UA needs CPI ≤ ~$0.50 to clear LTV:CPI ≥ 1.3, so it is assumed never to open at scale (§8 R5) — viability rides on (b). Open: exact organic-loop thresholds and number of geos before scaling. Default: both mandatory; if the organic loop can't be shown, pivot to premium paid or kill.