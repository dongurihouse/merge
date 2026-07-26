# Cell improvements (Soil · Magnet) — spec (2026-07-26)

Draft 3. Rollout step 4 of `2026-07-26-progression-systems-design.md`; supersedes its §6
where they differ. All numbers are provisional dials — the `grove_sim` re-pass owns finals.
Acorns = `currencies.diamonds` (`save.gd:145-160`). Home board only (Rush is a separate
scene, `explore_rush.gd:65` — no flag needed).

## 1 · Placement

- Two types: **Soil** — a resting piece grows a tier on a timer. **Magnet** — matching
  pieces inside its range merge automatically.
- Build on any unsealed, empty cell. Caps: **9 Soil · 3 Magnets**.
- One payment builds at rank 1: pad → two-card sheet → `Save.spend(price, "improvement")`.
  Price keyed to the count of that type already built (§6).
- Rebuild to the other type: 200 coins, cell must be empty, rank resets. Demolish: free, no
  refund.

## 2 · Model & laws

`BoardModel.improvements: Dictionary` — cell → `{kind, rank, code, ends_at, watered}`, the
`gens` trio shape (`board_model.gd:13-24`). Serialized as flattened
`[[row, col, kind, rank, code, ends_at, watered], …]` inside `to_dict()`/`from_dict()`
(`board_model.gd:493-557`), tolerant parse, rides `g["board"]` — no new `_persist()` key,
no `SCHEMA_VERSION` bump (a bump wipes saves, `save.gd:49-58`).

Laws (each tested, §9):

1. Piece truth stays in `board.items[cell]`; improvement rows never copy a piece.
2. Pieces are never locked; the Soil clock reacts to changes instead (§3).
3. Improved cells are ordinary ground — spawns and drops land on them; on Soil, any arrival
   starts growing. Exception: generator auto-placement (`seed_gens`, self-dup
   `board.gd:3076`, birth-on-tap) skips improved cells. Manual gen drops allowed.
4. No randomness, ever (the RNG stream is persisted and order-sensitive, `board.gd:983`).
   All ordering, timing, and selection below is deterministic; auto-merges roll no drops.
5. No path calls `G.earn_coins`/`Save.earn_coins` (sim invariant Y, `save.gd:118-124`).
6. Beats: Soil reconcile + Magnet scan in `_after_board_change()` (`board.gd:1011`);
   countdown display on the 1 Hz board Timer (`board.gd:362-366`); completion authority is
   the `ends_at` unix stamp, checked on tick and in `_load_state` (offline-inclusive, the
   `regen_ts` pattern `board_logic.gd:13-20`).

Pure rules in `engine/scripts/core/improvements.gd` (`resident_bucket.gd` shape: statics,
time injected). Dials in `grove_data.gd`, read through `content.gd`. All behind
`Features.on("improvements")`.

## 3 · Soil

- Any eligible piece resting on Soil is growing, however it arrived. No plant verb, no
  cancel verb.
- Eligible: tiered line piece below `G.merge_top(code)` (`content.gd:1390`; specials cap
  t3). Not coins (line 9), chests (10), collectables (12/13), generators. Ineligible sits,
  no ring.
- Reconcile each `_after_board_change()`: same code → clock runs; new eligible occupant →
  fresh clock, `watered` cleared; empty or ineligible → activity cleared.
- Completion at `ends_at`: +1 tier in place (rank 3: +2), clamped to `merge_top`; land
  bounce (`board.gd:3049-3067` trio); fresh clock starts at the new tier.
- Curve — time per step, by the tier grown **from**:

| From | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Time | 10 s | 45 s | 3 min | 15 min | 30 min | 1 h | 4 h | 8 h | 16 h | 24 h | 48 h |

- Ranks: r2 times −30% · r3 +2 tiers per completion.
- No ask interplay — growth ignores the fence.
- Selecting a growing piece → info-bar grow row: *"Growing to t8 — 2h 18m"*
  (`residents.gd:648` format) + two chips (`ActionBar.action_chip`, pattern
  `board.gd:2118-2124`):
  - **💧 −10** — spend `SOIL_WATER_COST := 10` board water, once per step: remaining time
    halves. Via the scene `water` field + `_update_water_hud`, then `_after_board_change()`.
  - **🌰 finish** — `Save.spend_diamonds(max(1, ceil(remaining_secs / 1800.0)))` — 1 acorn
    per started 30 min (1 h → 2, 48 h → 96).
- On the piece: thin progress ring (1 Hz); a countdown chip ("2h") when the step ≥ 15 min.
- **t7+ warning:** any player action that resets or consumes a piece growing from tier ≥ 7 —
  move, merge, deliver, sell, stash — first shows a confirm (`Overlay.modal`, dismissable):
  *"This restarts 6h of growing. Move it anyway?"* — Keep growing (default) / Move it.
  Nothing below t7. No automatic path needs it (Magnets skip growing pieces).
- Weather seam (dormant): module exposes `apply_water(activity, now)`; the 💧 chip pays and
  calls it; Rain (step 5) calls it free per `2026-07-26-weather-hours-design.md` §4.

## 4 · Magnet

- Range by rank: r1 **1×3** (its model row) · r2 **plus** (5 cells) · r3 **3×3**. Off-board
  and sealed cells are not in range. Shown as a faint field on selection and in build mode.
- When two same-code `can_merge` pieces (`board_model.gd:305-311`) sit inside one Magnet's
  range, they auto-merge: both slide to the pair cell nearer the Magnet (tie → lower board
  index, `board_model.gd:37`), then standard merge FX at reduced scale (`GridFx.play_merge`
  dialog-muted, `grid_fx.gd:27`).
- Cadence: scan in `_after_board_change()`; one merge per ~0.3 s, model-committed before its
  FX (per-merge `animating` stays under the 0.6 s watchdog, `board.gd:412-419`); loops until
  no pair remains. Order: lowest tier, then board index. Overlapping ranges: each Magnet
  scans independently, in board-index order; a pair must fit inside a single Magnet's range.
- Guards (each tested):
  - never a quest-asked code — `_asked_codes` (`board.gd:1512-1518`) lifted into a
    `quests.gd` static (step-2 mastery's `ask_band` derives from the same primitive);
  - never a piece growing on Soil;
  - hold fire while a chain is armed — the scene's `chain_armed_cell()` seam (cascade spec
    §4); resume on the next fan-out;
  - no combo bump, no coin/special drop rolls, no chain credit; bramble opening
    (`openable_brambles`) and the fan-out refreshes still fire;
  - kind-uniform otherwise: coins, chests, specials auto-merge like anything (cascade R5).
- Pair scan: new `board_logic.gd` static `range_pairs(board, cells: Array) -> Array` of
  `[cell_a, cell_b]`. Validate against a known-positive and a known-negative fixture.

## 5 · Build mode, UI, FTUE

- **Build button:** small leaf overlaid on a board-area corner; hidden until the FTUE beat;
  bottom bar unchanged (`board.gd:1869-1891`).
- **Build mode:** dim one step (hand-hint veil recipe minus cutouts, `hand_hint.gd:128-192`);
  every empty unsealed cell becomes a pad (new `Kit.slot_cell` state,
  `ui_kit.gd:5891-5906`); built cells highlight → rank view; occupied and sealed cells show
  nothing. Outside build mode: built-cell art + 1–3 leaf rank pips only.
- **Sheet:** `Overlay.modal` (`overlay.gd:47-71`) + the shop offer-card grid
  (`shop.gd:292-413`). Two cards — Soil *"A piece resting here grows."* · Magnet *"Matching
  pieces in its range merge themselves."* Each shows count vs cap ("Soil · 3/9"), greys at
  cap. Tap = spend + build (direct-spend, no nested confirm; unaffordable = grey 0.45,
  pressable, wallet wiggle `shop.gd:603-609`).
- **Rank view** (tap a built cell in build mode): rank ladder, next price on the bag-slot
  gold tile (`bag_overlay.gd:77-103`, "Max" at top), Rebuild row, Demolish. Rank-up:
  `FX.celebrate_at`, no modal.
- **FTUE (~L6):** arms at level ≥ 6, `ftue_seen("soil")` (`save.gd:288-300`); calm-moment
  deferred beat (retirement-offer template `board.gd:3938-3964`, gated on
  `board_tutorial_seen`). One-line card — *"You can tend the ground now — pick a spot for
  some soil."* — then build mode opens with a free Soil credit; `HandHint.present`
  (`hand_hint.gd:53-71`) taps a suggested empty cell; the player's tap builds it. The Build
  button appears with the beat.
- Art via intake (`docs/design/art-style-guide.md`): soil patch, pebble, buildable pad, leaf
  button, rank pips ×3, time chip, range field.

## 6 · Dials (provisional)

| Dial | Value |
|---|---|
| Soil builds (Nth) | free (FTUE) · 500 · 1 000 · 2 000 · 4 000 · 8 000 · 16 000 · 32 000 · 64 000 |
| Magnet builds (Nth) | 2 000 · 8 000 · 32 000 |
| Rebuild / Demolish | 200 coins flat / free, no refund |
| Soil ranks | r2 600 · r3 1 500 |
| Magnet ranks | r2 5 000 · r3 20 000 |
| `SOIL_WATER_COST` | 10 water — sim revisits the flat halve at t10+ (worth 24 h at t11) |
| Acorn finish | `max(1, ceil(remaining / 30 min))` |

Consts in `grove_data.gd` beside `BOOST_COST` (`grove_data.gd:232`); nothing in
`economy_tuning.json` unless the owner wants a live dial.

## 7 · Sim re-pass (gates the merge)

Run: `godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- [days] [seed]`.

- `improve_spend` counter into `coin_sink` (`grove_sim.gd:337`) and the Z report (`:341`);
  the bot buys builds/ranks greedily (boost-buy block as template) → I3 runway.
- I1 zero jams at full build-out (12 improved cells).
- Soil as a bounded faucet — 9 cells on the §3 curve to t12; re-confirm Y and faucet drift;
  price the t10+ watering halve.
- Magnet is value-neutral (merges only what exists); assert no ledger moves beyond normal
  merge accounting.

## 8 · Persistence

- Rows ride `g["board"]`; defaulted on read; cloud save unchanged.
- Tolerant load: invalid-cell rows dropped; activity reconciled against `items[cell]` as on
  any board change (covers `_purge_above_level_content`, `board.gd:774-822`).
- Store `ends_at` stamps, never remaining-seconds.

## 9 · Tests

New `games/grove/tests/grove_improvements_tests.gd` on `grove_test_base.gd` (pure rules +
real-scene via manual `_ready`, `grove_test_base.gd:438-441`, and `_tap_board` `:126-134`);
`range_pairs` units in `engine/tests/`. Add the suite to `GROVE_TESTS` in the Makefile and
the `CLAUDE.md` suite list in the same commit.

Cover: build/rebuild/demolish/rank flows + cap refusals · pads only on empty+unsealed ·
spawn on Soil grows; gen auto-place skips · clock reconcile matrix
(arrive/leave/replace/merge-onto/complete; `watered` per step) · curve incl. ranks and
`merge_top` clamps · water-once + finish price · offline completion via stamp · t7+ warning
on every reset path, absent below t7 · range shapes per rank · auto-merge order, landing
cell, loop-until-done · all five guards (asked code · growing piece · armed chain · no
credit/no RNG, `rng.state` byte-identical · kind-uniformity) · save round-trip, tolerant
load, purge self-heal · `range_pairs` known-positive/negative · FTUE once-only, free credit
spends once.

## 10 · Open questions

1. Move verb for placed improvements, or rebuild/demolish only? (A misplaced 32 000-coin
   Magnet has no recovery.)
2. Magnet r1/r2 range shapes — only the 3×3 max was pinned; 1×3 → plus is this spec's
   fill-in.
3. t5 grow step = 30 min — interpolated between the pinned 15 min and 1 h.
