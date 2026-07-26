# Progression Systems — design (2026-07-26)

**Status: draft, awaiting Dev review.** Companions: `docs/design/picturebook_lines_recipes.md`
(the line roster and craft web), `2026-07-17-picturebook-scenes-design.md` (scenes),
`engine/scripts/core/content.gd` §6/§7 (the shipped window + retirement).

All numbers in this doc are **provisional dials** — the economy-sim re-pass owns the finals.

---

## 1 · The problems this design answers

1. **Craft dependencies block retirement.** Specials fold back into base generators forever
   (spices ← wildberries+woolens, tea cups ← spices+wildberries), and the active-line window
   freezes at the last zone — so on the shipped roster retirement fires exactly three times
   (gen_1 past L11, gen_6 past L22, gen_16 past L33) and five generators never retire
   (`content.gd:397`).
2. **The endgame is a content treadmill.** Past the last zone the window freezes; growth
   depends on authoring new scenes. Fine for v1, not a durable engine.
3. **Board pollution.** Off-window lines leave idle generators and dead mid-tier stock on the
   board for 10+ levels between ingredient uses. The shipped retirement offer is correct but
   covers only the three truly-dead lines.
4. **Repetition.** One verb — pop, merge, deliver — with the Rush as the only alternate mode.

**Direction (Dev call, 2026-07-26): systems-first.** Variety and endgame come from repeatable
systems over existing content. New scenes still land, but engagement no longer depends on them.

---

## 2 · The foundation — the Shelf (universal dormancy)

Every line is always in exactly one state:

| State | Meaning | Where its stuff lives |
|---|---|---|
| **Active** | inside the quest window, or an ingredient of a live ask | board |
| **Dormant** | will be asked for again later (usually as a craft ingredient) | the Shelf |
| **Retired** | no remaining level can ever ask for it (`G.gen_retirable`) | Collection trophy |

**Auto-shelve.** When a line leaves the active window, its generator and every leftover piece
sweep off the board into the Shelf automatically — a short sweep animation, no modal, nothing
to confirm, nothing lost. This is the "automatic retirement" of problem 3: the board only ever
holds lines the game currently cares about.

**The label.** Each shelf entry prints when the line matters next, derived from the zone
ladder (always computable): *"Wildberries — needed again at Level 22, for Spices."* The player
never has to wonder whether shelved stock has a future.

**Return.** Generators already re-birth on tap when a craft needs them (`Quests.due_gen` walks
the ingredient tree — shipped). Shelved **stock** is pull-based: open the Shelf, tap pieces to
place them back on the board (board space permitting). Deliveries and crafts still happen only
on the board.

**True retirement** keeps the shipped offer-card ceremony, now reached from the Shelf too: the
line converts to coins (spendable only) and becomes a Collection trophy. With the Shelf in
place, "only three lines ever retire" stops being a problem — dormancy is the cleaner;
retirement is just the epilogue.

---

## 3 · Generator mastery (+ the Scissors)

**Meter.** Each line has a mastery meter fed **only by fence deliveries** of that line's items
(selling never counts — same law as the coin clock). Higher-tier deliveries feed it more
(reuse the item t1-equivalent value curve). Five ranks:

| Rank | Permanent reward |
|---|---|
| 1 | Better burst odds — doubles pop more often |
| 2 | Pops start at tier 2 |
| 3 | Bursts sometimes add a bonus piece |
| 4 | Pops start at tier 3 |
| 5 | Water cost per pop −1 (floor 1) |

**The floor rule.** A line's pop floor always stays ≥3 tiers below its current ask band. If
the band is low, the floor waits. This keeps asks meaningful at every rank.

**Visuals.** A thin progress ring around the generator fills as you deliver. Rank-up: a short
celebration, the generator art gains a visible trim (ribbon → gold edge → blossoms), and a
plain card states the change: *"Berry Bush now pops tier-2 berries."* The library/Shelf entry
shows every line's rank and next reward. Mastery is permanent — it survives shelving and
retirement and gilds the Collection entry forever.

**The Scissors — load-bearing, ships with mastery rank 2.** Crafts merge two ingredient pieces
at the **same tier**, so a tier-3 pop floor would make tier-2 ingredient asks impossible. The
Scissors is a tool item that fixes tier overshoot:

- **Recommended behavior — split:** drag the Scissors onto a piece → it becomes **two pieces
  of one tier lower** (needs one free neighboring cell; refused gently on a full board).
  Value-neutral, feels like scissors, and doubles as a combo-setup tool.
- *Alternative (Dev may prefer): plain reduce — the piece drops one tier, value lost.*
- **Acquisition:** occasional special drop (joins the chest·water·acorn table) plus a cheap
  coin purchase in the shop. Never required before mastery rank 2 exists.
- **Economy guard:** split is value-neutral only if the sell curve doubles per tier; the sim
  must price Scissors so split→sell is never an arbitrage.

---

## 4 · Garden plots (soil cells)

A **soil cell** is a board cell drawn as a small soil patch (placed via Improvements, §7).
Drag any piece onto it → it is planted and grows to **+1 tier**.

**Fast → idle curve.** Growth must be *visible* at low tiers and *idle* at high tiers:

| Planted tier | 1 | 2 | 3 | 4 | 5 | 6 | 7+ |
|---|---|---|---|---|---|---|---|
| Grow time | ~10 s | ~45 s | ~3 min | ~15 min | ~1 h | ~3 h | ~8 h cap |

Tier 1–2 sprout while you watch (a little growth animation — this teaches the mechanic
viscerally). Tier 5+ is the overnight check-back loop.

**Rules.** You cannot plant a piece already at its line's top ask tier (nothing to grow into).
Cancel any time, free — the original piece returns. **Watering:** tap the growing cell to
spend board water and halve the remaining time, once per growth. **Acorns** can finish a grow
instantly, priced by time remaining — this is the game's paid lever: money buys time, never
items (the paid-bundle idea is cut; buying items with quest coins is circular).

**Unlock.** The first soil cell is free at ~level 6 (an FTUE beat: plant a tier-1, watch it
sprout in seconds). Further soil cells and their upgrades come from Improvements (§7):
rank 2 grows 30% faster; rank 3 harvests **+2 tiers** (still respecting the ask-tier cap).

---

## 5 · Weather hours

One grove "day" = **one real hour**. Every hour, a seeded roll (`floor(unix_time / 3600)` —
deterministic, offline-correct, no server) picks the hour's weather. A session sees one or two
skies change; every login feels different. **Never a penalty — weather only gives.**

Two layers:

- **The theme** — the hour's bonus, announced by a cut-paper banner on board entry (and a
  quiet transition if the hour turns mid-session) plus a small HUD icon.
- **The patch** — most weathers project one soft spatial effect (a sunbeam down one column, a
  rain cloud across one row) as a light overlay. The lane is seeded per hour: stable while you
  play, moved by the next sky.

| Weather | Effect |
|---|---|
| **Sunbeam** | merges in the lit column pay double combo coins and count +1 chain step |
| **Rain** | water drops doubled everywhere; soil cells water themselves |
| **Breeze** | a merge result in the breeze row slides one cell toward its nearest match |
| **Harvest sun** | no patch; one featured line pays ×2 coins at the fence |
| **Fireflies** | chest and acorn drop odds up inside the patch |
| **Festival** *(rare, ~1 in 12)* | two of the above at once |

---

## 6 · Cascade combos + ready-ladder outlines

**The chain rule.** A merge continues the chain only if it **uses the piece the previous merge
just created**. Two t2 mushrooms → t3 → drag that t3 onto a neighboring t3 → ×2 → the t4 lands
beside another t4 → ×3. Broken by: any merge that ignores the newest piece, any pop, any
delivery. **Not** broken by plain drags — rearrange and think as long as you like. No timer
anywhere; the skill lives upstream, in setting up the dominoes.

**Ready-ladder outlines (the visual aid).** The board continuously detects **ready ladders** —
a connected group of same-line pieces whose tiers cascade from a duplicated bottom (t2·t2·t3,
then +t4, …). Around each group it draws a stitched cut-paper boundary in the line's palette
color; the boundary **grows and brightens as the player extends the ladder**, with a small
**×N** tag showing the chain waiting inside. The affordance rewards the setup before the
payoff, and makes the mechanic self-teaching. (Detection: for each same-line adjacency
component, check the tier multiset for a duplicated minimum with consecutive steps above it;
recompute on board change — 63 cells, cheap.)

**Rewards.** Per step: +1, +2, +4, +8 coins, capped at +8 past ×5 — **spendable only, never
the clock**. Sparkle and sound pitch escalate; confetti at ×5. Once per day, the first ×5
chain pays a small chest. A sparkle cell (§7) counts a merge made on it as one step higher.

---

## 7 · Improvements (cell upgrades)

Six fixed **improvement slots** on the board perimeter (4 corners + 2 mid-edges). Buy a slot
with coins, then choose what to build; rebuilding to another type later costs a little. This
is the standing **coin sink** the economy lacks. Hard cap: 6 improved cells ever — the board
stays a merge board. Improved cells behave as normal cells (spawning included); only a soil
cell is occupied while something grows.

| Type | Does | Rank 2 | Rank 3 |
|---|---|---|---|
| **Soil** | grows planted pieces (§4) | 30% faster | harvests +2 tiers |
| **Spring** | drips 1 free water onto the board per day | 2/day | 3/day |
| **Sparkle** | a merge on it counts +1 chain step (§6) | double combo coins on it | +chance of a water drop |

Prices: first slot ~500 coins, roughly doubling per slot; ranks cost a multiple of the slot.
(The "cushion" storage cell from brainstorming is **cut** — the Shelf already does storage.)

---

## 8 · Resident trades (fence visitors)

A placed resident occasionally **walks up to the fence** — the existing giver stand, but the
card is visibly different paper with a **trade stamp**: give on the left, get on the right,
one accept button. Not a quest: it never advances the clock, and it cannot be confused with
one. No new screen, no navigation.

**Cadence.** One visiting trader at a time, refreshing roughly daily (seeded per resident,
20–28 h). Decline is free; the visitor returns with a new offer next cycle.

**Offer generation.** The **want** is drawn from your surplus — lines with high board+Shelf
counts outside the current window, mid tiers. The **give** is drawn from what the current
window needs (a tier just under the ask band), or a water bundle, or coins. Value uses the
existing sell curve with a player-favor multiplier (~1.15) — accepting always feels good.
Items are taken and delivered automatically from board + Shelf.

**Guards.** A trade never asks for pieces an active quest needs (recursive needed-set check,
same walk as `due_gen`), and never touches a line below a count threshold.

**Resident tier matters.** Higher-tier residents trade bigger amounts at better rates (up to
~1.3×); top tiers occasionally offer a 1-acorn trade — a felt reason to merge residents up.
Trade flavor follows the resident kind (a koi trades water things).

---

## 9 · Economy guards (cross-cutting laws)

- **The clock is quests only** (unchanged). Combo coins, trade proceeds, and retirement
  payouts are spendable-only.
- **Mastery feeds on deliveries only** — selling and trading never advance a meter.
- **Acorns buy time, never items** (plot finish, and existing uses). The paid-bundle idea is
  rejected.
- **Floors respect asks:** pop floor ≤ ask band − 3; plots refuse pieces at the ask cap.
- **Scissors must not be a sell arbitrage** (sim-checked).
- **Weather never punishes.**

---

## 10 · Rollout (each row = one Dev-given task, own worktree)

Order chosen so each step stands alone and the next builds on it:

1. **Shelf** — auto-shelve on window exit, labels, pull-back, retirement re-homed. (Fixes
   problems 1 + 3 by itself.)
2. **Mastery + Scissors** — meters, ranks, floor rule, rank-up UI; Scissors ships with it.
3. **Combos + ready-ladder outlines.**
4. **Improvements + Soil plots** — slots, the three types (sparkle builds on step 3's chain
   steps), the plot loop, acorn finish.
5. **Weather hours.**
6. **Resident trades.**

Each task carries headless suite coverage; economy-touching steps (2, 3, 6) get a `grove_sim`
re-pass before merge. These are parked in the backlog for the Dev to pull one at a time — not
an autonomous queue.

---

## 11 · Parked (explicitly not in this design)

- **Memory vignettes** (puzzle mini-boards telling the parents' backstory) — strongest future
  candidate for a second mode; parked by Dev call 2026-07-26.
- **The Exhibition** (weekly seeded fair; entries consumed; NPC rivals, no leaderboard) —
  parked with it.
- **Ripening shelf** (passive tier growth while shelved) — superseded by plots; the Shelf
  only stores and labels.
- **Cushion cell** — superseded by the Shelf.
- **Paid tier bundles** — rejected outright (circular economy).

## 12 · Open questions for Dev review

1. Scissors: **split into two** (recommended) or plain reduce-by-one?
2. Trade surface confirmed as fence visitor (recommended), or would you rather scene bubbles?
3. Weather hour length: 60 min per grove day — right feel? Festival at ~1-in-12?
4. Soil FTUE at level 6 — earlier/later?
