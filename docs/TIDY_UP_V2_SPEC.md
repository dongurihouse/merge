# Tidy Up v2 — The Generator-Board Spec (draft for owner review)

**Status:** DRAFT 2026-06-10 · supersedes the board/level/economy core of
`archive/TIDY_UP_SPEC.md` (v1) per the owner pivots recorded in `archive/DESIGN_NOTES_2026-06-10.md`.
All numbers are coherent placeholders for the tuning sim (§9) — shapes are the spec,
values are not.

> **One sentence:** a cozy long-term *cultivation companion* — one persistent
> merge board per area-project, fed by a water-gated generator, where forest
> animals consume your harvests into Stars that visibly restore the homestead.

## §0 — THEME LOCKED: "Ghibli Grove" (owner, 2026-06-10)

Hand-drawn pastoral anime style (ART_DIRECTION.md Direction F + style bible in
`GROVE_STYLE.md`). **Merging is growing.** The canonical noun map — the spec
below still uses some v1 nouns; read them through this table:

| Mechanic noun (spec) | Grove noun (the game) |
|---|---|
| Board | a garden clearing on the homestead |
| Item families / tiers | **growth lines**: seed → sprout → sapling → bloom → harvest |
| The Box / generators | **seed satchel**, compost bin, beehive… (one per line-set) |
| Energy | **Water** (watering can; refills = rain) |
| Locked boxes (ring tiers) | **bramble / overgrowth patches** (denser by ring) |
| Dust covers / tangles | leaf piles / vines |
| Quest givers (busts) | **forest animals & neighbors** (fox, hedgehog, owl…) |
| The home scene | **the homestead** (farmhouse, barn, well, pond) |
| Scene unlock track (stars) | restoration spots — and **unlocks make animals
  appear and STAY** (ambient life is earned, not decorative) |
| Districts / projects | **areas of the grove**: Farmhouse Garden → Orchard →
  Pond → Meadow … |
| Coins | acorns? (TBD owner) — personalization variants |
| Diamonds | **dewdrops/amber** (TBD owner) — premium-shaped, earned |

Working title stays "Tidy Up" in code; the shipping name is an open owner call
(grove-flavored candidates whenever ready). The cozy-night UI palette (purples)
will be replaced by the grove daylight palette (GROVE_STYLE.md) during P1.

---

## §0c — OWNER DELTAS (2026-06-11, all built)

1. **Home = one free-pan top-down MAP.** Zones are POI sprites placed at authored
   coords on EMPTY terrain art (no boxes, no baked-in buildings); locked zones
   render greyed-out in place; tap-vs-drag on the same surface.
2. **The board fills the phone side to side** with a garden-bed mat behind the
   grid for contrast (tray art; bordered panel until it lands).
3. **The quest row is a FENCE** spanning the screen above the grid: a bordered
   wall the giver animals pop up over — up to 5 asks visible at once + the
   merchant at the right end (was: 2 floating chips).
4. **Idle hint:** after ~7s without input, one mergeable pair wiggles; re-nudges
   every ~4s while idle.
5. **The board edge is END GAME.** Bramble gates are now (line, tier):
   ring ≤2 → t2 any · ring 3 → t4 any · ring 4 (screen edge) → **t5 of a LATE
   line** — top half mushrooms (compost), bottom half honey (beehive). Gated
   bramble contents seed their own line. Terrain encodes gate_line*16+req
   (legacy saves decode unchanged).
6. **Generator #3 — the Beehive** (line 4 "Honey", 8 tiers) reveals at chapter 27
   in the orchard era; its asks join the chapters from there (deterministic
   builder gives every new line a tier-3 ease-in for its debut zone). End state:
   three generators share the board; the sim still PASSes (0 jams; the optimal
   bot finishes all 40 spots with ~14 edge brambles left as long-tail goals).
7. **Art regen queue:** berry_2 (read identical to flower_2), tall board tray,
   fence strip, beehive + honey line — rows + aspect discipline in ART_CHECKLIST.
8. **Zones are CHESTS with lids (supersedes the scattered pins).** Closed =
   the building + one status line ("✿ after <zone>" locked · "✿ N★ left" open ·
   "✿ restored"). Tap an unlocked zone → its lid opens IN PLACE (no modal),
   listing the unlockables inside — each row carries its state pin: ✿N★ buy /
   Lv N gate / ✓ owned (+variant swatch). Tap the land to close. The
   alternative (items baked into the map art at exact spots) stays open via a
   very placement-specific map prompt if we ever want it.
8b. **The top bar is ONE module** (scripts/hud.gd): ★🪙💎 cluster + the Store
   button pinned to the same pixels in every scene; scenes add only their own
   chip (Lv at home, 💧 on the board, top-left).
8c. **The Shop** (scripts/shop.gd, §6b): 💎→water (25), 💎→coins (5💎→150🪙),
   and cash→💎 packs ($0.99→80 / $4.99→450 / $9.99→1000) as a CONFIRM-ONLY
   popup that grants directly — the IAP rails replace exactly that confirm
   later. Earned-only economy otherwise unchanged.
9. **(prior #8) No 0/8 zone button — the items LIVE on the map.** Each zone's 8 spots
   scatter around its house (offsets derive from the close-up positions, pushed
   off the building footprint; the modal close-up is retired). Every spot is
   LEVEL-gated: gate(rank i) = the level a worst-case player provably has after
   i purchases (level_for_exp(30·i)) — pigeonhole-proof against stranding
   (test 14c walks all 40 worst-case). Greyed "Lv N" pin → "✿ N★" pin (tap =
   star check → buy) → built chip. Tapping an OWNED item opens its
   customization list: Classic (free) + a coin variant (25-95🪙) + a diamond
   variant (2-4💎), persisted per spot (grove.custom), tinting the piece.
   The board gate + sim are level-aware (givers never pause for a locked spot).

10. **Zone INTERIORS (2026-06-11 — supersedes the OPEN state of #8/#9).** The
   map keeps ONLY the closed zone state (building + "✿ N★ left"/requirement
   line). Tapping an unlocked zone opens a full-screen INTERIOR under the
   pinned HUD: the room art is the screen, unlock spots sit at their painted
   plots with the same 3-state pins, owned spots draw furniture sprites, and
   the inline customize strip moves inside. The single-input-surface law,
   level gates, and all purchase flows carry forward. (BUILD_QUEUE order K.)

11. **Interior PLACEMENT LAW (2026-06-11, owner screenshot).** Star-unlock
   items in a zone interior must be FLOOR-STANDING objects the engine can
   composite onto the room art (bed, table, chest, rug…), positioned on the
   painted floor with the sprite drawn from the SAME camera angle as the room.
   At most ONE flat wall-hung picture per room; nothing else wall-attached,
   shelf-mounted, or sill-mounted (too hard to place well). Architectural
   fixtures (hearth/fireplace, stalls, lofts, doors, windows) are BAKED into
   the room background, never sold as unlockables. Sprite cutouts must be
   clean — no white left in enclosed gaps (between table legs). Supersedes
   #10's "painted plots" language: v2+ room art paints an EMPTY open floor;
   spot positions are authored data (order Q3). The canvas
   outside the room cutaway is never plain white (paint the surrounding
   garden/grounds). Applies to EVERY zone; outdoor zones (pond/orchard/meadow)
   comply naturally — ground placement IS floor placement. (BUILD_QUEUE order Q.)

12. **Placements are HUMAN-AUTHORED via the placement tool (2026-06-12,
   owner-direct to eng).** Every scene with placeable items — zone interiors,
   the map's POIs and waysides, any future room — gets its positions placed
   by a HUMAN with the placement tool (eng builds it on the owner's direct
   instruction): drag each item into place on the real art, and the tool
   writes the coords (and footprint size) back into the content data. Agents
   never hand-guess or measure-guess coordinates once the tool exists — Q3's
   gridded-render fit and M's centroid blobbing were the stopgaps that
   motivated this rule. **New-scene workflow:** art lands → spots/props
   register with provisional positions (explicitly marked provisional) →
   the OWNER places them with the tool → positions commit as content data
   like any other change. An agent re-fit is acceptable only as the
   provisional default awaiting human placement, never as final.

## §1 — The board (ONE per map, persistent, long-running — H1 resolved)

- **Grid 7×9 (63 cells).** At project start only the **center 3×3 is open**: the
  **Box** (generator) in the middle + a few starter items. Everything else is a
  field of **locked boxes**.
- **The board is SAVED** — grid, boxes, quest state persist across sessions. There
  is no "level select", no restart, no board-clear win, no undo. The board is a
  workplace, not a puzzle.
- **Locked boxes** open the v1-drawer way: a **merge adjacent** to a box unlocks it,
  revealing its contents (items / coins / occasionally energy or a diamond).
  - Boxes carry a **required merge tier** that grows ring by ring from the center:
    ring 1 opens on any adjacent merge, ring 2 needs a **t2+** merge beside it,
    ring 3 t3+, outer corners t4+. (Wordless: the box's padlock shows the item
    silhouette of the tier it wants — the v1 shelf-ghost trick.)
  - **Opening boxes is expansion, NOT the goal (owner, 2026-06-10).** The board is
    meant to **never really finish** — the field is deep and the outer rings
    demand t4/t5 merges, so working space grows for as long as the project runs.
    If a player DOES open every box anyway: a **special award** (a "Spotless!"
    badge + a diamond bundle), and the board simply keeps operating fully open.
- **Free arrangement (owner, 2026-06-10):** any unlocked item can be **dragged to
  any empty cell** — position is the player's to manage (clearing working space,
  lining a merge up beside the box it should open). Merging stays drag-onto-match;
  moving is drag-onto-empty.
- **Families arrive WITH their generators** (§2): the starter generator carries
  1–2 families; each later generator adds its own (the district's signature
  family debuts mid-project with its generator — v1's debut rule, kept). Items
  merge only within their family.
- **8–10 tiers per line (owner, 2026-06-10; was 5).** The ladder is exponential
  (a t8 = 128 t1-equivalents ≈ ~80 pops — an EPIC ask), so: top tiers are
  genuinely rare trophies, the art cost is just a few more icons per line, and
  late-zone quests get depth headroom (zone asks ramp ~t3 → t6; t7–t8 are rare
  showcase asks / tail content). Growth ladder example (8): seed packet →
  sprout → seedling → sapling → bush → blooming bush → fruiting tree →
  harvest tree (→ bounty cart → golden tree for 10-tier lines).
- **Coins as items:** ~10% of merges also drop a coin on a free cell
  (c1 = 1 coin; c1+c1 → c2 = 5; c2+c2 → c3 = 25). Tap to collect (free). Coins on
  cells add gentle space pressure.

## §2 — The Box (the generator)

- **Tap a generator → 1 Energy → one item pops** to a nearby free cell (pop juice).
- **Generators ARE the complexity curve (owner, 2026-06-10):** every board starts
  with **one generator** (the center Box) — early merging is naturally simple and
  abundant. As the player levels up through the chaptered quest script (§3), **new
  generators appear at scripted milestones** (presented as a reveal in the locked
  box-field), each producing its **own family set**. A new family debuts WITH its
  generator.
- **What pops:**
  1. **Tier is random with decaying odds** — mostly t1, occasionally higher
     (placeholder: t1 65% · t2 25% · t3 9% · t4 1% — sim-tuned per generator).
  2. **Family weighted toward open quest asks** (within that generator's lines) —
     a giver wanting books makes the book generator lean bookish.
- **SELL ANYTHING (owner-FINAL, 2026-06-10 — supersedes the earlier rejection):**
  any unlocked item can be sold to the Merchant for a few coins (drag it onto
  the squirrel's cart; value scales with tier, small). **Clearing the board is
  always free and always available — THE friction is water, nothing else.**
  Board squeeze becomes a soft management cost (sell junk cheap vs. bag it vs.
  merge it), never a wall. Deadlock is trivially impossible.
- **The Merchant (one character, two trades):** the standing Market Squirrel
  - **pays WELL for top-tier trophies** (tap the cart when a t8 exists →
    +MERCHANT_COINS — the proud moment), and
  - **buys ANYTHING dragged onto the cart** for tier-scaled pocket change
    (the cleanup verb). Coins themselves aren't sellable — tap collects them.
  One system still owns "things leave the board": givers.
- Other tools unchanged: move to empty cells (§1), the **Bag** (§2b), diamonds
  to **pop a locked box open** (§6). A full board just dims the generators
  (popping costs nothing while dimmed).

### §2b — The Bag (overflow storage)

- A small tray at the board's edge: **drag any unlocked item in** to shelve it,
  tap to place it back on any empty cell later. No timers, no cost to use.
- **2 slots free**; more slots are bought with **diamonds** (escalating price);
  level-ups occasionally gift one. (This is the earlier "inventory" idea — same
  feature, one name: the Bag.)

## §3 — Quest givers (the content; this IS the authored part)

- **2 giver slots** (3rd unlocks by level). Each giver is a character (bust art)
  with an ask: *N items of family/tier* — some want one item, some a small set.
- Asks come from the project's **authored quest script**: an ordered, deterministic
  list `(family, tier, count) → payout (★, coins, sometimes 💎)`. The script only
  references families/tiers already available, ramps t3 → t5, and IS the project's
  difficulty curve. Authoring v2 content = writing quest scripts, not boards.
- **Quests are FINITE and CHAPTERED (owner, 2026-06-10).** The script is cut into
  chapters; each chapter issues just enough quests to bank the stars for the next
  progression step. **When banked stars cover the next level-up/unlock, the givers
  stop coming** — no quest grinding ahead, no star hoarding. The player is DRIVEN
  to spend: level up / unlock the next scene spot → the next chapter's quests
  arrive, **possibly a new generator appears**, complexity rises — and chapter by
  chapter the project completes and the next district opens.
  - Built-in safety: the pause only ever triggers when the player CAN afford the
    next step, so "no quests + can't progress" is impossible by construction.
    While paused, the board stays fully playable (merge/move/open boxes — stock
    up for the next chapter).
- **The complexity ramp is quest-shaped:** early asks want one thing from the one
  generator; later asks want **two+ things from DIFFERENT generators** ("a t4 book
  AND a t3 plant") — juggling production lines on one board is the late game.
- **Delivering:** when an asked item is on the board the giver's icon lights up;
  tapping it **flies the items off the board** into their hands → payout +
  **avatar cheer** ("hey, you did it!" — big pop, the bust bounces in). The giver
  leaves; the script's next entry walks up.
- Board-leaving items replace v1's clear-rule: there's no clearability math —
  the Box's policy (§2) plus script-aware weighting keeps every ask completable.

## §4 — The home scene & the star track (no separate bedroom screen)

- **ONE pannable map, 4–5 ZONES (owner, 2026-06-10).** The home scene is a single
  grove map: **Zone 1 = your farmhouse** (the starting area) → **Zone 2 = the
  barn** → Zone 3 the pond → Zone 4 the orchard → (Zone 5 the meadow). Zones
  open sequentially.
- **Zoom-in presentation:** pan over a zone to peek, or **tap to "open the
  roof"** — a dollhouse-style close-up where that zone's unlock spots live
  (Zone 1's unlocks are INSIDE the farmhouse). Art per zone: one exterior on the
  map + one close-up interior + its unlock overlay layers (the same-canvas
  cutout technique; `process_decor.gd` pipeline).
- **Each zone has 8–10 unlock spots · each spot costs 3–5★** (owner numbers).
  Star prices NEVER inflate — pacing comes from quest depth (§6 pacing table).
  Unlocks appear in place with the reveal beat; **animals arrive and stay** at
  scripted spots; the v1 room machinery (pins, glow, completion beat) relocates
  here and `Room.tscn`/`Menu.tscn` retire.
- **Each unlock grants EXP + a reward bundle** (coins always; every ~3rd unlock
  1–3 💎; occasional energy).
- **Coins personalize**: any unlocked spot can be re-skinned with a styled variant
  (coin-priced; pure expression, never progress).
- **Project complete = the scene's unlock track is complete** (all decoration
  spots — or whatever that district requires). The board's box-field is NOT a
  completion requirement (§1) — it's the workplace, sized to outlast the project.
  → Completion ceremony → the **next district project** begins: fresh board, new
  backdrop/tray (already shipped per district), new family debut, new quest
  script. The **map becomes the project portfolio** (done projects = postcards;
  current = progress bar; future = locked teasers).

## §5 — Player level (the visible timeline)

- **EXP** comes mostly from home unlocks (+ a little per quest).
- The top-of-screen **level** fills along a **visible timeline of upcoming
  unlocks**; each level-up pays **energy + diamonds** and unlocks features on a
  fixed schedule — this REPLACES v1's progress-based FTUE staging:
  L2 inventory slot · L3 coin variants shop · L4 third giver slot · L5 district
  page/map · L6 helper: Hint · L8 helper: Sweep · L10 second project preview …
- Level-ups can also grant **special items** (a Wild piece, a box-key).

## §6 — Energy & the four currencies

| | Earn | Spend | Notes |
|---|---|---|---|
| **Energy/Water** (cap 100) | +1 / 2 min (regens while away) · level-ups · free refill ×3 lifetime on first empties · **win-back refill** (full cap when returning after ≥48h away) · **quest rewards on a cadence** (chapter-final quests pay water — gives the player a reason to keep playing RIGHT NOW; invariant: a chapter's water rewards < ~30% of its water cost, so sessions extend but never self-sustain) · 💎 refill | 1 per generator pop | THE pacing friction — and (owner, 2026-06-10) the friction is INTENTIONAL: it's what monetization later hangs on. Merging, moving, delivering, selling, collecting, decorating are always FREE — out of water, the board still lets you finish everything in flight. |
| **Stars** | Quests only (1–3★ by ask depth) | Home-scene unlocks | The progress currency. |
| **Coins** | Board pickups · quest bonuses · unlock bundles | Variants (personalization) · later: inventory slots | The expression currency. |
| **Diamonds** | Unlock bundles · level-ups · rare quest bonus | Energy refill (25💎 = full) · **delete any item** (2💎) · **instantly open a locked box** (5–15💎 by ring) · **Bag slots** (10/25/50💎…) · coins (1💎 = 10c) · special skins | Premium-SHAPED, **earned-only at launch**. **When the game is complete, diamond IAP switches on** (owner, 2026-06-10) — this is the planned monetization path; every diamond sink above is therefore also a future revenue surface. |

**Pacing math (owner numbers checked, 2026-06-10 — sim still validates §9):**

Fixed by owner: unlock = **3–5★** (avg 4) · quest pays **1–2★** (avg 1.5) ·
zone = **8–10 spots** (avg 9). Therefore, per zone: **~36★ ≈ ~24 quests**, and
the chapter gate fires every **2–4 quests** (a spend beat each time — great
cadence). Whole 5-zone map ≈ **160★ ≈ ~110–120 authored quests**.

The water cost of a star is the ONLY pacing lever (star prices stay small and
friendly forever). With random-tier drops, expected pops per item ≈ tier-value /
1.6, plus mismatch overhead. Scaling ask depth by zone:

| Zone | Ask depth | ~water/★ | ~water/zone | Engaged days (~300💧/day) |
|---|---|---|---|---|
| 1 Farmhouse | t2–t3, single-line | 4 | ~145 | **~0.5** (the hook) |
| 2 Barn | t3, occasional t4 | 7 | ~250 | ~1 |
| 3 Pond | t3–t4, 2nd generator asks | 10 | ~360 | ~1–1.5 |
| 4 Orchard | t4, cross-generator | 14 | ~500 | ~1.5–2 |
| 5 Meadow | t4–t5, multi-item cross-gen | 18 | ~650 | ~2–3 |

**Map total ≈ 1,900💧 ≈ 6–8 engaged days (casual ≈ 2×)** — matches "huge and
long, can't be finished quickly" while the FTUE stays hot: first unlock = 3★ =
2 quests ≈ ~10💧 ≈ **inside the first 15 minutes**.

**Verdict on the owner's numbers: they work,** with one rule added — *quest
depth scales by zone; star prices don't.* (Flat depth at the same star numbers
would finish the map in ~2–3 days.) The box-field stays sized so the scene
completes with brambles left over (full-clear = tail achievement, ~p10).

## §6b — The Shop (owner 2026-06-11; scripts/shop.gd)

Reached from the 🛒 in the shared top bar (scripts/hud.gd) — same spot on every
screen. Diamonds buy SPEED, never possibility; cash buys diamonds only.

| item | price | grants | notes |
|---|---|---|---|
| Fill your water ☔ | `G.REFILL_DIAMOND_COST` (25💎) | water → cap | row shown only where the host can grant water (a `water_grant` Callable); ONE price constant shared with the board's paid rain |
| Pocket of coins | 5💎 | +150🪙 | pocket-change sink for customizations |
| Gem pack S | $0.99 | +80💎 | confirm-only popup |
| Gem pack M | $4.99 | +450💎 | confirm-only popup |
| Gem pack L | $9.99 | +1000💎 | confirm-only popup |

**Cash is NOT hooked up.** Each pack opens a confirm popup labeled
*"(test build — nothing is charged)"*; confirming grants the diamonds directly.
The future IAP integration replaces ONLY the middle of `Shop._confirm_cash`
(the grant call) — UI, rows, and grants API stay as-is. Diamond rows disable
(dim) when the balance can't cover them; balances rebuild after every purchase.

## §7 — Screens & flow (v2 topology)

```
Boot → HOME (the current project scene, pannable; HUD: level/★/⚡/coins/💎)
        ├─ the project site → THE BOARD (one tap away, the core loop)
        ├─ star-unlock pins on the scene (the spend moment)
        ├─ quest list button (asks + rewards + "Go")
        └─ MAP (project portfolio: done postcards · current bars · future teasers)
```
- Plaza ambience (people/cars/swipe-theater) = **v2.1 lux**, not load-bearing.
- v1 screens: `Main.tscn` board → becomes the project board · `Jobs.tscn` →
  becomes the portfolio map · `Room.tscn` → retires into HOME · `Menu.tscn` →
  retires (boot lands on HOME; settings gear moves to HOME).

## §8 — UX commitments carried in

- **Drop zones +50%** while dragging; overlapping zones resolve to closest center.
- **Idle hint**: ~8s without action → two mergeable items pop gently.
- **Drawer/ticket prominence** → boxes pulse when a merge would open them; givers
  bounce when deliverable. Completions SCREAM (avatar cheer + burst + shout).
- All v1 juice (FX layer), calm mode, settings, i18n, safe-area, quiet-capture
  and e2e tooling carry over unchanged.

## §9 — Build phases (each ends device-playable; feel gates like v1's R1)

1. **P1 Core feel (gate):** 7×9 persistent saved board, locked-box rings, Box
   dispensing per §2 (energy OFF), one scripted giver consuming items, avatar
   cheer. *Gate: is pop→merge→deliver satisfying for 10 minutes?*
2. **P2 Economy:** energy + regen + free refills, stars, full quest script,
   coins-on-board, EconConfig v2 tables, **headless pacing sim** (a bot that plays
   N days and charts energy→★→unlock rates — the e2e driver pattern).
3. **P3 Home scene:** pannable project scene, star unlocks in place (port room
   machinery), EXP/level timeline, nav rewire, retire Menu/Room/level-select.
4. **P4 Projects:** completion ceremony, project 2 (Linen Lane scene art needed),
   portfolio map, family debuts.
5. **P5 Polish:** inventory, diamond sinks/skins, FTUE script (free pops → first
   star in 2 min → energy reveal on first empty), plaza ambience, audio.

QoL items (§8 drop zones + idle hint) can ship on the CURRENT game immediately —
they're core-agnostic.

---

## §10 — REVIEW: does it hold together?

**Loop closure ✓** — every currency has a source and a sink; the only externality
is time (energy regen), which is the intended retention mechanic. Dead ends are
**possible by design** (no system guarantee) but always tool-escapable: move to
empty cells, Bag, diamond delete/box-open — and diamonds drip steadily from the
earn loop. A player with 0 energy can still merge, move, deliver, and decorate
(sessions end on a beat, not a wall).

**Deterministic ✓** — quest script, unlock track, level timeline, box contents,
and dispenser policy are all authored tables; two players at the same point see
the same game (dispense randomness is cosmetic: which family pops first, not
whether progress is possible).

**Risks (carried into playtest):**
- **R1′ energy friction — REFRAMED (owner, 2026-06-10): the resentment is the
  point.** Wanting more water is what monetization later hangs on; do NOT design
  it away. The line held instead: **diamonds buy SPEED, never POSSIBILITY** —
  progress is always free (regen, free movement, selling, 2 bag slots), just
  slower. Watch the first-empty moment for tone, not for existence.
- **R2′ one-board monotony** — mitigations: family debut mid-project, ring tiers
  changing the unlock cadence, coins, script variety, project transitions. If the
  sim shows >2 days on an unchanged board section, the script needs an event.
- **R3′ early dead air** — 0 energy + 0 stars + nothing deliverable = nothing to
  do. Acceptable steady-state (that's the timer), FATAL in the first session —
  the FTUE script must guarantee a star unlock and a refill before first empty.
  (The §3 chapter gate helps here: a quest pause always means "you can afford the
  next step" — dead air from quest exhaustion is impossible by construction; only
  energy can stall you.)
- **R4′ table tuning** — placeholder numbers WILL be wrong; the P2 sim bot is
  load-bearing, not nice-to-have.
- **R5′ art scale** — each project needs a full pannable scene + unlock layers.
  Project 1 is free (bedroom art exists). Project 2+ ≈ 10–14 images each — same
  scripted-loop pipeline, prompts doc when P4 nears.
- **R6′ soft-stuck — CLOSED by the sell valve (§10b H2):** with sell-any-item
  free, a board can always be drained; true deadlock is impossible. Sim still
  watches "forced-sell frequency" as a comfort metric.
- **R7′ monetization optics — REFRAMED with R1′:** friction is intentional, but
  the defensible (and app-review-safe) line is *speed vs possibility*: every
  wall must be passable free (slower), never purchasable-only. EconConfig
  invariants: chapter water-rewards < ~30% of chapter cost · sell always
  available · diamond drip from the earn loop never hits zero for >1 chapter.

### §10b — Second end-to-end review (2026-06-10): holes found → owner-resolved

- **H1 — RESOLVED (owner): ONE BOARD PER MAP.** A map (this one: "the Ghibli
  Grove") contains 4–5 zones (house, barn, pond…); the single persistent board
  serves the whole map; zone milestones are where generators appear. The NEXT
  map comes only after this one is completely unlocked (and that takes a
  while). **v1 scope = map 1 only.**
- **H2 — RE-RESOLVED (owner-FINAL, 2026-06-10): sell-anything IS in.** The
  Merchant keeps the generous top-tier trade AND buys any dragged item for
  tier-scaled pocket change. Rationale: clearing the board should always be
  free — **water is the only intended friction**; space is a management cost,
  not a gate. (Liquidation isn't profitable: sell values are far below the
  water invested, so selling is cleanup, never income.) Deadlock trivially
  impossible.
- **H3 — ACCEPTED (re-grained in P4):** water gifts < ~30% of measured spend,
  enforced per ZONE (per-chapter denominators are seed-noisy under an optimal
  bot; the intent — sessions extend, never self-sustain — is a totals property).
  Paid at the spot purchase (the real gate). Sim-checked, 4 seeds.
- **H4 — ACCEPTED:** win-back refill at ≥48h absence → full cap.
- **H5 — DOWNGRADED (owner): squeeze is a FEATURE, measured not capped.** With
  the merchant + bag + free movement, hard walls are impossible — so board
  squeeze is intentional monetization pressure (bag slots, box-opens), not a
  bug. The sim still TRACKS squeeze per chapter (forced-merchant frequency,
  open-cell low-water-mark) so the pressure CURVE is known and tuned
  deliberately — intentional ≠ unmeasured.
- **H6 — ACCEPTED AND WIDENED (owner):** chapters carry MORE than one surplus
  quest — slack scales with depth (zone 1: N+1 → zone 4–5: N+2..N+3). Complete
  any N; leftovers expire at the chapter gate. Determinism kept, walls gone.
- **H7 — TUNING NOTES stand:** mild dispenser weighting (~60/40), alternate
  zone-1 asks between lines, and the freebie-cliff taper (week-1→2 water budget
  slopes via chapter-final rewards, never steps).

## §11 — COMPARISON: v2 vs v1

| Axis | v1 (today, shipped) | v2 (this spec) |
|---|---|---|
| Core verb | merge-2 identicals | **same** (untouched) |
| A "board" | authored puzzle, cleared in minutes | one persistent workplace per project, lives for days |
| Win moment | board-clear ("All tidy!") | quest delivery + star unlock + project ceremony (many small beats, no terminal clear) |
| Session shape | pick level → clear → next | pop/merge/deliver until energy ebbs → spend stars → leave mid-board safely |
| Friction | authored frictions (drawers/covers/tangles/floor) | **energy** + the locked-box field (drawers, scaled up) |
| Stars | per-board performance (★★★) | quest currency → home unlocks |
| Economy | coins from clears → buy decor | 4-currency deterministic track (§6) |
| Content cost | hand-author every board (+ clearability math) | author quest scripts + box pools — cheaper per hour of play |
| Can't-lose | can't lose, can always finish NOW | can't lose, but **can have to wait**, and a full board **can jam** (tools — move/Bag/diamonds — are the escape; jam-rate is a sim-watched metric) |
| Positioning | cozy puzzle snack | cozy long-term renovation companion (Merge-Mansion-shaped, tidying-themed) |
| Monetization | none | none WIRED; diamond-shaped socket exists |
| Kept pillars | zero-learning · wordless · juice · cozy · families · adjacent-unlock language — **all retained** | |

**Honest assessment:** v1 was the more *novel* game; v2 is the more *retentive*
one — it adopts the proven merge-meta model and keeps our differentiators (the
tidying fantasy, the adjacent-merge unlock language, the visible renovation, the
client characters). The main thing v1 had that v2 must not lose is **the clean
session-ending beat** — v1 ended on "All tidy!"; v2 sessions end on energy, so the
design leans on delivery/unlock beats to close sessions warmly. If R1′ (energy
resentment) playtests badly, the fallback is energy-free with daily quest caps —
the rest of the spec survives that swap intact.
