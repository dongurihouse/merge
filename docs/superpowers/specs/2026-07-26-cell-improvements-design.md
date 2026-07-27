# Cell improvements (Soil · Magnet) — spec (2026-07-26)

Draft 6 — **build mode is cut; improvements arrive as seed items** (§1, §1a lists what to
revert). Rollout step 4 of `2026-07-26-progression-systems-design.md`; supersedes its §6
where they differ. All numbers are provisional dials — the `grove_sim` re-pass owns finals.
Acorns = `currencies.diamonds` (`save.gd:145-160`). Home board only (Rush is a separate
scene, `explore_rush.gd:65` — no flag needed).

## Summary — what is being built

Two cell improvements on the home merge board, behind a feature flag. There is **no build
mode and no board-edge button**: improvements are acquired as **seed items that drop on the
board**, and every interaction reuses the existing tap → info-bar-chip surface.

- **Seeds** drop like other special items. Tap one and its info bar offers **Place** (become
  this cell's improvement) · **Bag** · **Sell**. At most one unplaced seed per kind exists at
  a time.
- **Soil** (max 9, 3 ranks): any eligible piece resting on it grows +1 tier on an
  offline-capable timer — 10 s at tier 1 up to 48 h for t11→t12. Pieces are never locked;
  changing one restarts the clock, with a confirm at t7+. Watering halves a step once;
  acorns finish it now.
- **Magnet** (max 3, rankless): a passive 3×3 field — matching pieces inside it auto-merge,
  guarded so it never eats quest-asked codes, growing pieces, or a live chain.
- A placed improvement is the cell's **background**: pieces spawn, rest, and merge on it
  normally. Tapping the cell **while it is empty** offers **Unsocket**, which pays a cost and
  turns it back into a seed — that is also how you move one.
- Around them: an FTUE seed grant at ~L6, save state riding the board dict, a test suite, and
  a `grove_sim` re-pass. Mocks: `games/grove/assets/_concepts/ui/improvements_v1/`.

## 1 · Seeds — acquisition, placement, unsocket

**The seed item.** Soil and Magnet each get a pseudo-line in `SPECIAL_ITEMS`
(`grove_data.gd:356`) — lines **14** (soil seed) and **15** (magnet seed), both `"top": 1`
so they never merge. They are ordinary board occupants otherwise: draggable, stashable in the
bag, sellable, and they occupy a cell.

**Dropping.** Seeds join the existing special-drop table
(`SPECIAL_DROP_WEIGHTS`, `grove_data.gd:366`) and ride the roll that already happens after a
merge — `pick_special_drop` makes exactly **one** `randi_range` call
(`content.gd:1431-1440`), and adding kinds must not add a second. Weight the seeds low
(§6). A kind is **filtered out of the weight table before the draw** when either:

- an unplaced seed of that kind already exists on the board **or** in the bag, or
- that kind is at its placed cap (9 Soil / 3 Magnets).

The filter is a pure function of board + bag state, so the draw count is unchanged and the
stream stays deterministic. When filtering empties the table, the drop resolves to the
ordinary special-item pick as it does today. Per-kind gating means one soil seed and one
magnet seed may be in flight at once.

**Placing.** Tap a seed → the info bar shows its name and three chips
(`ActionBar.action_chip`, the pattern at `board.gd:2118-2124`):

- **Place** — the seed is consumed and the cell it sits on becomes that improvement. Legal
  only where `can_build_improvement()` already allows (unsealed, no generator, not already
  improved); the seed's own occupancy does not count against "empty". Free.
- **Bag** — stashes the seed through the existing `_stash` path.
- **Sell** — the existing trashcan chip, at the §6 dial price.

Placing from the **bag** is not a separate flow: drag the seed back onto a cell, then tap and
Place. There is no chooser modal, no pads, and no build mode.

**Unsocket (and how you move one).** Tapping an improved cell **that has no piece on it**
selects it and offers one chip, **Unsocket**: pay the §6 cost, and the improvement becomes a
seed item on that same cell. Soil rank travels with the seed. Moving is unsocket → carry →
Place, so there is no separate move verb and no pending-move state. An improved cell holding
a piece selects that piece as normal — the improvement is background.

### 1a · What to revert from draft 5's implementation

The shipped branch built a build mode. Remove it entirely:

- `board.gd` — the leaf button (`build_btn`, `_refresh_build_button`, its `_ready` wiring),
  `_build_mode`, `_start_build_mode`, `_exit_build_mode`, `_render_build_pads`,
  `_clear_build_pads`, `_improvement_pad_nodes`, `_make_improvement_pad`,
  `_on_improvement_pad_pressed`, `_open_improvement_sheet`, `_improvement_move_from`,
  `_move_improvement_from`, `_move_improvement_from_confirmed`, `_finish_improvement_move`.
- `_open_improvement_cell` — keep the cell-tap entry point but replace the modal sheet with
  the info-bar Unsocket chip; Soil rank-up moves onto the same info bar.
- `BoardActions.build_improvement` / `move_improvement` → replace with
  `place_seed(board, cell)` and `unsocket_improvement(board, cell)`.
- Dials `SOIL_BUILD_PRICES`, `MAGNET_BUILD_PRICES`, `IMPROVEMENT_MOVE_COST` and their
  `content.gd` re-exports.
- The FTUE beat's `_start_build_mode()` call (`board.gd:2578`) → grant a seed instead (§5).
- `games/grove/assets/ui/kit/build_leaf.png` (+ `.import`) — delete, the button is gone.
- Tests naming build mode / pads / the move flow.

**Keep unchanged:** everything in §2–§4 (the model, the laws, soil growth and its curve,
ranks, water/finish, the t7+ warning, the magnet field and its five guards), the save shape,
`cell_soil.png` / `cell_magnet.png` / `pip_leaf.png`, and every regression test from the
review round (the dead-fall-through, RNG byte-identity, mark-seen catch-up, and drag-node
tests are all still load-bearing).

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

- **No ranks — one range: the full 3×3 from the moment it is placed.** Off-board and sealed
  cells are not in range. Shown as a faint field while the Magnet cell is selected.
- The Magnet's own cell is ordinary ground: pieces may be placed on it, spawn there, or rest
  there; a piece on the Magnet cell is inside the range and auto-merges like any other (a
  pair including it lands on the Magnet cell — it is the nearest cell).
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

## 5 · UI & FTUE

Everything runs on the existing select → info-bar-chip surface. No modals, no pads, no
board-edge button, no new screen.

- **Seed selected:** info bar shows the seed's name and one-line description, plus chips
  **Place** (garden-green, primary) · **Bag** · the existing **Sell** trashcan. `Place` is
  disabled-with-wobble on an illegal cell (sealed, generator, already improved) with the
  reason in the subtitle. Placing plays `FX.pop` on the new cell art.
- **Improved cell, empty, selected:** info bar shows *"Soil · rank 2"* or *"Magnet"* plus
  **Unsocket** carrying its price (coin or acorn icon), and for Soil the next rank's price
  on the same row (`FX.celebrate_at` on rank-up, no modal). Direct-spend, no nested confirm —
  the `board.gd:3151` boost pattern; unaffordable wobbles the wallet.
- **Improved cell holding a piece:** selects the piece exactly as today; the improvement is
  background. The grow row (below) replaces the chips while it is growing.
- **FTUE (~L6):** arms at level ≥ 6, `ftue_seen("soil")` (`save.gd:288-300`); calm-moment
  deferred beat (retirement-offer template `board.gd:3938-3964`, gated on
  `board_tutorial_seen`). It **grants a soil seed** onto a free cell (deterministic, not
  rolled) with a one-line card — *"A seed of good earth! Tap it to choose a spot."* — then
  `HandHint.present` (`hand_hint.gd:53-71`) points at the seed. The player taps it and
  presses Place. Seeds begin dropping normally from then on.
- Visuals (normative for mocks and implementation; palette roles per the art guide §3):
  - Soil seed item: a small burlap seed pouch, gold-brown, sprig of green at the neck.
  - Magnet seed item: a slate-blue horseshoe nub half-buried in a paper seed husk.
  - Soil cell: rounded matte earth patch, desaturated gold-brown, deckled cut-paper edge, one
    same-hue shadow plane.
  - Magnet cell: horseshoe pebble in structural slate, inset on the cell.
  - Soil rank pips: 1–3 garden-green leaf pips, bottom-left corner of the cell. Magnet has
    no pips.
  - Growing piece: thin garden-green progress ring, clockwise; small warm-cream time chip
    with ink text ("2h") at the piece's top-right when the step ≥ 15 min; sprout wiggle.
  - Magnet range field: translucent garden-green cut-paper field (~15% opacity) over the
    range cells, under the pieces.
  - Grow row: info tray title *"Growing to t8 — 2h 18m"*; chips 💧 droplet **−10** ·
    🌰 acorn **8**.
  - Warning card: *"This restarts 6h of growing. Move it anyway?"* — **Keep growing**
    (action green, default) · **Move it** (quiet cream).
- Raster masters (already produced; 512² transparent, at `games/grove/assets/ui/kit/`):
  `cell_soil.png` · `cell_magnet.png` · `pip_leaf.png` · **`seed_soil.png`** ·
  **`seed_magnet.png`**. `build_leaf.png` is deleted with the button (§1a). Everything else
  — ring, time chip, range field, chips — is code-drawn. **Generate no art**: wire these
  paths; if one is missing use an existing kit icon behind the same seam.
- Mocks: `games/grove/assets/_concepts/ui/improvements_v1/` — the soil-growing and
  magnet-range mocks still hold. The build-mode and build-sheet mocks are **stale**; ignore
  them (kept only as history).

## 6 · Dials (provisional)

| Dial | Value |
|---|---|
| Seeds | drop free; `SPECIAL_DROP_WEIGHTS` soil **1**, magnet **1** against chest/water/acorn 1 each |
| Caps | 9 Soil · 3 Magnets (placed + unplaced count toward the drop gate) |
| Place | free |
| **Unsocket** | Soil **100 coins** · Magnet **10 acorns** |
| Seed sell price | Soil seed **250 coins** · Magnet seed **1 000 coins** |
| Soil ranks | r2 600 · r3 1 500 coins |
| `SOIL_WATER_COST` | 10 water — sim revisits the flat halve at t10+ (worth 24 h at t11) |
| Acorn finish | `max(1, ceil(remaining / 30 min))` |

Consts in `grove_data.gd` beside `BOOST_COST` (`grove_data.gd:232`); nothing in
`economy_tuning.json` unless the owner wants a live dial.

**Economy note (owner decision, flagged for veto).** Free seeds delete the build-price
ladder, which was the standing coin sink and the *only* premium sink — the last sim run
showed `improvements 5600🪙` and `magnets 175💎`. To keep both alive the cost moves to the
verb the Dev specified: **unsocketting costs coins for Soil and acorns for Magnet**. Soil
rank-ups (up to 9 × 2 100 coins) carry the coin sink. If you would rather magnets stay
purely free-to-earn, say so and the acorn sink drops to zero — the sim re-pass will show it.

## 7 · Sim re-pass (gates the merge)

Run: `godot --headless --path . -s res://games/grove/tools/grove_sim.gd -- [days] [seed]`.

- coin spends (Soil ranks + Soil unsockets) into a new `improve_spend` counter folded into
  `coin_sink` (`grove_sim.gd:337`) and the Z report (`:341`); Magnet unsocket acorns into the
  D diamond ledger. The bot places every seed it earns and ranks up greedily → I3 runway.
- **Seed supply:** model the drop gate (one unplaced seed per kind, caps 9/3) and report how
  many days it takes to reach the caps — free seeds mean the build ladder no longer paces
  adoption, so the drop weight is now the pacing dial.
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

Cover: **seed drop gate** — no second seed of a kind while one is unplaced on board or in
bag, none at cap, and the filtered pick makes exactly ONE rng draw (assert `rng.state`
advances by the same amount as an unfiltered drop) · seed Place/Bag/Sell chips incl. illegal
-cell refusal · **unsocket** — cost charged, seed returned to that cell, Soil rank travels,
refused while a piece rests there · a placed improvement is background (pieces spawn/rest/
merge on it) · spawn on Soil grows; gen auto-place skips · clock reconcile matrix
(arrive/leave/replace/merge-onto/complete; `watered` per step) · curve incl. ranks and
`merge_top` clamps · water-once + finish price · offline completion via stamp · t7+ warning
on every reset path, absent below t7 · magnet 3×3 from placement; a piece on the Magnet cell
auto-merges · auto-merge order, landing cell, loop-until-done · all five guards (asked code
· growing piece · armed chain · no credit/no RNG, `rng.state` byte-identical ·
kind-uniformity) · save round-trip, tolerant load, purge self-heal · `range_pairs`
known-positive/negative · FTUE grants exactly one seed, once.

**Carry forward unchanged** — the regression tests added in the draft-5 review round stay
and must keep passing: `_stash` / `_deliver_from_board` fall-through, giver-tap t7 confirm,
magnet-bramble `rng.state` identity, `_mark_seen` catch-up, top-soil info refresh, and the
tick-does-not-free-the-drag-node test.

## 10 · Implementation directions (for the implementing agent)

**This is an edit of existing work, not a fresh build.** The branch `improvements` at
`/Users/xup/dh/wt-improvements` already implements draft 5 and passed review (41 suites,
2 466 assertions). Continue on that branch: first apply the §1a revert, then build §1's seed
flow on top. Keep §2–§4 and every existing regression test. The branch stays **unmerged** —
review happens in the worktree. Never edit the main checkout (a hook blocks it).

If that worktree is gone, recreate it from the branch:

```
git -C /Users/xup/dh/merge worktree add /Users/xup/dh/wt-improvements improvements
rsync -a --delete /Users/xup/dh/merge/.godot/ /Users/xup/dh/wt-improvements/.godot/
```

The rsync seeds the import cache — without it the first test run does a slow full reimport.

Read before coding: this spec end to end; `docs/design/board_decomposition.md` (layering
`scenes/ → ui/ → core/`, frozen `_persist()` key set, RNG discipline); the §2 anchors in
their files.

Build in commit-sized steps, each green (`feat(improvements): …` messages):

1. `Features` flag `improvements` (+ `docs/FEATURES.md` row) · dials in `grove_data.gd`
   re-exported through `content.gd` · pure rules module `engine/scripts/core/improvements.gd`
   with unit tests in the new suite `games/grove/tests/grove_improvements_tests.gd`.
2. `BoardModel.improvements` + `to_dict`/`from_dict` rows + reconcile helper; save
   round-trip and tolerant-load tests.
3. Soil runtime in `board.gd`: reconcile in `_after_board_change()`, completion on the 1 Hz
   tick + `_load_state`, land-bounce, info-bar grow row (`ActionBar.action_chip`), water and
   acorn-finish spends, t7+ warning (`Overlay.modal`), ring + time chip rendering.
4. `board_logic.range_pairs` (+ known-positive/negative tests) · Magnet scan/execute loop
   with all five guards · pull FX.
5. Seeds: the two `SPECIAL_ITEMS` lines, the filtered drop pick, the info-bar Place / Bag /
   Sell chips, and the Unsocket chip + spend paths on an empty improved cell.
6. FTUE beat (`ftue_seen("soil")`, retirement-offer template, `HandHint`) — grants one seed.
7. Register the suite in `GROVE_TESTS` (Makefile) **and** the `CLAUDE.md` suite list — same
   commit.
8. `grove_sim` additions (§7), run the re-pass, paste the invariant numbers into the final
   commit message.

Hard rules (violations fail review): never bump `SCHEMA_VERSION`; zero RNG draws in any
improvement path (the byte-identity test pins it); never call `G.earn_coins`/
`Save.earn_coins`; reuse the named shared components — no bespoke modals, chips, cells, or
keyers; all dials in `grove_data.gd`, none inline.

**Assets — do not generate any.** The five raster masters (§5) already exist at
`games/grove/assets/ui/kit/`: `cell_soil.png`, `cell_magnet.png`, `pip_leaf.png`,
`seed_soil.png`, `seed_magnet.png`. Do not generate, draw, edit, or download art of any
kind. Wire the exact paths; if a master is missing, put a placeholder behind the same seam —
an existing kit icon or a flat tinted rect — so the real file swaps in with zero code
change. Everything else is code-drawn per §5. `build_leaf.png` is deleted with the button
(§1a). When a master is first drawn in a top-level dialog, add its bake target per the art
guide §8 (`make bake-textures`).

Process: run `make test-fast` after every change and the full `make test` before handing
off — always in the **foreground** (a backgrounded run never returns to an agent). A plain
`godot -s` foreground run times out at 2 min — parse-check with
`godot --headless --check-only --script <file>` and run suites only via `make`. After adding
any new `.gd`, run `make import` before committing so its `.uid` lands in the same commit.
Capture proof of the new surfaces (`make shot-grove OUT=…` from the worktree) and list the
capture paths in the handoff note.

Done = full `make test` green in the worktree, sim invariants pasted, captures listed,
branch pushed-in-place and left unmerged for review.

## 11 · Open questions

1. t5 grow step = 30 min — interpolated between the pinned 15 min and 1 h.
