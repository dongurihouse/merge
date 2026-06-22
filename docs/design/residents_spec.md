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
  from a list, you discover who turns up and keep one. Spirits have **rarity** (common → rare →
  special), and a **premium (diamond) path** improves the odds. Starts simple; built to grow
  into a full search-and-extraction mini-game.
- **Place — capacity.** Each completed map holds a limited number of spirits (~8 to start,
  upgradable). Two of a kind merge into one — raising tier *and* freeing a slot — so merging is
  progression and space management at once.
- **Expand — the pull outward.** Because spirits need room, the player has a concrete new
  reason to unlock more maps and upgrade capacity, wiring the expansion into the base game's
  progression.
- **Reward — the payback.** Placed spirits **produce for the core game**: board items
  collected from the bag and spent back on the board — boosters, generator items, even Water.
  More and higher-tier spirits make more (the idle, compounding payoff). They also fill a
  **collection** worth completing (kinds × rarity × signatures, per map and overall) and act as
  **quest-givers** handing out special things.

The residents loop: explore → keep one → place → merge → run out of room → expand → explore again.

## The whole-game loop

The expansion turns one loop into three that feed each other:

1. **Merge the board** *(base game)* — restore spots and unlock maps; that buys more board
   space *and* more room for residents.
2. **Explore and grow residents** *(this expansion)* — explore, bring spirits home, merge to
   climb tiers and free slots; that pushes you to unlock and upgrade more maps.
3. **Residents power the board** *(payback)* — placed spirits produce boosters, coins, items,
   and Water that make the board faster and more fun.

The cycle closes: stronger board → more space → more residents → more production → stronger
board. The base game was a single loop that *ended* when a map was finished; this makes it a
three-engine flywheel with no end state — which is what an endgame needs.

---

## Mechanics

*High-level shape; numbers and edge rules are sim-tuned later (see Economy). This bolts onto the
existing roster plumbing — the persisted `{map_id: {type_id: …}}` roster, two-of-a-kind auto-merge,
and the ambient render layer all carry over.*

### Explore — acquire

Replaces the base game's pick-from-a-list "welcome a spirit" panel. There is a single **Explore**
destination — you venture out from home rather than shop from a completed map. Spend **coins** to run
an **expedition**; it surfaces **up to three** spirits drawn from a rarity-weighted **pool shared
across all unlocked maps**. You **keep one for free**; the other candidates vanish unless you spend
**diamonds** to keep them too. Whatever you keep is then **placed** on a completed map that has an open
slot — the separate **Place** step. Capacity gates the whole flow: you can't launch an expedition
with no room anywhere, and you can't keep more spirits than you can house (see **Place**). You
discover who turns up; you don't shop.

- **Rarity** — common → rare → special. A map's **signature** spirits are its *special* draws; the
  shared core (moss / acorn / lantern) are *commons*. Rarity is a new axis on the resident type.
- **Pool grows with progress** — the shared core is always discoverable; **unlocking a new map adds
  its signatures to the pool.** Pushing the base game forward widens *what you can find*, not just
  where you house them — each new map is a discovery event and feeds the collection.
- **Diamonds, two levers** — both buy *better odds and convenience, never exclusivity*; every spirit
  stays reachable on coin expeditions alone, just slower (the base game's "premium buys speed +
  looks, never possibility" law holds):
  - **Premium expedition** — a pricier, diamond-funded expedition draws from **better rarity odds**
    (more rares and specials per run).
  - **Keep extras** — on any expedition, pay diamonds to keep a second or third candidate instead of
    letting it vanish — offered only while you still have free slots to house them.
- **Growth seam** — v1 is the weighted draw only. The thesis's "full search-and-extraction
  mini-game" layers on top later without changing the keep-one contract.

### Place — capacity

Each completed map is a **habitat with a slot capacity** (start: **~8**, upgradable). Placing a kept
spirit assigns it to that map's roster, where it wanders as today.

- **Accounting** — **one slot per resident instance, any tier.** Two tier-1s fill two slots;
  merging them into one tier-2 frees a slot. Merging is therefore progression *and* space management
  at once.
- **Capacity gates Explore** — the expedition reads your **total free slots across all completed
  maps.** Zero free → the expedition is **disabled**, with a message telling you to merge or
  upgrade/unlock room. One or more free → you may explore, and you can keep at most as many spirits
  as you have free slots (the diamond "keep extras" option is offered only while slots remain). You
  never hold a homeless spirit — acquisition is blocked before it can happen.
- **Out of room → expand** — a full habitat is the engine of the next move: merge to free a slot,
  upgrade a map's capacity, or unlock another map.
- **Placement seam** — v1 placement is "assign to map"; spirits still wander freely (stateless
  ambient render). Hand-positioning on a grid is a later layer.

### Expand — the pull outward

Capacity is **per map**, so habitat scales two ways: **upgrade** a map you own (intensive) or
**unlock the next map** (extensive — each new map brings its own ~8 slots). No new unlock mechanic;
this rides the existing completion-chained map sequence. Running out of room becomes a concrete
reason to push the base-game progression forward.

*(Runway note: only the 5 home-grove maps are wired today; the designed 20-place journey is the
long-tail this move leans on.)*

### Reward — the payback

Placed spirits **produce over time** into a collect-point — idle and compounding, so more spirits
and higher tiers yield more. Output spans the full menu:

- **Items** — low-tier board items dropped into the bag, spent back on the board.
- **Coins** — a soft-currency trickle.
- **Water** — capped as a daily top-up only, so it never makes energy self-sustaining (respects the
  energy invariant; see Risk).
- **Boosters** — the **Wild piece** (the one booster grove already ships); this does *not* reopen
  the tone-cut Bomb / x2 / Producer / Countdown toys.

Two collection-facing roles ride on the same residents:

- **Collection** — a ledger of discovered spirits (kind × rarity × signature), tracked per map and
  overall, with rewards for completing sets. Reuses the Explore rarity axis.
- **Quest-givers** — placed signature/special spirits periodically offer a **special quest** (deliver
  requested items → a special reward), coexisting with the metered quest fence.

### The loop, restated

Explore (spend coins) → keep one → place (fill a slot) → merge (climb tier, free a slot) → run out
of room → expand (upgrade or unlock a map) → explore again — while placed spirits quietly produce
back into the board.
