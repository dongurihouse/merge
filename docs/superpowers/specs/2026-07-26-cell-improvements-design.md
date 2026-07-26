# Cell improvements (Soil · Magnet · Mirror) — full design (2026-07-26)

**Status: draft 1, for Dev review.** This is the full spec for §6 of
`2026-07-26-progression-systems-design.md` (rollout step 4 — "the ground works"). The parent doc
owns the why and the vocabulary split (sky gives / ground works); this doc owns every rule, seam,
dial, and test needed to build it. Code anchors are current as of today's `main`.

All numbers are **provisional dials** — the `grove_sim` re-pass owns the finals (§10).

**Terminology guard.** These are *improvements* on *improved cells* of the home board. They are
unrelated to "habitat cells" (resident-bucket capacity, `engine/scripts/core/bucket.gd`). The
premium currency is written *acorns* everywhere; its save field is `currencies.diamonds`
(`save.gd:145-160`) — one currency, two names, noted once here.

---

## 1 · Scope

Ships: six fixed improvement slots on the home board, the build/upgrade/rebuild flow, and the
three cell types — **Soil** (grows a planted piece), **Magnet** (holds a piece, gathers its
ladder), **Mirror** (a merge on it echoes ready pairs) — with their rank ladders, save state,
FTUE beat, FX, sim coverage, and tests.

Not in scope: weather coupling (§4 of the parent is unshipped; one forward seam noted in §4
below), the Rush board (a separate scene with its own throwaway grid — `explore_rush.gd:65` —
so every hook below is home-only for free), new currencies, and any change to the board's
unseal pacing (`MIN_LEVEL` stays the owner's dial).

**Relationship to rollout step 3 (cascades).** Magnet and Mirror need adjacency-based
ready-pair/ladder detection, which does not exist yet — the only pair finder on the home board,
`board_logic.find_mergeable_pair` (`board_logic.gd:25`), is *not* adjacency-based, and Rush's
`Explore.neighbor_match` (`explore.gd:160-173`) lives in the Rush layer. §7 defines the shared
pure module; whichever of steps 3 and 4 lands first ships it, the other consumes it.

---

## 2 · The slots — where and when

**Six slot cells, fixed, in model coordinates** (`Vector2i(row, col)`, 9×7 grid,
`grove_data.gd:8-9`; landscape rendering transposes visually only, `board.gd:1704-1716`):

| Slot cells | Live unseal level |
|---|---|
| 4 corners — (0,0) (0,6) (8,0) (8,6) | **L16** |
| 2 side mid-edges — (4,0) (4,6) | **L4** |

A slot is **buildable only once its cell is unsealed by the normal bramble rules** — level
reached *plus* an adjacent merge (`board_model.gd:437-443`, fired from `_after_merge`
`board.gd:3208`). The levels above are the **live** `min_level` grid from
`games/grove/economy_tuning.json` (which overrides the `grove_data.gd:82-93` const via
`content.apply_tuning`, `content.gd:146-149`). `MIN_LEVEL` is not re-tuned by this feature.

So the cadence is: the free FTUE soil at ~L6 on a side mid-edge (§8), a second cheap slot
whenever the player wants it, and the corner quartet arriving from L16 (mid–Fairy Hollow under
the live `SCENE_END_LEVEL` windows) — exactly when the coin surplus the sink exists to absorb
starts building. The L4→L16 gap is a known lump; see open question 1.

**Buying is building — one payment.** Tap an empty pad in build mode → the three-card sheet →
tap a card → `Save.spend(price, "improvement")` → the cell is built at rank 1. There is no
separate "own the slot" state (a paid-for empty pad would be a dead intermediate). The price is
keyed to the **Nth paid build** (§9), not to which cell. **Rebuilding** a built cell to another
type later costs a small flat fee, requires the cell idle and piece-free, and resets the new
type to rank 1 (ranks are per-build, not banked).

---

## 3 · Board model & cross-cutting laws

**State lives in `BoardModel`, beside the generator trio.** New field
`improvements: Dictionary` — cell `Vector2i` → `{kind: int, rank: int, ...activity}` — exactly
the `gens`/`gen_tiers`/`gen_boost` shape (`board_model.gd:13-24`). Serialization: flattened
rows `[[row, col, kind, rank, a, b], …]` appended inside `to_dict()`
(`board_model.gd:493-503`; `Vector2i` keys are not JSON-safe), parsed tolerantly in
`from_dict()` with the existing `changed = true` re-persist idiom. It rides the existing
`g["board"]` key — no new top-level `_persist()` key, which keeps the
`board_decomposition.md:42-45` "fixed key set" note true. Additive and defaulted-on-read:
**no `SCHEMA_VERSION` bump ever** (a bump discards every player's save — `save.gd:49-58`).

**The laws** (each gets a test, §12):

1. **Piece truth stays in `board.items[cell]`.** A planted or held piece is never copied into
   the improvement row; the row only marks *how the cell treats the piece on it*. Purge, save
   round-trips, and every existing read keep working unchanged.
2. **An idle improved cell is ordinary ground.** Spawns may land on it and sit inert
   (`roll_spawn` untouched), drops may land, pieces may be moved onto/off it freely, a merge
   may resolve on it. Only a *deliberate player drop* plants (Soil) or arms (Magnet); a Mirror
   acts only when a merge lands on it. A merge result landing on a Magnet does **not** arm it —
   "placed" means an explicit drop. One exception: **generator auto-placement**
   (`seed_gens`, gen self-dup `board.gd:3076`, birth-on-tap) skips improved cells — a generator
   is a long-lived squatter; manual gen drops are still allowed (player's choice, movable).
3. **A growing piece is locked.** While Soil grows a piece: not draggable (`_begin_drag`
   refuses), not a merge target (`can_merge` guard + `_merge_target_at` skip,
   `board.gd:1720-1746`), not sellable/deliverable (selection shows the grow row instead, §4),
   not hintable (`find_mergeable_pair` + hand-hint eligibility skip), never taken by a Magnet
   or consumed by a Mirror echo. Model-level predicate `BoardModel.piece_locked(cell)`; the
   listed sites are the exhaustive touchpoint set.
4. **Improvements draw no randomness, ever.** The board RNG stream is persisted and
   order-sensitive (`board.gd:983`, `board_logic.gd:119-124`); grow times, parking order, glide
   order, and echo selection are all deterministic. This is also why echo merges skip the
   coin/special drop rolls (§6) — the free-value guard and the RNG law are the same law.
5. **Improvements never touch the level clock.** No path calls `G.earn_coins`/`Save.earn_coins`
   (`save.gd:118-124`, sim invariant Y `grove_sim.gd:20`).
6. **Re-evaluation beats.** Magnet scans, pad refresh, and the §5-outline hook ride
   `_after_board_change()` (`board.gd:1011-1016`). Soil countdown display rides the existing
   1 Hz board Timer (`board.gd:362-366`); authoritative completion is a persisted unix stamp
   checked on the tick and on `_load_state` (offline-inclusive, the `regen_ts` pattern
   `board_logic.gd:13-20`).

**Rules module.** Pure logic goes in `engine/scripts/core/improvements.gd` — the
`resident_bucket.gd` shape: static rules, time injected as a parameter, headless-testable.
Dials live in `grove_data.gd`, read through `content.gd` like `TIER_ODDS` (`content.gd:25`).
The whole surface sits behind a `Features.on("improvements")` flag (`features.gd`,
`docs/FEATURES.md`) so it can land dark.

---

## 4 · Soil — plant, wait, harvest

**Verb.** Drag an eligible piece onto an empty Soil → planted. Eligible: an ordinary tiered
line piece — not coins (line 9), chests (10), collectables (12/13), not a generator, not a
locked piece. Specials **are** plantable (they're tiered); every cap below also clamps to
`G.merge_top(code)` (`content.gd:1390`), which caps specials at t3 automatically.

**The ask caps** (parent §7 law, made concrete):

- Let `top_ask(line)` = the highest tier among the line's **live** fence asks. You cannot plant
  a piece at or above `top_ask`; a harvest clamps to `top_ask`.
- A line with **no live asks** uses a hard ceiling of **t8** instead (the §3 mastery ask-band
  ceiling; soil never mints t9+ — the road to t12 stays merging).
- Queries: `_asked_codes`/`_quest_for_code` are today scene-private (`board.gd:1512-1528`) and
  no line→top-tier index exists. Lift them into `quests.gd` as statics and add
  `Quests.top_ask_tier(quests, line) -> int` (0 = none) so the rule is headless-testable.

**Growth.** One timer, tier bump at completion — never gradual:

| Planted tier | 1 | 2 | 3 | 4 | 5 | 6 | 7+ |
|---|---|---|---|---|---|---|---|
| Grow time | 10 s | 45 s | 3 min | 15 min | 1 h | 3 h | 8 h |

Activity state: `{code, ends_at, watered}` with `ends_at` an **absolute unix stamp**. On
completion (1 Hz tick or `_load_state`), the piece flips in place to tier+1 (rank 3: +2),
clamped by the caps, with the standard land-bounce (`LandFx.apply`, the `board.gd:3049-3067`
trio). The grown piece is then ordinary and simply occupies the Soil until moved off.

**Ranks.** r1 base · r2 grow times −30% · r3 harvest +2 tiers (keeps the −30%). Clamps apply
after the +2.

**The three actions while growing** — selecting a growing Soil populates the **info bar** with
a grow row instead of the sell/buy chips: title + *"Growing — 2h 18m"* (the `residents.gd:648`
time format), and three `ActionBar.action_chip` chips (`action_bar.gd:263-330`, the
`_build_burst_chip` pattern `board.gd:2118-2124`):

- **💧 Water** — spend `SOIL_WATER_COST := 10` board water, once per growth
  (`watered` flag): remaining time halves. Routed through the scene's `water` field +
  `_update_water_hud`, like `_pop_seed` — there is no core water API — then
  `_after_board_change()` so the new `ends_at` persists. Chip label carries the cost
  ("💧 −10") to keep it distinct from the shop's "refill water" vocabulary.
- **🌰 Finish now** — `Save.spend_diamonds(price)` with
  `price = max(1, ceil(remaining_secs / 1200.0))` — 1 acorn per started 20 min: t5 1h → 3,
  t7 8h → 24 (the 25-acorn refill is the price anchor, `grove_data.gd:310`). Watering first
  halves the remaining time and therefore the finish price — intended: money buys time, both
  levers are time. This is a **new pricing primitive** (nothing time-priced exists today);
  the remaining-seconds read is a plain `ends_at - now`.
- **✕ Cancel** — free, any time: growth stops, the piece unlocks at its planted tier.

**Forward seam (weather, step 5).** When §4-weather ships, a Rain hour waters soils free. One
seam only: the water action calls `Improvements.water_cost()` which returns the dial; weather
will make it return 0 for the hour. Nothing else is built now.

---

## 5 · Magnet — hold a piece, gather its ladder

**Verb.** Drop a piece onto an empty Magnet → **held**. Placing is the only arming action: a
spawn landing there sits inert (law 2), a merge result landing there leaves the Magnet
unarmed. The held piece stays ordinary — dragging it away disarms the Magnet; merging it away
(the tip-over) leaves the Magnet empty until the next deliberate drop.

**Attraction.** While holding a piece of line L at tier t, the Magnet attracts the pieces that
extend the ladder, in order: first a second t (the pair), then t+1, then t+2, … up to the rank
limit. Candidates are scanned in `_after_board_change()`; when one exists, it **glides** to the
next parking cell — one piece at a time, ~0.3 s each, each glide a committed model move +
`MoveFx` slide (per-glide `animating` is fine: 0.3 s sits under the 0.6 s watchdog,
`board.gd:412-419`). **Attraction only positions pieces; nothing ever merges by itself** — the
§5-outline lights up over the arrangement (§7 hook) and the tip-over is always the player's
drag.

**Parking order — deterministic snake.** Ring-1 neighbours of the Magnet clockwise from north
— (r−1,c), (r−1,c+1), (r,c+1), (r+1,c+1), (r+1,c), (r+1,c−1), (r,c−1), (r−1,c−1) — then ring-2
in the same sweep. Off-board, sealed, improved, and occupied cells are skipped; when no parking
cell is free, attraction pauses (no shuffling of other pieces, no error).

**Never attracted:** a growing piece, another Magnet's held piece or parked arrangement member
(each piece belongs to ≤1 arrangement; multiple Magnets scan in fixed slot order, first claim
wins), the newest piece of a live §5 chain (forward guard — vacuous until step 3), a piece
mid-drag. **Player override:** dragging a piece *out* of an arrangement flags it exempt from
that Magnet until the piece next changes cells by any non-drag cause — no tug-of-war.

**Ranks.**

| Rank | The gathered ladder |
|---|---|
| 1 | the pair + 1 rung (a ×2 waits) |
| 2 | the pair + 3 rungs (a ×4 waits) |
| 3 | unlimited — the longest ladder the board offers |

---

## 6 · Mirror — merge here, harvest there (unique, max 1)

**Trigger.** A player-performed merge whose **result lands on the Mirror cell** — standard
target semantics: dragging A onto B resolves at B's cell (`_commit_merge`, `board.gd:3163`),
so "merge on the Mirror" = the target piece sits on it. The merge-priority drop zone
(`_merge_target_at`, `board.gd:1720-1746`) makes aiming at it forgiving for free.

**Echo selection.** Ready pairs = **adjacent** same-code pairs elsewhere on the board (§7
detection). The trigger merge's own result is "here", not elsewhere — it is never part of an
echoed pair this trigger (re-consuming the mirror's output is exactly what rank 4's bounce is,
for echoed results only). Filtered further: never a code an active quest asks for
(`Quests` statics, §4), never a growing or held piece — parked arrangement members *are*
eligible (they're ordinary; a Mirror can eat a Magnet's prep — player's layout choice). Order:
lowest tier first, ties by board index (`board_model.gd:37`). Rank N echoes up to N pairs per
trigger; the echoed result lands on the pair's lower-index cell. **Rank 4 bounce:** if an
echoed result is itself adjacent to a matching piece, that pair merges too — one bounce per
echo.

**Execution.** All echo merges are committed **synchronously in the model** at trigger time,
then one `_after_board_change()`; the FX plays catch-up — a ripple from the pond to each pair,
then the standard merge FX at reduced scale (`GridFx.play_merge` with the dialog-muted profile,
`grid_fx.gd:27`) — **without holding the `animating` gate**, so input always sees the
post-echo truth and nothing can wedge (`board.gd:2651-2657`).

**Echoes are free value, not an engine** (parent §7): they skip `_bump_combo`
(`board.gd:3238`), the coin-drop and special-drop rolls (zero RNG draws — law 4), and any
future chain credit. Deterministic side-effects still fire: bramble opening
(`openable_brambles` on the landing cell) and the quest-ready/dim refreshes in the fan-out.
No cooldown — the cost is that ready pairs are finite.

**Ranks.** r1 1 echo · r2 2 · r3 3 · r4 echoes may bounce.

---

## 7 · Ready-pair / ladder detection — the shared module

New pure module `engine/scripts/core/board_ladders.gd` (engine-layer, model-only deps):

- `ready_pairs(model, locked: Callable) -> Array` of `[cell_a, cell_b]` — adjacent
  (4-neighbour) same-code pairs where `can_merge` holds and neither piece is locked or held.
  Mirror consumes this.
- `next_rung(held_tier: int, arrangement_tiers: Array) -> int` — the tier that extends the
  ladder next: the pair (same tier) until it exists, then the lowest missing ascending rung.
  Magnet's candidate rule, pure over the current arrangement multiset.
- `chain_newest(model) -> Variant` — a cell or null; returns null (no live chain) until step 3
  lands its chain tracker. Magnet's forward guard reads it.
- Step 3 adds its connected-component/outline detection here; the outline hook over a Magnet
  arrangement is that system rendering what this module reports. Whichever step lands first
  ships the module (validate with a known-positive AND a known-negative fixture before
  trusting it).

`find_mergeable_pair` (`board_logic.gd:25`, hints/FTUE) is untouched apart from the
locked-piece skip.

---

## 8 · Build mode & UI

**The Build button.** A small round leaf button overlaid on the board area's corner (the
bottom bar stays exactly Home · info tray · Bag, `board.gd:1869-1891`). Hidden until the first
slot cell is unsealed; from then on always present, badge-free, quiet.

**Build mode.** Tapping it dims play one step (the hand-hint veil recipe,
`hand_hint.gd:128-192`, minus cutouts) and shows each slot cell as a pad:

- unsealed + unbuilt → dashed cut-paper pad with **+** (new `Kit.slot_cell` state beside
  `empty/locked/unlockable/next`, `ui_kit.gd:5891-5906` — the shared art seam);
- still sealed → a faint locked pad with its level, the `LockBadge` language
  (`lock_badge.gd:21,55`) — honest, and only visible inside build mode;
- built → its cell art highlighted; tap opens the rank view.

Outside build mode: unbuilt slots are invisible (zero clutter); built cells always show their
art + 1–4 leaf rank pips on a corner.

**The build sheet.** `Overlay.modal` (`overlay.gd:47-71`) + the shop's offer-card grid
(`shop.gd:292-413` card schema: art · title · one-line verb · price pill). Three cards — Soil
*"Grows a planted piece one tier."* · Magnet *"Gathers a held piece's ladder."* · Mirror
*"A merge here echoes ready pairs."* Mirror's card greys once one exists (uniqueness). Tap a
card = spend + build, the direct-spend pattern of boost (`board.gd:3151`) and cluster unlocks
(`map.gd:1838`) — no nested confirm; unaffordable cards grey at 0.45 but stay pressable and
wiggle the wallet (`shop.gd:603-609`).

**The rank view.** Tapping a built, idle cell (in build mode) opens the same sheet showing the
type's rank ladder, the next rank's price on the bag-slot gold-tile pattern
(`bag_overlay.gd:77-103`, "Max" when topped), and a small Rebuild row (fee + type picker).
Rank-up celebration is light: `FX.celebrate_at` at the cell, no modal.

**In action.** Soil: planted piece in the dirt, thin progress ring (1 Hz), sprout wiggle;
harvest = the standard land bounce. Magnet: held piece on the pebble, attracted pieces glide
in with a soft trail. Mirror: pond ripple to each echoed pair, reduced-scale merge FX.

**FTUE — the free soil at ~L6.** Arms at level ≥ 6 (`ftue_seen` id `"soil"`,
`save.gd:288-300`); fires as a calm-moment deferred beat (the retirement-offer template,
`board.gd:3938-3964`: never over the FTUE hand-hints, gated on `board_tutorial_seen`) once a
slot cell is unsealed — immediately at L6 if one already is (they unseal from L4), otherwise
on the unseal that follows. The beat: Soil is built free on that cell (lowest board index if
both side mid-edges are open) with a one-line card (*"A patch of soil! Plant a little one and watch it grow."* — OK), then
`HandHint.present` drags a tier-1 onto it (`hand_hint.gd:53-71`); the t1's 10 s sprout is the
payoff. The Build button appears with the beat.

**Art assets** (through the intake pipeline, `docs/design/art-style-guide.md`): soil patch,
horseshoe pebble, tiny pond, dashed pad, leaf Build button, leaf rank pips ×4, water/acorn
chip icons reuse existing.

---

## 9 · Prices & dials (provisional — sim owns finals)

| Dial | Value |
|---|---|
| Paid slot builds (Nth) | 500 · 1 000 · 2 000 · 4 000 · 8 000 coins |
| FTUE slot | free (soil, pre-built, ~L6) |
| Rebuild fee | 200 coins, flat |
| Soil ranks | r2 600 · r3 1 500 coins |
| Magnet ranks | r2 800 · r3 2 000 coins |
| Mirror ranks | r2 800 · r3 2 000 · r4 5 000 coins |
| `SOIL_WATER_COST` | 10 water (halve, once) |
| Acorn finish | `max(1, ceil(remaining / 20 min))` acorns |
| Grow times | table in §4 |

Rank prices are **flat per-type dials**, deviating from the parent's "ranks cost a multiple of
the slot" — the FTUE slot is free, so a slot-multiple prices its upgrades at 0; flat dials also
sim cleaner. Consts live in `grove_data.gd` beside `BOOST_COST` (`grove_data.gd:232`); nothing
goes in `economy_tuning.json` unless the owner asks for a live dial.

---

## 10 · Economy guards & the sim re-pass

Restated as testable laws: no `earn_coins` from any improvement path (Y); echo merges bump no
combo, roll no drops, leave `rng.state` byte-identical; soil refuses top-ask plants and clamps
harvests (ask cap, t8 ceiling, `merge_top`); acorns buy **time only** (finish-now — never a
piece); every coin spend goes through `Save.spend(n, "improvement")`.

`grove_sim` additions (`games/grove/tools/grove_sim.gd`; no make target — run
`godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- [days] [seed]`):

- new sink counters (`improve_spend`) folded into `coin_sink` (`grove_sim.gd:337`) and the Z
  faucet-vs-sink report line (`:341`);
- the bot buys slots/ranks greedily when affordable (the boost-buy block is the template), so
  the sink's absorption shows up in I3 runway;
- board-space pressure: up to 6 cells occupied by improvements — re-confirm I1 zero jams;
- soil throughput modeled as a bounded item faucet (6 slots × the grow table) feeding
  deliveries — re-confirm Y and the coin faucet don't drift.

Gate: the sim re-pass runs before this task merges (parent §8).

---

## 11 · Persistence details

- Rows ride `g["board"]` inside `BoardModel.to_dict/from_dict` (§3); defaults on read; no
  schema bump; cloud save carries the grove blob unchanged.
- Tolerant load: a row on an invalid cell is dropped; activity whose piece is gone
  (`items[cell] == 0` — e.g. `_purge_above_level_content`, `board.gd:774-822`, stripped it)
  is cleared to idle, `changed = true`, self-healed.
- `ends_at` unix stamps make growth offline-correct with zero extra machinery; never store
  remaining-seconds.

---

## 12 · Tests

New suite `games/grove/tests/grove_improvements_tests.gd` on `grove_test_base.gd` (pure rules
headless + real-scene beats via the manual-`_ready` drive pattern, `grove_test_base.gd:438-441`,
and `_tap_board` `:126-134`), plus detection units in `engine/tests/` beside `hint_tests.gd`.
**Add the suite to `GROVE_TESTS` in the Makefile and to the suite list in `CLAUDE.md` in the
same commit** (the project keeps those in step by law).

Coverage checklist: slot unseal gating · buy/build/rebuild/rank flows + refusals ·
ordinariness law (spawn lands inert; gen auto-place skips) · soil plant/refuse/clamp matrix
(live-ask, no-ask t8, specials t3) · water-once + finish price curve + cancel · offline
completion via stamp · locked-piece touchpoint sweep (drag, merge target, sell, deliver, hint,
magnet, echo) · magnet claim/parking/exemption determinism · mirror trigger semantics, echo
order, guards, bounce, rng-state byte-identity across an echo · save round-trip + tolerant
load + purge self-heal · detection known-positive and known-negative · FTUE beat once-only.

---

## 13 · Deviations from the parent doc (called out)

1. **Flat per-type rank prices** (not "a multiple of the slot") — free-slot hole, cleaner sim.
2. **The grow "mini-row" is the info bar's grow row** — the standard selected-cell surface
   (chips API already exists) instead of a new floating widget.
3. **Slot availability binds to the live `MIN_LEVEL` unseal** (side-mids L4, corners L16);
   "first soil free at ~L6" is kept as the FTUE arm level, not a cell-unlock override.
4. **One payment buys and builds** — no owned-but-empty pad state.
5. **Echo FX never holds the input gate** — merges commit synchronously, FX catches up.

## 14 · Open questions for Dev

1. **Slot set.** Recommended: 4 corners + 2 side mid-edges (symmetric, matches the parent).
   Alternative: swap two corners for the top/bottom mid-edges (0,3)/(8,3) at L7 — smoother
   sink pacing (L4/L4/L7/L7/L16/L16), at the cost of symmetry. Which?
2. **Specials in soil** — recommended yes (clamped to t3 by `merge_top`); confirm.
3. **Build button placement** — recommended: floating leaf on the board area's corner;
   alternative: a fourth bottom-bar tile (crowds the three-tile bar). Confirm.
