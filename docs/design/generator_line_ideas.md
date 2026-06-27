# Generators & lines — redesign ideas (captured brainstorm)

Status: **BAKED INTO THE CANONICAL SPEC + ALL SHIPPED (2026-06-26).** The authoritative model lives in
`merge_spec.md` §6 (banner A–E) and `grove_spec.md` §2 (the as-built tables). All five clusters are now
built: **idea 3** (single persistent generator, a **rolling line window** — older lines retire; revised
2026-06-26 from the earlier "opened lines never retire"), **special drop items** (§6.B —
chest/key/water/acorn/exp/wildcard; the tool was cut), **utility accumulator lines** (§6.C), **temporary
treat generators + per-map special "treasure" lines** (§6.D — one 12-tier fruit per map), and **more
regular lines per map** (§6.E). This file is kept as the working brainstorm + decision log behind that spec.

## Why this exists
Today every line is mechanically identical (tap generator → merge 12 tiers → deliver/sell), so a 2nd
line per zone would feel like a cosmetic swap. We explored two directions and **rejected** one:

- **Rejected — producer→processor chains.** Drag line A's items into generator B to make line C.
  Adds cognitive load ("what feeds what, drag this there") and fights the cozy, low-friction core.
- **Keep — payout/faucet differentiation.** Each line *pays a different resource*; the only decision
  is "what do I need right now?" — no routing. The ideas below build on this.

Vocabulary note: the user wrote "stars" for the progression number; the game collapsed stars into
**exp** (the one progression clock). Read "stars" as "exp" below. "Zone" here means a **restoration
spot/region inside a map** (not a whole map).

---

## Idea 1 — special drop items (can pop from ANY generator)
A pool of special items that can randomly appear from any generator's pops, mixed in with the normal
line. Each behaves differently:

| # | Item | Behaviour |
|---|---|---|
| 1 | **Chest** | merges like coins; yields more rewards (bigger payout the higher it's merged) |
| 2 | **Key** | merges; **opens a chest**; better rewards when merged up |
| 3 | **Water** | merges like coins (energy top-up) |
| 4 | **Acorn** | merges (premium currency) |
| 5 | **Tool** | **single-use, no merge**; opens **any locked cell** (bramble/obstacle) |
| 6 | **Wildcard** | merges with **itself** to raise its tier; also merges with **any other item of the same tier** to advance that line |
| 7 | **Coins** | already in the game (coin pseudo-line) |
| 8 | **Exp** | merges (progression) |

Chest + key are a paired mechanic (key opens chest → reward). Tool is the board-expansion item
(no routing — just tap/use on a locked cell). Wildcard is the scarce "get unstuck" comfort.

## Idea 2 — special resource lines (unlocked across map 1)
The **first 4 spots restored in map 1** each unlock one **special line**:

1. **Water line**
2. **Coin line**
3. **Exp line**
4. **Acorn line**

Rules:
- These lines **do not cost water** to produce.
- They are **accumulators** (not single-click-then-timeout): each banks production **over time up to
  a small cap**. The player checks in and **collects** the banked output; once full it idles until
  collected. The small cap rewards regular check-ins (retention) without grind.
- They live on the board **permanently** — they cost space but pay passively, so the player has a
  standing reason to keep all four placed.

So early progression (restoring the home Farm) hands the player a faucet for each core resource —
delivering early-game variety and a reason to revisit each.

## Idea 3 — a single permanent "smart" generator (replaces per-map generator grants)
A new generator model that removes the constant "which generator do I tap / drag to" question:

1. There is **one generator for the whole game** — no more popping out a new generator each map
   (but there is "something else", see Idea 4).
2. This generator **automatically produces whatever items the current quests need**.
3. Quests don't only ask for the **latest** line — they can ask for **ANY previously-opened line of
   the current map**.
4. With ~3 active quests, the generator may be outputting items from **3 different (random) lines at
   once** — natural variety without the player managing anything.

## Idea 4 — temporary / consumable generators + a per-map special line
1. Each map has **one special line** that gives **better rewards and more exp**.
2. The special line **only comes from special generators**.
3. The single main generator (Idea 3) can, **with some chance, pop out a temporary generator**.
   1. The temporary generator has a **random number of clicks** available; after they're used up it
      **disappears**.

So the premium content (the special line) arrives as an occasional, time-limited burst generator —
a "treat" moment — rather than a permanent fixture to manage.

---

## Decisions (resolved)
- **Drops AND dedicated lines — keep both.** Distinct roles: random **drops = rare serendipity** (a
  pleasant surprise on top), dedicated **accumulator lines = the reliable steady supply**. Cost: each
  resource now has 2 faucets, so they must be budgeted *together* against the invariants.
- **Exp faucet — keep it, tune later.** Accept that an exp line/drop can speed the world; cap it if it
  threatens the 3–4 week arc when we tune.
- **Utility lines = capped accumulators kept on-board permanently** (see Idea 2) — resolves "is it a
  cooldown?": it accumulates to a small cap, the player collects.

## Decisions (resolved) — round 2
- **Board space → use the bag.** Utility generators can be **dragged into the bag and keep
  accumulating clicks there**. The player keeps them on-board while actively collecting, then stows
  them in the bag (off the merge board) where they continue to bank up to their cap. Resolves the
  board-space risk without a new dock surface.
- **Player agency → not a concern (owner call).** The original design is also low-agency — it just had
  multiple generators that get thrown away anyway. This is no worse; the auto-quest generator is an
  acceptable, UI-neutral mechanics swap.

## Open questions / to reconcile (next pass)
- **Do accumulators spawn board ITEMS or just bank a number?** Idea 1 says water/coin/exp/acorn "merge
  like coins" (board items). If accumulators spawn mergeable items, that's *more* board pressure (the
  accumulator cell + its output). If they just bank a collectable number, far less. Decide.
- **Faucet vs the two load-bearing invariants.** Water (the friction / monetization socket) and exp
  (the one pacing clock) now each gain extra faucets (drops + accumulator line). Budget all sources
  together so I2 (water gift < 30% of spend) and the 3–4 week exp arc survive.
- **Wildcard tiering.** Confirm: a wildcard-tN clears a same-tier slot of any line; two wildcards →
  wildcard-t(N+1).
- **Art scope.** Which are full 12-tier lines vs single special items? Chest/key/tool/wildcard may be
  short or single-sprite; the 4 resource lines + per-map special line are bigger.

## Design review — my honest take (2026-06-25)
**Direction is strong.** The single auto-quest generator (Idea 3) genuinely removes the "which
generator / what to merge" load while still producing variety (3 quests → 3 lines). Accumulator
utility lines + treat generators give meaningful, low-load differentiation. It hits the original goal:
variety *without* routing.

**Two things that most decide whether it works:**
1. **Spatial design (board space).** The biggest risk by far — see above. Likely answer: a utility
   dock separate from the merge board.
2. **Preserving agency.** Auto-producing quest items risks a passive "the game plays itself" feel.
   Find the deliberate decision the player makes.

**Reality check on scope.** This is a **core re-architecture**, not an increment. The shipped game is
built around per-map generators (quests, burst, generator-grant rewards, line-introduction pacing all
assume them). Replacing them with one smart generator + accumulators + treat generators touches all of
that — much bigger than the level-curve change. Worth building as its own phased effort with a
prototype, not a single pass.

## Relationship to shipped work
- Builds on the level-curve reshape (one region per level, ~3–4 week arc) — these ideas add *content
  variety*, not pacing.
- Coins already exist as a pseudo-line (`COIN_LINE`), and brambles/obstacles already gate on
  level+merge — the tool item and coin drops have existing hooks to extend.
