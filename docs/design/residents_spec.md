# Residents — Expansion Spec

*Working title: "The Homecoming" (placeholder).*
*Status: in progress — mechanics drafted (high-level, under review); economy and risk sections to follow.*

A standalone expansion layered on top of the base game (`merge_spec.md`, `grove_spec.md`). It
supersedes the base game's "residents are cosmetic-only" stance; the base specs (`merge_spec.md`
§4/§8, `grove_spec.md` §3) now defer the resident model to this spec.

---

## Summary

The base game restores places. This expansion makes a restored place worth living in.

It adds two things: a new **Explore** mode, where the player spends coins to venture out and
bring spirit-folk home; and a rule that every completed map is a **habitat with limited
capacity** for them. You explore to find spirits, choose who to keep, place them, and merge
two-of-a-kind to climb tiers and free space. In return, the spirits produce items that feed
back into the merge board.

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

- **Explore — acquire.** Spend **coins** to venture out and bring spirits home; you don't pick
  from a list, you discover who turns up and keep one for free (more for diamonds). Spirits have
  **rarity** (four tiers: white · blue · orange · red), and a **premium (diamond) path** improves the
  odds. Starts simple; built to grow into a full search-and-extraction mini-game.
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

Replaces the base game's pick-from-a-list "welcome a spirit" panel. There is a single **Explore**
destination — you venture out from home rather than shop from a completed map. Spend **coins** to run
an **expedition**; it surfaces **up to three** spirits drawn from a rarity-weighted **pool shared
across all unlocked maps**. You **keep one for free**; the other candidates vanish unless you spend
**diamonds** to keep them too. Whatever you keep is then **placed** on a completed map that has an open
slot — the separate **Place** step. Capacity gates the whole flow: you can't launch an expedition
with no room anywhere, and you can't keep more spirits than you can house (see **Place**). You
discover who turns up; you don't shop.

- **Rarity** — four tiers, colour-coded: **white** (common), **blue** (magic), **orange**
  (legendary), **red** (heroic). Rarity is a new axis on the spirit, and it **pays off in
  production**: a rarer spirit yields more (yield rises with rarity × tier — see Reward), so chasing
  reds matters beyond the collection badge. *(The actual roster of spirits at each rarity is content,
  parked with the reward-set design — the existing core/signature placeholders aren't the final set.)*
- **Pool grows with progress** — the shared core is always discoverable; **unlocking a new map adds
  its signatures to the pool.** Pushing the base game forward widens *what you can find*, not just
  where you house them — each new map is a discovery event and feeds the collection.
- **Diamonds, two levers** — both buy *better odds and convenience, never exclusivity*; every spirit
  stays reachable on coin expeditions alone, just slower (the base game's "premium buys speed +
  looks, never possibility" law holds):
  - **Premium expedition** — a pricier, diamond-funded expedition shifts the draw upward two ways: it
    **removes white (common)** from the pool and **lowers the chance of blue (magic)**, so results
    skew toward orange and red. (Every rarity still appears on coin-only expeditions, just at lower
    odds — premium compresses time-to-red, never gates it.)
  - **Keep extras** — on any expedition, pay diamonds to keep a second or third candidate instead of
    letting it vanish — offered only while you still have free slots to house them. The vanish-or-pay
    framing is a deliberate choice that **relaxes the base game's no-loss guardrail** — flagged as
    such for the Risk pass, not an oversight.
- **Growth seam** — v1 is the weighted draw only. The thesis's "full search-and-extraction
  mini-game" layers on top later without changing the keep-one contract.

### Place — capacity & assignment

The residents loop lives on a new **Residents screen** — a hub separate from the merge board and the
map-restoration view. From it you can **assign** a spirit to a map, **merge** two-of-a-kind, **free
or sell** a spirit, **view the collection**, and **launch an expedition** (Explore).

Each completed map is a **habitat with a slot capacity** (start: **~8**, upgradable). Assigning a
spirit to a map fills a slot *and* raises that map's production (see **Reward**) — placement is a
real economic decision, not flavor: where you put a spirit chooses which reward you make more of.

- **Accounting** — **one slot per spirit instance, any tier.** Two tier-1s fill two slots; merging
  them into one tier-2 frees a slot. Merge is progression *and* space management at once.
- **Merge is per-map** — two-of-a-kind merge only while assigned to the **same map**; the higher-tier
  result produces more for that map. Concentrating a type on one map is how you climb its tiers and
  free its slots.
- **Re-assignment is free** — move a placed spirit between maps any time, to line up a merge or
  rebalance which reward you favor. This is what keeps merging and producing from fighting: a map's
  output sums *all* its assigned spirits' yield (not specific types), so concentrating a type to
  merge it never strands the spirit or permanently starves another map — merge-for-tier and
  assign-for-reward pull the same direction.
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
**unlock the next map** (extensive — each new map brings its own ~8 slots). Each new map also opens a
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

### The loop, restated

Explore (spend coins) → keep one → assign to a map (fill a slot, boost that map's reward) → merge
(climb tier, free a slot) → run out of room → expand (upgrade or unlock a map) → explore again —
while assigned spirits keep producing back into the board.
