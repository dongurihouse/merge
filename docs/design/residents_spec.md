# Residents — Expansion Spec

*Working title: "The Homecoming" (placeholder).*
*Status: in progress — Explore (merge-rush → mystery boxes) + mechanics + risk drafted; economy structure stubbed (numbers sim-tuned last).*

A standalone expansion layered on top of the base game (`merge_spec.md`, `grove_spec.md`). It
supersedes the base game's "residents are cosmetic-only" stance; the base specs (`merge_spec.md`
§4/§8, `grove_spec.md` §3) now defer the resident model to this spec.

---

## Summary

The base game restores places. This expansion makes a restored place worth living in.

It adds two things: a new **Explore** mode — a short, timed **merge-for-score** rush you kit out with
coin-bought boosts, where the score you earn buys **mystery boxes** that reveal the spirits you bring
home; and a rule that every completed map is a **habitat with limited capacity** for them. You merge
spirits in your hand to climb tiers, then place them on maps to produce. In return, the spirits produce
coins, currencies, and utility rewards that feed back into the game.

Because spirits need room — and rarer ones are worth chasing — finishing a map is no longer an
end but the start of a long-tail loop that pushes you to unlock and upgrade more maps. Coins fund the
expeditions (their first open-ended use), so both currencies finally have somewhere to go. Today's
dead-end — "the map is finished, nothing left to do" — becomes the game's primary long-tail and
daily-return loop.

## Why we want it

A completed map is currently a trophy with nothing behind it. Welcoming a resident is a pure
coin **sink**: you spend, a placeholder wanders in, and nothing comes back — no goal, no
reward, no reason to continue. The "cosmetic-only, no yield, no power" rule kept the economy
safe but left the endgame hollow:

- **Coins have nowhere meaningful to go** — spending is a drain, not a power.
- **Finished maps go dead** — the player's hardest-won content has the least to do.
- **Nothing compounds or pulls them back** — no set to complete, no growth to check on.

The base game proves the player *can* finish a map. It gives them no reason to *live* in one.

## Thesis

A restored world should **grow, reward, and ask** — not sit there. Four moves form a
self-renewing loop, bolted on top of the merge core without changing how the core plays:

- **Explore — acquire.** Kit out a run with coin-bought **boosts**, then play a short
  **merge-for-score rush** (merge for tiers; the line rerolls on every merge; a combo multiplier
  builds). Trade the score for **mystery boxes** — pricier boxes, better odds — and bring home
  whatever they reveal. Spirits have **rarity** (white · blue · orange · red); boxes are bought with
  skill-earned score, and any premium path buys *better odds, never an exclusive spirit*. Built to
  grow into a full search-and-extraction mini-game.
- **Place — capacity.** Each completed map holds a limited number of spirits (~8 to start,
  upgradable). You **merge two-of-a-kind in your hand** to raise tier, then place — a higher-tier
  spirit packs more production into one of a map's limited slots, so capacity stays the squeeze.
- **Expand — the pull outward.** Because spirits need room, the player has a concrete new
  reason to unlock more maps and upgrade capacity, wiring the expansion into the base game's
  progression.
- **Reward — the payback.** Placed spirits **produce for the core game** — a distinct, non-staling
  reward per map (coins, Water, a generator-booster, premium currency, even more residents). More and
  higher-tier spirits make more (the idle, compounding payoff). They also fill a **collection** worth
  completing (global at first, per-map sets later). *(Quest-giving was considered and is parked — see
  Mechanics.)*

The residents loop: rush for score → open boxes → place → merge → run out of room → expand → rush again.

## The whole-game loop

The expansion turns one loop into three that feed each other:

1. **Merge the board** *(base game)* — restore spots and unlock maps; that buys more board
   space *and* more room for residents.
2. **Explore and grow residents** *(this expansion)* — run merge-rushes, open boxes to bring spirits
   home, merge them to climb tiers and free slots; that pushes you to unlock and upgrade more maps.
3. **Residents power the board** *(payback)* — placed spirits produce coins, Water, generator
   boosters, premium currency, and even more residents that make the board faster and more fun.

The cycle closes: stronger board → more space → more residents → more production → stronger
board. The base game was a single loop that *ended* when a map was finished; this makes it a
three-engine flywheel with no end state — which is what an endgame needs.

---

## Mechanics

*High-level shape; numbers and edge rules are sim-tuned later (see Economy). The **habitat** side
reuses the existing roster plumbing — the persisted per-map roster, two-of-a-kind auto-merge, and the
ambient render layer. The **Rush** is net-new (see Build-readiness). Three pillars deliberately
**reverse** base-game invariants and must be re-proven, not inherited: **capacity** makes the resident
sink finite again (the base `sink > faucet` proof relied on there being no cap), and **idle production
/ Water** re-open the cut passive faucet and the energy invariant (I2). Those re-proofs land in the
parked Economy/Risk pass.*

*v1 simplification — **rarity is parked.** Assume every spirit is **common**; production is
**tier-only** and the merge rule is **same kind + same tier**. Rarity (white · blue · orange · red) is
a clean later extension — wherever this spec still says "rarity × tier", "box rarity odds", or "kind ×
rarity collection", read v1 as the all-common, tier-only version. The merge-across-rarity rule (result
takes the higher) and the collection almanac come back with it.*

### Explore — acquire

Explore is a single global **destination** — you venture out from home, not shop from a completed map.
Acquisition is a three-beat ritual: **Load out → Rush → Trade.** The Rush is a short, timed
**merge-for-score** game; spirits aren't on the board — they come out of the **mystery boxes** you buy
with the score you earn. Skill decides *how much* you can open; the box decides *what* you get.

**1. Load out.** Before a run you spend **coins** on **boost items** and **stack as many as you can
afford** (consumed per run — the recurring coin sink, coins' first open-ended use). Each boosts a
different aspect of the run — extend time, faster drops, calmer woods (fewer treefalls), tier-2 drops,
fewer lines, and so on. The loadout is the strategic prep. *(Some boosts may later be diamond-priced —
premium buys speed/odds, never possibility.)*

**2. Rush** — a board-fuelled, timed game on a **dedicated expedition board** (a fresh temporary grid;
v1 reuses the home **7×9**, a Rush-sim knob; discarded after — never your home board). For a short
window (~45–90s):

- **Traces rain in automatically** — no generator tapping, no Water cost — and the inflow accelerates
  into a frenzy. The drop *is* the pressure.
- **Tap to merge** a matching neighbour (drag-free, to keep it frantic), **and the result rerolls to a
  random line.** You can't tunnel a single line — you merge opportunistically for *tier*, and the line
  scrambles each time. **Fling**: tap a tile with no match and it hops to a random safe column — your
  timber escape.
- **Score is the prize, from the whole board.** Each merge scores **non-linearly by tier** (a high
  tier is worth far more than several low ones), times a **live combo multiplier** that climbs as you
  keep merging and decays when you pause. You want the *whole board* worked high, fast — not one peak
  tile, and not one tunneled line.
- **Treefall (the hazard).** Periodically a column is telegraphed, then a tree falls and destroys that
  line; fling your good tiles clear in time. **Emptying the doomed column before it lands is a "clean
  dodge" — a multiplier bonus**, so the hazard doubles as a scoring opportunity. (Easy dial:
  knock-down-a-tier instead of destroy.)
- **Two clocks.** You race the countdown *and* the board filling — board-full ends the run early.
  Space management is the core skill.
- **Balance is simmed, not guessed.** Drop rate, line count, treefall cadence, the score curve and
  multiplier decay are tuned in a **Rush sim** (the way `grove_sim` tunes the economy) to keep the
  mode fair and fun.

**3. Trade.** The Rush pays out a **score**. You spend it on **mystery boxes** of escalating cost —
pricier boxes carry **better rarity odds**. You choose how to spend (several cheap boxes vs one
expensive gamble). Each box opens to reveal **spirits** (kind × rarity), and **only what the boxes
give you comes home** — then you place them across your maps (see **Place**).

- **Rarity lives on the spirit, set by the box** — four tiers: **white** (common) · **blue** (magic) ·
  **orange** (legendary) · **red** (heroic). Pricier boxes weight toward the top. Rarity drives
  production (yield rises with rarity × housed tier — see Reward); spirits enter the roster at **housed
  tier 1** and climb only via in-habitat merges. *(The roster of spirits at each rarity is content,
  parked with the reward-set design; current placeholders aren't the final set.)*
- **Boxes are skill-earned, not sold.** They're bought with **score** (earned by play), and **every
  box tier is reachable** by playing well — a loot reveal, not a paid gacha. If diamonds ever buy a
  premium box or boost odds, they buy *better odds, never an exclusive spirit* (the base law holds).
  See Risk for the cozy-tone note.
- **Pool grows with progress** — completing/unlocking a map adds its **signature spirits** to the box
  pool, so progressing the base game widens *what can come out of a box* and feeds the collection.
- **Growth seam** — v1 is this one merge-rush + boxes. Later layers (no contract change):
  destinations/biomes with different line sets and box pools, richer loadout items, and
  **limited-time featured events** (e.g. a "Red Spirit Trek" weekend) as the live-ops urgency layer.

### Place — capacity & assignment

The residents loop lives on a **Residents screen** — a hub separate from the merge board and the
map-restoration view. From it you **merge** spirits in your hand, **assign** them to maps, **free or
sell** a spirit, and **launch an expedition** (Explore) — the collection lives on its own almanac page.
The screen
**promotes** the existing per-map welcome overlay (already reached from the residents nav button) into
a full hub — likely a dedicated scene (today only the board and map scenes exist) — and **supersedes
that per-map welcome panel**; acquisition moves off the individual maps into Explore. (*Assign* is the
v1 verb for the Place action; hand-positioning is a later seam. Diegetic trade-off: the base game
welcomes spirits on the map they live on; the hub swaps a little of that intimacy for one legible
management surface.)

Each completed map is a **habitat with a slot capacity** (start: **~8**, upgradable). Assigning a
spirit to a map fills a slot *and* raises that map's production (see **Reward**) — placement is a real
economic decision, not flavor: where you put a spirit chooses which reward you make more of.

- **Accounting** — **one slot per spirit instance, any tier.** A map slot holds one spirit and is
  freed by **selling or moving** it (not by merging — merge lives in the hand now). A higher-tier
  spirit packs more production into that one slot.
- **Merge is in-hand** — you merge **before placing**: in the hand, drag two-of-a-kind (**same kind +
  same tier**) together to make one a tier up. Maps just hold placed spirits and produce — no on-map
  merge. Merging up in hand is how you fit more production into a map's limited slots.
- **Re-assignment is free** — move a placed spirit between maps any time to rebalance which reward you
  favor. A map's output sums *all* its assigned spirits' yield, so moving a spirit never strands it or
  starves a map.
- **Why you don't just dog-pile the best map** — per-map **capacity (~8)** is the brake. You can only
  fit your ~8 best spirits on your favourite reward (say map 4's diamonds); a growing roster *must*
  spill onto other maps, so you naturally earn a **mix** of rewards and every map's identity stays
  live. Over-indexing your favourite is the *choice* capacity lets you make — not a dominant strategy.
- **Capacity gates placement, not the run.** Launching an expedition only needs **one completed map**
  (you might run purely for score / the collection). Box-spirits land **in-hand** and you place them on
  maps with free slots; overflow waits in-hand until you free room. A full habitat across all maps is
  the pressure that drives Expand. **Selling is the always-available door:** even a habitat full of
  distinct singletons (no legal merge) can free a slot by selling one.
- **Free / sell** — remove an assigned spirit to recover its slot (what you get back is TBD — see
  Economy).
- **Out of room → expand** — a full habitat is the engine of the next move: **sell or move** a spirit
  to free a slot, upgrade a map's capacity, or unlock another map.
- **Placement seam** — v1 assignment puts a spirit on a map where it wanders (stateless render);
  hand-positioning on a grid is a later layer.

### Expand — the pull outward

Capacity is **per map**, so habitat scales two ways: **upgrade** a map you own (intensive) or **unlock
the next map** (extensive — each new map brings its own ~8 starting slots, also upgradable). Each new
map also opens a **new reward stream** to feed, so unlocking widens both your housing *and* your
production mix. No new unlock mechanic; this rides the existing completion-chained map sequence.
Running out of room becomes a concrete reason to push the base-game progression forward.

*(Runway note: only the 5 home-grove maps are wired today; the designed 20-place journey is the
long-tail this move leans on.)*

### Reward — the payback

**Each completed map produces one specific reward type, and its rate is the sum of every assigned
spirit's yield** — and a spirit's yield rises with its **rarity × housed tier**. So you raise a map's
output two ways: place *more* spirits, or place **higher-tier** ones (merged up in hand). Production is
**idle and compounding**: it accrues while you're away (capped, so it's a daily-return pull rather
than infinite idle) and you **collect** it from the Residents screen.

- **Merge stays worth it** — yield rises *per slot* with tier: a higher-tier spirit out-produces the
  two that merged into it, so merging up in hand is always a production gain — there's no "place a pile
  of tier-1s" degenerate play.
- **Accrual contract** — each completed map stores a last-collect time; accrued = its assigned
  spirits' rate × elapsed, **clamped to a cap** (the daily-return ceiling); **collect** banks it into
  that map's reward target and resets the clock. Rates and caps are Economy.

**Map → reward (home grove, 5 maps).** Each map has a fixed, distinct payback — deliberately chosen
to be things that *don't* go stale (currencies and utility, not early-tier board line-items):

| Map | Produces |
|-----|----------|
| 1 | **Coins** |
| 2 | **Water** |
| 3 | a **generator-booster item** (boosts generator output) |
| 4 | **Premium currency** (diamonds) |
| 5 | a **special generator** — itself spawns *random residents* over time, no expedition needed |

Every map gets a clear identity, and "Expand" now opens a genuinely new payback each unlock (map 4 →
a diamond stream; map 5 → a free-resident faucet). A vertical slice can start on **map 1 (coins)** —
the simplest stream — and layer the rest in.

Three of these reopen base-economy questions, flagged for the parked Risk/Economy pass, not settled
here:

- **Water (map 2)** must respect the energy invariant (I2) — a capped top-up that cannot scale with
  spirit count/tier like the others, or it is pulled from v1.
- **Premium currency (map 4)** makes residents a *diamond faucet.* Diamonds are tightly metered today
  (IAP + sparse earns), so this reopens the premium economy and the IAP value proposition — the
  highest-stakes balance question in the expansion; it needs hard caps.
- **Special generator (map 5)** is a second resident-acquisition path that bypasses the coin-funded
  expedition — it must stay slow/random enough that Explore remains the primary, targeted route.

The **generator-booster (map 3)** and **special generator (map 5)** are new content to define and
build; their exact behaviour and numbers are an implementation/Economy detail.

Beyond production, the same residents feed a **collection**:

- **Collection** — a **global** ledger of discovered spirits (kind × rarity × signature), reusing the
  Explore rarity axis. It lives on **its own almanac page** (a shared almanac component, not inline on
  the habitat screen) and is **parked to the backlog** (`docs/BACKLOG.md`). Completion reward and
  per-map sets are later layers.

**Parked — quest-givers.** The thesis once floated residents "acting as quest-givers." It's parked:
here residents are the *supply* side (they produce), while quests are *demand* and already live on the
board's quest fence — a resident-run quest would duplicate the fence and blur the resident's role. If
ever revisited, the coherent form is a residents-loop *goal* (e.g. "house a tier-3 on the Garden →
reward"), not a board-item delivery quest.

### Build-readiness notes

Things a vertical slice must respect, captured here rather than left implicit:

- **Gating** — the loop is gated on **at least one completed map** (it inherits `can_populate` /
  `map_complete`): there's nowhere to house spirits until a map is done, so a slice must be seeded with
  one completed map. The **pre-first-completion coin gap** (until the first map is done, coins have only
  burst-upgrades / cosmetics to spend on) is a known base-economy concern, carried to Economy.
- **Score → box → spirit contract** — a run yields a **score** (sum of merge value × multiplier);
  score buys **boxes** at fixed costs; a box rolls a **rarity** from its odds table and a **kind** from
  the unlocked pool; the spirit enters the roster at **housed tier 1**. This is the seam between the
  Rush (skill) and the habitat (roster) — define the box cost/odds tables and the kind pool with it.
- **Save shape & migration** — the habitat needs state today's per-map roster doesn't hold: a
  **rarity** axis, **per-map capacity**, a **global collection** ledger, **per-map production state**
  (last-collect time + accrued), and an **in-hand holding area** for box-spirits awaiting placement.
  Because rarity persists per instance (it drives yield), the roster **key becomes (kind, rarity)** and
  merges require matching **kind *and* rarity**. Migration is non-destructive — old saves read as
  housed white-rarity commons, capacity defaults to ~8.
- **The Rush is a net-new board engine** — the expedition board shares nothing with the home board: a
  separate grid model, an **auto-drop / no-Water spawn driver**, **tap-to-merge with random-line
  output**, fling, the treefall hazard, and a **scoring + combo-multiplier** system, in its own scene.
  The home board is a single fixed-7×9, generator+Water-gated instance, so this is the **single largest
  build item** (honestly a growth seam, not a reskin); v1 keeps it small (reuse the 7×9 grid).
- **Coins are both sink and faucet** — Explore's loadout items spend coins; map 1 produces them.
  Sink-positivity must hold against the **total** coin faucet (merge drops + selling + quest coins +
  map-1 residents) vs the **total** coin sink (loadout boosts + capacity upgrades + burst upgrades) —
  not in isolation. That total is what the re-authored `grove_sim` must prove.
- **Art** — no signature/rarity sprites ship today; the slice uses placeholder bodies with a
  **colour-frame** rarity indicator (white / blue / orange / red), and neutral line tiles in the Rush.
  Bespoke per-spirit and per-rarity art is parked with the reward-set content.

### Prototype status

A playable HTML **feel-prototype** of the full expedition (Loadout → Rush → Trade → Manage) lives at
`docs/design/prototypes/expedition_rush.html` (open in a browser). It validated the model and the
juice: auto-dropping traces with a landing squash; **tap-to-merge with random-line output**; **fling**
(no-match tile hops to a safe column); **non-linear scoring × a live combo multiplier** with a
**clean-dodge** bonus when you empty a telegraphed column before the timber lands; the board-shake +
squish treefall; the low-time suspense vignette; a **loadout** of stackable coin-bought boosts; and
the **Trade** step where score buys escalating **mystery boxes** that reveal spirits to place across
five map rows.

Decisions the prototype locked: **tap-to-merge (no drag); fling for rescue; auto-rerolled line on
merge; score-not-capture; mystery boxes as the acquisition; loadout as the coin sink.**

Still open (tuning, deferred to the Rush sim + playtest): the **score curve** and box costs/odds
(reaching high tiers is luck-dependent under random-line output — the curve must keep runs rewarding
without a dominant strategy); **fling can't be aimed**, so a "clean dodge" is partly luck — may bias
fling toward emptying the danger column; the **loadout item set** and prices; treefall **destroy vs
knock-down** default. The prototype is HTML for feel only; the real Rush is the net-new GDScript engine.

A second feel-prototype (`docs/design/prototypes/habitat_production.html`) validated the **payback
half** and locked these decisions: **merge happens in the hand via drag** (drag two-of-a-kind
together), **drag a spirit onto a map to place** it, maps **produce idly** in a fill→collect rhythm at
a rate that rises with the spirits on them, and **capacity is freed by sell/move** (not on-map merge).
The per-map reward identities read as a real "where do I load this" choice. Open tuning: collect
cadence (naggy vs satisfying — levers are fewer maps / a collect-all / bigger caps) and the accrual-cap
curve. (Rarity is parked — every spirit is common; see the Mechanics note.)

### The loop, restated

Load out (spend coins on boosts) → merge-rush for score → trade score for mystery boxes → open them →
merge spirits up in hand → place across maps → collect production → run out of room → sell / expand →
rush again — while placed spirits produce back into the board.

---

## Economy

*Parked for last — numbers are sim-tuned once the mechanics settle.* This section will set the
**structure** of the new flows, not invent final numbers:

- **Coin sinks** — per-run **loadout boosts** (coins' first open-ended sink) and **per-map
  capacity-upgrade** cost.
- **Score economy** — the Rush **score curve** (non-linear tier value × combo multiplier + clean-dodge
  bonuses), and the **mystery-box** cost/odds tables, tuned so a good run affords a meaningful pull and
  better play earns better boxes — with every box reachable on skill alone.
- **Diamond levers** — premium boxes / odds boosts / premium loadout items (odds + speed, never
  possibility).
- **Faucets** — per-map production rates and caps for each reward (coins, Water, generator-booster,
  diamonds, residents), plus the free / sell return.
- **The proof** — re-author `grove_sim` around the resident faucet + capacity and show the base
  invariants stay green (no-strand, no-jam, `sink > faucet`, selling-is-not-income, I2), plus the new
  **Rush sim** (fair tide, score→box pacing, no dominant strategy, no forced loss).
- **Felt scale (provisional targets)** — the sim and reviewers need the intended magnitude, e.g. a
  fully-housed map-1 produces ~one loadout's coin cost per day; a map-4 red's diamond trickle stays
  well under a cash pack; collection completion is a multi-week chase.

---

## Risk

The expansion bolts a faucet, a cap, a premium-currency source, and a frantic mini-game (plus a
mystery-box reveal) onto a deliberately-tuned base economy. The honest risks, grouped, with how each
is contained:

### Economy (load-bearing)

- **Premium-currency faucet (map 4)** — residents minting diamonds reopens the IAP value proposition;
  if output out-paces the cash packs it guts monetization. *Contain:* hard daily/clamped caps,
  modelled against the IAP ladder; the single most-scrutinized number here, and a candidate to cut
  from v1 if it won't sit.
- **Capacity re-opens `sink > faucet`** — the base proof relied on residents being an *uncapped* sink.
  A finite cap plus a production faucet means the inequality must be **re-proven on `grove_sim`, not
  inherited**.
- **Idle, compounding production = a passive faucet the base game cut** — re-introduces deferred idle
  income. *Contain:* per-map accrual caps (the daily-return ceiling), simmed so total output stays
  under faucet limits.
- **Water vs invariant I2** — Water output must stay a capped top-up that does **not** scale with
  spirit count/tier (I2: a level's energy rewards < 30% of its cost), or it's pulled from v1.
- **Coins self-funding** — map 1 makes coins while loadouts spend them; the net must stay sink-positive
  or the loop pays for itself.
- **Map-5 bypass** — the resident-spawning generator is a free acquisition path; it must stay
  slow/random enough that paid Explore remains primary.

### Tone & design

- **Mystery boxes = a mild gacha** — a loot reveal could read as predatory against the cozy "no-FOMO"
  posture. *Contain:* boxes are bought with **skill-earned score**, not money, and **every box tier is
  reachable** by playing well; nothing is time-gated or lost. If diamonds ever buy boxes they buy
  *odds, never an exclusive spirit*. Worth a deliberate tone check in playtest.
- **Rush: fun vs chaotic** — auto-tide + random-line merges + treefall + a building multiplier +
  countdown is a lot at once and could read as stressful, not cozy-exciting. *Contain:* the Rush sim +
  playtest set the rates; treefalls are telegraphed; loadout boosts and easy dials (knock-down crush,
  slower tide, fewer lines) soften it.
- **Score balance / no dominant strategy** — non-linear scoring + random-line output must reward
  *whole-board* throughput without collapsing to one solved play; the Rush sim guards this.
- **Pay-to-win perception** — premium boxes / loadout items could feel like a gate. *Contain:* "premium
  buys speed + looks, never possibility" holds, with every box and spirit reachable on coins + skill.
- **Hub vs the world** — a global Residents screen trades the base game's "welcome them home where they
  live" intimacy for one management surface. Accepted; watch it doesn't feel detached.

### Scope & technical

- **Content dependencies** — the **Rush engine**, the **loadout item set**, the **mystery-box tables**,
  the map-3 generator-booster and the map-5 special generator are all **new**, and rarity/collection
  art doesn't exist; v1 leans on placeholders + colour-frames. This is a genuine scope risk.
- **Save migration** — a schema change (rarity, capacity, collection, production state, in-hand
  holding); must be non-destructive (old saves read as housed commons).
- **Runway** — only the 5 home-grove maps are wired against a designed 20-place journey, so the
  *Expand* arm and reward-stream variety stay thin until post-launch maps ship.
- **Early-game gap** — the loop is gated on first-map completion; the pre-completion coin-sink gap is
  inherited and unverified.

All the economy items converge on one obligation: **re-author and re-run `grove_sim`** (plus the new
**Rush sim**) around the resident faucet + capacity before build, holding the base invariants green.
That work is the parked Economy pass.
