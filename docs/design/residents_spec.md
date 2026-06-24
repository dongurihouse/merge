# Residents — Expansion Spec

*Working title: "The Homecoming" (placeholder).*
*Status: in progress — mechanics + risk drafted; economy structure stubbed (numbers sim-tuned last).*

A standalone expansion layered on top of the base game (`merge_spec.md`, `grove_spec.md`). It
supersedes the base game's "residents are cosmetic-only" stance; the base specs (`merge_spec.md`
§4/§8, `grove_spec.md` §3) now defer the resident model to this spec.

---

## Summary

The base game restores places. This expansion makes a restored place worth living in.

It adds two things: a new **Explore** mode, where the player spends coins to venture out and
bring spirit-folk home; and a rule that every completed map is a **habitat with limited
capacity** for them. You explore to find spirits, choose who to keep, place them, and merge
two-of-a-kind to climb tiers and free space. In return, the spirits produce coins, currencies,
and utility rewards that feed back into the game.

Because spirits need room — and rarer ones are worth chasing — finishing a map is no longer an
end but the start of a long-tail loop that pushes you to unlock and upgrade more maps. Coins
fund the expeditions (their first open-ended use) and diamonds buy better odds, so both
currencies finally have somewhere to go. Today's dead-end — "the map is finished, nothing left
to do" — becomes the game's primary long-tail and daily-return loop.

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

- **Explore — acquire.** Spend **coins** to venture out and bring spirits home; you don't pick from a
  list, you discover who turns up and keep one for free (more for diamonds, if you have room). Spirits have **rarity**
  (four tiers: white · blue · orange · red), and a **premium (diamond) path** improves the odds. The
  *act* of exploring is a timed merge-rush (see Mechanics), not a slot pull — built to grow into a
  full search-and-extraction mini-game.
- **Place — capacity.** Each completed map holds a limited number of spirits (~8 to start,
  upgradable). Two of a kind merge into one — raising tier *and* freeing a slot — so merging is
  progression and space management at once.
- **Expand — the pull outward.** Because spirits need room, the player has a concrete new
  reason to unlock more maps and upgrade capacity, wiring the expansion into the base game's
  progression.
- **Reward — the payback.** Placed spirits **produce for the core game** — rewards that feed back
  into play (the reward set is TBD; see Mechanics). More and higher-tier spirits make more (the
  idle, compounding payoff). They also fill a **collection** worth completing (global at first,
  per-map sets later). *(Quest-giving was considered and is parked — see Mechanics.)*

The residents loop: explore → keep one → place → merge → run out of room → expand → explore again.

## The whole-game loop

The expansion turns one loop into three that feed each other:

1. **Merge the board** *(base game)* — restore spots and unlock maps; that buys more board
   space *and* more room for residents.
2. **Explore and grow residents** *(this expansion)* — explore, bring spirits home, merge to
   climb tiers and free slots; that pushes you to unlock and upgrade more maps.
3. **Residents power the board** *(payback)* — placed spirits produce coins, Water, generator
   boosters, premium currency, and even more residents that make the board faster and more fun.

The cycle closes: stronger board → more space → more residents → more production → stronger
board. The base game was a single loop that *ended* when a map was finished; this makes it a
three-engine flywheel with no end state — which is what an endgame needs.

---

## Mechanics

*High-level shape; numbers and edge rules are sim-tuned later (see Economy). It reuses the existing
roster plumbing where it can — the persisted `{map_id: {type_id: …}}` roster, two-of-a-kind
auto-merge, and the ambient render layer. But three pillars deliberately **reverse** base-game
invariants and must be re-proven, not inherited: **capacity** makes the resident sink finite again
(the base `sink > faucet` proof relied on there being no cap), and **idle production / Water** re-open
the cut passive faucet and the energy invariant (I2). Those re-proofs land in the parked Economy/Risk
pass; the save-shape changes they imply are called out in that pass too.*

### Explore — acquire

Replaces the base game's pick-from-a-list "welcome a spirit" panel. Explore is a single global
**destination** — you venture out from home, not shop from a completed map — and acquisition is a
three-beat ritual: **Launch → Rush → Haul**. The Rush is the playable heart: a short, timed
merge-frenzy that turns the pull into a real game, not a slot machine.

**1. Launch.** Spend **coins** to set out (coins' first open-ended sink). Capacity-gated: you can't
launch with no free slot anywhere, and you can't keep more spirits than you can house (see **Place**).

**2. Rush** — a board-fuelled, timed game on a **dedicated expedition board**: a fresh temporary grid
(v1 reuses the home **7×9** — a Rush-sim knob), discarded after; you're out in the wilds, never on your
home board. For a short window (~60–90s):

- **Traces rain in automatically** — no generator tapping, no Water cost — and the inflow accelerates
  into a frenzy. The drop *is* the pressure.
- You **merge traces up the tiers** toward rarer results. Traces come in a **small set of colours**,
  kept few so each colour's supply stays dense and mergeable.
- **Capture is the friction.** Spirits appear as targets, each with a **colour + required tier +
  patience timer**; to catch one you merge a matching-colour trace to that tier and **deliver it onto
  the spirit** (which also clears those cells). Rarer = rarer colour, higher tier, shorter patience —
  so you're choosing *which target*, *which colour chain to feed*, and *commit-or-hedge*, not just
  spotting pairs.
- **Two clocks.** You race the countdown *and* the board filling: the Rush ends on **countdown→0 or
  board-full, whichever first.** Captures **bank progressively** — board-full is not a wipe, you keep
  what you'd caught — then the Haul opens. Space is the core skill, and capturing relieves space, so it
  both scores and keeps you alive. A **zero-capture run still sends one common home** (you paid coins
  to launch; you never come back empty-handed) — *flagged for the no-loss guardrail.*
- **Treefall (the hazard).** Periodically a tree looms over a row or column (telegraphed with a
  warning), then falls and **destroys** everything in that line. Drag items clear in time to save
  them — rescue the reds and near-done chains, sacrifice the whites. Treefall is the Rush's single
  hoarding-pressure: **one readable threat** instead of a grid of per-item timers. (Letting a doomed
  line fall to clear a clogged board is an *emergent* desperate option, not a second mode; the **easy
  dial** — crush knocks items down a tier instead of destroying them — is a global difficulty setting,
  not a per-fall choice.)
- **Balance is simmed, not guessed.** Drop rate, colour count, treefall cadence and target spawn are
  tuned in a **Rush sim** (the way `grove_sim` tunes the economy) to keep the mode fair and fun —
  e.g. there's always somewhere to rescue items to, and capture targets keep pace with the climb.

**3. Haul.** The spirits you caught form your slate — a post-Rush modal. **Keep one for free** (you
pick which, if you caught several); in v1 the rest auto-release, with diamond keep-extras and the
multi-keep UI parked. Anything beyond your free capacity auto-releases too. Then place each on a map.

**What a caught spirit *is* (capture → roster).** A target's **colour is its rarity** (white / blue /
orange / red); the tier you had to build on the expedition board is **capture difficulty, not housed
tier.** A kept spirit enters the roster at **housed tier 1** and only climbs via in-habitat merges —
so the Rush decides *which rarity* and *how many* come home; the habitat decides their tier.

- **Rarity** — four tiers, colour-coded: **white** (common), **blue** (magic), **orange**
  (legendary), **red** (heroic). Rarity is a new axis on the spirit, and it **pays off in
  production**: a rarer spirit yields more (yield rises with rarity × tier — see Reward), so chasing
  reds matters beyond the collection badge. *(The actual roster of spirits at each rarity is content,
  parked with the reward-set design — the existing core/signature placeholders aren't the final set.)*
- **Pool grows with progress** — the shared core is always discoverable; **unlocking a new map adds
  its signatures to the pool** of spirits that can appear as Rush targets. Pushing the base game
  forward widens *what you can find*, not just where you house them — each new map is a discovery
  event and feeds the collection.
- **Diamonds, two levers** — both buy *better odds and convenience, never exclusivity*; every spirit
  stays reachable on coin expeditions alone, just slower (the base game's "premium buys speed +
  looks, never possibility" law holds):
  - **Premium expedition** — a pricier run that shifts the odds upward two ways: it **removes white
    (common)** and **lowers the chance of blue (magic)**, so the spirits that appear as Rush targets
    skew toward orange and red. (Every rarity still appears on coin-only runs, just at lower odds —
    premium compresses time-to-red, never gates it.)
  - **Keep extras** — on any expedition, pay diamonds to keep a second or third candidate instead of
    letting it vanish — offered only while you still have free slots to house them. The vanish-or-pay
    framing is a deliberate choice that **relaxes the base game's no-loss guardrail** — flagged as
    such for the Risk pass, not an oversight.
- **Growth seam** — the Rush *is* the v1 search-and-extraction game. Later layers (no contract
  change): destinations/biomes with different pools, a pre-Rush loadout/bait beat, and **limited-time
  featured events** (e.g. a "Red Spirit Trek" weekend) as the live-ops urgency layer.

### Place — capacity & assignment

The residents loop lives on a new **Residents screen** — a hub separate from the merge board and the
map-restoration view. From it you can **assign** a spirit to a map, **merge** two-of-a-kind, **free
or sell** a spirit, **view the collection**, and **launch an expedition** (Explore). This screen is
**promotes** the existing per-map welcome overlay (already reached from the residents nav button) into
a full **hub** — adding assign / merge / free-sell / collection / launch — likely as a dedicated scene
(today only the board and map scenes exist). It **supersedes that per-map welcome panel**; acquisition
moves off the individual maps and into Explore. (*Assign* is the v1 verb for the Place action;
hand-positioning is a later seam. Diegetic trade-off: the base game welcomes spirits on the map they
live on; the hub swaps a little of that intimacy for one legible management surface.)

Each completed map is a **habitat with a slot capacity** (start: **~8**, upgradable). Assigning a
spirit to a map fills a slot *and* raises that map's production (see **Reward**) — placement is a
real economic decision, not flavor: where you put a spirit chooses which reward you make more of.

- **Accounting** — **one slot per spirit instance, any tier.** Two tier-1s fill two slots; merging
  them into one tier-2 frees a slot. Merge is progression *and* space management at once.
- **Merge is per-map** — two-of-a-kind merge only while assigned to the **same map**; the higher-tier
  result produces more for that map. Concentrating a type on one map is how you climb its tiers and
  free its slots.
- **Re-assignment is free** — move a placed spirit between maps any time, to line up a merge or
  rebalance which reward you favor. This keeps merging and producing from fighting: a map's output
  sums *all* its assigned spirits' yield (not specific types), so concentrating a type to merge it
  never strands the spirit or starves another map.
- **Why you don't just dog-pile the best map** — per-map **capacity (~8)** is the brake. You can only
  fit your ~8 best spirits on your favourite reward (say map 4's diamonds); a growing roster *must*
  spill onto other maps, so you naturally earn a **mix** of rewards and every map's identity stays
  live. Over-indexing your favourite is the *choice* capacity lets you make — not a dominant
  strategy. (Capacity upgrades let you deepen a favourite, at a cost.)
- **Capacity gates Explore** — the expedition reads your **total free slots across all completed
  maps.** Zero free → the expedition is **disabled**, with a message to **merge, sell, or
  upgrade/unlock** room. One or more free → you may explore, keeping at most as many spirits as you
  have room for (the diamond "keep extras" option is offered only while slots remain). You never hold
  a homeless spirit. **Selling is the always-available door:** even a habitat full of distinct
  singletons (no legal merge) can free a slot by selling one, so the gate is never a dead wall.
- **Free / sell** — remove an assigned spirit to recover its slot (what you get back is TBD — see
  Economy).
- **Out of room → expand** — a full habitat is the engine of the next move: merge to free a slot,
  upgrade a map's capacity, or unlock another map.
- **Placement seam** — v1 assignment puts a spirit on a map where it wanders (stateless render);
  hand-positioning on a grid is a later layer.

### Expand — the pull outward

Capacity is **per map**, so habitat scales two ways: **upgrade** a map you own (intensive) or
**unlock the next map** (extensive — each new map brings its own ~8 starting slots, also upgradable). Each new map also opens a
**new reward stream** to feed, so unlocking widens both your housing *and* your production mix. No
new unlock mechanic; this rides the existing completion-chained map sequence. Running out of room
becomes a concrete reason to push the base-game progression forward.

*(Runway note: only the 5 home-grove maps are wired today; the designed 20-place journey is the
long-tail this move leans on.)*

### Reward — the payback

**Each completed map produces one specific reward type, and its rate is the sum of every assigned
spirit's yield** — and a spirit's yield rises with its **rarity × tier**. So you raise a map's output
two ways: assign *more* spirits, or merge to push the ones there to higher tiers. Production is **idle
and compounding**: it accrues while you're away (capped, so it's a daily-return pull rather than
infinite idle) and you **collect** it from the Residents screen. Where you assign spirits is an
economic choice — load a map to pour out more of its reward.

- **Merge stays worth it** — yield rises *per slot* with tier: a higher-tier spirit out-produces the
  two that merged into it. So merging is always a production gain, not only space management — there's
  no "hoard tier-1 commons" degenerate play.
- **Accrual contract** — each completed map stores a last-collect time; accrued = its assigned
  spirits' rate × elapsed, **clamped to a cap** (the daily-return ceiling); **collect** banks it into
  that map's reward target and resets the clock. Rates and caps are Economy.

**Map → reward (home grove, 5 maps).** Each map has a fixed, distinct payback — deliberately chosen
to be things that *don't* go stale (currencies and utility, not early-tier board line-items, which
resolves the staleness concern that earlier kept this parked):

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
  expedition — it must stay slow/random enough that Explore remains the primary, targeted route, so
  it doesn't undercut coins' role as the first open-ended sink.

The **generator-booster (map 3)** and **special generator (map 5)** are new content to define and
build; their exact behaviour and numbers are an implementation/Economy detail.

Beyond production, the same residents feed a **collection**:

- **Collection** — a **global** ledger of discovered spirits (kind × rarity × signature), reusing the
  Explore rarity axis. Completing it grants a gameplay **reward** (the specific payoff is parked, like
  the production content). *(Per-map sets are a later layer.)*

**Parked — quest-givers.** The thesis floated residents "acting as quest-givers." It's parked: here
residents are the *supply* side (they produce), while quests are *demand* and already live on the
board's quest fence — a resident-run quest would duplicate the fence and blur the resident's role. If
ever revisited, the coherent form is a residents-loop *goal* (e.g. "house a tier-3 on the Garden →
reward"), not a board-item delivery quest.

### Build-readiness notes

Things a vertical slice must respect, captured here rather than left implicit:

- **Gating** — the whole loop is gated on **at least one completed map** (it inherits the base game's
  `can_populate` / `map_complete`): capacity lives on completed maps and Explore reads free slots
  across them, so with zero completed maps Explore is simply unavailable. A slice must be seeded with
  one completed map. The **pre-first-completion coin gap** (until the first map is done, coins have
  only burst-upgrades / cosmetics to spend on) is a known base-economy concern, carried to Economy.
- **Save shape & migration** — the expansion needs state today's `{map_id:{type_id:[t1,t2,t3]}}` roster
  doesn't hold: a **rarity** axis, **per-map capacity**, a **global collection** ledger, **per-map
  production state** (last-collect time + accrued), and a transient home for **in-hand** spirits.
  Because rarity persists per instance (it drives yield), the roster **key becomes (type, rarity)** and
  merges require matching **type *and* rarity** — rarity is not cosmetic. In-hand is **transient**: a
  kept spirit must be assigned to a map before the Haul modal closes (that's how "you never hold a
  homeless spirit" holds). Migration is non-destructive — old saves read as housed white-rarity
  commons, capacity defaults to ~8.
- **The Rush is a net-new board engine** — the expedition board shares nothing with the home board: a
  separate grid model, an **auto-drop / no-Water spawn driver**, the capture and treefall verbs, and
  its own scene. The home board is a single fixed-7×9, generator+Water-gated instance, so this is the
  **single largest build item** (honestly a growth seam, not a reskin); v1 keeps it small (reuse 7×9).
- **Coins are both sink and faucet** — Explore spends coins; map 1 produces them. Sink-positivity must
  hold against the **total** coin faucet (merge drops + selling + quest coins + map-1 residents) vs the
  **total** coin sink (launches + capacity upgrades + burst upgrades) — not map-1-vs-expedition in
  isolation. That total is what the re-authored `grove_sim` must prove.
- **Art** — no signature/rarity sprites ship today; the slice uses the existing placeholder body with
  a **colour-frame** rarity indicator (white / blue / orange / red). Bespoke per-spirit and
  per-rarity art is parked with the reward-set content.

### Prototype status & open interaction questions

A playable HTML **feel-prototype** of the full expedition (Start → Rush → Haul → Manage) lives at
`docs/design/prototypes/expedition_rush.html` (open in a browser). It validates the **juice** — traces
falling with a landing squash, tap-to-merge pop + particle burst + combo screen-flash, the telegraphed
**treefall** (board shake + tiles squished to dust), and the low-time **suspense vignette** — and the
screen flow:

- **Start** — two run choices: Coin run (all rarities) vs Premium run (removes white, fewer blue).
- **Haul** — the spirits you caught; keep one (the rest release).
- **Manage** — **5 rows, one per map**, each showing its reward + housed spirits + a production number;
  tap a row to assign your kept spirit. (Confirms the "simple 5-row assign screen" shape.)

**Open before the GDScript port** (prototype shortcuts to resolve):

- **Merge verb** — the prototype uses **tap-an-adjacent-match**; the home board uses **drag-to-merge**.
  Pick one for the Rush.
- **Capture** — prototype **auto-fires** when you build a tile matching a target's colour + tier; the
  alternative is **drag the finished tile onto the target** (more deliberate, more juice).
- **Treefall imagery** — vertical **timber down a column** (prototype) vs a tree **toppling across a row**.
- **Pacing dials** — drop acceleration, treefall cadence, combo threshold, suspense intensity — set by
  the Rush sim + playtest, not by hand.

The prototype is HTML for feel only; the real Rush is the net-new GDScript board engine (see
Build-readiness).

### The loop, restated

Explore (spend coins) → keep one → assign to a map (fill a slot, boost that map's reward) → merge
(climb tier, free a slot) → run out of room → expand (upgrade or unlock a map) → explore again —
while assigned spirits keep producing back into the board.

---

## Economy

*Parked for last — numbers are sim-tuned once the mechanics settle.* This section will set the
**structure** of the new currency flows, not invent final numbers:

- **Coin sinks** — expedition launch cost (coins' first open-ended sink) and per-map capacity-upgrade
  cost.
- **Diamond levers** — premium-expedition price and keep-extras price.
- **Faucets** — per-map production rates and caps for each reward (coins, Water, generator-booster,
  diamonds, residents), plus the free / sell return.
- **The proof** — re-author `grove_sim` around the resident faucet + capacity and show the base
  invariants stay green (no-strand, no-jam, `sink > faucet`, selling-is-not-income, I2), plus the new
  **Rush sim** (fair tide, no forced loss).
- **Felt scale (provisional targets)** — the sim and reviewers need the intended magnitude, e.g. a
  fully-housed map-1 produces ~one expedition's coin cost per day (which also directly tests
  sink-positivity); a map-4 red's diamond trickle stays well under a cash pack; collection completion
  is a multi-week chase. Provisional, but stated so "is the payback worth the grind" is answerable.

---

## Risk

The expansion bolts a faucet, a cap, a premium-currency source, and a frantic mini-game onto a
deliberately-tuned base economy. The honest risks, grouped, with how each is contained:

### Economy (load-bearing)

- **Premium-currency faucet (map 4)** — residents minting diamonds reopens the IAP value proposition
  itself; if output out-paces the cash packs it guts monetization. *Contain:* hard daily/clamped caps,
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
- **Coins self-funding** — map 1 makes coins while Explore spends them; the net must stay
  sink-positive or the loop pays for itself.
- **Map-5 bypass** — the resident-spawning generator is a free acquisition path; it must stay
  slow/random enough that paid Explore remains primary, so it doesn't undercut coins' sink.

### Tone & design

- **No-loss guardrail relaxed** — keep-extras' "vanish unless you pay" is a deliberate FOMO lever in a
  cozy game. *Contain:* bounded — every spirit stays reachable on coin runs; premium only compresses
  time-to-red — but a real departure to watch in playtest.
- **Rush: fun vs chaotic** — tide + capture + treefall + countdown is a lot at once and could read as
  stressful, not cozy-exciting. *Contain:* the Rush sim + playtest set the rates; treefalls are
  telegraphed; easy dials exist (knock-down crush, slower tide).
- **Pay-to-win perception** — two diamond levers could feel like a gate. *Contain:* "premium buys
  speed + looks, never possibility" holds, with a defined coin-only reachability floor per rarity.
- **Hub vs the world** — a global Residents screen trades the base game's "welcome them home where
  they live" intimacy for one management surface. Accepted; watch it doesn't feel detached.

### Scope & technical

- **Content dependencies** — the map-3 generator-booster and the map-5 special generator are **not
  built**, and rarity/collection art doesn't exist; v1 leans on the placeholder + colour-frame.
  Bespoke content is a separate task and a genuine scope risk.
- **Save migration** — a schema change (rarity, capacity, collection, production state, in-hand
  spirits); must be non-destructive (old saves read as housed commons).
- **Runway** — only the 5 home-grove maps are wired against a designed 20-place journey, so the
  *Expand* arm and reward-stream variety stay thin until post-launch maps ship; v1 leans on Explore +
  merge + collection.
- **Early-game gap** — the loop is gated on first-map completion; the pre-completion coin-sink gap is
  inherited and unverified.

All the economy items converge on one obligation: **re-author and re-run `grove_sim`** around the
resident faucet + capacity before build, holding the base invariants green. That work is the parked
Economy pass.
