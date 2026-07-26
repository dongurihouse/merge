# Cell improvements (Soil · Magnet) — full design (2026-07-26)

**Status: draft 2, after first Dev review (same day).** Review deltas: the Mirror is **cut**
(its auto-merge role is absorbed by the redesigned Magnet); the Magnet is now a **range
auto-merger**, not a ladder-gatherer; the six-slot model is replaced by **free placement with
per-type caps** (9 Soil · 3 Magnets); growing pieces are **never locked** — changing one just
restarts its clock, with a warning at t7+; the grow curve extends to **t12** on long timers.
This doc is the full spec for §6 of `2026-07-26-progression-systems-design.md` (rollout
step 4 — "the ground works") and supersedes the parent's §6 where they differ (§12 lists
every deviation). Code anchors are current as of today's `main`.

All numbers are **provisional dials** — the `grove_sim` re-pass owns the finals (§9).

**Terminology guard.** These are *improvements* on *improved cells* of the home board. They are
unrelated to "habitat cells" (resident-bucket capacity, `engine/scripts/core/bucket.gd`). The
premium currency is written *acorns* everywhere; its save field is `currencies.diamonds`
(`save.gd:145-160`) — one currency, two names, noted once here.

---

## 1 · Scope

Ships: buildable improvements on the home board — **Soil** (a piece resting on it grows a
tier on a timer) and **Magnet** (auto-merges matching pieces inside its range) — with build
mode, per-type caps and rank ladders, the restart-clock growth model and its t7+ warning,
save state, the FTUE beat, FX, sim coverage, and tests.

Not in scope: weather coupling (§4's dormant contract only), the Rush board (a separate scene
with its own throwaway grid — `explore_rush.gd:65` — so every hook below is home-only for
free), new currencies, and any change to the board's unseal pacing (`MIN_LEVEL` stays the
owner's dial).

**Relationship to rollout step 3 (cascades).** The landed step-3 draft
(`2026-07-26-cascade-combos-design.md`) owns chain state and detection. This step consumes
only the scene's `chain_armed_cell()` seam — the Magnet holds fire while a chain is armed —
and its auto-merges bypass chain credit (the cascade spec's R4). The old contract line about
the Magnet consuming `ready_ladders` and gliding pieces described the pre-review Magnet; this
revision amends that line in the cascade doc. Neither system blocks the other's ship order.

---

## 2 · Placement — build anywhere, capped per type

Improvements are built on **any unsealed, empty board cell** the player picks — placement is
the strategy (a Magnet's range wants interior cells; Soil is happy anywhere). No fixed slots.

| Type | Cap on board | Why |
|---|---|---|
| Soil | **9** | a farm, not a second board — 9 of 63 cells |
| Magnet | **3** | three 3×3 fields is plenty of automation |

Caps are per built cell (Dev review call; replaces the parent's six perimeter slots and its
6-cell cap). With everything built, 12 of 63 cells are improved — the board stays a merge
board, and the sim re-pass checks jam pressure at full build-out (§9).

**Buying is building — one payment.** In build mode, tap an empty open cell → the two-card
sheet (Soil · Magnet) → tap a card → `Save.spend(price, "improvement")` → built at rank 1.
Prices climb per type by count already built (§8). **Rebuild** (swap a built cell to the
other type) costs a small flat fee, requires the cell empty, and starts the new type at
rank 1. **Demolish** is free and refunds nothing (open question 1 covers a move verb).

---

## 3 · Board model & cross-cutting laws

**State lives in `BoardModel`, beside the generator trio.** New field
`improvements: Dictionary` — cell `Vector2i` → `{kind: int, rank: int, ...activity}` — the
`gens`/`gen_tiers`/`gen_boost` shape (`board_model.gd:13-24`). Serialization: flattened rows
`[[row, col, kind, rank, code, ends_at, watered], …]` appended inside `to_dict()`
(`board_model.gd:493-503`; `Vector2i` keys are not JSON-safe), parsed tolerantly in
`from_dict()` with the existing `changed = true` re-persist idiom. It rides the existing
`g["board"]` key — no new top-level `_persist()` key, which keeps the
`board_decomposition.md:42-45` "fixed key set" note true. Additive and defaulted-on-read:
**no `SCHEMA_VERSION` bump ever** (a bump discards every player's save — `save.gd:49-58`).

**The laws** (each gets a test, §11):

1. **Piece truth stays in `board.items[cell]`.** An improvement row never copies a piece; it
   only records how the cell treats whatever piece rests on it. Purge, save round-trips, and
   every existing read keep working unchanged.
2. **Pieces are never locked.** A growing piece is fully ordinary — draggable, mergeable,
   deliverable, sellable, stashable. The *clock* is what reacts: any change to the piece on a
   Soil cell (moved away, merged, consumed, replaced) restarts the cell's clock for its new
   occupant, or clears it (§4). The only friction is the t7+ warning (§4), and it is a
   confirm, not a lock.
3. **Improved cells are ordinary ground.** Spawns and drops may land on them
   (`roll_spawn` untouched); on Soil, whatever rests there simply starts growing — arrival
   route doesn't matter. One exception: **generator auto-placement** (`seed_gens`, gen
   self-dup `board.gd:3076`, birth-on-tap) skips improved cells — a generator is a long-lived
   squatter; manual gen drops are still allowed (player's choice, movable).
4. **Improvements draw no randomness, ever.** The board RNG stream is persisted and
   order-sensitive (`board.gd:983`, `board_logic.gd:119-124`); grow times, auto-merge order,
   and every rule below are deterministic. This is also why Magnet auto-merges skip the
   coin/special drop rolls (§5) — the free-value guard and the RNG law are the same law.
5. **Improvements never touch the level clock.** No path calls `G.earn_coins`/`Save.earn_coins`
   (`save.gd:118-124`, sim invariant Y `grove_sim.gd:20`).
6. **Re-evaluation beats.** Soil clock reconciliation and the Magnet scan ride
   `_after_board_change()` (`board.gd:1011-1016`); countdown display rides the existing 1 Hz
   board Timer (`board.gd:362-366`); authoritative completion is a persisted unix stamp
   checked on the tick and on `_load_state` (offline-inclusive, the `regen_ts` pattern
   `board_logic.gd:13-20`).

**Rules module.** Pure logic goes in `engine/scripts/core/improvements.gd` — the
`resident_bucket.gd` shape: static rules, time injected as a parameter, headless-testable.
Dials live in `grove_data.gd`, read through `content.gd` like `TIER_ODDS` (`content.gd:25`).
The whole surface sits behind a `Features.on("improvements")` flag (`features.gd`,
`docs/FEATURES.md`) so it can land dark.

---

## 4 · Soil — rest a piece, wait, it grows

**Verb: none.** Any eligible piece **resting on a Soil cell is growing** — dropped there,
spawned there, or a merge result landing there; the clock starts on arrival. There is no
plant action, no locked state, no cancel action (moving the piece off *is* cancelling).
Eligible: an ordinary tiered line piece below its `G.merge_top(code)` (`content.gd:1390` —
t12 for lines, t3 for specials) — not coins (line 9), chests (10), collectables (12/13), not
a generator. An ineligible or at-cap piece just sits; the cell shows no ring.

**The clock follows the occupant.** Soil activity is `{code, ends_at, watered}`. On every
`_after_board_change()`, the cell reconciles: same code still there → clock runs; new
eligible occupant → fresh clock at its tier (`watered` cleared); empty or ineligible →
activity cleared. Moving a growing piece away and back restarts it from zero — that is the
whole model, and the t7+ warning below is the guard rail.

**Growth completes in place:** at `ends_at` (1 Hz tick or `_load_state` — offline counts),
the piece flips to tier+1 (rank 3: +2, still clamped by `merge_top`) with the standard land
bounce (`LandFx.apply`, the `board.gd:3049-3067` trio) — and, being a changed occupant, a
fresh clock starts at the new tier. Left alone, a piece climbs tier by tier toward t12; each
step is a fresh (longer) timer.

**The grow curve** (Dev re-tune at review — long-tail idle to the top; times are per step,
by the tier the piece is growing **from**):

| From tier | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| To next | 10 s | 45 s | 3 min | 15 min | 30 min | **1 h** | **4 h** | **8 h** | **16 h** | **24 h** | **48 h** |

The Dev pinned →t7 = 1 h and the t8…t12 ladder (4/8/16/24/48 h); t5's 30 min is
interpolated. **This supersedes the parent's ask-cap law** (§7 "soil refuses pieces at the
ask cap and clamps harvests") — there is no ask refusal and no t8 ceiling; the long timers
*are* the balance, and the sim re-pass gates it (§9).

**Ranks.** r1 base · r2 grow times −30% · r3 completion +2 tiers (keeps the −30%; +2 clamps
to `merge_top`).

**The two boosts** — selecting a growing piece populates the **info bar** with a grow row:
title + *"Growing to t8 — 2h 18m"* (the `residents.gd:648` time format) and two
`ActionBar.action_chip` chips (`action_bar.gd:263-330`, the `_build_burst_chip` pattern
`board.gd:2118-2124`):

- **💧 Water** — spend `SOIL_WATER_COST := 10` board water, once per growth step (`watered`
  flag): remaining time halves. Routed through the scene's `water` field +
  `_update_water_hud`, like `_pop_seed` — there is no core water API — then
  `_after_board_change()` so the new `ends_at` persists. Chip label carries the cost
  ("💧 −10"). *Sim flag:* a flat halve is worth 24 h at the t11 step — the re-pass decides
  whether the dial scales with tier or caps the saved time.
- **🌰 Finish now** — `Save.spend_diamonds(price)` with
  `price = max(1, ceil(remaining_secs / 1800.0))` — 1 acorn per started 30 min: 1 h → 2,
  4 h → 8, 48 h → 96 (the 25-acorn refill, `grove_data.gd:310`, is the low-end anchor).
  A new pricing primitive — nothing time-priced exists today; the read is `ends_at − now`.

**Time on the piece.** A growing piece shows a thin progress ring (1 Hz) and a sprout
wiggle; once the step is ≥ 15 min it also wears a small cut-paper time chip ("2h") that
counts down — the Dev asked for remaining time visible on the item, not only in the info
bar. Precise time lives in the grow row.

**The t7+ warning (accidental-reset guard).** Any *player* action that would reset or
consume a growing piece **from tier ≥ 7** — moving it off the Soil, merging it, delivering,
selling, stashing — first shows a small confirm (`Overlay.modal`, dismissable): *"This
restarts 6h of growing. Move it anyway?"* — Keep growing (default) / Move it. Declining
snaps the drag back. Below t7 (steps ≤ 1 h) actions are free of friction. Magnet auto-merges
never touch growing pieces (§5), so no automatic path needs the warning.

**Ask interplay.** None — growth ignores the fence entirely (review call). The lifted
`Quests.top_ask_tier` helper from draft 1 is no longer needed by Soil; the Magnet's
asked-pair guard uses `_asked_codes` lifted into `quests.gd` (§5), which the step-2 mastery
draft's `ask_band` can also derive from — one ask primitive, two consumers.

**Forward seam (weather, step 5).** The landed weather draft pins the contract
(`2026-07-26-weather-hours-design.md` §4): while Rain holds, a growing soil *inside the
patch* fires its once-per-growth watering **free and automatically** — on growth start in
the patch, or on the patch arriving over it. So the seam is the action itself: the pure
module exposes `apply_water(activity, now) -> activity` (halve remaining, set `watered`);
the player's 💧 chip spends water and calls it, weather will call the same seam free.
Dormant until both ship; nothing else is built now.

---

## 5 · Magnet — a field that merges for you

**Verb: none — it's a field.** A Magnet has a **range** centered on its cell. Whenever two
same-code, mergeable pieces (`can_merge`, `board_model.gd:305-311`) both sit inside one
Magnet's range, they **merge automatically**: the pieces pull together and the result lands
on the pair's cell nearer the Magnet (ties → lower board index, `board_model.gd:37`). No
holding, no arrangement, no gliding — the parent's ladder-loom Magnet is superseded (Dev
review call), and the cut Mirror's auto-merge role lives here now.

**Range by rank** (the Dev pinned the max — rank 3 = 3×3; the two lower shapes are this
spec's fill-in):

| Rank | Range |
|---|---|
| 1 | its model row's 1×3 — the cell + east/west neighbours |
| 2 | the plus — the cell + 4 orthogonal neighbours |
| 3 | the full 3×3 |

Off-board and sealed cells simply aren't in range. Ranges of different Magnets may overlap;
a pair fires when both pieces are inside a *single* Magnet's range (each Magnet scans
independently, in board-index order).

**Cadence & FX.** Candidates are scanned in `_after_board_change()`; auto-merges execute one
at a time, ~0.3 s apart — both pieces slide toward the landing cell (`MoveFx`), then the
standard merge FX at reduced scale (`GridFx.play_merge` with the dialog-muted profile,
`grid_fx.gd:27`). Each merge is model-committed before its FX plays and re-enters
`_after_board_change()`, so the loop continues naturally until no pair remains. Per-merge
`animating` is held only for the ~0.3 s slide — under the 0.6 s watchdog
(`board.gd:412-419`), input never wedges. Selection order when several pairs qualify: lowest
tier first, ties by board index.

**Auto-merge guards** (each a test):

- **Never a code an active quest asks for** — auto-merging a deliverable destroys it. Query:
  `_asked_codes` (`board.gd:1512-1518`) lifted into `quests.gd` as a static.
- **Never a piece growing on Soil** (the Magnet doesn't fight the farm — and the t7+ warning
  can't confirm an automatic action).
- **Never while a chain is armed** — reads the scene's `chain_armed_cell()` seam
  (cascade spec §4); an auto-merge mid-cascade would break the player's chain. Resumes on
  the next `_after_board_change()` after the chain disarms. Vacuous until step 3's
  implementation lands.
- **No credit:** auto-merges bump no combo (`_bump_combo` skipped), roll no coin/special
  drops (zero RNG draws — law 4), earn no chain credit (cascade R4). Deterministic
  side-effects still fire: bramble opening (`openable_brambles` on the landing cell) and the
  quest-ready/dim refreshes in the fan-out.
- Uniform over piece kinds otherwise (the cascade spec's R5): coins, chests, and specials
  auto-merge like anything else — consolidation, never new value.

**Range display.** Selecting a Magnet (or entering build mode) shows its range as a faint
cut-paper field under the pieces — the palette treatment the ready-ladder outline uses,
static, no stitching. Rank pips as on every improved cell (§7).

---

## 6 · Shared seams with the cascade system

This step consumes exactly one seam: **`chain_armed_cell()`** (the armed-chain read the
cascade spec exposes on the scene) for the Magnet's hold-fire guard. Auto-merges bypass
chain credit by construction (cascade R4). The cascade draft's step-4 reuse-contract line
("the Magnet consumes `ready_ladders` … never glide the armed piece") described the
pre-review ladder-loom Magnet; this revision amends that line in
`2026-07-26-cascade-combos-design.md` to the guard above. `find_mergeable_pair`
(`board_logic.gd:25`, hints/FTUE) is untouched. The Magnet's own pair scan is a new pure
static beside it — `range_pairs(board, cells: Array) -> Array` of `[cell_a, cell_b]` —
validated with a known-positive AND a known-negative fixture before trusting it.

---

## 7 · Build mode & UI

**The Build button.** A small round leaf button overlaid on the board area's corner (the
bottom bar stays exactly Home · info tray · Bag, `board.gd:1869-1891`). Hidden until the
FTUE beat below has fired; from then on always present, badge-free, quiet.

**Build mode.** Tapping it dims play one step (the hand-hint veil recipe,
`hand_hint.gd:128-192`, minus cutouts) and marks every **empty, unsealed** cell as a
buildable pad (new `Kit.slot_cell` state beside `empty/locked/unlockable/next`,
`ui_kit.gd:5891-5906` — the shared art seam). Built cells show highlighted; tap one for the
rank view. Occupied and sealed cells show nothing. Outside build mode there are no pads —
built cells always show their art + 1–3 leaf rank pips on a corner.

**The build sheet.** `Overlay.modal` (`overlay.gd:47-71`) + the shop's offer-card grid
(`shop.gd:292-413` card schema: art · title · one-line verb · price pill). Two cards — Soil
*"A piece resting here grows."* · Magnet *"Matching pieces in its range merge themselves."*
Each card shows its count against cap ("Soil · 3/9") and greys at cap. Tap a card = spend +
build, the direct-spend pattern of boost (`board.gd:3151`) and cluster unlocks
(`map.gd:1838`) — no nested confirm; unaffordable cards grey at 0.45 but stay pressable and
wiggle the wallet (`shop.gd:603-609`).

**The rank view.** Tapping a built cell (in build mode) opens the same sheet showing the
type's rank ladder, the next rank's price on the bag-slot gold-tile pattern
(`bag_overlay.gd:77-103`, "Max" when topped), a Rebuild row (fee + the other type), and
Demolish. Rank-up celebration is light: `FX.celebrate_at` at the cell, no modal.

**FTUE — the free soil at ~L6.** Arms at level ≥ 6 (`ftue_seen` id `"soil"`,
`save.gd:288-300`); fires as a calm-moment deferred beat (the retirement-offer template,
`board.gd:3938-3964`: never over the FTUE hand-hints, gated on `board_tutorial_seen`). The
beat teaches build mode itself: a one-line card (*"You can tend the ground now — pick a spot
for some soil."* — OK), then build mode opens with a **free Soil credit** and
`HandHint.present` taps a suggested empty cell (`hand_hint.gd:53-71`); the player's tap
builds the free Soil there. The 10 s sprout of the next tier-1 that lands on it is the
payoff. The Build button appears with the beat.

**Art assets** (through the intake pipeline, `docs/design/art-style-guide.md`): soil patch,
horseshoe pebble, buildable pad, leaf Build button, leaf rank pips ×3, the growing-piece
time chip, the magnet range field. Water/acorn chip icons reuse existing.

---

## 8 · Prices & dials (provisional — sim owns finals)

| Dial | Value |
|---|---|
| Soil builds (Nth) | free (FTUE) · 500 · 1 000 · 2 000 · 4 000 · 8 000 · 16 000 · 32 000 · 64 000 coins |
| Magnet builds (Nth) | 2 000 · 8 000 · 32 000 coins |
| Rebuild fee | 200 coins, flat · Demolish free, no refund |
| Soil ranks | r2 600 · r3 1 500 coins |
| Magnet ranks | r2 5 000 · r3 20 000 coins |
| `SOIL_WATER_COST` | 10 water (halve, once per step — sim to revisit at t10+) |
| Acorn finish | `max(1, ceil(remaining / 30 min))` acorns |
| Grow curve | table in §4 |

Per-type ladders (types build independently now); rank prices are flat per-type dials —
deviating from the parent's "ranks cost a multiple of the slot": the FTUE Soil is free, so a
slot-multiple prices its upgrades at 0, and flat dials sim cleaner. Consts live in
`grove_data.gd` beside `BOOST_COST` (`grove_data.gd:232`); nothing goes in
`economy_tuning.json` unless the owner wants a live dial.

---

## 9 · Economy guards & the sim re-pass

Restated as testable laws: no `earn_coins` from any improvement path (Y); auto-merges bump
no combo, roll no drops, leave `rng.state` byte-identical; acorns buy **time only**
(finish-now — never a piece); every coin spend goes through `Save.spend(n, "improvement")`.

`grove_sim` additions (`games/grove/tools/grove_sim.gd`; no make target — run
`godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- [days] [seed]`):

- new sink counters (`improve_spend`) folded into `coin_sink` (`grove_sim.gd:337`) and the Z
  faucet-vs-sink report line (`:341`); the bot buys builds/ranks greedily when affordable
  (the boost-buy block is the template) so absorption shows in I3 runway;
- board-space pressure at full build-out (12 improved cells) — re-confirm I1 zero jams;
- soil throughput as a bounded faucet — 9 cells on the §4 curve, now reaching t12: model
  the long-tail value creation and re-confirm Y and the coin faucet don't drift, and price
  the watering halve at t10+ (§4 flag);
- magnet consolidation is value-neutral by construction (it only merges what exists) — assert
  no sim ledger moves from auto-merges beyond normal merge accounting.

Gate: the sim re-pass runs before this task merges (parent §8).

---

## 10 · Persistence details

- Rows ride `g["board"]` inside `BoardModel.to_dict/from_dict` (§3); defaults on read; no
  schema bump; cloud save carries the grove blob unchanged.
- Tolerant load: a row on an invalid cell is dropped; soil activity is reconciled against
  `items[cell]` on load exactly as on any board change (§4) — a mismatch (e.g.
  `_purge_above_level_content`, `board.gd:774-822`, stripped the piece) just restarts or
  clears the clock, `changed = true`, self-healed.
- `ends_at` unix stamps make growth offline-correct with zero extra machinery; never store
  remaining-seconds.

---

## 11 · Tests

New suite `games/grove/tests/grove_improvements_tests.gd` on `grove_test_base.gd` (pure rules
headless + real-scene beats via the manual-`_ready` drive pattern, `grove_test_base.gd:438-441`,
and `_tap_board` `:126-134`), plus `range_pairs` units in `engine/tests/` beside
`hint_tests.gd`. **Add the suite to `GROVE_TESTS` in the Makefile and to the suite list in
`CLAUDE.md` in the same commit** (the project keeps those in step by law).

Coverage checklist: build/rebuild/demolish/rank flows + cap refusals · pads only on
empty+unsealed cells · ordinariness law (spawn on Soil starts growing; gen auto-place skips)
· clock reconciliation matrix (arrive/leave/replace/merge-onto/complete → restart or clear;
watered resets per step) · the grow curve incl. rank 2/3 and `merge_top` clamps (specials
stop at t3) · water-once + finish price curve · offline completion via stamp · t7+ warning
on every reset path (move, merge, deliver, sell, stash) and absent below t7 · magnet
range shapes per rank · auto-merge ordering, landing cell, loop-until-done · all five
auto-merge guards (asked code, growing piece, armed chain, no credit/no RNG — rng.state
byte-identity — kind-uniformity) · save round-trip + tolerant load + purge self-heal ·
detection known-positive and known-negative · FTUE beat once-only, free credit spends once.

---

## 12 · Deviations from the parent doc (called out)

Dev-review revisions (this round): **Mirror cut** (auto-merge absorbed into the Magnet);
**Magnet redesigned** — range auto-merger, no holding/attraction; **free placement + per-type
caps 9/3** replace the six perimeter slots and the 6-cell cap; **no locking** — restart-clock
model + t7+ warning; **grow curve to t12** — the ask-cap law (parent §7) is superseded, idle
growth is a sanctioned long-tail road to the top.

Carried from draft 1: flat per-type rank prices (not "a multiple of the slot"); the grow
"mini-row" is the info bar's grow row; one payment buys and builds; auto-merge FX never
wedges the input gate (model commits first, FX catches up); improvements draw no randomness.

## 13 · Open questions for Dev

1. **Move verb?** Demolish is free with no refund; there is no "dig up and replant
   elsewhere". A misplaced 32 000-coin Magnet stings. Add a move-for-fee verb, or is
   rebuild/demolish enough?
2. **Magnet rank-1/2 ranges** — the Dev pinned only the 3×3 max; the 1×3 → plus → 3×3
   ladder is this spec's fill-in. Confirm or re-shape.
3. **t5 grow step** — 30 min is interpolated between the pinned 15 min (t4) and 1 h (t6).
   Confirm.
