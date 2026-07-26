# Progression Systems — design (2026-07-26)

**Status: revised after Dev review (same day).** Companions: `docs/design/picturebook_lines_recipes.md`
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

**The meter — how ranks grow.** Each line's meter counts **value productively used**, in
tier-1 equivalents (a tier-t piece = 2^(t−1)). Two feeds:

- **Fence deliveries** of the line's own items.
- **Craft consumption** — the line's pieces consumed as ingredients in a craft merge. This is
  the load-bearing half: ingredient lines live on long after their own quests stop, and this
  keeps exactly those lines growing through their afterlife.

Selling and trading never feed a meter. Rank thresholds step ~×3 (provisional):

| Rank | Threshold (t1-eq) | Permanent reward |
|---|---|---|
| 1 | 30 | Better burst odds — doubles pop more often |
| 2 | 120 | Pops start at tier 2 |
| 3 | 350 | Bursts sometimes add a bonus piece |
| 4 | 900 | Pops start at tier 3 |
| 5 | 2400 | Water cost per pop −1 (floor 1) |

Expected pacing: rank 1 in the first session with a line; ranks 2–3 across its quest-window
life; ranks 4–5 accumulate slowly through its ingredient afterlife.

**The floor rule.** A line's pop floor always stays ≥3 tiers below its current ask band. If
the band is low, the floor waits. This keeps asks meaningful at every rank.

**Visuals.** A thin progress ring around the generator fills as you deliver. Rank-up: a short
celebration, the generator art gains a visible trim (ribbon → gold edge → blossoms), and a
plain card states the change: *"Berry Bush now pops tier-2 berries."* The library/Shelf entry
shows every line's rank and next reward. Mastery is permanent — it survives shelving and
retirement and gilds the Collection entry forever.

**The Scissors — load-bearing, ships with mastery.** Crafts merge two ingredient pieces at
the **same tier**, so a tier-3 pop floor would make tier-2 ingredient asks impossible. The
Scissors is a tool item: drag it onto a piece → the piece **splits into two pieces of one
tier lower** (Dev-confirmed behavior). Needs one free neighboring cell; refused gently on a
full board. Value-neutral, and doubles as a combo-setup tool.

- **Acquisition:** occasional special drop (joins the chest·water·acorn table) plus a cheap
  coin purchase in the shop. Never required before mastery rank 2 exists.
- **Economy guard:** split is value-neutral only if the sell curve doubles per tier; the sim
  must price Scissors so split→sell is never an arbitrage.

---

## 4 · Weather hours

One grove "day" = **one real hour**. Every hour, a seeded roll (`floor(unix_time / 3600)` —
deterministic, offline-correct, no server) picks the hour's sky. A session sees one or two
skies change; every login feels different. **Never a penalty — weather only gives.**

Two layers:

- **The sky** — announced by a cut-paper banner on board entry (and a quiet transition if the
  hour turns mid-session) plus a small HUD icon.
- **The patch** — the sky projects one soft spatial effect (a beam down one column, a cloud
  across one row) as a light overlay. The lane is seeded per hour: stable while you play,
  moved by the next sky.

Merges do not pay coins in this game — they **drop** things (the ~10% coin-drop) and **do**
things. Every sky effect is therefore something a merge in the patch pops out or triggers,
and each row is mechanically distinct:

| Sky | A merge in the patch… |
|---|---|
| **Sunbeam** | pops extra coin drops (rate and count up) |
| **Rain** | pops extra water drops; soil cells water themselves free this hour |
| **Magnet** | pulls the nearest same-line-same-tier piece adjacent to the result — chain fuel |
| **Mirror pool** | echoes: one ready pair elsewhere on the board merges itself |
| **Starfall** *(uncommon)* | once this hour, a free Wild piece drifts down onto the lane |
| **Festival** *(rare, ~1 in 12)* | two skies at once |

Mirror guards: the echo picks the **lowest-tier** ready pair (never spends a pair being saved
for something big), and echo merges feed **no** chain counter and drop **no** combo coins —
free value, not an engine. *(Cut from the earlier draft: Breeze — a weaker, less legible
magnet; Harvest sun — duplicate of Sunbeam; Fireflies — same drop-boost pattern again.)*

---

## 5 · Cascade combos + ready-ladder outlines

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
payoff. (Detection: for each same-line adjacency component, check the tier multiset for a
duplicated minimum with consecutive steps above it; recompute on board change — 63 cells,
cheap.)

**FTUE.** The first time a ready ladder exists on the board, a one-time cut-paper dialog
introduces cascades: the outline lights up and the existing hand-hint system traces the
tip-over merge. One show, then never again (standard FTUE flagging).

**Rewards.** Per step: +1, +2, +4, +8 coins, capped at +8 past ×5 — **spendable only, never
the clock**. Sparkle and sound pitch escalate; confetti at ×5. Once per day, the first ×5
chain pays a small chest.

---

## 6 · Improvements (cell upgrades) — own a patch of weather

**The principle (Dev call): improvements mirror the skies.** Weather rents an effect for an
hour, board-wide in one lane; an improvement lets the player **own a small permanent version
on one cell**. Weather is the teacher — you feel Magnet hour, love it, buy a magnet cell.
When the sky matches your cell (Sun hour over a sun cell), that cell shines double.

Six fixed **improvement slots** on the board perimeter (4 corners + 2 mid-edges). Buy a slot
with coins, then choose what to build; rebuilding to another type later costs a little. This
is the standing **coin sink** the economy lacks. Hard cap: 6 improved cells ever — the board
stays a merge board. Improved cells behave as normal cells (spawning included); only a soil
cell is occupied while something grows.

| Cell | A merge on it… | Rank 2 | Rank 3 |
|---|---|---|---|
| **Sun** | pops extra coin drops | better odds | more coins per drop |
| **Spring** | pops extra water drops | better odds | more water per drop |
| **Magnet** | pulls the nearest same-line-same-tier piece adjacent | pulls 2 pieces | pulls from anywhere on the board |
| **Mirror** | echoes one ready pair (cooldown: once per grove hour) | cooldown halves | 2 echoes per hour |
| **Soil** | *(no sky version)* plant a piece → it grows +1 tier | 30% faster | harvests +2 tiers |

Mirror-cell echoes follow the same guards as Mirror weather (lowest pair, no chain credit).

**Soil, in detail** (folded in from the old plots section). Drag any piece onto soil → it is
planted and grows to +1 tier. Growth is **visible at low tiers, idle at high tiers**:

| Planted tier | 1 | 2 | 3 | 4 | 5 | 6 | 7+ |
|---|---|---|---|---|---|---|---|
| Grow time | ~10 s | ~45 s | ~3 min | ~15 min | ~1 h | ~3 h | ~8 h cap |

Tier 1–2 sprout while you watch (a little growth animation — the mechanic teaches itself).
Tier 5+ is the overnight check-back loop. You cannot plant a piece already at its line's top
ask tier. Cancel any time, free. **Watering:** tap the growing cell to spend board water and
halve the remaining time, once per growth. **Acorns** finish a grow instantly, priced by time
remaining — the paid lever: money buys time, never items.

**Unlock.** The first soil cell is free at ~level 6 (an FTUE beat: plant a tier-1, watch it
sprout in seconds). Everything else: first slot ~500 coins, roughly doubling per slot; ranks
cost a multiple of the slot.

---

## 7 · Resident trades (fence visitors)

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

## 8 · Economy guards (cross-cutting laws)

- **The clock is quests only** (unchanged). Combo coins, trade proceeds, and retirement
  payouts are spendable-only.
- **Mastery feeds on productive use only** — fence deliveries and craft consumption; selling
  and trading never.
- **Acorns buy time, never items** (soil finish, and existing uses). The paid-bundle idea is
  rejected.
- **Floors respect asks:** pop floor ≤ ask band − 3; soil refuses pieces at the ask cap.
- **Scissors must not be a sell arbitrage** (sim-checked).
- **Echo merges are free value, not an engine** — no chain credit, no combo coins.
- **Weather never punishes.**

---

## 9 · Rollout (each row = one Dev-given task, own worktree)

Order chosen so each step stands alone and the next builds on it. Weather lands before
Improvements because the cells are permanent versions of the sky effects (shared effect code).

1. **Shelf** — auto-shelve on window exit, labels, pull-back, retirement re-homed. (Fixes
   problems 1 + 3 by itself.)
2. **Mastery + Scissors** — meters, ranks, floor rule, rank-up UI; Scissors ships with it.
3. **Combos + ready-ladder outlines + cascade FTUE.**
4. **Weather hours** — the sky roll, the patch, the six skies.
5. **Improvements** — slots, the five cell types (reusing step 4's effects), the soil loop,
   acorn finish.
6. **Resident trades.**

Each task carries headless suite coverage; economy-touching steps (2, 5, 6) get a `grove_sim`
re-pass before merge. These are parked in the backlog for the Dev to pull one at a time — not
an autonomous queue.

---

## 10 · Parked (explicitly not in this design)

- **Memory vignettes** (puzzle mini-boards telling the parents' backstory) — strongest future
  candidate for a second mode; parked by Dev call 2026-07-26.
- **The Exhibition** (weekly seeded fair; entries consumed; NPC rivals, no leaderboard) —
  parked with it.
- **Ripening shelf** (passive tier growth while shelved) — superseded by soil; the Shelf
  only stores and labels.
- **Cushion cell** — superseded by the Shelf. **Sparkle cell** — superseded by the
  weather-mirror cell set.
- **Breeze / Harvest sun / Fireflies skies** — cut as weak or duplicate effects (§4).
- **Paid tier bundles** — rejected outright (circular economy).

## 11 · Open questions for Dev review

1. Mirror echo target: lowest-tier ready pair (recommended) — confirm.
2. Mastery craft-consumption credit (§3) is a new law — confirm.
3. Soil FTUE at level 6 — earlier/later?
