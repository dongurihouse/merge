# Progression Systems — design (2026-07-26)

**Status: rev 6, after fourth Dev review (same day).** Companions:
`docs/design/picturebook_lines_recipes.md` (the line roster and craft web),
`2026-07-17-picturebook-scenes-design.md` (scenes), `engine/scripts/core/content.gd` §6/§7
(the shipped window + retirement).

All numbers in this doc are **provisional dials** — the economy-sim re-pass owns the finals.

---

## 1 · The problems this design answers

1. **Craft dependencies block retirement.** Specials fold back into base generators forever
   (spices ← wildberries+woolens, tea cups ← spices+wildberries), and the active-line window
   freezes at the last zone — so on the shipped roster retirement fires exactly three times
   (gen_1/gen_6/gen_16, each at its `zone_unlock_level(3)/(8)/(11)` boundary — L33/L55/L69 on
   today's derived cadence) and five generators never retire (`content.gd:397`).
2. **The endgame is a content treadmill.** Past the last zone the window freezes; growth
   depends on authoring new scenes. Fine for v1, not a durable engine.
3. **Board pollution.** Off-window lines leave idle generators and dead mid-tier stock on the
   board for 10+ levels between ingredient uses. The shipped retirement offer is correct but
   covers only the three truly-dead lines.
4. **Repetition.** One verb — pop, merge, deliver — with the Rush as the only alternate mode.

**Direction (Dev call, 2026-07-26): systems-first.** Variety and endgame come from repeatable
systems over existing content. New scenes still land, but engagement no longer depends on them.

**The split (rev 6):** the **sky gives** — weather is passive gifts falling into play (coins,
water, a starfall piece); the **ground works** — improvements are owned tools built on cells
(grow, arrange, echo). The two vocabularies never overlap.

---

## 2 · The foundation — the Shelf (comeback lines)

Every line is always in exactly one state:

| State | Meaning | Where its stuff lives |
|---|---|---|
| **Active** | inside the quest window, or an ingredient of a live ask | board |
| **Comeback** | will be asked for again later (usually as a craft ingredient) | the Shelf |
| **Retired** | no remaining level can ever ask for it (`G.gen_retirable`) | Collection trophy |

**The farewell card (rev 6 — one component, one line of text, both states).** Comeback and
retirement use the **same card**: the line's art centered, **exactly one line of text**, one
button.

- Comeback: *"The Wildberries will be back at Level 69, for Tea Cups."* — button **OK**
  (auto-executed on close; there is no choice to make).
- Retirement: *"The Glowshrooms' story is complete — 340 coins join your purse."* — button
  **Retire**, dismissable (the shipped offer semantics; the info-bar sell path remains the
  manual fallback).

The card fires whenever a line leaves the **Active** state — its window row rolling off, or
the last live ask that borrowed it as an ingredient resolving. On close, the sweep animation
carries the generator and every leftover piece off the board into the Shelf. Stock the player
pulled back by hand stays out until used — the sweep fires only on the Active→Comeback
transition, and an ingredient line crosses it again each time a craft era ends, so leftovers
always have a next sweep. *(Post-arc the Shelf empties itself: the final window's lines stay
active forever and every other line has retired — the Shelf is the arc's traffic system, not
a permanent hoard.)*

**Return.** Generators already re-birth on tap when a craft needs them (`Quests.due_gen`
walks the ingredient tree — shipped). Shelved **stock** is pull-based: open the Shelf, tap
pieces to place them back on the board (board space permitting). Deliveries and crafts still
happen only on the board.

**UI.**

- **Where it lives:** the bottom-nav bag well opens a two-tab panel — **Bag** (loose stored
  pieces, the existing surface) and **Shelf** (per-line rows). No new nav entry.
- **A shelf row:** line icon with its mastery trim · count-per-tier chips (tap a chip →
  that piece returns to the board, space permitting) · the one-line promise in small text:
  *"Back at L51 · for Spices."* A retirable line's row swaps the promise for a **Retire**
  button that opens the farewell card.
- **The farewell card:** centered cut-paper card over a dim veil (the existing overlay
  pattern): line art, the one line, the one button. No stat blocks, no item grids.
- **The sweep:** pieces and generator arc off-board toward the bag well (the existing
  fly-to-well FX), staggered, ~1 s total.

---

## 3 · Generator mastery (+ the Scissors)

**The meter.** Each line's meter counts **value productively used**, in tier-1 equivalents
(a tier-t piece = 2^(t−1)). Two feeds: **fence deliveries** of the line's own items, and
**craft consumption** — the line's pieces consumed as ingredients in a craft merge (the
load-bearing half: it keeps ingredient lines growing through their afterlife). Selling never
feeds a meter.

**How mastery plugs into the existing spawn machinery.** Pops already roll a **spread**, not
a flat tier-1: `TIER_ODDS = [0.65, 0.25, 0.09, 0.01]` lands t1–t4 today
(`board_logic.roll_tier`). Mastery does not invent new pop logic — a floor rank **shifts the
whole spread window up** (floor t3 = pops land t3–t6 on the same decaying odds), and rank 7
turns on, per-line, the **ask-lean dial that already exists in code** (`ASK_TIER_WEIGHT` in
`roll_spawn` — held at 0 globally because the sim showed full-strength front-loads spend;
scoping it to top-mastery lines bounds it, and the step-2 sim re-pass gates it).

**The ladder — 8 ranks, fast early.** Thresholds step ~×2.2 and start low:

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

**The Scissors — load-bearing, ships with mastery.** Crafts merge two ingredient pieces at
the **same tier**, so a tier-3+ pop floor would make tier-2 ingredient asks impossible. The
Scissors is a tool item: drag it onto a piece → the piece **splits into two pieces of one
tier lower**. Needs one free neighboring cell; refused gently on a full board.
Value-neutral, and doubles as a combo-setup tool.

- **Acquisition:** a shop item, purchasable with coins, always in stock and cheap. Never
  required before mastery rank 2 exists.
- **Economy guard:** the sim must price Scissors so split→sell is never an arbitrage.

**UI.**

- **The ring:** a thin progress ring in the line's palette color around the generator,
  filling clockwise as the meter grows. No numbers on the board.
- **The trim:** at each floor rank (2 / 4 / 6 / 8) the generator art gains a visible trim —
  ribbon → bronze edge → silver edge → gold blossom — so a glance says how far a line has
  come. Same trim gilds the line's Shelf row and Collection entry.
- **Rank-up:** the existing celebration pattern — brief confetti, then a small card:
  generator art + one line (*"Berry Bush — pops now land t3–t6."*) + Continue.
- **Inspect:** selecting a generator already surfaces the info-bar; it gains one mastery
  line: rank pips, a slim meter bar, and the next reward in six words.
- **Scissors in shop:** one shop row — scissors art, price, one line: *"Cuts a piece into
  two of a tier lower."* Bought scissors land on the board as a tool piece.
- **Scissors in hand:** dragging it over a piece ghosts the two result halves; drop plays a
  snip + the halves pop apart into the free cell. Over an ineligible target (tier 1, no free
  neighbor) the ghost shakes its head — no snip, no loss.

---

## 4 · Weather hours — the sky gives

One grove "day" = **one real hour**. Every hour, a seeded roll (`floor(unix_time / 3600)` —
deterministic, offline-correct, no server) picks the hour's sky. A session sees one or two
skies change; every login feels different. **Never a penalty — weather only gives.** Home
board only — the Rush keeps its own rules.

Two layers:

- **The sky** — the hour's gift, announced once.
- **The patch** — the sky projects one soft spatial effect (a beam down one column, a cloud
  across one row) as a light overlay. The lane is seeded per hour: stable while you play,
  moved by the next sky.

Three skies (rev 6 — Magnet and Mirror moved to cells only, §6; weather is the passive-gift
vocabulary):

| Sky | In the patch… |
|---|---|
| **Sunbeam** | merges pop extra coin drops (rate and count up) |
| **Rain** | merges pop extra water drops; soil cells water themselves free this hour |
| **Starfall** *(uncommon)* | once this hour, a **high-tier piece** falls onto the lane |

**The starfall drop.** The falling star lands as a normal piece from a random **active**
line, at a weighted high tier: ~80% t8, 15% t9, 5% t10. Two rules: the roll **skips any
line+tier an active quest currently asks for** (a sky must never complete a top ask
outright), and the piece is ordinary in every way once landed. (This replaced the Wild piece
— rationale in §9.)

**UI.**

- **The banner:** on board entry (and on an hour turn mid-session), a full-width cut-paper
  strip slides down under the HUD — sky icon, name, one line (*"Rain — merges shake water
  loose."*) — and auto-dismisses in ~2.5 s.
- **The HUD chip:** a small sky icon sits by the top info bar all hour; tapping it replays
  the banner line.
- **The patch:** a low-alpha light overlay on its lane — a warm shaft for Sunbeam, a drifting
  cloud shadow with sparse droplet particles for Rain, a faint star-glimmer for Starfall.
  Soft-edged, slow shimmer, under the pieces — legible, never loud.
- **Sky turn:** the old overlay cross-fades out, the new banner plays once.
- **The star:** when Starfall pays out, the piece arcs down onto the lane with a comet trail
  and lands with the standard spawn bounce.

---

## 5 · Cascade combos + ready-ladder outlines

**The chain rule.** A merge continues the chain only if it **uses the piece the previous
merge just created**. Two t2 mushrooms → t3 → drag that t3 onto a neighboring t3 → ×2 → the
t4 lands beside another t4 → ×3. Broken by: any merge that ignores the newest piece, any pop,
any delivery. **Not** broken by plain drags — rearrange and think as long as you like. No
timer anywhere; the skill lives upstream, in setting up the dominoes.

**Ready-ladder outlines.** The board continuously detects **ready ladders** — a connected
group of same-line pieces whose tiers cascade from a duplicated bottom (t2·t2·t3, then +t4,
…). Around each group it draws a stitched cut-paper boundary in the line's palette color; the
boundary **grows and brightens as the player extends the ladder**, with a small **×N** tag
showing the chain waiting inside. (Detection: per same-line adjacency component, check the
tier multiset for a duplicated minimum with consecutive steps above it; recompute on board
change — 63 cells, cheap.)

**FTUE.** The first time a ready ladder exists, a one-time cut-paper dialog introduces
cascades: the outline lights up and the existing hand-hint traces the tip-over merge.

**Rewards.** Per step: +1, +2, +4, +8 coins, capped at +8 past ×5 — **spendable only, never
the clock**. Once per **real** day (not grove hour), the first ×5 chain pays a small chest.

**UI.**

- **The outline:** dashed "stitching" along the group's outer cell edges, in the line's
  palette color, drawn under the pieces. Each rung added thickens the stitch one step and
  brightens it; the **×N** paper tag pins to the top-tier piece's corner and counts up.
- **The chain counter:** on each chain step, a small "×2 · ×3 · ×4" floats up from the merge
  with escalating sparkle; the chain drives no audio of its own — cascading merges ride the
  existing time-window merge-streak melody (the baked pentatonic note ladder in the FX layer,
  not `board_logic` — rev 2 separation call, cascade-combos spec §2 delta 1). Confetti burst
  at ×5.
- **The daily chest:** on the first ×5 of the day, a chest drops onto a free cell with the
  standard chest FX — no modal.
- **The FTUE dialog:** one centered card — a tiny 3-piece diagram (t·t·t+1 with an arrow),
  one line: *"Merge the pair — the new piece lands by its match. Keep going."* — Got it.

---

## 6 · Improvements (cell upgrades) — the ground works

Three buildable cell types (rev 6 — Sun and Spring cut: coin/water gifts are the sky's
vocabulary; cells are **owned tools**): **Soil** grows, **Magnet** arranges, **Mirror**
echoes.

Six fixed **improvement slots** on the board perimeter (4 corners + 2 mid-edges). Buy a slot
with coins, then choose what to build; rebuilding to another type later costs a little. This
is the standing **coin sink** the economy lacks. Hard cap: 6 improved cells ever — the board
stays a merge board. A cell inside a weather patch simply enjoys both effects independently
(Rain still waters soil free); there is no same-type overlap to reason about.

| Cell | Verb | Rank ladder |
|---|---|---|
| **Soil** | plant a piece → it grows +1 tier | 3 ranks: 30% faster → harvests +2 tiers |
| **Magnet** | hold a piece → its ladder gathers around it | 3 ranks, below |
| **Mirror** *(unique — max 1)* | a merge on it echoes ready pairs elsewhere | 4 ranks, below |

**Magnet — the ladder loom (rev 6, rebuilt for clarity).** The magnet **holds** one piece:
placing is its only verb, exactly like soil — you never merge *on* a magnet, and a spawn
landing there does not trigger it. While a piece sits on it, the magnet **attracts that
piece's ladder**: whenever a same-line piece exists (or appears) whose tier extends the
ladder — first a same-tier partner, then t+1, then t+2… — it glides over, one piece at a
time, and parks in the next cell of a snake around the magnet. **Attraction only positions
pieces; nothing ever merges by itself** — the §5 outline lights up over the growing
arrangement, and the tip-over is always the player's move.

The walkthrough (place a t1): a second t1 glides in beside it (the pair) → a t2 parks next →
a t3 next, rank permitting. Merge the pair when ready: the t2 result lands beside the parked
t2 → ×2 → its t3 lands beside the parked t3 → ×3. The magnet pre-builds the dominoes; the
player tips them.

Attracted pieces stay ordinary — drag one away and the magnet re-attracts when a new
candidate appears. It never takes a piece growing in soil or the newest piece of a live
chain. After a cascade consumes the arrangement, the magnet sits empty until the next piece
is placed.

| Rank | The gathered ladder |
|---|---|
| 1 | the pair + 1 rung (a ×2 waits) |
| 2 | the pair + 3 rungs (a ×4 waits) |
| 3 | unlimited rungs — the longest ladder the board can offer |

**Mirror — merge here, harvest there.** A merge **on** the mirror echoes: ready pairs
elsewhere on the board merge themselves. No cooldown; the cost is that ready pairs are
finite. Max 1 on the board: every merge can already be funneled through one pool, so a second
adds nothing but a duplicate landmark — uniqueness keeps it special.

| Rank | Each merge on it… |
|---|---|
| 1 | echoes 1 ready pair |
| 2 | echoes 2 ready pairs |
| 3 | echoes 3 ready pairs |
| 4 | echoes may **bounce** — an echoed merge that creates a new ready pair merges it too (one bounce per echo) |

Echo guards: lowest-tier pairs first, never a pair an active quest asks for, no chain
credit, no combo coins — free value, not an engine.

**Soil, in detail.** Drag any piece onto soil → planted, grows +1 tier. **Visible at low
tiers, idle at high tiers**:

| Planted tier | 1 | 2 | 3 | 4 | 5 | 6 | 7+ |
|---|---|---|---|---|---|---|---|
| Grow time | ~10 s | ~45 s | ~3 min | ~15 min | ~1 h | ~3 h | ~8 h cap |

You cannot plant a piece at its line's top ask tier, and **harvests clamp at that cap** (a
rank-3 +2 growth from one below the cap lands at the cap) — the road to tier 12 is mastery
and merging, not idle waiting. Cancel any time, free. **Watering:** tap the growing cell to
spend board water and halve the remaining time, once per growth. **Acorns** finish a grow
instantly, priced by time remaining — the paid lever: money buys time, never items.

**Unlock.** The first soil cell is free at ~level 6 (an FTUE beat: plant a tier-1, watch it
sprout in seconds). Everything else: first slot ~500 coins, roughly doubling per slot; ranks
cost a multiple of the slot.

**UI.**

- **Build mode:** a small **Build** leaf-button at the board's edge. Tapping it dims play
  one step and shows the six perimeter slots as dashed cut-paper pads (+ on empty ones).
  Outside build mode, unbuilt slots are invisible — zero clutter.
- **The build sheet:** tap a pad → a three-card sheet (Soil · Magnet · Mirror), each with
  art, price, and a one-line verb (*"Grows a planted piece one tier."*). Mirror's card greys
  out once one exists. Confirm builds it; the cell gains its art.
- **Cell art & ranks:** soil = a small earth patch; magnet = a horseshoe pebble; mirror = a
  tiny pond. Rank shown as 1–3 leaf pips on the cell's corner. Tapping a **built, idle** cell
  opens the same sheet showing its rank ladder and the next rank's price.
- **Soil in action:** the planted piece sits in the dirt with a thin progress ring and a
  sprout wiggle; tapping it opens a mini-row: 💧 water (halve time) · 🌰 finish now · ✕
  cancel. Harvest pops the grown piece with the standard spawn bounce.
- **Magnet in action:** the held piece sits on the pebble; attracted pieces glide in with a
  soft trail (one at a time, ~0.3 s each); the §5 outline appears over the arrangement as it
  forms — one affordance, shared.
- **Mirror in action:** on an echo, a ripple leaves the pond toward each echoed pair, which
  then merges with the standard FX at reduced scale — reads as "echo," not "my merge."

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

1. **Shelf** — farewell card, auto-sweep, shelf tab, pull-back, retirement re-homed. (Fixes
   problems 1 + 3 by itself.)
2. **Mastery + Scissors** — meters, 8 ranks, floor rule, ring/trim/rank-up UI; Scissors
   ships with it.
3. **Combos + ready-ladder outlines + cascade FTUE.**
4. **Improvements** — build mode, slots, Soil + Magnet + Mirror. (Magnet and Mirror build on
   step 3's ladder detection and echo guards.)
5. **Weather hours** — the sky roll, the patch, three skies, the starfall drop. (Independent
   of step 4; order between 4 and 5 is the Dev's pick.)

Each task carries headless suite coverage; economy-touching steps (2, 4, 5) get a
`grove_sim` re-pass before merge. These are parked in the backlog for the Dev to pull one at
a time — not an autonomous queue.

---

## 9 · Parked (explicitly not in this design)

- **The Wild piece** (star piece that merges with anything as its t+1) — replaced by the
  starfall drop, rev 4: a new mechanic needing special cases across every other system, where
  a plain t8 piece needs none. Revisit only if the game wants a toy back.
- **Sun / Spring cells** — cut rev 6: passive coin/water gifts are the sky's vocabulary, not
  a tool the ground should own.
- **Magnet / Mirror skies** — cut rev 6: active tools are the ground's vocabulary; a sky
  that rearranges or merges the player's board is a gift that touches their stuff.
- **Resident trades** (fence-visitor barter: wants drawn from surplus, gives from current
  needs, ~1.15 player-favor rate, resident tier improves rates) — parked, rev 3.
- **Festival sky** (two skies at once) — parked, rev 3: overlapping patch visuals are hard;
  revisit after the base skies ship.
- **Memory vignettes** (puzzle mini-boards telling the parents' backstory) — strongest
  future candidate for a second mode; parked by Dev call 2026-07-26.
- **The Exhibition** (weekly seeded fair; entries consumed; NPC rivals, no leaderboard) —
  parked with it.
- **Ripening shelf** (passive tier growth while shelved) — superseded by soil; the Shelf
  only stores and labels.
- **Cushion cell** — superseded by the Shelf. **Sparkle cell** — superseded by the cell
  rework.
- **Breeze / Harvest sun / Fireflies skies** — cut as weak or duplicate effects.
- **Paid tier bundles** — rejected outright (circular economy).

## 10 · Open questions for Dev review

1. Mastery craft-consumption credit (§3) is a new law — confirm.
2. Soil FTUE at level 6 — earlier/later?
