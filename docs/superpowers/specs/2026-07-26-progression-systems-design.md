# Progression Systems — design (2026-07-26)

**Status: rev 5, after third Dev review (same day).** Companions:
`docs/design/picturebook_lines_recipes.md` (the line roster and craft web),
`2026-07-17-picturebook-scenes-design.md` (scenes), `engine/scripts/core/content.gd` §6/§7
(the shipped window + retirement).

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

## 2 · The foundation — the Shelf (comeback lines)

Every line is always in exactly one state:

| State | Meaning | Where its stuff lives |
|---|---|---|
| **Active** | inside the quest window, or an ingredient of a live ask | board |
| **Comeback** | will be asked for again later (usually as a craft ingredient) | the Shelf |
| **Retired** | no remaining level can ever ask for it (`G.gen_retirable`) | Collection trophy |

**The comeback ceremony (Dev call, rev 3).** Whenever a line leaves the **Active** state —
its window row rolling off, or the last live ask that borrowed it as an ingredient resolving
— a short
ceremonial dialog plays — the sibling of the retirement card, informational, one OK button:
the line's art, *"The Wildberries head to the shelf — they'll be back at Level 22, for
Spices."* On OK the sweep animation carries the generator and every leftover piece off the
board into the Shelf. Auto-executed (there is no choice to make), but never silent: leaving
is a story beat, and the promise to return is said out loud. Stock the player pulled back by
hand stays out until used — the sweep fires only on this Active→Comeback transition, and an
ingredient line crosses it again each time a craft era ends, so leftovers always have a next
sweep. *(Post-arc, the Shelf empties itself: the final window's lines stay active forever and
every other line has retired — the Shelf is the arc's traffic system, not a permanent hoard.)*

**The label.** Each shelf entry repeats the promise, derived from the zone ladder (always
computable): *"Wildberries — back at Level 22, for Spices."*

**Return.** Generators already re-birth on tap when a craft needs them (`Quests.due_gen`
walks the ingredient tree — shipped). Shelved **stock** is pull-based: open the Shelf, tap
pieces to place them back on the board (board space permitting). Deliveries and crafts still
happen only on the board.

**True retirement** keeps the shipped offer-card ceremony, now reached from the Shelf too:
the line converts to coins (spendable only) and becomes a Collection trophy. With the Shelf
in place, "only three lines ever retire" stops being a problem — the comeback sweep is the
cleaner; retirement is just the epilogue.

---

## 3 · Generator mastery (+ the Scissors)

**The meter — how ranks grow.** Each line's meter counts **value productively used**, in
tier-1 equivalents (a tier-t piece = 2^(t−1)). Two feeds:

- **Fence deliveries** of the line's own items.
- **Craft consumption** — the line's pieces consumed as ingredients in a craft merge. This is
  the load-bearing half: ingredient lines live on long after their own quests stop, and this
  keeps exactly those lines growing through their afterlife.

Selling never feeds a meter.

**How mastery plugs into the existing spawn machinery (rev 5).** Pops already roll a
**spread**, not a flat tier-1: `TIER_ODDS = [0.65, 0.25, 0.09, 0.01]` lands t1–t4 today
(`board_logic.roll_tier`). Mastery therefore does not invent new pop logic — a floor rank
**shifts the whole spread window up** (floor t3 = pops land t3–t6 on the same decaying odds),
and rank 7 turns on, per-line, the **ask-lean dial that already exists in code**
(`ASK_TIER_WEIGHT` in `roll_spawn` — held at 0 globally because the sim showed full-strength
front-loads spend; scoping it to top-mastery lines bounds it, and the step-2 sim re-pass
gates it).

**The ladder — 8 ranks, fast early (rev 3: the old 5-rank ladder ending in a water discount
is cut — pops already cost 1 water, and the real goal is higher pop floors so tier 12 is
actually reachable).** Thresholds step ~×2.2 and start low, so the first ranks land in a
line's first sessions:

| Rank | Threshold (t1-eq) | Permanent reward |
|---|---|---|
| 1 | 20 | Better burst odds — doubles pop more often |
| 2 | 60 | Spread shifts up — pops land t2–t5 |
| 3 | 150 | Bursts sometimes add a bonus piece |
| 4 | 350 | Spread shifts up — pops land t3–t6 |
| 5 | 800 | Bigger bursts — triples possible |
| 6 | 1700 | Spread shifts up — pops land t4–t7 |
| 7 | 3400 | Pops lean toward the tier the fence is asking (the parked `ASK_TIER_WEIGHT` machinery, per-line) |
| 8 | 6500 | Spread shifts up — pops land t5–t8 |

Pacing intent: steady use carries a line to rank 4–6 across its window life and craft
afterlife; rank 8 is the devoted-line goal. **Why floors are the point: at a tier-5 floor, a
tier-12 trophy costs 128 pops, not 2048** — mastery is the road to tier 12.

**The floor rule.** The mastery rank grants an *entitlement*; the **effective** pop floor is
`min(mastery floor, current ask band − 3)`, where the band is the line's **own** live asks. A
comeback line re-birthed as an ingredient tool has no own asks — its mastery floor applies
unclamped, and the Scissors is the bridge down to low ingredient tiers. If the band is low,
the floor waits and unlocks retroactively as bands climb. With ask bands capping at t8, the
effective floor caps at t5 — exactly rank 8's grant, so the two ceilings agree.

**Visuals.** A thin progress ring around the generator fills as you deliver. Rank-up: a short
celebration, the generator art gains a visible trim (ribbon → gold edge → blossoms), and a
plain card states the change: *"Berry Bush now pops tier-2 berries."* The library/Shelf entry
shows every line's rank and next reward. Mastery is permanent — it survives shelving and
retirement and gilds the Collection entry forever.

**The Scissors — load-bearing, ships with mastery.** Crafts merge two ingredient pieces at
the **same tier**, so a tier-3+ pop floor would make tier-2 ingredient asks impossible. The
Scissors is a tool item: drag it onto a piece → the piece **splits into two pieces of one
tier lower** (Dev-confirmed). Needs one free neighboring cell; refused gently on a full
board. Value-neutral, and doubles as a combo-setup tool.

- **Acquisition (rev 5):** a shop item, purchasable with coins, always in stock and cheap.
  (The special-drop source is cut — a tool you need should be bought when needed, not waited
  for.) Never required before mastery rank 2 exists.
- **Economy guard:** split is value-neutral only if the sell curve doubles per tier; the sim
  must price Scissors so split→sell is never an arbitrage.

---

## 4 · Weather hours

One grove "day" = **one real hour**. Every hour, a seeded roll (`floor(unix_time / 3600)` —
deterministic, offline-correct, no server) picks the hour's sky. A session sees one or two
skies change; every login feels different. **Never a penalty — weather only gives.** Home
board only — the Rush keeps its own rules.

Two layers:

- **The sky** — announced by a cut-paper banner on board entry (and a quiet transition if the
  hour turns mid-session) plus a small HUD icon.
- **The patch** — the sky projects one soft spatial effect (a beam down one column, a cloud
  across one row) as a light overlay. The lane is seeded per hour: stable while you play,
  moved by the next sky.

Merges do not pay coins in this game — they **drop** things (the ~10% coin-drop) and **do**
things. Every sky effect is therefore something the patch pops out or triggers, and each row
is mechanically distinct:

| Sky | In the patch… |
|---|---|
| **Sunbeam** | merges pop extra coin drops (rate and count up) |
| **Rain** | merges pop extra water drops; soil cells water themselves free this hour |
| **Magnet** *(rev 5)* | generator pops **land next to their match** when one exists — pairs assemble themselves, nothing merges |
| **Mirror pool** | a merge echoes: one ready pair elsewhere on the board merges itself |
| **Starfall** *(uncommon)* | once this hour, a **high-tier piece** falls onto the lane |

**The starfall drop (rev 4 — replaces the Wild piece, Dev call).** The falling star lands as
a normal piece from a random **active** line, at a weighted high tier: ~80% t8, 15% t9, 5%
t10. Two rules: the roll **skips any line+tier an active quest currently asks for** (the same
guard the mirror echoes obey — an uncommon sky must never complete a top ask outright), and
the piece is ordinary in every way once landed — every system already knows what it is. Why
this replaced the Wild: a wild is a new mechanic needing a special case in chains, outlines,
magnet pulls, mirror echoes, scissors, soil and the Shelf; a t8 piece needs none, its value
is bounded and sim-modelable, and it is a concrete 1/16th of the tier-12 trophy the mastery
ladder is aimed at. (The Wild piece — the last surviving "toy" — moves to Parked, not dead.)

Mirror guards (shared with the mirror cell, §6): echoes pick the **lowest-tier** ready pair,
**skip any pair whose line+tier an active quest asks for**, feed no chain counter, and drop
no combo coins — free value, not an engine.

*(Cut from earlier drafts: Breeze — a weaker, less legible magnet; Harvest sun — duplicate of
Sunbeam; Fireflies — same drop-boost pattern again. **Festival** — parked, rev 3: two
overlapping patch visuals are hard to render well; revisit after the five base skies ship.)*

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
the clock**. Sparkle and sound pitch escalate; confetti at ×5. Once per **real** day
(not grove hour), the first ×5 chain pays a small chest.

---

## 6 · Improvements (cell upgrades) — own a patch of weather

**The principle: improvements mirror the skies.** Weather rents an effect for an hour,
board-wide in one lane; an improvement lets the player **own a small permanent version on one
cell**. Weather is the teacher — you feel Magnet hour, love it, buy a magnet cell. Sun,
Spring and Mirror share their sky's effect code; Magnet shares the *theme* (attraction) with
a different verb — the sky snaps spawns to pairs, the cell arranges ladders on demand.

**When sky and cell overlap (rev 5, the interaction law).** Same-type sky over its cell
(Sun hour + sun cell, Rain + spring, Mirror pool + mirror, Magnet + magnet): the cell acts
**one rank higher** for the hour; if already max rank, its signature number doubles instead
(drop amount, pieces pulled, echoes). Different-type overlap (any cell standing inside any
patch lane): both effects simply apply, independent — no interaction, nothing to memorize.

Six fixed **improvement slots** on the board perimeter (4 corners + 2 mid-edges). Buy a slot
with coins, then choose what to build; rebuilding to another type later costs a little. This
is the standing **coin sink** the economy lacks. Hard cap: 6 improved cells ever — the board
stays a merge board. Improved cells behave as normal cells (spawning included); only a soil
cell is occupied while something grows.

| Cell | Effect | Rank ladder |
|---|---|---|
| **Sun** | a merge on it pops extra coin drops | 3 ranks: better odds → more per drop |
| **Spring** | a merge on it pops extra water drops | 3 ranks: better odds → more per drop |
| **Magnet** | **place** (don't merge) a piece on it → it arranges a ready ladder around itself | 4 ranks, below |
| **Mirror** *(unique — max 1 on the board)* | a merge on it echoes ready pairs elsewhere | 4 ranks, below |
| **Soil** | *(no sky version)* plant a piece → it grows +1 tier | 3 ranks: 30% faster → harvests +2 tiers |

**Magnet — the ladder-builder (rev 5).** The rev-3 version pulled a match for each merge's
result — which handed the player the next chain step mid-cascade and collided with the chain
rule. Rebuilt on a different trigger: **placing** a piece onto the magnet (a plain drag — an
action that never breaks a chain and never merges anything; a spawn landing there does
not trigger it). The magnet then pulls that
piece's line-mates in and lays them out as a connected cascade ladder around itself — a
same-tier partner first, then ascending tiers as available. **Nothing merges**: the ready-
ladder outline (§5) lights up around the arrangement, and tipping it over stays the player's
move. Pulled pieces glide one at a time; pieces growing in soil and a live chain's newest
piece are never taken.

| Rank | The arrangement |
|---|---|
| 1 | pulls from within ~3 cells, up to 3 pieces |
| 2 | reach becomes the whole board |
| 3 | up to 5 pieces |
| 4 | no cap — the longest ladder the board can offer |

At rank 4 the cell earns its name: drop one berry on it, and the board lays the whole
cascade at your feet — the tip-over is still yours.

**Mirror — echoes scale like magnet (rev 3: no cooldown; capped at one cell instead).**
Why max 1: the player chooses where to merge, so every merge can already be funneled through
one pool — a second adds nothing but a duplicate landmark. Uniqueness also keeps its board
presence special.

| Rank | Each merge on it… |
|---|---|
| 1 | echoes 1 ready pair |
| 2 | echoes 2 ready pairs |
| 3 | echoes 3 ready pairs |
| 4 | echoes may **bounce** — if an echoed merge creates a new ready pair, that merges too (one bounce per echo) |

Mirror-cell echoes follow the §4 guards: lowest-tier pairs first, never a pair an active
quest asks for, no chain credit, no combo coins.

**Soil, in detail.** Drag any piece onto soil → it is planted and grows to +1 tier. Growth is
**visible at low tiers, idle at high tiers**:

| Planted tier | 1 | 2 | 3 | 4 | 5 | 6 | 7+ |
|---|---|---|---|---|---|---|---|
| Grow time | ~10 s | ~45 s | ~3 min | ~15 min | ~1 h | ~3 h | ~8 h cap |

Tier 1–2 sprout while you watch (a little growth animation — the mechanic teaches itself).
Tier 5+ is the overnight check-back loop. You cannot plant a piece already at its line's top
ask tier, and **harvests clamp at that cap** (a rank-3 +2 growth from one tier below the cap
still lands at the cap, not past it) — the road to tier 12 is mastery and merging, not idle
waiting. Cancel any time, free. **Watering:** tap the growing cell to spend board water and
halve the remaining time, once per growth. **Acorns** finish a grow instantly, priced by time
remaining — the paid lever: money buys time, never items.

**Unlock.** The first soil cell is free at ~level 6 (an FTUE beat: plant a tier-1, watch it
sprout in seconds). Everything else: first slot ~500 coins, roughly doubling per slot; ranks
cost a multiple of the slot.

---

## 7 · Economy guards (cross-cutting laws)

- **The clock is quests only** (unchanged). Combo coins and retirement payouts are
  spendable-only.
- **Mastery feeds on productive use only** — fence deliveries and craft consumption; selling
  never.
- **Acorns buy time, never items** (soil finish, and existing uses). The paid-bundle idea is
  rejected.
- **Floors respect asks:** effective pop floor = min(mastery floor, ask band − 3); soil
  refuses pieces at the ask cap and clamps harvests to it.
- **Scissors must not be a sell arbitrage** (sim-checked).
- **Echo merges are free value, not an engine** — no chain credit, no combo coins, never a
  quest-asked pair.
- **Weather never punishes.**

---

## 8 · Rollout (each row = one Dev-given task, own worktree)

Order chosen so each step stands alone and the next builds on it. Weather lands before
Improvements because Sun/Spring/Mirror cells reuse the sky effect code (the Magnet cell's
arranger is its own build — only the theme is shared).

1. **Shelf** — comeback ceremony, auto-sweep, labels, pull-back, retirement re-homed. (Fixes
   problems 1 + 3 by itself.)
2. **Mastery + Scissors** — meters, 8 ranks, floor rule, rank-up UI; Scissors ships with it.
3. **Combos + ready-ladder outlines + cascade FTUE.**
4. **Weather hours** — the sky roll, the patch, the five skies, the starfall drop.
5. **Improvements** — slots, the five cell types (reusing step 4's effects), the soil loop,
   acorn finish.

Each task carries headless suite coverage; economy-touching steps (2, 5) get a `grove_sim`
re-pass before merge. These are parked in the backlog for the Dev to pull one at a time — not
an autonomous queue.

---

## 9 · Parked (explicitly not in this design)

- **The Wild piece** (star piece that merges with anything as its t+1) — replaced by the
  starfall drop, rev 4: a new mechanic needing special cases across every other system, where
  a plain t8 piece needs none. Revisit only if the game wants a toy back.
- **Resident trades** (fence-visitor barter: wants drawn from surplus, gives from current
  needs, ~1.15 player-favor rate, resident tier improves rates) — parked, rev 3.
- **Festival sky** (two skies at once) — parked, rev 3: overlapping patch visuals are hard;
  revisit after the five base skies ship.
- **Memory vignettes** (puzzle mini-boards telling the parents' backstory) — strongest future
  candidate for a second mode; parked by Dev call 2026-07-26.
- **The Exhibition** (weekly seeded fair; entries consumed; NPC rivals, no leaderboard) —
  parked with it.
- **Ripening shelf** (passive tier growth while shelved) — superseded by soil; the Shelf only
  stores and labels.
- **Cushion cell** — superseded by the Shelf. **Sparkle cell** — superseded by the
  weather-mirror cell set.
- **Breeze / Harvest sun / Fireflies skies** — cut as weak or duplicate effects (§4).
- **Paid tier bundles** — rejected outright (circular economy).

## 10 · Open questions for Dev review

1. Mastery craft-consumption credit (§3) is a new law — confirm.
2. Soil FTUE at level 6 — earlier/later?
